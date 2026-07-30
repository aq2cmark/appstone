import 'package:appstone/services/defense_context_service.dart';
import 'package:flutter_test/flutter_test.dart';

// The project context the student types on the Defense Practice menu is what
// makes the AI panel's questions and scoring about their own capstone. These
// cover the two things that would quietly break that: a context that survives
// being saved and reloaded, and a prompt block that says nothing at all when the
// student added nothing (so a session without context prompts exactly as it did
// before the feature existed).
void main() {
  test('a context with nothing in it is empty and adds nothing to the prompt', () {
    const empty = DefenseContext();
    expect(empty.isEmpty, isTrue);
    expect(empty.promptBlock, isEmpty);
    expect(empty.filledCount, 0);
  });

  test('whitespace-only fields still count as no context', () {
    const blank = DefenseContext(projectTitle: '   ', notes: '\n\t');
    expect(blank.isEmpty, isTrue);
    expect(blank.promptBlock, isEmpty);
  });

  test('only the filled fields reach the prompt', () {
    const partial = DefenseContext(
      projectTitle: 'Appstone',
      techStack: 'Flutter and Firebase',
    );
    final prompt = partial.promptBlock;
    expect(partial.filledCount, 2);
    expect(prompt, contains('Project title: Appstone'));
    expect(prompt, contains('Technology stack: Flutter and Firebase'));
    // Nothing was said about users, so the model must not be handed an empty
    // label it has to interpret.
    expect(prompt, isNot(contains('Target users')));
    expect(prompt, isNot(contains('problem solved')));
  });

  test('a long field is capped so one student cannot blow up the prompt', () {
    final huge = DefenseContext(notes: 'a' * 5000);
    expect(huge.promptBlock.length, lessThan(1400));
    expect(huge.promptBlock, endsWith('...'));
  });

  test('encoding and decoding round-trips every field', () {
    const original = DefenseContext(
      projectTitle: 'Appstone',
      problem: 'Students cannot practice their defense.',
      techStack: 'Flutter, Firestore',
      targetUsers: 'CS students',
      notes: 'Voice answers use Whisper.',
    );
    final restored = DefenseContext.decode(original.encode());
    expect(restored.projectTitle, original.projectTitle);
    expect(restored.problem, original.problem);
    expect(restored.techStack, original.techStack);
    expect(restored.targetUsers, original.targetUsers);
    expect(restored.notes, original.notes);
  });

  test('a corrupt saved payload reads back as no context instead of throwing', () {
    // Starting a practice session must never fail because of what is on disk.
    expect(DefenseContext.decode('not json at all').isEmpty, isTrue);
    expect(DefenseContext.decode('[1,2,3]').isEmpty, isTrue);
    expect(DefenseContext.decode('{"projectTitle": 42}').isEmpty, isTrue);
  });
}
