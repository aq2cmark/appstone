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

  // One-off fetch of all groups, used by the bulk student import to validate
  // rows and map group names to ids.
  Future<List<CapstoneGroup>> getGroups() async {
    final snapshot = await _firestore
        .collection('groups')
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map(CapstoneGroup.fromSnapshot).toList();
  }

  // Admin accounts are created in Firebase Authentication. Returns the
  // credential so the caller can read the uid and then check authorization
  // against the `admins` collection.
  Future<UserCredential> signInAdmin({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ---- Admin authorization + management -------------------------------------
  //
  // Being able to sign in with Firebase Auth is no longer enough to be an
  // admin. Access is gated on a matching, active document in the `admins`
  // collection (doc id = lower-cased email). This is what makes deactivating an
  // admin instant and lets owners manage who has access from inside the app.

  // Called right after a successful Firebase Auth sign-in. Returns the caller's
  // admin account, or throws when they are not authorized. There is NO
  // auto-bootstrap: the very first owner must be created directly in the
  // Firestore console. (Auto-creating an owner when the collection is empty
  // would let any signed-in user - including a student - become owner if the
  // admins list were ever wiped.)
  Future<AdminAccount> resolveAdminAccess({
    required String email,
    required String uid,
  }) async {
    final lower = email.trim().toLowerCase();
    final ref = _firestore.collection('admins').doc(lower);
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final account = AdminAccount.fromSnapshot(snapshot);
      if (!account.active) {
        throw StateError(
          'Your admin access has been deactivated. Contact an owner.',
        );
      }
      // Link the Auth uid the first time this invited admin signs in.
      if (account.uid != uid) {
        await ref.update({
          'uid': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return account.copyWith(uid: uid);
    }

    throw StateError('This account is not authorized to use the admin portal.');
  }

  // Live list of admins for the owner-only management page.
  Stream<List<AdminAccount>> adminsStream() {
    return _firestore
        .collection('admins')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(AdminAccount.fromSnapshot).toList());
  }

  // Live, newest-first feed of admin actions for the owner-only audit log
  // page. Capped so a long-lived portal never streams an unbounded history.
  Stream<List<AuditLogEntry>> auditLogStream({int limit = 200}) {
    return _firestore
        .collection('audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AuditLogEntry.fromSnapshot).toList());
  }

  // Appends one entry to the append-only `audit_logs` collection describing an
  // admin action, tagged with the signed-in admin who performed it. Audit
  // logging is best-effort: a failure here must never surface to the user or
  // undo the action that already succeeded, so every error is swallowed.
  Future<void> _recordAudit({
    required String action,
    required String description,
  }) async {
    try {
      final actor = _auth.currentUser;
      await _firestore.collection('audit_logs').add({
        'action': action,
        'description': description,
        'actorEmail': actor?.email?.toLowerCase() ?? 'unknown',
        'actorUid': actor?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Intentionally ignored - see the doc comment above.
    }
  }

  // Owner action: invite a new admin by email. They then create their own
  // login through the "invited admin" sign-up screen; this only records that
  // the email is allowed and with what role.
  Future<void> inviteAdmin({
    required String email,
    required String name,
    required AdminRole role,
  }) async {
    final lower = email.trim().toLowerCase();
    if (lower.isEmpty || !lower.contains('@')) {
      throw StateError('Enter a valid email address.');
    }
    final ref = _firestore.collection('admins').doc(lower);
    final existing = await ref.get();
    if (existing.exists) {
      throw StateError('An admin with this email already exists.');
    }
    await ref.set({
      'email': lower,
      'name': name.trim().isEmpty ? lower : name.trim(),
      'role': role.name,
      'active': true,
      'uid': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _recordAudit(
      action: 'admin.invite',
      description: 'Invited ${role.name} $lower',
    );
  }

  // Owner action: turn an admin's access on or off without deleting anything.
  Future<void> setAdminActive({
    required String email,
    required bool active,
  }) async {
    final lower = email.toLowerCase();
    await _firestore.collection('admins').doc(lower).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _recordAudit(
      action: active ? 'admin.reactivate' : 'admin.deactivate',
      description: '${active ? 'Reactivated' : 'Deactivated'} admin $lower',
    );
  }

  // Owner action: remove the admin record entirely (e.g. a pending invite).
  // This does NOT delete their Firebase Auth login - that is a Firebase console
  // action - but with no active `admins` doc they can no longer get in.
  Future<void> deleteAdmin(String email) async {
    final lower = email.toLowerCase();
    await _firestore.collection('admins').doc(lower).delete();
    await _recordAudit(
      action: 'admin.delete',
      description: 'Removed admin record $lower',
    );
  }

  // ---- Owner transfer (exactly one owner may exist at a time) ---------------
  //
  // Promoting someone to owner is sensitive and hard to reverse, so it is
  // never done directly by toggling a role field. The current owner requests
  // a transfer, which emails a Firebase sign-in link to THEIR OWN address (not
  // the new owner's) as a live "prove you still control this inbox right now"
  // check - a session left open or taken over is not enough on its own to
  // hand off ownership. Only after that link is confirmed does the role swap
  // happen, atomically, so the app is never left with zero or two owners.
  // Invites can also never create an owner directly (see AdminManagementPage);
  // this is the only path that produces one.

  // Step 1: record which admin the pending transfer is to and email the
  // OWNER a confirmation link. The target is embedded in the link itself (as
  // a query param) so a later, unrelated transfer request can't get confused
  // with this one if both are outstanding at once.
  Future<void> requestOwnershipTransfer({
    required String ownerEmail,
    required String toEmail,
  }) async {
    final ownerLower = ownerEmail.trim().toLowerCase();
    final toLower = toEmail.trim().toLowerCase();

    final targetSnapshot = await _firestore
        .collection('admins')
        .doc(toLower)
        .get();
    if (!targetSnapshot.exists) {
      throw StateError('That admin record no longer exists.');
    }
    if (!AdminAccount.fromSnapshot(targetSnapshot).active) {
      throw StateError('Reactivate this admin before making them owner.');
    }

    await _firestore.collection('admins').doc(ownerLower).update({
      'pendingOwnerTransferTo': toLower,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _auth.sendSignInLinkToEmail(
      email: ownerLower,
      actionCodeSettings: ActionCodeSettings(
        url: '${Uri.base.origin}?intent=ownerTransfer&to=$toLower',
        handleCodeInApp: true,
      ),
    );
  }

  bool isOwnerTransferLink(String link) {
    return _auth.isSignInWithEmailLink(link) &&
        Uri.parse(link).queryParameters['intent'] == 'ownerTransfer';
  }

  // Step 2a: sign in with the link (the actual proof of live inbox control),
  // then look up who this specific transfer would hand ownership to, so the
  // page can show a final "make X the owner?" confirmation before anything
  // is written. Signs back out and refuses if the link doesn't match a still-
  // pending transfer (e.g. it was already used, or a newer request replaced
  // it).
  Future<AdminAccount> verifyOwnershipTransferLink({
    required String ownerEmail,
    required String emailLink,
  }) async {
    final ownerLower = ownerEmail.trim().toLowerCase();
    await _auth.signInWithEmailLink(email: ownerLower, emailLink: emailLink);

    final toLower = Uri.parse(emailLink).queryParameters['to'];
    final ownerSnapshot = await _firestore
        .collection('admins')
        .doc(ownerLower)
        .get();
    final pendingTo = ownerSnapshot.data()?['pendingOwnerTransferTo'] as String?;

    if (toLower == null || pendingTo == null || pendingTo != toLower) {
      await _auth.signOut();
      throw StateError(
        'This transfer request is no longer valid. Start a new one from the '
        'Admins page.',
      );
    }

    final targetSnapshot = await _firestore
        .collection('admins')
        .doc(toLower)
        .get();
    if (!targetSnapshot.exists) {
      await _auth.signOut();
      throw StateError('That admin record no longer exists.');
    }
    return AdminAccount.fromSnapshot(targetSnapshot);
  }

  // Step 2b: called when the owner presses the final in-app confirm button.
  // Swaps both roles in one atomic batch so there is never a moment with zero
  // or two owners.
  Future<void> applyOwnershipTransfer({
    required String ownerEmail,
    required String toEmail,
  }) async {
    final ownerLower = ownerEmail.trim().toLowerCase();
    final toLower = toEmail.trim().toLowerCase();
    final ownerRef = _firestore.collection('admins').doc(ownerLower);
    final targetRef = _firestore.collection('admins').doc(toLower);

    final batch = _firestore.batch();
    batch.update(ownerRef, {
      'role': AdminRole.admin.name,
      'pendingOwnerTransferTo': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(targetRef, {
      'role': AdminRole.owner.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _recordAudit(
      action: 'admin.transferOwnership',
      description: 'Transferred ownership to $toLower',
    );
  }

  Future<void> signOut() => _auth.signOut();

  // Creates a group document. Students are stored inside the group for now
  // because this prototype is simpler to understand that way.
  Future<void> createGroup(String name) => createGroupReturningId(name);

  // Same as createGroup but returns the new group's id, which the bulk import
  // needs so it can immediately place students into a just-created group.
  Future<String> createGroupReturningId(String name) async {
    final ref = await _firestore.collection('groups').add({
      'name': name,
      'isPremium': false,
      'students': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _recordAudit(
      action: 'group.create',
      description: 'Created group "$name"',
    );
    return ref.id;
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
  Future<void> grantPremium(CapstoneGroup group) async {
    await _firestore.collection('groups').doc(group.id).update({
      'isPremium': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _recordAudit(
      action: 'group.grantPremium',
      description: 'Granted premium to ${group.name}',
    );
  }

  Future<void> deleteGroup(String groupId) async {
    final snapshot = await _firestore.collection('groups').doc(groupId).get();
    final name = snapshot.data()?['name'] as String? ?? groupId;
    await _firestore.collection('groups').doc(groupId).delete();
    await _recordAudit(
      action: 'group.delete',
      description: 'Deleted group "$name"',
    );
  }

  // Fixes a typo in a group's name.
  Future<void> renameGroup({
    required String groupId,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw StateError('Group name cannot be empty.');
    }
    await _firestore.collection('groups').doc(groupId).update({
      'name': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _recordAudit(
      action: 'group.rename',
      description: 'Renamed a group to "$trimmed"',
    );
  }

  // Admin action: fix a typo in a student's name, or move them to a
  // different group entirely. Moving groups means removing them from the old
  // group's embedded student list and adding them to the new one, across two
  // documents, so it runs as one transaction - a failure partway through
  // can't leave the student in neither (or both) group.
  Future<void> editStudent({
    required CapstoneGroup fromGroup,
    required StudentAccount student,
    required String newName,
    required String newGroupId,
  }) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw StateError('Name cannot be empty.');
    }

    if (newGroupId == fromGroup.id) {
      await _updateStudentInGroup(
        groupId: fromGroup.id,
        studentId: student.id,
        transform: (current) => current.copyWith(name: trimmedName),
      );
      await _recordAudit(
        action: 'student.edit',
        description:
            'Renamed ${student.name} to "$trimmedName" in ${fromGroup.name}',
      );
      return;
    }

    var toGroupName = '';
    final fromRef = _firestore.collection('groups').doc(fromGroup.id);
    final toRef = _firestore.collection('groups').doc(newGroupId);

    await _firestore.runTransaction((transaction) async {
      final fromSnapshot = await transaction.get(fromRef);
      final toSnapshot = await transaction.get(toRef);
      if (!fromSnapshot.exists) {
        throw StateError('The student\'s current group no longer exists.');
      }
      if (!toSnapshot.exists) {
        throw StateError('The target group no longer exists.');
      }

      final fromGroupNow = CapstoneGroup.fromSnapshot(fromSnapshot);
      final toGroupNow = CapstoneGroup.fromSnapshot(toSnapshot);
      toGroupName = toGroupNow.name;
      if (!fromGroupNow.students.any((s) => s.id == student.id)) {
        throw StateError('Student account not found.');
      }
      if (toGroupNow.students.length >= 5) {
        throw StateError('${toGroupNow.name} already has 5 members.');
      }

      final movedStudent = student.copyWith(name: trimmedName);
      final remainingFrom = fromGroupNow.students
          .where((s) => s.id != student.id)
          .map((s) => s.toMap())
          .toList();
      final updatedTo = [
        ...toGroupNow.students.map((s) => s.toMap()),
        movedStudent.toMap(),
      ];

      transaction.update(fromRef, {
        'students': remainingFrom,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(toRef, {
        'students': updatedTo,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Keep the login lookup pointing at the student's new group, or they
      // couldn't be found (and couldn't log in) after the move.
      if (student.uid.isNotEmpty) {
        transaction.set(
          _firestore.collection('studentIndex').doc(student.uid),
          {'groupId': newGroupId},
          SetOptions(merge: true),
        );
      }
    });

    await _recordAudit(
      action: 'student.edit',
      description:
          'Moved ${student.name} from ${fromGroup.name} to $toGroupName'
          '${trimmedName == student.name ? '' : ' (renamed to "$trimmedName")'}',
    );
  }

  // ---- Firebase Auth student login helpers ----------------------------------

  // Resolves a login identifier to the email Firebase Auth uses. An email is
  // returned as-is (lower-cased); a Student ID (e.g. STU001) is translated via
  // the public studentIdToEmail lookup. Returns null when a Student ID has no
  // match, so the caller can show "no account found".
  Future<String?> resolveStudentEmail(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('@')) return trimmed.toLowerCase();
    final snapshot = await _firestore
        .collection('studentIdToEmail')
        .doc(trimmed.toUpperCase())
        .get();
    if (!snapshot.exists) return null;
    return snapshot.data()?['email'] as String?;
  }

  // After a student signs in with Firebase Auth, maps their uid to the group +
  // student record the dashboard needs. Returns null if the uid isn't a student
  // (e.g. it's an admin), so the caller can route accordingly.
  Future<StudentLoginResult?> getStudentContextByUid(String uid) async {
    final indexSnap =
        await _firestore.collection('studentIndex').doc(uid).get();
    if (!indexSnap.exists) return null;
    final groupId = indexSnap.data()?['groupId'] as String?;
    if (groupId == null) return null;
    final group = await getGroup(groupId);
    if (group == null) return null;
    for (final student in group.students) {
      if (student.uid == uid) {
        return StudentLoginResult(group: group, student: student);
      }
    }
    return null;
  }

}

// Admin roles. `owner` can manage other admins (invite / deactivate /
// promote); `admin` can only manage students and groups.
enum AdminRole { owner, admin }

// One admin record from the `admins` collection. The doc id is the lower-cased
// email; `uid` is filled in the first time the invited person signs in.
class AdminAccount {
  const AdminAccount({
    required this.email,
    required this.name,
    required this.role,
    required this.active,
    this.uid,
  });

  factory AdminAccount.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AdminAccount(
      email: (data['email'] as String?) ?? snapshot.id,
      name: (data['name'] as String?) ?? snapshot.id,
      role: (data['role'] as String?) == 'owner'
          ? AdminRole.owner
          : AdminRole.admin,
      active: (data['active'] as bool?) ?? true,
      uid: data['uid'] as String?,
    );
  }

  final String email;
  final String name;
  final AdminRole role;
  final bool active;
  final String? uid;

  bool get isOwner => role == AdminRole.owner;
  // True while the invite hasn't been claimed by a sign-up yet.
  bool get isPending => uid == null;

  AdminAccount copyWith({String? uid}) => AdminAccount(
        email: email,
        name: name,
        role: role,
        active: active,
        uid: uid ?? this.uid,
      );
}

// One recorded admin action from the append-only `audit_logs` collection.
// `action` is a stable machine key like 'group.delete' (its prefix drives the
// icon shown in the UI); `description` is the human-readable line.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.description,
    required this.actorEmail,
    required this.createdAt,
  });

  factory AuditLogEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AuditLogEntry(
      id: snapshot.id,
      action: data['action'] as String? ?? '',
      description: data['description'] as String? ?? '',
      actorEmail: data['actorEmail'] as String? ?? 'unknown',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String action;
  final String description;
  final String actorEmail;
  // Null only for the brief moment before the server timestamp resolves.
  final DateTime? createdAt;

  // Broad category from the action prefix ('group', 'student', 'admin'), used
  // to pick the row icon and colour on the audit log page.
  String get category => action.split('.').first;
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
    this.uid = '',
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
      // The student's Firebase Auth uid. Empty only for a legacy record that
      // predates the Auth migration.
      uid: map['uid'] as String? ?? '',
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

  // The student's Firebase Auth uid, used to reset/delete their login and to
  // match them after they sign in. Empty for a legacy, un-migrated record.
  final String uid;

  StudentAccount copyWith({
    String? name,
    String? password,
    String? tempPassword,
    bool? mustChangePassword,
    bool? resetRequested,
  }) {
    return StudentAccount(
      id: id,
      name: name ?? this.name,
      email: email,
      studentId: studentId,
      password: password ?? this.password,
      tempPassword: tempPassword ?? this.tempPassword,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      resetRequested: resetRequested ?? this.resetRequested,
      uid: uid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'studentId': studentId,
      // Real passwords live in Firebase Auth, never Firestore. Only the
      // shareable temp password (cleared once the student sets their own) and
      // the uid are stored here.
      'tempPassword': tempPassword,
      'mustChangePassword': mustChangePassword,
      'resetRequested': resetRequested,
      'uid': uid,
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
