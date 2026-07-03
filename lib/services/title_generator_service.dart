import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

// Calls the Gemini API (Google AI Studio) to turn selected filter chips
// into capstone title suggestions.
//
// The API key lives in Firebase Remote Config (parameter "gemini_api_key"),
// not in source or build args, so it can be set/rotated without a rebuild.
class TitleGeneratorService {
  static const _model = 'gemini-2.5-flash';

  Future<String> _fetchApiKey() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getString('gemini_api_key');
  }

  Future<List<String>> generateTitles({
    required List<String> projectTypes,
    required List<String> targetUsers,
    required List<String> problemAreas,
    required List<String> technologies,
  }) async {
    final apiKey = await _fetchApiKey();
    if (apiKey.isEmpty) {
      throw StateError(
        'AI title generation is not configured. Ask an admin to set '
        'the "gemini_api_key" parameter in Firebase Remote Config.',
      );
    }

    final prompt = _buildPrompt(
      projectTypes: projectTypes,
      targetUsers: targetUsers,
      problemAreas: problemAreas,
      technologies: technologies,
    );

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw StateError('Gemini API error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw StateError('Gemini returned no titles.');
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
