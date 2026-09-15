import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workflow_plan.dart';
import '../services/admin_repository.dart';
import '../services/functions_service.dart';
import '../services/paper_check_history_service.dart';
import '../services/practice_history_service.dart';
import '../services/session_cache.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/app_shell.dart';
import '../widgets/charts/progress_ring.dart';
import '../widgets/icon_tile.dart';
import '../widgets/offline_notice.dart';
import '../widgets/premium_upsell.dart';
import '../widgets/states/app_states.dart';
import '../widgets/states/skeleton.dart';
import 'login_page.dart';

/// The student's app after login.
///
/// The constructor is unchanged from the pre-overhaul version so `AuthGate`
/// and `LoginPage` keep working untouched; what changed is that it now returns
/// the navigation shell with Home inside it, rather than being a bare page.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.studentName,
    required this.groupName,
    required this.isPremium,
    required this.groupId,
    required this.studentId,
    this.mustChangePassword = false,
  });

  final String studentName;
  final String groupName;
  final bool isPremium;
  final String groupId;
  final String studentId;

  /// True when the student signed in with an admin-issued temporary password.
  /// Home then forces them to set their own before continuing.
  final bool mustChangePassword;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      isPremium: isPremium,
      home: HomeView(
        studentName: studentName,
        groupName: groupName,
        isPremium: isPremium,
        groupId: groupId,
        studentId: studentId,
        mustChangePassword: mustChangePassword,
      ),
    );
  }
}

