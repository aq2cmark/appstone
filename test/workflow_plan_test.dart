import 'package:appstone/models/workflow_plan.dart';
import 'package:flutter_test/flutter_test.dart';

// WorkflowPlan does all its own date arithmetic and hands out the remaining
// days by weight, so the failures worth covering are arithmetic ones: a phase
// that gets zero days, an allocation that doesn't add up to the budget, or a
// finished phase whose leftover time never reaches the phases still to come.
// `now` is injectable, so every expectation here is an exact date rather than
// something that drifts with the calendar.

WorkflowPhase phase(String name, double weight,
        {bool done = false, DateTime? on, String tips = ''}) =>
    WorkflowPhase(
      name: name,
      weight: weight,
      note: '',
      tips: tips,
      done: done,
      completedOn: on,
    );

WorkflowPlan planOf(List<WorkflowPhase> phases, {int totalDays = 30}) =>
    WorkflowPlan(
      startDate: DateTime(2026, 1, 1),
      totalDays: totalDays,
      assessment: 'Chapters 1-3 drafted.',
      paperName: 'capstone.docx',
      phases: phases,
    );

void main() {
  test('the deadline is the start date plus the day budget', () {
    expect(planOf([phase('A', 1)]).deadline, DateTime(2026, 1, 31));
  });

  test('days remaining counts from the given day, not the start date', () {
    final plan = planOf([phase('A', 1)]);

    expect(plan.daysRemaining(DateTime(2026, 1, 1)), 30);
    expect(plan.daysRemaining(DateTime(2026, 1, 21)), 10);
    // Past the deadline it goes negative rather than clamping - the screen
    // needs to be able to say "overdue".
    expect(plan.daysRemaining(DateTime(2026, 2, 5)), -5);
  });

  test('remaining days are split by weight and land exactly on the deadline', () {
    // Weights 1:1:2 over a 30-day budget. The heavier phase must get roughly
    // double, and the rounded-off remainder has to be handed back out so the
    // parts still sum to 30 - otherwise the plan quietly finishes early.
    final plan = planOf([phase('A', 1), phase('B', 1), phase('C', 2)]);
    final schedule = plan.schedule(DateTime(2026, 1, 1));

    expect(schedule.map((s) => s.days).toList(), [8, 7, 15]);
    expect(schedule.fold<int>(0, (sum, s) => sum + s.days), 30);
    expect(schedule.first.start, DateTime(2026, 1, 1));
    expect(schedule.last.end, DateTime(2026, 1, 31));
    expect(plan.projectedFinish(DateTime(2026, 1, 1)), plan.deadline);
    expect(plan.isOnTrack(DateTime(2026, 1, 1)), isTrue);
  });

  test('each phase runs from where the previous one ended', () {
    final plan = planOf([phase('A', 1), phase('B', 1), phase('C', 2)]);
    final schedule = plan.schedule(DateTime(2026, 1, 1));

    expect(schedule[0].end, schedule[1].start);
    expect(schedule[1].end, schedule[2].start);
  });

  test('finishing a phase early hands its leftover days to the ones left', () {
    // A was budgeted 8 days but was ticked off on day 2. B and C should now
    // share the whole rest of the window - if they don't, finishing early
    // silently buys the student nothing.
    final plan = planOf([
      phase('A', 1, done: true, on: DateTime(2026, 1, 2)),
      phase('B', 1),
      phase('C', 2),
    ]);
    final schedule = plan.schedule(DateTime(2026, 1, 2));

    expect(schedule[0].days, 0);
    expect(schedule[0].start, DateTime(2026, 1, 2));
    expect(schedule[0].end, DateTime(2026, 1, 2));
    // B had 7 days on the original split and now has more.
    expect(schedule[1].days, greaterThan(7));
    expect(schedule[1].days + schedule[2].days, 29);
    expect(schedule.last.end, DateTime(2026, 1, 31));
    expect(plan.isOnTrack(DateTime(2026, 1, 2)), isTrue);
  });

  test('a done phase with no completion date falls back to today', () {
    final plan = planOf([phase('A', 1, done: true), phase('B', 1)]);
    final schedule = plan.schedule(DateTime(2026, 1, 5));

    expect(schedule[0].start, DateTime(2026, 1, 5));
    expect(schedule[0].isOverdue, isFalse);
  });

  test('a zero-weight phase still gets a day rather than none', () {
    // Nothing stops the AI returning a 0 weight, and a phase scheduled for
    // zero days would render as an empty window.
    final schedule = planOf([phase('A', 0), phase('B', 1)]).schedule(
      DateTime(2026, 1, 1),
    );

    expect(schedule[0].days, greaterThanOrEqualTo(1));
    expect(schedule[1].days, greaterThanOrEqualTo(1));
  });

  test('too little time overruns the deadline and is flagged, not squeezed', () {
    // Three phases into a one-day budget can't fit. Every phase still gets its
    // minimum day and the plan runs past the deadline, which is what the screen
    // shows as "behind schedule".
    final plan = planOf([
      phase('A', 1),
      phase('B', 1),
      phase('C', 1),
    ], totalDays: 1);
    final schedule = plan.schedule(DateTime(2026, 1, 1));

    expect(schedule.every((s) => s.days >= 1), isTrue);
    expect(schedule.last.isOverdue, isTrue);
    expect(plan.isOnTrack(DateTime(2026, 1, 1)), isFalse);
    expect(plan.projectedFinish(DateTime(2026, 1, 1)).isAfter(plan.deadline), isTrue);
  });

  test('a plan opened after its start date schedules from today', () {
    // Reopening a plan on day 11 must not schedule the remaining work into
    // days that have already gone by.
    final plan = planOf([phase('A', 1), phase('B', 1)]);
    final schedule = plan.schedule(DateTime(2026, 1, 11));

    expect(schedule.first.start, DateTime(2026, 1, 11));
    expect(schedule.fold<int>(0, (sum, s) => sum + s.days), 20);
  });

  test('progress counts the ticked-off phases', () {
    final plan = planOf([
      phase('A', 1, done: true),
      phase('B', 1),
      phase('C', 1, done: true),
      phase('D', 1),
    ]);

    expect(plan.doneCount, 2);
    expect(plan.totalCount, 4);
    expect(plan.progress, 0.5);
  });

  test('a plan with no phases has zero progress instead of dividing by zero', () {
    final plan = planOf([]);

    expect(plan.progress, 0);
    expect(plan.schedule(DateTime(2026, 1, 1)), isEmpty);
    expect(plan.projectedFinish(DateTime(2026, 1, 1)), plan.deadline);
  });

  test('a plan survives the round trip through saved storage', () {
    // The plan is persisted as a JSON string between sessions, so anything the
    // encoder drops is work the student loses.
    final original = planOf([
      phase('A', 1.5, done: true, on: DateTime(2026, 1, 3), tips: 'Do X, then Y.'),
      phase('B', 2),
    ]);

    final restored = WorkflowPlan.decode(original.encode())!;

    expect(restored.startDate, original.startDate);
    expect(restored.totalDays, 30);
    expect(restored.assessment, 'Chapters 1-3 drafted.');
    expect(restored.paperName, 'capstone.docx');
    expect(restored.phases.length, 2);
    expect(restored.phases[0].weight, 1.5);
    expect(restored.phases[0].done, isTrue);
    expect(restored.phases[0].completedOn, DateTime(2026, 1, 3));
    // Tips are generated with the plan and shown on tap, so they have to
    // survive the save too - otherwise the student loses them on reopen.
    expect(restored.phases[0].tips, 'Do X, then Y.');
    expect(restored.phases[1].name, 'B');
    expect(restored.phases[1].done, isFalse);
    // And it still schedules to the same days it did before saving.
    expect(
      restored.schedule(DateTime(2026, 1, 3)).map((s) => s.days).toList(),
      original.schedule(DateTime(2026, 1, 3)).map((s) => s.days).toList(),
    );
  });

  test('unreadable saved data gives back null instead of throwing', () {
    // Whatever is in storage is not guaranteed to still be a plan.
    expect(WorkflowPlan.decode('not json at all'), isNull);
    expect(WorkflowPlan.decode(''), isNull);
    expect(WorkflowPlan.decode('[1,2,3]'), isNull);
  });
}
