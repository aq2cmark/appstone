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

  // One-off group fetch, used to restore a saved student session on startup.
  Future<CapstoneGroup?> getGroup(String groupId) async {
    final snapshot = await _firestore.collection('groups').doc(groupId).get();
    if (!snapshot.exists) return null;
    return CapstoneGroup.fromSnapshot(snapshot);
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
        tempPassword: password,
        // Fresh accounts start on a temp password and must set their own.
        mustChangePassword: true,
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

  // Admin reset: generate a new temporary password for one student. This makes
  // the temp password the current login again, forces the student to change it
  // on next login, and clears any pending "forgot password" request.
  Future<String> resetStudentPassword({
    required CapstoneGroup group,
    required StudentAccount student,
  }) async {
    final newPassword = _generatePassword(
      DateTime.now().millisecondsSinceEpoch,
    );
    await _updateStudentInGroup(
      groupId: group.id,
      studentId: student.id,
      transform: (current) => current.copyWith(
        password: newPassword,
        tempPassword: newPassword,
        mustChangePassword: true,
        resetRequested: false,
      ),
    );
    return newPassword;
  }

  // Student change password: verify the old password, then save the new one.
  // The new password is stored only in [password] (never in [tempPassword]),
  // so it is never revealed on the admin dashboard.
  Future<void> changeStudentPassword({
    required String groupId,
    required String studentId,
    required String currentPassword,
    required String newPassword,
  }) async {
    _validateNewPassword(newPassword);
    await _updateStudentInGroup(
      groupId: groupId,
      studentId: studentId,
      transform: (current) {
        if (current.password != currentPassword) {
          throw StateError('Current password is incorrect.');
        }
        return current.copyWith(
          password: newPassword,
          mustChangePassword: false,
        );
      },
    );
  }

  // Used by the forced prompt after a student logs in with a temp password.
  // No current-password check is needed because the student just authenticated
  // with it; we only clear the "must change" flag and store the new password.
  Future<void> completeTempPasswordChange({
    required String groupId,
    required String studentId,
    required String newPassword,
  }) async {
    _validateNewPassword(newPassword);
    await _updateStudentInGroup(
      groupId: groupId,
      studentId: studentId,
      transform: (current) => current.copyWith(
        password: newPassword,
        mustChangePassword: false,
      ),
    );
  }

  // Student-facing "forgot password": flags the account so the admin sees a
  // reset request (an icon on the student's row). Returns the student's name
  // when a match is found, or null when nothing matched.
  Future<String?> requestPasswordReset(String usernameOrEmail) async {
    final normalized = usernameOrEmail.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final snapshot = await _firestore.collection('groups').get();
    for (final groupDoc in snapshot.docs) {
      final group = CapstoneGroup.fromSnapshot(groupDoc);
      for (final student in group.students) {
        final matches =
            student.email.toLowerCase() == normalized ||
            student.studentId.toLowerCase() == normalized;
        if (matches) {
          await _updateStudentInGroup(
            groupId: group.id,
            studentId: student.id,
            transform: (current) => current.copyWith(resetRequested: true),
          );
          return student.name;
        }
      }
    }
    return null;
  }

  void _validateNewPassword(String newPassword) {
    if (newPassword.length < 6) {
      throw StateError('New password must be at least 6 characters.');
    }
  }

  // Shared transaction helper: reads the group, applies [transform] to the one
  // matching student, and writes the students list back. Throwing inside
  // [transform] aborts the transaction, which is how validation is enforced.
  Future<void> _updateStudentInGroup({
    required String groupId,
    required String studentId,
    required StudentAccount Function(StudentAccount current) transform,
  }) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) throw StateError('Group not found.');

      final group = CapstoneGroup.fromSnapshot(groupSnapshot);
      if (!group.students.any((student) => student.id == studentId)) {
        throw StateError('Student account not found.');
      }

      final updatedStudents = [
        for (final item in group.students)
          item.id == studentId ? transform(item) : item,
      ];

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
  StudentAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.studentId,
    required this.password,
    String? tempPassword,
    this.mustChangePassword = false,
    this.resetRequested = false,
  }) : tempPassword = tempPassword ?? password;

  factory StudentAccount.fromMap(Map<dynamic, dynamic> map) {
    final password = map['password'] as String? ?? '';
    return StudentAccount(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      studentId: map['studentId'] as String? ?? '',
      password: password,
      // Older records have no separate temp password; fall back to whatever
      // password is stored so the admin still sees something to share.
      tempPassword: map['tempPassword'] as String? ?? password,
      mustChangePassword: map['mustChangePassword'] as bool? ?? false,
      resetRequested: map['resetRequested'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String email;
  final String studentId;

  // The real, current login password. This is intentionally NOT surfaced to
  // the admin once a student changes it - admins only ever see [tempPassword].
  final String password;

  // The last temporary password the admin generated (at registration or on a
  // reset). This is the only credential shown on the admin dashboard.
  final String tempPassword;

  // True while the account is still on an admin-issued temp password. When
  // true the student is forced to set their own password after logging in.
  final bool mustChangePassword;

  // True when the student used "Forgot password" and is waiting on the admin.
  // Drives the notification icon next to the student on the admin dashboard.
  final bool resetRequested;

  StudentAccount copyWith({
    String? password,
    String? tempPassword,
    bool? mustChangePassword,
    bool? resetRequested,
  }) {
    return StudentAccount(
      id: id,
      name: name,
      email: email,
      studentId: studentId,
      password: password ?? this.password,
      tempPassword: tempPassword ?? this.tempPassword,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      resetRequested: resetRequested ?? this.resetRequested,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'studentId': studentId,
      'password': password,
      'tempPassword': tempPassword,
      'mustChangePassword': mustChangePassword,
      'resetRequested': resetRequested,
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
