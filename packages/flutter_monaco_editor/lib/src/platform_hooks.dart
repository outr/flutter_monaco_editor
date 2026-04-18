import 'package:flutter/widgets.dart';

import 'bridge/bridge.dart';
import 'monaco_controller.dart';

/// Hooks a platform-specific implementation into the main package.
///
/// The web transport is always available via `dart:js_interop`. Additional
/// transports (native webview in Phase 4) register themselves here at app
/// startup, replacing the default "unsupported platform" stub.
///
/// Typical native setup (in your app's `main`):
///
/// ```dart
/// import 'package:flutter_monaco_editor_native/flutter_monaco_editor_native.dart';
///
/// void main() {
///   MonacoNative.register();   // installs hooks via MonacoPlatformHooks
///   runApp(const MyApp());
/// }
/// ```
class MonacoPlatformHooks {
  MonacoPlatformHooks._();

  /// Factory for acquiring a [MonacoBridge] on non-web platforms.
  /// Set by [MonacoPlatformHooks.install] — users should not call directly.
  static Future<MonacoBridge> Function()? bridgeFactory;

  /// Factory for building the platform view that hosts a Monaco editor on
  /// non-web platforms.
  static Widget Function(
    MonacoController controller,
    ValueChanged<String>? onChanged,
    bool transparent,
  )? platformViewFactory;

  /// Install a native implementation. Idempotent: only the first call
  /// takes effect, so apps are safe to call from multiple entrypoints.
  static void install({
    required Future<MonacoBridge> Function() bridgeFactory,
    required Widget Function(
      MonacoController controller,
      ValueChanged<String>? onChanged,
      bool transparent,
    ) platformViewFactory,
  }) {
    MonacoPlatformHooks.bridgeFactory ??= bridgeFactory;
    MonacoPlatformHooks.platformViewFactory ??= platformViewFactory;
  }

  /// True once a non-web implementation has registered hooks.
  static bool get isInstalled =>
      bridgeFactory != null && platformViewFactory != null;
}
