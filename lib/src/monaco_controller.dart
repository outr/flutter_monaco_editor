import 'dart:async';

import 'bridge/bridge.dart';
import 'models/models.dart';
import 'options/options.dart';

/// The programmatic interface to a single `MonacoEditor` instance.
///
/// Lifetime:
///   1. Create a controller (optionally with initial state).
///   2. Pass it to `MonacoEditor(controller: ...)`.
///   3. When the widget mounts and the underlying editor is created, the
///      controller transitions to the *attached* state — [ready] completes.
///   4. When the widget unmounts, the controller detaches. It can be
///      re-attached to another widget, or disposed.
///   5. Call [dispose] when you're done with it.
///
/// Calls made before attachment are safe:
/// - State setters ([setValue], [setLanguage], [setReadOnly]) update cached
///   values; those values are used as creation options when the editor is
///   built.
/// - Stateless methods ([setPosition], [setSelection], [revealLine], ...)
///   await [ready] and then invoke the bridge.
class MonacoController {
  MonacoController({
    String initialValue = '',
    String language = 'plaintext',
    String theme = 'vs-dark',
    bool readOnly = false,
    MonacoEditorOptions? options,
  })  : _cachedValue = initialValue,
        _cachedLanguage = language,
        _cachedTheme = theme,
        _cachedReadOnly = readOnly,
        _cachedOptions = options;

  // --- bridge state ---
  MonacoBridge? _bridge;
  String? _editorId;
  StreamSubscription<BridgeEvent>? _eventsSub;
  final Completer<void> _readyCompleter = Completer<void>();
  bool _disposed = false;

  // --- action / command callback maps ---
  final Map<String, MonacoActionCallback> _actionHandlers = {};
  final Map<String, void Function()> _commandHandlers = {};
  int _nextCommandId = 1;

  // --- cached state ---
  String _cachedValue;
  String _cachedLanguage;
  String _cachedTheme;
  bool _cachedReadOnly;
  MonacoEditorOptions? _cachedOptions;
  MonacoPosition? _cachedPosition;
  MonacoSelection? _cachedSelection;

  // --- event controllers (lazily initialized broadcast) ---
  final StreamController<String> _contentCtrl =
      StreamController<String>.broadcast();
  final StreamController<MonacoPosition> _cursorCtrl =
      StreamController<MonacoPosition>.broadcast();
  final StreamController<MonacoSelection> _selectionCtrl =
      StreamController<MonacoSelection>.broadcast();
  final StreamController<MonacoScrollEvent> _scrollCtrl =
      StreamController<MonacoScrollEvent>.broadcast();
  final StreamController<void> _focusCtrl =
      StreamController<void>.broadcast();
  final StreamController<void> _blurCtrl =
      StreamController<void>.broadcast();
  final StreamController<MonacoKeyEvent> _keyDownCtrl =
      StreamController<MonacoKeyEvent>.broadcast();
  final StreamController<MonacoKeyEvent> _keyUpCtrl =
      StreamController<MonacoKeyEvent>.broadcast();

  // ==========================================================================
  // Lifecycle
  // ==========================================================================

  /// Completes when the controller is attached to an editor and the bridge
  /// handshake is done. Further waits (across detach/re-attach cycles) return
  /// the already-completed future — attachment is considered a one-shot
  /// signal for Phase 1.3.
  Future<void> get ready => _readyCompleter.future;

