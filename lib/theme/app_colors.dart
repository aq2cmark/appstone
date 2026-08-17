import 'package:flutter/material.dart';

/// The Appstone colour system.
///
/// Every colour in the app comes from here. Screens must never write
/// `Colors.white`, `Colors.green`, or a raw `Color(0xFF...)` - a hardcoded
/// light colour silently breaks dark mode, and the pre-overhaul codebase had
/// 125 of them.
///
/// Read the palette with [AppColors.of] so it resolves for the current
/// brightness:
///
/// ```dart
/// final colors = AppColors.of(context);
/// Container(color: colors.surface);
/// ```
///
/// The brand is maroon (#8B1A1A), matching the Appstone logo, launcher icons,
/// favicon and PWA theme colour. Each feature module owns an accent so the
/// dashboard reads at a glance instead of repeating the same two hues.
@immutable
class AppColors {
  const AppColors({
    required this.brightness,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.onBrand,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.onColor,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
    required this.info,
    required this.infoTint,
    required this.premium,
    required this.premiumTint,
    required this.moduleManual,
    required this.moduleTitleGen,
    required this.moduleDefense,
    required this.moduleWorkflow,
    required this.modulePaper,
    required this.titleDefense,
    required this.oralDefense,
    required this.finalDefense,
    required this.shadow,
    required this.scrim,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  final Brightness brightness;

  /// Primary brand maroon. App chrome, primary actions, focus rings.
  final Color brand;

  /// Deeper brand tone for pressed states and gradient depth.
  final Color brandStrong;

  /// Very low-opacity brand wash for selected rows and tinted panels.
  final Color brandSoft;

  /// Foreground that is legible on top of [brand].
  final Color onBrand;

  /// The page behind everything.
  final Color background;

  /// Default card / sheet colour.
  final Color surface;

  /// A surface that should read as lifted above [surface].
  final Color surfaceElevated;

  /// A recessed well - progress tracks, input fills, code blocks.
  final Color surfaceSunken;

  /// Hairline around cards and inputs.
  final Color border;

  /// Separator inside a surface.
  final Color divider;

  /// Headings and body copy.
  final Color textPrimary;

  /// Supporting copy, captions, subtitles.
  final Color textSecondary;

  /// De-emphasised metadata and placeholders.
  final Color textTertiary;

  /// Foreground for solid status/module colour fills (badges, icon tiles).
  final Color onColor;

  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;

  /// Destructive actions and time's-up alerts.
  final Color danger;
  final Color dangerTint;
  final Color info;
  final Color infoTint;

  /// Premium tier gold. Locks, premium badges, upgrade affordances.
  final Color premium;
  final Color premiumTint;

  /// Capstone Manual.
  final Color moduleManual;

  /// Title Generator.
  final Color moduleTitleGen;

  /// Defense Practice (the module as a whole).
  final Color moduleDefense;

  /// AI Workflow planner.
  final Color moduleWorkflow;

  /// Paper Checker.
  final Color modulePaper;

  /// Title Defense practice mode.
  final Color titleDefense;

  /// Oral Defense practice mode.
  final Color oralDefense;

  /// Final Defense practice mode.
  final Color finalDefense;

  final Color shadow;

  /// Dimming behind modals and sheets.
  final Color scrim;

  final Color skeletonBase;
  final Color skeletonHighlight;

  bool get isDark => brightness == Brightness.dark;

  /// The palette for the current theme brightness.
  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// A soft, theme-appropriate wash of [color] for tinted panels.
  ///
  /// Dark surfaces need a stronger alpha than light ones to read at all, which
  /// is why this is a method rather than a fixed opacity everyone copies.
  Color tint(Color color) =>
      color.withValues(alpha: isDark ? 0.22 : 0.10);

  /// A border-weight wash of [color], for outlines around tinted panels.
  Color tintBorder(Color color) =>
      color.withValues(alpha: isDark ? 0.38 : 0.22);

  /// The module accent for a dashboard/feature route.
  ///
  /// Falls back to [brand] so an unknown route still renders on-brand rather
  /// than throwing or rendering grey.
  Color moduleFor(String route) {
    switch (route) {
      case '/capstone-manual':
        return moduleManual;
      case '/title-generator':
        return moduleTitleGen;
      case '/defense-practice':
      case '/defense-context':
      case '/session-history':
        return moduleDefense;
      case '/title-defense':
        return titleDefense;
      case '/oral-defense':
        return oralDefense;
      case '/final-defense':
        return finalDefense;
      case '/ai-workflow':
        return moduleWorkflow;
      case '/paper-checker':
      case '/paper-check-history':
        return modulePaper;
      default:
        return brand;
    }
  }

  // ---------------------------------------------------------------------------
  // Light
  // ---------------------------------------------------------------------------

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    brand: Color(0xFF8B1A1A),
    brandStrong: Color(0xFF6B1414),
    brandSoft: Color(0xFFF6EAEA),
    onBrand: Color(0xFFFFFFFF),
    background: Color(0xFFF5F3F0),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEBE7E2),
    border: Color(0xFFE3DDD6),
    divider: Color(0xFFEDE8E2),
    textPrimary: Color(0xFF1A1614),
    textSecondary: Color(0xFF6B625C),
    textTertiary: Color(0xFF98908A),
    onColor: Color(0xFFFFFFFF),
    success: Color(0xFF1B7F4B),
    successTint: Color(0xFFE6F4EC),
    warning: Color(0xFFB26A00),
    warningTint: Color(0xFFFDF1DE),
    danger: Color(0xFFC62828),
    dangerTint: Color(0xFFFCEAEA),
    info: Color(0xFF1E5F8C),
    infoTint: Color(0xFFE7F1F8),
    premium: Color(0xFF9A7A16),
    premiumTint: Color(0xFFFBF3DC),
    moduleManual: Color(0xFF8B1A1A),
    moduleTitleGen: Color(0xFFAD6A0B),
    moduleDefense: Color(0xFF9A2C4E),
    moduleWorkflow: Color(0xFF3B4B9A),
    modulePaper: Color(0xFF0F766E),
    titleDefense: Color(0xFFB4530A),
    oralDefense: Color(0xFF6B3FA0),
    finalDefense: Color(0xFFA62B20),
    shadow: Color(0x1A1A1614),
    scrim: Color(0x801A1614),
    skeletonBase: Color(0xFFE8E3DD),
    skeletonHighlight: Color(0xFFF5F2EE),
  );

