import 'monaco_provider_params.dart';

/// Mirrors Monaco's `SignatureHelpTriggerKind`.
enum MonacoSignatureHelpTriggerKind {
  invoke(1),
  triggerCharacter(2),
  contentChange(3);

  const MonacoSignatureHelpTriggerKind(this.wireValue);
  final int wireValue;

  static MonacoSignatureHelpTriggerKind fromWire(int v) => switch (v) {
        1 => MonacoSignatureHelpTriggerKind.invoke,
        2 => MonacoSignatureHelpTriggerKind.triggerCharacter,
        3 => MonacoSignatureHelpTriggerKind.contentChange,
        _ => MonacoSignatureHelpTriggerKind.invoke,
      };
}

class MonacoSignatureHelpContext {
  const MonacoSignatureHelpContext({
    required this.triggerKind,
    this.triggerCharacter,
    this.isRetrigger = false,
  });

  factory MonacoSignatureHelpContext.fromJson(Map<String, Object?> json) =>
      MonacoSignatureHelpContext(
        triggerKind: MonacoSignatureHelpTriggerKind.fromWire(
          (json['triggerKind'] as num?)?.toInt() ?? 1,
        ),
        triggerCharacter: json['triggerCharacter'] as String?,
        isRetrigger: json['isRetrigger'] as bool? ?? false,
      );

  final MonacoSignatureHelpTriggerKind triggerKind;
  final String? triggerCharacter;
  final bool isRetrigger;
}

class MonacoSignatureHelpParams extends MonacoProviderParams {
  const MonacoSignatureHelpParams({
    required super.uri,
    required super.languageId,
    required super.value,
    required super.position,
    required this.context,
  });

  factory MonacoSignatureHelpParams.fromJson(Map<String, Object?> json) {
    final base = MonacoProviderParams.fromJson(json);
    return MonacoSignatureHelpParams(
      uri: base.uri,
      languageId: base.languageId,
      value: base.value,
      position: base.position,
      context: MonacoSignatureHelpContext.fromJson(
        (json['context'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
    );
  }

  final MonacoSignatureHelpContext context;
}

class MonacoParameterInformation {
  const MonacoParameterInformation({required this.label, this.documentation});

  final String label;
  final String? documentation;

  Map<String, Object?> toJson() => {
        'label': label,
        if (documentation != null)
          'documentation': {'value': documentation, 'isTrusted': false},
      };
}

class MonacoSignatureInformation {
  const MonacoSignatureInformation({
    required this.label,
    this.documentation,
    this.parameters = const [],
    this.activeParameter,
  });

  final String label;
  final String? documentation;
  final List<MonacoParameterInformation> parameters;
  final int? activeParameter;

  Map<String, Object?> toJson() => {
        'label': label,
        if (documentation != null)
          'documentation': {'value': documentation, 'isTrusted': false},
        'parameters': parameters.map((p) => p.toJson()).toList(),
        if (activeParameter != null) 'activeParameter': activeParameter,
      };
}

class MonacoSignatureHelp {
  const MonacoSignatureHelp({
    required this.signatures,
    this.activeSignature = 0,
    this.activeParameter = 0,
  });

  final List<MonacoSignatureInformation> signatures;
  final int activeSignature;
  final int activeParameter;

  Map<String, Object?> toJson() => {
        'signatures': signatures.map((s) => s.toJson()).toList(),
        'activeSignature': activeSignature,
        'activeParameter': activeParameter,
      };
}

abstract interface class MonacoSignatureHelpProvider {
  /// Characters that open signature help when typed (typically `['(', ',']`).
  List<String> get triggerCharacters;
  List<String> get retriggerCharacters => const [];

  Future<MonacoSignatureHelp?> provideSignatureHelp(
    MonacoSignatureHelpParams params,
  );
}
