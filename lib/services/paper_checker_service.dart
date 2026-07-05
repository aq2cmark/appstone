import 'dart:convert';

import 'package:http/http.dart' as http;

// One row of the official Capstone Manuscript rubric (Section 8.3 of the DCT
// CCS Capstone Manual). Kept as data so the exact wording drives BOTH the AI
// prompt and the on-screen criteria list - one source of truth, no drift.
class RubricSection {
  const RubricSection(this.name, this.max, this.criteria);

  final String name;
  final int max;
  final List<String> criteria;
}

// Section 8.3 "Rubric of Capstone Manuscript Grading" - totals 50 points.
const List<RubricSection> manuscriptRubric = [
  RubricSection('Initial Pages', 4, [
    'Table of contents is consistent',
    'Acknowledgement is brief and formal',
    'Abstract is brief but complete',
  ]),
  RubricSection('Chapter 1 - Introduction', 10, [
    'Introduction is intact and gives a clear overview of the entire project',
    'Statement of the Problem / Objectives is SMART',
    'Scope and Limitations are clearly defined',
  ]),
  RubricSection('Chapter 2 - Review of Related Literature', 8, [
    'Related literatures are recent and relevant',
    'Anchor theory provides a solid background',
    'Auxiliary theories are evident',
    'Sources are appropriately cited and noted',
    'Related studies are relevant and include global and local scope',
  ]),
  RubricSection('Chapter 3 - Technical Background', 8, [
    'Comprehensive discussion of the technologies (hardware/software) involved',
    'Discussion of related past projects and technologies',
  ]),
  RubricSection('Chapter 4 - Methodology', 10, [
    'Methodology strictly follows the SDLC',
    'Includes project management techniques appropriate to the project',
    'Requirements Specification is complete and answers the objectives',
    'Design tools used are relevant and based on the requirements',
    'Development plan is concrete and consistent with the design',
    'Testing techniques assess all aspects of the project',
    'Implementation plan is aligned with the objectives',
  ]),
  RubricSection('Final Pages', 3, [
    'Findings and Conclusions are attuned with the objectives',
    'Recommendations are feasible and practical',
    'Glossary terms are defined operationally and arranged alphabetically',
    'Bibliography follows the required format',
    'Appendices are relevant and support the principal content',
  ]),
  RubricSection('Appendices', 2, [
    'Deliverables compiled are intact and complete',
  ]),
  RubricSection('Manuscript Mechanics', 5, [
    'Organization and fluidity of ideas are apparent',
    'Formatting and layout are consistent',
    'All parts of the manuscript are grammatically correct',
  ]),
];

int get rubricMaxScore =>
    manuscriptRubric.fold(0, (sum, section) => sum + section.max);

// The AI's assessment of one rubric section against the uploaded paper.
class RubricResult {
  const RubricResult({
    required this.name,
    required this.score,
    required this.max,
    required this.comment,
    required this.issues,
  });

  final String name;
  final int score;
  final int max;
  final String comment;
  // The concrete "wrongs" - what's missing, weak, or non-compliant.
  final List<String> issues;
}

// The full pre-check: every rubric section plus a computed total and verdict.
class PaperReview {
  PaperReview({
    required this.summary,
    required this.sections,
  });

  final String summary;
  final List<RubricResult> sections;

  int get totalScore => sections.fold(0, (sum, s) => sum + s.score);
  int get maxScore => sections.fold(0, (sum, s) => sum + s.max);
  double get percent => maxScore == 0 ? 0 : totalScore / maxScore;

  // A plain-language band so students see where they stand at a glance. This
  // reflects manuscript readiness, not the official panel verdict (which also
  // weighs the software and oral defense).
  String get verdict {
    final p = percent;
    if (p >= 0.9) return 'Excellent';
    if (p >= 0.75) return 'Good - minor revisions';
    if (p >= 0.5) return 'Needs major revisions';
    return 'Not ready - substantial work needed';
  }
}

