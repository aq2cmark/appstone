import 'package:flutter/material.dart';

/// The spacing scale.
///
/// The pre-overhaul codebase had ~201 magic-number `SizedBox`es using 17
/// different values, including one-offs like `SizedBox(height: 7)`. Every gap
/// now comes from here so rhythm stays consistent across 20+ screens.
///
/// Steps are 4-based, which keeps everything on a half-grid that lines up with
/// Material's own 8dp baseline.
abstract final class AppSpacing {
  /// 4 - hairline gaps, icon-to-label inside a chip.
  static const double xs = 4;

  /// 8 - tight gaps between closely related elements.
  static const double sm = 8;

  /// 12 - default gap inside a card.
  static const double md = 12;

  /// 16 - default gap between cards, default page padding on phones.
  static const double lg = 16;

  /// 24 - section separation, card padding.
  static const double xl = 24;

  /// 32 - major section breaks, desktop page padding.
  static const double xxl = 32;

  /// 48 - hero spacing, empty-state breathing room.
  static const double xxxl = 48;

  /// Vertical gap.
  static SizedBox gapV(double size) => SizedBox(height: size);

  /// Horizontal gap.
  static SizedBox gapH(double size) => SizedBox(width: size);

  // Common gaps as constants, so the hot paths stay `const`.
  static const SizedBox vXs = SizedBox(height: xs);
  static const SizedBox vSm = SizedBox(height: sm);
  static const SizedBox vMd = SizedBox(height: md);
  static const SizedBox vLg = SizedBox(height: lg);
  static const SizedBox vXl = SizedBox(height: xl);
  static const SizedBox vXxl = SizedBox(height: xxl);

  static const SizedBox hXs = SizedBox(width: xs);
  static const SizedBox hSm = SizedBox(width: sm);
  static const SizedBox hMd = SizedBox(width: md);
  static const SizedBox hLg = SizedBox(width: lg);
  static const SizedBox hXl = SizedBox(width: xl);
}

/// Corner radii.
///
/// The old codebase intended a 12 (controls) / 18 (cards) / 20 (pills) system
/// but leaked 14 for tinted cards, 16 for badges, and split progress-bar clips
/// between 8 and 6. These are the only radii allowed now.
abstract final class AppRadius {
  /// 8 - progress tracks, small clips, nav tiles.
  static const double sm = 8;

  /// 12 - inputs, buttons, snackbars.
  static const double md = 12;

  /// 18 - cards, panels.
  static const double lg = 18;

  /// 24 - dialogs, bottom sheets, hero surfaces.
  static const double xl = 24;

  /// Fully rounded - pills, chips, avatars.
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const RoundedRectangleBorder smShape =
      RoundedRectangleBorder(borderRadius: smAll);
  static const RoundedRectangleBorder mdShape =
      RoundedRectangleBorder(borderRadius: mdAll);
  static const RoundedRectangleBorder lgShape =
      RoundedRectangleBorder(borderRadius: lgAll);
  static const RoundedRectangleBorder xlShape =
      RoundedRectangleBorder(borderRadius: xlAll);
  static const StadiumBorder pillShape = StadiumBorder();
}

/// Elevation steps.
///
/// Material's default shadow is the only shadow in the app; these keep the
/// depths intentional rather than arbitrary.
abstract final class AppElevation {
  /// Flush with the page.
  static const double flat = 0;

  /// Resting card.
  static const double raised = 1;

  /// Hovered / focused card, popovers.
  static const double floating = 8;

  /// Dialogs and sheets.
  static const double overlay = 16;
}

/// Content widths.
///
/// `maxWidth: 760` was copy-pasted across 9 screens, `680` across 2, and `420`
/// across 2, none of them shared. These replace all of it.
abstract final class AppContentWidth {
  /// 440 - login, single-purpose forms.
  static const double form = 440;

  /// 780 - comfortable reading measure for a single column of content.
  static const double reading = 780;

  /// 1120 - two-column feature layouts on desktop.
  static const double wide = 1120;

  /// 1400 - the dashboard grid and admin tables.
  static const double max = 1400;
}

/// Sizes for repeated UI furniture, so "how big is an icon tile" has one answer.
abstract final class AppSize {
  /// Icon inside a body row.
  static const double iconSm = 18;

  /// Default icon.
  static const double iconMd = 22;

  /// Feature/emphasis icon.
  static const double iconLg = 28;

  /// Empty-state and hero icon.
  static const double iconXl = 56;

  /// Small solid icon tile (admin stat cards).
  static const double tileSm = 48;

  /// Large solid icon tile (dashboard feature cards).
  static const double tileLg = 64;

  /// Minimum interactive target. Anything tappable must be at least this tall.
  static const double tapTarget = 48;
}
