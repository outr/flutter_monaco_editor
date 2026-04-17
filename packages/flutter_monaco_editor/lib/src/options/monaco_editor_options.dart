import 'enums.dart';
import 'monaco_hover_options.dart';
import 'monaco_minimap_options.dart';
import 'monaco_padding_options.dart';
import 'monaco_scrollbar_options.dart';
import 'monaco_sticky_scroll_options.dart';

/// Typed editor options corresponding to Monaco's `IEditorOptions`.
///
/// Phase 1.4 covers the ~60 IDE-critical options by hand. The remainder of
/// Monaco's 200+ option surface can be set through [rawOptions], which is
/// merged over the typed fields (raw values win on key collision). A
/// generator that emits 1:1 Dart types from `monaco.d.ts` is planned — see
/// the roadmap.
///
/// All fields are nullable. `null` means "don't touch this option" — useful
/// for `MonacoController.updateOptions` where you want to patch a subset
/// without resetting other options.
class MonacoEditorOptions {
  const MonacoEditorOptions({
    // Layout / visibility
    this.readOnly,
    this.domReadOnly,
    this.wordWrap,
    this.wordWrapColumn,
    this.lineNumbers,
    this.lineNumbersMinChars,
    this.glyphMargin,
    this.folding,
    this.foldingStrategy,
    this.showFoldingControls,
    this.renderWhitespace,
    this.renderLineHighlight,
    this.renderFinalNewline,
    this.scrollBeyondLastLine,
    this.scrollBeyondLastColumn,
    this.smoothScrolling,
    this.roundedSelection,
    this.fixedOverflowWidgets,
    this.ariaLabel,

    // Font
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.fontLigatures,
    this.letterSpacing,
    this.lineHeight,

    // Indent
    this.tabSize,
    this.insertSpaces,
    this.detectIndentation,
    this.trimAutoWhitespace,
    this.autoIndent,

    // Cursor / mouse
    this.cursorBlinking,
    this.cursorStyle,
    this.cursorWidth,
    this.cursorSmoothCaretAnimation,
    this.cursorSurroundingLines,
    this.mouseWheelZoom,
    this.multiCursorModifier,

    // Behavior
    this.formatOnPaste,
    this.formatOnType,
    this.autoClosingBrackets,
    this.autoClosingQuotes,
    this.autoSurround,
    this.matchBrackets,
    this.bracketPairColorization,
    this.linkedEditing,
    this.dragAndDrop,
    this.contextmenu,
    this.copyWithSyntaxHighlighting,

    // Suggestion / IntelliSense
    this.quickSuggestions,
    this.quickSuggestionsDelay,
    this.acceptSuggestionOnEnter,
    this.acceptSuggestionOnCommitCharacter,
    this.tabCompletion,
    this.snippetSuggestions,
    this.suggestOnTriggerCharacters,
    this.wordBasedSuggestions,
    this.parameterHints,

    // Scroll
    this.mouseWheelScrollSensitivity,
    this.fastScrollSensitivity,
    this.scrollPredominantAxis,

    // Accessibility
    this.accessibilitySupport,
    this.accessibilityPageSize,

    // Misc display / input
    this.rulers,
    this.showUnused,
    this.emptySelectionClipboard,
    this.useTabStops,
    this.columnSelection,
    this.renderControlCharacters,
    this.disableLayerHinting,
    this.disableMonospaceOptimizations,
    this.hideCursorInOverviewRuler,
    this.tabFocusMode,
    this.multiCursorPaste,
    this.wrappingIndent,
    this.wrappingStrategy,

    // Nested
    this.minimap,
    this.scrollbar,
    this.padding,
    this.stickyScroll,
    this.hover,

    // Escape hatch
    this.rawOptions,
  });

  // --- Layout / visibility ---
  final bool? readOnly;
  final bool? domReadOnly;
  final MonacoWordWrap? wordWrap;
  final int? wordWrapColumn;
  final MonacoLineNumbersStyle? lineNumbers;
  final int? lineNumbersMinChars;
  final bool? glyphMargin;
  final bool? folding;
  final MonacoFoldingStrategy? foldingStrategy;
  final String? showFoldingControls; // 'always' | 'never' | 'mouseover'
  final MonacoRenderWhitespace? renderWhitespace;
  final MonacoRenderLineHighlight? renderLineHighlight;
  final String? renderFinalNewline; // 'on' | 'off' | 'dimmed'
  final bool? scrollBeyondLastLine;
  final int? scrollBeyondLastColumn;
  final bool? smoothScrolling;
  final bool? roundedSelection;
  final bool? fixedOverflowWidgets;
  final String? ariaLabel;

