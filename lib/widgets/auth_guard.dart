import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth_gate.dart';
import '../screens/login_page.dart';
import '../theme/app_colors.dart';
import 'premium_upsell.dart';
import 'states/app_states.dart';

/// Wraps a route so only a signed-in user can open it.
///
/// On Flutter web, named routes are reachable by typing the URL directly
/// (e.g. /#/title-generator), which would otherwise open a feature screen with
/// no login. This guard blocks that: if there is no signed-in user it shows the
/// login page instead of the requested screen.
///
/// It waits for Firebase to finish restoring a persisted session first, so a
/// genuine deep-link on a cold page load isn't wrongly bounced to login.
class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Fast path: already known to be signed in (normal in-app navigation).
    if (FirebaseAuth.instance.currentUser != null) return child;

    // Cold load / deep link: wait for auth state to be determined.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GuardLoading();
        }
        if (snapshot.data == null) return const LoginPage();
        return child;
      },
    );
  }
}

/// Like [AuthGuard], but also requires the signed-in student's group to be
/// premium. Used for premium-only feature routes so they can't be opened by URL
/// by a non-premium (or non-student) account - the home cards already gate
/// premium, but a direct URL bypassed that.
class PremiumGuard extends StatelessWidget {
  const PremiumGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return _PremiumGate(user: current, child: child);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GuardLoading();
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return _PremiumGate(user: user, child: child);
      },
    );
  }
}

/// Resolves the group's premium flag, then either shows the feature or the
/// upsell.
///
/// Stateful so a failed lookup can be retried. That matters: the previous
/// version let a Firestore error fall through as `data != true`, which rendered
/// the paywall - so a student on a flaky connection was told they had to pay for
/// something they had already been granted.
class _PremiumGate extends StatefulWidget {
  const _PremiumGate({required this.user, required this.child});

  final User user;
  final Widget child;

  @override
  State<_PremiumGate> createState() => _PremiumGateState();
}

class _PremiumGateState extends State<_PremiumGate> {
  late Future<bool> _future = _isPremiumStudent(widget.user);

  Future<bool> _isPremiumStudent(User user) async {
    final db = FirebaseFirestore.instance;
    final index = await db.collection('studentIndex').doc(user.uid).get();
    final groupId = index.data()?['groupId'] as String?;
    if (groupId == null) return false; // not a student (e.g. an admin)
    final group = await db.collection('groups').doc(groupId).get();
    return (group.data()?['isPremium'] as bool?) ?? false;
  }

  void _retry() {
    setState(() => _future = _isPremiumStudent(widget.user));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GuardLoading();
        }
        // A lookup failure is a connection problem, not a verdict on their
        // plan - say so, and offer a retry rather than a paywall.
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.of(context).background,
            appBar: AppBar(title: const Text('Appstone')),
            body: AppErrorView(
              error: snapshot.error,
              title: 'Could not check your access',
              onRetry: _retry,
            ),
          );
        }
        if (snapshot.data == true) return widget.child;
        return PremiumUpsellView(
          onBack: () => Navigator.pushReplacement<void, void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const AuthGate()),
          ),
        );
      },
    );
  }
}

class _GuardLoading extends StatelessWidget {
  const _GuardLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: const AppLoading(message: 'Checking your account...'),
    );
  }
}
