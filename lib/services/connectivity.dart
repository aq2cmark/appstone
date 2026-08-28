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
// or a wifi network with no route out. So it drives advisory banners, and every
// request still fails through friendlyErrorMessage() the way it always did.
//
// One deliberate exception: `login_page.dart` refuses to submit a sign-in while
// this reads false. That is sound because the unreliable direction is only
// `true` - a false reading means the browser knows there is no network, and the
// attempt could do nothing but time out. It is a shortcut past a wait, not an
// authorisation decision, and the sign-in failure paths still classify the
// error themselves rather than trusting this check.
export 'connectivity_io.dart'
    if (dart.library.js_interop) 'connectivity_web.dart';
