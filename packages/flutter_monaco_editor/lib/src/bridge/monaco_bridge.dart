import 'bridge_event.dart';

/// Transport-agnostic interface to the Monaco JavaScript bridge.
///
/// Implementations:
/// - `WebMonacoBridge` — runs Monaco in the main document via `dart:js_interop`.
/// - `NativeMonacoBridge` — runs Monaco inside a `webview_flutter` WebView
///   (Phase 4).
///
/// The JS side of both bridges is the same file: `assets/bridge/monaco_bridge.js`.
abstract interface class MonacoBridge {
  /// Completes once Monaco has loaded and the bridge is ready to accept calls.
  ///
  /// Before this future completes, [invoke] awaits internally — callers never
  /// need to gate work on readiness themselves.
  Future<void> get ready;

  /// Stream of events emitted by the JS side (content changes, cursor moves,
  /// focus/blur, custom events, and bridge lifecycle events).
  ///
  /// Broadcast; multiple listeners safe.
  Stream<BridgeEvent> get events;

  /// Invoke a bridge method. Method names are namespaced (`editor.create`,
  /// `editor.getValue`, ...). Returns the JSON-decoded result.
  ///
  /// Throws [MonacoBridgeException] if the JS handler throws.
  Future<Object?> invoke(String method, [Map<String, Object?> args = const {}]);

  /// Release resources. After dispose, [invoke] throws and [events] closes.
  Future<void> dispose();
}

class MonacoBridgeException implements Exception {
  MonacoBridgeException(this.message, {this.method});

  final String message;
  final String? method;

  @override
  String toString() =>
      method == null ? 'MonacoBridgeException: $message' : 'MonacoBridgeException[$method]: $message';
}
