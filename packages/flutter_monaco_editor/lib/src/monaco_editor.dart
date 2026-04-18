import 'package:flutter/widgets.dart';

import 'monaco_controller.dart';
import 'options/options.dart';
import 'platform/platform_view.dart';

/// A Flutter widget that hosts a Monaco Editor instance.
///
/// Provide a [controller] for programmatic access (get/set value, cursor,
/// event streams, ...). If omitted, the widget creates and owns an internal
/// controller — useful for simple read-only displays.
///
/// Currently only web (Chrome, Firefox, Edge, Safari) is supported. Native
/// platforms (Android, iOS, macOS, Windows, Linux) render a placeholder
/// until Phase 4.
class MonacoEditor extends StatefulWidget {
  const MonacoEditor({
    super.key,
    this.controller,
    this.initialValue = '',
    this.language = 'plaintext',
    this.theme = 'vs-dark',
    this.readOnly = false,
    this.options,
    this.onChanged,
    this.transparent = false,
  }) : assert(
          controller == null ||
              (initialValue == '' &&
                  language == 'plaintext' &&
                  theme == 'vs-dark' &&
                  readOnly == false &&
                  options == null),
          'When a MonacoController is provided, configure initial state on '
          'the controller instead of passing initialValue/language/theme/'
          'readOnly/options to the widget.',
        );

  /// Optional controller for programmatic access. If null, the widget owns
  /// an internal controller built from [initialValue], [language], [theme],
  /// [readOnly], and [options].
  final MonacoController? controller;

  /// Initial content. Ignored if [controller] is provided.
  final String initialValue;

  /// Initial language mode. Ignored if [controller] is provided.
  final String language;

  /// Initial Monaco theme. Ignored if [controller] is provided.
  final String theme;

  /// Initial read-only mode. Ignored if [controller] is provided.
  final bool readOnly;

  /// Typed editor options. Ignored if [controller] is provided.
  final MonacoEditorOptions? options;

  /// Shortcut callback that fires on content changes. Equivalent to
  /// `controller.onDidChangeContent.listen(...)`.
  final ValueChanged<String>? onChanged;

  /// When true, the underlying editor host has a transparent background.
  ///
  /// - **Web**: the host div has no background of its own, so transparency
  ///   is governed by the active Monaco theme's `editor.background` color.
  ///   Use `MonacoTheme.transparent()` (or a theme with alpha=0 backgrounds)
  ///   alongside this flag to reveal a Flutter background image behind
  ///   the editor.
  /// - **Native (webview)**: the underlying WebView's background color is
  ///   set to transparent. Combined with a transparent theme, a Flutter
  ///   widget behind the editor shows through.
  final bool transparent;

  @override
  State<MonacoEditor> createState() => _MonacoEditorState();
}

class _MonacoEditorState extends State<MonacoEditor> {
  MonacoController? _internalController;

  MonacoController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = MonacoController(
        initialValue: widget.initialValue,
        language: widget.language,
        theme: widget.theme,
        readOnly: widget.readOnly,
        options: widget.options,
      );
    }
  }

  @override
  void didUpdateWidget(MonacoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null && widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      } else if (oldWidget.controller != null && widget.controller == null) {
        _internalController = MonacoController(
          initialValue: widget.initialValue,
          language: widget.language,
          theme: widget.theme,
          readOnly: widget.readOnly,
          options: widget.options,
        );
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MonacoPlatformView(
      controller: _effectiveController,
      onChanged: widget.onChanged,
      transparent: widget.transparent,
    );
  }
}
