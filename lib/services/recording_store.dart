// Where a recording lives between "stop" and "upload", which is not the same
// thing on every platform: native recorders write a real file and hand back a
// path, while on web the clip stays in browser memory and `stop()` hands back a
// blob: URL instead. Both need reading back as bytes, but by different means -
// and dart:io can't even be imported into a web build - so the platform half
// lives behind this conditional export.
export 'recording_store_io.dart'
    if (dart.library.js_interop) 'recording_store_web.dart';
