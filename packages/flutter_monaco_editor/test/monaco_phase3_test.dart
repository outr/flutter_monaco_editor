import 'package:flutter_monaco_editor/flutter_monaco_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonacoCompletionItem', () {
    test('serializes with kind wire value + insertTextRules', () {
      const item = MonacoCompletionItem(
        label: 'foo',
        kind: MonacoCompletionKind.function,
        insertText: 'foo()',
        insertTextRules: MonacoInsertTextRule.insertAsSnippet,
        detail: 'void',
        documentation: 'Does things',
      );
      final j = item.toJson();
      expect(j['label'], 'foo');
      expect(j['kind'], 1); // Function
      expect(j['insertText'], 'foo()');
      expect(j['insertTextRules'], 4);
      expect(j['detail'], 'void');
      expect((j['documentation']! as Map)['value'], 'Does things');
    });

    test('range attached when present', () {
      const item = MonacoCompletionItem(
        label: 'x',
        kind: MonacoCompletionKind.variable,
        insertText: 'x',
        range: MonacoRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
      );
      expect(item.toJson()['range'], isA<Map<String, Object?>>());
    });
  });

  group('MonacoCompletionKind', () {
    test('wire values span 0..27 for all 28 kinds', () {
      expect(MonacoCompletionKind.values.length, 28);
      expect(MonacoCompletionKind.method.wireValue, 0);
      expect(MonacoCompletionKind.function.wireValue, 1);
      expect(MonacoCompletionKind.snippet.wireValue, 27);
    });
  });

  group('MonacoHover', () {
    test('contents wrap into Markdown value objects', () {
      const h = MonacoHover(contents: ['hello', '**bold**']);
      final j = h.toJson();
      final contents = j['contents']! as List;
      expect(contents.length, 2);
      expect((contents.first as Map)['value'], 'hello');
    });
  });

  group('MonacoSignatureHelp', () {
    test('serialization covers signatures + active indices', () {
      const help = MonacoSignatureHelp(
        signatures: [
          MonacoSignatureInformation(
            label: 'foo(a, b)',
            parameters: [
              MonacoParameterInformation(label: 'a'),
              MonacoParameterInformation(label: 'b'),
            ],
          ),
        ],
        activeParameter: 1,
      );
      final j = help.toJson();
      expect(j['activeSignature'], 0);
      expect(j['activeParameter'], 1);
      expect((j['signatures']! as List).length, 1);
    });
  });

  group('MonacoLocation', () {
    test('uri + range round trip via JSON', () {
      const loc = MonacoLocation(
        uri: 'file:///a.dart',
        range: MonacoRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 5),
      );
      final j = loc.toJson();
      expect(j['uri'], 'file:///a.dart');
      expect(j['range'], isA<Map<String, Object?>>());
    });
  });

  group('MonacoCompletionContext', () {
    test('triggerKind.fromWire maps values', () {
      expect(MonacoCompletionTriggerKind.fromWire(0),
          MonacoCompletionTriggerKind.invoke);
      expect(MonacoCompletionTriggerKind.fromWire(1),
          MonacoCompletionTriggerKind.triggerCharacter);
      expect(MonacoCompletionTriggerKind.fromWire(2),
          MonacoCompletionTriggerKind.triggerForIncompleteCompletions);
      expect(MonacoCompletionTriggerKind.fromWire(99),
          MonacoCompletionTriggerKind.invoke); // default fallback
    });
  });
}
