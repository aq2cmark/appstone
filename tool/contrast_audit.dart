// WCAG 2.1 contrast audit for the Appstone palette.
//
// A command-line tool, not app code - printing to stdout is the whole point.
// ignore_for_file: avoid_print
// Run: dart run contrast.dart
import 'dart:math' as math;

double _lin(int c) {
  final s = c / 255.0;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double luminance(int hex) {
  final r = (hex >> 16) & 0xFF;
  final g = (hex >> 8) & 0xFF;
  final b = hex & 0xFF;
  return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b);
}

double ratio(int a, int b) {
  final la = luminance(a);
  final lb = luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const light = <String, int>{
  'brand': 0x8B1A1A, 'brandStrong': 0x6B1414, 'brandSoft': 0xF6EAEA,
  'background': 0xF5F3F0, 'surface': 0xFFFFFF, 'surfaceElevated': 0xFFFFFF,
  'surfaceSunken': 0xEBE7E2, 'border': 0xE3DDD6, 'divider': 0xEDE8E2,
  'textPrimary': 0x1A1614, 'textSecondary': 0x6B625C, 'textTertiary': 0x746C66,
  'success': 0x1B7F4B, 'successTint': 0xEAF6EF,
  'warning': 0x9A5C00, 'warningTint': 0xFDF1DE,
  'danger': 0xC62828, 'dangerTint': 0xFCEAEA,
  'info': 0x1E5F8C, 'infoTint': 0xE7F1F8,
  'premium': 0x8A6D14, 'premiumTint': 0xFDF6E4,
  'moduleManual': 0x8B1A1A, 'moduleTitleGen': 0x9C5F0A,
  'moduleDefense': 0x9A2C4E, 'moduleWorkflow': 0x3B4B9A,
  'modulePaper': 0x0F766E, 'titleDefense': 0xB4530A,
  'oralDefense': 0x6B3FA0, 'finalDefense': 0xA62B20,
};

const dark = <String, int>{
  'brand': 0xD9645A, 'brandStrong': 0x8B1A1A, 'brandSoft': 0x2A1A19,
  'background': 0x141110, 'surface': 0x1E1A19, 'surfaceElevated': 0x272120,
  'surfaceSunken': 0x0E0C0B, 'border': 0x3A3331, 'divider': 0x2E2826,
  'textPrimary': 0xF5F1EE, 'textSecondary': 0xB3A9A3, 'textTertiary': 0x938A82,
  'success': 0x4ADE80, 'successTint': 0x14301F,
  'warning': 0xE0A33A, 'warningTint': 0x33240C,
  'danger': 0xF06A6A, 'dangerTint': 0x361718,
  'info': 0x6BB2E0, 'infoTint': 0x12242F,
  'premium': 0xDDB83F, 'premiumTint': 0x322913,
  'moduleManual': 0xD9645A, 'moduleTitleGen': 0xE0A054,
  'moduleDefense': 0xDE7395, 'moduleWorkflow': 0x8A97E8,
  'modulePaper': 0x4FBFB2, 'titleDefense': 0xE59355,
  'oralDefense': 0xAF8AE0, 'finalDefense': 0xE8776B,
};

// Foreground -> the surfaces it is actually painted on in this app.
const pairs = <String, List<String>>{
  'textPrimary': ['background', 'surface', 'surfaceElevated'],
  'textSecondary': ['background', 'surface', 'surfaceElevated'],
  'textTertiary': ['background', 'surface'],
  'brand': ['background', 'surface', 'brandSoft'],
  'success': ['surface', 'successTint'],
  'warning': ['surface', 'warningTint'],
  'danger': ['surface', 'dangerTint'],
  'info': ['surface', 'infoTint'],
  'premium': ['surface', 'premiumTint'],
  'moduleManual': ['surface'],
  'moduleTitleGen': ['surface'],
  'moduleDefense': ['surface'],
  'moduleWorkflow': ['surface'],
  'modulePaper': ['surface'],
  'titleDefense': ['surface'],
  'oralDefense': ['surface'],
  'finalDefense': ['surface'],
};

void audit(String label, Map<String, int> p) {
  print('\n=== $label ===');
  final fails = <String>[];
  pairs.forEach((fg, bgs) {
    for (final bg in bgs) {
      if (!p.containsKey(fg) || !p.containsKey(bg)) continue;
      final r = ratio(p[fg]!, p[bg]!);
      // 4.5 = AA body text. 3.0 = AA large text / UI component.
      final okBody = r >= 4.5;
      final okLarge = r >= 3.0;
      final mark = okBody ? 'PASS' : (okLarge ? 'LARGE-ONLY' : 'FAIL');
      if (!okBody) {
        fails.add('  $mark  $fg on $bg = ${r.toStringAsFixed(2)}');
      }
    }
  });
  if (fails.isEmpty) {
    print('  all pairs pass AA (4.5:1)');
  } else {
    fails.forEach(print);
  }
}

void main() {
  audit('LIGHT', light);
  audit('DARK', dark);

  // onBrand (white) on every filled surface a button or badge uses.
  print('\n=== WHITE ON FILLED (buttons/badges) ===');
  for (final entry in <String, Map<String, int>>{'light': light, 'dark': dark}.entries) {
    for (final key in ['brand', 'success', 'warning', 'danger', 'info', 'premium']) {
      final ink = entry.key == 'dark' ? 0x1A1614 : 0xFFFFFF;
      final r = ratio(ink, entry.value[key]!);
      if (r < 4.5) {
        print('  ${r >= 3.0 ? "LARGE-ONLY" : "FAIL"}  ink on ${entry.key}.$key = ${r.toStringAsFixed(2)}');
      }
    }
  }
}
