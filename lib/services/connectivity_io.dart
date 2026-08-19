// Native builds: there is no cheap synchronous connectivity check without
// adding a plugin, and the app's mobile story is an installed PWA, so nothing
// here needs one. Report online and let request failures speak for themselves.
bool get isOnline => true;

Stream<bool> get onlineChanges => const Stream<bool>.empty();
