# Changelog

## 0.4.0-dev

### Phase 4 — native platform bridge

- `NativeMonacoBridge`: `MonacoBridge` implementation backed by
  `webview_flutter` + JavaScriptChannel.
- `NativeMonacoPlatformView` widget hosting one WebView per editor.
- `MonacoNative.register()` installs hooks into `flutter_monaco_editor`
  via `MonacoPlatformHooks`.
- Ships with known limitations — see README.
