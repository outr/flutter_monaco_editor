/// Editor `padding` option — space reserved above and below the content area.
class MonacoPaddingOptions {
  const MonacoPaddingOptions({this.top, this.bottom});

  final int? top;
  final int? bottom;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{};
    if (top != null) out['top'] = top;
    if (bottom != null) out['bottom'] = bottom;
    return out;
  }
}
