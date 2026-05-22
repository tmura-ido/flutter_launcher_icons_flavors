import 'package:flutter_launcher_icons_flavors/config/badge_config.dart';
import 'package:flutter_launcher_icons_flavors/config/ios_alternate_icons_config.dart';
import 'package:flutter_launcher_icons_flavors/config/linux_config.dart';
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
    this.backgroundColor,
    this.backgroundColorIOS,
    this.webConfig,
    this.windowsConfig,
    this.macOSConfig,
    this.flavor,
    this.xcodeprojPath,
    this.iosLegacySizes,
    this.iosSingleSize,
    this.optimizePng,
    this.iosDisableLiquidGlass,
    this.nonSquareImageOk,
    this.linuxConfig,
    this.iosAlternateIcons,
    this.badge,
  });

  /// Optional explicit flavor name. Wins over the filename-derived flavor
  /// (`flutter_launcher_icons-<flavor>.yaml`) when both are present. Lets
  /// users keep a single-flavor file outside the project root and still
  /// route output to the right `src/<flavor>/res/` directory (upstream
  /// #490).
  final String? flavor;

  /// Optional Xcode project path override. When unset, the iOS pipeline
  /// auto-detects via `ios/*.xcodeproj` and falls back to
  /// `ios/Runner.xcodeproj` (upstream #543 + #637).
  @JsonKey(name: 'xcodeproj_path')
  final String? xcodeprojPath;

  /// When true, emit the union of legacy + modern iOS sizes so the
  /// app switcher / older system surfaces find the 1x assets they need
  /// (upstream #661). Default false.
  @JsonKey(name: 'ios_legacy_sizes')
  final bool? iosLegacySizes;

  /// When true, the iOS writer emits only the 1024×1024 marketing slot
  /// + a minimal `Contents.json` (Xcode 14+ "single size" mode, upstream
  /// #592). Overrides `ios_legacy_sizes`. Default false.
  @JsonKey(name: 'ios_single_size')
  final bool? iosSingleSize;

  /// When true, every PNG the generator writes is run through the `image`
  /// package's max-compression encoder. Slower; typical 30–70 % file-size
  /// savings (upstream #139 / #199). Default false.
  @JsonKey(name: 'optimize_png')
  final bool? optimizePng;

  /// When true, the iOS asset-catalog Contents.json carries the
  /// Liquid-Glass opt-out marker for Xcode 26+ (upstream #657). The exact
  /// Apple metadata key is still under investigation; setting this flag
  /// today is preserved through config but is a stub until the Contents
  /// emitter learns the key.
  @JsonKey(name: 'ios_disable_liquid_glass')
  final bool? iosDisableLiquidGlass;

  /// Opt-out of the doctor's "non-square source" warning (upstream #214).
  /// When true, non-square sources are accepted silently. Default false.
  @JsonKey(name: 'non_square_image_ok')
  final bool? nonSquareImageOk;

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

  /// Top-level hex background color used as the default for every platform's
  /// letter-box bars (upstream #214) and as the fallback for
  /// [backgroundColorIOS] and `web.background_color` when those aren't set
  /// explicitly. Accepted formats: `#RRGGBB` / `#RRGGBBAA`. Unset (null) →
  /// platform-specific defaults are kept; the Android non-adaptive mipmap
  /// path stays on legacy squish.
  @JsonKey(name: 'background_color')
  final String? backgroundColor;

  /// IOS background_color_ios — when set, wins over [backgroundColor] for
  /// the iOS pipeline. When unset, falls back to [backgroundColor], then
  /// `#FFFFFF`.
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

  /// Linux platform config (upstream #666).
  @JsonKey(name: 'linux')
  final LinuxConfig? linuxConfig;

  /// iOS alternate-icon sets (upstream #92, phase 1). Only the asset
  /// sets are generated; Info.plist patching ships with phase 2.
  @JsonKey(name: 'ios_alternate_icons')
  final IosAlternateIconsConfig? iosAlternateIcons;

  /// Per-flavor environment-badge overlay (upstream #622, phase 1:
  /// schema only). Set in `defaults:` or per-flavor; per-flavor wins.
  @JsonKey(name: 'badge')
  final BadgeConfig? badge;

  /// Creates a [PartialConfig] from a YAML/JSON map.
  factory PartialConfig.fromJson(Map json) => _$PartialConfigFromJson(json);

  /// Converts this [PartialConfig] to a JSON-friendly map.
  Map<String, dynamic> toJson() => _$PartialConfigToJson(this);

  @override
  String toString() => 'PartialConfig: ${toJson()}';
}
