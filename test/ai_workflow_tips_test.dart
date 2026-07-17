import 'package:appstone/models/workflow_plan.dart';
import 'package:appstone/screens/ai_workflow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Tips are generated together with the plan and shown inline when a phase card
// is expanded - the same expandable-card pattern as the Paper Checker, with no
// second AI call and no loading. These cover that reveal, and that a phase
// carrying no tips (an older saved plan) stays a plain, non-expandable card.
void main() {
  Future<void> pumpWithPlan(WidgetTester tester, WorkflowPlan plan) async {
    SharedPreferences.setMockInitialValues({'workflow_plan_v1': plan.encode()});
    await tester.pumpWidget(const MaterialApp(home: AIWorkflowScreen()));
    await tester.pumpAndSettle();
  }

  WorkflowPlan planWith(List<WorkflowPhase> phases) => WorkflowPlan(
        startDate: DateTime.now(),
        totalDays: 20,
        assessment: 'Chapters 1-2 drafted.',
        paperName: 'capstone.docx',
        phases: phases,
      );

  testWidgets('a phase reveals its tips inline when expanded, with no loading', (
    tester,
  ) async {
    await pumpWithPlan(
      tester,
      planWith([
        WorkflowPhase(
          name: 'Chapter 3 - Technical Background',
          weight: 10,
          note: 'Describe the tech stack.',
          tips: 'Start with a hardware overview, then the software.',
        ),
      ]),
    );

    // Collapsed: the tips live in the tree only once expanded, so there is no
    // tips section and - crucially - no spinner, because nothing is fetched.
    expect(find.text('Tips for this phase'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Chapter 3 - Technical Background'));
    await tester.pumpAndSettle();

    expect(find.text('Tips for this phase'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    // Still no spinner after expanding: the tips came with the plan.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a phase with no tips stays a plain, non-expandable card', (
    tester,
  ) async {
    await pumpWithPlan(
      tester,
      planWith([
        WorkflowPhase(
          name: 'Prototype Development',
          weight: 8,
          note: 'Build the core feature.',
        ),
      ]),
    );

    expect(find.text('Prototype Development'), findsOneWidget);
    // No expandable tile means no expand arrow and no tips section to reveal.
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Tips for this phase'), findsNothing);
  });
}
