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

// Make sure the app shell is cached under the key an offline refresh looks for.
//
// `flutter_service_worker.js` caches the shell during install under the name in
// its CORE list - "index.html" - so the entry it writes is `<origin>/index.html`.
// But a browser reloading the site root requests `<origin>/`, and the worker's
// own fetch handler maps that to the key "/". The two are different cache
// entries, and "/" is only ever written opportunistically: `onlineFirst` stores
// it after a *successful online* navigation that passed through an already
// active worker.
//
// On a first visit the worker installs after that navigation has finished, so
// "/" is never written at all. The student loads Appstone, goes offline,
// refreshes - and gets the browser's "You're offline" page, even though
// main.dart.js, canvaskit/ and every asset are sitting in the cache. Only a
// second online load would have fixed it, which is not something to ask a
// student to know.
//
// Re-requesting the root once the worker controls this page closes the gap. The
// request goes through the worker's own fetch handler, so the response lands
// under "/" - the exact key the next offline refresh matches against - without
// this file having to know the worker's cache name. It is one small HTML
// request, and it doubles as a refresh of the offline copy of the shell.
(function () {
  if (!("serviceWorker" in navigator)) return;

  var warmed = false;

  function warmAppShell() {
    // No worker in control means nothing would intercept this fetch, and
    // offline it would only fail.
    if (warmed || !navigator.serviceWorker.controller || !navigator.onLine) {
      return;
    }
    warmed = true;
    // Resolved against <base href>, so a sub-folder deploy warms its own root.
    // The Accept header mimics a navigation request: a cached response is
    // matched subject to the server's `Vary`, and a shell stored under a
    // different Accept could fail to match the real refresh later.
    fetch(".", {
      credentials: "same-origin",
      headers: {
        Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    }).catch(function () {
      // Offline or interrupted. Leave it retryable for the next load.
      warmed = false;
    });
  }

  // First visit: the worker calls clients.claim() during activate, which is
  // the moment this page gains a controller.
  navigator.serviceWorker.addEventListener("controllerchange", warmAppShell);

  // Later visits: a controller is already attached. Waiting for first frame
  // keeps this off the critical path while the bundle is still downloading.
  window.addEventListener("flutter-first-frame", warmAppShell);
})();