// Grades an uploaded capstone manuscript against Section 8.3 of the DCT CCS
// Capstone Manual. Like the app's other AI features, it calls our own
// /api/nararouter Vercel function, which forwards to NaraRouter (an
// OpenAI-compatible gateway) with the API key attached server-side.
class PaperCheckerService {
  static const _model = 'mistral-large';

  Future<PaperReview> checkPaper({required String paperText}) async {
    final result = await _generateJson(_buildPrompt(paperText));

    final rawSections = (result['sections'] as List?) ?? const [];
    final sections = <RubricResult>[];
    for (var i = 0; i < manuscriptRubric.length; i++) {
      final rubric = manuscriptRubric[i];
      // Match by name when possible so a shuffled response still lines up;
      // fall back to positional order. Max always comes from the rubric, and
      // the score is clamped to it, so the total can never exceed 50.
      final match = _findSection(rawSections, rubric.name, i);
      final rawScore = (match?['score'] as num?)?.toInt() ?? 0;
      sections.add(
        RubricResult(
          name: rubric.name,
          max: rubric.max,
          score: rawScore.clamp(0, rubric.max),
          comment: (match?['comment'] as String?)?.trim() ?? '',
          issues: ((match?['issues'] as List?) ?? const [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
      );
    }

    return PaperReview(
      summary: (result['summary'] as String?)?.trim() ?? '',
      sections: sections,
    );
  }

  Map<String, dynamic>? _findSection(List<dynamic> raw, String name, int index) {
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final itemName = (item['name'] as String?)?.toLowerCase() ?? '';
        if (itemName.contains(name.split(' - ').first.toLowerCase())) {
          return item;
        }
      }
    }
    if (index < raw.length && raw[index] is Map<String, dynamic>) {
      return raw[index] as Map<String, dynamic>;
    }
    return null;
  }

  String _buildPrompt(String paperText) {
    final rubricText = manuscriptRubric
        .map((section) {
          final criteria =
              section.criteria.map((c) => '   - $c').join('\n');
          return '"${section.name}" (max ${section.max} points):\n$criteria';
        })
        .join('\n\n');

    return '''
You are a strict but fair capstone panelist for a BS Information Technology
program. Grade the student's capstone MANUSCRIPT below against the official
manuscript rubric. Judge only what is actually present in the text. If a
required section appears to be missing, incomplete, or generic, say so plainly
and score it low - do not assume content that isn't there.

For EACH rubric section give:
- "score": an integer from 0 to that section's max points,
- "comment": one or two sentences explaining the score, referencing the paper,
- "issues": a list of specific, actionable problems (the "wrongs") the student
  must fix - missing parts, weak/vague writing, non-compliance with the
  criteria, citation gaps, etc. Use an empty list only if the section is truly
  solid.

RUBRIC (grade every section, keep this exact order and these names):

$rubricText

Also write a short overall "summary" (2-3 sentences) of the manuscript's
readiness and the most important things to fix first.

Respond ONLY with JSON in exactly this shape:
{
  "summary": "...",
  "sections": [
    {"name": "Initial Pages", "score": 0, "issues": ["..."], "comment": "..."}
  ]
}

=== STUDENT MANUSCRIPT START ===
$paperText
=== STUDENT MANUSCRIPT END ===
''';
  }

  Future<Map<String, dynamic>> _generateJson(String prompt) async {
    final uri = Uri.parse('/api/nararouter');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 429) {
      throw StateError(
        'The AI has hit its request limit for now. Please wait a bit and try '
        'again.',
      );
    }
    if (response.statusCode != 200) {
      throw StateError(
        'NaraRouter API error (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['choices']?[0]?['message']?['content'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw StateError('NaraRouter returned an empty response.');
    }
    final cleaned = text
        .trim()
        .replaceFirst(RegExp(r'^```(json)?'), '')
        .replaceFirst(RegExp(r'```$'), '')
        .trim();
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }
}
