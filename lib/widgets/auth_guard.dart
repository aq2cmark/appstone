import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../screens/auth_gate.dart';
import '../screens/login_page.dart';

// Wraps a route so only a signed-in user can open it.
//
// On Flutter web, named routes are reachable by typing the URL directly
// (e.g. /#/title-generator), which would otherwise open a feature screen with
// no login. This guard blocks that: if there is no signed-in user it shows the
// login page instead of the requested screen.
//
// It waits for Firebase to finish restoring a persisted session first, so a
// genuine deep-link on a cold page load isn't wrongly bounced to login.
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

// Like AuthGuard, but also requires the signed-in student's group to be premium.
// Used for premium-only feature routes so they can't be opened by URL by a
// non-premium (or non-student) account - the dashboard buttons already gate
// premium, but a direct URL bypassed that.
class PremiumGuard extends StatelessWidget {
  const PremiumGuard({super.key, required this.child});

  final Widget child;

  Future<bool> _isPremiumStudent(User user) async {
    final db = FirebaseFirestore.instance;
    final index = await db.collection('studentIndex').doc(user.uid).get();
    final groupId = index.data()?['groupId'] as String?;
    if (groupId == null) return false; // not a student (e.g. an admin)
    final group = await db.collection('groups').doc(groupId).get();
    return (group.data()?['isPremium'] as bool?) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return _premiumBuilder(current);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GuardLoading();
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return _premiumBuilder(user);
      },
    );
  }

  Widget _premiumBuilder(User user) {
    return FutureBuilder<bool>(
      future: _isPremiumStudent(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GuardLoading();
        }
        if (snapshot.data == true) return child;
        return const _PremiumRequired();
      },
    );
  }
}

class _GuardLoading extends StatelessWidget {
  const _GuardLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PremiumRequired extends StatelessWidget {
  const _PremiumRequired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Premium Feature')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 64,
                color: AppColors.gold,
              ),
              const SizedBox(height: 16),
              const Text(
                'This is a premium feature',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your group needs a premium plan to use this. Ask your admin to '
                'upgrade your group.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                ),
                child: const Text('Back to app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