  /// Whether the controller is currently driving a live editor.
  bool get isAttached => _bridge != null && _editorId != null;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// Releases all resources. After calling, the controller is unusable.
  /// Event streams close.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventsSub?.cancel();
    _eventsSub = null;
    if (_bridge != null) {
      try {
        await _bridge!.invoke('feeef.clearCustomPropsTypes');
      } catch (_) {}
    }
    if (_bridge != null && _editorId != null) {
      unawaited(_bridge!.invoke('editor.dispose', {'editorId': _editorId!}));
    }
    _bridge = null;
    _editorId = null;
    await Future.wait([
      _contentCtrl.close(),
      _cursorCtrl.close(),
      _selectionCtrl.close(),
      _scrollCtrl.close(),
      _focusCtrl.close(),
      _blurCtrl.close(),
      _keyDownCtrl.close(),
      _keyUpCtrl.close(),
    ]);
  }

  // ==========================================================================
  // State accessors
  // ==========================================================================

  /// Last-known editor content. Always reflects the most recent value — either
  /// the initial seed, the last [setValue] call, or the latest content change
  /// from the editor itself.
  String get value => _cachedValue;

  String get language => _cachedLanguage;

  String get theme => _cachedTheme;

  bool get readOnly => _cachedReadOnly;

  /// Last-set structured options. `null` if no options have been set since
  /// construction (the editor uses Monaco defaults).
  MonacoEditorOptions? get options => _cachedOptions;

  /// Last-observed cursor position. `null` before the first cursor event
  /// (typically, before the editor is attached).
  MonacoPosition? get position => _cachedPosition;

  /// Last-observed primary selection. `null` before the first selection event.
  MonacoSelection? get selection => _cachedSelection;

  // ==========================================================================
  // State setters
  // ==========================================================================

  /// Replaces the editor content with [value].
  ///
  /// Safe to call before attachment — the value becomes the editor's initial
  /// content when it's created.
  Future<void> setValue(String value) async {
    _assertNotDisposed();
    _cachedValue = value;
    if (!isAttached) return;
    await _bridge!.invoke('editor.setValue', {
      'editorId': _editorId!,
      'value': value,
    });
  }

  /// Switches the editor's language mode (e.g. `'dart'`, `'javascript'`,
  /// `'plaintext'`).
  Future<void> setLanguage(String language) async {
    _assertNotDisposed();
    _cachedLanguage = language;
    if (!isAttached) return;
    await _bridge!.invoke('editor.setLanguage', {
      'editorId': _editorId!,
      'language': language,
    });
  }

  /// Registers or replaces the virtual `file:///feeef/dynamic-props.d.ts` with
  /// TypeScript for `const props: …` (Feeef template propsSchema in the
  /// merchant app). The bridge disposes a previous registration when this is
  /// called again; [dispose] clears it as well.
  Future<void> setCustomPropsTypeScript(String content) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('feeef.setCustomPropsTypes', {
      'content': content,
    });
  }

  /// Sets the global Monaco theme for this controller's editor. Note: Monaco
  /// themes are process-global — changing one editor's theme changes all
  /// editors in the same page.
  Future<void> setTheme(String theme) async {
    _assertNotDisposed();
    _cachedTheme = theme;
    if (!isAttached) return;
    await _bridge!.invoke('editor.setTheme', {
      'editorId': _editorId!,
      'theme': theme,
    });
  }

  /// Toggles read-only mode.
  Future<void> setReadOnly(bool readOnly) async {
    _assertNotDisposed();
    _cachedReadOnly = readOnly;
    if (!isAttached) return;
    await _bridge!.invoke('editor.updateOptions', {
      'editorId': _editorId!,
      'options': {'readOnly': readOnly},
    });
  }

  /// Apply a partial or full [MonacoEditorOptions] update. Non-null fields in
  /// [partial] overwrite the cached options; null fields are preserved.
  Future<void> updateOptions(MonacoEditorOptions partial) async {
    _assertNotDisposed();
    _cachedOptions = _cachedOptions == null
        ? partial
        : _cachedOptions!.mergedWith(partial);
    if (!isAttached) return;
    await _bridge!.invoke('editor.updateOptions', {
      'editorId': _editorId!,
      'options': partial.toJson(),
    });
  }

  // ==========================================================================
  // Position / selection / navigation
  // ==========================================================================

  Future<void> setPosition(MonacoPosition position) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('editor.setPosition', {
      'editorId': _editorId!,
      ...position.toJson(),
    });
  }

  Future<void> setSelection(MonacoSelection selection) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('editor.setSelection', {
      'editorId': _editorId!,
      ...selection.toJson(),
    });
  }

  Future<void> focus() async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('editor.focus', {'editorId': _editorId!});
  }

  Future<void> revealLine(int line) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('editor.revealLine', {
      'editorId': _editorId!,
      'line': line,
    });
  }

  Future<void> revealLineInCenter(int line) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('editor.revealLineInCenter', {
      'editorId': _editorId!,
      'line': line,
    });
  }

  Future<void> revealRange(MonacoRange range) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('editor.revealRange', {
      'editorId': _editorId!,
      ...range.toJson(),
    });
  }

  // ==========================================================================
  // Decorations
  // ==========================================================================

  /// Replace the decorations identified by [oldIds] with [newDecorations],
  /// returning the ids of the newly created decorations.
  ///
  /// Pass an empty list for [oldIds] to add decorations without removing
  /// anything; pass an empty list for [newDecorations] to remove without
  /// adding.
  Future<List<String>> deltaDecorations(
    List<String> oldIds,
    List<MonacoDecoration> newDecorations,
  ) async {
    _assertNotDisposed();
    await ready;
    final result = await _bridge!.invoke('editor.deltaDecorations', {
      'editorId': _editorId!,
      'oldIds': oldIds,
      'newDecorations': newDecorations.map((d) => d.toJson()).toList(),
    });
    final list = (result as List?) ?? const [];
    return list.map((e) => e as String).toList(growable: false);
  }

  // ==========================================================================
  // Markers (diagnostics)
  // ==========================================================================

  /// Publish diagnostics for the current model. Markers with the same
  /// [owner] are replaced atomically. Use distinct owners for different
  /// providers (e.g. `'dart-analyzer'`, `'linter'`).
  Future<void> setModelMarkers(
    List<MonacoMarker> markers, {
    String owner = 'default',
  }) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('markers.set', {
      'editorId': _editorId!,
      'owner': owner,
      'markers': markers.map((m) => m.toJson()).toList(),
    });
  }

  /// Remove all markers belonging to [owner] on the current model.
  Future<void> clearModelMarkers({String owner = 'default'}) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('markers.clear', {
      'editorId': _editorId!,
      'owner': owner,
    });
  }

  // ==========================================================================
  // Actions & commands
  // ==========================================================================

  /// Register [action] with the editor. The action is listed in the command
  /// palette and (if [MonacoAction.contextMenuGroupId] is set) the context
  /// menu. [MonacoAction.run] fires when the action is invoked.
  ///
  /// Actions are cleaned up automatically when the controller is disposed.
  Future<void> addAction(MonacoAction action) async {
    _assertNotDisposed();
    _actionHandlers[action.id] = action.run;
    await ready;
    await _bridge!.invoke('editor.addAction', {
      'editorId': _editorId!,
      ...action.toRegistrationJson(),
    });
  }

  /// Bind a keybinding to a custom [handler] with no associated action.
  /// Useful for one-off shortcuts that don't need a command-palette entry.
  ///
  /// Returns an id you can pass to [removeCommand] to unbind.
  Future<String> addCommand(
    int keybinding,
    void Function() handler, {
    String? context,
  }) async {
    _assertNotDisposed();
    final commandId = 'cmd-${_nextCommandId++}';
    _commandHandlers[commandId] = handler;
    await ready;
    await _bridge!.invoke('editor.addCommand', {
      'editorId': _editorId!,
      'commandId': commandId,
      'keybinding': keybinding,
      if (context != null) 'context': context,
    });
    return commandId;
  }

  /// Unbind a command previously registered with [addCommand].
  Future<void> removeCommand(String commandId) async {
    _assertNotDisposed();
    _commandHandlers.remove(commandId);
    await ready;
    await _bridge!.invoke('editor.removeCommand', {
      'editorId': _editorId!,
      'commandId': commandId,
    });
  }

  /// Trigger a built-in Monaco action (`'editor.action.formatDocument'`,
  /// `'editor.action.commentLine'`, etc.) or a registered action by id.
  Future<void> trigger(
    String actionId, {
    String source = 'flutter_monaco_editor',
    Object? payload,
  }) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('editor.trigger', {
      'editorId': _editorId!,
      'source': source,
      'handlerId': actionId,
      if (payload != null) 'payload': payload,
    });
  }

  // ==========================================================================
  // Multi-model
  // ==========================================================================

  /// Create a new Monaco text model. If [uri] is omitted, Monaco assigns a
  /// fresh `inmemory://model/N` URI. Returns the URI so callers can
  /// reference the model later.
  ///
  /// Models are independent of editors — multiple editors can share one
  /// model (collaborative-style linked views) and one editor can switch
  /// between models (IDE tab-switching).
  Future<String> createModel({
    required String value,
    String language = 'plaintext',
    String? uri,
  }) async {
    _assertNotDisposed();
    await ready;
    final result = await _bridge!.invoke('models.create', {
      'value': value,
      'language': language,
      if (uri != null) 'uri': uri,
    });
    return (result as Map?)?['uri'] as String? ?? (result as String);
  }

  /// Switch the current editor to display the model identified by [uri].
  /// The model must have been created previously via [createModel].
  Future<void> switchToModel(String uri) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('editor.setModel', {
      'editorId': _editorId!,
      'uri': uri,
    });
  }

  /// Destroy a model previously created via [createModel]. If the model is
  /// currently displayed by this editor, call [switchToModel] first.
  Future<void> disposeMonacoModel(String uri) async {
    _assertNotDisposed();
    await ready;
    await _bridge!.invoke('models.dispose', {'uri': uri});
  }

  // ==========================================================================
  // Event streams (broadcast)
  // ==========================================================================

  Stream<String> get onDidChangeContent => _contentCtrl.stream;
  Stream<MonacoPosition> get onDidChangeCursorPosition => _cursorCtrl.stream;
  Stream<MonacoSelection> get onDidChangeCursorSelection => _selectionCtrl.stream;
  Stream<MonacoScrollEvent> get onDidScroll => _scrollCtrl.stream;
  Stream<void> get onDidFocus => _focusCtrl.stream;
  Stream<void> get onDidBlur => _blurCtrl.stream;
  Stream<MonacoKeyEvent> get onKeyDown => _keyDownCtrl.stream;
  Stream<MonacoKeyEvent> get onKeyUp => _keyUpCtrl.stream;

  // ==========================================================================
  // Internal — called by the platform view.
  // ==========================================================================

  /// Builds the option map used to create the Monaco editor. Called by the
  /// platform view at creation time.
  ///
  /// Merge order (later entries win):
  ///   1. [options] (from the typed [MonacoEditorOptions])
  ///   2. explicit controller state (value / language / theme / readOnly)
  ///   3. `automaticLayout: true` (always)
  Map<String, Object?> buildCreateOptions() => {
        ...?_cachedOptions?.toJson(),
        'value': _cachedValue,
        'language': _cachedLanguage,
        'theme': _cachedTheme,
        'readOnly': _cachedReadOnly,
        'automaticLayout': true,
      };

  /// Called by the platform view after `editor.create` returns successfully.
  void attach(MonacoBridge bridge, String editorId) {
    if (_disposed) {
      throw StateError('MonacoController.attach called on disposed controller');
    }
    if (isAttached) {
      throw StateError(
        'MonacoController already attached (editorId=$_editorId). '
        'Detach first before re-attaching.',
      );
    }
    _bridge = bridge;
    _editorId = editorId;
    _eventsSub = bridge.events.listen(_onBridgeEvent);
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  /// Called by the platform view during widget dispose. Does not tear down
  /// the underlying editor — that's the view's responsibility.
  void detach() {
    _eventsSub?.cancel();
    _eventsSub = null;
    _bridge = null;
    _editorId = null;
  }

  void _onBridgeEvent(BridgeEvent event) {
    if (event.editorId != _editorId) return;
    switch (event.type) {
      case 'editor.contentChange':
        final v = event.payload['value'];
        if (v is String) {
          _cachedValue = v;
          _contentCtrl.add(v);
        }
      case 'editor.cursorChange':
        final payload = event.payload;
        final pos = MonacoPosition(
          line: (payload['line']! as num).toInt(),
          column: (payload['column']! as num).toInt(),
        );
        _cachedPosition = pos;
        _cursorCtrl.add(pos);
      case 'editor.selectionChange':
        final sel = MonacoSelection.fromJson(
          event.payload.map((k, v) => MapEntry(k.toString(), v)),
        );
        _cachedSelection = sel;
        _selectionCtrl.add(sel);
      case 'editor.scrollChange':
        _scrollCtrl.add(MonacoScrollEvent.fromJson(
          event.payload.map((k, v) => MapEntry(k.toString(), v)),
        ));
      case 'editor.focus':
        _focusCtrl.add(null);
      case 'editor.blur':
        _blurCtrl.add(null);
      case 'editor.keyDown':
        _keyDownCtrl.add(MonacoKeyEvent.fromJson(
          event.payload.map((k, v) => MapEntry(k.toString(), v)),
        ));
      case 'editor.keyUp':
        _keyUpCtrl.add(MonacoKeyEvent.fromJson(
          event.payload.map((k, v) => MapEntry(k.toString(), v)),
        ));
      case 'editor.actionInvoked':
        final actionId = event.payload['actionId'] as String?;
        if (actionId != null) _actionHandlers[actionId]?.call(actionId);
      case 'editor.commandInvoked':
        final commandId = event.payload['commandId'] as String?;
        if (commandId != null) _commandHandlers[commandId]?.call();
    }
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('MonacoController is disposed');
    }
  }
}
