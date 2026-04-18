// flutter_monaco_editor — shared JS bridge.
//
// This file is loaded by both transports:
//   - Web:    injected into the main document by WebMonacoBridge.
//   - Native: loaded inside monaco_host.html by the webview.
//
// Transport differences are isolated to:
//   (a) how `window.monacoBridge.emit` is wired back to Dart
//       (web: direct js_interop callback; native: JavaScriptChannel.postMessage)
//   (b) how invokes are dispatched
//       (web: direct `invoke()`; native: `invokeAsync()` with callId + return event)
//
// Everything else — handlers, editor lifecycle, event wiring — is shared.

(function () {
  if (typeof window !== 'undefined' && window.monacoBridge) return;

  var bridge = {
    _ready: false,
    _readyResolvers: [],
    _emit: null,
    _editors: Object.create(null),
    _nextEditorId: 1,
    _diffs: Object.create(null),             // diffId → {editor, disposers}
    _nextDiffId: 1,
    _models: Object.create(null),            // uri → Monaco ITextModel
    _providers: Object.create(null),         // providerId → Monaco IDisposable
    _pendingRequests: Object.create(null),   // requestId → {resolve, reject}
    _nextRequestId: 1,
    _providerTimeoutMs: 8000,

    setEmitter: function (fn) { this._emit = fn; },

    emit: function (type, payload) {
      if (!this._emit) return;
      try { this._emit(type, payload || {}); }
      catch (e) { console.error('[monacoBridge] emit failed:', e); }
    },

    onReady: function (cb) {
      if (this._ready) { cb(); } else { this._readyResolvers.push(cb); }
    },

    _signalReady: function () {
      this._ready = true;
      var resolvers = this._readyResolvers;
      this._readyResolvers = [];
      for (var i = 0; i < resolvers.length; i++) {
        try { resolvers[i](); } catch (e) { console.error(e); }
      }
      this.emit('bridge.ready', {});
    },

    // Synchronous invoke. Web transport uses this directly via js_interop.
    // Handler return value may be a Promise; caller is responsible for awaiting.
    invoke: function (method, args) {
      var handler = handlers[method];
      if (!handler) throw new Error('monacoBridge: unknown method "' + method + '"');
      return handler(args || {});
    },

    // Async invoke. Native transport uses this + `_return` event for the reply.
    // Dart side: { callId, value } on success, { callId, error } on failure.
    invokeAsync: function (callId, method, args) {
      var self = this;
      try {
        Promise.resolve(this.invoke(method, args || {}))
          .then(function (value) { self.emit('_return', { callId: callId, value: value }); })
          .catch(function (err) { self.emit('_return', { callId: callId, error: String(err && err.message || err) }); });
      } catch (err) {
        self.emit('_return', { callId: callId, error: String(err && err.message || err) });
      }
    },
  };

  var handlers = Object.create(null);

  // ---------------------------------------------------------------------
  // dart2js interop fix.
  //
  // The Dart compiler (dart2js) adds enumerable tear-off shims like $0, $1,
  // $1$1 to Function.prototype. Monaco 0.55's bundle has a module-copy
  // helper that iterates `for (const n in S)` over the AMD `require`
  // function and expects `Object.getOwnPropertyDescriptor(S, n)` to be
  // defined for every iterated key. For *inherited* enumerable properties
  // from Function.prototype, GOPD returns undefined and Monaco crashes on
  // `r.get`.
  //
  // Two-part fix:
  //   1. Hide any currently-present $N on Function.prototype (cheap).
  //   2. Patch Object.getOwnPropertyDescriptor to synthesize a descriptor
  //      for inherited enumerable properties so the Monaco module-copy
  //      still works if dart2js adds more $N later. The synthesized
  //      descriptor is value/enumerable/configurable/writable; Monaco's
  //      helper takes the non-accessor branch and copies the value — which
  //      is fine, since these are plain methods.
  // ---------------------------------------------------------------------
  function _sanitizeFunctionPrototype() {
    try {
      var fp = Function.prototype;
      var names = Object.getOwnPropertyNames(fp);
      for (var i = 0; i < names.length; i++) {
        var k = names[i];
        if (/^\$/.test(k)) {
          var d = Object.getOwnPropertyDescriptor(fp, k);
          if (d && d.enumerable) {
            Object.defineProperty(fp, k, {
              value: d.value,
              writable: d.writable !== false,
              enumerable: false,
              configurable: d.configurable !== false,
            });
          }
        }
      }
    } catch (e) {
      console.warn('[monacoBridge] Function.prototype sanitize failed:', e);
    }

    // Install the GOPD safety net. Idempotent; keyed via a marker so a
    // reloaded bridge script doesn't double-wrap.
    try {
      if (!Object.getOwnPropertyDescriptor.__fmePatched) {
        var orig = Object.getOwnPropertyDescriptor;
        var patched = function (obj, key) {
          var d = orig(obj, key);
          if (d !== undefined) return d;
          // For inherited enumerable keys (seen via for-in), synthesize
          // a data descriptor so module-copy helpers don't crash.
          try {
            if (obj != null && key in obj) {
              return {
                value: obj[key],
                writable: true,
                enumerable: true,
                configurable: true,
              };
            }
          } catch (e) { /* fall through */ }
          return undefined;
        };
        patched.__fmePatched = true;
        Object.getOwnPropertyDescriptor = patched;
      }
    } catch (e) {
      console.warn('[monacoBridge] GOPD patch failed:', e);
    }
  }

  handlers['bridge.init'] = function (args) {
    return new Promise(function (resolve, reject) {
      if (bridge._ready) { resolve(); return; }
      if (!args || !args.vsPath) { reject(new Error('bridge.init: vsPath required')); return; }

      _sanitizeFunctionPrototype();

      var script = document.createElement('script');
      script.src = args.vsPath + '/loader.js';
      script.async = true;
      script.onload = function () {
        try {
          // eslint-disable-next-line no-undef
          require.config({ paths: { vs: args.vsPath } });
          // eslint-disable-next-line no-undef
          require(['vs/editor/editor.main'], function () {
            bridge._signalReady();
            resolve();
          }, function (err) {
            reject(new Error('monaco: editor.main load failed — ' + (err && err.message || err)));
          });
        } catch (e) { reject(e); }
      };
      script.onerror = function () {
        reject(new Error('monaco: loader.js failed to load from ' + script.src));
      };
      document.head.appendChild(script);
    });
  };

  handlers['editor.create'] = function (args) {
    var container = document.getElementById(args.containerId);
    // Flutter's HtmlElementView insertion is frame-scheduled. Even with
    // endOfFrame awaits on the Dart side, we occasionally see a one-frame
    // lag on web. Poll briefly before failing.
    if (!container) {
      return new Promise(function (resolve, reject) {
        var tries = 0;
        var maxTries = 20; // 20 * 25ms = 500ms budget
        var t = setInterval(function () {
          tries++;
          var c = document.getElementById(args.containerId);
          if (c) {
            clearInterval(t);
            try { resolve(_createEditorOn(c, args)); }
            catch (e) { reject(e); }
          } else if (tries >= maxTries) {
            clearInterval(t);
            reject(new Error('editor.create: container "' + args.containerId + '" not in DOM after ' + (maxTries * 25) + 'ms'));
          }
        }, 25);
      });
    }
    return _createEditorOn(container, args);
  };

  function _createEditorOn(container, args) {
    var editorId = String(bridge._nextEditorId++);
    // eslint-disable-next-line no-undef
    var editor = monaco.editor.create(container, args.options || {});

    var disposers = [
      editor.onDidChangeModelContent(function () {
        bridge.emit('editor.contentChange', { editorId: editorId, value: editor.getValue() });
      }),
      editor.onDidChangeCursorPosition(function (e) {
        bridge.emit('editor.cursorChange', {
          editorId: editorId,
          line: e.position.lineNumber,
          column: e.position.column,
        });
      }),
      editor.onDidChangeCursorSelection(function (e) {
        bridge.emit('editor.selectionChange', Object.assign(
          { editorId: editorId },
          _serializeSelection(e.selection)
        ));
      }),
      editor.onDidScrollChange(function (e) {
        bridge.emit('editor.scrollChange', {
          editorId: editorId,
          scrollTop: e.scrollTop,
          scrollLeft: e.scrollLeft,
          scrollHeight: e.scrollHeight,
          scrollWidth: e.scrollWidth,
          scrollTopChanged: !!e.scrollTopChanged,
          scrollLeftChanged: !!e.scrollLeftChanged,
          scrollHeightChanged: !!e.scrollHeightChanged,
          scrollWidthChanged: !!e.scrollWidthChanged,
        });
      }),
      editor.onDidFocusEditorText(function () { bridge.emit('editor.focus', { editorId: editorId }); }),
      editor.onDidBlurEditorText(function () { bridge.emit('editor.blur', { editorId: editorId }); }),
      editor.onKeyDown(function (e) { bridge.emit('editor.keyDown', _serializeKey(editorId, e)); }),
      editor.onKeyUp(function (e) { bridge.emit('editor.keyUp', _serializeKey(editorId, e)); }),
    ];

    bridge._editors[editorId] = { editor: editor, disposers: disposers };
    return editorId;
  }

  handlers['editor.getValue'] = function (args) {
    return _entry(args.editorId).editor.getValue();
  };

  handlers['editor.setValue'] = function (args) {
    _entry(args.editorId).editor.setValue(args.value == null ? '' : String(args.value));
    return null;
  };

  handlers['editor.setLanguage'] = function (args) {
    var entry = _entry(args.editorId);
    var model = entry.editor.getModel();
    if (model) {
      // eslint-disable-next-line no-undef
      monaco.editor.setModelLanguage(model, args.language);
    }
    return null;
  };

  handlers['editor.setTheme'] = function (args) {
    // eslint-disable-next-line no-undef
    monaco.editor.setTheme(args.theme);
    return null;
  };

  handlers['editor.focus'] = function (args) {
    _entry(args.editorId).editor.focus();
    return null;
  };

  handlers['editor.getPosition'] = function (args) {
    var pos = _entry(args.editorId).editor.getPosition();
    return pos ? { line: pos.lineNumber, column: pos.column } : null;
  };

  handlers['editor.setPosition'] = function (args) {
    _entry(args.editorId).editor.setPosition({
      lineNumber: args.line,
      column: args.column,
    });
    return null;
  };

  handlers['editor.getSelection'] = function (args) {
    var sel = _entry(args.editorId).editor.getSelection();
    return sel ? _serializeSelection(sel) : null;
  };

  handlers['editor.setSelection'] = function (args) {
    _entry(args.editorId).editor.setSelection({
      selectionStartLineNumber: args.selectionStartLine,
      selectionStartColumn: args.selectionStartColumn,
      positionLineNumber: args.positionLine,
      positionColumn: args.positionColumn,
    });
    return null;
  };

  handlers['editor.revealLine'] = function (args) {
    _entry(args.editorId).editor.revealLine(args.line);
    return null;
  };

  handlers['editor.revealLineInCenter'] = function (args) {
    _entry(args.editorId).editor.revealLineInCenter(args.line);
    return null;
  };

  handlers['editor.revealRange'] = function (args) {
    _entry(args.editorId).editor.revealRange({
      startLineNumber: args.startLine,
      startColumn: args.startColumn,
      endLineNumber: args.endLine,
      endColumn: args.endColumn,
    });
    return null;
  };

  handlers['editor.updateOptions'] = function (args) {
    _entry(args.editorId).editor.updateOptions(args.options || {});
    return null;
  };

  handlers['editor.dispose'] = function (args) {
    var entry = bridge._editors[args.editorId];
    if (!entry) return null;
    for (var i = 0; i < entry.disposers.length; i++) {
      try { entry.disposers[i].dispose(); } catch (e) { console.error(e); }
    }
    try { entry.editor.dispose(); } catch (e) { console.error(e); }
    delete bridge._editors[args.editorId];
    return null;
  };

  handlers['editor.deltaDecorations'] = function (args) {
    var entry = _entry(args.editorId);
    var newDecos = (args.newDecorations || []).map(function (d) {
      return {
        range: _toMonacoRange(d.range),
        options: d.options || {},
      };
    });
    return entry.editor.deltaDecorations(args.oldIds || [], newDecos);
  };

  handlers['markers.set'] = function (args) {
    var entry = _entry(args.editorId);
    var model = entry.editor.getModel();
    if (!model) return null;
    var markers = (args.markers || []).map(_toMonacoMarker);
    // eslint-disable-next-line no-undef
    monaco.editor.setModelMarkers(model, args.owner || 'default', markers);
    return null;
  };

  handlers['markers.clear'] = function (args) {
    var entry = _entry(args.editorId);
    var model = entry.editor.getModel();
    if (!model) return null;
    // eslint-disable-next-line no-undef
    monaco.editor.setModelMarkers(model, args.owner || 'default', []);
    return null;
  };

  handlers['editor.addAction'] = function (args) {
    var entry = _entry(args.editorId);
    var editorId = args.editorId;
    var actionId = args.id;
    var descriptor = {
      id: actionId,
      label: args.label,
      keybindings: args.keybindings || [],
      run: function () {
        bridge.emit('editor.actionInvoked', {
          editorId: editorId,
          actionId: actionId,
        });
      },
    };
    if (args.contextMenuGroupId) descriptor.contextMenuGroupId = args.contextMenuGroupId;
    if (typeof args.contextMenuOrder === 'number') descriptor.contextMenuOrder = args.contextMenuOrder;
    if (args.precondition) descriptor.precondition = args.precondition;
    if (args.keybindingContext) descriptor.keybindingContext = args.keybindingContext;

    var disposable = entry.editor.addAction(descriptor);
    entry.actions = entry.actions || Object.create(null);
    entry.actions[actionId] = disposable;
    entry.disposers.push(disposable);
    return null;
  };

  handlers['editor.addCommand'] = function (args) {
    var entry = _entry(args.editorId);
    var editorId = args.editorId;
    var commandId = args.commandId;
    // Monaco's editor.addCommand returns a raw command id string; we discard
    // it and key on our own commandId for cross-platform consistency.
    var disposable = entry.editor.addCommand(
      args.keybinding,
      function () {
        bridge.emit('editor.commandInvoked', {
          editorId: editorId,
          commandId: commandId,
        });
      },
      args.context
    );
    entry.commands = entry.commands || Object.create(null);
    // addCommand in some Monaco versions returns a string id (not disposable).
    // Normalize: store either for later removal.
    entry.commands[commandId] = disposable;
    return null;
  };

  handlers['editor.removeCommand'] = function (args) {
    var entry = _entry(args.editorId);
    if (!entry.commands) return null;
    var token = entry.commands[args.commandId];
    if (token && typeof token.dispose === 'function') {
      try { token.dispose(); } catch (e) { console.error(e); }
    }
    delete entry.commands[args.commandId];
    return null;
  };

  // ---------------------------------------------------------------------
  // Language providers — IntelliSense wiring
  // ---------------------------------------------------------------------

  function _askDart(eventType, providerId, model, position, extra) {
    var requestId = 'req-' + (bridge._nextRequestId++);
    return new Promise(function (resolve, reject) {
      bridge._pendingRequests[requestId] = { resolve: resolve, reject: reject };
      var payload = {
        providerId: providerId,
        requestId: requestId,
        uri: model.uri.toString(),
        languageId: model.getLanguageId(),
        value: model.getValue(),
        line: position.lineNumber,
        column: position.column,
      };
      if (extra) for (var k in extra) payload[k] = extra[k];
      bridge.emit(eventType, payload);

      setTimeout(function () {
        var pending = bridge._pendingRequests[requestId];
        if (pending) {
          delete bridge._pendingRequests[requestId];
          reject(new Error(eventType + ' timed out after ' + bridge._providerTimeoutMs + 'ms'));
        }
      }, bridge._providerTimeoutMs);
    });
  }

  handlers['languages.respond'] = function (args) {
    var pending = bridge._pendingRequests[args.requestId];
    if (!pending) return null;
    delete bridge._pendingRequests[args.requestId];
    if (args.error) {
      pending.reject(new Error(args.error));
    } else {
      pending.resolve(args.result);
    }
    return null;
  };

  handlers['languages.unregisterProvider'] = function (args) {
    var d = bridge._providers[args.providerId];
    if (d && typeof d.dispose === 'function') {
      try { d.dispose(); } catch (e) { console.error(e); }
    }
    delete bridge._providers[args.providerId];
    return null;
  };

  handlers['languages.registerCompletionProvider'] = function (args) {
    // eslint-disable-next-line no-undef
    var d = monaco.languages.registerCompletionItemProvider(args.languageId, {
      triggerCharacters: args.triggerCharacters || [],
      provideCompletionItems: function (model, position, context) {
        return _askDart(
          'language.completion.request', args.providerId, model, position,
          {
            context: {
              triggerKind: context.triggerKind,
              triggerCharacter: context.triggerCharacter || null,
            },
          }
        ).then(function (result) {
          if (!result) return { suggestions: [] };
          return {
            suggestions: (result.suggestions || []).map(_toMonacoCompletionItem),
            incomplete: !!result.incomplete,
          };
        });
      },
    });
    bridge._providers[args.providerId] = d;
    return null;
  };

  handlers['languages.registerHoverProvider'] = function (args) {
    // eslint-disable-next-line no-undef
    var d = monaco.languages.registerHoverProvider(args.languageId, {
      provideHover: function (model, position) {
        return _askDart(
          'language.hover.request', args.providerId, model, position
        ).then(function (result) {
          if (!result) return null;
          return {
            contents: result.contents || [],
            range: result.range ? _toMonacoRange(result.range) : undefined,
          };
        });
      },
    });
    bridge._providers[args.providerId] = d;
    return null;
  };

  handlers['languages.registerSignatureHelpProvider'] = function (args) {
    // eslint-disable-next-line no-undef
    var d = monaco.languages.registerSignatureHelpProvider(args.languageId, {
      signatureHelpTriggerCharacters: args.triggerCharacters || [],
      signatureHelpRetriggerCharacters: args.retriggerCharacters || [],
      provideSignatureHelp: function (model, position, token, context) {
        return _askDart(
          'language.signatureHelp.request', args.providerId, model, position,
          {
            context: {
              triggerKind: context.triggerKind,
              triggerCharacter: context.triggerCharacter || null,
              isRetrigger: !!context.isRetrigger,
            },
          }
        ).then(function (result) {
          if (!result) return null;
          return {
            value: {
              signatures: result.signatures || [],
              activeSignature: result.activeSignature || 0,
              activeParameter: result.activeParameter || 0,
            },
            dispose: function () {},
          };
        });
      },
    });
    bridge._providers[args.providerId] = d;
    return null;
  };

  handlers['languages.registerDefinitionProvider'] = function (args) {
    // eslint-disable-next-line no-undef
    var d = monaco.languages.registerDefinitionProvider(args.languageId, {
      provideDefinition: function (model, position) {
        return _askDart(
          'language.definition.request', args.providerId, model, position
        ).then(function (result) {
          if (!result) return null;
          return (Array.isArray(result) ? result : [result]).map(function (loc) {
            return {
              // eslint-disable-next-line no-undef
              uri: monaco.Uri.parse(loc.uri),
              range: _toMonacoRange(loc.range),
            };
          });
        });
      },
    });
    bridge._providers[args.providerId] = d;
    return null;
  };

  // ---------------------------------------------------------------------
  // Themes
  // ---------------------------------------------------------------------

  handlers['editor.defineTheme'] = function (args) {
    // eslint-disable-next-line no-undef
    monaco.editor.defineTheme(args.name, args.theme || {});
    return null;
  };

  // ---------------------------------------------------------------------
  // Multi-model
  // ---------------------------------------------------------------------

  handlers['models.create'] = function (args) {
    // eslint-disable-next-line no-undef
    var uri = args.uri ? monaco.Uri.parse(args.uri) : undefined;
    // eslint-disable-next-line no-undef
    var model = monaco.editor.createModel(args.value || '', args.language || 'plaintext', uri);
    var uriStr = model.uri.toString();
    bridge._models[uriStr] = model;
    return { uri: uriStr };
  };

  handlers['models.dispose'] = function (args) {
    var model = bridge._models[args.uri];
    if (model) {
      try { model.dispose(); } catch (e) { console.error(e); }
      delete bridge._models[args.uri];
    }
    return null;
  };

  handlers['editor.setModel'] = function (args) {
    var entry = _entry(args.editorId);
    var model = bridge._models[args.uri];
    if (!model) throw new Error('editor.setModel: unknown uri ' + args.uri);
    entry.editor.setModel(model);
    return null;
  };

  // ---------------------------------------------------------------------
  // Diff editor
  // ---------------------------------------------------------------------

  handlers['diff.create'] = function (args) {
    var container = document.getElementById(args.containerId);
    if (!container) {
      // Same platform-view-mount race as editor.create — poll briefly.
      return new Promise(function (resolve, reject) {
        var tries = 0;
        var maxTries = 20;
        var t = setInterval(function () {
          tries++;
          var c = document.getElementById(args.containerId);
          if (c) {
            clearInterval(t);
            try { resolve(_createDiffOn(c, args)); }
            catch (e) { reject(e); }
          } else if (tries >= maxTries) {
            clearInterval(t);
            reject(new Error('diff.create: container "' + args.containerId + '" not in DOM after ' + (maxTries * 25) + 'ms'));
          }
        }, 25);
      });
    }
    return _createDiffOn(container, args);
  };

  function _createDiffOn(container, args) {
    var diffId = 'diff-' + (bridge._nextDiffId++);
    var opts = args.options || {};
    // eslint-disable-next-line no-undef
    var diff = monaco.editor.createDiffEditor(container, opts);
    // eslint-disable-next-line no-undef
    var originalModel = monaco.editor.createModel(opts.original || '', opts.language || 'plaintext');
    // eslint-disable-next-line no-undef
    var modifiedModel = monaco.editor.createModel(opts.modified || '', opts.language || 'plaintext');
    diff.setModel({ original: originalModel, modified: modifiedModel });

    var disposers = [
      originalModel.onDidChangeContent(function () {
        bridge.emit('diff.originalChange', { diffId: diffId, value: originalModel.getValue() });
      }),
      modifiedModel.onDidChangeContent(function () {
        bridge.emit('diff.modifiedChange', { diffId: diffId, value: modifiedModel.getValue() });
      }),
    ];

    bridge._diffs[diffId] = { diff: diff, originalModel: originalModel, modifiedModel: modifiedModel, disposers: disposers };
    return diffId;
  }

  handlers['diff.setOriginal'] = function (args) {
    _diffEntry(args.diffId).originalModel.setValue(args.value == null ? '' : String(args.value));
    return null;
  };

  handlers['diff.setModified'] = function (args) {
    _diffEntry(args.diffId).modifiedModel.setValue(args.value == null ? '' : String(args.value));
    return null;
  };

  handlers['diff.setLanguage'] = function (args) {
    var entry = _diffEntry(args.diffId);
    // eslint-disable-next-line no-undef
    monaco.editor.setModelLanguage(entry.originalModel, args.language);
    // eslint-disable-next-line no-undef
    monaco.editor.setModelLanguage(entry.modifiedModel, args.language);
    return null;
  };

  handlers['diff.dispose'] = function (args) {
    var entry = bridge._diffs[args.diffId];
    if (!entry) return null;
    for (var i = 0; i < entry.disposers.length; i++) {
      try { entry.disposers[i].dispose(); } catch (e) { console.error(e); }
    }
    try { entry.diff.dispose(); } catch (e) { console.error(e); }
    try { entry.originalModel.dispose(); } catch (e) { console.error(e); }
    try { entry.modifiedModel.dispose(); } catch (e) { console.error(e); }
    delete bridge._diffs[args.diffId];
    return null;
  };

  handlers['editor.trigger'] = function (args) {
    _entry(args.editorId).editor.trigger(
      args.source || 'flutter_monaco_editor',
      args.handlerId,
      args.payload
    );
    return null;
  };

  function _entry(editorId) {
    var entry = bridge._editors[editorId];
    if (!entry) throw new Error('unknown editorId: ' + editorId);
    return entry;
  }

  function _diffEntry(diffId) {
    var entry = bridge._diffs[diffId];
    if (!entry) throw new Error('unknown diffId: ' + diffId);
    return entry;
  }

  function _serializeSelection(sel) {
    return {
      startLine: sel.startLineNumber,
      startColumn: sel.startColumn,
      endLine: sel.endLineNumber,
      endColumn: sel.endColumn,
      selectionStartLine: sel.selectionStartLineNumber,
      selectionStartColumn: sel.selectionStartColumn,
      positionLine: sel.positionLineNumber,
      positionColumn: sel.positionColumn,
    };
  }

  function _toMonacoRange(r) {
    if (!r) return r;
    return {
      startLineNumber: r.startLine,
      startColumn: r.startColumn,
      endLineNumber: r.endLine,
      endColumn: r.endColumn,
    };
  }

  function _toMonacoCompletionItem(item) {
    var out = {
      label: item.label,
      kind: item.kind,
      insertText: item.insertText,
      insertTextRules: item.insertTextRules || 0,
    };
    if (item.detail != null) out.detail = item.detail;
    if (item.documentation != null) out.documentation = item.documentation;
    if (item.sortText != null) out.sortText = item.sortText;
    if (item.filterText != null) out.filterText = item.filterText;
    if (item.preselect != null) out.preselect = item.preselect;
    if (item.commitCharacters != null) out.commitCharacters = item.commitCharacters;
    if (item.range) out.range = _toMonacoRange(item.range);
    return out;
  }

  function _toMonacoMarker(m) {
    var out = {
      startLineNumber: m.startLine,
      startColumn: m.startColumn,
      endLineNumber: m.endLine,
      endColumn: m.endColumn,
      severity: m.severity,
      message: m.message,
    };
    if (m.source) out.source = m.source;
    if (m.code !== undefined) out.code = m.code;
    if (m.tags) out.tags = m.tags;
    if (m.relatedInformation) {
      out.relatedInformation = m.relatedInformation.map(function (r) {
        return {
          resource: r.resource,
          message: r.message,
          startLineNumber: r.startLine,
          startColumn: r.startColumn,
          endLineNumber: r.endLine,
          endColumn: r.endColumn,
        };
      });
    }
    return out;
  }

  function _serializeKey(editorId, e) {
    // Monaco's IKeyboardEvent wraps the browser KeyboardEvent at `browserEvent`.
    var be = e && e.browserEvent || {};
    return {
      editorId: editorId,
      key: be.key || '',
      code: be.code || '',
      keyCode: typeof e.keyCode === 'number' ? e.keyCode : 0,
      ctrl: !!e.ctrlKey,
      shift: !!e.shiftKey,
      alt: !!e.altKey,
      meta: !!e.metaKey,
    };
  }

  window.monacoBridge = bridge;
})();
