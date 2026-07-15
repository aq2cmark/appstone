import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_endpoint.dart';

// Turns a recorded defense answer into text with Whisper, through the same
// Firebase proxy every other AI feature uses (the proxy routes this feature on
// to Groq - see functions/index.js).
//
// The recording travels as base64 inside normal JSON rather than as a multipart
// upload. Whisper itself wants multipart, but the proxy rebuilds that form
// server-side, which lets transcription reuse the proxy's existing auth, CORS
// and rate-limit handling instead of needing a second endpoint that repeats all
// of it.
class SpeechTranscriptionService {
  const SpeechTranscriptionService(this.sessionId);

  static const _model = 'whisper-large-v3';

  // The defense run's session id, deliberately shared.
  //
  // One run asks up to 20 questions, so counting each answer's transcription as
  // its own session would burn the whole 5-per-day allowance on a single
  // practice. Reusing the run's id makes every transcription in it part of that
  // one session, exactly like the run's other AI calls.
  final String sessionId;

  // Returns the spoken text, or an empty string when the recording held no
  // speech (Whisper answers silence with punctuation or nothing at all).
  Future<String> transcribe({
    required Uint8List audio,
    required String mimeType,
    required String filename,
  }) async {
    final response = await http.post(
      Uri.parse(naraRouterEndpoint),
      headers: await naraRouterHeaders(
        feature: AiFeature.speechToText,
        sessionId: sessionId,
      ),
      body: jsonEncode({
        'audio': base64Encode(audio),
        'mimeType': mimeType,
        'filename': filename,
        'model': _model,
        'language': 'en',
      }),
    );

    if (response.statusCode == 429) {
      throw StateError(aiRateLimitMessage(response.body));
    }
    if (response.statusCode != 200) {
      throw StateError(
        'Could not transcribe your answer (${response.statusCode}). '
        'You can type it instead.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (data['text'] as String? ?? '').trim();
    // Whisper transcribes a silent clip as a lone "." or similar - that's not
    // an answer, and it shouldn't land in the student's text box.
    if (text.isEmpty || RegExp(r'^[.\s,!?-]*$').hasMatch(text)) return '';
    return text;
  }
}
