import 'package:flutter/material.dart';

import '../app_colors.dart';

// The Appstone brand mark: a rounded-square tile carrying a capstone "A" - a
// flat-topped apex so the letter also reads as the top stone of a structure.
//
// Drawn with a CustomPainter rather than shipped as an image, for the same
// reason IconBadge is a widget: it stays razor-sharp at any size, needs no asset
// bundle or SVG package, and takes its colours straight from the app palette.
// The geometry is authored in the same 512x512 box as
// assets/branding/appstone_logo.svg, so the widget and the file are identical.
class AppstoneLogo extends StatelessWidget {
  const AppstoneLogo({
    super.key,
    this.size = 80,
    this.tileColor = AppColors.primary,
    this.markColor = Colors.white,
    this.showTile = true,
  });

  final double size;
  // The rounded tile behind the mark. Ignored when [showTile] is false.
  final Color tileColor;
  // Colour of the "A" strokes.
  final Color markColor;
  // When false only the glyph is painted on a transparent background, for
  // placing the mark on an already-coloured surface.
  final bool showTile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AppstoneMarkPainter(
          tileColor: showTile ? tileColor : null,
          markColor: markColor,
        ),
      ),
    );
  }
}

// The Appstone lockup: the mark paired with the "Appstone" wordmark (its first
// "A" picked out in brand maroon), optionally over a small tagline. Mirrors the
// two lockups on the brand sheet - [Axis.vertical] stacks them (for a centred
// hero like the login screen); [Axis.horizontal] sets them side by side.
class AppstoneLockup extends StatelessWidget {
  const AppstoneLockup({
    super.key,
    this.axis = Axis.vertical,
    this.markSize = 80,
    this.wordmarkSize = 28,
    this.tagline,
  });

  final Axis axis;
  final double markSize;
  final double wordmarkSize;
  // Small tracked caption under the wordmark, e.g. 'Capstone Companion'.
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    final wordmark = _AppstoneWordmark(
      size: wordmarkSize,
      tagline: tagline,
      align: vertical ? TextAlign.center : TextAlign.start,
      crossAxis: vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
    );

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppstoneLogo(size: markSize),
          SizedBox(height: markSize * 0.18),
          wordmark,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppstoneLogo(size: markSize),
        SizedBox(width: markSize * 0.28),
        wordmark,
      ],
    );
  }
}

class _AppstoneWordmark extends StatelessWidget {
  const _AppstoneWordmark({
    required this.size,
    required this.align,
    required this.crossAxis,
    this.tagline,
  });

  final double size;
  final String? tagline;
  final TextAlign align;
  final CrossAxisAlignment crossAxis;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxis,
      children: [
        Text.rich(
          TextSpan(
            children: const [
              TextSpan(text: 'A', style: TextStyle(color: AppColors.primary)),
              TextSpan(text: 'ppstone'),
            ],
          ),
          textAlign: align,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -size * 0.02,
            color: AppColors.textDark,
            height: 1.0,
          ),
        ),
        if (tagline != null) ...[
          SizedBox(height: size * 0.26),
          Text(
            tagline!.toUpperCase(),
            textAlign: align,
            style: TextStyle(
              fontSize: size * 0.30,
              fontWeight: FontWeight.w700,
              letterSpacing: size * 0.09,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ],
    );
  }
}

// Paints the Appstone mark into a [size]-square area. Shared by [AppstoneLogo]
// and the launcher-icon generator (test/generate_launcher_icons), so the in-app
// mark and the app icon are drawn from one definition. Pass [tileColor] null to
// paint only the "A" glyph on a transparent ground. Geometry is authored in the
// same 512-unit box as assets/branding/appstone_logo.svg, scaled to fit, so the
// stroke weight and corner radius keep their proportions at every size.
void paintAppstoneMark(
  Canvas canvas,
  Size size, {
  Color? tileColor,
  Color markColor = const Color(0xFFFFFFFF),
}) {
  final s = size.width / 512.0;
  Offset p(double x, double y) => Offset(x * s, y * s);

  if (tileColor != null) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(116 * s)),
      Paint()
        ..color = tileColor
        ..isAntiAlias = true,
    );
  }

  final stroke = Paint()
    ..color = markColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 44 * s
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  // Flat "capstone" apex (236->276) with the two legs, then the crossbar -
  // matches the "M236 132 H276 L360 388 M236 132 L152 388" + "M190 300 H322"
  // paths in the SVG asset.
  final a = Path()
    ..moveTo(p(236, 132).dx, p(236, 132).dy)
    ..lineTo(p(276, 132).dx, p(276, 132).dy)
    ..lineTo(p(360, 388).dx, p(360, 388).dy)
    ..moveTo(p(236, 132).dx, p(236, 132).dy)
    ..lineTo(p(152, 388).dx, p(152, 388).dy);
  canvas.drawPath(a, stroke);
  canvas.drawLine(p(190, 300), p(322, 300), stroke);
}

class _AppstoneMarkPainter extends CustomPainter {
  _AppstoneMarkPainter({required this.tileColor, required this.markColor});

  final Color? tileColor;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    paintAppstoneMark(
      canvas,
      size,
      tileColor: tileColor,
      markColor: markColor,
    );
  }

  @override
  bool shouldRepaint(_AppstoneMarkPainter old) =>
      old.tileColor != tileColor || old.markColor != markColor;
}
