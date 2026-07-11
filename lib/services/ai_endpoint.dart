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
import 'package:firebase_auth/firebase_auth.dart';

const naraRouterEndpoint = String.fromEnvironment(
  'NARAROUTER_ENDPOINT',
  defaultValue: 'https://us-central1-appstone-db.cloudfunctions.net/nararouter',
);

// Headers for a NaraRouter proxy call: JSON plus the caller's Firebase login
// token. The proxy now requires that token (only signed-in users may use the
// AI features), so a random script that finds the URL is refused.
Future<Map<String, String>> naraRouterHeaders() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
