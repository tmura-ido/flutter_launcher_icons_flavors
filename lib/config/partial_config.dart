import 'package:flutter_launcher_icons_flavors/config/macos_config.dart';
import 'package:flutter_launcher_icons_flavors/config/platform_toggle.dart';
import 'package:flutter_launcher_icons_flavors/config/web_config.dart';
import 'package:flutter_launcher_icons_flavors/config/windows_config.dart';
import 'package:json_annotation/json_annotation.dart';

part 'partial_config.g.dart';

/// A nullable mirror of `Config`. Used as the JSON deserialization target so
/// that "user omitted vs. user-set-to-default" is distinguishable when
/// configurations are merged later.
///
/// No defaults are applied here. No required-field validation is performed.
/// Use `Config.fromPartial` to materialize a fully-validated `Config`.
@JsonSerializable(
  anyMap: true,
  checked: true,
  includeIfNull: false,
  disallowUnrecognizedKeys: true,
)
class PartialConfig {
  /// Creates a [PartialConfig]. All fields default to `null`.
  const PartialConfig({
    this.imagePath,
    this.android,
    this.ios,
    this.imagePathAndroid,
    this.imagePathIOS,
    this.imagePathIOSDarkTransparent,
    this.imagePathIOSTintedGrayscale,
    this.adaptiveIconForeground,
    this.adaptiveIconForegroundInset,
    this.adaptiveIconBackground,
    this.adaptiveIconMonochrome,
    this.minSdkAndroid,
    this.copyMipmapXxxhdpiToDrawable,
    this.removeAlphaIOS,
    this.desaturateTintedToGrayscaleIOS,
    this.backgroundColorIOS,
    this.webConfig,
    this.windowsConfig,
    this.macOSConfig,
  });

  /// Generic image_path
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Android platform toggle.
  @NullablePlatformToggleConverter()
  final PlatformToggle? android;

  /// iOS platform toggle.
  @NullablePlatformToggleConverter()
  final PlatformToggle? ios;

  /// Image path specific to android
  @JsonKey(name: 'image_path_android')
  final String? imagePathAndroid;

  /// Image path specific to ios
  @JsonKey(name: 'image_path_ios')
  final String? imagePathIOS;

  /// IOS image_path_ios_dark_transparent
  @JsonKey(name: 'image_path_ios_dark_transparent')
  final String? imagePathIOSDarkTransparent;

  /// IOS image_path_ios_tinted_grayscale
  @JsonKey(name: 'image_path_ios_tinted_grayscale')
  final String? imagePathIOSTintedGrayscale;

  /// android adaptive_icon_foreground image
  @JsonKey(name: 'adaptive_icon_foreground')
  final String? adaptiveIconForeground;

  /// android adaptive_icon_foreground inset
  @JsonKey(name: 'adaptive_icon_foreground_inset')
  final int? adaptiveIconForegroundInset;

  /// android adaptive_icon_background image
  @JsonKey(name: 'adaptive_icon_background')
  final String? adaptiveIconBackground;

  /// android adaptive_icon_monochrome image
  @JsonKey(name: 'adaptive_icon_monochrome')
  final String? adaptiveIconMonochrome;

  /// Android min_sdk_android
  @JsonKey(name: 'min_sdk_android')
  final int? minSdkAndroid;

  /// When `true`, after generating Android launcher icons the largest
  /// mipmap (`mipmap-xxxhdpi/<icon>.png`) is also copied into the same
  /// flavor's `drawable/` folder (creating it if needed) under the same
  /// filename. Useful when notification icons or other XML resources need
  /// to reference the launcher icon as a drawable.
  @JsonKey(name: 'copy_mipmap_xxxhdpi_to_drawable')
  final bool? copyMipmapXxxhdpiToDrawable;

  /// IOS remove_alpha_ios
  @JsonKey(name: 'remove_alpha_ios')
  final bool? removeAlphaIOS;

  /// IOS desaturate_tinted_to_grayscale_ios
  @JsonKey(name: 'desaturate_tinted_to_grayscale_ios')
  final bool? desaturateTintedToGrayscaleIOS;

  /// IOS background_color_ios
  @JsonKey(name: 'background_color_ios')
  final String? backgroundColorIOS;

  /// Web platform config
  @JsonKey(name: 'web')
  final WebConfig? webConfig;

  /// Windows platform config
  @JsonKey(name: 'windows')
  final WindowsConfig? windowsConfig;

  /// MacOS platform config
  @JsonKey(name: 'macos')
  final MacOSConfig? macOSConfig;

  /// Creates a [PartialConfig] from a YAML/JSON map.
  factory PartialConfig.fromJson(Map json) => _$PartialConfigFromJson(json);

  /// Converts this [PartialConfig] to a JSON-friendly map.
  Map<String, dynamic> toJson() => _$PartialConfigToJson(this);

  @override
  String toString() => 'PartialConfig: ${toJson()}';
}