  // --- Font ---
  final String? fontFamily;
  final double? fontSize;
  final String? fontWeight; // 'normal' | 'bold' | '100'..'900'
  final bool? fontLigatures;
  final double? letterSpacing;
  final double? lineHeight;

  // --- Indent ---
  final int? tabSize;
  final bool? insertSpaces;
  final bool? detectIndentation;
  final bool? trimAutoWhitespace;
  final MonacoAutoIndent? autoIndent;

  // --- Cursor / mouse ---
  final MonacoCursorBlinking? cursorBlinking;
  final MonacoCursorStyle? cursorStyle;
  final int? cursorWidth;
  final bool? cursorSmoothCaretAnimation;
  final int? cursorSurroundingLines;
  final bool? mouseWheelZoom;
  final String? multiCursorModifier; // 'ctrlCmd' | 'alt'

  // --- Behavior ---
  final bool? formatOnPaste;
  final bool? formatOnType;
  final MonacoAutoClosingStrategy? autoClosingBrackets;
  final MonacoAutoClosingStrategy? autoClosingQuotes;
  final String? autoSurround; // 'languageDefined' | 'quotes' | 'brackets' | 'never'
  final MonacoMatchBrackets? matchBrackets;
  final bool? bracketPairColorization;
  final bool? linkedEditing;
  final bool? dragAndDrop;
  final bool? contextmenu;
  final bool? copyWithSyntaxHighlighting;

  // --- Suggestion / IntelliSense ---
  /// `editor.quickSuggestions` — `bool` (all contexts) or a per-context
  /// `{other, comments, strings}` record. Pass [rawOptions] for the record
  /// form.
  final bool? quickSuggestions;
  final int? quickSuggestionsDelay;
  final MonacoAcceptSuggestion? acceptSuggestionOnEnter;
  final bool? acceptSuggestionOnCommitCharacter;
  final MonacoTabCompletion? tabCompletion;
  final MonacoSnippetSuggestions? snippetSuggestions;
  final bool? suggestOnTriggerCharacters;
  final bool? wordBasedSuggestions;
  final bool? parameterHints;

  // --- Scroll ---
  final double? mouseWheelScrollSensitivity;
  final double? fastScrollSensitivity;
  final bool? scrollPredominantAxis;

  // --- Accessibility ---
  final MonacoAccessibilitySupport? accessibilitySupport;
  final int? accessibilityPageSize;

  // --- Misc display / input ---
  /// Columns at which to render vertical guide lines.
  final List<int>? rulers;
  final bool? showUnused;
  final bool? emptySelectionClipboard;
  final bool? useTabStops;
  final bool? columnSelection;
  final bool? renderControlCharacters;
  final bool? disableLayerHinting;
  final bool? disableMonospaceOptimizations;
  final bool? hideCursorInOverviewRuler;
  final bool? tabFocusMode;
  final MonacoMultiCursorPaste? multiCursorPaste;
  final MonacoWrappingIndent? wrappingIndent;
  final MonacoWrappingStrategy? wrappingStrategy;

  // --- Nested sub-options ---
  final MonacoMinimapOptions? minimap;
  final MonacoScrollbarOptions? scrollbar;
  final MonacoPaddingOptions? padding;
  final MonacoStickyScrollOptions? stickyScroll;
  final MonacoEditorHoverOptions? hover;

  /// Raw option overrides. Merged into the final JSON after typed fields;
  /// any key here overrides the typed value.
  final Map<String, Object?>? rawOptions;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{};

    void putIfNotNull(String key, Object? value) {
      if (value != null) out[key] = value;
    }

