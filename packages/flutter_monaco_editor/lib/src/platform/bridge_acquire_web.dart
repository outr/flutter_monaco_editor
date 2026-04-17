import '../bridge/bridge.dart';
import '../web/web_monaco_bridge.dart';

Future<MonacoBridge> acquireBridge() => WebMonacoBridge.instance();
