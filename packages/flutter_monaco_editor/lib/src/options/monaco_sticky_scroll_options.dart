/// Editor `stickyScroll` option — scroll-pinned outer scope headers.
class MonacoStickyScrollOptions {
  const MonacoStickyScrollOptions({
    this.enabled,
    this.maxLineCount,
    this.defaultModel,
    this.scrollWithEditor,
  });

  final bool? enabled;
  final int? maxLineCount;

  /// Which model provider drives the sticky lines: `'outlineModel'`,
  /// `'foldingProviderModel'`, `'indentationModel'`.
  final String? defaultModel;

  final bool? scrollWithEditor;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{};
    if (enabled != null) out['enabled'] = enabled;
    if (maxLineCount != null) out['maxLineCount'] = maxLineCount;
    if (defaultModel != null) out['defaultModel'] = defaultModel;
    if (scrollWithEditor != null) out['scrollWithEditor'] = scrollWithEditor;
    return out;
  }
}
