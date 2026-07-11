import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_endpoint.dart';

// Calls our own /api/nararouter Vercel serverless function to turn selected
// filter chips into capstone title suggestions. That function forwards to
// NaraRouter (an OpenAI-compatible model gateway) with the API key attached
// server-side - NaraRouter's own API can't be called directly from a browser
// (no CORS, and their docs require server-side-only key usage).
class TitleGeneratorService {
  static const _model = 'mistral-large';

  Future<List<String>> generateTitles({
    required List<String> projectTypes,
    required List<String> targetUsers,
    required List<String> problemAreas,
    required List<String> technologies,
  }) async {
    final prompt = _buildPrompt(
      projectTypes: projectTypes,
      targetUsers: targetUsers,
      problemAreas: problemAreas,
      technologies: technologies,
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
  }) {
    final lines = <String>[];
    if (projectTypes.isNotEmpty) lines.add('Project type: ${projectTypes.join(', ')}');
    if (targetUsers.isNotEmpty) lines.add('Target users: ${targetUsers.join(', ')}');
    if (problemAreas.isNotEmpty) lines.add('Problem area: ${problemAreas.join(', ')}');
    if (technologies.isNotEmpty) lines.add('Technology: ${technologies.join(', ')}');

    return '''
You are helping a Computer Science capstone/thesis student brainstorm project titles.

Generate 5 concise, formal capstone project titles that reflect ALL of these selected elements:
${lines.join('\n')}

Return ONLY the 5 titles, one per line, no numbering and no extra commentary.
''';
  }
}
