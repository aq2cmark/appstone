import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

// Web builds: the recorder ignores the path it's given and keeps the clip in
// browser memory, handing back a blob: URL from stop() instead.

// Only here to satisfy the recorder's required `path` argument - the browser
// never writes it anywhere.
Future<String> newRecordingLocation(String extension) async =>
    'answer.$extension';

// Fetching the blob: URL is how the bytes come back out of browser memory.
Future<Uint8List> readRecording(String location) async {
  return http.readBytes(Uri.parse(location));
}

// A blob: URL pins its data in memory until it's explicitly revoked - dropping
// the reference is NOT enough. One practice run can record twenty answers, so
// without this the whole session's audio piles up in the tab.
Future<void> disposeRecording(String location) async {
  try {
    web.URL.revokeObjectURL(location);
  } catch (_) {
    // Already revoked, or not a blob URL - nothing worth failing an answer for.
  }
}
