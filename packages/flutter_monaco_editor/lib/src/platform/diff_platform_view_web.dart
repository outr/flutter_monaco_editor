import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../monaco_diff_controller.dart';
import '../web/web_monaco_bridge.dart';

class MonacoDiffPlatformView extends StatefulWidget {
  const MonacoDiffPlatformView({super.key, required this.controller});

  final MonacoDiffController controller;

  @override
  State<MonacoDiffPlatformView> createState() => _MonacoDiffPlatformViewState();
}

class _MonacoDiffPlatformViewState extends State<MonacoDiffPlatformView> {
  static int _seq = 0;

  String? _viewType;
  String? _diffId;
  Completer<web.HTMLDivElement>? _containerReady;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final bridge = await WebMonacoBridge.instance();
    if (!mounted) return;

    final seq = ++_seq;
    final containerId = 'monaco-diff-$seq';
    final viewType = 'flutter-monaco-diff-$seq';
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

    // See platform_view_web.dart — Flutter's HtmlElementView insertion is
    // frame-scheduled, so a microtask is not enough.
    await _containerReady!.future;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final diffId = await bridge.invoke('diff.create', {
      'containerId': containerId,
      'options': widget.controller.buildCreateOptions(),
    }) as String;
    if (!mounted || widget.controller.isDisposed) {
      unawaited(bridge.invoke('diff.dispose', {'diffId': diffId}));
      return;
    }
    _diffId = diffId;
    widget.controller.attach(bridge, diffId);
  }

  @override
  void dispose() {
    final diffId = _diffId;
    if (diffId != null) {
      widget.controller.detach();
      unawaited(
        WebMonacoBridge.instance().then(
          (b) => b.invoke('diff.dispose', {'diffId': diffId}),
        ),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _viewType;
    if (viewType == null) return const SizedBox.expand();
    return HtmlElementView(viewType: viewType);
  }
}
