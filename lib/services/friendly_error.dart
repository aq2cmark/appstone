import 'dart:async';
import 'dart:io' show SocketException;

// FirebaseException and FirebaseAuthException both arrive through this single
// import - firebase_auth re-exports firebase_core's base types.
import 'package:firebase_auth/firebase_auth.dart';

import 'document_text_extractor.dart';
import 'student_import_service.dart';

/// Turns a thrown object into something a student can actually read.
///
/// Before this existed, roughly twenty screens showed `error.toString()`
/// directly in a snackbar, which meant users saw raw Firebase text like
/// `[cloud_firestore/permission-denied] Missing or insufficient permissions.`
/// That is a stack trace wearing a coat, not an error message.
///
/// The rules, in order:
///
/// 1. Exceptions the app raises deliberately already carry good copy - the
///    services author those messages for humans, so pass them through.
/// 2. Firebase codes get a hand-written sentence each.
/// 3. Anything unrecognised falls back to a neutral line rather than leaking
///    internals.
String friendlyErrorMessage(Object error) {
  // 1. Our own exceptions - these messages are already written for students.
  if (error is DocumentExtractionException) return error.message;
  if (error is ImportException) return error.message;

  // Services use StateError for "this cannot proceed, and here is why" - e.g.
  // 'Log in as a student to see your session history.' or the AI rate-limit
  // copy from aiRateLimitMessage(). Those are intentional and user-facing.
  if (error is StateError) return error.message;

  // 2. Firebase.
  if (error is FirebaseAuthException) return _authMessage(error);
  if (error is FirebaseFunctionsLikeException) {
    return error.friendlyMessage ?? _genericServer;
  }
  if (error is FirebaseException) return _firebaseMessage(error);

  // 3. Transport.
  if (error is TimeoutException) {
    return 'That took too long to respond. Check your connection and try again.';
  }
  if (error is SocketException) return _offline;

  final text = error.toString();
  if (_looksOffline(text)) return _offline;

  return 'Something went wrong. Please try again.';
}

/// True when [error] is a connection problem rather than a refusal.
///
/// The distinction matters at sign-in: a `permission-denied` means this account
/// is not allowed in and should be signed out, while an `unavailable` means we
/// could not ask. Signing someone out on the second one is a trap - they are
/// offline, so they cannot sign back in.
bool isOfflineError(Object error) {
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is FirebaseAuthException) {
    return error.code == 'network-request-failed';
  }
  if (error is FirebaseException) {
    return error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'network-request-failed';
  }
  return _looksOffline(error.toString());
}

const String _offline =
    'You appear to be offline. Check your internet connection and try again.';

const String _genericServer =
    'The server could not complete that request. Please try again.';

bool _looksOffline(String text) {
  final lower = text.toLowerCase();
  return lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('clientexception') ||
      lower.contains('xmlhttprequest');
}

String _authMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'That username or password is not correct.';
    case 'invalid-email':
      return 'That does not look like a valid email address.';
    case 'user-disabled':
      return 'This account has been disabled. Contact your administrator.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a few minutes and try again.';
    case 'requires-recent-login':
      return 'For your security, please log in again before changing this.';
    case 'weak-password':
      return 'That password is too weak. Use at least 6 characters.';
    case 'email-already-in-use':
      return 'An account already exists for that email address.';
    case 'network-request-failed':
      return _offline;
    case 'operation-not-allowed':
      return 'That sign-in method is not enabled. Contact your administrator.';
    default:
      return error.message ?? 'Could not sign you in. Please try again.';
  }
}

String _firebaseMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'You do not have permission to do that.';
    case 'unavailable':
      return 'The server is unreachable right now. Please try again shortly.';
    case 'deadline-exceeded':
      return 'That request timed out. Please try again.';
    case 'not-found':
      return 'We could not find that record. It may have been removed.';
    case 'already-exists':
      return 'That record already exists.';
    case 'resource-exhausted':
      return 'The service is busy right now. Please try again in a moment.';
    case 'unauthenticated':
      return 'Your session has expired. Please log in again.';
    case 'cancelled':
      return 'That request was cancelled.';
    default:
      return error.message ?? _genericServer;
  }
}

/// Marker for callable-function failures that already carry friendly copy.
///
/// `FunctionsService` converts `FirebaseFunctionsException` into a
/// [StateError] carrying the Cloud Function's own `HttpsError` message, so in
/// practice those arrive here as a [StateError] and are passed straight
/// through. This interface exists so a future caller can opt in explicitly
/// without depending on that conversion.
abstract interface class FirebaseFunctionsLikeException implements Exception {
  String? get friendlyMessage;
}
