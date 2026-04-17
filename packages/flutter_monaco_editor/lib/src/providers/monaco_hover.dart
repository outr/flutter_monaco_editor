import '../models/monaco_range.dart';
import 'monaco_provider_params.dart';

/// A hover tooltip result — a list of Markdown-formatted content blocks
/// optionally pinned to [range].
class MonacoHover {
  const MonacoHover({required this.contents, this.range});

  /// Each entry is rendered as a Markdown block in the hover popup.
  final List<String> contents;

  /// Highlighted range in the editor when the hover is visible. If null,
  /// Monaco infers from the word under the cursor.
  final MonacoRange? range;

  Map<String, Object?> toJson() => {
        'contents': contents
            .map((c) => {'value': c, 'isTrusted': false})
            .toList(),
        if (range != null) 'range': range!.toJson(),
      };
}

abstract interface class MonacoHoverProvider {
  Future<MonacoHover?> provideHover(MonacoProviderParams params);
}
