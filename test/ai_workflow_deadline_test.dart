import 'package:appstone/screens/ai_workflow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The workflow screen asks for a deadline date rather than an amount + unit, so
// the day count comes from calendar arithmetic. These cover the bits of that
// which fail at runtime rather than at compile time.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AIWorkflowScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for a deadline date instead of an amount and unit', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('2. When do you need to finish?'), findsOneWidget);
    expect(find.text('Pick your deadline'), findsOneWidget);
    // The old amount/unit pair is what made "3 days, 2 weeks and 1 month"
    // impossible to say - it shouldn't be back.
    expect(find.text('Weeks'), findsNothing);
    expect(find.text('Amount'), findsNothing);
  });

  testWidgets('the picker opens, and reopens, without tripping its own asserts', (
    tester,
  ) async {
    // showDatePicker asserts that initialDate is within firstDate..lastDate, so
    // getting those bounds wrong is a crash rather than a wrong pixel. Opening
    // it twice covers the reopen path, where a previously chosen date is fed
    // back in as initialDate.
    await pumpScreen(tester);

    await tester.tap(find.text('Pick your deadline'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pick your deadline'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('choosing a date reports how many days it leaves', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Pick your deadline'));
    await tester.pumpAndSettle();

    // Accept the default the picker opens on, which is 28 days out.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pick your deadline'), findsNothing);
    expect(find.text('28 days to work with.'), findsOneWidget);
  });
}
