/// An event emitted by the JS bridge — e.g. content change, cursor move,
/// ready signal, or a return value for an async invoke.
class BridgeEvent {
  const BridgeEvent(this.type, this.payload);

  /// The event type. Bridge lifecycle events use the `bridge.` prefix; editor
  /// events use `editor.`. Internal transport events use a `_` prefix.
  final String type;

  /// JSON-decoded payload. Always non-null; may be empty.
  final Map<String, Object?> payload;

  /// Convenience accessor — editor events carry this field.
  String? get editorId => payload['editorId'] as String?;

  @override
  String toString() => 'BridgeEvent($type, $payload)';
}
