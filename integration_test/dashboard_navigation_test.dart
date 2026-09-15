// Runs the real Dashboard screen in a real browser engine (Chrome / Edge) and
// exercises the cross-cutting flow that unit tests don't reach: a student
// taps every feature card and the route that actually opens depends on BOTH
// the card's `requiresPremium` flag AND the group's premium status. No
// Firebase is touched here - DashboardScreen takes its student/group state as
// plain constructor params, so this is a true integration test of the
// dashboard + Navigator working together, without needing a backend double.
//
// Run with:
//   flutter test integration_test/dashboard_navigation_test.dart -d chrome
//   flutter test integration_test/dashboard_navigation_test.dart -d edge
import 'package:appstone/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Stand-ins for the real guarded feature screens. The point of this test is
  // routing + gating, not what each destination screen renders.
  Widget placeholder(String label) =>
      Scaffold(body: Center(child: Text('OPENED: $label')));

  Future<void> pumpDashboard(WidgetTester tester, {required bool isPremium}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          studentName: 'Juan Cruz',
          groupName: 'Capstone Group 1',
          isPremium: isPremium,
          groupId: 'group-1',
          studentId: 'STU001',
        ),
        routes: {
          '/capstone-manual': (_) => placeholder('capstone-manual'),
          '/title-generator': (_) => placeholder('title-generator'),
          '/defense-practice': (_) => placeholder('defense-practice'),
          '/ai-workflow': (_) => placeholder('ai-workflow'),
          '/paper-checker': (_) => placeholder('paper-checker'),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Dashboard feature routing (free group)', () {
    testWidgets('free features open normally', (tester) async {
      await pumpDashboard(tester, isPremium: false);

      await tester.tap(find.text('Capstone Manual'));
      await tester.pumpAndSettle();
      expect(find.text('OPENED: capstone-manual'), findsOneWidget);
    });

    testWidgets('premium features are blocked with a snackbar, not opened', (
      tester,
    ) async {
      await pumpDashboard(tester, isPremium: false);

      await tester.tap(find.text('Defense Practice'));
      await tester.pump(); // let the SnackBar animation start
      expect(find.text('Avail premium to access this feature.'), findsOneWidget);
      // Must NOT have navigated - the placeholder screen never appears.
      expect(find.text('OPENED: defense-practice'), findsNothing);
    });
  });

  group('Dashboard feature routing (premium group)', () {
    // One isolated testWidgets per feature (a fresh pumpWidget each time)
    // rather than one shared loop - that keeps each case independent of
    // whatever overlay/scroll state the previous tap left behind, and mirrors
    // how the free-group cases above are already structured.
    for (final feature in const [
      ('Capstone Manual', 'capstone-manual'),
      ('Title Generator', 'title-generator'),
      ('Defense Practice', 'defense-practice'),
      ('AI Workflow', 'ai-workflow'),
      ('Paper Checker', 'paper-checker'),
    ]) {
      testWidgets('${feature.$1} opens once the group is premium', (
        tester,
      ) async {
        await pumpDashboard(tester, isPremium: true);
        // A real WebDriver-driven browser tap needs the target inside the
        // visible viewport (unlike the Dart-VM test harness, which hit-tests
        // regardless of scroll position) - scroll it in first.
        final card = find.text(feature.$1);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(
          find.text('OPENED: ${feature.$2}'),
          findsOneWidget,
          reason: '${feature.$1} should open ${feature.$2} once premium',
        );
      });
    }

    testWidgets('the Premium chip is shown in the header', (tester) async {
      await pumpDashboard(tester, isPremium: true);
      expect(find.text('Premium'), findsOneWidget);
    });
  });
}
