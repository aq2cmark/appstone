import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';
import 'admin_portal_page.dart';
import 'admin_signup_page.dart';
import 'login_page.dart';

// Landing page opened from the email link sent by AdminSignupPage. Reaching
// here already proves the visitor controls the invited inbox (Firebase would
// not have let them sign in with the link otherwise); this page only asks for
// a password to finish creating the account.
class AdminClaimPage extends StatefulWidget {
  const AdminClaimPage({super.key, required this.emailLink});

  final String emailLink;

  @override
  State<AdminClaimPage> createState() => _AdminClaimPageState();
}

class _AdminClaimPageState extends State<AdminClaimPage> {
  final _repo = AdminRepository();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loadingStoredEmail = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStoredEmail();
  }

  Future<void> _loadStoredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(adminClaimEmailPrefsKey);
    if (!mounted) return;
    setState(() {
      if (stored != null) _emailController.text = stored;
      _loadingStoredEmail = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Finish Creating Your Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _loadingStoredEmail
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Your email is verified. Set a password to finish '
                        'creating your admin account.',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Invited email',
                          helperText:
                              'Confirm the email you requested this link with.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New password (min 6 characters)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Finishing...' : 'Finish Setup'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                                (route) => false,
                              ),
                        child: const Text('Back to login'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty) {
      setState(() => _error = 'Enter the email you requested this link with.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final account = await _repo.completeAdminClaim(
        email: email,
        emailLink: widget.emailLink,
        password: password,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(adminClaimEmailPrefsKey);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AdminPortalPage(role: account.role)),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _authMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError ? error.message : error.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-action-code':
        return 'This link has expired or was already used. Go back and '
            'request a new one.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return error.message ?? 'Could not finish creating the account.';
    }
  }
}
