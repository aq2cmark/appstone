import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

/// Motion primitives shared across the app.
///
/// These wrap the handful of patterns that would otherwise be re-implemented
/// on every screen, and they all respect the platform's reduce-motion setting
/// through [AppMotion.reduced].

/// Fades and lifts a widget into place, optionally after a stagger delay.
///
/// Use [StaggeredEntrance.list] to animate a column of cards in sequence.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 16,
    this.duration = AppMotion.standard,
  });

  final Widget child;

  /// Position in the group; drives the stagger delay.
  final int index;

  /// How far the child travels up as it fades in.
  final double offset;

  final Duration duration;

  /// Wraps each of [children] so they arrive one after another.
  static List<Widget> list(List<Widget> children, {double offset = 16}) {
    return <Widget>[
      for (var i = 0; i < children.length; i++)
        StaggeredEntrance(index: i, offset: offset, child: children[i]),
    ];
  }

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (AppMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(AppMotion.staggerDelay(widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - curved.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Scales a widget down slightly while pressed, and up on hover.
///
/// Gives every tappable card the same physical feedback. The dashboard already
/// did this by hand for its feature cards; this generalises it.
class AnimatedPressable extends StatefulWidget {
  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.hoveredScale = 1.0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final double hoveredScale;

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final scale = !enabled
        ? 1.0
        : _pressed
        ? widget.pressedScale
        : (_hovered ? widget.hoveredScale : 1.0);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: AppMotion.respect(context, AppMotion.quick),
          curve: AppMotion.enter,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Cross-fades between children along the shared-axis pattern.
///
/// Used where one region swaps content in place - a setup form becoming a
/// generated plan, a question becoming the next question.
class SharedAxisSwitcher extends StatelessWidget {
  const SharedAxisSwitcher({
    super.key,
    required this.child,
    this.axis = Axis.horizontal,
    this.duration = AppMotion.standard,
  });

  /// Give each distinct state a distinct [Key] or the switcher cannot tell
  /// that anything changed.
  final Widget child;
  final Axis axis;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.respect(context, duration),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: axis == Axis.horizontal
              ? const Offset(0.06, 0)
              : const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: child,
    );
  }
}

/// Animates an integer from its previous value to [value].
///
/// Scores, counts and totals land better when they count up rather than
/// appearing. Uses tabular figures via the caller's style so digits do not
/// jitter mid-count.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.duration = AppMotion.celebratory,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: AppMotion.respect(context, duration),
      curve: AppMotion.enter,
      builder: (context, animated, _) =>
          Text('$prefix${animated.round()}$suffix', style: style),
    );
  }
}

/// A [LinearProgressIndicator] that sweeps to its value instead of snapping.
///
/// Used for the rubric section bars, the workflow completion bar and the
/// defense question tracker. A bar that jumps straight to its final width
/// reads as a static graphic; one that fills draws the eye to the number it is
/// reporting. Honours the reader's reduced-motion setting, in which case it
/// paints the final value immediately.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 8,
    this.borderRadius = AppRadius.smAll,
    this.duration = AppMotion.celebratory,
  });

  /// 0..1. Values outside that range are clamped rather than throwing.
  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;
  final BorderRadius borderRadius;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final reduced = AppMotion.reduced(context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: TweenAnimationBuilder<double>(
        // Tweening from the current value (not from zero) means a bar that
        // advances - the defense question tracker - slides forward by one step
        // rather than rewinding to empty every time a question is answered.
        tween: Tween<double>(begin: reduced ? target : 0, end: target),
        duration: reduced ? Duration.zero : duration,
        curve: AppMotion.enter,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: minHeight,
          color: color,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}
