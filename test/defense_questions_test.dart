import 'package:appstone/services/defense_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

// A practice run only rewrites its panel questions around the student's project
// when the student actually described one. These cover the half of that promise
// that can be checked without a network: with no context to rewrite from, the
// fixed questions must come back exactly as they went in, and no AI call may be
// attempted at all - a call here would fail in a test (no Firebase, no network),
// so a returned list is itself the proof that none was made.
void main() {
  const baseQuestions = <String>[
    'What is the main problem your capstone project aims to solve?',
    'How is your project different from existing solutions?',
    'What technology stack will you use and why?',
  ];

  test('no project context leaves the fixed questions untouched', () async {
    final tailored = await DefenseAiService().tailorQuestions(
      panelTitle: 'Title Defense',
      baseQuestions: baseQuestions,
      projectContext: '',
    );

    expect(tailored, baseQuestions);
  });

  test('a whitespace-only context still counts as none', () async {
    final tailored = await DefenseAiService().tailorQuestions(
      panelTitle: 'Oral Defense',
      baseQuestions: baseQuestions,
      projectContext: '   \n\t ',
    );

    expect(tailored, baseQuestions);
  });

  test('an empty question list is returned as-is, not sent off to be rewritten',
      () async {
    final tailored = await DefenseAiService().tailorQuestions(
      panelTitle: 'Final Defense',
      baseQuestions: const <String>[],
      projectContext: 'Project title: Appstone',
    );

    expect(tailored, isEmpty);
  });
}
