/// Per-flavor environment-badge overlay config (upstream #622, phase 1).
///
/// Set in `defaults:` or per-flavor; per-flavor wins via the existing
/// merge pipeline. Phase 1 (this file) defines the schema; the badge
/// renderer + bundled TTF font ship separately.
class BadgeConfig {
  /// Badge text (required). Empty/whitespace causes a doctor warning.
  final String text;

  /// Text color (hex). Default `#FFFFFF`.
  final String? color;

  /// Optional solid pill / banner background color. When null the badge
  /// has no background.
  final String? backgroundColor;

  /// Position: one of `tl`, `topleft`, `tr`, `topright`, `bl`,
  /// `bottomleft`, `br`, `bottomright`, `banner-top`, `banner-bottom`.
  final String position;

  /// Font size as a % of image height. Default 18.
  final int fontSizePct;

  /// Font: either a built-in named font (`Roboto`, `RobotoMono`, `Inter`)
  /// or a path to a `.ttf` file.
  final String? fontFamily;

  /// Padding between badge edge and image edge, % of image height.
  /// Default 4.
  final int paddingPct;

  /// Creates a [BadgeConfig].
  const BadgeConfig({
    required this.text,
    this.color,
    this.backgroundColor,
    this.position = 'tr',
    this.fontSizePct = 18,
    this.fontFamily,
    this.paddingPct = 4,
  });

  /// Parses from a JSON map.
  factory BadgeConfig.fromJson(Map json) => BadgeConfig(
    text: json['text'] as String? ?? '',
    color: json['color'] as String?,
    backgroundColor: json['background_color'] as String?,
    position: (json['position'] as String?) ?? 'tr',
    fontSizePct: (json['font_size_pct'] as num?)?.toInt() ?? 18,
    fontFamily: json['font_family'] as String?,
    paddingPct: (json['padding_pct'] as num?)?.toInt() ?? 4,
  );

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text,
    'color': color,
    'background_color': backgroundColor,
    'position': position,
    'font_size_pct': fontSizePct,
    'font_family': fontFamily,
    'padding_pct': paddingPct,
  };
}
