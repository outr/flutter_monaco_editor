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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _initialCode = '''
// flutter_monaco_editor — Phase 1.2 preview
// Bundled Monaco: $monacoVersion
void main() {
  final editor = 'Monaco';
  print('Hello from \$editor!');
}
''';

  int _charCount = _initialCode.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_monaco_editor'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Monaco $monacoVersion  •  $_charCount chars',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
      body: MonacoEditor(
        initialValue: _initialCode,
        language: 'dart',
        onChanged: (value) => setState(() => _charCount = value.length),
      ),
    );
  }
}
