import 'dart:io';

import '../bridge/bridge.dart';
import '../native/native_monaco_bridge.dart';

Future<MonacoBridge> acquireBridge() async {
  if (Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows) {
    return NativeMonacoBridge.instance();
  }
  throw UnsupportedError(
    'flutter_monaco_editor: no Monaco transport for this platform',
  );
}
