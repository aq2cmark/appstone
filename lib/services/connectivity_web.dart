import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get isOnline => web.window.navigator.onLine;

/// Emits true when the browser regains a connection and false when it loses
/// one. A fresh stream per call: each listener owns its own subscription, so
/// nothing has to live in a global.
Stream<bool> get onlineChanges {
  final controller = StreamController<bool>.broadcast();
  final onOnline = ((web.Event _) => controller.add(true)).toJS;
  final onOffline = ((web.Event _) => controller.add(false)).toJS;

  controller
    ..onListen = () {
      web.window.addEventListener('online', onOnline);
      web.window.addEventListener('offline', onOffline);
    }
    ..onCancel = () {
      web.window.removeEventListener('online', onOnline);
      web.window.removeEventListener('offline', onOffline);
    };

  return controller.stream;
}
