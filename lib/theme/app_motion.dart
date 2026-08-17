import 'package:flutter/material.dart';

/// The motion language.
///
/// Two registers, deliberately:
///
/// * **Calm** - everywhere. Entrance staggers, page transitions, hover and
///   press feedback, animated counters. Nothing overshoots.
/// * **Expressive** - Defense Practice and Defense Results only. The timer
///   ring, the score dial sweep, the radar reveal. This is the "gamified"
///   register the capstone paper promises; it must not leak into the manual,
///   the admin portal, or any form.
///
/// Values are ported from the two pieces of motion the app already got right:
/// the dashboard hover dock (160ms easeOut) and the title generator's chip wrap
/// (260ms easeOutCubic).
abstract final class AppMotion {
  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------

  /// 100ms - state flips that should feel immediate (checkbox, ripple tail).
  static const Duration instant = Duration(milliseconds: 100);

  /// 180ms - hover, press, small scale and colour changes.
  static const Duration quick = Duration(milliseconds: 180);

  /// 260ms - the default. Layout shifts, reveals, page transitions.
  static const Duration standard = Duration(milliseconds: 260);

  /// 400ms - larger surfaces entering, expanding panels.
  static const Duration slow = Duration(milliseconds: 400);

  /// 700ms - expressive only. Score dials, radar sweeps, celebration beats.
  static const Duration celebratory = Duration(milliseconds: 700);

  /// 1200ms - the shimmer loop on skeleton loaders.
  static const Duration shimmer = Duration(milliseconds: 1200);

  // ---------------------------------------------------------------------------
  // Curves
  // ---------------------------------------------------------------------------

  /// Things arriving. Fast out of the gate, settles gently.
  static const Curve enter = Curves.easeOutCubic;

  /// Things leaving. Eases in, then goes quickly.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric motion - something moving from A to B and staying on screen.
  static const Curve standardCurve = Curves.easeInOutCubic;

  /// Expressive only. Slight overshoot for score reveals and celebration.
  static const Curve emphasis = Curves.easeOutBack;

  /// Continuous, non-decelerating motion (pulses, indeterminate loops).
  static const Curve linear = Curves.linear;

  // ---------------------------------------------------------------------------
  // Stagger
  // ---------------------------------------------------------------------------

  /// Delay between consecutive items in a staggered entrance.
  static const Duration staggerStep = Duration(milliseconds: 45);

  /// Cap on stagger delay, so a long list's last item doesn't wait seconds.
  static const int staggerMaxItems = 8;

  /// Entrance delay for the item at [index] in a staggered group.
  static Duration staggerDelay(int index) => staggerStep *
      (index > staggerMaxItems ? staggerMaxItems : index);

  // ---------------------------------------------------------------------------
  // Accessibility
  // ---------------------------------------------------------------------------

  /// Whether the platform has asked for reduced motion.
  ///
  /// Decorative motion (staggers, sweeps, pulses, celebration) must be skipped
  /// when this is true. Functional motion that communicates state - a progress
  /// bar filling, an expanding panel - may stay.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or [Duration.zero] when the user has asked for reduced motion.
  static Duration respect(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
