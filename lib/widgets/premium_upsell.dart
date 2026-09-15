import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_motion_widgets.dart';

/// What a premium group unlocks. Mirrors the `requiresPremium` flags on the
/// dashboard features and the `PremiumGuard` routes, so the list a student is
/// shown is the list the app actually enforces.
const List<({IconData icon, String title, String body})> premiumFeatures =
    <({IconData icon, String title, String body})>[
  (
    icon: Icons.shield_rounded,
    title: 'Defense Practice',
    body:
        'Simulated title, oral and final defense with a timed panel, voice '
        'answers, and AI follow-up questions.',
  ),
  (
    icon: Icons.insights_rounded,
    title: 'Progress Tracking',
    body:
        'Every practice session and manuscript check saved, scored, and '
        'compared against your previous attempts.',
  ),
  (
    icon: Icons.calendar_month_rounded,
    title: 'AI Workflow Planner',
    body:
        'A phase-by-phase timeline built from your actual paper and your '
        'real deadline, that reschedules as you finish work.',
  ),
  (
    icon: Icons.fact_check_rounded,
    title: 'AI Paper Checker',
    body:
        'Your manuscript graded against the Capstone Manual rubric, plus a '
        'formatting check on margins, spacing and font.',
  ),
];

/// Shown where a premium-only surface would be.
///
/// This replaces two much weaker states: a grey snack bar reading
/// "Avail premium to access this feature." on the dashboard, and a bare
/// centred icon in `PremiumGuard`. Neither told the student what premium
/// actually contains or how to get it.
class PremiumUpsellView extends StatelessWidget {
  const PremiumUpsellView({
    super.key,
    this.feature,
    this.showAppBar = true,
    this.onBack,
  });

  /// The thing they tried to open, named back to them.
  final String? feature;

  final bool showAppBar;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final content = SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppContentWidth.reading),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StaggeredEntrance(
                index: 0,
                child: _Header(feature: feature),
              ),
              AppSpacing.vXl,
              ...StaggeredEntrance.list(<Widget>[
                for (final item in premiumFeatures)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _FeatureRow(
                      icon: item.icon,
                      title: item.title,
                      body: item.body,
                    ),
                  ),
              ]),
              AppSpacing.vLg,
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.infoTint,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: colors.tintBorder(colors.info)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      color: colors.info,
                      size: AppSize.iconMd,
                    ),
                    AppSpacing.hMd,
                    Expanded(
                      child: Text(
                        'Premium is arranged through your capstone '
                        'administrator. Once your group has been verified, it '
                        'unlocks for everyone in the group automatically - '
                        'there is nothing to buy inside the app.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onBack != null) ...<Widget>[
                AppSpacing.vXl,
                FilledButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Appstone'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!showAppBar) return content;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Premium feature'),
        automaticallyImplyLeading: onBack != null,
      ),
      body: content,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.feature});

  final String? feature;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: colors.tintBorder(colors.premium)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.premiumTint,
            colors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: AppSize.tileSm,
                height: AppSize.tileSm,
                decoration: BoxDecoration(
                  color: colors.premium,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: colors.onColor,
                  size: AppSize.iconLg,
                ),
              ),
              AppSpacing.hLg,
              Expanded(
                child: Text(
                  feature == null
                      ? 'This is a premium feature'
                      : '$feature is a premium feature',
                  style: AppTypography.headlineMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vMd,
          Text(
            'Your group is currently on the free version, which includes the '
            'full Capstone Manual and the Title Generator. Premium adds the '
            'practice, planning and checking tools below.',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.tint(colors.premium),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, color: colors.premium, size: AppSize.iconMd),
            ),
            AppSpacing.hLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  AppSpacing.vXs,
                  Text(
                    body,
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
    );
  }
}
