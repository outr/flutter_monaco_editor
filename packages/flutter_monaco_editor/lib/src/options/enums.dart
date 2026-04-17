// Enum wrappers over Monaco's string-union option types.
//
// Each enum carries a [wireId] that serializes to the exact string Monaco
// expects. Using enums everywhere gives us autocomplete + type safety in
// Dart while still producing the right JSON for the bridge.

/// `editor.wordWrap` — how long lines should wrap.
enum MonacoWordWrap {
  off,
  on,
  wordWrapColumn,
  bounded;

  String get wireId => switch (this) {
        MonacoWordWrap.off => 'off',
        MonacoWordWrap.on => 'on',
        MonacoWordWrap.wordWrapColumn => 'wordWrapColumn',
        MonacoWordWrap.bounded => 'bounded',
      };
}

/// `editor.lineNumbers` — gutter line-number rendering style. Monaco also
/// accepts a function for custom rendering; use `rawOptions` on
/// `MonacoEditorOptions` if you need that.
enum MonacoLineNumbersStyle {
  on,
  off,
  relative,
  interval;

  String get wireId => name;
}

/// `editor.cursorBlinking`.
enum MonacoCursorBlinking {
  blink,
  smooth,
  phase,
  expand,
  solid;

  String get wireId => name;
}

/// `editor.cursorStyle`.
enum MonacoCursorStyle {
  line,
  block,
  underline,
  lineThin,
  blockOutline,
  underlineThin;

  String get wireId => switch (this) {
        MonacoCursorStyle.line => 'line',
        MonacoCursorStyle.block => 'block',
        MonacoCursorStyle.underline => 'underline',
        MonacoCursorStyle.lineThin => 'line-thin',
        MonacoCursorStyle.blockOutline => 'block-outline',
        MonacoCursorStyle.underlineThin => 'underline-thin',
      };
}

/// `editor.renderWhitespace`.
enum MonacoRenderWhitespace {
  none,
  boundary,
  selection,
  trailing,
  all;

  String get wireId => name;
}

/// `editor.renderLineHighlight`.
enum MonacoRenderLineHighlight {
  none,
  gutter,
  line,
  all;

  String get wireId => name;
}

/// `editor.autoClosingBrackets` / `autoClosingQuotes`.
enum MonacoAutoClosingStrategy {
  always,
  languageDefined,
  beforeWhitespace,
  never;

  String get wireId => switch (this) {
        MonacoAutoClosingStrategy.always => 'always',
        MonacoAutoClosingStrategy.languageDefined => 'languageDefined',
        MonacoAutoClosingStrategy.beforeWhitespace => 'beforeWhitespace',
        MonacoAutoClosingStrategy.never => 'never',
      };
}

/// `editor.autoIndent`.
enum MonacoAutoIndent {
  none,
  keep,
  brackets,
  advanced,
  full;

  String get wireId => name;
}

/// `editor.acceptSuggestionOnEnter` / similar.
enum MonacoAcceptSuggestion {
  on,
  smart,
  off;

  String get wireId => name;
}

/// `editor.snippetSuggestions` — placement relative to other completions.
enum MonacoSnippetSuggestions {
  top,
  bottom,
  inline,
  none;

  String get wireId => name;
}

/// `editor.matchBrackets`.
enum MonacoMatchBrackets {
  never,
  near,
  always;

  String get wireId => name;
}

/// `editor.tabCompletion`.
enum MonacoTabCompletion {
  on,
  off,
  onlySnippets;

  String get wireId => name;
}

/// `editor.foldingStrategy`.
enum MonacoFoldingStrategy {
  auto,
  indentation;

  String get wireId => name;
}

/// `editor.minimap.side`.
enum MonacoMinimapSide {
  right,
  left;

  String get wireId => name;
}

/// `editor.minimap.showSlider`.
enum MonacoMinimapSlider {
  always,
  mouseover;

  String get wireId => name;
}

/// `editor.minimap.size`.
enum MonacoMinimapSize {
  proportional,
  fill,
  fit;

  String get wireId => name;
}

/// `editor.scrollbar.{vertical,horizontal}` visibility.
enum MonacoScrollbarVisibility {
  auto,
  visible,
  hidden;

  String get wireId => name;
}

/// `editor.wrappingIndent`.
enum MonacoWrappingIndent {
  none,
  same,
  indent,
  deepIndent;

  String get wireId => name;
}

/// `editor.wrappingStrategy`.
enum MonacoWrappingStrategy {
  simple,
  advanced;

  String get wireId => name;
}

/// `editor.multiCursorPaste`.
enum MonacoMultiCursorPaste {
  spread,
  full;

  String get wireId => name;
}

/// `editor.accessibilitySupport`.
enum MonacoAccessibilitySupport {
  auto,
  on,
  off;

  String get wireId => name;
}

/// `editor.renderFinalNewline`.
enum MonacoRenderFinalNewline {
  on,
  off,
  dimmed;

  String get wireId => name;
}

/// `editor.showFoldingControls`.
enum MonacoShowFoldingControls {
  always,
  never,
  mouseover;

  String get wireId => name;
}
