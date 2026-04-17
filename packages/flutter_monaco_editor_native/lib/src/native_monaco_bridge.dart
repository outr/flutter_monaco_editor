import 'dart:async';
import 'dart:convert';

import 'package:flutter_monaco_editor/flutter_monaco_editor.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Webview-backed MonacoBridge for native platforms.
///
/// Each instance owns its own [WebViewController] and hosts its own Monaco
/// runtime — unlike the web transport where Monaco is a process singleton.
/// The first instance created becomes the "shared" bridge exposed via
/// [instance] so global APIs (language providers) have somewhere to
/// register. See README for limitations.
class NativeMonacoBridge implements MonacoBridge {
  NativeMonacoBridge._();

  /// The Flutter asset key for the bundled HTML host page.
  static const String _hostAssetKey =
      'packages/flutter_monaco_editor/assets/bridge/monaco_host.html';

  /// The JavaScriptChannel name used by `monaco_bridge.js` to post events
  /// back to Dart. Hardcoded in host HTML via a shim installed on
  /// `monacoBridge.setEmitter`.
  static const String _channelName = 'FmeChannel';

  static NativeMonacoBridge? _shared;

  /// Returns the "shared" bridge for process-global APIs — language
  /// providers ([MonacoLanguages]), theme registration ([MonacoThemes]).
  /// On native, each editor widget has its own WebView, so these global
  /// APIs operate only on the first-created bridge. Document accordingly
  /// when using them in a multi-editor native UI.
  ///
  /// If no widget has created a bridge yet, one is created on demand
  /// (headless — no attached editor). The first widget to mount will
  /// adopt it if it's still around.
  static Future<NativeMonacoBridge> instance() async {
    final existing = _shared;
    if (existing != null && !existing._disposed) return existing;
    return create();
  }

  /// Create a new, isolated bridge + WebView host. Each call yields a
  /// fresh Monaco runtime — this is what each [NativeMonacoPlatformView]
  /// uses, giving one editor per WebView.
  static Future<NativeMonacoBridge> create() async {
    final bridge = NativeMonacoBridge._();
    await bridge._bootstrap();
    _shared ??= bridge;
    return bridge;
  }

  late final WebViewController _webController;
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<BridgeEvent> _events =
      StreamController<BridgeEvent>.broadcast();
  final Map<String, Completer<Object?>> _pending = {};
  int _nextCallId = 1;
  bool _disposed = false;

  /// Exposed for [NativeMonacoPlatformView] — the widget mounts this
  /// controller inside a `WebViewWidget`.
  WebViewController get webViewController => _webController;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<BridgeEvent> get events => _events.stream;

  @override
  Future<Object?> invoke(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    if (_disposed) {
      throw MonacoBridgeException('bridge disposed', method: method);
    }
    await ready;
    final callId = 'c-${_nextCallId++}';
    final completer = Completer<Object?>();
    _pending[callId] = completer;
    final payload = jsonEncode({
      'method': method,
      'args': args,
      'callId': callId,
    });
    // `window.__fmeDispatch` is defined by the shim injected in
    // monaco_host.html and forwards to monacoBridge.invokeAsync.
    await _webController.runJavaScript('window.__fmeDispatch($payload)');
    return completer.future;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _events.close();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('bridge disposed'));
    }
    _pending.clear();
    if (identical(_shared, this)) _shared = null;
  }

  Future<void> _bootstrap() async {
    _webController = WebViewController();
    await _webController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _webController.addJavaScriptChannel(
      _channelName,
      onMessageReceived: _onChannelMessage,
    );
    // The emitter shim + __fmeDispatch wiring is baked into monaco_host.html;
    // runJavaScript is post-load, so we rely on the page's inline <script>.
    await _webController.loadFlutterAsset(_hostAssetKey);
  }

  void _onChannelMessage(JavaScriptMessage message) {
    if (_disposed) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } catch (e) {
      // ignore: avoid_print
      print('[NativeMonacoBridge] non-JSON channel message: ${message.message}');
      return;
    }
    if (decoded is! Map) return;
    final type = decoded['type']?.toString();
    if (type == null) return;
    final payloadRaw = decoded['payload'];
    final payload = payloadRaw is Map
        ? payloadRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, Object?>{};

    if (type == 'bridge.ready') {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      _events.add(BridgeEvent(type, payload));
      return;
    }

    if (type == '_return') {
      final callId = payload['callId']?.toString();
      if (callId == null) return;
      final completer = _pending.remove(callId);
      if (completer == null) return;
      if (payload.containsKey('error')) {
        completer.completeError(
          MonacoBridgeException(payload['error'].toString()),
        );
      } else {
        completer.complete(payload['value']);
      }
      return;
    }

    _events.add(BridgeEvent(type, payload));
  }
}
