import 'package:flutter/material.dart';

import '../services/defense_ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/charts/metric_radar.dart';
import '../widgets/charts/score_dial.dart';
import 'title_defense_screen.dart';

/// Shown after a defense practice session ends.
///
/// Score comes from `DefenseAiService.scoreSession`, computed once all
/// questions (generic + any AI follow-ups) have been answered.
///
/// This is the one screen where the expressive motion register applies: the
/// dial sweeps up from zero, the radar draws itself, and a strong score earns a
/// single celebratory beat. Everywhere outside defense practice stays calm.
class DefenseResultsScreen extends StatefulWidget {
  const DefenseResultsScreen({
    super.key,
    required this.title,
    required this.questions,
    required this.maxQuestions,
    required this.secondsPerQuestion,
    required this.questionsAnswered,
    required this.score,
  });

  final String title;
  final List<String> questions;
  final int maxQuestions;

  /// Carried through so "Practice again" starts with the same question timer.
  final int secondsPerQuestion;
  final int questionsAnswered;
  final DefenseScore score;

  @override
  State<DefenseResultsScreen> createState() => _DefenseResultsScreenState();
}

class _DefenseResultsScreenState extends State<DefenseResultsScreen> {
  /// A plain-language band for the overall score.
  ///
  /// Derived from the score the AI already returns - no new data is stored, and
  /// nothing about the grading changes. It exists so the number lands as
  /// feedback rather than as a bare integer.
  ({String label, String headline, IconData icon}) get _rank {
    final overall = widget.score.overall;
    if (overall >= 85) {
      return (
        label: 'Panel ready',
        headline: 'Strong session',
        icon: Icons.workspace_premium_rounded,
      );
    }
    if (overall >= 70) {
      return (
        label: 'Nearly there',
        headline: 'Good effort',
        icon: Icons.trending_up_rounded,
      );
    }
    if (overall >= 50) {
      return (
        label: 'Needs work',
        headline: 'Keep practicing',
        icon: Icons.school_rounded,
      );
    }
    return (
      label: 'Early days',
      headline: 'Room to grow',
      icon: Icons.self_improvement_rounded,
    );
  }

