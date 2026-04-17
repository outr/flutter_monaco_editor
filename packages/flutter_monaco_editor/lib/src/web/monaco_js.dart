@JS()
library;

import 'dart:js_interop';

/// Matches the `window.monacoBridge` object created by `monaco_bridge.js`.
///
/// The browser-side bridge is transport-independent; the web transport
/// wraps it with js_interop. The native (webview) transport performs the
/// same calls through a WebView channel — see Phase 4.
extension type MonacoBridgeJs._(JSObject _) implements JSObject {
  external void setEmitter(JSFunction fn);
  external void onReady(JSFunction cb);

  /// Synchronous invoke. Returns a raw JS value — may be a `Promise`; callers
  /// must check and await.
  external JSAny? invoke(String method, JSAny? args);
}

@JS('monacoBridge')
external MonacoBridgeJs? get monacoBridgeJs;
