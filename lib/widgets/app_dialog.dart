import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The app's dialog. **Use this instead of a bare [AlertDialog].**
///
/// Six dialogs in the pre-overhaul app put a `Column(mainAxisSize: min)` of
/// text fields straight into `AlertDialog.content`. That content does not
/// scroll, so every one of them overflowed the moment the on-screen keyboard
/// appeared - which on a phone is *always*, because they are all forms.
///
/// [AppDialog] makes the content scrollable and caps its height against the
/// viewport, so the same dialog works on a 320x568 phone with the keyboard up
/// and on a 4K monitor.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions = const <Widget>[],
    this.icon,
    this.accent,
    this.width = 460,
  });

  final String title;

  /// Body copy shown above [content].
  final String? message;

  /// Form fields, lists, or anything else. Scrolls when it does not fit.
  final Widget? content;

  final List<Widget> actions;

  /// Optional glyph shown beside the title.
  final IconData? icon;

  /// Tone for [icon] and emphasis. Defaults to the brand colour.
  final Color? accent;

  /// Preferred width. Always clamped to the viewport, so this is a maximum and
  /// never forces horizontal overflow the way a fixed `SizedBox(width: 420)`
  /// inside an `AlertDialog` did.
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final media = MediaQuery.of(context);
    final tone = accent ?? colors.brand;

    // AlertDialog reserves 40 of inset padding per side by default; leave room
    // for that plus a little breathing space.
    final availableWidth = media.size.width - 2 * AppSpacing.xl;
    final dialogWidth = width < availableWidth ? width : availableWidth;

    // Leave room for the title, the actions row, and the keyboard.
    final availableHeight =
        media.size.height - media.viewInsets.vertical - 220;
    final maxContentHeight = availableHeight < 160 ? 160.0 : availableHeight;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.tint(tone),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, color: tone, size: AppSize.iconMd),
            ),
            AppSpacing.hMd,
          ],
          Expanded(
            child: Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (message != null)
                  Text(
                    message!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                if (message != null && content != null) AppSpacing.vLg,
                if (content != null) content!,
              ],
            ),
          ),
        ),
      ),
      // Wrap rather than Row: three actions at a large text scale on a narrow
      // phone would otherwise overflow the actions bar.
      actions: <Widget>[
        if (actions.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: actions,
          ),
      ],
    );
  }
}

/// Shows an [AppDialog] and resolves with whatever its actions pop.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  List<Widget> actions = const <Widget>[],
  IconData? icon,
  Color? accent,
  double width = 460,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AppDialog(
      title: title,
      message: message,
      content: content,
      actions: actions,
      icon: icon,
      accent: accent,
      width: width,
    ),
  );
}

/// A yes/no confirmation. Returns true only when the user confirms.
///
/// The app has eight of these (grant premium, delete group, delete student,
/// reset password, deactivate admin, transfer ownership, start over, leave
/// practice); this gives them one consistent shape.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,

  /// Styles the confirm button as destructive and tints the icon red.
  bool destructive = false,
}) async {
  final colors = AppColors.of(context);
  final tone = destructive ? colors.danger : colors.brand;

  final result = await showAppDialog<bool>(
    context: context,
    title: title,
    message: message,
    icon: icon,
    accent: tone,
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(cancelLabel),
      ),
      FilledButton(
        style: destructive
            ? FilledButton.styleFrom(
                backgroundColor: colors.danger,
                foregroundColor: colors.onColor,
              )
            : null,
        onPressed: () => Navigator.pop(context, true),
        child: Text(confirmLabel),
      ),
    ],
  );
  return result ?? false;
}
