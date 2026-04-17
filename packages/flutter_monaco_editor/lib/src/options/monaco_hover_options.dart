/// Editor `hover` option — tooltip behavior.
class MonacoEditorHoverOptions {
  const MonacoEditorHoverOptions({
    this.enabled,
    this.delay,
    this.sticky,
    this.hidingDelay,
    this.above,
  });

  final bool? enabled;

  /// Milliseconds before the hover tooltip appears after pointer rests.
  final int? delay;

  /// If true, the tooltip remains visible while the pointer is over it.
  final bool? sticky;

  /// Milliseconds before the hover tooltip hides after the pointer leaves.
  final int? hidingDelay;

  /// If true, prefer showing the tooltip above the cursor.
  final bool? above;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{};
    if (enabled != null) out['enabled'] = enabled;
    if (delay != null) out['delay'] = delay;
    if (sticky != null) out['sticky'] = sticky;
    if (hidingDelay != null) out['hidingDelay'] = hidingDelay;
    if (above != null) out['above'] = above;
    return out;
  }
}
