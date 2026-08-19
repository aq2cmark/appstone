import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_endpoint.dart';
import 'docx_layout_checker.dart';

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

// "Formatting and layout are consistent" is the one Manuscript Mechanics
// criterion the app can measure exactly - DocxLayoutChecker reads the real
// values out of the .docx. Those 2 points are computed, not graded, so the
// model never has to guess at formatting it cannot see. The section's other
// two criteria (organisation, grammar) stay with the model.
const String _mechanicsSection = 'Manuscript Mechanics';
const String _formattingCriterion = 'Formatting and layout are consistent';
const int _formattingPoints = 2;

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

  // [layout] is the deterministic .docx measurement the controller already
  // ran. Passing it in matters: the extracted text has no fonts, margins or
  // spacing left in it, so without these numbers the model is guessing at the
  // formatting half of "Manuscript Mechanics". Null for non-.docx uploads.
  Future<PaperReview> checkPaper({
    required String paperText,
    LayoutReport? layout,
  }) async {
    final result = await _generateJson(_buildPrompt(paperText, layout));

    final rawSections = (result['sections'] as List?) ?? const [];
    final sections = <RubricResult>[];
    for (var i = 0; i < manuscriptRubric.length; i++) {
      final rubric = manuscriptRubric[i];
      // Match by name when possible so a shuffled response still lines up;
      // fall back to positional order. Max always comes from the rubric, and
      // the score is clamped to it, so the total can never exceed 50.
      final match = _findSection(rawSections, rubric.name, i);
      final rawScore = (match?['score'] as num?)?.toInt() ?? 0;

      // Manuscript Mechanics is split when the formatting could be measured:
      // the model scores what it can read (organisation, grammar) and the
      // formatting points come from the file itself.
      final measured =
          rubric.name == _mechanicsSection && _usesMeasuredFormatting(layout);
      final modelMax = measured ? rubric.max - _formattingPoints : rubric.max;
      final formatting = measured ? _formattingScore(layout!) : 0;
      final comment = (match?['comment'] as String?)?.trim() ?? '';

      sections.add(
        RubricResult(
          name: rubric.name,
          max: rubric.max,
          score: rawScore.clamp(0, modelMax) + formatting,
          comment: measured
              ? '$comment Formatting measured from the file: '
                    '${layout!.passCount} of ${layout.total} layout rules '
                    'passed ($formatting of $_formattingPoints points).'
              : comment,
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

  // Only usable when the upload was a .docx AND the checker actually found
  // rules to measure; otherwise the model grades all 5 points as before.
  bool _usesMeasuredFormatting(LayoutReport? layout) =>
      layout != null && layout.total > 0;

  // Proportional, so a manuscript that gets most of the format right is not
  // scored as though it got none of it right.
  int _formattingScore(LayoutReport layout) =>
      (_formattingPoints * layout.passCount / layout.total).round().clamp(
        0,
        _formattingPoints,
      );

  // The formatting half of "Manuscript Mechanics" can only be judged from the
  // file's own XML - the extracted text has none of it left. Hand the model
  // the measurements instead of letting it guess at them.
  String _layoutEvidence(LayoutReport? layout) {
    if (layout == null) {
      return 'FORMATTING MEASUREMENTS: unavailable - this upload was not a '
          '.docx, so judge "Manuscript Mechanics" on organisation, fluidity '
          'and grammar alone. Do not speculate about fonts, margins or spacing.';
    }

    final buffer = StringBuffer()
      ..writeln(
        'FORMATTING MEASUREMENTS (read straight from the .docx file itself, '
        'not from the text below - treat these as authoritative fact):',
      );
    for (final rule in layout.rules) {
      final verdict = rule.pass ? 'PASS' : 'FAIL';
      buffer.writeln(
        '- ${rule.name}: required "${rule.expected}", '
        'found "${rule.actual}" - $verdict',
      );
    }
    buffer.write(
      'The app scores the "Formatting and layout are consistent" criterion '
      'itself from these measurements, so it is NOT yours to grade - that is '
      'why "Manuscript Mechanics" is listed below out of '
      '${5 - _formattingPoints} rather than 5. Grade only organisation and '
      'fluidity of ideas, and grammatical correctness. The manuscript text '
      'below has had all formatting stripped out, so never infer fonts, '
      'margins or spacing from it.',
    );
    return buffer.toString();
  }

  String _buildPrompt(String paperText, LayoutReport? layout) {
    // When formatting is measured the model must see the reduced max, and
    // must NOT see the criterion it is no longer grading - otherwise it
    // scores formatting anyway and those points get counted twice.
    final measured = _usesMeasuredFormatting(layout);
    final rubricText = manuscriptRubric
        .map((section) {
          final split = measured && section.name == _mechanicsSection;
          final criteria = section.criteria
              .where((c) => !split || c != _formattingCriterion)
              .map((c) => '   - $c')
              .join('\n');
          final max = split ? section.max - _formattingPoints : section.max;
          return '"${section.name}" (max $max points):\n$criteria';
        })
        .join('\n\n');

    final layoutText = _layoutEvidence(layout);

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

SCORING BANDS - apply these to every section, scaled to that section's max:
- Full marks: every criterion met, and you can point to where in the paper.
- About three quarters: criteria substantially met, minor gaps only.
- About half: the section exists but is generic or incomplete, with several
  criteria unmet.
- About a quarter: token content only - a heading with little behind it.
- Zero: the section is absent.
Award the band the evidence supports, not the effort it implies.

PROGRAM STANDARDS (DCT CCS Capstone Manual). These override any general
academic convention you may be used to:
- Required order: preliminary pages (title page, sign-off sheets,
  acknowledgement, abstract, table of contents), Chapter 1 Introduction,
  Chapter 2 Review of Related Literature/Systems, Chapter 3 Technical
  Background, Chapter 4 Methodology/Results/Discussion, Chapter 5 Conclusion
  and Recommendations, then References, Resource Persons, Glossary, Appendices.
- In-text citations use the author's first four letters plus the year, e.g.
  [MILL1991]. That IS the required format - never flag it as wrong, and never
  ask for APA, IEEE, or footnotes instead.
- The abstract must run 150-200 words, state the rationale and objectives,
  contain no citations or quotations, and must not open with
  "This paper/study/project...".

$layoutText

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
    final uri = Uri.parse(naraRouterEndpoint);

    final response = await http.post(
      uri,
      headers: await naraRouterHeaders(
        feature: AiFeature.paperChecker,
        sessionId: newAiSessionId(),
      ),
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        // Grading has to be repeatable: the same manuscript must not score
        // differently on two runs. Left unset, the model samples at the
        // provider's default and drifts a point or two per section, which
        // adds up across the rubric. Sampling still belongs in the creative
        // features (title ideas, defense questions) - just not in grading.
        'temperature': 0,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 429) {
      throw StateError(aiRateLimitMessage(response.body));
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

