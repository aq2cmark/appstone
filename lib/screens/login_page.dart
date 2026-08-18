import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/admin_repository.dart';
import '../services/friendly_error.dart';
import '../services/functions_service.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/appstone_logo.dart';
import '../widgets/states/app_states.dart';
import 'admin_portal_page.dart';
import 'auth_gate.dart';
import 'dashboard_screen.dart';

// Prefs keys for the "remember me" convenience: whether to remember, and the
// last username/email typed. The PASSWORD is never stored here - the browser's
// own password manager handles that securely via autofill.
const _rememberMeKey = 'loginRememberMe';
const _rememberedUserKey = 'loginRememberedUser';

/// Shared login screen for both admins and students.
///
/// Admins use Firebase Auth email/password. Students use the generated Student
/// ID or email plus their password.
///
/// On wide windows this is a split layout: a branded panel on the left and the
/// form on the right. On phones the panel collapses to a compact lockup above
/// the form, so one screen serves both without a second implementation.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialError});

  /// Shown once on arrival - used by AuthGate to explain why a restored
  /// session was rejected (e.g. a deactivated admin) instead of silently
  /// landing here with no context.
  final String? initialError;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _repo = AdminRepository();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  // Separate from _isLoading so sending a reset link doesn't make the Sign In
  // button read "Signing in...".
  bool _sendingReset = false;
  bool _hidePassword = true;
  bool _rememberMe = true;

  // Inline field errors. The pre-overhaul screen pushed every one of these to a
  // snack bar, which meant the message could vanish before it was read and
  // never pointed at the field that was actually wrong.
  String? _usernameError;
  String? _passwordError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final error = widget.initialError;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _formError = error);
      });
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
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final split = context.breakpoint.usesTwoColumn;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: split
            ? Row(
                children: <Widget>[
                  const Expanded(flex: 5, child: _BrandPanel()),
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppContentWidth.form,
                          ),
                          child: _buildForm(compact: false),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.pagePadding,
                    vertical: AppSpacing.xxl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppContentWidth.form,
                    ),
                    child: _buildForm(compact: true),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildForm({required bool compact}) {
    final colors = AppColors.of(context);
    // Keeps the entrance stagger in visual order in both layouts, where the
    // compact one has an extra leading element.
    var step = 0;
    int next() => step++;

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (compact) ...<Widget>[
            StaggeredEntrance(
              index: next(),
              child: Column(
                children: <Widget>[
                  const AppstoneLockup(markSize: 68, wordmarkSize: 26),
                  AppSpacing.vSm,
                  Text(
                    'Dominican College of Tarlac, Inc.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vXl,
          ],
          StaggeredEntrance(
            index: next(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sign in',
                  style: AppTypography.headlineLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                AppSpacing.vXs,
                Text(
                  'Use the Student ID or email your capstone administrator '
                  'issued you.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vXl,
          if (_formError != null) ...<Widget>[
            _FormBanner(
              message: _formError!,
              onDismiss: () => setState(() => _formError = null),
            ),
            AppSpacing.vLg,
          ],
          StaggeredEntrance(
            index: next(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _usernameController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  autofillHints: const <String>[
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  onChanged: (_) {
                    if (_usernameError != null) {
                      setState(() => _usernameError = null);
                    }
                  },
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: 'Student ID or email',
                    hintText: 'STU001 or you@dct.edu',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    errorText: _usernameError,
                  ),
                ),
                AppSpacing.vLg,
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: _hidePassword,
                  enabled: !_isLoading,
                  autofillHints: const <String>[AutofillHints.password],
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  onSubmitted: (_) {
                    if (!_isLoading) _signIn();
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    errorText: _passwordError,
                    suffixIcon: IconButton(
                      tooltip:
                          _hidePassword ? 'Show password' : 'Hide password',
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
              ],
            ),
          ),
          AppSpacing.vSm,
          StaggeredEntrance(
            index: next(),
            child: Row(
              children: <Widget>[
                Checkbox(
                  value: _rememberMe,
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _rememberMe = value ?? true),
                ),
                Expanded(
                  child: Text(
                    'Remember me',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: (_isLoading || _sendingReset)
                      ? null
                      : _showForgotPasswordDialog,
                  child: Text(_sendingReset ? 'Sending...' : 'Forgot password?'),
                ),
              ],
            ),
          ),
          AppSpacing.vLg,
          StaggeredEntrance(
            index: next(),
            child: FilledButton(
              onPressed: _isLoading ? null : _signIn,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onBrand,
                          ),
                        ),
                        AppSpacing.hMd,
                        const Text('Signing in...'),
                      ],
                    )
                  : const Text('Sign in'),
            ),
          ),
          AppSpacing.vXl,
          StaggeredEntrance(
            index: next(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: colors.textTertiary,
                ),
                AppSpacing.hXs,
                Flexible(
                  child: Text(
                    'Accounts are created by your administrator.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (compact) ...<Widget>[
            AppSpacing.vMd,
            const Center(child: ThemeToggleButton()),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sign in
  // ---------------------------------------------------------------------------

  Future<void> _signIn() async {
    final identifier = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _usernameError =
          identifier.isEmpty ? 'Enter your Student ID or email.' : null;
      _passwordError = password.isEmpty ? 'Enter your password.' : null;
      _formError = null;
    });
    if (identifier.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Everyone - admins and students - now signs in with Firebase Auth.
      // Admins type their email; students may type their Student ID, which we
      // translate to the email their Auth login uses.
      final email = await _repo.resolveStudentEmail(identifier);
      if (!mounted) return;
      if (email == null) {
        setState(
          () =>
              _usernameError = 'No account found for that Student ID or email.',
        );
        return;
      }

      final UserCredential credential;
      try {
        credential = await _repo.signInAdmin(email: email, password: password);
      } on FirebaseAuthException {
        if (!mounted) return;
        setState(() => _passwordError = 'That password does not match.');
        return;
      }
      final user = credential.user;
      if (user == null) {
        if (!mounted) return;
        setState(() => _formError = 'Invalid Student ID/email or password.');
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
      if (!mounted) return;
      setState(
        () => _formError = 'This account is not authorized to sign in here.',
      );
    } catch (error) {
      if (mounted) setState(() => _formError = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(
      text: _usernameController.text.trim(),
    );

    final value = await showAppDialog<String>(
      context: context,
      title: 'Forgot password',
      icon: Icons.help_outline_rounded,
      message: 'Enter your Student ID or email and we will send a link to set '
          'a new password. You can also ask your administrator to reset it.',
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Student ID or email'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Send link'),
        ),
      ],
    );

    controller.dispose();
    if (value == null || value.isEmpty) return;
    if (!mounted) return;

    setState(() => _sendingReset = true);
    try {
      // Self-serve reset for students and admins: emails a reset link via Brevo
      // through our Cloud Function. Kept generic so it never reveals whether an
      // account exists.
      await FunctionsService().sendPasswordResetEmail(value);
      if (!mounted) return;
      showMessageSnack(
        context,
        'If an account matches that, a reset link has been emailed.',
      );
    } catch (_) {
      if (mounted) {
        showMessageSnack(
          context,
          'Could not send the request. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  /// Saves the username (never the password) for next time, and asks the
  /// browser to save the just-used password through its own password manager.
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
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

/// The branded half of the split desktop layout.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const List<(IconData, String)> _highlights = <(IconData, String)>[
    (Icons.menu_book_rounded, 'The CCS Capstone Manual, searchable'),
    (Icons.lightbulb_rounded, 'Title ideas built from your field and users'),
    (Icons.shield_rounded, 'Timed mock defense with AI follow-up questions'),
    (Icons.fact_check_rounded, 'Manuscript checked against the rubric'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.brandStrong, colors.brand],
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Two soft discs, echoing the corner wash on the home feature cards.
          Positioned(
            top: -90,
            right: -70,
            child: _Disc(
              size: 260,
              color: colors.onBrand.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _Disc(
              size: 320,
              color: colors.onBrand.withValues(alpha: 0.05),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppstoneLogo(
                    size: 76,
                    tileColor: colors.onBrand.withValues(alpha: 0.16),
                    markColor: colors.onBrand,
                  ),
                  AppSpacing.vXl,
                  Text(
                    'Appstone',
                    style: AppTypography.displayMedium.copyWith(
                      color: colors.onBrand,
                    ),
                  ),
                  AppSpacing.vSm,
                  Text(
                    'Capstone guidance for the College of Computer Studies, '
                    'Dominican College of Tarlac, Inc.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: colors.onBrand.withValues(alpha: 0.82),
                    ),
                  ),
                  AppSpacing.vXxl,
                  for (final item in _highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            item.$1,
                            color: colors.onBrand.withValues(alpha: 0.9),
                            size: AppSize.iconSm,
                          ),
                          AppSpacing.hMd,
                          Expanded(
                            child: Text(
                              item.$2,
                              style: AppTypography.bodyMedium.copyWith(
                                color: colors.onBrand.withValues(alpha: 0.82),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: ThemeToggleButton(color: colors.onBrand),
          ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// A dismissible error banner above the fields.
class _FormBanner extends StatelessWidget {
  const _FormBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.dangerTint,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.tintBorder(colors.danger)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color: colors.danger,
            size: AppSize.iconSm,
          ),
          AppSpacing.hMd,
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: colors.danger),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            iconSize: AppSize.iconSm,
            color: colors.danger,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
