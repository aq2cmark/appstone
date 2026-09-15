import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

// Native builds: the recorder needs a real path to write to, and the clip is a
// file on disk afterwards.

// A fresh temp path per answer, so a slow upload can never be overwritten by
// the next recording starting.
Future<String> newRecordingLocation(String extension) async {
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  return '${dir.path}${Platform.pathSeparator}answer_$stamp.$extension';
}

Future<Uint8List> readRecording(String location) async {
  return File(location).readAsBytes();
}

// Best-effort cleanup once the bytes are safely uploaded. A student may record
// twenty answers in one run, and leaving every clip behind on their phone would
// be rude - but a failed delete is never worth losing the answer over.
Future<void> disposeRecording(String location) async {
  try {
    final file = File(location);
    if (file.existsSync()) await file.delete();
  } catch (_) {
    // Temp files get cleared by the OS eventually.
  }
}
