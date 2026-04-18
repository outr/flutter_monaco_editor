import 'package:flutter/material.dart';

import 'actions_demo.dart';
import 'background_demo.dart';
import 'basic_demo.dart';
import 'diagnostics_demo.dart';
import 'diff_demo.dart';
import 'intellisense_demo.dart';
import 'languages_demo.dart';
import 'options_demo.dart';
import 'themes_demo.dart';

/// One entry in the navigation rail — a demo page with a label and icon.
class Demo {
  const Demo({
    required this.label,
    required this.blurb,
    required this.icon,
    required this.builder,
  });

  final String label;
  final String blurb;
  final IconData icon;
  final WidgetBuilder builder;
}

const List<Demo> demos = [
  Demo(
    label: 'Basic',
    blurb: 'Minimal editor + read-only / theme toggles.',
    icon: Icons.article_outlined,
    builder: BasicDemo.builder,
  ),
  Demo(
    label: 'Languages',
    blurb: 'Switch syntax highlighting between Dart, JS, Python, JSON, HTML, Markdown, SQL.',
    icon: Icons.translate,
    builder: LanguagesDemo.builder,
  ),
  Demo(
    label: 'Options',
    blurb: 'Live toggles for font size, word wrap, minimap, line numbers, cursor style.',
    icon: Icons.tune,
    builder: OptionsDemo.builder,
  ),
  Demo(
    label: 'Diagnostics',
    blurb: 'Error / warning / info markers and inline + gutter decorations.',
    icon: Icons.error_outline,
    builder: DiagnosticsDemo.builder,
  ),
  Demo(
    label: 'Actions & Commands',
    blurb: 'Custom actions with keybindings, context-menu entries, and bare commands.',
    icon: Icons.keyboard,
    builder: ActionsDemo.builder,
  ),
  Demo(
    label: 'IntelliSense',
    blurb: 'Dart-side completion + hover providers with async round-trip to Monaco.',
    icon: Icons.auto_awesome,
    builder: IntelliSenseDemo.builder,
  ),
  Demo(
    label: 'Diff Editor',
    blurb: 'Side-by-side or inline diff of original vs. modified text.',
    icon: Icons.compare_arrows,
    builder: DiffDemo.builder,
  ),
  Demo(
    label: 'Custom Themes',
    blurb: 'Define named themes at runtime and switch between them globally.',
    icon: Icons.palette_outlined,
    builder: ThemesDemo.builder,
  ),
  Demo(
    label: 'Custom Background',
    blurb: 'Layer the editor on a Flutter-rendered background with transparent: true.',
    icon: Icons.wallpaper,
    builder: BackgroundDemo.builder,
  ),
];

/// Consistent chrome around each demo — title, blurb, content.
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.demo,
    required this.child,
    this.actions,
  });

  final Demo demo;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(demo.icon, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      demo.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      demo.blurb,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              ...?actions,
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
