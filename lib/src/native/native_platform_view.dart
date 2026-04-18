import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_all/webview_all.dart';

import '../monaco_controller.dart';
import 'native_monaco_bridge.dart';

/// Native (webview) platform view. Each instance owns a fresh
/// [NativeMonacoBridge] — one WebView per Monaco editor.
class NativeMonacoPlatformView extends StatefulWidget {
  const NativeMonacoPlatformView({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.transparent,
  });

  final MonacoController controller;
  final ValueChanged<String>? onChanged;
  final bool transparent;

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
    // One fresh bridge = one WebView = one Monaco runtime per widget.
    // The first bridge created also becomes the shared one used by
    // global APIs (MonacoLanguages / MonacoThemes) — see
    // NativeMonacoBridge.instance().
    final bridge = await NativeMonacoBridge.create(transparent: widget.transparent);
    if (!mounted) {
      unawaited(bridge.dispose());
      return;
    }
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
    if (bridge != null) {
      if (editorId != null) {
        widget.controller.detach();
        unawaited(bridge.invoke('editor.dispose', {'editorId': editorId}));
      }
      // The bridge owns its WebView — tear it down with the widget so we
      // don't leak WebViews in long-lived IDE sessions.
      unawaited(bridge.dispose());
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
