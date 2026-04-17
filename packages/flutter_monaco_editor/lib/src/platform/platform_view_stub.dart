import 'package:flutter/widgets.dart';

/// Non-web stub. Phase 4 replaces this with a webview-backed implementation.
class MonacoPlatformView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'flutter_monaco_editor: this platform is not yet supported.\n'
        'Run on web (Chrome) for now. Native support arrives in Phase 4.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
