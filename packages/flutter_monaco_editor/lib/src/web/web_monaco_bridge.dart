import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

import '../bridge/bridge.dart';
import 'monaco_js.dart';

/// Web transport for [MonacoBridge].
///
/// On web, Monaco lives in the main document — no iframe — so JS calls cross
/// into Dart via direct `js_interop`, not `postMessage`. Startup sequence:
///
/// 1. Load `monaco_bridge.js` from package assets and inject it inline,
///    defining `window.monacoBridge`.
/// 2. Wire an emitter from JS back to [_dispatchEvent].
/// 3. Invoke `bridge.init` to load Monaco's AMD loader and `editor.main`.
/// 4. When the JS side emits `bridge.ready`, complete [ready].
///
/// Calls issued before ready are awaited internally inside [invoke].
class WebMonacoBridge implements MonacoBridge {
  WebMonacoBridge._(this._vsPath);

  /// Default path where Monaco is served for a stock Flutter web app.
  /// Override via [instance] if the app uses a non-standard base href or
  /// ships its own Monaco copy.
  static const String defaultVsPath =
      'assets/packages/flutter_monaco_editor/assets/monaco-min/vs';

  static const String _bridgeScriptAssetKey =
      'packages/flutter_monaco_editor/assets/bridge/monaco_bridge.js';

  final String _vsPath;
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<BridgeEvent> _events = StreamController.broadcast();
  bool _disposed = false;

  static WebMonacoBridge? _instance;

  /// Returns the process-global web bridge, creating it on first call.
  ///
  /// Monaco registers itself on `window`, so there is one bridge per page
  /// regardless of how many editor widgets exist.
  static Future<WebMonacoBridge> instance({String? vsPath}) async {
    final existing = _instance;
    if (existing != null) return existing;

    final bridge = WebMonacoBridge._(vsPath ?? _resolveDefaultVsPath());
    _instance = bridge;
    await bridge._bootstrap();
    return bridge;
  }

  @visibleForTesting
  static void debugReset() {
    _instance = null;
  }

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<BridgeEvent> get events => _events.stream;

  @override
  Future<Object?> invoke(String method, [Map<String, Object?> args = const {}]) async {
    if (_disposed) {
      throw MonacoBridgeException('bridge disposed', method: method);
    }
    await ready;
    final js = monacoBridgeJs;
    if (js == null) {
      throw MonacoBridgeException('window.monacoBridge missing', method: method);
    }

    final JSAny? result;
    try {
      result = js.invoke(method, args.jsify());
    } catch (e) {
      throw MonacoBridgeException(e.toString(), method: method);
    }

    // Handlers may return a Promise (e.g. bridge.init). Await if so.
    if (result != null && result.instanceOfString('Promise')) {
      final awaited = await (result as JSPromise<JSAny?>).toDart;
      return awaited?.dartify();
    }
    return result?.dartify();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _events.close();
    // NOTE: we intentionally do NOT delete window.monacoBridge or unload Monaco
    // — the bridge is process-singleton and may be reused if the app creates
    // a new editor later.
  }

  Future<void> _bootstrap() async {
    await _injectBridgeScript();
    final js = monacoBridgeJs;
    if (js == null) {
      throw StateError('monaco_bridge.js did not define window.monacoBridge');
    }

    js.setEmitter(_dispatchEvent.toJS);
    js.onReady(_onReady.toJS);

    // Kick off Monaco load. The JS handler returns a Promise that resolves
    // when editor.main is ready; we don't await it here because onReady
    // also fires via the event channel.
    final initResult = js.invoke('bridge.init', {'vsPath': _vsPath}.jsify());
    if (initResult != null && initResult.instanceOfString('Promise')) {
      // Swallow — errors propagate via stream / completer.
      unawaited((initResult as JSPromise<JSAny?>).toDart.then(
        (_) {},
        onError: (Object err) {
          if (!_readyCompleter.isCompleted) {
            _readyCompleter.completeError(
              MonacoBridgeException(err.toString(), method: 'bridge.init'),
            );
          }
        },
      ));
    }
  }

  Future<void> _injectBridgeScript() async {
    // Idempotent: if a previous page load already injected it, skip.
    if (monacoBridgeJs != null) return;

    final source = await rootBundle.loadString(_bridgeScriptAssetKey);
    final script = web.HTMLScriptElement()
      ..type = 'text/javascript'
      ..text = source;
    web.document.head!.appendChild(script);

    if (monacoBridgeJs == null) {
      throw StateError(
        'Injected monaco_bridge.js but window.monacoBridge is still undefined '
        '(CSP blocking inline scripts?).',
      );
    }
  }

  void _dispatchEvent(JSString type, JSAny? payload) {
    if (_disposed) return;
    final Map<String, Object?> payloadMap;
    final dartPayload = payload?.dartify();
    if (dartPayload is Map) {
      payloadMap = dartPayload.map((k, v) => MapEntry(k.toString(), v));
    } else {
      payloadMap = <String, Object?>{};
    }
    _events.add(BridgeEvent(type.toDart, payloadMap));
  }

  void _onReady() {
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  static String _resolveDefaultVsPath() {
    try {
      final base = web.document.baseURI;
      return Uri.parse(base).resolve(defaultVsPath).toString();
    } catch (_) {
      return defaultVsPath;
    }
  }
}
