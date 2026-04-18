import 'package:flutter/material.dart';

/// A custom Monaco theme — a set of tokenizer rules + semantic colors on
/// top of one of the built-in base themes.
///
/// See <https://microsoft.github.io/monaco-editor/docs.html#interfaces/editor.IStandaloneThemeData.html>.
class MonacoTheme {
  const MonacoTheme({
    required this.base,
    this.inherit = true,
    this.rules = const [],
    this.colors = const {},
  });

  /// A theme whose editor chrome colors are fully transparent — every
  /// surface that could cover a Flutter background image (editor,
  /// gutter, line numbers, minimap, overview ruler, widget backgrounds)
  /// is set to `#00000000`. Tokenizer colors inherit from [base], so
  /// syntax highlighting still works.
  ///
  /// Use alongside the `transparent: true` flag on `MonacoEditor` (which
  /// toggles the WebView background on native) to overlay the editor on
  /// a Flutter-rendered background.
  /// Derive a Monaco theme from a Flutter [ThemeData].
  ///
  /// Maps the Flutter color scheme to the Monaco surface colors that
  /// matter most for embedding the editor into a themed app:
  ///
  /// - `colorScheme.surface` → `editor.background`
  /// - `colorScheme.onSurface` → `editor.foreground`
  /// - `colorScheme.primary` → cursor + links
  /// - `colorScheme.primary` (25% alpha) → selection background
  /// - `colorScheme.onSurfaceVariant` → line-number gutter foreground
  /// - `colorScheme.surfaceContainerHighest` → minimap / widget backgrounds
  ///
  /// Token (syntax) colors inherit from the matching base theme
  /// (`vs` for light, `vs-dark` for dark). Pass [tokenRules] to layer
  /// your own syntax colors on top.
  ///
  /// When [transparent] is true, `editor.background` is set to `#00000000`
  /// instead of the surface color — pair with `MonacoEditor(transparent: true)`
  /// to overlay the editor on a Flutter background.
  factory MonacoTheme.fromFlutterTheme(
    ThemeData theme, {
    List<MonacoTokenRule> tokenRules = const [],
    bool transparent = false,
  }) {
    final cs = theme.colorScheme;
    final bgHex = transparent ? '#00000000' : _hex(cs.surface);
    final widgetBgHex = transparent ? '#00000000' : _hex(cs.surfaceContainerHighest);
    return MonacoTheme(
      base: theme.brightness == Brightness.dark ? 'vs-dark' : 'vs',
      rules: tokenRules,
      colors: {
        'editor.background': bgHex,
        'editor.foreground': _hex(cs.onSurface),
        'editorCursor.foreground': _hex(cs.primary),
        'editorLink.activeForeground': _hex(cs.primary),
        'editor.selectionBackground': _hexAlpha(cs.primary, 0x55),
        'editor.inactiveSelectionBackground': _hexAlpha(cs.primary, 0x33),
        'editor.lineHighlightBackground': _hexAlpha(cs.onSurface, 0x0F),
        'editorLineNumber.foreground': _hexAlpha(cs.onSurfaceVariant, 0x80),
        'editorLineNumber.activeForeground': _hex(cs.onSurface),
        'editorGutter.background': bgHex,
        'editorWhitespace.foreground': _hexAlpha(cs.onSurfaceVariant, 0x40),
        'editorIndentGuide.background1': _hexAlpha(cs.onSurfaceVariant, 0x20),
        'editorIndentGuide.activeBackground1': _hexAlpha(cs.primary, 0x60),
        'minimap.background': widgetBgHex,
        'editorOverviewRuler.background': widgetBgHex,
        'editorWidget.background': widgetBgHex,
        'editorWidget.border': _hexAlpha(cs.outline, 0x80),
        'editorHoverWidget.background': widgetBgHex,
        'editorSuggestWidget.background': widgetBgHex,
        'editorSuggestWidget.selectedBackground': _hexAlpha(cs.primary, 0x40),
        'scrollbarSlider.background': _hexAlpha(cs.onSurfaceVariant, 0x40),
        'scrollbarSlider.hoverBackground': _hexAlpha(cs.onSurfaceVariant, 0x60),
        'scrollbarSlider.activeBackground': _hexAlpha(cs.primary, 0x80),
      },
    );
  }

  factory MonacoTheme.transparent({String base = 'vs-dark'}) {
    return MonacoTheme(
      base: base,
      colors: const {
        'editor.background': '#00000000',
        'editor.lineHighlightBackground': '#00000000',
        'editorGutter.background': '#00000000',
        'editorLineNumber.background': '#00000000',
        'minimap.background': '#00000000',
        'editorOverviewRuler.background': '#00000000',
        'editorWidget.background': '#00000000',
        'editorHoverWidget.background': '#00000000',
        'editorSuggestWidget.background': '#00000000',
        'scrollbarSlider.background': '#30808080',
        'scrollbarSlider.hoverBackground': '#40808080',
      },
    );
  }

  /// One of: `'vs'`, `'vs-dark'`, `'hc-black'`, `'hc-light'`.
  final String base;

  /// When true, theme rules and colors inherit from [base] where not
  /// overridden.
  final bool inherit;

  /// Token-scope → color rules. Scopes follow the TextMate-grammar-based
  /// naming from VS Code (`'comment'`, `'keyword'`, `'string.quoted'`, ...).
  final List<MonacoTokenRule> rules;

  /// Semantic UI colors — e.g. `{'editor.background': '#1E1E2E',
  /// 'editor.foreground': '#CDD6F4'}`.
  final Map<String, String> colors;

  Map<String, Object?> toJson() => {
        'base': base,
        'inherit': inherit,
        'rules': rules.map((r) => r.toJson()).toList(),
        'colors': colors,
      };
}

/// A single tokenizer rule — what foreground/background/style to apply to
/// a given TextMate scope.
class MonacoTokenRule {
  const MonacoTokenRule({
    required this.token,
    this.foreground,
    this.background,
    this.fontStyle,
  });

  /// The TextMate scope (e.g. `'comment'`, `'keyword'`, `'string'`).
  final String token;

  /// Hex color **without the leading `#`** — e.g. `'6A9955'`.
  final String? foreground;
  final String? background;

  /// Space-separated font styles: `'italic'`, `'bold'`, `'underline'`,
  /// `'strikethrough'`.
  final String? fontStyle;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{'token': token};
    if (foreground != null) out['foreground'] = foreground;
    if (background != null) out['background'] = background;
    if (fontStyle != null) out['fontStyle'] = fontStyle;
    return out;
  }
}

String _hex(Color c) {
  final r = ((c.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final g = ((c.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final b = ((c.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

String _hexAlpha(Color c, int alpha) {
  final r = ((c.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final g = ((c.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final b = ((c.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final a = (alpha & 0xff).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b$a';
}
