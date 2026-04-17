import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_monaco_editor/flutter_monaco_editor.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_monaco_editor example',
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

const String _initialCode = '''
// flutter_monaco_editor — Phase 3 preview
// Bundled Monaco: $monacoVersion
//
// Try:
//   * Type "pr" or "fl" or "wi" to see Dart-ish completions
//     (provided by DemoCompletionProvider below)
//   * Hover any of: "print", "Future", "main" — docs come from
//     DemoHoverProvider
//   * Ctrl/Cmd+Shift+L — excited-greeting action
//   * Ctrl/Cmd+K — demo snackbar command
//   * Right-click — see the registered action in the context menu

import 'dart:async';
import 'package:flutter/material.dart';

Future<void> main() async {
  final greetings = ['Hello', 'Bonjour', 'Hallo', 'Hola', 'こんにちは'];
  for (final greeting in greetings) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    print('\$greeting from Monaco!');
  }
  print('All done.');
}
''';

/// A trivial Dart-ish completion provider. Real IDEs drive this from
/// a language server; this one hardcodes a handful of items.
class DemoCompletionProvider implements MonacoCompletionProvider {
  @override
  List<String> get triggerCharacters => const ['.'];

  static const List<MonacoCompletionItem> _items = [
    MonacoCompletionItem(
      label: 'print',
      kind: MonacoCompletionKind.function,
      insertText: 'print(\${1:value});',
      insertTextRules: MonacoInsertTextRule.insertAsSnippet,
      detail: 'void print(Object? value)',
      documentation: 'Writes the string representation of `value` to stdout.',
    ),
    MonacoCompletionItem(
      label: 'Future.delayed',
      kind: MonacoCompletionKind.constructor,
      insertText: 'Future<void>.delayed(const Duration(milliseconds: \${1:100}));',
      insertTextRules: MonacoInsertTextRule.insertAsSnippet,
      detail: 'Future<T>.delayed(Duration duration, [FutureOr<T> Function()?])',
      documentation: 'Creates a future that completes after the given duration.',
    ),
    MonacoCompletionItem(
      label: 'flutter_monaco_editor',
      kind: MonacoCompletionKind.module,
      insertText: 'flutter_monaco_editor',
      detail: 'package',
      documentation: 'This package. See PLAN.md for roadmap.',
    ),
    MonacoCompletionItem(
      label: 'withColors',
      kind: MonacoCompletionKind.snippet,
      insertText:
          'const Text(\n  \'\${1:text}\',\n  style: TextStyle(color: \${2:Colors.blue}),\n)',
      insertTextRules: MonacoInsertTextRule.insertAsSnippet,
      detail: 'Styled Text snippet',
    ),
  ];

  @override
  Future<MonacoCompletionList> provideCompletionItems(
    MonacoCompletionParams params,
  ) async {
    return const MonacoCompletionList(suggestions: _items);
  }
}

/// A trivial hover provider that returns Markdown docs for a few tokens.
class DemoHoverProvider implements MonacoHoverProvider {
  static const Map<String, String> _docs = {
    'print': '**print(value)** — writes the value to stdout.\n\n_Provided by DemoHoverProvider._',
    'Future': '**Future&lt;T&gt;** — represents a computation that may not have completed yet.',
    'main': '**main()** — the entry point of every Dart program.',
    'Monaco': '**Monaco Editor** — VS Code\'s editor, embedded in Flutter via `flutter_monaco_editor`.',
  };

  @override
  Future<MonacoHover?> provideHover(MonacoProviderParams params) async {
    final line = _extractLine(params.value, params.position.line);
    final word = _wordAt(line, params.position.column);
    final doc = _docs[word];
    if (doc == null) return null;
    return MonacoHover(contents: [doc]);
  }

  static String _extractLine(String full, int line) {
    final lines = full.split('\n');
    return (line - 1) < lines.length ? lines[line - 1] : '';
  }

