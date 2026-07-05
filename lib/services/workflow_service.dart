import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/workflow_plan.dart';

// Result of asking the AI to read a paper and plan the remaining work: a short
// read on the paper's current state plus the ordered, weighted phases.
class WorkflowGeneration {
  const WorkflowGeneration({required this.assessment, required this.phases});

  final String assessment;
  final List<WorkflowPhase> phases;
}

// Turns an uploaded capstone paper + a time budget into a suggested timeline.
// The AI decides which chapters still need work and how much relative effort
// each remaining phase deserves; the day-by-day scheduling is done locally in
// WorkflowPlan so it can re-adjust instantly as phases get checked off.
// Calls our /api/nararouter Vercel function (forwards to NaraRouter with the
// key server-side), same as the app's other AI features.
class WorkflowService {
  static const _model = 'mistral-large';

  Future<WorkflowGeneration> generate({
    required String paperText,
    required int totalDays,
  }) async {
    final result = await _generateJson(_buildPrompt(paperText, totalDays));

    final rawPhases = (result['phases'] as List?) ?? const [];
    final phases = rawPhases
        .whereType<Map<String, dynamic>>()
        .map(
          (p) => WorkflowPhase(
            name: (p['name'] as String?)?.trim().isNotEmpty == true
                ? (p['name'] as String).trim()
                : 'Phase',
            weight: (p['weight'] as num?)?.toDouble() ?? 1,
            note: (p['note'] as String?)?.trim() ?? '',
          ),
        )
        .where((p) => p.weight > 0)
        .toList();

    if (phases.isEmpty) {
      throw StateError('The AI did not return a usable plan. Please try again.');
    }

    return WorkflowGeneration(
      assessment: (result['assessment'] as String?)?.trim() ?? '',
      phases: phases,
    );
  }

  String _buildPrompt(String paperText, int totalDays) {
    return '''
You are a capstone project adviser for a BS Information Technology student.
Read the student's CURRENT capstone paper below and build a realistic plan to
FINISH it within $totalDays day(s) total, starting today.

First judge what is already present and how complete each part is (chapters,
methodology, prototype/software, testing, revisions). Then produce an ordered
list of the remaining work phases needed to complete the capstone.

For each phase give:
- "name": a short phase name (e.g. "Chapter 3 - Technical Background",
  "Prototype Development", "Testing & Debugging", "Final Defense Prep"),
- "weight": a number for the relative share of effort it needs (bigger = more
  time). Give already-strong parts a small weight and missing/weak parts a
  large weight. The weights do not need to add up to any specific total.
- "note": one short sentence on exactly what to do in that phase.

Use 4 to 8 phases in the logical order they should be worked on. Also give a
short "assessment" (1-2 sentences) of where the paper currently stands.

Respond ONLY with JSON in exactly this shape:
{
  "assessment": "...",
  "phases": [
    {"name": "Chapter 1 - Introduction", "weight": 10, "note": "..."}
  ]
}

=== STUDENT PAPER START ===
$paperText
=== STUDENT PAPER END ===
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
