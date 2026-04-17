import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_monaco_editor/flutter_monaco_editor.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'native_monaco_bridge.dart';

/// Native (webview) platform view. Each instance owns a fresh
/// [NativeMonacoBridge] — one WebView per Monaco editor.
class NativeMonacoPlatformView extends StatefulWidget {
  const NativeMonacoPlatformView({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final MonacoController controller;
  final ValueChanged<String>? onChanged;

  @override
  State<NativeMonacoPlatformView> createState() =>
      _NativeMonacoPlatformViewState();
}

class _NativeMonacoPlatformViewState extends State<NativeMonacoPlatformView> {
  NativeMonacoBridge? _bridge;
  String? _editorId;
  StreamSubscription<String>? _onChangedSub;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
    _wireOnChanged(widget.controller);
  }

  @override
  void didUpdateWidget(NativeMonacoPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.onChanged != widget.onChanged) {
      _onChangedSub?.cancel();
      _wireOnChanged(widget.controller);
    }
  }

  void _wireOnChanged(MonacoController controller) {
    final cb = widget.onChanged;
    if (cb == null) return;
    _onChangedSub = controller.onDidChangeContent.listen(cb);
  }

  Future<void> _initialize() async {
    // Use the shared bridge if one exists (so language providers registered
    // globally also apply here); otherwise create a dedicated one.
    final bridge = await NativeMonacoBridge.instance();
    if (!mounted) return;
    _bridge = bridge;

    final editorId = await bridge.invoke('editor.create', {
      // There's no external DOM container on native — JS uses the
      // monaco-root div baked into monaco_host.html.
      'containerId': 'monaco-root',
      'options': widget.controller.buildCreateOptions(),
    }) as String;
    _editorId = editorId;
    widget.controller.attach(bridge, editorId);
  }

  @override
  void dispose() {
    _onChangedSub?.cancel();
    final bridge = _bridge;
    final editorId = _editorId;
    if (bridge != null && editorId != null) {
      widget.controller.detach();
      unawaited(bridge.invoke('editor.dispose', {'editorId': editorId}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bridge = _bridge;
    if (bridge == null) {
      return const Center(child: Text('Loading editor…'));
    }
    return WebViewWidget(controller: bridge.webViewController);
  }
}
