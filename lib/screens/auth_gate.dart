import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_repository.dart';
import '../services/friendly_error.dart';
import '../services/session_cache.dart';
import 'admin_portal_page.dart';
import 'dashboard_screen.dart';
import 'login_page.dart';
import 'owner_transfer_confirm_page.dart';

// The prefs keys moved to services/session_cache.dart, which now owns the whole
// saved-session record. They are re-exported here because eight screens import
// them from this file.
export '../services/session_cache.dart'
    show studentIdPrefsKey, groupIdPrefsKey;

// Runs once on app startup so a page refresh doesn't force a fresh login.
// Admin sessions are restored by Firebase Auth itself; student sessions are
// re-checked against Firestore so a removed student or deleted group falls back
// to the login screen.
//
// Offline behaviour is deliberate. Every Firestore read below can fail simply
// because there is no connection, and none of those failures is a verdict on
// who the account is - so a network error restores the locally cached session
// instead of signing anyone out. That is what lets a student open Appstone with
// no signal and read the Capstone Manual, whose content is compiled into the
// app bundle. Only an answer from the *server* - "not an admin, not a student"
// - ends a session.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _repo = AdminRepository();
  Widget? _resolvedPage;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    // An owner arriving via an ownership-transfer confirmation link takes
    // priority over any restored session: it is a fresh confirmation, not a
    // normal app open.
    final currentLink = Uri.base.toString();
    if (_repo.isOwnerTransferLink(currentLink)) {
      _finish(OwnerTransferConfirmPage(emailLink: currentLink));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Both admins and students now have Firebase Auth sessions. Try admin
      // first; if the account isn't an admin, try to restore it as a student;
      // if it's neither (or a deactivated admin), sign out to the login screen.
      try {
        final account = await _repo.resolveAdminAccess(
          email: user.email ?? '',
          uid: user.uid,
        );
        // Whoever used this browser last, this is an admin now: drop any
        // student session so an offline reopen cannot restore it.
        await clearStudentSession();
        _finish(AdminPortalPage(role: account.role));
        return;
      } on StateError {
        // Not an admin - fall through to the student check.
      } catch (error) {
        if (await _restoredOffline(error, uid: user.uid)) return;
        // A real refusal (deactivated, permission denied): end the session.
        await _repo.signOut();
        _finish(LoginPage(initialError: friendlyErrorMessage(error)));
        return;
      }

      final StudentLoginResult? student;
      try {
        student = await _repo.getStudentContextByUid(user.uid);
      } catch (error) {
        if (await _restoredOffline(error, uid: user.uid)) return;
        _finish(LoginPage(initialError: friendlyErrorMessage(error)));
        return;
      }

      if (student != null) {
        await saveStudentSession(
          studentId: student.student.id,
          groupId: student.group.id,
          studentName: student.student.name,
          groupName: student.group.name,
          isPremium: student.group.isPremium,
          mustChangePassword: student.student.mustChangePassword,
          uid: user.uid,
        );
        _finish(_dashboardFor(student));
        return;
      }

      // The server answered, and this account is neither an admin nor a
      // student. That is a real refusal, so the session ends.
      await _repo.signOut();
      await clearStudentSession();
      _finish(const LoginPage());
      return;
    }

    // No Firebase Auth session. A saved student session may still be restorable
    // - this is the path a pre-Auth-migration login lands on.
    final cached = await loadStudentSession();
    if (cached != null) {
      final CapstoneGroup? group;
      try {
        group = await _repo.getGroup(cached.groupId);
      } catch (error) {
        if (await _restoredOffline(error)) return;
        _finish(LoginPage(initialError: friendlyErrorMessage(error)));
        return;
      }

      StudentAccount? student;
      if (group != null) {
        for (final candidate in group.students) {
          if (candidate.id == cached.studentId) {
            student = candidate;
            break;
          }
        }
      }

      if (group != null && student != null) {
        await saveStudentSession(
          studentId: student.id,
          groupId: group.id,
          studentName: student.name,
          groupName: group.name,
          isPremium: group.isPremium,
          // A student who closed the app before changing their temp password
          // is still prompted when their saved session is restored.
          mustChangePassword: student.mustChangePassword,
        );
        _finish(
          DashboardScreen(
            studentName: student.name,
            groupName: group.name,
            isPremium: group.isPremium,
            groupId: group.id,
            studentId: student.id,
            mustChangePassword: student.mustChangePassword,
          ),
        );
        return;
      }

      await clearStudentSession();
    }

    _finish(const LoginPage());
  }

  /// Opens the cached session when [error] turns out to be a connection
  /// problem. Returns true when it did, so the caller stops.
  ///
  /// Nothing is signed out on this path: offline, the user could not sign back
  /// in, so ending the session would lock them out of content they already
  /// have on the device.
  Future<bool> _restoredOffline(Object error, {String? uid}) async {
    if (!isOfflineError(error)) return false;

    final cached = await loadStudentSession();
    if (cached == null || !cached.belongsTo(uid)) {
      // An admin, a student who has never signed in on this device, or a
      // session belonging to a different account. There is nothing usable
      // offline, but the Firebase session stays intact so reopening with a
      // connection just works.
      _finish(LoginPage(initialError: friendlyErrorMessage(error)));
      return true;
    }

    _finish(
      DashboardScreen(
        studentName: cached.studentName,
        groupName: cached.groupName,
        isPremium: cached.isPremium,
        groupId: cached.groupId,
        studentId: cached.studentId,
        // Never force the temp-password dialog offline: changing it needs
        // Firebase Auth, so the student would be trapped in a dialog they
        // cannot complete. They are prompted again on the next online open.
        mustChangePassword: false,
      ),
    );
    return true;
  }

  Widget _dashboardFor(StudentLoginResult student) => DashboardScreen(
        studentName: student.student.name,
        groupName: student.group.name,
        isPremium: student.group.isPremium,
        groupId: student.group.id,
        studentId: student.student.id,
        mustChangePassword: student.student.mustChangePassword,
      );

  void _finish(Widget page) {
    if (!mounted) return;
    setState(() => _resolvedPage = page);
  }

  @override
  Widget build(BuildContext context) {
    return _resolvedPage ??
        const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
