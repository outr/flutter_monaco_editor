import 'dart:async';

import 'bridge/bridge.dart';

/// Programmatic interface to a `MonacoDiffEditor` instance.
///
/// A diff editor hosts two underlying text editors — the "original" (left,
/// read-only by default) and the "modified" (right, user-editable by default).
/// Each side has its own content and change stream.
class MonacoDiffController {
  MonacoDiffController({
    String originalValue = '',
    String modifiedValue = '',
    String language = 'plaintext',
    String theme = 'vs-dark',
    bool renderSideBySide = true,
    bool readOnly = false,
    bool ignoreTrimWhitespace = false,
  })  : _cachedOriginal = originalValue,
        _cachedModified = modifiedValue,
        _cachedLanguage = language,
        _cachedTheme = theme,
        _renderSideBySide = renderSideBySide,
        _readOnly = readOnly,
        _ignoreTrimWhitespace = ignoreTrimWhitespace;

  MonacoBridge? _bridge;
  String? _diffId;
  StreamSubscription<BridgeEvent>? _eventsSub;
  final Completer<void> _readyCompleter = Completer<void>();
  bool _disposed = false;

  String _cachedOriginal;
  String _cachedModified;
  String _cachedLanguage;
  final String _cachedTheme;
  final bool _renderSideBySide;
  final bool _readOnly;
  final bool _ignoreTrimWhitespace;

  final StreamController<String> _originalCtrl =
      StreamController<String>.broadcast();
  final StreamController<String> _modifiedCtrl =
      StreamController<String>.broadcast();

  // --- state ---
  String get originalValue => _cachedOriginal;
  String get modifiedValue => _cachedModified;
  String get language => _cachedLanguage;
  String get theme => _cachedTheme;
  bool get isAttached => _bridge != null && _diffId != null;

  /// Whether [dispose] has been called on this controller.
  bool get isDisposed => _disposed;
  Future<void> get ready => _readyCompleter.future;

  // --- setters ---
  Future<void> setOriginalValue(String value) async {
    _assertNotDisposed();
    _cachedOriginal = value;
    if (!isAttached) return;
    await _bridge!.invoke('diff.setOriginal', {
      'diffId': _diffId!,
      'value': value,
    });
  }

  Future<void> setModifiedValue(String value) async {
    _assertNotDisposed();
    _cachedModified = value;
    if (!isAttached) return;
    await _bridge!.invoke('diff.setModified', {
      'diffId': _diffId!,
      'value': value,
    });
  }

  Future<void> setLanguage(String language) async {
    _assertNotDisposed();
    _cachedLanguage = language;
    if (!isAttached) return;
    await _bridge!.invoke('diff.setLanguage', {
      'diffId': _diffId!,
      'language': language,
    });
  }

  // --- streams ---
  Stream<String> get onOriginalChange => _originalCtrl.stream;
  Stream<String> get onModifiedChange => _modifiedCtrl.stream;

  // --- internal (used by the diff platform view) ---
  Map<String, Object?> buildCreateOptions() => {
        'original': _cachedOriginal,
        'modified': _cachedModified,
        'language': _cachedLanguage,
        'theme': _cachedTheme,
        'renderSideBySide': _renderSideBySide,
        // Monaco's default behavior is to auto-switch to inline view when
        // the container is narrower than ~900px. That's great for web
        // resizing but bad on mobile where you'd never see side-by-side.
        // Honor the caller's explicit choice — if they say side-by-side,
        // give them side-by-side regardless of width.
        'useInlineViewWhenSpaceIsLimited': !_renderSideBySide,
        'readOnly': _readOnly,
        'ignoreTrimWhitespace': _ignoreTrimWhitespace,
        'automaticLayout': true,
      };

  void attach(MonacoBridge bridge, String diffId) {
    if (_disposed) {
      throw StateError('MonacoDiffController.attach called on disposed controller');
    }
    _bridge = bridge;
    _diffId = diffId;
    _eventsSub = bridge.events.listen(_onEvent);
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  void detach() {
    _eventsSub?.cancel();
    _eventsSub = null;
    _bridge = null;
    _diffId = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventsSub?.cancel();
    _eventsSub = null;
    if (_bridge != null && _diffId != null) {
      unawaited(_bridge!.invoke('diff.dispose', {'diffId': _diffId!}));
    }
    _bridge = null;
    _diffId = null;
    await Future.wait([
      _originalCtrl.close(),
      _modifiedCtrl.close(),
    ]);
  }

  void _onEvent(BridgeEvent event) {
    if (event.payload['diffId'] != _diffId) return;
    switch (event.type) {
      case 'diff.originalChange':
        final v = event.payload['value'];
        if (v is String) {
          _cachedOriginal = v;
          _originalCtrl.add(v);
        }
      case 'diff.modifiedChange':
        final v = event.payload['value'];
        if (v is String) {
          _cachedModified = v;
          _modifiedCtrl.add(v);
        }
    }
  }

  void _assertNotDisposed() {
    if (_disposed) throw StateError('MonacoDiffController is disposed');
  }
}
