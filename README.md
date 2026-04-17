# flutter_monaco_editor

A complete Flutter wrapper for [Monaco Editor](https://github.com/microsoft/monaco-editor) (the editor that powers VS Code) with **full API parity** across Web, Android, iOS, macOS, Windows, and Linux.

## Status

**Early development.** Phase 1 (web platform, core API) is in progress. See [PLAN.md](PLAN.md) for the roadmap.

## Why this project exists

Existing Flutter Monaco packages cover one platform each — `monaco_editor` is web-only, `flutter_monaco` is native-only. Neither exposes the full Monaco API. This package aims to be the one-stop integration: every Monaco feature, every platform, one Dart API.

Built to support a Flutter-based IDE, so full functionality — IntelliSense providers, diagnostics, decorations, diff editor, custom themes, multi-model — is a requirement, not a stretch goal.

## Packages

This repository is a monorepo.

| Package | Description | Status |
|---|---|---|
| [`flutter_monaco_editor`](packages/flutter_monaco_editor) | Main package. Dart API + Web platform implementation. | ✓ |
| [`flutter_monaco_editor_native`](packages/flutter_monaco_editor_native) | Webview implementation for Android, iOS, macOS, Windows, Linux. | ✓ (MVP) |

## Platform support target

| Platform | Hosting | Communication |
|---|---|---|
| Web | `HtmlElementView` — Monaco loaded directly in DOM | `dart:js_interop` direct calls |
| Android / iOS | `webview_flutter` loading local HTML asset | WebView JavaScript channel |
| macOS / Windows / Linux | `webview_flutter` loading local HTML asset | WebView JavaScript channel |

Monaco's JavaScript API is identical regardless of hosting. One Dart API, one shared JS bridge protocol, two transports.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. Monaco Editor is bundled under its MIT license — see [LICENSE](LICENSE) and `packages/flutter_monaco_editor/assets/ThirdPartyNotices.txt`.
