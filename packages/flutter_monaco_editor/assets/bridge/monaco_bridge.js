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

  handlers['bridge.init'] = function (args) {
    // Loads Monaco's AMD loader, configures paths, then requires editor.main.
    // On success, signals ready.
    return new Promise(function (resolve, reject) {
      if (bridge._ready) { resolve(); return; }
      if (!args || !args.vsPath) { reject(new Error('bridge.init: vsPath required')); return; }

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
    if (!container) throw new Error('editor.create: container "' + args.containerId + '" not in DOM');

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
      editor.onDidFocusEditorText(function () { bridge.emit('editor.focus', { editorId: editorId }); }),
      editor.onDidBlurEditorText(function () { bridge.emit('editor.blur', { editorId: editorId }); }),
    ];

    bridge._editors[editorId] = { editor: editor, disposers: disposers };
    return editorId;
  };

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

  function _entry(editorId) {
    var entry = bridge._editors[editorId];
    if (!entry) throw new Error('unknown editorId: ' + editorId);
    return entry;
  }

  window.monacoBridge = bridge;
})();
