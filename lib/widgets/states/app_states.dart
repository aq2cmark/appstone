import 'package:flutter/material.dart';

import '../../services/friendly_error.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// The three async surfaces every data-driven screen needs.
///
/// Before this, loading was a bare spinner (19 of them), errors were
/// `error.toString()` in a snackbar, and only 2 of ~20 screens offered a retry.

/// Centred spinner with a line of context, so the user knows what is loading.
///
/// Prefer a skeleton (see `skeleton.dart`) when you know the shape of what is
/// coming. Use this for short, indeterminate waits.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message, this.compact = false});

  /// e.g. 'Loading your sessions...'
  final String? message;

  /// Sits inline in a small area rather than filling the viewport.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: compact ? 22 : 34,
          height: compact ? 22 : 34,
          child: CircularProgressIndicator(
            strokeWidth: compact ? 2.5 : 3,
            color: colors.brand,
          ),
        ),
        if (message != null) ...<Widget>[
          AppSpacing.vLg,
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );

    if (compact) return Center(child: content);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: content,
      ),
    );
  }
}

/// A failure the user can understand and act on.
///
/// Always pass the raw [error]; this widget runs it through
/// [friendlyErrorMessage] so no screen has to remember to.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.error,
    this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline_rounded,
    this.compact = false,
  }) : assert(
          error != null || message != null,
          'Provide either the caught error or an explicit message.',
        );

  /// The caught object. Converted to readable copy automatically.
  final Object? error;

  /// Overrides [error] when the screen already knows exactly what to say.
  final String? message;

  final String title;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  /// Renders as an inline card instead of a full-viewport panel.
  final bool compact;

  String _text() => message ?? friendlyErrorMessage(error!);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.dangerTint,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: colors.tintBorder(colors.danger)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colors.danger, size: AppSize.iconMd),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                _text(),
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (onRetry != null) ...<Widget>[
              AppSpacing.hSm,
              TextButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      );
    }

    return _CenteredMessage(
      icon: icon,
      iconColor: colors.danger,
      iconBackground: colors.dangerTint,
      title: title,
      body: _text(),
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
    );
  }
}

/// "There is nothing here yet, and here is how to change that."
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  /// Module accent, so an empty Paper Checker reads teal and an empty practice
  /// history reads rose. Defaults to a neutral tone.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tone = accent ?? colors.textTertiary;

    return _CenteredMessage(
      icon: icon,
      iconColor: tone,
      iconBackground: colors.tint(tone),
      title: title,
      body: body,
      action: action,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Scrollable so a short landscape phone can still reach the action button -
    // the old _PremiumRequired screen overflowed for exactly this reason.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppContentWidth.form),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: iconColor),
              ),
              AppSpacing.vXl,
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.headlineSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              AppSpacing.vSm,
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (action != null) ...<Widget>[
                AppSpacing.vXl,
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows [error] as a snackbar with readable copy.
///
/// Replaces the `ScaffoldMessenger...Text(error.toString())` pattern that was
/// repeated across the app.
void showErrorSnack(BuildContext context, Object error) {
  showMessageSnack(context, friendlyErrorMessage(error), isError: true);
}

/// Shows a plain message snackbar.
void showMessageSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final colors = AppColors.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: AppSize.iconSm,
              color: isError ? colors.danger : colors.success,
            ),
            AppSpacing.hMd,
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
