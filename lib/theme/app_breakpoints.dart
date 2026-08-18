import 'package:flutter/material.dart';

/// Layout sizes, following Material 3's window size classes.
///
/// These are the *only* width thresholds allowed in the app. The pre-overhaul
/// code had ad-hoc numbers scattered around - 800 for the admin sidebar, 900
/// for admin padding, 650 for a group card header, a derived 1180 for the
/// dashboard dock - none of which agreed with each other.
enum AppBreakpoint {
  /// < 600 - phones in portrait. Bottom navigation, single column, stacked
  /// cards instead of tables.
  compact,

  /// 600-1023 - large phones in landscape, small tablets. Navigation rail
  /// (icons only), still a single content column.
  medium,

  /// 1024-1439 - tablets in landscape, small laptops. Navigation rail, and the
  /// point where two-column feature layouts switch on.
  expanded,

  /// >= 1440 - desktop. Extended navigation rail with labels.
  large;

  bool get isCompact => this == AppBreakpoint.compact;
  bool get isMedium => this == AppBreakpoint.medium;
  bool get isExpanded => this == AppBreakpoint.expanded;
  bool get isLarge => this == AppBreakpoint.large;

  /// True for phone-sized windows, where bottom navigation is used.
  bool get usesBottomNav => this == AppBreakpoint.compact;

  /// True once there is room for a persistent side rail.
  bool get usesRail => this != AppBreakpoint.compact;

  /// True once the rail should show labels beside its icons.
  bool get usesExtendedRail => this == AppBreakpoint.large;

  /// True once a screen with a natural split should go two-column.
  bool get usesTwoColumn =>
      this == AppBreakpoint.expanded || this == AppBreakpoint.large;

  /// True where a `DataTable` is appropriate. Below this, render stacked cards.
  bool get usesDataTable => this != AppBreakpoint.compact;
}

abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
  static const double large = 1440;

  static AppBreakpoint fromWidth(double width) {
    if (width >= large) return AppBreakpoint.large;
    if (width >= expanded) return AppBreakpoint.expanded;
    if (width >= medium) return AppBreakpoint.medium;
    return AppBreakpoint.compact;
  }

  /// Breakpoint of the whole window.
  ///
  /// Use this for app-level chrome (navigation shell). For content that sits
  /// inside a constrained region - a screen body next to a rail, or a panel -
  /// prefer [LayoutBuilder] with [fromWidth] so the decision is made from the
  /// space actually available rather than the window.
  static AppBreakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}

extension AppBreakpointContext on BuildContext {
  AppBreakpoint get breakpoint => AppBreakpoints.of(this);

  /// Pick a value per size class. [medium] and [expanded] fall back to the
  /// next smaller value when omitted, so most callers only pass two.
  T responsive<T>({
    required T compact,
    T? medium,
    T? expanded,
    T? large,
  }) {
    switch (breakpoint) {
      case AppBreakpoint.compact:
        return compact;
      case AppBreakpoint.medium:
        return medium ?? compact;
      case AppBreakpoint.expanded:
        return expanded ?? medium ?? compact;
      case AppBreakpoint.large:
        return large ?? expanded ?? medium ?? compact;
    }
  }

  /// Horizontal page gutter for the current size class.
  double get pagePadding =>
      responsive(compact: 16, medium: 24, expanded: 32, large: 40);

  /// Vertical page padding.
  ///
  /// Deliberately *not* the same as [pagePadding]. The horizontal gutter should
  /// grow with the window, but vertical space is the scarce axis on a laptop -
  /// a 1440x900 screen is wide and short. Stacking a 40 px gutter on top and
  /// bottom there just pushes content below the fold, so the vertical rhythm
  /// stops growing past the medium size class.
  double get pagePaddingVertical => responsive(compact: 16, medium: 24);
}
