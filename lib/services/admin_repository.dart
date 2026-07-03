import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// AdminRepository is the Firebase layer.
// Screens call these methods instead of writing Firebase code directly.
// This keeps UI files easier to read and makes Firebase changes easier later.
class AdminRepository {
  AdminRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Live list of capstone groups. Any Firestore change updates the admin UI.
  Stream<List<CapstoneGroup>> groupsStream() {
    return _firestore
        .collection('groups')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(CapstoneGroup.fromSnapshot).toList(),
        );
  }

  // Admin accounts are created in Firebase Authentication.
  Future<void> signInAdmin({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Sends Firebase's built-in password reset email for admin accounts.
  // Student accounts in this prototype use generated passwords, so admins reset them manually.
  Future<void> sendAdminPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  // Creates a group document. Students are stored inside the group for now
  // because this prototype is simpler to understand that way.
  Future<void> createGroup(String name) {
    return _firestore.collection('groups').add({
      'name': name,
      'isPremium': false,
      'students': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Adds a student to a group and generates a simple Student ID/password.
  // Later, this can be upgraded to real Firebase Auth student accounts.
  Future<StudentAccount> registerStudent(StudentDraft draft) async {
    final groupRef = _firestore.collection('groups').doc(draft.groupId);
    final counterRef = _firestore.collection('metadata').doc('studentCounter');

    return _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) {
        throw StateError('The selected group no longer exists.');
      }

      final group = CapstoneGroup.fromSnapshot(groupSnapshot);
      if (group.students.length >= 5) {
        throw StateError('This group already has 5 members.');
      }

      final counterSnapshot = await transaction.get(counterRef);
      final currentNumber = counterSnapshot.data()?['nextNumber'] as int? ?? 1;
      final studentId = 'STU${currentNumber.toString().padLeft(3, '0')}';
      final password = _generatePassword(currentNumber);
      final student = StudentAccount(
        id: groupRef.collection('students').doc().id,
        name: draft.name,
        email: draft.email,
        studentId: studentId,
        password: password,
      );

      transaction.set(counterRef, {
        'nextNumber': currentNumber + 1,
      }, SetOptions(merge: true));
      transaction.update(groupRef, {
        'students': FieldValue.arrayUnion([student.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return student;
    });
  }

  Future<void> deleteStudent({
    required CapstoneGroup group,
    required StudentAccount student,
  }) {
    return _firestore.collection('groups').doc(group.id).update({
      'students': FieldValue.arrayRemove([student.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Admin reset: generate a new temporary password for one student.
  Future<String> resetStudentPassword({
    required CapstoneGroup group,
    required StudentAccount student,
  }) async {
    final newPassword = _generatePassword(
      DateTime.now().millisecondsSinceEpoch,
    );
    await updateStudentPassword(
      groupId: group.id,
      studentId: student.id,
      newPassword: newPassword,
    );
    return newPassword;
  }

  // Student change password: verify the old password, then save the new one.
  Future<void> changeStudentPassword({
    required String groupId,
    required String studentId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw StateError('New password must be at least 6 characters.');
    }

    final groupRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) throw StateError('Group not found.');

      final group = CapstoneGroup.fromSnapshot(groupSnapshot);
      final student = group.students.firstWhere(
        (student) => student.id == studentId,
        orElse: () => throw StateError('Student account not found.'),
      );

      if (student.password != currentPassword) {
        throw StateError('Current password is incorrect.');
      }

      final updatedStudents = [
        for (final item in group.students)
          item.id == studentId ? item.copyWith(password: newPassword) : item,
      ];

      transaction.update(groupRef, {
        'students': updatedStudents.map((student) => student.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateStudentPassword({
    required String groupId,
    required String studentId,
    required String newPassword,
  }) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) throw StateError('Group not found.');

      final group = CapstoneGroup.fromSnapshot(groupSnapshot);
      final updatedStudents = [
        for (final item in group.students)
          item.id == studentId ? item.copyWith(password: newPassword) : item,
      ];

      if (!group.students.any((student) => student.id == studentId)) {
        throw StateError('Student account not found.');
      }

      transaction.update(groupRef, {
        'students': updatedStudents.map((student) => student.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Premium is one-directional: once granted it stays on, so there is no revoke path.
  Future<void> grantPremium(CapstoneGroup group) {
    return _firestore.collection('groups').doc(group.id).update({
      'isPremium': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGroup(String groupId) {
    return _firestore.collection('groups').doc(groupId).delete();
  }

  // Student login checks the generated credentials stored inside groups.
  // This is simple for the prototype; secure production auth should use Auth.
  Future<StudentLoginResult?> signInStudent({
    required String usernameOrEmail,
    required String password,
  }) async {
    final normalizedLogin = usernameOrEmail.trim().toLowerCase();
    final snapshot = await _firestore.collection('groups').get();

    for (final groupDoc in snapshot.docs) {
      final group = CapstoneGroup.fromSnapshot(groupDoc);
      for (final student in group.students) {
        final emailMatches = student.email.toLowerCase() == normalizedLogin;
        final idMatches = student.studentId.toLowerCase() == normalizedLogin;
        if ((emailMatches || idMatches) && student.password == password) {
          return StudentLoginResult(group: group, student: student);
        }
      }
    }

    return null;
  }

  String _generatePassword(int seed) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random(DateTime.now().microsecondsSinceEpoch + seed);
    final code = List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'temp$code';
  }
}

// Data model for one capstone group from Firestore.
class CapstoneGroup {
  const CapstoneGroup({
    required this.id,
    required this.name,
    required this.isPremium,
    required this.students,
  });

  factory CapstoneGroup.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final rawStudents = data['students'] as List<dynamic>? ?? [];
    return CapstoneGroup(
      id: snapshot.id,
      name: data['name'] as String? ?? 'Untitled Group',
      isPremium: data['isPremium'] as bool? ?? false,
      students: rawStudents
          .whereType<Map<dynamic, dynamic>>()
          .map((student) => StudentAccount.fromMap(student))
          .toList(),
    );
  }

  final String id;
  final String name;
  final bool isPremium;
  final List<StudentAccount> students;
}

// Data model for one student account inside a group.
class StudentAccount {
  const StudentAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.studentId,
    required this.password,
  });

  factory StudentAccount.fromMap(Map<dynamic, dynamic> map) {
    return StudentAccount(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      studentId: map['studentId'] as String? ?? '',
      password: map['password'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String email;
  final String studentId;
  final String password;

  StudentAccount copyWith({String? password}) {
    return StudentAccount(
      id: id,
      name: name,
      email: email,
      studentId: studentId,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'studentId': studentId,
      'password': password,
    };
  }
}

// Temporary object used when the admin submits the register student form.
class StudentDraft {
  const StudentDraft({
    required this.name,
    required this.email,
    required this.groupId,
  });

  final String name;
  final String email;
  final String groupId;
}

// Returned after a student login so the dashboard can show student/group info.
class StudentLoginResult {
  const StudentLoginResult({required this.group, required this.student});

  final CapstoneGroup group;
  final StudentAccount student;
}
