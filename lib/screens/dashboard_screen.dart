import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';
import '../widgets/icon_tile.dart';
import '../widgets/section_header.dart';
import 'auth_gate.dart';
import 'login_page.dart';

// Max width the dashboard content stretches to on a wide desktop before it
// stays centered. Wide enough to use the screen (cards spread across the row
// instead of a narrow column) but capped so it never looks stretched on an
// ultra-wide monitor. The header and body share it so they line up.
const dashboardContentWidth = 1360.0;

// Resting height of a feature card, and how much the hovered card grows in the
// desktop dock layout. Shared by the grid and the card so the row reserves
// enough vertical room for the magnified card.
const _dockBaseHeight = 272.0;
const _hoverPeakScale = 1.16;

// Student dashboard after login.
// It receives the student and group names from LoginPage after credentials pass.
class DashboardScreen extends StatefulWidget {
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
  // True when the student signed in with an admin-issued temporary password.
  // The dashboard then forces them to set their own password before continuing.
  final bool mustChangePassword;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = AdminRepository();
  bool _promptedForTempChange = false;
  // Index of the feature card the mouse is currently over, driving the desktop
  // "dock" magnification. Null when nothing is hovered (and always null on
  // touch devices, which never fire hover events). Kept as a ValueNotifier so a
  // hover only rebuilds the cards that listen to it - not the whole dashboard -
  // which is what keeps the magnify animation smooth.
  final ValueNotifier<int?> _hoveredFeature = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    if (widget.mustChangePassword) {
      // Wait for the first frame so a dialog can be shown over the dashboard.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _forceTempPasswordChange();
      });
    }
  }

  @override
  void dispose() {
    _hoveredFeature.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: dashboardContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPLORE FEATURES',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          buildFeatureGrid(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    return SectionHeader(
      title: widget.studentName,
      maxContentWidth: dashboardContentWidth,
      chips: [
        widget.groupName,
        'DCT',
        '2026-2027',
        if (widget.isPremium) 'Premium',
      ],
      actions: [
        IconButton(
          tooltip: 'Change password',
          onPressed: () => showChangePasswordDialog(context),
          icon: const Icon(Icons.lock_reset, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Logout',
          onPressed: () async {
            await AdminRepository().signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(studentIdPrefsKey);
            await prefs.remove(groupIdPrefsKey);
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          icon: const Icon(Icons.logout, color: Colors.white),
        ),
      ],
    );
  }

  // We aim for a comfortable card width and fit as many columns as the space
  // allows, then size each card to fill its share of the row exactly. When
  // every feature fits on a single row (a wide desktop), we upgrade to an
  // interactive "dock" layout that magnifies the hovered card and shrinks its
  // neighbours by distance. On narrower/touch layouts the cards simply reflow.
  Widget buildFeatureGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 20.0;
        const targetCardWidth = 220.0;
        final maxWidth = constraints.maxWidth;
        // How many ~220px cards fit across (never more than the feature count).
        var columns = ((maxWidth + gap) / (targetCardWidth + gap)).floor();
        columns = columns.clamp(1, _features.length);
        // Divide the row evenly so cards fill the full width with no empty gap
        // on the right. floor keeps rounding from bumping a card to a new row.
        final cardWidth =
            ((maxWidth - gap * (columns - 1)) / columns).floorToDouble();

        // All features on one row -> enable the magnifying dock.
        if (columns >= _features.length) {
          return _buildDock(cardWidth, gap);
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final feature in _features)
              AppFeatureCard(
                title: feature.title,
                subtitle: feature.subtitle,
                icon: feature.icon,
                color: feature.color,
                width: cardWidth,
                height: _dockBaseHeight,
                locked: feature.requiresPremium && !widget.isPremium,
                onTap: () => _openFeature(context, feature),
              ),
          ],
        );
      },
    );
  }

  // The single-row desktop layout. Each card is wrapped in a MouseRegion +
  // AnimatedScale so hovering one pops it out while its neighbours ease down in
  // size. The row is given extra height so the magnified card isn't clipped.
  Widget _buildDock(double cardWidth, double gap) {
    return SizedBox(
      height: _dockBaseHeight * _hoverPeakScale + 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _features.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            _buildDockCard(context, i, cardWidth),
          ],
        ],
      ),
    );
  }

  Widget _buildDockCard(BuildContext context, int index, double cardWidth) {
    final feature = _features[index];
    return MouseRegion(
      onEnter: (_) => _hoveredFeature.value = index,
      onExit: (_) {
        // Guard against a stale exit clearing a newer hover.
        if (_hoveredFeature.value == index) _hoveredFeature.value = null;
      },
      // Only the cards listen to the hovered index, so a hover rebuilds these
      // five lightweight wrappers - never the header or the surrounding list -
      // and AnimatedScale runs the frames on the GPU from there.
      child: ValueListenableBuilder<int?>(
        valueListenable: _hoveredFeature,
        builder: (context, hovered, _) {
          return AnimatedScale(
            scale: _hoverScale(hovered, index),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AppFeatureCard(
              title: feature.title,
              subtitle: feature.subtitle,
              icon: feature.icon,
              color: feature.color,
              width: cardWidth,
              height: _dockBaseHeight,
              elevated: hovered == index,
              locked: feature.requiresPremium && !widget.isPremium,
              onTap: () => _openFeature(context, feature),
            ),
          );
        },
      ),
    );
  }

  // Scale for a card given which one is hovered: the hovered card grows, and
  // each step further away shrinks a little more, so the focused card visibly
  // pops out of the row. 1.0 for every card when nothing is hovered.
  double _hoverScale(int? hovered, int index) {
    if (hovered == null) return 1.0;
    switch ((hovered - index).abs()) {
      case 0:
        return _hoverPeakScale;
      case 1:
        return 0.95;
      case 2:
        return 0.88;
      default:
        return 0.85;
    }
  }

  void _openFeature(BuildContext context, _FeatureDef feature) {
    if (feature.requiresPremium && !widget.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avail premium to access this feature.')),
      );
      return;
    }
    Navigator.pushNamed(context, feature.route);
  }

  Future<void> showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Current password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'New password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Confirm new password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldChange != true) {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
      return;
    }

    final currentPassword = currentController.text;
    final newPassword = newController.text;
    final confirmPassword = confirmController.text;
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (!context.mounted) return;
    if (newPassword != confirmPassword) {
      showMessage(context, 'New passwords do not match.');
      return;
    }

    try {
      await _repo.changeStudentPassword(
        groupId: widget.groupId,
        studentId: widget.studentId,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!context.mounted) return;
      showMessage(context, 'Password changed.');
    } catch (error) {
      if (!context.mounted) return;
      showMessage(context, error.toString());
    }
  }

  // Non-dismissible prompt shown right after logging in with a temp password.
  // The student cannot reach the rest of the app until they set a real one.
  // Loops until the change succeeds so they can't skip it with a bad entry.
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
          child: AlertDialog(
            title: const Text('Set Your Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You logged in with a temporary password. Create your own '
                  'password to continue.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'New password (min 6 characters)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Confirm new password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Save Password'),
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
        showMessage(context, 'Passwords do not match. Please try again.');
        continue;
      }

      try {
        await _repo.completeTempPasswordChange(
          groupId: widget.groupId,
          studentId: widget.studentId,
          newPassword: newPassword,
        );
        done = true;
        if (mounted) showMessage(context, 'Password updated. You are all set!');
      } catch (error) {
        if (mounted) showMessage(context, error.toString());
      }
    }
  }

  void showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

}

