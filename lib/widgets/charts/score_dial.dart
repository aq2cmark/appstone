import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// The headline score display: a 240-degree gauge that sweeps up to the score.
///
/// This is the app's one genuinely celebratory moment, used on the Defense
/// Results screen and for the Paper Checker's compliance score. The paper
/// promises a "Performance Breakdown Dashboard"; this is what delivers it
/// visually. It reads existing data only - no new metric is invented.
class ScoreDial extends StatelessWidget {
  const ScoreDial({
    super.key,
    required this.score,
    this.maxScore = 100,
    this.size = 200,
    this.label,
    this.color,
    this.animate = true,
  });

  final int score;
  final int maxScore;
  final double size;

  /// Sits under the number, e.g. 'OVERALL' or 'out of 50'.
  final String? label;

  /// Defaults to a band colour derived from the score.
  final Color? color;

  final bool animate;

  /// Score bands, matching how the app already talks about results elsewhere:
  /// the paper checker's verdicts break at 90 / 75 / 50 percent.
  static Color bandColor(AppColors colors, double fraction) {
    if (fraction >= 0.9) return colors.success;
    if (fraction >= 0.75) return colors.modulePaper;
    if (fraction >= 0.5) return colors.warning;
    return colors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fraction = maxScore <= 0 ? 0.0 : (score / maxScore).clamp(0.0, 1.0);
    final tone = color ?? bandColor(colors, fraction);
    final reduced = AppMotion.reduced(context) || !animate;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduced ? fraction : 0, end: fraction),
      duration: reduced ? Duration.zero : AppMotion.celebratory,
      curve: AppMotion.enter,
      builder: (context, animated, _) {
        return SizedBox(
          width: size,
          height: size * 0.78,
          child: CustomPaint(
            painter: _DialPainter(
              value: animated,
              color: tone,
              trackColor: colors.surfaceSunken,
              strokeWidth: size * 0.075,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(height: size * 0.10),
                  Text(
                    '${(animated * maxScore).round()}',
                    style: AppTypography.displayLarge.copyWith(
                      color: colors.textPrimary,
                      fontSize: size * 0.24,
                    ),
                  ),
                  Text(
                    label ?? 'out of $maxScore',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  /// A 240-degree arc, opening downward - the shape people read as a gauge.
  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, radius + strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, track);

    if (value <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle * value.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// One labelled metric with a value bar. Used beneath the dial for the
/// individual AI metrics, and by the paper checker for per-rubric-section
/// scores.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.color,
    this.index = 0,
    this.valueSuffix,
  });

  final String label;
  final num value;
  final num max;
  final Color? color;

  /// Position in the group, used to stagger the fill animation.
  final int index;

  /// e.g. '/30'. Defaults to '/max'.
  final String? valueSuffix;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fraction =
        max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();
    final tone = color ?? ScoreDial.bandColor(colors, fraction);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            AppSpacing.hSm,
            Text(
              '$value${valueSuffix ?? '/$max'}',
              style: AppTypography.numeric.copyWith(color: tone),
            ),
          ],
        ),
        AppSpacing.vSm,
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: fraction),
          duration: AppMotion.respect(
            context,
            AppMotion.slow + AppMotion.staggerDelay(index),
          ),
          curve: AppMotion.enter,
          builder: (context, animated, _) => ClipRRect(
            borderRadius: AppRadius.smAll,
            child: LinearProgressIndicator(
              value: animated,
              minHeight: AppSpacing.sm,
              backgroundColor: colors.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
        ),
      ],
    );
  }
}
