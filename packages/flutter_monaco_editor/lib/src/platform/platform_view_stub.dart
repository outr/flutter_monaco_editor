import 'package:flutter/widgets.dart';

import '../monaco_controller.dart';
import '../platform_hooks.dart';

/// Fallback for platforms where no implementation has registered.
/// [MonacoPlatformHooks.install] swaps in the real view factory for
/// native platforms.
class MonacoPlatformView extends StatelessWidget {
  const MonacoPlatformView({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final MonacoController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final factory = MonacoPlatformHooks.platformViewFactory;
    if (factory != null) return factory(controller, onChanged);
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'flutter_monaco_editor: no native implementation registered.\n\n'
          'Add flutter_monaco_editor_native to your pubspec and call\n'
          'MonacoNative.register() before runApp() to enable editing on '
          'this platform.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
