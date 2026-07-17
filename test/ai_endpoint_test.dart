import 'package:appstone/services/ai_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

// The proxy answers 429 for two reasons that must never be confused: 'busy'
// (the provider's per-minute cap held, nothing was spent, retrying works) and
// 'daily-limit' (the student's allowance really is gone). Telling a student to
// come back tomorrow when they could retry in ten seconds is the bug these
// cover, along with the reverse.
void main() {
  test('a busy 429 is recognised as worth retrying', () {
    expect(aiIsBusy('{"error":{"code":"busy","message":"AI service is busy."}}'), isTrue);
  });

  test('a spent-allowance 429 is not treated as busy', () {
    expect(
      aiIsBusy('{"error":{"code":"daily-limit","message":"Limit reached."}}'),
      isFalse,
    );
  });

  test('a body that is not the expected shape is not treated as busy', () {
    // An upstream can fail in ways that never reach our JSON envelope, and
    // guessing "busy" would put the app into a retry loop.
    expect(aiIsBusy('<html>502 Bad Gateway</html>'), isFalse);
    expect(aiIsBusy(''), isFalse);
    expect(aiIsBusy('{"error":"a plain string"}'), isFalse);
    expect(aiIsBusy('{"error":{}}'), isFalse);
  });

  test('the server message is shown to the student when there is one', () {
    // The function writes the friendly wording, including the actual per-day
    // number, so the app must not paper over it with its own copy.
    expect(
      aiRateLimitMessage(
        '{"error":{"code":"daily-limit","message":"You have reached today\'s limit for this feature (5 per day)."}}',
      ),
      "You have reached today's limit for this feature (5 per day).",
    );
  });

  test('a busy 429 with no message falls back to busy wording, not tomorrow', () {
    final message = aiRateLimitMessage('{"error":{"code":"busy"}}');

    expect(message.toLowerCase(), contains('busy'));
    expect(message.toLowerCase(), isNot(contains('tomorrow')));
  });

  test('an unreadable 429 falls back to the daily-limit wording', () {
    expect(aiRateLimitMessage('not json').toLowerCase(), contains('tomorrow'));
    expect(aiRateLimitMessage('{"error":{}}').toLowerCase(), contains('tomorrow'));
  });

  test('a blank server message falls back rather than showing nothing', () {
    expect(aiRateLimitMessage('{"error":{"message":"   "}}'), isNotEmpty);
  });

  test('session ids are unique across a rapid burst', () {
    // Two calls in the same microsecond would share an id, and the second
    // would ride free on the first's session - or worse, collide across users.
    final ids = List.generate(500, (_) => newAiSessionId());

    expect(ids.toSet().length, 500);
  });

  test('every AI feature has its own id, so allowances stay separate', () {
    const features = [
      AiFeature.titleGenerator,
      AiFeature.paperChecker,
      AiFeature.aiWorkflow,
      AiFeature.defensePractice,
      AiFeature.speechToText,
    ];

    expect(features.toSet().length, features.length);
    expect(features.every((f) => f.isNotEmpty), isTrue);
    // The function truncates the header at 40 characters before bucketing.
    expect(features.every((f) => f.length <= 40), isTrue);
  });

  test('the endpoint points at the deployed proxy, never straight at a provider', () {
    // Shipping a build that calls a provider directly would put the API key in
    // the browser. The default must stay the Cloud Function.
    expect(naraRouterEndpoint, contains('cloudfunctions.net/nararouter'));
    expect(naraRouterEndpoint, isNot(contains('api.groq.com')));
    expect(naraRouterEndpoint, isNot(contains('router.bynara.id')));
    // The region is compile-time here and must match the deployed functions.
    expect(naraRouterEndpoint, contains('asia-east2'));
  });
}
