import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's light/dark preference and persists it per device.
///
/// A [ValueNotifier] rather than a state-management package, matching the rest
/// of the app - `MainApp` listens with a `ValueListenableBuilder`, so changing
/// the theme rebuilds `MaterialApp` and nothing else has to know.
///
/// The value is read once at startup (before `runApp`) so the first frame is
/// already in the right theme and there is no flash of the wrong background.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  static final ThemeController instance = ThemeController._();

  static const String _prefsKey = 'theme_mode_v1';

  /// Loads the saved preference. Safe to call before `runApp`.
  ///
  /// Failures are swallowed deliberately: a corrupt or unavailable
  /// SharedPreferences must not stop the app from starting - it just means the
  /// user gets the system theme.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = _decode(prefs.getString(_prefsKey));
    } catch (_) {
      value = ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    if (value == mode) return;
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encode(mode));
    } catch (_) {
      // The theme still applies for this session; only persistence failed.
    }
  }

  /// Flips between light and dark.
  ///
  /// When the mode is currently [ThemeMode.system] we resolve what the user is
  /// actually looking at and pick the opposite, so one tap always visibly
  /// changes something.
  Future<void> toggle(BuildContext context) {
    final effective = value == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context)
        : (value == ThemeMode.dark ? Brightness.dark : Brightness.light);
    return set(
      effective == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  /// The brightness the user is currently seeing.
  Brightness resolvedBrightness(BuildContext context) {
    switch (value) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