    // Layout / visibility
    putIfNotNull('readOnly', readOnly);
    putIfNotNull('domReadOnly', domReadOnly);
    putIfNotNull('wordWrap', wordWrap?.wireId);
    putIfNotNull('wordWrapColumn', wordWrapColumn);
    putIfNotNull('lineNumbers', lineNumbers?.wireId);
    putIfNotNull('lineNumbersMinChars', lineNumbersMinChars);
    putIfNotNull('glyphMargin', glyphMargin);
    putIfNotNull('folding', folding);
    putIfNotNull('foldingStrategy', foldingStrategy?.wireId);
    putIfNotNull('showFoldingControls', showFoldingControls);
    putIfNotNull('renderWhitespace', renderWhitespace?.wireId);
    putIfNotNull('renderLineHighlight', renderLineHighlight?.wireId);
    putIfNotNull('renderFinalNewline', renderFinalNewline);
    putIfNotNull('scrollBeyondLastLine', scrollBeyondLastLine);
    putIfNotNull('scrollBeyondLastColumn', scrollBeyondLastColumn);
    putIfNotNull('smoothScrolling', smoothScrolling);
    putIfNotNull('roundedSelection', roundedSelection);
    putIfNotNull('fixedOverflowWidgets', fixedOverflowWidgets);
    putIfNotNull('ariaLabel', ariaLabel);

    // Font
    putIfNotNull('fontFamily', fontFamily);
    putIfNotNull('fontSize', fontSize);
    putIfNotNull('fontWeight', fontWeight);
    putIfNotNull('fontLigatures', fontLigatures);
    putIfNotNull('letterSpacing', letterSpacing);
    putIfNotNull('lineHeight', lineHeight);

    // Indent
    putIfNotNull('tabSize', tabSize);
    putIfNotNull('insertSpaces', insertSpaces);
    putIfNotNull('detectIndentation', detectIndentation);
    putIfNotNull('trimAutoWhitespace', trimAutoWhitespace);
    putIfNotNull('autoIndent', autoIndent?.wireId);

    // Cursor / mouse
    putIfNotNull('cursorBlinking', cursorBlinking?.wireId);
    putIfNotNull('cursorStyle', cursorStyle?.wireId);
    putIfNotNull('cursorWidth', cursorWidth);
    putIfNotNull('cursorSmoothCaretAnimation', cursorSmoothCaretAnimation);
    putIfNotNull('cursorSurroundingLines', cursorSurroundingLines);
    putIfNotNull('mouseWheelZoom', mouseWheelZoom);
    putIfNotNull('multiCursorModifier', multiCursorModifier);

    // Behavior
    putIfNotNull('formatOnPaste', formatOnPaste);
    putIfNotNull('formatOnType', formatOnType);
    putIfNotNull('autoClosingBrackets', autoClosingBrackets?.wireId);
    putIfNotNull('autoClosingQuotes', autoClosingQuotes?.wireId);
    putIfNotNull('autoSurround', autoSurround);
    putIfNotNull('matchBrackets', matchBrackets?.wireId);
    putIfNotNull('bracketPairColorization',
        bracketPairColorization == null ? null : {'enabled': bracketPairColorization});
    putIfNotNull('linkedEditing', linkedEditing);
    putIfNotNull('dragAndDrop', dragAndDrop);
    putIfNotNull('contextmenu', contextmenu);
    putIfNotNull('copyWithSyntaxHighlighting', copyWithSyntaxHighlighting);

    // Suggestion / IntelliSense
    putIfNotNull('quickSuggestions', quickSuggestions);
    putIfNotNull('quickSuggestionsDelay', quickSuggestionsDelay);
    putIfNotNull('acceptSuggestionOnEnter', acceptSuggestionOnEnter?.wireId);
    putIfNotNull(
      'acceptSuggestionOnCommitCharacter',
      acceptSuggestionOnCommitCharacter,
    );
    putIfNotNull('tabCompletion', tabCompletion?.wireId);
    putIfNotNull('snippetSuggestions', snippetSuggestions?.wireId);
    putIfNotNull('suggestOnTriggerCharacters', suggestOnTriggerCharacters);
    putIfNotNull('wordBasedSuggestions', wordBasedSuggestions);
    putIfNotNull('parameterHints',
        parameterHints == null ? null : {'enabled': parameterHints});

    // Scroll
    putIfNotNull('mouseWheelScrollSensitivity', mouseWheelScrollSensitivity);
    putIfNotNull('fastScrollSensitivity', fastScrollSensitivity);
    putIfNotNull('scrollPredominantAxis', scrollPredominantAxis);

