import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
    // Trigger a rebuild so build() switches from the "Loading…" placeholder
    // to WebViewWidget(controller: bridge.webViewController).
    setState(() => _bridge = bridge);

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
    return _AlwaysRepaint(
      child: WebViewWidget(controller: bridge.webViewController),
    );
  }
}

/// Forces a paint cycle every frame on the wrapped subtree — without
/// recreating any widgets. The webview child keeps its State.
///
/// Needed because `webview_all_linux`'s platform-view hides its
/// underlying GtkWidget the moment a frame goes by where our
/// RenderObject's `paint()` wasn't called. In a static widget tree Flutter
/// optimizes away redundant paints, so the webview disappears after the
/// first render. Here we push `markNeedsPaint` after every paint, keeping
/// the paint path active. Cost: one repaint per frame on this subtree —
/// cheap since the child is just a platform view pass-through.
class _AlwaysRepaint extends SingleChildRenderObjectWidget {
  const _AlwaysRepaint({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _AlwaysRepaintBox();
}

class _AlwaysRepaintBox extends RenderProxyBox {
  int _frameCallbackId = -1;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // Schedule a paint for the next frame. We cancel+re-schedule to avoid
    // stacking callbacks during unusual pipeline orderings.
    if (_frameCallbackId != -1) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_frameCallbackId);
    }
    _frameCallbackId =
        SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameCallbackId = -1;
      if (attached) markNeedsPaint();
    });
  }

  @override
  void detach() {
    if (_frameCallbackId != -1) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_frameCallbackId);
      _frameCallbackId = -1;
    }
    super.detach();
  }
}
