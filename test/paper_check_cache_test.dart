// The paper checker reuses a stored result when the same manuscript is
// uploaded again, which is the only way the same document reliably scores the
// same twice - an LLM re-run drifts by a point or two per section even at
// temperature 0. That reuse hinges entirely on the content fingerprint, so
// these tests pin its behaviour.
import 'package:appstone/services/docx_layout_checker.dart';
import 'package:appstone/services/paper_check_controller.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutReport layoutWith(int passing) => LayoutReport([
  for (var i = 0; i < 11; i++)
    LayoutRule(
      name: 'Rule $i',
      expected: 'expected',
      actual: i < passing ? 'expected' : 'wrong',
      pass: i < passing,
    ),
]);

const _paper = 'Chapter 1 - Introduction. This capstone project addresses...';

void main() {
  test('the same manuscript always fingerprints the same', () {
    expect(
      PaperCheckController.contentHashOf(_paper, layoutWith(11)),
      PaperCheckController.contentHashOf(_paper, layoutWith(11)),
    );
  });

  test('an edited manuscript is graded fresh', () {
    expect(
      PaperCheckController.contentHashOf('$_paper And a new sentence.',
          layoutWith(11)),
      isNot(PaperCheckController.contentHashOf(_paper, layoutWith(11))),
    );
  });

  test('fixing the formatting alone is enough to re-grade', () {
    // Manuscript Mechanics is scored partly from the layout measurements, so
    // the same words with different formatting is a different grade.
    expect(
      PaperCheckController.contentHashOf(_paper, layoutWith(9)),
      isNot(PaperCheckController.contentHashOf(_paper, layoutWith(11))),
    );
  });

  test('a non-docx upload never collides with a measured one', () {
    expect(
      PaperCheckController.contentHashOf(_paper, null),
      isNot(PaperCheckController.contentHashOf(_paper, layoutWith(11))),
    );
  });

  test('the fingerprint is a full sha256', () {
    final hash = PaperCheckController.contentHashOf(_paper, layoutWith(11));
    expect(hash, hasLength(64));
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
  });
}