    // Accessibility
    putIfNotNull('accessibilitySupport', accessibilitySupport?.wireId);
    putIfNotNull('accessibilityPageSize', accessibilityPageSize);

    // Misc display / input
    putIfNotNull('rulers', rulers);
    putIfNotNull('showUnused', showUnused);
    putIfNotNull('emptySelectionClipboard', emptySelectionClipboard);
    putIfNotNull('useTabStops', useTabStops);
    putIfNotNull('columnSelection', columnSelection);
    putIfNotNull('renderControlCharacters', renderControlCharacters);
    putIfNotNull('disableLayerHinting', disableLayerHinting);
    putIfNotNull('disableMonospaceOptimizations', disableMonospaceOptimizations);
    putIfNotNull('hideCursorInOverviewRuler', hideCursorInOverviewRuler);
    putIfNotNull('tabFocusMode', tabFocusMode);
    putIfNotNull('multiCursorPaste', multiCursorPaste?.wireId);
    putIfNotNull('wrappingIndent', wrappingIndent?.wireId);
    putIfNotNull('wrappingStrategy', wrappingStrategy?.wireId);

    // Nested
    if (minimap != null) out['minimap'] = minimap!.toJson();
    if (scrollbar != null) out['scrollbar'] = scrollbar!.toJson();
    if (padding != null) out['padding'] = padding!.toJson();
    if (stickyScroll != null) out['stickyScroll'] = stickyScroll!.toJson();
    if (hover != null) out['hover'] = hover!.toJson();

