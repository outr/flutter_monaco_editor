import '../bridge/bridge.dart';
import '../platform_hooks.dart';

Future<MonacoBridge> acquireBridge() {
  final factory = MonacoPlatformHooks.bridgeFactory;
  if (factory != null) return factory();
  throw UnsupportedError(
    'flutter_monaco_editor: no bridge implementation registered for this '
    'platform. Add flutter_monaco_editor_native to your pubspec and call '
    'MonacoNative.register() before runApp().',
  );
}
