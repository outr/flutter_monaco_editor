import 'package:flutter/widgets.dart';

import 'platform/platform_view.dart';

/// A Flutter widget that hosts a Monaco Editor instance.
///
/// Phase 1.2 — minimum viable editor. [initialValue], [language], and [theme]
/// apply on creation. [onChanged] fires on every content change. A full
/// `MonacoController` (position/selection/options/focus/events streams)
/// arrives in Phase 1.3.
///
/// Currently only web (Chrome, Firefox, Edge, Safari) is supported. Native
/// platforms (Android, iOS, macOS, Windows, Linux) render a placeholder
/// until Phase 4.
class MonacoEditor extends StatelessWidget {
  const MonacoEditor({
    super.key,
    this.initialValue = '',
    this.language = 'plaintext',
    this.theme = 'vs-dark',
    this.onChanged,
  });

  final String initialValue;
  final String language;
  final String theme;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MonacoPlatformView(
      initialValue: initialValue,
      language: language,
      theme: theme,
      onChanged: onChanged,
    );
  }
}
