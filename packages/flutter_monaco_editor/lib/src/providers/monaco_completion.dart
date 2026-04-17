import '../models/monaco_range.dart';
import 'monaco_provider_params.dart';

/// Mirrors Monaco's `CompletionItemKind` enum.
enum MonacoCompletionKind {
  method(0),
  function(1),
  constructor(2),
  field(3),
  variable(4),
  classKind(5),
  struct(6),
  interface(7),
  module(8),
  property(9),
  event(10),
  operator(11),
  unit(12),
  value(13),
  constant(14),
  enumKind(15),
  enumMember(16),
  keyword(17),
  text(18),
  color(19),
  file(20),
  reference(21),
  customColor(22),
  folder(23),
  typeParameter(24),
  user(25),
  issue(26),
  snippet(27);

  const MonacoCompletionKind(this.wireValue);
  final int wireValue;
}

/// Flags on `CompletionItem.insertTextRules`.
class MonacoInsertTextRule {
  const MonacoInsertTextRule._();
  static const int none = 0;

  /// Keep the whitespace before the insertion position.
  static const int keepWhitespace = 1;

  /// The `insertText` is a Monaco snippet — supports `$1`, `${1:placeholder}`,
  /// `${1|one,two|}`, etc.
  static const int insertAsSnippet = 4;
}

enum MonacoCompletionTriggerKind {
  invoke(0),
  triggerCharacter(1),
  triggerForIncompleteCompletions(2);

  const MonacoCompletionTriggerKind(this.wireValue);
  final int wireValue;

  static MonacoCompletionTriggerKind fromWire(int v) => switch (v) {
        0 => MonacoCompletionTriggerKind.invoke,
        1 => MonacoCompletionTriggerKind.triggerCharacter,
        2 => MonacoCompletionTriggerKind.triggerForIncompleteCompletions,
        _ => MonacoCompletionTriggerKind.invoke,
      };
}

class MonacoCompletionContext {
  const MonacoCompletionContext({
    required this.triggerKind,
    this.triggerCharacter,
  });

  factory MonacoCompletionContext.fromJson(Map<String, Object?> json) =>
      MonacoCompletionContext(
        triggerKind: MonacoCompletionTriggerKind.fromWire(
          (json['triggerKind'] as num?)?.toInt() ?? 0,
        ),
        triggerCharacter: json['triggerCharacter'] as String?,
      );

  final MonacoCompletionTriggerKind triggerKind;
  final String? triggerCharacter;
}

/// Parameters passed to [MonacoCompletionProvider.provideCompletionItems].
class MonacoCompletionParams extends MonacoProviderParams {
  const MonacoCompletionParams({
    required super.uri,
    required super.languageId,
    required super.value,
    required super.position,
    required this.context,
  });

  factory MonacoCompletionParams.fromJson(Map<String, Object?> json) {
    final base = MonacoProviderParams.fromJson(json);
    return MonacoCompletionParams(
      uri: base.uri,
      languageId: base.languageId,
      value: base.value,
      position: base.position,
      context: MonacoCompletionContext.fromJson(
        (json['context'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
    );
  }

  final MonacoCompletionContext context;
}

/// A single completion candidate. Fields correspond to Monaco's
/// `languages.CompletionItem`.
class MonacoCompletionItem {
  const MonacoCompletionItem({
    required this.label,
    required this.kind,
    required this.insertText,
    this.detail,
    this.documentation,
    this.sortText,
    this.filterText,
    this.insertTextRules = MonacoInsertTextRule.none,
    this.range,
    this.preselect,
    this.commitCharacters,
  });

  final String label;
  final MonacoCompletionKind kind;

  /// Short right-aligned text shown next to the label in the completion
  /// popup — commonly the type signature.
  final String? detail;

  /// Markdown rendered in the completion details panel.
  final String? documentation;

  final String insertText;

  /// Treated as a Monaco snippet when [MonacoInsertTextRule.insertAsSnippet]
  /// is set (bitwise OR with other rule flags).
  final int insertTextRules;

  /// Sort key — controls ordering when Monaco ranks completions.
  final String? sortText;

  /// Filter key — Monaco matches the user's typing against this instead of
  /// [label] if provided.
  final String? filterText;

  /// Replacement range. If null, Monaco substitutes at the current word.
  final MonacoRange? range;

  /// When true, Monaco pre-selects this item.
  final bool? preselect;

  final List<String>? commitCharacters;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{
      'label': label,
      'kind': kind.wireValue,
      'insertText': insertText,
      'insertTextRules': insertTextRules,
    };
    if (detail != null) out['detail'] = detail;
    if (documentation != null) {
      out['documentation'] = {'value': documentation, 'isTrusted': false};
    }
    if (sortText != null) out['sortText'] = sortText;
    if (filterText != null) out['filterText'] = filterText;
    if (range != null) out['range'] = range!.toJson();
    if (preselect != null) out['preselect'] = preselect;
    if (commitCharacters != null) out['commitCharacters'] = commitCharacters;
    return out;
  }
}

class MonacoCompletionList {
  const MonacoCompletionList({
    this.suggestions = const [],
    this.incomplete = false,
  });

  final List<MonacoCompletionItem> suggestions;

  /// When true, Monaco re-queries the provider as the user types instead
  /// of filtering the existing suggestions.
  final bool incomplete;
}

abstract interface class MonacoCompletionProvider {
  /// Characters that trigger completion when typed (e.g. `['.', ':']`).
  List<String> get triggerCharacters;

  Future<MonacoCompletionList> provideCompletionItems(
    MonacoCompletionParams params,
  );
}
