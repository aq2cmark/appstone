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
