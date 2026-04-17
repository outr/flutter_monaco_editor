import '../models/monaco_range.dart';
import 'monaco_provider_params.dart';

/// A pointer to a region of a resource — used for go-to-definition and
/// find-references results.
class MonacoLocation {
  const MonacoLocation({required this.uri, required this.range});

  /// URI of the target resource. May be `inmemory://model/N` for in-memory
  /// models, or a `file://` / scheme-specific URL.
  final String uri;
  final MonacoRange range;

  Map<String, Object?> toJson() => {
        'uri': uri,
        'range': range.toJson(),
      };
}

abstract interface class MonacoDefinitionProvider {
  Future<List<MonacoLocation>?> provideDefinition(
    MonacoProviderParams params,
  );
}
