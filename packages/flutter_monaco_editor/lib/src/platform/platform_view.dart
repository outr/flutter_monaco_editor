// Platform-conditional export: picks the web implementation when
// `dart:js_interop` is available, otherwise a stub that renders a
// "not supported" placeholder.
//
// Native (webview-based) implementation lands in Phase 4 and replaces the
// stub by keying on `dart.library.io` plus a WebView-capable environment.
export 'platform_view_stub.dart'
    if (dart.library.js_interop) 'platform_view_web.dart';
