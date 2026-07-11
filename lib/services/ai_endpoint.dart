// The deployed Firebase Cloud Function that proxies the app's AI calls to
// NaraRouter with the API key attached server-side (see functions/index.js).
//
// This is a FIXED address that does not change when the app itself moves hosts
// (local dev, Vercel, or Hostinger later), because the backend lives in the
// Firebase project - not alongside the web build. That's the whole point of
// moving the proxy to Firebase.
//
// It can be overridden at build time if ever needed (e.g. to hit the local
// Functions emulator):
//   flutter run --dart-define=NARAROUTER_ENDPOINT=http://127.0.0.1:5001/appstone-db/us-central1/nararouter
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

const naraRouterEndpoint = String.fromEnvironment(
  'NARAROUTER_ENDPOINT',
  defaultValue: 'https://us-central1-appstone-db.cloudfunctions.net/nararouter',
);

// Feature ids for the per-feature daily limit. Each gets its own allowance.
class AiFeature {
  static const titleGenerator = 'title-generator';
  static const paperChecker = 'paper-checker';
  static const aiWorkflow = 'ai-workflow';
  static const defensePractice = 'defense-practice';
}

final _random = Random();

// A random id identifying one AI "session/use". Single-shot features generate a
// fresh one per action; a defense-practice run reuses ONE id across all its
// calls so the whole run counts as a single session against the daily limit.
String newAiSessionId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}';

// Headers for a NaraRouter proxy call: JSON, the caller's Firebase login token
// (the proxy requires it), and the feature + session id used for the per-feature
// daily rate limit.
Future<Map<String, String>> naraRouterHeaders({
  String? feature,
  String? sessionId,
}) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
    if (feature != null) 'X-AI-Feature': feature,
    if (sessionId != null) 'X-AI-Session': sessionId,
  };
}

// Pulls the server's rate-limit message out of a 429 response body (e.g. the
// per-feature daily-limit text), with a friendly fallback.
String aiRateLimitMessage(String responseBody) {
  try {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    final message = (body['error'] as Map?)?['message'] as String?;
    if (message != null && message.isNotEmpty) return message;
  } catch (_) {
    // fall through to the default
  }
  return "You've reached today's AI limit for this feature. Try again tomorrow.";
}
