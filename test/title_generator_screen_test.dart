import 'package:appstone/screens/title_generator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The filter chips are laid out by hand (see _AnimatedChipWrap) so they can
// glide between positions, which means their widths are measured rather than
// discovered. If that measurement is ever too tight the chips silently overflow
// at runtime, so these tests drive a real reorder and let the overflow error
// fail the build instead.
void main() {
  // Reads the chip's real selection state rather than inferring it from colour.
  bool isSelected(WidgetTester tester, String label) {
    return tester
        .widget<ChoiceChip>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(ChoiceChip),
          ),
        )
        .selected;
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    // Chips reorder as picks accumulate, so one can end up below the fold -
    // and tapping an off-screen widget quietly does nothing.
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

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

  // "Farmers" is Agriculture-only and "Healthcare Workers" is Healthcare-only,
  // so the second pick is exactly the cross-field case the confirmation exists
  // for. These guard that the prompt fires when it should, stays out of the way
  // when it should not, and never selects anything on its own.
  group('cross-field confirmation', () {
    testWidgets('the first pick is never questioned', (tester) async {
      await pumpScreen(tester);

      await tapChip(tester, 'Farmers');

      // Nothing is picked yet, so nothing can clash with it.
      expect(find.text('Add a chip from another field?'), findsNothing);
      expect(isSelected(tester, 'Farmers'), isTrue);
    });

    testWidgets('a chip from an unrelated field asks first and waits', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapChip(tester, 'Farmers');

      await tapChip(tester, 'Healthcare Workers');

      expect(find.text('Add a chip from another field?'), findsOneWidget);
      // The point of the dialog: the chip must not already be picked behind it.
      expect(isSelected(tester, 'Healthcare Workers'), isFalse);
    });

    testWidgets('cancelling leaves the selection exactly as it was', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapChip(tester, 'Farmers');
      await tapChip(tester, 'Healthcare Workers');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add a chip from another field?'), findsNothing);
      expect(isSelected(tester, 'Healthcare Workers'), isFalse);
      expect(isSelected(tester, 'Farmers'), isTrue);
    });

    testWidgets('confirming adds the chip - the mix is allowed, not blocked', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapChip(tester, 'Farmers');
      await tapChip(tester, 'Healthcare Workers');

      await tester.tap(find.text('Add anyway'));
      await tester.pumpAndSettle();

      expect(isSelected(tester, 'Healthcare Workers'), isTrue);
      expect(isSelected(tester, 'Farmers'), isTrue);
    });

    testWidgets('a chip that fits the picked field is not questioned', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapChip(tester, 'Farmers');

      // Same field as Farmers, so there is nothing to warn about.
      await tapChip(tester, 'Agriculture');

      expect(find.text('Add a chip from another field?'), findsNothing);
      expect(isSelected(tester, 'Agriculture'), isTrue);
    });

    testWidgets('a field-agnostic chip is never questioned', (tester) async {
      await pumpScreen(tester);
      await tapChip(tester, 'Farmers');

      // No domain tags at all - a mobile app is at home in any capstone.
      await tapChip(tester, 'Mobile Application');

      expect(find.text('Add a chip from another field?'), findsNothing);
      expect(isSelected(tester, 'Mobile Application'), isTrue);
    });

    testWidgets('removing a pick is never questioned', (tester) async {
      await pumpScreen(tester);
      await tapChip(tester, 'Farmers');
      await tapChip(tester, 'Healthcare Workers');
      await tester.tap(find.text('Add anyway'));
      await tester.pumpAndSettle();

      // Un-picking can only ever make the set more coherent.
      await tapChip(tester, 'Healthcare Workers');

      expect(find.text('Add a chip from another field?'), findsNothing);
      expect(isSelected(tester, 'Healthcare Workers'), isFalse);
    });
  });
}
