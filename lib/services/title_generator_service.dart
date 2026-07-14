import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_endpoint.dart';

// Turns the selected filter chips into capstone title suggestions, via the same
// Firebase proxy the app's other AI features use (the key stays server-side).
//
// This feature alone is routed on to Groq rather than NaraRouter - Groq's free
// tier allows 30 requests/minute against NaraRouter's 10, and this is the
// lightest call we make, so moving it frees NaraRouter up for the heavier
// features. The routing is by feature id, server-side; see functions/index.js.
class TitleGeneratorService {
  static const _model = 'openai/gpt-oss-20b';

  Future<List<String>> generateTitles({
    required List<String> projectTypes,
    required List<String> targetUsers,
    required List<String> problemAreas,
    required List<String> technologies,
    String others = '',
  }) async {
    final prompt = _buildPrompt(
      projectTypes: projectTypes,
      targetUsers: targetUsers,
      problemAreas: problemAreas,
      technologies: technologies,
      others: others,
    );

    final uri = Uri.parse(naraRouterEndpoint);

    final response = await http.post(
      uri,
      headers: await naraRouterHeaders(
        feature: AiFeature.titleGenerator,
        sessionId: newAiSessionId(),
      ),
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        // gpt-oss models think before answering, and those hidden reasoning
        // tokens still count against Groq's free 200K/day. Naming a project
        // needs no deliberation, so keep it minimal - this roughly doubles how
        // many generations the daily allowance covers.
        'reasoning_effort': 'low',
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
      throw StateError('NaraRouter returned no titles.');
    }

    return text
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^[\s\-\d.]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String _buildPrompt({
    required List<String> projectTypes,
    required List<String> targetUsers,
    required List<String> problemAreas,
    required List<String> technologies,
    String others = '',
  }) {
    final lines = <String>[];
    if (projectTypes.isNotEmpty) lines.add('Project type: ${projectTypes.join(', ')}');
    if (targetUsers.isNotEmpty) lines.add('Target users: ${targetUsers.join(', ')}');
    if (problemAreas.isNotEmpty) lines.add('Problem area: ${problemAreas.join(', ')}');
    if (technologies.isNotEmpty) lines.add('Technology: ${technologies.join(', ')}');
    // The student's own words. Last so it reads as the closing instruction, and
    // called out as most important - if they bothered to type something specific
    // it should outrank a chip they tapped.
    if (others.isNotEmpty) lines.add('Student\'s own request: $others');

    return '''
You are helping an Information Technology capstone/thesis student brainstorm
project titles. Keep in mind they are students: suggest titles that are feasible
for them to actually build.

Generate 5 concise, formal capstone project titles that reflect ALL of these
selected elements:
${lines.join('\n')}

The elements above belong together - treat them as ONE coherent project, not a
list of separate ideas to combine arbitrarily. If the student wrote their own
request, weight it most heavily.

Return ONLY the 5 titles, one per line, no numbering and no extra commentary.
''';
  }
}
