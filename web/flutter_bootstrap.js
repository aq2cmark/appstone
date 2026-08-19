// Custom Flutter web bootstrap.
//
// This file replaces the one Flutter generates. The `{{...}}` tokens are filled
// in by `flutter build web`; everything else here is ours.
//
// Why it exists: by default the engine loads CanvasKit from
// https://www.gstatic.com/flutter-canvaskit/<engine-revision>/. That is a
// cross-origin URL, so `flutter_service_worker.js` cannot cache it - it only
// caches same-origin entries listed in its own RESOURCES map. The result was
// that a student with no connection got a maroon splash that never resolved:
// main.dart.js was cached, but the renderer it needs was not.
//
// Pinning `canvasKitBaseUrl` to the local `canvaskit/` folder - which
// `flutter build web` already copies into build/web and already lists in
// RESOURCES - means the renderer is served from our own origin, the service
// worker caches it on the first successful load, and the app boots offline
// afterwards. That is what makes the Capstone Manual readable with no
// connection. The path is relative, so a sub-folder deploy
// (`--base-href /appstone/`) still resolves correctly.
//
// The same effect is available as `flutter build web --no-web-resources-cdn`,
// but that is a flag someone has to remember on every build; this is a
// property of the app.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
