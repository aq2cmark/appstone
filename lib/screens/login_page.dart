import 'package:appstone/app_colors.dart';
import 'package:appstone/screens/admin_portal_page.dart';
import 'package:appstone/screens/auth_gate.dart';
import 'package:appstone/screens/dashboard_screen.dart';
import 'package:appstone/services/admin_repository.dart';
import 'package:appstone/services/functions_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Shared login screen for both admins and students.
// Admins use Firebase Auth email/password.
// Students use the generated Student ID or email plus temporary password.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialError});

  // Shown once on arrival - used by AuthGate to explain why a restored
  // session was rejected (e.g. a deactivated admin) instead of silently
  // landing here with no context.
  final String? initialError;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _repo = AdminRepository();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    final error = widget.initialError;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMessage(error));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.menu_book, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'APPSTONE',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Dominican College of Tarlac INC',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Username or Email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _usernameController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Enter your username or email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _hidePassword = !_hidePassword);
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _isLoading ? 'Signing in...' : 'Sign In',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
                    child: const Text('Forgot password?'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    final identifier = _usernameController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showMessage('Please enter your login details.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Everyone - admins and students - now signs in with Firebase Auth.
      // Admins type their email; students may type their Student ID, which we
      // translate to the email their Auth login uses.
      final email = await _repo.resolveStudentEmail(identifier);
      if (!mounted) return;
      if (email == null) {
        _showMessage('No account found for that Student ID or email.');
        return;
      }

      final UserCredential credential;
      try {
        credential = await _repo.signInAdmin(email: email, password: password);
      } on FirebaseAuthException {
        _showMessage('Invalid Student ID/email or password.');
        return;
      }
      final user = credential.user;
      if (user == null) {
        _showMessage('Invalid Student ID/email or password.');
        return;
      }

      // Admin? An active `admins` record routes to the portal.
      try {
        final account = await _repo.resolveAdminAccess(
          email: email,
          uid: user.uid,
        );
        if (!mounted) return;
        _goTo(AdminPortalPage(role: account.role));
        return;
      } on StateError {
        // Not an admin - fall through to the student check.
      }

      // Student? A `studentIndex` record routes to the dashboard.
      final student = await _repo.getStudentContextByUid(user.uid);
      if (!mounted) return;
      if (student != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(studentIdPrefsKey, student.student.id);
        await prefs.setString(groupIdPrefsKey, student.group.id);
        if (!mounted) return;
        _goTo(
          DashboardScreen(
            studentName: student.student.name,
            groupName: student.group.name,
            isPremium: student.group.isPremium,
            groupId: student.group.id,
            studentId: student.student.id,
            // Forces a password change on arrival when they signed in with an
            // admin-issued temp password.
            mustChangePassword: student.student.mustChangePassword,
          ),
        );
        return;
      }

      // Signed in but neither admin nor student - refuse and sign back out.
      await _repo.signOut();
      _showMessage('This account is not authorized to sign in here.');
    } catch (error) {
      _showMessage('Login failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Students: enter your Student ID or email to send a reset request '
              'to your admin. They will generate a new temporary password for '
              'you.\n\nAdmins: enter your email to receive a Firebase reset link.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Email or Student ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (value == null || value.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // First treat it as a student (matches Student ID or student email) and
      // notify the admin. This handles student emails too, which also contain
      // '@', so we can't decide by the '@' sign alone.
      final studentName = await _repo.requestPasswordReset(value);
      if (!mounted) return;
      if (studentName != null) {
        _showMessage(
          'Reset request sent for $studentName. Your admin will give you a '
          'new temporary password.',
        );
        return;
      }

      // Otherwise send a self-serve reset link via Brevo (through our Cloud
      // Function). Works for admins now, and for students once they are on
      // Firebase Auth. Kept generic so it never reveals whether an account
      // exists.
      await FunctionsService().sendPasswordResetEmail(value);
      if (!mounted) return;
      _showMessage('If an account matches that, a reset link has been emailed.');
    } catch (_) {
      if (mounted) {
        _showMessage('Could not send the request. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goTo(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
