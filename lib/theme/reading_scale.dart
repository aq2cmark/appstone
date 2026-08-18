import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reader-chosen text size for the Capstone Manual.
///
/// The manual is the only place in the app where someone reads continuously for
/// several minutes, and comfortable body size is genuinely personal - it
/// depends on the device, the lighting and the reader's eyesight. Rather than
/// pick one size and hope, the manual carries A- / A+ controls backed by this.
///
/// It deliberately scales *only* the manual's reading surface. The app-wide
/// text scale already follows the OS accessibility setting (clamped in
/// `main.dart`); this sits on top of that for one screen, so raising it does
/// not stretch the navigation bar or the admin tables.
class ReadingScale extends ValueNotifier<double> {
  ReadingScale._() : super(_defaultStep) {
    _restore();
  }

  static final ReadingScale instance = ReadingScale._();

  static const String _prefsKey = 'manual_text_scale_v1';

  /// Four steps rather than a free slider: enough choice to matter, few enough
  /// that every step is a layout the design was actually checked at.
  static const List<double> steps = <double>[1.0, 1.15, 1.3, 1.45];
  static const double _defaultStep = 1.0;

  bool get canDecrease => value > steps.first;
  bool get canIncrease => value < steps.last;

  /// Position in [steps], for a "2 of 4" style readout.
  int get stepIndex => steps.indexOf(value).clamp(0, steps.length - 1);

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_prefsKey);
      // Only accept a value we still offer - a stored step from an older build
      // could otherwise produce a size the layout was never checked at.
      if (saved != null && steps.contains(saved)) value = saved;
    } catch (_) {
      // A preferences failure just means the default size; not worth surfacing.
    }
  }

  Future<void> increase() => _moveBy(1);
  Future<void> decrease() => _moveBy(-1);

  Future<void> _moveBy(int delta) async {
    final next = (stepIndex + delta).clamp(0, steps.length - 1);
    if (steps[next] == value) return;
    value = steps[next];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKey, value);
    } catch (_) {
      // The size still applies for this session even if it cannot be saved.
    }
  }
}