  Color get _tone {
    final colors = AppColors.of(context);
    final overall = widget.score.overall;
    if (overall >= 85) return colors.success;
    if (overall >= 70) return colors.moduleDefense;
    if (overall >= 50) return colors.warning;
    return colors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rank = _rank;

    return AppScaffold(
      title: 'Session complete',
      subtitle: widget.title,
      accent: colors.moduleDefense,
      maxContentWidth: AppContentWidth.wide,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StaggeredEntrance(index: 0, child: _buildScoreCard(rank)),
          AppSpacing.vXl,
          // Radar and bars say the same thing two ways: the radar shows the
          // shape of the performance at a glance, the bars give exact numbers.
          StaggeredEntrance(
            index: 1,
            child: AppTwoColumn(
              sideWidth: 320,
              sideFirstWhenStacked: true,
              main: AppSection(
                label: 'Evaluation metrics',
                accent: colors.moduleDefense,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: <Widget>[
                        MetricBar(
                          label: 'Clarity',
                          value: widget.score.clarity,
                          max: 100,
                          color: colors.moduleDefense,
                        ),
                        MetricBar(
                          label: 'Technical accuracy',
                          value: widget.score.technical,
                          max: 100,
                          color: colors.moduleDefense,
                        ),
                        MetricBar(
                          label: 'Completeness',
                          value: widget.score.completeness,
                          max: 100,
                          color: colors.moduleDefense,
                        ),
                        MetricBar(
                          label: 'Presentation',
                          value: widget.score.presentation,
                          max: 100,
                          color: colors.moduleDefense,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              side: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: MetricRadar(
                      size: 240,
                      color: colors.moduleDefense,
                      metrics: <RadarMetric>[
                        RadarMetric(
                          label: 'Clarity',
                          value: widget.score.clarity,
                        ),
                        RadarMetric(
                          label: 'Technical',
                          value: widget.score.technical,
                        ),
                        RadarMetric(
                          label: 'Complete',
                          value: widget.score.completeness,
                        ),
                        RadarMetric(
                          label: 'Delivery',
                          value: widget.score.presentation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.score.insights.trim().isNotEmpty) ...<Widget>[
            AppSpacing.vXl,
            StaggeredEntrance(index: 2, child: _buildInsights()),
          ],
          AppSpacing.vXl,
          StaggeredEntrance(index: 3, child: _buildRubric()),
          AppSpacing.vXl,
          StaggeredEntrance(
            index: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _practiceAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Practice again'),
                ),
                AppSpacing.vMd,
                TextButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('Back to home'),
                ),
              ],
            ),
          ),
          AppSpacing.vLg,
          Text(
            'Practice feedback from the AI panel. It is not an official '
            'evaluation and does not replace your adviser or capstone panel.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(({String label, String headline, IconData icon}) rank) {
    final colors = AppColors.of(context);
    final tone = _tone;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: colors.tintBorder(tone)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.tint(tone), colors.surface],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dial = ScoreDial(
            score: widget.score.overall,
            size: 168,
            color: tone,
            label: 'out of 100',
          );

          final details = Column(
            crossAxisAlignment: constraints.maxWidth < 520
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: <Widget>[
              _RankBadge(label: rank.label, icon: rank.icon, color: tone),
              AppSpacing.vMd,
              Text(
                rank.headline,
                textAlign:
                    constraints.maxWidth < 520 ? TextAlign.center : TextAlign.start,
                style: AppTypography.headlineLarge.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              AppSpacing.vXs,
              Text(
                '${widget.questionsAnswered} of ${widget.maxQuestions} '
                'questions answered in ${widget.title}.',
                textAlign:
                    constraints.maxWidth < 520 ? TextAlign.center : TextAlign.start,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 520) {
            return Column(
              children: <Widget>[dial, AppSpacing.vXl, details],
            );
          }

          return Row(
            children: <Widget>[
              dial,
              AppSpacing.hXl,
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInsights() {
    final colors = AppColors.of(context);

    return AppSection(
      label: 'Panel insights',
      accent: colors.moduleDefense,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.psychology_outlined,
                color: colors.moduleDefense,
                size: AppSize.iconMd,
              ),
              AppSpacing.hLg,
              Expanded(
                child: Text(
                  widget.score.insights.trim(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRubric() {
    final colors = AppColors.of(context);

    const rubric = <(String, String)>[
      (
        'Clarity',
        'How directly the answer addressed the question, without wandering.',
      ),
      (
        'Technical accuracy',
        'Whether the technical claims were correct and specific to your system.',
      ),
      (
        'Completeness',
        'Whether the answer covered what the panel actually asked for.',
      ),
      (
        'Presentation',
        'Structure and confidence of the wording in your written answer.',
      ),
    ];

    return AppSection(
      label: 'How this was graded',
      accent: colors.moduleDefense,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < rubric.length; i++) ...<Widget>[
                if (i > 0) ...<Widget>[
                  AppSpacing.vMd,
                  Divider(height: 1, color: colors.divider),
                  AppSpacing.vMd,
                ],
                Text(
                  rubric[i].$1,
                  style: AppTypography.titleSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                AppSpacing.vXs,
                Text(
                  rubric[i].$2,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _practiceAgain() {
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DefensePracticeSessionScreen(
          title: widget.title,
          questions: widget.questions,
          maxQuestions: widget.maxQuestions,
          secondsPerQuestion: widget.secondsPerQuestion,
        ),
      ),
    );
  }

}

/// The rank pill above the headline.
///
/// Scales in once on arrival - the single celebratory beat allowed on this
/// screen. It is suppressed when the reader has asked for reduced motion.
class _RankBadge extends StatefulWidget {
  const _RankBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  State<_RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<_RankBadge> {
  double _scale = 0.6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _scale = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedScale(
      scale: AppMotion.reduced(context) ? 1 : _scale,
      duration: AppMotion.respect(context, AppMotion.celebratory),
      curve: AppMotion.emphasis,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: colors.tint(widget.color),
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: colors.tintBorder(widget.color)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(widget.icon, size: 15, color: widget.color),
            AppSpacing.hSm,
            Text(
              widget.label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}
