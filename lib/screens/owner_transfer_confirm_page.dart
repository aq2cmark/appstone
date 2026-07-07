import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';
import 'admin_portal_page.dart';
import 'login_page.dart';

// Prefs key so this page can recover which owner email requested the
// transfer, letting a same-browser click skip re-entering it.
const ownerTransferEmailPrefsKey = 'ownerTransferEmail';

// Landing page opened from the confirmation link sent by
// AdminManagementPage's "Make Owner" action. Reaching a verified state here
// already proves the visitor currently controls the owner's inbox; the
// actual role swap still waits for an explicit button press so an email
// client's link-preview/scanner opening this URL can't trigger it by itself.
class OwnerTransferConfirmPage extends StatefulWidget {
  const OwnerTransferConfirmPage({super.key, required this.emailLink});

  final String emailLink;

  @override
  State<OwnerTransferConfirmPage> createState() =>
      _OwnerTransferConfirmPageState();
}

class _OwnerTransferConfirmPageState extends State<OwnerTransferConfirmPage> {
  final _repo = AdminRepository();
  final _emailController = TextEditingController();
  bool _loadingStoredEmail = true;
  bool _busy = false;
  String? _error;
  AdminAccount? _target;

  @override
  void initState() {
    super.initState();
    _loadStoredEmail();
  }

  Future<void> _loadStoredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(ownerTransferEmailPrefsKey);
    if (!mounted) return;
    setState(() {
      if (stored != null) _emailController.text = stored;
      _loadingStoredEmail = false;
    });
    if (stored != null) await _verify();
  }

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
        title: const Text('Confirm Ownership Transfer'),
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
                    children: _target == null ? _buildVerifyStep() : _buildConfirmStep(),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildVerifyStep() {
    return [
      const Text(
        'Confirm the owner email you requested this transfer with.',
        style: TextStyle(color: AppColors.textGrey),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Owner email',
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
        onPressed: _busy ? null : _verify,
        child: Text(_busy ? 'Verifying...' : 'Verify'),
      ),
      _backToLoginButton(),
    ];
  }

  List<Widget> _buildConfirmStep() {
    final target = _target!;
    return [
      const Icon(
        Icons.workspace_premium_outlined,
        size: 48,
        color: AppColors.primary,
      ),
      const SizedBox(height: 16),
      Text(
        'Make ${target.name} (${target.email}) the new owner?',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 8),
      const Text(
        'You will move to the Admin role. This takes effect immediately and '
        'is not automatically reversible - you would need the new owner to '
        'transfer it back.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGrey),
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
        onPressed: _busy ? null : _confirm,
        child: Text(_busy ? 'Transferring...' : 'Yes, Transfer Ownership'),
      ),
      _backToLoginButton(),
    ];
  }

  Widget _backToLoginButton() {
    return TextButton(
      onPressed: _busy
          ? null
          : () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            ),
      child: const Text('Back to login'),
    );
  }

  Future<void> _verify() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter the owner email you requested this with.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final target = await _repo.verifyOwnershipTransferLink(
        ownerEmail: email,
        emailLink: widget.emailLink,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ownerTransferEmailPrefsKey, email.toLowerCase());
      if (!mounted) return;
      setState(() => _target = target);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError ? error.message : error.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ownerEmail = _emailController.text.trim();
      await _repo.applyOwnershipTransfer(
        ownerEmail: ownerEmail,
        toEmail: _target!.email,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ownerTransferEmailPrefsKey);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminPortalPage(role: AdminRole.admin),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is StateError ? error.message : error.toString();
      });
    }
  }
}
