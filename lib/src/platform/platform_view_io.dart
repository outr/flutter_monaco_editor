import 'dart:io';

import 'package:flutter/widgets.dart';

import '../monaco_controller.dart';
import '../native/native_platform_view.dart';

/// Non-web platform view dispatcher.
///
/// All native platforms (Android, iOS, macOS, Windows, Linux) go through
/// `NativeMonacoPlatformView`, which drives `webview_all`'s unified
/// WebView API (WKWebView on Apple, WebView on Android, WebView2 on
/// Windows, WebKitGTK on Linux).
class MonacoPlatformView extends StatelessWidget {
  const MonacoPlatformView({
    super.key,
    required this.controller,
    required this.onChanged,
    this.transparent = false,
  });

  final MonacoController controller;
  final ValueChanged<String>? onChanged;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isWindows) {
      return NativeMonacoPlatformView(
        controller: controller,
        onChanged: onChanged,
        transparent: transparent,
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'flutter_monaco_editor: this platform has no Monaco transport.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
