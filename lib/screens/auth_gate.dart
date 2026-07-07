import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/admin_repository.dart';
import 'admin_claim_page.dart';
import 'admin_portal_page.dart';
import 'dashboard_screen.dart';
import 'login_page.dart';

const studentIdPrefsKey = 'studentId';
const groupIdPrefsKey = 'groupId';

// Runs once on app startup so a page refresh doesn't force a fresh login.
// Admin sessions are restored by Firebase Auth itself; student sessions are
// restored from a saved student/group id, re-checked against Firestore so a
// removed student or deleted group falls back to the login screen.
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
    // An admin arriving via the "verify your email" link sent from
    // AdminSignupPage takes priority over any restored session: this is a
    // fresh claim attempt, not a normal app open.
    final currentLink = Uri.base.toString();
    if (_repo.isAdminClaimLink(currentLink)) {
      _finish(AdminClaimPage(emailLink: currentLink));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // A restored Firebase session is only an admin if it still matches an
      // active `admins` record, so a deactivated admin is kicked to login.
      try {
        final account = await _repo.resolveAdminAccess(
          email: user.email ?? '',
          uid: user.uid,
        );
        _finish(AdminPortalPage(role: account.role));
      } catch (error) {
        await _repo.signOut();
        // Surface why the restored session was rejected instead of silently
        // bouncing to a blank login screen - this is what made the earlier
        // permission-denied error so hard to diagnose.
        _finish(
          LoginPage(
            initialError: error is StateError ? error.message : error.toString(),
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString(studentIdPrefsKey);
    final groupId = prefs.getString(groupIdPrefsKey);

    if (studentId != null && groupId != null) {
      final group = await _repo.getGroup(groupId);
      StudentAccount? student;
      if (group != null) {
        for (final candidate in group.students) {
          if (candidate.id == studentId) {
            student = candidate;
            break;
          }
        }
      }

      if (group != null && student != null) {
        _finish(
          DashboardScreen(
            studentName: student.name,
            groupName: group.name,
            isPremium: group.isPremium,
            groupId: group.id,
            studentId: student.id,
            // A student who closed the app before changing their temp password
            // is still prompted when their saved session is restored.
            mustChangePassword: student.mustChangePassword,
          ),
        );
        return;
      }

      await prefs.remove(studentIdPrefsKey);
      await prefs.remove(groupIdPrefsKey);
    }

    _finish(const LoginPage());
  }

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
