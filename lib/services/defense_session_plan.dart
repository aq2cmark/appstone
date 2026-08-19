import 'dart:math';

// How long one practice run will be, and which of its questions the panel may
// spend a follow-up on.
//
// Before this, every answer cost an AI call: the panel asked the model "does
// this need a follow-up?" after each one, so a Title Defense run made 5-8 calls
// and an Oral Defense up to 15, all inside a few minutes. Both providers cap
// requests per MINUTE across the whole app, so a class practising together could
// trip that cap on their own.
//
// The run is planned up front instead. A length is drawn inside the range the
// mode already advertises ("5-8 questions"), which decides how many follow-ups
// there is room for, and those follow-ups are assigned to particular questions
// before the first one is asked. Every other answer moves the panel straight on
// with no AI call at all - so a five-question run can cost as little as one call
// (the final scoring) instead of six.
//
// What this does NOT do is decide the follow-ups themselves. A planned slot only
// buys the model the chance to ask: it still reads the answer and still declines
// when the answer was good, exactly as before. So a run can come in under its
// planned length, and no student is asked a follow-up they earned their way out
// of.
class DefenseSessionPlan {
  const DefenseSessionPlan({
    required this.baseQuestionCount,
    required this.followUpSlots,
  });

  // Draws a plan for one run.
  //
  // [baseQuestionCount] is the mode's fixed question list; [maxQuestions] is its
  // ceiling - 5 and 8 for Title Defense. The gap between them is the room for
  // follow-ups, and how much of that room this run uses is random, so two runs
  // of the same mode are not the same length. Sometimes it draws zero: a run
  // where the panel asks its list and nothing more.
  factory DefenseSessionPlan.draw({
    required int baseQuestionCount,
    required int maxQuestions,
    Random? random,
  }) {
    final base = baseQuestionCount < 0 ? 0 : baseQuestionCount;
    // A slot is a question that may be followed up, so there can never be more
    // slots than there are questions to attach them to.
    final room = (maxQuestions - base).clamp(0, base);
    if (room == 0) {
      return DefenseSessionPlan(
        baseQuestionCount: base,
        followUpSlots: const <int>{},
      );
    }

    final rng = random ?? Random();
    final budget = rng.nextInt(room + 1);
    // Which questions get the follow-ups is random too. Otherwise the panel
    // would always press hardest at the start, and a student who practised
    // twice would learn where the pressure falls.
    final available = <int>[for (var i = 0; i < base; i++) i]..shuffle(rng);

    return DefenseSessionPlan(
      baseQuestionCount: base,
      followUpSlots: available.take(budget).toSet(),
    );
  }

  final int baseQuestionCount;

  // Indices into the mode's fixed question list. An answer to one of these may
  // be sent to the model to judge; every other answer is not.
  final Set<int> followUpSlots;

  // The most questions this run will ask: the fixed list plus its follow-ups.
  // A run can end below this, never above it.
  int get targetQuestions => baseQuestionCount + followUpSlots.length;

  // How many follow-ups are still to be spent. Counts down as they are asked,
  // and also caps the chain when a follow-up's own answer gets followed up.
  int get followUpBudget => followUpSlots.length;

  bool allowsFollowUpAt(int questionIndex) =>
      followUpSlots.contains(questionIndex);
}