// The 5 dashboard features. Each gets a distinct on-brand color so the grid
// reads clearly at a glance instead of repeating the same 2-3 hues.
const _features = [
  _FeatureDef(
    title: 'Capstone Manual',
    subtitle: 'Read guidelines and requirements',
    icon: Icons.menu_book_outlined,
    color: AppColors.primary,
    route: '/capstone-manual',
  ),
  _FeatureDef(
    title: 'Title Generator',
    subtitle: 'AI-powered topic ideas',
    icon: Icons.lightbulb_outline,
    color: AppColors.gold,
    route: '/title-generator',
  ),
  _FeatureDef(
    title: 'Defense Practice',
    subtitle: 'Gamified simulation mode',
    icon: Icons.shield_outlined,
    color: AppColors.primaryDark,
    route: '/defense-practice',
    requiresPremium: true,
  ),
  _FeatureDef(
    title: 'AI Workflow',
    subtitle: 'Plan and track your timeline',
    icon: Icons.calendar_month_outlined,
    color: AppColors.greyDark,
    route: '/ai-workflow',
    requiresPremium: true,
  ),
  _FeatureDef(
    title: 'Paper Checker',
    subtitle: 'Check compliance and format',
    icon: Icons.description_outlined,
    color: AppColors.grey,
    route: '/paper-checker',
    requiresPremium: true,
  ),
];

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