    // Raw overrides win
    if (rawOptions != null) out.addAll(rawOptions!);
    return out;
  }

  /// Merge [other]'s non-null fields over this one. Useful for layering
  /// defaults with user overrides.
  MonacoEditorOptions mergedWith(MonacoEditorOptions other) {
    return MonacoEditorOptions(
      readOnly: other.readOnly ?? readOnly,
      domReadOnly: other.domReadOnly ?? domReadOnly,
      wordWrap: other.wordWrap ?? wordWrap,
      wordWrapColumn: other.wordWrapColumn ?? wordWrapColumn,
      lineNumbers: other.lineNumbers ?? lineNumbers,
      lineNumbersMinChars: other.lineNumbersMinChars ?? lineNumbersMinChars,
      glyphMargin: other.glyphMargin ?? glyphMargin,
      folding: other.folding ?? folding,
      foldingStrategy: other.foldingStrategy ?? foldingStrategy,
      showFoldingControls: other.showFoldingControls ?? showFoldingControls,
      renderWhitespace: other.renderWhitespace ?? renderWhitespace,
      renderLineHighlight: other.renderLineHighlight ?? renderLineHighlight,
      renderFinalNewline: other.renderFinalNewline ?? renderFinalNewline,
      scrollBeyondLastLine: other.scrollBeyondLastLine ?? scrollBeyondLastLine,
      scrollBeyondLastColumn:
          other.scrollBeyondLastColumn ?? scrollBeyondLastColumn,
      smoothScrolling: other.smoothScrolling ?? smoothScrolling,
      roundedSelection: other.roundedSelection ?? roundedSelection,
      fixedOverflowWidgets: other.fixedOverflowWidgets ?? fixedOverflowWidgets,
      ariaLabel: other.ariaLabel ?? ariaLabel,
      fontFamily: other.fontFamily ?? fontFamily,
      fontSize: other.fontSize ?? fontSize,
      fontWeight: other.fontWeight ?? fontWeight,
      fontLigatures: other.fontLigatures ?? fontLigatures,
      letterSpacing: other.letterSpacing ?? letterSpacing,
      lineHeight: other.lineHeight ?? lineHeight,
      tabSize: other.tabSize ?? tabSize,
      insertSpaces: other.insertSpaces ?? insertSpaces,
      detectIndentation: other.detectIndentation ?? detectIndentation,
      trimAutoWhitespace: other.trimAutoWhitespace ?? trimAutoWhitespace,
      autoIndent: other.autoIndent ?? autoIndent,
      cursorBlinking: other.cursorBlinking ?? cursorBlinking,
      cursorStyle: other.cursorStyle ?? cursorStyle,
      cursorWidth: other.cursorWidth ?? cursorWidth,
      cursorSmoothCaretAnimation:
          other.cursorSmoothCaretAnimation ?? cursorSmoothCaretAnimation,
      cursorSurroundingLines:
          other.cursorSurroundingLines ?? cursorSurroundingLines,
      mouseWheelZoom: other.mouseWheelZoom ?? mouseWheelZoom,
      multiCursorModifier: other.multiCursorModifier ?? multiCursorModifier,
      formatOnPaste: other.formatOnPaste ?? formatOnPaste,
      formatOnType: other.formatOnType ?? formatOnType,
      autoClosingBrackets: other.autoClosingBrackets ?? autoClosingBrackets,
      autoClosingQuotes: other.autoClosingQuotes ?? autoClosingQuotes,
      autoSurround: other.autoSurround ?? autoSurround,
      matchBrackets: other.matchBrackets ?? matchBrackets,
      bracketPairColorization:
          other.bracketPairColorization ?? bracketPairColorization,
      linkedEditing: other.linkedEditing ?? linkedEditing,
      dragAndDrop: other.dragAndDrop ?? dragAndDrop,
      contextmenu: other.contextmenu ?? contextmenu,
      copyWithSyntaxHighlighting:
          other.copyWithSyntaxHighlighting ?? copyWithSyntaxHighlighting,
      quickSuggestions: other.quickSuggestions ?? quickSuggestions,
      quickSuggestionsDelay:
          other.quickSuggestionsDelay ?? quickSuggestionsDelay,
      acceptSuggestionOnEnter:
          other.acceptSuggestionOnEnter ?? acceptSuggestionOnEnter,
      acceptSuggestionOnCommitCharacter: other.acceptSuggestionOnCommitCharacter ??
          acceptSuggestionOnCommitCharacter,
      tabCompletion: other.tabCompletion ?? tabCompletion,
      snippetSuggestions: other.snippetSuggestions ?? snippetSuggestions,
      suggestOnTriggerCharacters:
          other.suggestOnTriggerCharacters ?? suggestOnTriggerCharacters,
      wordBasedSuggestions:
          other.wordBasedSuggestions ?? wordBasedSuggestions,
      parameterHints: other.parameterHints ?? parameterHints,
      mouseWheelScrollSensitivity:
          other.mouseWheelScrollSensitivity ?? mouseWheelScrollSensitivity,
      fastScrollSensitivity:
          other.fastScrollSensitivity ?? fastScrollSensitivity,
      scrollPredominantAxis:
          other.scrollPredominantAxis ?? scrollPredominantAxis,
      accessibilitySupport:
          other.accessibilitySupport ?? accessibilitySupport,
      accessibilityPageSize:
          other.accessibilityPageSize ?? accessibilityPageSize,
      rulers: other.rulers ?? rulers,
      showUnused: other.showUnused ?? showUnused,
      emptySelectionClipboard:
          other.emptySelectionClipboard ?? emptySelectionClipboard,
      useTabStops: other.useTabStops ?? useTabStops,
      columnSelection: other.columnSelection ?? columnSelection,
      renderControlCharacters:
          other.renderControlCharacters ?? renderControlCharacters,
      disableLayerHinting:
          other.disableLayerHinting ?? disableLayerHinting,
      disableMonospaceOptimizations: other.disableMonospaceOptimizations ??
          disableMonospaceOptimizations,
      hideCursorInOverviewRuler:
          other.hideCursorInOverviewRuler ?? hideCursorInOverviewRuler,
      tabFocusMode: other.tabFocusMode ?? tabFocusMode,
      multiCursorPaste: other.multiCursorPaste ?? multiCursorPaste,
      wrappingIndent: other.wrappingIndent ?? wrappingIndent,
      wrappingStrategy: other.wrappingStrategy ?? wrappingStrategy,
      minimap: other.minimap ?? minimap,
      scrollbar: other.scrollbar ?? scrollbar,
      padding: other.padding ?? padding,
      stickyScroll: other.stickyScroll ?? stickyScroll,
      hover: other.hover ?? hover,
      rawOptions: {
        ...?rawOptions,
        ...?other.rawOptions,
      },
    );
  }
}
