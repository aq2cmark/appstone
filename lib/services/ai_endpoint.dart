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
//   flutter run --dart-define=NARAROUTER_ENDPOINT=http://127.0.0.1:5001/appstone-db/asia-east2/nararouter
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

const naraRouterEndpoint = String.fromEnvironment(
  'NARAROUTER_ENDPOINT',
  defaultValue: 'https://asia-east2-appstone-db.cloudfunctions.net/nararouter',
);

// Feature ids for the per-feature daily limit. Each gets its own allowance.
class AiFeature {
  static const titleGenerator = 'title-generator';
  static const paperChecker = 'paper-checker';
  // Covers both generating the plan and the per-chapter "tap for tips" help -
  // they share this one daily allowance.
  static const aiWorkflow = 'ai-workflow';
  static const defensePractice = 'defense-practice';
  // Transcribing a spoken defense answer. Routed to Whisper rather than a chat
  // model - see functions/index.js.
  static const speechToText = 'speech-to-text';
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

// The proxy answers 429 for two very different reasons, told apart by
// error.code:
//   'daily-limit' - this feature's daily allowance is spent; the response says
//                   how long until it resets.
//   'busy'        - NaraRouter's per-minute cap held even after the proxy waited
//                   it out. Nothing is used up; trying again shortly works.
const _busyFallback =
    'The AI service is busy right now. Please try again in a moment.';

// The proxy normally writes this sentence itself, wait included. This is the
// same sentence for the case where its response never arrived intact - a
// mangled body, an error page from something in between - so a student is told
// when they can come back even then.
String _dailyLimitFallback() =>
    "You've reached today's AI limit for this feature. You can use it again in "
    '${_untilDailyReset()}.';

// Everyone using Appstone is in the Philippines, and the proxy buckets the daily
// allowance against that same UTC+8 day (see QUOTA_UTC_OFFSET_HOURS in
// functions/index.js), so turns come back at midnight where the student is.
//
// Deliberately not the device's own zone: the server decides when the allowance
// resets, and a device set to another zone - or a wrong clock - would otherwise
// be told a time the server does not agree with.
const _quotaUtcOffset = Duration(hours: 8);

String _untilDailyReset() {
  final local = DateTime.now().toUtc().add(_quotaUtcOffset);
  final nextMidnight = DateTime.utc(local.year, local.month, local.day + 1);
  return _humanDuration(nextMidnight.difference(local));
}

// "6 hours 12 minutes", "12 minutes", "30 seconds". Rounded to whole units: this
// is written into a message once, not counted down, so it should not imply more
// precision than it has.
String _humanDuration(Duration left) {
  if (left.inMinutes < 1) {
    final seconds = left.inSeconds < 1 ? 1 : left.inSeconds;
    return '$seconds second${seconds == 1 ? '' : 's'}';
  }
  final hours = left.inHours;
  final minutes = left.inMinutes % 60;
  return <String>[
    if (hours > 0) '$hours hour${hours == 1 ? '' : 's'}',
    if (minutes > 0) '$minutes minute${minutes == 1 ? '' : 's'}',
  ].join(' ');
}

String? _errorCode(String responseBody) {
  try {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    return (body['error'] as Map?)?['code'] as String?;
  } catch (_) {
    return null;
  }
}

// True when a 429 means "too many requests right this minute" rather than
// "allowance spent" - i.e. the action is worth retrying, and cost the user
// nothing.
bool aiIsBusy(String responseBody) => _errorCode(responseBody) == 'busy';

// Pulls the server's rate-limit message out of a 429 response body, falling back
// to text matching whichever kind of limit it was.
String aiRateLimitMessage(String responseBody) {
  try {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    final error = body['error'] as Map?;
    final message = (error?['message'] as String?)?.trim();
    if (message != null && message.isNotEmpty) return message;
    if (error?['code'] == 'busy') return _busyFallback;
  } catch (_) {
    // fall through to the default
  }
  return _dailyLimitFallback();
}
