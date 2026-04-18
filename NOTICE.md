# Third-party notices

`flutter_monaco_editor` is licensed under the MIT License (see [LICENSE](LICENSE)).

## Bundled third-party software

### Monaco Editor

This package bundles Microsoft's [Monaco Editor](https://github.com/microsoft/monaco-editor)
(the editor that powers VS Code) as a runtime asset under `assets/monaco-min/`.
Monaco Editor is distributed under the MIT License. The full upstream
attribution for Monaco's own third-party dependencies ships in
[`assets/ThirdPartyNotices.txt`](assets/ThirdPartyNotices.txt).

## Runtime platform dependencies

The package depends on:

- [`webview_all`](https://pub.dev/packages/webview_all) (BSD-3-Clause) — a
  cross-platform webview wrapper that re-exports `webview_flutter`'s
  platform interface on Android, iOS, macOS, Windows, and Linux.
- [`web`](https://pub.dev/packages/web) (BSD-3-Clause) — Dart's modern web
  interop library (used for the `dart:js_interop` web transport).
