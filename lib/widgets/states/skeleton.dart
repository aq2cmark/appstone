import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';

/// Shimmering placeholder blocks shown while real content loads.
///
/// The app previously showed 19 bare [CircularProgressIndicator]s, which tell
/// the user nothing about what is arriving. A skeleton shaped like the real
/// content reads as "this is nearly here" instead of "something is happening".
///
/// Wrap a group of [SkeletonBox]es in a single [Skeleton] so they all pulse on
/// one animation controller rather than one per box.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A user who asked for reduced motion gets flat blocks, not a pulse.
    if (AppMotion.reduced(context)) {
      return _SkeletonScope(progress: null, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          _SkeletonScope(progress: _controller.value, child: child!),
      child: widget.child,
    );
  }
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required this.progress, required super.child});

  /// 0..1 shimmer position, or null when motion is disabled.
  final double? progress;

  static _SkeletonScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonScope>();

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) =>
      oldWidget.progress != progress;
}

/// One placeholder block. Must be inside a [Skeleton] to shimmer; on its own it
/// renders as a flat block, which is a fine degraded state.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  /// A block sized like a line of text.
  const SkeletonBox.text({super.key, this.width, this.height = 14})
      : radius = AppRadius.sm;

  /// A block sized like a solid icon tile.
  const SkeletonBox.tile({super.key, double size = AppSize.tileLg})
      : width = size,
        height = size,
        radius = AppRadius.md;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final progress = _SkeletonScope.maybeOf(context)?.progress;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.skeletonBase,
        borderRadius: BorderRadius.circular(radius),
        gradient: progress == null
            ? null
            : LinearGradient(
                // Sweep the highlight from off-screen left to off-screen right.
                begin: Alignment(-1 - 2 * (1 - progress), 0),
                end: Alignment(1 - 2 * (1 - progress), 0),
                colors: <Color>[
                  colors.skeletonBase,
                  colors.skeletonHighlight,
                  colors.skeletonBase,
                ],
                stops: const <double>[0.35, 0.5, 0.65],
              ),
      ),
    );
  }
}

/// Placeholder shaped like a card with an icon tile, a title and two lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 2, this.showTile = true});

  final int lines;
  final bool showTile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showTile) ...<Widget>[
              const SkeletonBox.tile(size: AppSize.tileSm),
              AppSpacing.vLg,
            ],
            const SkeletonBox(width: 160, height: 18),
            for (var i = 0; i < lines; i++) ...<Widget>[
              AppSpacing.vSm,
              SkeletonBox(width: i.isEven ? double.infinity : 200),
            ],
          ],
        ),
      ),
    );
  }
}

/// A vertical run of [SkeletonCard]s, for list screens that are still loading.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 3,
    this.lines = 2,
    this.showTile = false,
  });

  final int count;
  final int lines;
  final bool showTile;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        children: <Widget>[
          for (var i = 0; i < count; i++) ...<Widget>[
            if (i > 0) AppSpacing.vLg,
            SkeletonCard(lines: lines, showTile: showTile),
          ],
        ],
      ),
    );
  }
}
