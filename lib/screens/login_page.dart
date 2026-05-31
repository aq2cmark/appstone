import 'package:appstone/screens/admin_portal_page.dart';
import 'package:appstone/screens/dashboard_page.dart';
import 'package:appstone/services/admin_repository.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.menu_book, color: AppColors.red, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'AppStone',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Dominican College of Tarlac',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _usernameController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email or Student ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _hidePassword = !_hidePassword);
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isLoading ? null : _signIn,
                      child: Text(_isLoading ? 'Signing in...' : 'Sign In'),
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
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Please enter your login details.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (username.contains('@')) {
        final isAdmin = await _tryAdminLogin(username, password);
        if (!mounted) return;
        if (isAdmin) {
          _goTo(const AdminPortalPage());
          return;
        }
      }

      final student = await _repo.signInStudent(
        usernameOrEmail: username,
        password: password,
      );

      if (!mounted) return;
      if (student != null) {
        _goTo(const DashboardPage());
      } else {
        _showMessage('Invalid credentials.');
      }
    } catch (error) {
      _showMessage('Login failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _tryAdminLogin(String email, String password) async {
    try {
      await _repo.signInAdmin(email: email, password: password);
      return true;
    } catch (_) {
      return false;
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

class AppColors {
  static const red = Color(0xFF9E1B1F);
  static const gold = Color(0xFFA77B22);
  static const paper = Color(0xFFF4F1EF);
}
