import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../bridge/bridge.dart';
import '../web/web_monaco_bridge.dart';

class MonacoPlatformView extends StatefulWidget {
  const MonacoPlatformView({
    super.key,
    required this.initialValue,
    required this.language,
    required this.theme,
    required this.onChanged,
  });

  final String initialValue;
  final String language;
  final String theme;
  final ValueChanged<String>? onChanged;

  @override
  State<MonacoPlatformView> createState() => _MonacoPlatformViewState();
}

class _MonacoPlatformViewState extends State<MonacoPlatformView> {
  static int _factorySeq = 0;

  String? _viewType;
  String? _editorId;
  MonacoBridge? _bridge;
  StreamSubscription<BridgeEvent>? _eventsSub;
  Completer<web.HTMLDivElement>? _containerReady;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final bridge = await WebMonacoBridge.instance();
    if (!mounted) return;
    _bridge = bridge;

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

    await _containerReady!.future;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final editorId = await bridge.invoke('editor.create', {
      'containerId': containerId,
      'options': <String, Object?>{
        'value': widget.initialValue,
        'language': widget.language,
        'theme': widget.theme,
        'automaticLayout': true,
      },
    }) as String;
    _editorId = editorId;

    _eventsSub = bridge.events.listen((event) {
      if (event.editorId != editorId) return;
      if (event.type == 'editor.contentChange') {
        final value = event.payload['value'];
        if (value is String) widget.onChanged?.call(value);
      }
    });
  }

  @override
  void dispose() {
    final bridge = _bridge;
    final editorId = _editorId;
    _eventsSub?.cancel();
    if (bridge != null && editorId != null) {
      unawaited(bridge.invoke('editor.dispose', {'editorId': editorId}));
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
