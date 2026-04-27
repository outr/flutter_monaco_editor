import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:webview_all/webview_all.dart';

import '../bridge/bridge.dart';
import 'asset_server.dart';

/// Webview-backed MonacoBridge for native platforms.
///
/// Each instance owns its own [WebViewController] and hosts its own Monaco
/// runtime — unlike the web transport where Monaco is a process singleton.
/// The first instance created becomes the "shared" bridge exposed via
/// [instance] so global APIs (language providers) have somewhere to
/// register. See README for limitations.
class NativeMonacoBridge implements MonacoBridge {
  NativeMonacoBridge._({bool transparent = false}) : _transparent = transparent;

  bool _transparent;

  /// Path segment appended to the asset server's base URL to reach the
  /// host HTML. Matches the on-disk path under the Flutter asset bundle
  /// so relative refs inside the HTML (`./monaco_bridge.js`, `../monaco-min/vs`)
  /// resolve correctly.
  static const String _hostPath =
      'packages/flutter_monaco_editor/assets/bridge/monaco_host.html';

  /// The JavaScriptChannel name used by `monaco_bridge.js` to post events
  /// back to Dart. Hardcoded in host HTML via a shim installed on
  /// `monacoBridge.setEmitter`.
  static const String _channelName = 'FmeChannel';

  static NativeMonacoBridge? _shared;

  /// Returns the "shared" bridge for process-global APIs — language
  /// providers (`MonacoLanguages`), theme registration (`MonacoThemes`).
  /// On native, each editor widget has its own WebView, so these global
  /// APIs operate only on the first-created bridge.
  static Future<NativeMonacoBridge> instance() async {
    final existing = _shared;
    if (existing != null && !existing._disposed) return existing;
    return create();
  }

  /// Create a new, isolated bridge + WebView host. Each call yields a
  /// fresh Monaco runtime.
  ///
  /// When [transparent] is true, the underlying WebView is created with
  /// a transparent background, so a Flutter widget (e.g. an image) behind
  /// the editor shows through any transparent regions of the active
  /// Monaco theme.
  static Future<NativeMonacoBridge> create({bool transparent = false}) async {
    final bridge = NativeMonacoBridge._(transparent: transparent);
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

  /// Exposed for `NativeMonacoPlatformView` — the widget mounts this
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
    // Sensible pre-Monaco-load background: opaque vs-dark by default,
    // transparent when the caller has requested it (so a Flutter layer
    // behind the editor shows through during load).
    await _setWebViewBackgroundColor();
    await _webController.addJavaScriptChannel(
      _channelName,
      onMessageReceived: _onChannelMessage,
    );

    // Asset loading goes through an in-process HTTP server on 127.0.0.1.
    //
    // loadFlutterAsset looked simpler on mobile, but Android's WebView
    // blocks `file://` sub-resource loads inside Web Workers — so
    // Monaco's diff-compute worker fails to import its bundled script
    // and the diff highlighting never renders. WebKitGTK on Linux has
    // the same category of restriction. Loading via http://127.0.0.1
    // sidesteps both.
    //
    // Platform setup requirements for apps that consume this package:
    //   * Android: INTERNET permission + cleartext allowance for
    //     127.0.0.1 (see the example's AndroidManifest.xml and
    //     network_security_config.xml).
    //   * iOS: NSAppTransportSecurity NSAllowsLocalNetworking=true
    //     (mentioned in the example's Info.plist).
    //   * macOS: no extra setup.
    //   * Linux / Windows: no extra setup.
    final server = await MonacoAssetServer.instance();
    await _webController.loadRequest(Uri.parse('${server.baseUrl}/$_hostPath'));
  }

  /// Toggle the WebView's background at runtime. Pair with a matching
  /// `MonacoTheme.transparent()` / opaque theme for the visual effect to
  /// be visible.
  Future<void> setTransparent(bool transparent) async {
    _transparent = transparent;
    await _setWebViewBackgroundColor();
  }

  /// Best-effort WebView background before Monaco loads / when toggling transparency.
  ///
  /// On **macOS**, `setBackgroundColor` can throw [UnimplementedError] because
  /// the embedded WKWebView path does not implement `setOpaque` for `NSView`
  /// (see flutter/flutter#153773). Catching that allows the bridge to load; the
  /// pre-paint background may differ until Monaco renders.
  Future<void> _setWebViewBackgroundColor() async {
    try {
      await _webController.setBackgroundColor(
        _transparent ? const Color(0x00000000) : const Color(0xFF1E1E1E),
      );
    } on UnimplementedError {
      // Tracked upstream: webview background / opaque on macOS (NSView).
    }
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
