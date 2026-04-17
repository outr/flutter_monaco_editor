import '../bridge/bridge.dart';

Future<MonacoBridge> acquireBridge() {
  throw UnsupportedError(
    'flutter_monaco_editor: language providers are only available on web '
    'right now. Native webview support arrives in Phase 4.',
  );
}
