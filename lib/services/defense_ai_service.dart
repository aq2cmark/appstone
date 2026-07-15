import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_endpoint.dart';

// One question/answer pair from a practice session, used to build the
// final transcript sent to the AI for scoring.
class QaExchange {
  const QaExchange({required this.question, required this.answer});

  final String question;
  final String answer;
}

// The AI's decision on whether an answer needs a follow-up question.
class DefenseFollowUp {
  const DefenseFollowUp({required this.hasGap, required this.followUpQuestion});

  final bool hasGap;
  final String followUpQuestion;
}

// The AI's rating of a full practice session across five metrics, plus a
// plain-language explanation of why it gave those scores.
class DefenseScore {
  const DefenseScore({
    required this.overall,
    required this.clarity,
    required this.technical,
    required this.confidence,
    required this.completeness,
    required this.presentation,
    required this.insights,
  });

  final int overall;
  final int clarity;
  final int technical;
  final int confidence;
  final int completeness;
  final int presentation;
  final String insights;
}

// Runs an adaptive mock defense: decides whether each answer needs a
// follow-up question, then scores the whole session once it's done.
// Calls our own /api/nararouter Vercel serverless function, which forwards
// to NaraRouter (an OpenAI-compatible model gateway) with the API key
// attached server-side. NaraRouter's own API can't be called directly from a
// browser (no CORS, and their docs require server-side-only key usage), so
// this proxy is required, not optional.
class DefenseAiService {
  static const _model = 'mistral-large';

  // One id for this whole practice session (this service is created once per
  // session), so all of its AI calls count as a SINGLE session against the cap.
  final String _sessionId = newAiSessionId();

  // Exposed so transcribing this run's spoken answers can reuse the same id and
  // ride along inside this one session, rather than counting as its own.
  String get sessionId => _sessionId;

  Future<Map<String, dynamic>> _generateJson(String prompt) async {
    final uri = Uri.parse(naraRouterEndpoint);

    final response = await http.post(
      uri,
      headers: await naraRouterHeaders(
        feature: AiFeature.defensePractice,
        sessionId: _sessionId,
      ),
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
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
    // Some models wrap JSON in a markdown code fence despite json_object mode.
    final cleaned = text
        .trim()
        .replaceFirst(RegExp(r'^```(json)?'), '')
        .replaceFirst(RegExp(r'```$'), '')
        .trim();
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  Future<DefenseFollowUp> evaluateAnswer({
    required String panelTitle,
    required String question,
    required String answer,
    required int followUpsSoFarOnTopic,
    required int maxFollowUpsPerTopic,
  }) async {
    final result = await _generateJson('''
You are a strict capstone panelist conducting a $panelTitle practice defense.

Question asked: "$question"
Student's answer: "$answer"

This topic has already had $followUpsSoFarOnTopic follow-up question(s) out of a maximum
of $maxFollowUpsPerTopic before the panel must move on regardless.

Decide if the answer has real gaps: missing justification, vague claims, or details a
panelist would reasonably press further on. If the answer already covers the question
well, do not invent a follow-up just to have one. Also, if the student seems to genuinely
not know the answer, is repeating themselves, or you've already pressed this same topic
once or more, prefer to move on to a new topic instead of asking another narrow follow-up
on the same point - set hasGap to false in that case, even if the answer wasn't perfect.

Respond ONLY with JSON in this exact shape:
{"hasGap": true or false, "followUpQuestion": "a short, specific follow-up question, or empty string if hasGap is false"}
''');

    return DefenseFollowUp(
      hasGap: result['hasGap'] as bool? ?? false,
      followUpQuestion: result['followUpQuestion'] as String? ?? '',
    );
  }

  Future<DefenseScore> scoreSession({
    required String panelTitle,
    required List<QaExchange> exchanges,
  }) async {
    final transcript = exchanges
        .map((exchange) => 'Q: ${exchange.question}\nA: ${exchange.answer}')
        .join('\n\n');

    final result = await _generateJson('''
You are grading a Computer Science capstone student's $panelTitle practice defense.

Transcript:
$transcript

Rate the student's performance as integers from 0 to 100 for each metric:
- clarity: how clear and understandable the answers were
- technical: depth and accuracy of technical explanation
- confidence: how confident and decisive the answers sounded
- completeness: whether answers fully addressed each question
- presentation: structure and professionalism of the answers
Also give an overall score from 0 to 100.

Also write "insights": 2-4 sentences in plain language a student would understand,
explaining WHY these scores were given. Reference specific things they actually said -
concrete strengths and concrete weaknesses - not generic praise or criticism.

Respond ONLY with JSON in this exact shape:
{"overall": 0, "clarity": 0, "technical": 0, "confidence": 0, "completeness": 0, "presentation": 0, "insights": "..."}
''');

    return DefenseScore(
      overall: (result['overall'] as num?)?.toInt() ?? 0,
      clarity: (result['clarity'] as num?)?.toInt() ?? 0,
      technical: (result['technical'] as num?)?.toInt() ?? 0,
      confidence: (result['confidence'] as num?)?.toInt() ?? 0,
      completeness: (result['completeness'] as num?)?.toInt() ?? 0,
      presentation: (result['presentation'] as num?)?.toInt() ?? 0,
      insights: result['insights'] as String? ?? '',
    );
  }
}
