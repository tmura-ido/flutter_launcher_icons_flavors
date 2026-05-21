import 'package:json_annotation/json_annotation.dart';

part 'web_config.g.dart';

/// The flutter_launcher_icons configuration set for Web
@JsonSerializable(anyMap: true, checked: true)
class WebConfig {
  /// Specifies whether to generate icons for web
  final bool generate;

  /// Image path for web
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// manifest.json's background_color
  @JsonKey(name: 'background_color')
  final String? backgroundColor;

  /// manifest.json's theme_color
  @JsonKey(name: 'theme_color')
  final String? themeColor;

  /// Optional output directory for web assets. When unset, defaults to
  /// `web_<flavor>/` if a flavor is active, otherwise plain `web/`
  /// (upstream #426).
  @JsonKey(name: 'output_path')
  final String? outputPath;

  /// When true, emit a multi-size `favicon.ico` alongside `favicon.png`
  /// (upstream #540 / #152). Default true to match long-standing user
  /// expectation; users with their own favicon can opt out.
  @JsonKey(name: 'generate_favicon')
  final bool generateFavicon;

  /// Optional override for the favicon source image (upstream #515 /
  /// #635). Falls back to [imagePath], then to the top-level
  /// `image_path`. Lets users supply a tight, low-padding source for the
  /// small favicon while PWA icons keep their safe-zone padding.
  @JsonKey(name: 'favicon_path')
  final String? faviconPath;

  /// Optional override for the PNG favicon side length. Default is
  /// `constants.kFaviconSize` (16). Upstream #614 (already covered by
  /// existing test) + paired with [generateFavicon] / [faviconPath].
  @JsonKey(name: 'favicon_size')
  final int? faviconSize;

  /// Creates an instance of [WebConfig]
  const WebConfig({
    this.generate = false,
    this.imagePath,
    this.backgroundColor,
    this.themeColor,
    this.outputPath,
    this.generateFavicon = true,
    this.faviconPath,
    this.faviconSize,
  });

  /// Creates [WebConfig] from [json]
  factory WebConfig.fromJson(Map json) => _$WebConfigFromJson(json);

  /// Creates [Map] from [WebConfig]
  Map<String, dynamic> toJson() => _$WebConfigToJson(this);

  @override
  String toString() => 'WebConfig: ${toJson()}';
}
