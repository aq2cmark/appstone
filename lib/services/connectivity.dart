// Whether the device currently has a network connection.
//
// Only the browser can answer this cheaply and without a round trip, so the
// real implementation is the web one; native builds report "online" and let the
// normal error handling in each service surface a failure instead. Same shape
// as recording_store.dart: a conditional export rather than a runtime check, so
// dart:js_interop never reaches a native build.
//
// This is a *hint*, not a guarantee. `navigator.onLine` is false only when the
// browser knows there is no network; it can still read true on a captive portal
// or a wifi network with no route out. Nothing here is allowed to gate access -
// it drives an advisory banner, and every request still fails through
// friendlyErrorMessage() the way it always did.
export 'connectivity_io.dart'
    if (dart.library.js_interop) 'connectivity_web.dart';
