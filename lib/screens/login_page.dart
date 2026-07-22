import 'package:appstone/app_colors.dart';
import 'package:appstone/screens/admin_portal_page.dart';
import 'package:appstone/screens/auth_gate.dart';
import 'package:appstone/screens/dashboard_screen.dart';
import 'package:appstone/services/admin_repository.dart';
import 'package:appstone/services/functions_service.dart';
import 'package:appstone/widgets/appstone_logo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:shared_preferences/shared_preferences.dart';

// Prefs keys for the "remember me" convenience: whether to remember, and the
// last username/email typed. The PASSWORD is never stored here - the browser's
// own password manager handles that securely via autofill.
const _rememberMeKey = 'loginRememberMe';
const _rememberedUserKey = 'loginRememberedUser';

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
  // Separate from _isLoading so sending a reset link doesn't make the Sign In
  // button read "Signing in...".
  bool _sendingReset = false;
  bool _hidePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    final error = widget.initialError;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMessage(error));
    }
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberMeKey) ?? true;
    final savedUser = prefs.getString(_rememberedUserKey);
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember && savedUser != null && savedUser.isNotEmpty) {
        _usernameController.text = savedUser;
      }
    });
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
              child: AutofillGroup(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppstoneLogo(size: 80),
                  const SizedBox(height: 12),
                  const Text(
                    'Appstone',
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
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
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
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!_isLoading) _signIn();
                    },
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? true),
                      ),
                      const Expanded(child: Text('Remember me')),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                    onPressed: (_isLoading || _sendingReset)
                        ? null
                        : _showForgotPasswordDialog,
                    child: Text(
                      _sendingReset ? 'Sending link…' : 'Forgot password?',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ),
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

      // Remember the username + let the browser offer to save the password.
      await _rememberLogin(identifier);

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
              'Enter your Student ID or email and we will send a link to set a '
              'new password. Students can also ask their admin to reset it.',
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

    setState(() => _sendingReset = true);
    try {
      // Self-serve reset for students and admins: emails a reset link via Brevo
      // through our Cloud Function. Kept generic so it never reveals whether an
      // account exists.
      await FunctionsService().sendPasswordResetEmail(value);
      if (!mounted) return;
      _showMessage('If an account matches that, a reset link has been emailed.');
    } catch (_) {
      if (mounted) {
        _showMessage('Could not send the request. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  // Saves the username (never the password) for next time, and asks the browser
  // to save the just-used password through its own password manager.
  Future<void> _rememberLogin(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(_rememberedUserKey, identifier);
    } else {
      await prefs.remove(_rememberedUserKey);
    }
    TextInput.finishAutofillContext();
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
