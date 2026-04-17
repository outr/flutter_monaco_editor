import 'dart:async';

import 'bridge/bridge.dart';
import 'platform/bridge_acquire.dart';
import 'providers/providers.dart';

/// Top-level access to Monaco's `monaco.languages.*` registration surface.
///
/// Providers are process-global, keyed by language id — not per-editor.
/// Every editor rendering the matching language sees the provider's
/// contributions.
///
/// All `register*` methods return a [MonacoDisposable]; call `dispose()` to
/// unregister the provider. Dart-side state (e.g. the Dart callback) is
/// cleaned up atomically with the JS-side registration.
class MonacoLanguages {
  MonacoLanguages._();

  static int _nextProviderId = 1;
  static final Map<int, _ProviderEntry> _providers = {};
  static bool _eventsWired = false;

  static Future<MonacoDisposable> registerCompletionProvider(
    String languageId,
    MonacoCompletionProvider provider,
  ) async {
    final bridge = await acquireBridge();
    await _wireEventsOnce(bridge);
    final id = _nextProviderId++;
    _providers[id] = _CompletionEntry(provider);
    await bridge.invoke('languages.registerCompletionProvider', {
      'providerId': id,
      'languageId': languageId,
      'triggerCharacters': provider.triggerCharacters,
    });
    return MonacoDisposableCallback(() => _unregister(bridge, id));
  }

  static Future<MonacoDisposable> registerHoverProvider(
    String languageId,
    MonacoHoverProvider provider,
  ) async {
    final bridge = await acquireBridge();
    await _wireEventsOnce(bridge);
    final id = _nextProviderId++;
    _providers[id] = _HoverEntry(provider);
    await bridge.invoke('languages.registerHoverProvider', {
      'providerId': id,
      'languageId': languageId,
    });
    return MonacoDisposableCallback(() => _unregister(bridge, id));
  }

  static Future<MonacoDisposable> registerSignatureHelpProvider(
    String languageId,
    MonacoSignatureHelpProvider provider,
  ) async {
    final bridge = await acquireBridge();
    await _wireEventsOnce(bridge);
    final id = _nextProviderId++;
    _providers[id] = _SignatureHelpEntry(provider);
    await bridge.invoke('languages.registerSignatureHelpProvider', {
      'providerId': id,
      'languageId': languageId,
      'triggerCharacters': provider.triggerCharacters,
      'retriggerCharacters': provider.retriggerCharacters,
    });
    return MonacoDisposableCallback(() => _unregister(bridge, id));
  }

  static Future<MonacoDisposable> registerDefinitionProvider(
    String languageId,
    MonacoDefinitionProvider provider,
  ) async {
    final bridge = await acquireBridge();
    await _wireEventsOnce(bridge);
    final id = _nextProviderId++;
    _providers[id] = _DefinitionEntry(provider);
    await bridge.invoke('languages.registerDefinitionProvider', {
      'providerId': id,
      'languageId': languageId,
    });
    return MonacoDisposableCallback(() => _unregister(bridge, id));
  }

  static Future<void> _unregister(MonacoBridge bridge, int providerId) async {
    _providers.remove(providerId);
    await bridge.invoke('languages.unregisterProvider', {
      'providerId': providerId,
    });
  }

  static Future<void> _wireEventsOnce(MonacoBridge bridge) async {
    if (_eventsWired) return;
    _eventsWired = true;
    bridge.events.listen((event) => _handleEvent(bridge, event));
  }

  static Future<void> _handleEvent(
    MonacoBridge bridge,
    BridgeEvent event,
  ) async {
    final providerId = (event.payload['providerId'] as num?)?.toInt();
    final requestId = event.payload['requestId'] as String?;
    if (providerId == null || requestId == null) return;

    final entry = _providers[providerId];
    if (entry == null) {
      // Provider was disposed while a request was in flight — tell JS to
      // resolve with null so Monaco doesn't hang.
      await bridge.invoke('languages.respond', {
        'requestId': requestId,
        'result': null,
      });
      return;
    }

    try {
      final result = await entry.handle(event);
      await bridge.invoke('languages.respond', {
        'requestId': requestId,
        'result': result,
      });
    } catch (e, st) {
      await bridge.invoke('languages.respond', {
        'requestId': requestId,
        'error': '$e\n$st',
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Internal provider-entry dispatch — one subtype per provider kind; each
// returns the JSON result to send back over the bridge.
// ---------------------------------------------------------------------------

abstract class _ProviderEntry {
  Future<Object?> handle(BridgeEvent event);
}

class _CompletionEntry extends _ProviderEntry {
  _CompletionEntry(this.provider);
  final MonacoCompletionProvider provider;

  @override
  Future<Object?> handle(BridgeEvent event) async {
    if (event.type != 'language.completion.request') return null;
    final params = MonacoCompletionParams.fromJson(event.payload);
    final list = await provider.provideCompletionItems(params);
    return {
      'suggestions': list.suggestions.map((s) => s.toJson()).toList(),
      'incomplete': list.incomplete,
    };
  }
}

class _HoverEntry extends _ProviderEntry {
  _HoverEntry(this.provider);
  final MonacoHoverProvider provider;

  @override
  Future<Object?> handle(BridgeEvent event) async {
    if (event.type != 'language.hover.request') return null;
    final params = MonacoProviderParams.fromJson(event.payload);
    final hover = await provider.provideHover(params);
    return hover?.toJson();
  }
}

class _SignatureHelpEntry extends _ProviderEntry {
  _SignatureHelpEntry(this.provider);
  final MonacoSignatureHelpProvider provider;

  @override
  Future<Object?> handle(BridgeEvent event) async {
    if (event.type != 'language.signatureHelp.request') return null;
    final params = MonacoSignatureHelpParams.fromJson(event.payload);
    final help = await provider.provideSignatureHelp(params);
    return help?.toJson();
  }
}

class _DefinitionEntry extends _ProviderEntry {
  _DefinitionEntry(this.provider);
  final MonacoDefinitionProvider provider;

  @override
  Future<Object?> handle(BridgeEvent event) async {
    if (event.type != 'language.definition.request') return null;
    final params = MonacoProviderParams.fromJson(event.payload);
    final locations = await provider.provideDefinition(params);
    if (locations == null) return null;
    return locations.map((l) => l.toJson()).toList();
  }
}
