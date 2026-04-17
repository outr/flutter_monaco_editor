// Platform-conditional accessor for the process-global MonacoBridge.
//
// Only the web path is implemented today. Phase 4 plugs in the native
// webview implementation.
export 'bridge_acquire_stub.dart'
    if (dart.library.js_interop) 'bridge_acquire_web.dart';
