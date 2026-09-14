/// Conditional entry point for the EIP-1193 wallet bridge.
///
/// Picks the web implementation (real `window.ethereum` interop via
/// `dart:js_interop`) when running in a browser and a no-op stub everywhere
/// else so the app still compiles on the Dart VM (widget tests, native
/// targets) where the JS interop libraries do not exist.
library;

export 'ethereum_provider_bridge_stub.dart'
    if (dart.library.js_interop) 'ethereum_provider_bridge_web.dart';