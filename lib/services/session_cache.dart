import 'package:shared_preferences/shared_preferences.dart';

// The signed-in student's own details, kept on the device.
//
// The app already stored `studentId` and `groupId` here; this widens that to
// the handful of fields the dashboard needs to render, for one reason: opening
// Appstone with no connection used to be a dead end. AuthGate resolved a
// restored session by reading `admins` and `studentIndex` from Firestore, and
// with no network those reads throw - which either stranded the user on the
// spinner or, worse, signed them out of an account they then could not sign
// back into.
//
// With these fields cached, a student who has signed in once can reopen the app
// offline and go straight to Home, where the Capstone Manual - whose content is
// compiled into the bundle - is fully readable. Nothing new is written to
// Firestore and no document shape changes; this is a local mirror of values the
// server already returned, refreshed on every successful online resolve.
//
// It is deliberately NOT an authorisation cache. Premium access is still
// checked against Firestore by PremiumGuard on every open, so a stale
// `isPremium` here cannot unlock a paid module.

const studentIdPrefsKey = 'studentId';
const groupIdPrefsKey = 'groupId';

const _studentNameKey = 'sessionStudentName';
const _groupNameKey = 'sessionGroupName';
const _isPremiumKey = 'sessionIsPremium';
const _mustChangePasswordKey = 'sessionMustChangePassword';
const _uidKey = 'sessionUid';

/// Everything `DashboardScreen` needs to build itself without a round trip.
class CachedStudentSession {
  const CachedStudentSession({
    required this.studentId,
    required this.groupId,
    required this.studentName,
    required this.groupName,
    required this.isPremium,
    required this.mustChangePassword,
    this.uid,
  });

  /// The Firebase Auth uid this record was saved for, so a session cached by
  /// one account is never restored for another - an admin signing in on a
  /// shared library machine must not land on the last student's dashboard.
  /// Null on records written before this field existed.
  final String? uid;

  /// True when this record is safe to restore for [currentUid].
  ///
  /// A legacy record (no uid) is allowed through: it predates account
  /// switching being possible on the offline path, and refusing it would sign
  /// out every upgrading student.
  bool belongsTo(String? currentUid) =>
      currentUid == null || uid == null || uid == currentUid;

  final String studentId;
  final String groupId;
  final String studentName;
  final String groupName;
  final bool isPremium;
  final bool mustChangePassword;
}

/// Records the session after a successful sign-in or online restore.
Future<void> saveStudentSession({
  required String studentId,
  required String groupId,
  required String studentName,
  required String groupName,
  required bool isPremium,
  required bool mustChangePassword,
  String? uid,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (uid != null) await prefs.setString(_uidKey, uid);
  await prefs.setString(studentIdPrefsKey, studentId);
  await prefs.setString(groupIdPrefsKey, groupId);
  await prefs.setString(_studentNameKey, studentName);
  await prefs.setString(_groupNameKey, groupName);
  await prefs.setBool(_isPremiumKey, isPremium);
  await prefs.setBool(_mustChangePasswordKey, mustChangePassword);
}

/// The last recorded session, or null if there is none.
///
/// Returns null unless the two identifying fields are both present, so a
/// half-written record from an interrupted sign-in cannot open a session.
Future<CachedStudentSession?> loadStudentSession() async {
  final prefs = await SharedPreferences.getInstance();
  final studentId = prefs.getString(studentIdPrefsKey);
  final groupId = prefs.getString(groupIdPrefsKey);
  if (studentId == null || groupId == null) return null;

  return CachedStudentSession(
    studentId: studentId,
    groupId: groupId,
    // Sessions saved before this cache existed have the ids but not the
    // names. Falling back keeps those students signed in rather than bouncing
    // them to login on the release that ships this.
    studentName: prefs.getString(_studentNameKey) ?? 'Student',
    groupName: prefs.getString(_groupNameKey) ?? 'Your group',
    isPremium: prefs.getBool(_isPremiumKey) ?? false,
    mustChangePassword: prefs.getBool(_mustChangePasswordKey) ?? false,
    uid: prefs.getString(_uidKey),
  );
}

/// Wipes the session. Called on logout and whenever the server says the
/// student or their group no longer exists.
Future<void> clearStudentSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(studentIdPrefsKey);
  await prefs.remove(groupIdPrefsKey);
  await prefs.remove(_studentNameKey);
  await prefs.remove(_groupNameKey);
  await prefs.remove(_isPremiumKey);
  await prefs.remove(_mustChangePasswordKey);
  await prefs.remove(_uidKey);
}