  static String _wordAt(String line, int column) {
    final idx = column - 1;
    if (idx < 0 || idx > line.length) return '';
    var start = idx;
    var end = idx;
    bool isWord(int i) =>
        i >= 0 && i < line.length && RegExp(r'[A-Za-z_]').hasMatch(line[i]);
    while (isWord(start - 1)) {
      start--;
    }
    while (isWord(end)) {
      end++;
    }
    return line.substring(start, end);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MonacoController _controller;

  MonacoPosition? _position;
  int _charCount = _initialCode.length;
  bool _readOnly = false;
  MonacoDisposable? _completionDispose;
  MonacoDisposable? _hoverDispose;

  @override
  void initState() {
    super.initState();
    _controller = MonacoController(
      initialValue: _initialCode,
      language: 'dart',
      options: const MonacoEditorOptions(
        fontSize: 14,
        bracketPairColorization: true,
        smoothScrolling: true,
        cursorSmoothCaretAnimation: true,
        glyphMargin: true,
        quickSuggestions: true,
      ),
    );

    _controller.onDidChangeContent.listen((value) {
      setState(() => _charCount = value.length);
    });
    _controller.onDidChangeCursorPosition.listen((pos) {
      setState(() => _position = pos);
    });

    unawaited(_afterReady());
  }

  Future<void> _afterReady() async {
    await _controller.ready;

    // Phase 3 — language providers
    _completionDispose = await MonacoLanguages.registerCompletionProvider(
      'dart',
      DemoCompletionProvider(),
    );
    _hoverDispose = await MonacoLanguages.registerHoverProvider(
      'dart',
      DemoHoverProvider(),
    );

    // Phase 2 — action & command
    await _controller.addAction(MonacoAction(
      id: 'example.exciteGreeting',
      label: 'Excite the first "Hello"',
      keybindings: const [
        MonacoKeyMod.ctrlCmd | MonacoKeyMod.shift | MonacoKeyCode.keyL,
      ],
      contextMenuGroupId: '1_modification',
      contextMenuOrder: 1.5,
      run: (_) async {
        final value = _controller.value;
        if (!value.contains('Hello')) return;
        final updated = value.replaceFirst('Hello', 'Hello!');
        await _controller.setValue(updated);
        if (mounted) _snack('Added enthusiasm to "Hello"');
      },
    ));

    await _controller.addCommand(
      MonacoKeyMod.ctrlCmd | MonacoKeyCode.keyK,
      () => _snack('Ctrl/Cmd+K fired from Monaco'),
    );

    // Warning marker on the greetings line.
    await _controller.setModelMarkers(
      const [
        MonacoMarker(
          range: MonacoRange(
            startLine: 13, startColumn: 1, endLine: 13, endColumn: 80,
          ),
          severity: MonacoMarkerSeverity.info,
          message: 'Demo diagnostic — localization ready!',
          source: 'example',
        ),
      ],
      owner: 'example',
    );
  }

  @override
  void dispose() {
    unawaited(_completionDispose?.dispose());
    unawaited(_hoverDispose?.dispose());
    _controller.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _toggleReadOnly() async {
    setState(() => _readOnly = !_readOnly);
    await _controller.setReadOnly(_readOnly);
  }

  Future<void> _triggerCompletion() async {
    await _controller.trigger('editor.action.triggerSuggest');
  }

  @override
  Widget build(BuildContext context) {
    final pos = _position;
    final statusLine = [
      'Monaco $monacoVersion',
      '$_charCount chars',
      if (pos != null) 'Ln ${pos.line}, Col ${pos.column}',
      if (_readOnly) 'read-only',
    ].join('  •  ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_monaco_editor'),
        actions: [
          IconButton(
            tooltip: _readOnly ? 'Enable editing' : 'Set read-only',
            icon: Icon(_readOnly ? Icons.lock : Icons.lock_open),
            onPressed: _toggleReadOnly,
          ),
          IconButton(
            tooltip: 'Trigger completion (Ctrl+Space)',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _triggerCompletion,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                statusLine,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
      body: MonacoEditor(controller: _controller),
    );
  }
}
