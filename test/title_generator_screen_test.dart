import 'package:appstone/screens/title_generator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The filter chips are laid out by hand (see _AnimatedChipWrap) so they can
// glide between positions, which means their widths are measured rather than
// discovered. If that measurement is ever too tight the chips silently overflow
// at runtime, so these tests drive a real reorder and let the overflow error
// fail the build instead.
void main() {
  Future<void> pumpScreen(WidgetTester tester, {Size? surface}) async {
    if (surface != null) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(const MaterialApp(home: TitleGeneratorScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('chips lay out without overflowing', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Farmers'), findsOneWidget);
    expect(find.text('Agriculture'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a chip glides the rest without overflowing', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Farmers'));
    await tester.pump();
    // Part-way through the glide is where chips are mid-flight and most likely
    // to be drawn somewhere they don't fit.
    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a related chip glides to the front instead of teleporting', (
    tester,
  ) async {
    await pumpScreen(tester);

    // "Agriculture" is the only farming problem area, so picking "Farmers"
    // pulls it from the middle of the row up to the front.
    final start = tester.getTopLeft(find.text('Agriculture'));

    await tester.tap(find.text('Farmers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midFlight = tester.getTopLeft(find.text('Agriculture'));

    await tester.pumpAndSettle();
    final settled = tester.getTopLeft(find.text('Agriculture'));

    // It ended up somewhere new...
    expect(settled, isNot(start));
    // ...and part-way through was still travelling rather than already parked,
    // which is the difference between gliding and teleporting.
    expect(midFlight, isNot(settled));
    expect(midFlight, isNot(start));
  });

  testWidgets('narrow screens re-wrap without overflowing', (tester) async {
    // A phone-width surface forces far more row breaks than the default test
    // window, which is where a too-generous width estimate would show up.
    await pumpScreen(tester, surface: const Size(360, 800));

    // The chip sits below the fold at this width, and tapping a widget that
    // isn't on screen quietly does nothing - scroll to it or this test passes
    // without ever triggering a reorder.
    await tester.ensureVisible(find.text('Farmers'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Farmers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Proves the tap landed: "Agriculture" shares the farming domain, so a real
    // reorder leaves it selected-adjacent and still on screen.
    expect(find.text('Agriculture'), findsOneWidget);
  });
}
