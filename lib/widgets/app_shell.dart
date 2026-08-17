import 'package:flutter/material.dart';

import '../screens/capstone_manual_screen.dart';
import '../screens/defense_practice_screen.dart';
import '../screens/session_history_screen.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_controller.dart';
import 'premium_upsell.dart';

/// The student's persistent navigation.
///
/// Before this, the app had no navigation architecture at all: every screen
/// was a `Navigator.push` from the dashboard and the only way back was the
/// system back button. On a desktop that left a 760 px column stranded in the
/// middle of the window with no chrome around it.
///
/// The shell adapts to the window: a bottom [NavigationBar] on phones, an
/// icon [NavigationRail] on tablets and laptops, and an extended rail with
/// labels on large desktops.
///
/// ## Why the destinations keep their own Scaffold
///
/// This widget's [Scaffold] deliberately has **no app bar**. Each destination
/// supplies its own, which means the existing feature screens drop straight in
/// without being rewritten - the outer Scaffold contributes the rail and the
/// bottom bar, the inner one contributes the app bar and body. Nesting is safe
/// here because `ScaffoldMessenger` lives above both, so snack bars raised by
/// an inner screen still display correctly.
enum AppDestination {
  home(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  practice(
    label: 'Practice',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield_rounded,
    requiresPremium: true,
  ),
  progress(
    label: 'Progress',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    requiresPremium: true,
  ),
  manual(
    label: 'Manual',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
  );

  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.requiresPremium = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool requiresPremium;
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.home,
    required this.isPremium,
  });

  /// The Home destination. Passed in rather than constructed here because it
  /// needs the signed-in student's details.
  final Widget home;

  /// Drives whether the premium destinations open or show the upsell.
  final bool isPremium;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// Destinations are built lazily and then kept alive, so switching tabs does
  /// not re-run a screen's Firestore reads or lose its scroll position. Home is
  /// always built; the rest appear the first time they are opened.
  late final List<Widget?> _built = <Widget?>[widget.home, null, null, null];

  Widget _destination(int index) {
    final destination = AppDestination.values[index];

    // A free student sees what they are missing rather than a dead tab.
    if (destination.requiresPremium && !widget.isPremium) {
      return PremiumUpsellView(feature: destination.label);
    }

    return _built[index] ??= switch (destination) {
      AppDestination.home => widget.home,
      AppDestination.practice => const DefensePracticeScreen(),
      AppDestination.progress => const SessionHistoryScreen(),
      AppDestination.manual => const CapstoneManualScreen(),
    };
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final breakpoint = context.breakpoint;

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: <Widget>[
          if (breakpoint.usesRail) ...<Widget>[
            _Rail(
              index: _index,
              extended: breakpoint.usesExtendedRail,
              isPremium: widget.isPremium,
              onSelect: _select,
            ),
            VerticalDivider(width: 1, thickness: 1, color: colors.divider),
          ],
          Expanded(
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                for (var i = 0; i < AppDestination.values.length; i++)
                  // IndexedStack builds every child, so untouched destinations
                  // stay an empty box until they are first selected.
                  if (_built[i] != null ||
                      i == _index ||
                      (AppDestination.values[i].requiresPremium &&
                          !widget.isPremium))
                    _destination(i)
                  else
                    const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: breakpoint.usesBottomNav
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: <Widget>[
                for (final destination in AppDestination.values)
                  NavigationDestination(
                    icon: _DestinationIcon(
                      destination: destination,
                      selected: false,
                      isPremium: widget.isPremium,
                    ),
                    selectedIcon: _DestinationIcon(
                      destination: destination,
                      selected: true,
                      isPremium: widget.isPremium,
                    ),
                    label: destination.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.index,
    required this.extended,
    required this.isPremium,
    required this.onSelect,
  });

  final int index;
  final bool extended;
  final bool isPremium;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onSelect,
      extended: extended,
      minWidth: 76,
      minExtendedWidth: 212,
      labelType:
          extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.xl,
          bottom: AppSpacing.lg,
        ),
        child: _RailBrand(extended: extended),
      ),
      destinations: <NavigationRailDestination>[
        for (final destination in AppDestination.values)
          NavigationRailDestination(
            icon: _DestinationIcon(
              destination: destination,
              selected: false,
              isPremium: isPremium,
            ),
            selectedIcon: _DestinationIcon(
              destination: destination,
              selected: true,
              isPremium: isPremium,
            ),
            label: Text(destination.label),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          ),
      ],
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Icon(
              Icons.school_outlined,
              color: colors.textTertiary,
              size: AppSize.iconSm,
            ),
          ),
        ),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final mark = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colors.brandStrong,
        borderRadius: AppRadius.smAll,
      ),
      alignment: Alignment.center,
      child: Text(
        'A',
        style: AppTypography.titleLarge.copyWith(color: colors.onBrand),
      ),
    );

    if (!extended) return mark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          mark,
          AppSpacing.hMd,
          Expanded(
            child: Text(
              'Appstone',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A destination glyph, badged with a small lock when the student's group is
/// not premium. The destination stays visible on purpose - hiding it would
/// leave free students unaware the feature exists.
class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({
    required this.destination,
    required this.selected,
    required this.isPremium,
  });

  final AppDestination destination;
  final bool selected;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final icon = Icon(selected ? destination.selectedIcon : destination.icon);

    if (!destination.requiresPremium || isPremium) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        icon,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_rounded,
              size: 11,
              color: colors.premium,
            ),
          ),
        ),
      ],
    );
  }
}

/// The account / settings menu shown in every destination's app bar.
///
/// Holds the theme toggle and the actions that used to be bare icon buttons on
/// the dashboard header.
class AppShellActions extends StatelessWidget {
  const AppShellActions({
    super.key,
    required this.onChangePassword,
    required this.onLogout,
    this.studentName,
    this.groupName,
  });

  final VoidCallback onChangePassword;
  final VoidCallback onLogout;
  final String? studentName;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const ThemeToggleButton(),
        PopupMenuButton<String>(
          tooltip: 'Account',
          position: PopupMenuPosition.under,
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: colors.brandSoft,
            child: Text(
              _initials(studentName),
              style: AppTypography.labelSmall.copyWith(color: colors.brand),
            ),
          ),
          onSelected: (value) {
            switch (value) {
              case 'password':
                onChangePassword();
              case 'logout':
                onLogout();
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            if (studentName != null)
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      studentName!,
                      style: AppTypography.titleSmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (groupName != null)
                      Text(
                        groupName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            if (studentName != null) const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'password',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_reset_rounded),
                title: Text('Change password'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'logout',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded, color: colors.danger),
                title: Text(
                  'Log out',
                  style: TextStyle(color: colors.danger),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Switches between light and dark, with the icon crossfading.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      onPressed: () => ThemeController.instance.toggle(context),
      icon: AnimatedSwitcher(
        duration: AppMotion.respect(context, AppMotion.quick),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey<bool>(isDark),
        ),
      ),
    );
  }
}
