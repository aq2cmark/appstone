import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';

/// A circular progress indicator that sweeps to its value and can hold a label
/// in the middle.
///
/// Used for the defense timer, the project-context completeness meter, and
/// workflow phase progress. Drawn with a [CustomPainter] rather than a chart
/// package because it is a single arc - pulling in a dependency for that would
/// be more code, not less.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 8,
    this.color,
    this.trackColor,
    this.child,
    this.animate = true,
    this.duration = AppMotion.celebratory,
  }) : assert(value >= 0 && value <= 1, 'value must be a 0..1 fraction');

  /// 0..1.
  final double value;

  final double size;
  final double strokeWidth;

  /// Defaults to the brand colour.
  final Color? color;
  final Color? trackColor;

  /// Rendered centred inside the ring.
  final Widget? child;

  final bool animate;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tone = color ?? colors.brand;
    final track = trackColor ?? colors.surfaceSunken;

    Widget paint(double v) => CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            value: v,
            color: tone,
            trackColor: track,
            strokeWidth: strokeWidth,
          ),
          child: SizedBox.square(
            dimension: size,
            child: child == null ? null : Center(child: child),
          ),
        );

    if (!animate || AppMotion.reduced(context)) return paint(value);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: AppMotion.enter,
      builder: (context, animated, _) => paint(animated),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Start at 12 o'clock and sweep clockwise, which is how people read a dial.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