  // ---------------------------------------------------------------------------
  // Dark
  //
  // Warm-tinted neutrals rather than pure grey, so the maroon brand sits in the
  // dark theme instead of fighting it. Brand and module accents are lightened -
  // #8B1A1A on a dark surface is close to unreadable, so the dark palette uses
  // brighter tones for accents and keeps the deep maroon for solid fills.
  // ---------------------------------------------------------------------------

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    brand: Color(0xFFD9645A),
    brandStrong: Color(0xFF8B1A1A),
    brandSoft: Color(0xFF2A1A19),
    onBrand: Color(0xFFFFFFFF),
    background: Color(0xFF141110),
    surface: Color(0xFF1E1A19),
    surfaceElevated: Color(0xFF272120),
    surfaceSunken: Color(0xFF0E0C0B),
    border: Color(0xFF3A3331),
    divider: Color(0xFF2E2826),
    textPrimary: Color(0xFFF5F1EE),
    textSecondary: Color(0xFFB3A9A3),
    textTertiary: Color(0xFF7D7570),
    onColor: Color(0xFFFFFFFF),
    success: Color(0xFF4ADE80),
    successTint: Color(0xFF14301F),
    warning: Color(0xFFE0A33A),
    warningTint: Color(0xFF33240C),
    danger: Color(0xFFF06A6A),
    dangerTint: Color(0xFF361718),
    info: Color(0xFF6BB2E0),
    infoTint: Color(0xFF12242F),
    premium: Color(0xFFDDB83F),
    premiumTint: Color(0xFF322913),
    moduleManual: Color(0xFFD9645A),
    moduleTitleGen: Color(0xFFE0A054),
    moduleDefense: Color(0xFFDE7395),
    moduleWorkflow: Color(0xFF8A97E8),
    modulePaper: Color(0xFF4FBFB2),
    titleDefense: Color(0xFFE59355),
    oralDefense: Color(0xFFAF8AE0),
    finalDefense: Color(0xFFE8776B),
    shadow: Color(0x66000000),
    scrim: Color(0xB3000000),
    skeletonBase: Color(0xFF2A2422),
    skeletonHighlight: Color(0xFF383130),
  );
}

/// Convenience so screens can write `context.colors.surface`.
extension AppColorsContext on BuildContext {
  AppColors get colors => AppColors.of(this);
}
