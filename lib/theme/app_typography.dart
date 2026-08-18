import 'package:flutter/material.dart';

/// The Appstone type scale.
///
/// The pre-overhaul codebase had ~147 inline `TextStyle`s spread across 26
/// font sizes with near-duplicates at every step (12/12.5/13/13.5,
/// 14/14.5/15/15.5, 20/21/22, 26/28). This collapses all of it into one scale.
///
/// **Never write an inline `TextStyle(fontSize: ...)` in a screen.** Take a
/// style from `Theme.of(context).textTheme`, or from here. If the style you
/// need is missing, add it to the scale rather than inlining one.
///
/// ## Why `fontVariations`
///
/// Plus Jakarta Sans ships from Google Fonts as a *variable* font - a single
/// 172 KB file with a continuous `wght` axis, rather than five static files.
/// One asset is a meaningful saving in a ~26 MB web build.
///
/// The catch is that `fontWeight` alone does not drive a variable axis
/// reliably across Flutter's platforms; `fontVariations` does. Every style
/// below therefore sets *both*: `fontVariations` for the real weight, and
/// `fontWeight` so any fallback font (and the test font) still renders with
/// roughly the right emphasis.
abstract final class AppTypography {
  /// Declared in pubspec.yaml against `assets/fonts/PlusJakartaSans-Variable.ttf`.
  static const String fontFamily = 'Plus Jakarta Sans';

  /// Fallbacks matter on web, where the bundled font is fetched with the app
  /// bundle - these cover the first paint and any glyph the family lacks.
  static const List<String> fontFamilyFallback = <String>[
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  // ---------------------------------------------------------------------------
  // Weights
  // ---------------------------------------------------------------------------

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  /// Builds a style on the variable axis. Used by every entry in the scale.
  static TextStyle _style({
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
      ],
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ---------------------------------------------------------------------------
  // Display - hero numbers only (score dials, big counters)
  // ---------------------------------------------------------------------------

  static final TextStyle displayLarge =
      _style(size: 40, weight: extraBold, height: 1.1, letterSpacing: -0.8);

  static final TextStyle displayMedium =
      _style(size: 32, weight: bold, height: 1.15, letterSpacing: -0.5);

  // ---------------------------------------------------------------------------
  // Headline - page and hero titles
  // ---------------------------------------------------------------------------

  static final TextStyle headlineLarge =
      _style(size: 26, weight: bold, height: 1.2, letterSpacing: -0.4);

  static final TextStyle headlineMedium =
      _style(size: 22, weight: bold, height: 1.25, letterSpacing: -0.2);

  static final TextStyle headlineSmall =
      _style(size: 19, weight: semiBold, height: 1.3);

  // ---------------------------------------------------------------------------
  // Title - card titles, section headings, list leads
  // ---------------------------------------------------------------------------

  static final TextStyle titleLarge =
      _style(size: 17, weight: semiBold, height: 1.35);

  static final TextStyle titleMedium =
      _style(size: 15, weight: semiBold, height: 1.35);

  static final TextStyle titleSmall =
      _style(size: 13.5, weight: semiBold, height: 1.35);

  // ---------------------------------------------------------------------------
  // Body - running copy
  // ---------------------------------------------------------------------------

  static final TextStyle bodyLarge =
      _style(size: 16, weight: regular, height: 1.5);

  static final TextStyle bodyMedium =
      _style(size: 14.5, weight: regular, height: 1.5);

  static final TextStyle bodySmall =
      _style(size: 13, weight: regular, height: 1.45);

  // ---------------------------------------------------------------------------
  // Label - buttons, chips, tabs, dense metadata
  // ---------------------------------------------------------------------------

  static final TextStyle labelLarge =
      _style(size: 15, weight: semiBold, height: 1.2, letterSpacing: 0.1);

  static final TextStyle labelMedium =
      _style(size: 13, weight: medium, height: 1.2, letterSpacing: 0.1);

  static final TextStyle labelSmall =
      _style(size: 11.5, weight: medium, height: 1.2, letterSpacing: 0.2);

  /// Small uppercase section marker - the "EXPLORE FEATURES" / "N RESULTS"
  /// pattern that was re-typed inline on three screens.
  static final TextStyle eyebrow =
      _style(size: 11.5, weight: bold, height: 1.2, letterSpacing: 1.1);

  /// Tabular figures for scores, counts and timers, so digits don't jitter as
  /// a countdown ticks.
  static final TextStyle numeric = _style(
    size: 15,
    weight: semiBold,
    height: 1.2,
  ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

  /// The complete [TextTheme] handed to [ThemeData].
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: primary),
      displayMedium: displayMedium.copyWith(color: primary),
      headlineLarge: headlineLarge.copyWith(color: primary),
      headlineMedium: headlineMedium.copyWith(color: primary),
      headlineSmall: headlineSmall.copyWith(color: primary),
      titleLarge: titleLarge.copyWith(color: primary),
      titleMedium: titleMedium.copyWith(color: primary),
      titleSmall: titleSmall.copyWith(color: primary),
      bodyLarge: bodyLarge.copyWith(color: primary),
      bodyMedium: bodyMedium.copyWith(color: primary),
      bodySmall: bodySmall.copyWith(color: secondary),
      labelLarge: labelLarge.copyWith(color: primary),
      labelMedium: labelMedium.copyWith(color: secondary),
      labelSmall: labelSmall.copyWith(color: secondary),
    );
  }
}

/// Shorthand for the two lookups screens do constantly.
extension AppTextContext on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}