/// The Home destination.
class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.studentName,
    required this.groupName,
    required this.isPremium,
    required this.groupId,
    required this.studentId,
    this.mustChangePassword = false,
  });

  final String studentName;
  final String groupName;
  final bool isPremium;
  final String groupId;
  final String studentId;
  final bool mustChangePassword;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _promptedForTempChange = false;

  _HomeSummary? _summary;
  bool _loadingSummary = true;

  @override
  void initState() {
    super.initState();
    if (widget.mustChangePassword) {
      // Wait for the first frame so a dialog can be shown over Home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _forceTempPasswordChange();
      });
    }
    _loadSummary();
  }

  /// Reads what the student has already done, so Home can show state instead of
  /// being a static grid of links.
  ///
  /// Everything here is read-only and comes from stores that already exist -
  /// the saved workflow plan in SharedPreferences, and the `paper_checks` and
  /// `practice_sessions` collections. No new data is written and no schema
  /// changes were needed.
  Future<void> _loadSummary() async {
    if (!widget.isPremium) {
      // A free group has no plan, no checks and no sessions by definition;
      // skip three round trips that can only come back empty.
      if (mounted) setState(() => _loadingSummary = false);
      return;
    }

    WorkflowPlan? plan;
    List<PaperCheckRecord> checks = const <PaperCheckRecord>[];
    List<PracticeSessionRecord> sessions = const <PracticeSessionRecord>[];

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(workflowPlanPrefsKey);
      plan = raw == null ? null : WorkflowPlan.decode(raw);
    } catch (_) {
      plan = null;
    }

    // Home is a summary: if a source is unavailable it is simply left out
    // rather than blocking the whole screen behind an error.
    try {
      checks = await PaperCheckHistoryService().fetchChecks(
        groupId: widget.groupId,
        studentId: widget.studentId,
      );
    } catch (_) {
      checks = const <PaperCheckRecord>[];
    }

    try {
      sessions = await PracticeHistoryService().fetchSessions(
        groupId: widget.groupId,
        studentId: widget.studentId,
      );
    } catch (_) {
      sessions = const <PracticeSessionRecord>[];
    }

    if (!mounted) return;
    setState(() {
      _summary = _HomeSummary(
        plan: plan,
        latestCheck: checks.isNotEmpty ? checks.first : null,
        previousCheck: checks.length > 1 ? checks[1] : null,
        latestSession: sessions.isNotEmpty ? sessions.first : null,
        sessionCount: sessions.length,
      );
      _loadingSummary = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: context.pagePadding,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.brandStrong,
                borderRadius: AppRadius.smAll,
              ),
              alignment: Alignment.center,
              child: Text(
                'A',
                style: AppTypography.titleSmall.copyWith(color: colors.onBrandStrong),
              ),
            ),
            AppSpacing.hSm,
            Text(
              'Appstone',
              style: AppTypography.titleLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          AppShellActions(
            studentName: widget.studentName,
            groupName: widget.groupName,
            onChangePassword: showChangePasswordDialog,
            onLogout: _logout,
          ),
          SizedBox(width: context.pagePadding - AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          // Branded via the indicator's own colours. Swapping in the Appstone
          // mark itself would mean replacing RefreshIndicator with a custom
          // sliver - it takes no child widget - which is a bigger change than
          // the polish is worth here.
          color: colors.brand,
          backgroundColor: colors.surface,
          onRefresh: () async {
            setState(() => _loadingSummary = true);
            await _loadSummary();
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              AppSpacing.lg,
              context.pagePadding,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppContentWidth.max),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Above the hero, and only while there is no connection:
                      // the AI modules below will fail without one, so say so
                      // up front rather than after a failed request.
                      const OfflineNotice(
                        message:
                            'The Capstone Manual is saved on this device and '
                            'works as normal. The AI features need a '
                            'connection and will not run until you are back '
                            'online.',
                      ),
                      StaggeredEntrance(index: 0, child: _buildHero()),
                      AppSpacing.vXl,
                      if (widget.isPremium) ...<Widget>[
                        StaggeredEntrance(index: 1, child: _buildProgress()),
                        AppSpacing.vXl,
                      ] else ...<Widget>[
                        StaggeredEntrance(index: 1, child: _buildFreeCard()),
                        AppSpacing.vXl,
                      ],
                      StaggeredEntrance(index: 2, child: _buildFeatures()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _buildHero() {
    final colors = AppColors.of(context);
    final first = widget.studentName.trim().split(RegExp(r'\s+')).first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${_greeting()}, $first',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headlineLarge.copyWith(
            color: colors.textPrimary,
          ),
        ),
        AppSpacing.vSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Chip(label: widget.groupName, icon: Icons.groups_outlined),
            const _Chip(label: 'DCT', icon: Icons.school_outlined),
            const _Chip(label: '2026-2027', icon: Icons.event_outlined),
            if (widget.isPremium)
              _Chip(
                label: 'Premium',
                icon: Icons.workspace_premium_rounded,
                color: colors.premium,
              ),
          ],
        ),
      ],
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // ---------------------------------------------------------------------------
  // Progress band, continue card, workflow preview
  // ---------------------------------------------------------------------------

  /// Crossfades the skeleton into the real band rather than hard-swapping.
  ///
  /// The swap is the most visible moment of the load, and an instant cut is
  /// what makes it read as unfinished. Keyed on the loading flag so the
  /// switcher knows the two states are different children.
  Widget _buildProgress() {
    return AnimatedSwitcher(
      duration: AppMotion.respect(context, AppMotion.standard),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      // The skeleton and the loaded band are different heights; without this
      // the outgoing child is laid out on top of the incoming one and the
      // section jumps.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[...previous, if (current != null) current],
      ),
      child: KeyedSubtree(
        key: ValueKey<bool>(_loadingSummary),
        child: _buildProgressContent(),
      ),
    );
  }

  Widget _buildProgressContent() {
    if (_loadingSummary) {
      return const Skeleton(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SkeletonBox(width: 120, height: 12),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 108, radius: AppRadius.lg),
          ],
        ),
      );
    }

    final summary = _summary;
    if (summary == null || summary.isEmpty) {
      return _EmptyProgressCard(onStart: () => _open('/ai-workflow'));
    }

    final continueTarget = summary.continueTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'YOUR PROGRESS',
          style: AppTypography.eyebrow.copyWith(color: AppColors.of(context).textTertiary),
        ),
        AppSpacing.vMd,
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final tiles = <Widget>[
              _StatTile(
                icon: Icons.calendar_month_rounded,
                accent: AppColors.of(context).moduleWorkflow,
                label: 'Workflow',
                value: summary.workflowValue,
                caption: summary.workflowCaption,
                progress: summary.plan?.progress,
                onTap: () => _open('/ai-workflow'),
              ),
              _StatTile(
                icon: Icons.fact_check_rounded,
                accent: AppColors.of(context).modulePaper,
                label: 'Latest paper check',
                value: summary.paperValue,
                caption: summary.paperCaption,
                delta: summary.paperDelta,
                onTap: () => _open('/paper-checker'),
              ),
              _StatTile(
                icon: Icons.shield_rounded,
                accent: AppColors.of(context).moduleDefense,
                label: 'Last practice',
                value: summary.practiceValue,
                caption: summary.practiceCaption,
                onTap: () => _open('/defense-practice'),
              ),
            ];

            if (!wide) {
              return Column(
                children: <Widget>[
                  for (var i = 0; i < tiles.length; i++) ...<Widget>[
                    if (i > 0) AppSpacing.vMd,
                    tiles[i],
                  ],
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < tiles.length; i++) ...<Widget>[
                    if (i > 0) AppSpacing.hMd,
                    Expanded(child: tiles[i]),
                  ],
                ],
              ),
            );
          },
        ),
        if (summary.plan != null) ...<Widget>[
          AppSpacing.vMd,
          _WorkflowPreview(
            plan: summary.plan!,
            onOpen: () => _open('/ai-workflow'),
          ),
        ],
        if (continueTarget != null) ...<Widget>[
          AppSpacing.vMd,
          _ContinueCard(
            target: continueTarget,
            onTap: () => _open(continueTarget.route),
          ),
        ],
      ],
    );
  }

  Widget _buildFreeCard() {
    final colors = AppColors.of(context);

    return Card(
      child: InkWell(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => PremiumUpsellView(
              onBack: () => Navigator.pop(context),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              IconBadge(
                icon: Icons.workspace_premium_rounded,
                color: colors.premium,
                soft: true,
              ),
              AppSpacing.hLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'You are on the free version',
                      style: AppTypography.titleMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    AppSpacing.vXs,
                    Text(
                      'The Capstone Manual and Title Generator are yours. See '
                      'what premium adds.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hSm,
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Feature grid
  // ---------------------------------------------------------------------------

  Widget _buildFeatures() {
    final colors = AppColors.of(context);

    final features = <_FeatureDef>[
      _FeatureDef(
        title: 'Capstone Manual',
        subtitle: 'Guidelines, rubrics and requirements, searchable',
        icon: Icons.menu_book_rounded,
        color: colors.moduleManual,
        route: '/capstone-manual',
      ),
      _FeatureDef(
        title: 'Title Generator',
        subtitle: 'Build a title from your field, users and technology',
        icon: Icons.lightbulb_rounded,
        color: colors.moduleTitleGen,
        route: '/title-generator',
      ),
      _FeatureDef(
        title: 'Defense Practice',
        subtitle: 'Timed mock panel with voice answers and follow-ups',
        icon: Icons.shield_rounded,
        color: colors.moduleDefense,
        route: '/defense-practice',
        requiresPremium: true,
      ),
      _FeatureDef(
        title: 'AI Workflow Planner',
        subtitle: 'A phase timeline built from your paper and deadline',
        icon: Icons.calendar_month_rounded,
        color: colors.moduleWorkflow,
        route: '/ai-workflow',
        requiresPremium: true,
      ),
      _FeatureDef(
        title: 'AI Paper Checker',
        subtitle: 'Rubric score and formatting check on your manuscript',
        icon: Icons.fact_check_rounded,
        color: colors.modulePaper,
        route: '/paper-checker',
        requiresPremium: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'EXPLORE FEATURES',
          style: AppTypography.eyebrow.copyWith(color: colors.textTertiary),
        ),
        AppSpacing.vMd,
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = AppSpacing.lg;
            const target = 260.0;
            var columns =
                ((constraints.maxWidth + gap) / (target + gap)).floor();
            columns = columns.clamp(1, features.length);
            final width =
                ((constraints.maxWidth - gap * (columns - 1)) / columns)
                    .floorToDouble();

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final feature in features)
                  SizedBox(
                    width: width,
                    child: AppFeatureCard(
                      title: feature.title,
                      subtitle: feature.subtitle,
                      icon: feature.icon,
                      color: feature.color,
                      locked: feature.requiresPremium && !widget.isPremium,
                      onTap: () => _openFeature(feature),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _openFeature(_FeatureDef feature) {
    if (feature.requiresPremium && !widget.isPremium) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PremiumUpsellView(
            feature: feature.title,
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
      return;
    }
    _open(feature.route);
  }

  /// Opens a module.
  ///
  /// Four of the five modules are shell destinations, so they switch tabs -
  /// landing in exactly the same place as tapping the tab, with the navigation
  /// bar still there. Anything else (the Title Generator) is pushed, and gets a
  /// back button automatically because it can pop.
  Future<void> _open(String route) async {
    final destination = AppShellScope.destinationForRoute(route);
    final shell = AppShellScope.of(context);

    if (destination != null && shell != null) {
      shell.go(destination);
      return;
    }

    await Navigator.pushNamed(context, route);
    // Coming back from a feature is the moment the summary is most likely to be
    // stale - a finished practice session or a new paper check just landed.
    if (mounted && widget.isPremium) _loadSummary();
  }

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------

  Future<void> _logout() async {
    // Confirmed first: the account menu sits in the app bar on every screen, so
    // a mis-tap used to end the session outright - and a student who signed in
    // with an admin-issued password may not remember it well enough to get back
    // in. It also clears the saved session, which is what makes the Capstone
    // Manual readable offline, so this is not a cost-free tap.
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Log out?',
      message:
          'You will need your Student ID and password to sign back in, and '
          'Appstone will stop working offline on this device until you do.',
      confirmLabel: 'Log out',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await AdminRepository().signOut();
    await clearStudentSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // Takes no BuildContext parameter on purpose: using this State's own
  // `context` is what lets the `mounted` checks below actually guard the
  // context that gets used after each await.
  Future<void> showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final shouldChange = await showAppDialog<bool>(
      context: context,
      title: 'Change password',
      icon: Icons.lock_reset_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: currentController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          AppSpacing.vMd,
          TextField(
            controller: newController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          AppSpacing.vMd,
          TextField(
            controller: confirmController,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Confirm new password'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    );

    final currentPassword = currentController.text;
    final newPassword = newController.text;
    final confirmPassword = confirmController.text;
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (shouldChange != true) return;
    if (!mounted) return;

    if (newPassword != confirmPassword) {
      showMessageSnack(context, 'New passwords do not match.', isError: true);
      return;
    }
    if (newPassword.length < 6) {
      showMessageSnack(
        context,
        'New password must be at least 6 characters.',
        isError: true,
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw StateError('You are not signed in.');
      }
      // Prove the current password (re-auth) before Firebase lets us change it.
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      if (!mounted) return;
      showMessageSnack(context, 'Password changed.');
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    }
  }

  /// Non-dismissible prompt shown right after logging in with a temp password.
  /// The student cannot reach the rest of the app until they set a real one.
  /// Loops until the change succeeds so they can't skip it with a bad entry.
  Future<void> _forceTempPasswordChange() async {
    if (_promptedForTempChange) return;
    _promptedForTempChange = true;

    var done = false;
    while (!done && mounted) {
      final newController = TextEditingController();
      final confirmController = TextEditingController();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AppDialog(
            title: 'Set your password',
            icon: Icons.key_rounded,
            message: 'You logged in with a temporary password. Create your own '
                'password to continue.',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password (min 6 characters)',
                  ),
                ),
                AppSpacing.vMd,
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm new password'),
                ),
              ],
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Save password'),
              ),
            ],
          ),
        ),
      );

      final newPassword = newController.text;
      final confirmPassword = confirmController.text;
      newController.dispose();
      confirmController.dispose();

      if (!mounted) return;
      if (newPassword != confirmPassword) {
        showMessageSnack(
          context,
          'Passwords do not match. Please try again.',
          isError: true,
        );
        continue;
      }
      if (newPassword.length < 6) {
        showMessageSnack(
          context,
          'Password must be at least 6 characters.',
          isError: true,
        );
        continue;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw StateError('You are not signed in.');
        // They just signed in, so no re-auth is needed to set a new password.
        await user.updatePassword(newPassword);
        // Clear the "must change" flag on their record (server-side, keyed to
        // their own uid).
        await FunctionsService().finishStudentPasswordChange(
          groupId: widget.groupId,
        );
        done = true;
        if (mounted) {
          showMessageSnack(context, 'Password updated. You are all set!');
        }
      } catch (error) {
        if (mounted) showErrorSnack(context, error);
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Summary model
// -----------------------------------------------------------------------------

/// What Home knows about the student's existing work.
class _HomeSummary {
  const _HomeSummary({
    this.plan,
    this.latestCheck,
    this.previousCheck,
    this.latestSession,
    this.sessionCount = 0,
  });

  final WorkflowPlan? plan;
  final PaperCheckRecord? latestCheck;
  final PaperCheckRecord? previousCheck;
  final PracticeSessionRecord? latestSession;
  final int sessionCount;

  bool get isEmpty =>
      plan == null && latestCheck == null && latestSession == null;

  String get workflowValue {
    final current = plan;
    if (current == null) return '-';
    final days = current.daysRemaining();
    if (days < 0) return 'Overdue';
    return '$days';
  }

  String get workflowCaption {
    final current = plan;
    if (current == null) return 'No plan yet';
    final days = current.daysRemaining();
    final phases = '${current.doneCount}/${current.totalCount} phases done';
    if (days < 0) return 'Past deadline - $phases';
    return '${days == 1 ? 'day' : 'days'} left - $phases';
  }

  String get paperValue {
    final check = latestCheck;
    if (check == null) return '-';
    return '${check.totalScore}/${check.maxScore}';
  }

  String get paperCaption {
    final check = latestCheck;
    if (check == null) return 'No checks yet';
    return check.verdict;
  }

  /// Change in score against the previous check, or null when there is nothing
  /// to compare against.
  int? get paperDelta {
    final current = latestCheck;
    final previous = previousCheck;
    if (current == null || previous == null) return null;
    return current.totalScore - previous.totalScore;
  }

  String get practiceValue {
    final session = latestSession;
    if (session == null) return '-';
    return '${session.overallScore}%';
  }

  String get practiceCaption {
    final session = latestSession;
    if (session == null) return 'No sessions yet';
    final plural = sessionCount == 1 ? 'session' : 'sessions';
    return '${session.sessionType} - $sessionCount $plural';
  }

  /// The single most useful thing to pick back up.
  ///
  /// Only ever points at a screen the student can already reach from the
  /// feature grid; it is a shortcut, not a new capability.
  _ContinueTarget? get continueTarget {
    final current = plan;
    if (current != null && current.doneCount < current.totalCount) {
      final schedule = current.schedule();
      final next = schedule
          .where((scheduled) => !scheduled.phase.done)
          .firstOrNull;
      return _ContinueTarget(
        title: next == null
            ? 'Continue your workflow'
            : 'Next up: ${next.phase.name}',
        subtitle: next == null
            ? '${current.doneCount} of ${current.totalCount} phases done'
            : next.isOverdue
                ? 'This phase is behind schedule'
                : 'Scheduled through ${DateFormat('MMM d').format(next.end)}',
        icon: Icons.calendar_month_rounded,
        route: '/ai-workflow',
      );
    }
    if (latestSession != null) {
      return const _ContinueTarget(
        title: 'Run another defense practice',
        subtitle: 'Keep your answers sharp before the real panel',
        icon: Icons.shield_rounded,
        route: '/defense-practice',
      );
    }
    if (latestCheck != null) {
      return const _ContinueTarget(
        title: 'Check your latest draft',
        subtitle: 'See what changed since your last submission',
        icon: Icons.fact_check_rounded,
        route: '/paper-checker',
      );
    }
    return null;
  }
}

class _ContinueTarget {
  const _ContinueTarget({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.caption,
    this.progress,
    this.delta,
    this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String caption;
  final double? progress;
  final int? delta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (progress != null)
                ProgressRing(
                  value: progress!.clamp(0.0, 1.0),
                  size: 44,
                  strokeWidth: 5,
                  color: accent,
                  child: Icon(icon, size: 18, color: accent),
                )
              else
                IconBadge(icon: icon, color: accent, size: 44, soft: true),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    AppSpacing.vXs,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineMedium.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (delta != null && delta != 0) ...<Widget>[
                          AppSpacing.hXs,
                          _DeltaPill(delta: delta!),
                        ],
                      ],
                    ),
                    AppSpacing.vXs,
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final up = delta > 0;
    final tone = up ? colors.success : colors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: colors.tint(tone),
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: tone,
          ),
          Text(
            '${delta.abs()}',
            style: AppTypography.labelSmall.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

/// Read-only preview of the saved workflow plan.
///
/// Built entirely from `WorkflowPlan.schedule()`, which already computes phase
/// windows, day counts and overdue flags - nothing new is calculated here.
class _WorkflowPreview extends StatelessWidget {
  const _WorkflowPreview({required this.plan, required this.onOpen});

  final WorkflowPlan plan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final schedule = plan.schedule();
    if (schedule.isEmpty) return const SizedBox.shrink();

    final totalDays = schedule.fold<int>(0, (sum, s) => sum + s.days);
    final onTrack = plan.isOnTrack();

    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Capstone timeline',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  AppSpacing.hSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors
                          .tint(onTrack ? colors.success : colors.warning),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Text(
                      onTrack ? 'On track' : 'Behind schedule',
                      style: AppTypography.labelSmall.copyWith(
                        color: onTrack ? colors.success : colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.vMd,
              // Each phase gets a slice of the bar proportional to its scheduled
              // days, so the shape of the bar is the shape of the plan.
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: <Widget>[
                      for (final scheduled in schedule)
                        Expanded(
                          flex: totalDays == 0 ? 1 : scheduled.days.clamp(1, 9999),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: ColoredBox(
                              color: scheduled.phase.done
                                  ? colors.success
                                  : scheduled.isOverdue
                                      ? colors.danger
                                      : colors.tint(colors.moduleWorkflow),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              AppSpacing.vMd,
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  _MetaText(
                    icon: Icons.flag_outlined,
                    text: DateFormat('MMM d, yyyy').format(plan.deadline),
                  ),
                  _MetaText(
                    icon: Icons.timelapse_rounded,
                    text: '${plan.totalCount} phases',
                  ),
                  if (plan.paperName != null)
                    _MetaText(
                      icon: Icons.description_outlined,
                      text: plan.paperName!,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Bounded on purpose: an unbounded Text inside a Row inside a Wrap is
    // exactly the pattern that overflows on the audit log and session history
    // screens when a value runs long.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colors.textTertiary),
          AppSpacing.hXs,
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.target, required this.onTap});

  final _ContinueTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      color: colors.brandSoft,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: colors.tintBorder(colors.brand)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(target.icon, color: colors.brand, size: AppSize.iconLg),
              AppSpacing.hLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CONTINUE WHERE YOU LEFT OFF',
                      style: AppTypography.eyebrow.copyWith(
                        color: colors.brand,
                      ),
                    ),
                    AppSpacing.vXs,
                    Text(
                      target.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      target.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hSm,
              Icon(Icons.arrow_forward_rounded, color: colors.brand),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProgressCard extends StatelessWidget {
  const _EmptyProgressCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            IconBadge(
              icon: Icons.rocket_launch_rounded,
              color: colors.moduleWorkflow,
              soft: true,
            ),
            AppSpacing.hLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Nothing tracked yet',
                    style: AppTypography.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  AppSpacing.vXs,
                  Text(
                    'Build a workflow plan, check a draft, or run a practice '
                    'session and your progress will appear here.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.hSm,
            FilledButton(onPressed: onStart, child: const Text('Start')),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tone = color ?? colors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color == null ? colors.surface : colors.tint(tone),
        borderRadius: AppRadius.pillAll,
        border: Border.all(
          color: color == null ? colors.border : colors.tintBorder(tone),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tone),
          AppSpacing.hXs,
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

class _FeatureDef {
  const _FeatureDef({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.requiresPremium = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool requiresPremium;
}
