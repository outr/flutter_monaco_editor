import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_monaco_editor/flutter_monaco_editor.dart';

import 'demo.dart';

class BackgroundDemo extends StatefulWidget {
  const BackgroundDemo({super.key});

  static Widget builder(BuildContext context) => const BackgroundDemo();

  @override
  State<BackgroundDemo> createState() => _BackgroundDemoState();
}

class _BackgroundDemoState extends State<BackgroundDemo> {
  static const Demo _demo = Demo(
    label: 'Custom Background',
    blurb: 'Layer the editor on a Flutter-rendered background with transparent: true.',
    icon: Icons.wallpaper,
    builder: BackgroundDemo.builder,
  );

  static const String _code = '''
// Toggle "Transparent" in the header to reveal the Flutter gradient.
// When enabled, the demo:
//   1. Sets MonacoEditor(transparent: true) — clears the editor host bg
//      (web: theme-driven; native: WebView setBackgroundColor transparent)
//   2. Registers MonacoTheme.transparent() and activates it globally,
//      zeroing every editor chrome color that could cover the background.
//
// Syntax highlighting still works because the transparent theme inherits
// token colors from its base ('vs-dark' by default).

class BackgroundImage extends StatelessWidget {
  const BackgroundImage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Your background image / gradient / animation goes here.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A237E),
                Color(0xFF311B92),
                Color(0xFFB71C1C),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
''';

  late final MonacoController _controller;
  bool _transparent = false;
  bool _themesReady = false;

  @override
  void initState() {
    super.initState();
    _controller = MonacoController(
      initialValue: _code,
      language: 'dart',
    );
    unawaited(_setupThemes());
  }

  Future<void> _setupThemes() async {
    await _controller.ready;
    await MonacoThemes.defineTheme(
      'demo-transparent',
      MonacoTheme.transparent(),
    );
    if (mounted) setState(() => _themesReady = true);
  }

  Future<void> _toggle() async {
    setState(() => _transparent = !_transparent);
    await MonacoThemes.setTheme(_transparent ? 'demo-transparent' : 'vs-dark');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      demo: _demo,
      actions: [
        FilterChip(
          label: const Text('Transparent'),
          selected: _transparent,
          onSelected: _themesReady ? (_) => _toggle() : null,
        ),
        const SizedBox(width: 8),
      ],
      // Stack the editor over a custom-painted gradient background. In a
      // real app this layer could be a NetworkImage, an asset Image, an
      // AnimatedContainer — anything.
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _DemoBackground(),
          // Key on transparency so we rebuild MonacoEditor when toggled,
          // giving the native WebView path a chance to pick up the new
          // transparent flag. On web the flag is a no-op; the theme swap
          // does the work.
          KeyedSubtree(
            key: ValueKey(_transparent),
            child: MonacoEditor(
              controller: _controller,
              transparent: _transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoBackground extends StatelessWidget {
  const _DemoBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.35, 0.75, 1.0],
          colors: [
            Color(0xFF0D1117),
            Color(0xFF1A237E),
            Color(0xFF311B92),
            Color(0xFFB71C1C),
          ],
        ),
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

/// Faint grid overlay — makes the transparency obvious when active.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
