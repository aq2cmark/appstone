import 'package:cloud_functions/cloud_functions.dart';

// Thin Dart wrapper over the callable Cloud Functions that do privileged work
// server-side: creating/resetting/deleting student logins, inviting admins, and
// self-serve password resets. Each function verifies the caller is a real admin
// before acting, so these powers never live inside the app.
//
// The functions are deployed in us-central1 (see functions/index.js).
class FunctionsService {
  FunctionsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  // Owner-only: create an admin login and email them a "set your password"
  // link via Brevo.
  Future<void> inviteAdmin({required String name, required String email}) {
    return _call('inviteAdmin', {'name': name, 'email': email});
  }

  // Admin: create a student login. Returns the Student ID and the one-time temp
  // password to hand over (never stored in Firestore).
  Future<StudentCreation> createStudent({
    required String name,
    required String email,
    required String groupId,
  }) async {
    final data = await _call('createStudent', {
      'name': name,
      'email': email,
      'groupId': groupId,
    });
    return StudentCreation(
      studentId: data['studentId'] as String? ?? '',
      tempPassword: data['tempPassword'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
    );
  }

  // Admin: reset a student to a fresh temp password (returned to show once).
  Future<String> resetStudentPassword({
    required String uid,
    required String groupId,
  }) async {
    final data = await _call('resetStudentPassword', {
      'uid': uid,
      'groupId': groupId,
    });
    return data['tempPassword'] as String? ?? '';
  }

  // Admin: delete a student's login and records.
  Future<void> deleteStudent({
    required String uid,
    required String groupId,
    required String studentId,
  }) {
    return _call('deleteStudent', {
      'uid': uid,
      'groupId': groupId,
      'studentId': studentId,
    });
  }

  // Student: clear the "must change password" flag on their own record after
  // they set a new password (their uid is taken from the auth token server-side).
  Future<void> finishStudentPasswordChange({required String groupId}) {
    return _call('finishStudentPasswordChange', {'groupId': groupId});
  }

  // Owner-only: request an ownership transfer. Emails the owner a confirmation
  // link via Brevo. [appOrigin] is where the link should land (the app URL).
  Future<void> requestOwnershipTransfer({
    required String toEmail,
    required String appOrigin,
  }) {
    return _call('requestOwnershipTransfer', {
      'toEmail': toEmail,
      'appOrigin': appOrigin,
    });
  }

  // Public: self-serve "forgot password" - emails a reset link via Brevo.
  // Accepts a Student ID or an email. Always succeeds so it never reveals
  // whether an account exists.
  Future<void> sendPasswordResetEmail(String identifier) {
    return _call('sendPasswordResetEmail', {'identifier': identifier});
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      final raw = result.data;
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (error) {
      // Surface the function's friendly message (from its HttpsError) to the UI.
      throw StateError(error.message ?? 'Something went wrong. Please try again.');
    }
  }
}

// What createStudent returns: the credentials the admin needs to hand over.
class StudentCreation {
  const StudentCreation({
    required this.studentId,
    required this.tempPassword,
    required this.uid,
  });

  final String studentId;
  final String tempPassword;
  final String uid;
}
