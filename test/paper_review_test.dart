import 'package:appstone/services/paper_checker_service.dart';
import 'package:flutter_test/flutter_test.dart';

// The rubric totals and the verdict band are what the student is actually
// shown, and both are arithmetic over data the AI returned. These cover the
// boundaries, where an off-by-one reads as a whole grade band.

RubricResult result(String name, int score, int max) => RubricResult(
      name: name,
      score: score,
      max: max,
      comment: '',
      issues: const [],
    );

// A review scoring [score] out of the rubric's real 50 points.
PaperReview reviewScoring(int score) => PaperReview(
      summary: '',
      sections: [result('Initial Pages', score, rubricMaxScore)],
    );

void main() {
  test('the rubric adds up to the 50 points the manual specifies', () {
    // Section 8.3 of the DCT CCS Capstone Manual totals 50. If a section's max
    // is edited without the others being adjusted, every percentage shown to a
    // student silently shifts.
    expect(rubricMaxScore, 50);
  });

  test('every rubric section carries criteria and a positive maximum', () {
    expect(manuscriptRubric, isNotEmpty);
    for (final section in manuscriptRubric) {
      expect(section.max, greaterThan(0), reason: section.name);
      expect(section.criteria, isNotEmpty, reason: section.name);
      expect(section.name.trim(), isNotEmpty);
    }
  });

  test('the total and maximum are the sums of the sections', () {
    final review = PaperReview(
      summary: 'Solid draft.',
      sections: [
        result('Initial Pages', 3, 4),
        result('Chapter 1 - Introduction', 8, 10),
        result('Manuscript Mechanics', 4, 5),
      ],
    );

    expect(review.totalScore, 15);
    expect(review.maxScore, 19);
    expect(review.percent, closeTo(15 / 19, 0.0001));
  });

  test('the verdict bands land on the right side of each boundary', () {
    // 90 / 75 / 50 percent are the cut-offs. Each pair here sits either side of
    // one of them.
    expect(reviewScoring(50).verdict, 'Excellent');
    expect(reviewScoring(45).verdict, 'Excellent'); // exactly 90%
    expect(reviewScoring(44).verdict, 'Good - minor revisions'); // 88%

    expect(reviewScoring(38).verdict, 'Good - minor revisions'); // 76%
    expect(reviewScoring(37).verdict, 'Needs major revisions'); // 74%

    expect(reviewScoring(25).verdict, 'Needs major revisions'); // exactly 50%
    expect(reviewScoring(24).verdict, 'Not ready - substantial work needed');

    expect(reviewScoring(0).verdict, 'Not ready - substantial work needed');
  });

  test('a review with no sections reports zero instead of dividing by zero', () {
    final review = PaperReview(summary: '', sections: const []);

    expect(review.totalScore, 0);
    expect(review.maxScore, 0);
    expect(review.percent, 0);
    expect(review.verdict, 'Not ready - substantial work needed');
  });
}
