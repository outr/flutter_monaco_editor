import 'package:flutter_monaco_editor/flutter_monaco_editor.dart';

import 'native_monaco_bridge.dart';
import 'native_platform_view.dart';

/// Entrypoint for wiring the native transport into `flutter_monaco_editor`.
///
/// Call [register] once before `runApp()`:
///
/// ```dart
/// void main() {
///   MonacoNative.register();
///   runApp(const MyApp());
/// }
/// ```
///
/// No-op on web — the main package detects `dart:js_interop` and uses its
/// own implementation.
class MonacoNative {
  const MonacoNative._();

  static bool _registered = false;

  /// Install hooks. Idempotent.
  static void register() {
    if (_registered) return;
    _registered = true;
    MonacoPlatformHooks.install(
      bridgeFactory: NativeMonacoBridge.instance,
      platformViewFactory: (controller, onChanged, transparent) =>
          NativeMonacoPlatformView(
        controller: controller,
        onChanged: onChanged,
        transparent: transparent,
      ),
    );
  }

  /// Whether [register] has been called.
  static bool get isRegistered => _registered;
}
