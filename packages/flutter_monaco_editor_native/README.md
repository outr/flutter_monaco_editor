# flutter_monaco_editor_native

Native platform (Android, iOS, macOS, Windows, Linux) implementation for [`flutter_monaco_editor`](../flutter_monaco_editor).

Uses `webview_flutter` to host Monaco inside a WebView. The Dart API is
identical to the web transport; the only setup step is calling
`MonacoNative.register()` once before `runApp()`.

## Installation

```yaml
dependencies:
  flutter_monaco_editor: ^0.4.0
  flutter_monaco_editor_native: ^0.4.0
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_monaco_editor/flutter_monaco_editor.dart';
import 'package:flutter_monaco_editor_native/flutter_monaco_editor_native.dart';

void main() {
  MonacoNative.register();  // no-op on web; installs native hooks elsewhere
  runApp(const MyApp());
}
```

Then use `MonacoEditor` exactly as on web:

```dart
MonacoEditor(
  initialValue: 'void main() {}',
  language: 'dart',
)
```

## Known limitations (Phase 4 MVP)

- **One WebView per editor.** Each `MonacoEditor` on native hosts its own
  Monaco instance inside a dedicated `webview_flutter` WebView. Expect
  ~30-100MB RSS per editor; multi-editor IDE UIs will want to share a
  WebView in a future release.
- **Language providers work per-editor.** `MonacoLanguages.register*`
  on native registers against the first-created editor. Providers will
  not contribute to editors created afterward in this release.
- **iOS worker loading.** Monaco's language workers (TS, JSON, HTML, CSS)
  require `getWorker` returning a `Worker` object built from a Blob;
  current CSP may need widening on iOS. Worker-dependent features (type
  checking, validation) may be unreliable on iOS in this release.
- **Web Workers on older webviews.** On some Android System WebView
  versions prior to 90, certain worker features fall back to main-thread
  tokenization.

These are tracked toward the 0.4.x series.

## License

MIT — same as the main package. Monaco Editor is bundled under its MIT
license via `flutter_monaco_editor`; see that package's `assets/ThirdPartyNotices.txt`.
