import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/theme_controller.dart';

/// Switches between the light and dark theme.
///
/// Lives in its own file rather than beside the shell because both the shell
/// and [AppScaffold] need it, and the shell imports the feature screens - which
/// import [AppScaffold]. Keeping it separate avoids that import cycle.
///
/// The icon shows the theme you would switch *to*, which is the convention
/// people already expect from the OS-level control.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.color});

  /// Overrides the icon colour. Used on the login screen's maroon brand panel,
  /// where the surrounding text is on-brand rather than on-surface.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      color: color,
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
