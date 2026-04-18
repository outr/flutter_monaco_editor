import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../monaco_controller.dart';
import '../web/web_monaco_bridge.dart';

class MonacoPlatformView extends StatefulWidget {
  const MonacoPlatformView({
    super.key,
    required this.controller,
    required this.onChanged,
    this.transparent = false,
  });

  final MonacoController controller;
  final ValueChanged<String>? onChanged;

  /// On web, transparency is controlled entirely by the active Monaco theme
  /// (`editor.background` and related keys) — the host div has no
  /// background of its own. This flag is accepted for API symmetry with
  /// the native path.
  final bool transparent;

  @override
  State<MonacoPlatformView> createState() => _MonacoPlatformViewState();
}

class _MonacoPlatformViewState extends State<MonacoPlatformView> {
  static int _factorySeq = 0;

  String? _viewType;
  String? _editorId;
  Completer<web.HTMLDivElement>? _containerReady;
  StreamSubscription<String>? _onChangedSub;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
    _wireOnChanged(widget.controller);
  }

  @override
  void didUpdateWidget(MonacoPlatformView oldWidget) {
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
    final bridge = await WebMonacoBridge.instance();
    if (!mounted) return;

    final seq = ++_factorySeq;
    final containerId = 'monaco-container-$seq';
    final viewType = 'flutter-monaco-editor-$seq';
    _containerReady = Completer<web.HTMLDivElement>();

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final div = web.HTMLDivElement()
        ..id = containerId
        ..style.width = '100%'
        ..style.height = '100%';
      _containerReady?.complete(div);
      return div;
    });

    setState(() => _viewType = viewType);

    // Wait for the factory to fire, then for Flutter to finish the frame
    // where it attaches the div to the DOM. `Duration.zero` is a microtask —
    // Flutter's frame pipeline hasn't necessarily run by then, so
    // document.getElementById can return null. endOfFrame is the right hook.
    await _containerReady!.future;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final editorId = await bridge.invoke('editor.create', {
      'containerId': containerId,
      'options': widget.controller.buildCreateOptions(),
    }) as String;
    if (!mounted) {
      // Widget was unmounted while editor.create was in-flight. Clean up the
      // orphan editor on the JS side so it doesn't leak.
      unawaited(bridge.invoke('editor.dispose', {'editorId': editorId}));
      return;
    }
    if (widget.controller.isDisposed) {
      unawaited(bridge.invoke('editor.dispose', {'editorId': editorId}));
      return;
    }
    _editorId = editorId;
    widget.controller.attach(bridge, editorId);
  }

  @override
  void dispose() {
    _onChangedSub?.cancel();
    final editorId = _editorId;
    if (editorId != null) {
      widget.controller.detach();
      // Bridge call is fire-and-forget; the bridge survives beyond this widget.
      unawaited(
        WebMonacoBridge.instance().then(
          (b) => b.invoke('editor.dispose', {'editorId': editorId}),
        ),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _viewType;
    if (viewType == null) {
      return const SizedBox.expand();
    }
    return HtmlElementView(viewType: viewType);
  }
}
