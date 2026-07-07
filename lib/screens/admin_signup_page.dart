import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';

// Prefs key so AdminClaimPage (the link-landing step) can recover which email
// requested the link, letting a same-browser click skip re-entering it.
const adminClaimEmailPrefsKey = 'adminClaimEmail';

// Sign-up screen for someone an owner has invited by email. This only ever
// sends a Firebase "sign in with email link" to the invited address - it
// never creates the account directly - so nobody can claim an admin invite
// just by knowing or guessing the email. The invitee finishes creating the
// account by opening that link (handled by AdminClaimPage).
class AdminSignupPage extends StatefulWidget {
  const AdminSignupPage({super.key});

  @override
  State<AdminSignupPage> createState() => _AdminSignupPageState();
}

class _AdminSignupPageState extends State<AdminSignupPage> {
  final _repo = AdminRepository();
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _sentTo;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Create Admin Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _sentTo == null ? _buildForm() : _buildSent(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildForm() {
    return [
      const Text(
        'Use the email an owner invited. If it has not been invited yet, ask '
        'an owner to add you first. We will email you a verification link to '
        'confirm it is really you before you can set a password.',
        style: TextStyle(color: AppColors.textGrey),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Invited email',
          border: OutlineInputBorder(),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, style: const TextStyle(color: AppColors.primary)),
      ],
      const SizedBox(height: 20),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _busy ? null : _sendLink,
        child: Text(_busy ? 'Sending...' : 'Send Verification Link'),
      ),
    ];
  }

  List<Widget> _buildSent() {
    return [
      const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.primary),
      const SizedBox(height: 16),
      Text(
        'We sent a verification link to $_sentTo.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Open it on this device to finish creating your account. If it does '
        'not arrive in a minute or two, check spam.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGrey),
      ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: _busy ? null : _sendLink,
        child: const Text('Resend link'),
      ),
    ];
  }

  Future<void> _sendLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your invited email.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _repo.sendAdminClaimLink(email);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(adminClaimEmailPrefsKey, email.toLowerCase());
      if (!mounted) return;
      setState(() => _sentTo = email);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError ? error.message : error.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
