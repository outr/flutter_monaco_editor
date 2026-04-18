import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Serves `flutter_monaco_editor` bundled assets over an in-process HTTP
/// server on `127.0.0.1`, so webview_cef — which wants a URL — can load
/// Monaco from the Flutter asset bundle.
///
/// The server binds to an OS-assigned port and serves any asset key that
/// starts with `packages/flutter_monaco_editor/`. Other paths return 404.
class MonacoAssetServer {
  MonacoAssetServer._(this._server);

  final HttpServer _server;

  /// Listening port.
  int get port => _server.port;

  /// Base URL (e.g. `http://127.0.0.1:54321`).
  String get baseUrl => 'http://127.0.0.1:$port';

  static MonacoAssetServer? _instance;

  /// Process-singleton. Idempotent: repeat calls return the same server.
  static Future<MonacoAssetServer> instance() async {
    return _instance ??= await _start();
  }

  static Future<MonacoAssetServer> _start() async {
    final server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: true);
    final wrapper = MonacoAssetServer._(server);
    wrapper._listen();
    return wrapper;
  }

  void _listen() {
    _server.listen((request) async {
      final resp = request.response;
      try {
        // Strip the leading slash to get the asset key.
        var key = request.uri.path;
        if (key.startsWith('/')) key = key.substring(1);

        // Only serve our own packaged assets.
        if (!key.startsWith('packages/flutter_monaco_editor/')) {
          resp.statusCode = HttpStatus.notFound;
          await resp.close();
          return;
        }

        final ByteData data;
        try {
          data = await rootBundle.load(key);
        } catch (_) {
          resp.statusCode = HttpStatus.notFound;
          await resp.close();
          return;
        }

        resp.statusCode = HttpStatus.ok;
        resp.headers.contentType = _contentTypeFor(key);
        resp.headers.set('Cache-Control', 'no-cache');
        resp.add(data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ));
        await resp.close();
      } catch (_) {
        try {
          resp.statusCode = HttpStatus.internalServerError;
          await resp.close();
        } catch (_) {}
      }
    });
  }

  static ContentType _contentTypeFor(String key) {
    final lower = key.toLowerCase();
    if (lower.endsWith('.html')) return ContentType.html;
    if (lower.endsWith('.js')) return ContentType('application', 'javascript');
    if (lower.endsWith('.css')) return ContentType('text', 'css');
    if (lower.endsWith('.json')) return ContentType.json;
    if (lower.endsWith('.svg')) {
      return ContentType('image', 'svg+xml');
    }
    if (lower.endsWith('.wasm')) return ContentType('application', 'wasm');
    if (lower.endsWith('.woff2')) return ContentType('font', 'woff2');
    if (lower.endsWith('.woff')) return ContentType('font', 'woff');
    if (lower.endsWith('.ttf')) return ContentType('font', 'ttf');
    return ContentType.binary;
  }
}
