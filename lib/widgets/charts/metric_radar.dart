import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';

/// One axis of the radar.
@immutable
class RadarMetric {
  const RadarMetric({required this.label, required this.value});

  /// Short axis label, e.g. 'Clarity'.
  final String label;

  /// 0..100.
  final int value;
}

/// Radar plot of the defense-practice evaluation metrics.
///
/// The capstone paper (B.3.7) promises a "Performance Breakdown Dashboard"
/// showing the evaluation metrics; before the overhaul this was four rows of
/// plain progress bars. The data is unchanged - these are exactly the metrics
/// `DefenseAiService.scoreSession` already returns.
///
/// Note: the paper also lists a *confidence* metric. The AI only ever receives
/// the student's typed or transcribed text, never audio, so it cannot honestly
/// judge vocal confidence and does not score it. That is a documentation error
/// to correct, not a gap to fill with an invented number.
class MetricRadar extends StatelessWidget {
  const MetricRadar({
    super.key,
    required this.metrics,
    this.color,
    this.size = 260,
  }) : assert(metrics.length >= 3, 'A radar needs at least three axes.');

  final List<RadarMetric> metrics;

  /// Defaults to the defense module accent.
  final Color? color;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tone = color ?? colors.moduleDefense;

    return SizedBox(
      height: size,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          radarBackgroundColor: Colors.transparent,
          radarBorderData: BorderSide(color: colors.border),
          gridBorderData: BorderSide(color: colors.divider),
          // The numeric ring labels are noise here - the axis labels and the
          // metric list underneath already carry the values.
          tickBorderData: const BorderSide(color: Colors.transparent),
          ticksTextStyle:
              const TextStyle(color: Colors.transparent, fontSize: 0),
          tickCount: 4,
          titlePositionPercentageOffset: 0.14,
          titleTextStyle: AppTypography.labelSmall.copyWith(
            color: colors.textSecondary,
          ),
          getTitle: (index, angle) => RadarChartTitle(
            text: index < metrics.length ? metrics[index].label : '',
          ),
          dataSets: <RadarDataSet>[
            // A fully transparent 0-100 ring. RadarChartData scales to the
            // largest entry it is given, so without this anchor a session
            // scoring 40/45/50/55 would fill the whole chart and look
            // identical to one scoring 85/90/95/100.
            RadarDataSet(
              fillColor: Colors.transparent,
              borderColor: Colors.transparent,
              entryRadius: 0,
              dataEntries: <RadarEntry>[
                for (var i = 0; i < metrics.length; i++)
                  const RadarEntry(value: 100),
              ],
            ),
            RadarDataSet(
              fillColor: tone.withValues(alpha: colors.isDark ? 0.3 : 0.18),
              borderColor: tone,
              borderWidth: 2,
              entryRadius: 3,
              dataEntries: <RadarEntry>[
                for (final metric in metrics)
                  RadarEntry(value: metric.value.toDouble().clamp(0, 100)),
              ],
            ),
          ],
        ),
        duration: AppMotion.respect(context, AppMotion.celebratory),
        curve: AppMotion.enter,
      ),
    );
  }
}
