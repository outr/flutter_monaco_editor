import '../models/monaco_position.dart';

/// Context passed to every language provider — the text model, the position
/// where the feature was requested, and metadata about the triggering event.
class MonacoProviderParams {
  const MonacoProviderParams({
    required this.uri,
    required this.languageId,
    required this.value,
    required this.position,
  });

  factory MonacoProviderParams.fromJson(Map<String, Object?> json) =>
      MonacoProviderParams(
        uri: json['uri'] as String? ?? '',
        languageId: json['languageId'] as String? ?? '',
        value: json['value'] as String? ?? '',
        position: MonacoPosition(
          line: (json['line']! as num).toInt(),
          column: (json['column']! as num).toInt(),
        ),
      );

  /// Text model URI — e.g. `inmemory://model/1`. A Flutter IDE built on top
  /// of this package can set meaningful URIs via `monaco.Uri.parse(...)`.
  final String uri;

  /// Monaco language id (`'dart'`, `'javascript'`, ...).
  final String languageId;

  /// Entire model content at the time of the request. Providers that do
  /// substantial work should cache this by (uri, version).
  final String value;

  final MonacoPosition position;
}
