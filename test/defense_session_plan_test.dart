import 'dart:math';

import 'package:appstone/services/defense_session_plan.dart';
import 'package:flutter_test/flutter_test.dart';

// A practice run plans its length and its follow-up slots before question one,
// so that most answers cost no AI call at all. Two things must hold for that to
// be safe: a run may never exceed the length its mode advertises, and a slot may
// never point at a question that does not exist.
void main() {
  // The real modes, from title_defense_screen.dart.
  const modes = <String, List<int>>{
    // name: [fixed questions, ceiling]
    'Title Defense': <int>[5, 8],
    'Oral Defense': <int>[10, 15],
    'Final Defense': <int>[15, 20],
  };

  test('every draw stays inside the range its mode advertises', () {
    final rng = Random(7);

    modes.forEach((name, sizes) {
      final base = sizes[0];
      final ceiling = sizes[1];

      for (var run = 0; run < 200; run++) {
        final plan = DefenseSessionPlan.draw(
          baseQuestionCount: base,
          maxQuestions: ceiling,
          random: rng,
        );

        expect(
          plan.targetQuestions,
          inInclusiveRange(base, ceiling),
          reason: '$name run $run drew ${plan.targetQuestions} questions',
        );
        // Every slot must be a real question in the fixed list, and no question
        // may be planned twice - a Set, so duplicates would silently shrink the
        // budget rather than fail loudly.
        for (final slot in plan.followUpSlots) {
          expect(slot, inInclusiveRange(0, base - 1));
        }
        expect(plan.followUpSlots.length, plan.followUpBudget);
      }
    });
  });

  test('runs vary in length rather than always drawing the same one', () {
    final rng = Random(11);
    final lengths = <int>{
      for (var run = 0; run < 60; run++)
        DefenseSessionPlan.draw(
          baseQuestionCount: 5,
          maxQuestions: 8,
          random: rng,
        ).targetQuestions,
    };

    expect(lengths.length, greaterThan(1));
  });

  test('a run with no follow-ups drawn asks the fixed list and nothing more',
      () {
    const plan = DefenseSessionPlan(
      baseQuestionCount: 5,
      followUpSlots: <int>{},
    );

    expect(plan.targetQuestions, 5);
    expect(plan.followUpBudget, 0);
    for (var i = 0; i < 5; i++) {
      expect(plan.allowsFollowUpAt(i), isFalse);
    }
  });

  test('a mode with no room above its fixed list never plans a follow-up', () {
    final plan = DefenseSessionPlan.draw(
      baseQuestionCount: 6,
      maxQuestions: 6,
      random: Random(3),
    );

    expect(plan.followUpSlots, isEmpty);
    expect(plan.targetQuestions, 6);
  });

  test('only the planned questions may be followed up', () {
    const plan = DefenseSessionPlan(
      baseQuestionCount: 5,
      followUpSlots: <int>{1, 3},
    );

    expect(plan.allowsFollowUpAt(1), isTrue);
    expect(plan.allowsFollowUpAt(3), isTrue);
    expect(plan.allowsFollowUpAt(0), isFalse);
    expect(plan.allowsFollowUpAt(2), isFalse);
    expect(plan.allowsFollowUpAt(4), isFalse);
    expect(plan.targetQuestions, 7);
  });
}
