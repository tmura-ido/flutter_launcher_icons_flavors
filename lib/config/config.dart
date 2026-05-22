import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart' as yaml;
import 'package:flutter_launcher_icons_flavors/config/badge_config.dart';
import 'package:flutter_launcher_icons_flavors/config/ios_alternate_icons_config.dart';
import 'package:flutter_launcher_icons_flavors/config/linux_config.dart';
import 'package:flutter_launcher_icons_flavors/config/macos_config.dart';
import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:flutter_launcher_icons_flavors/config/platform_toggle.dart';
import 'package:flutter_launcher_icons_flavors/config/web_config.dart';
import 'package:flutter_launcher_icons_flavors/config/windows_config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as path;

part 'config.g.dart';

/// A model representing the flutter_launcher_icons configuration
@JsonSerializable(anyMap: true, checked: true, createFactory: false)
class Config {
  /// Default value for `adaptive_icon_foreground_inset`.
  static const int defaultAdaptiveIconForegroundInset = 16;

  /// Default value for `remove_alpha_ios`.
  static const bool defaultRemoveAlphaIOS = false;

  /// Default value for `desaturate_tinted_to_grayscale_ios`.
  static const bool defaultDesaturateTintedToGrayscaleIOS = false;

  /// Default value for `background_color_ios`.
  static const String defaultBackgroundColorIOS = '#ffffff';

  /// Default value for `copy_mipmap_xxxhdpi_to_drawable`.
  static const bool defaultCopyMipmapXxxhdpiToDrawable = false;

  /// Creates an instance of [Config].
  ///
  /// All fields default to the same values that were previously implicit in
  /// the JSON deserializer.
  Config({
    this.imagePath,
    PlatformToggle? android,
    PlatformToggle? ios,
    this.imagePathAndroid,
    this.imagePathIOS,
    this.imagePathIOSDarkTransparent,
    this.imagePathIOSTintedGrayscale,
    this.adaptiveIconForeground,
    this.adaptiveIconForegroundInset = defaultAdaptiveIconForegroundInset,
    this.adaptiveIconBackground,
    this.adaptiveIconMonochrome,
    this.minSdkAndroid,
    this.copyMipmapXxxhdpiToDrawable = defaultCopyMipmapXxxhdpiToDrawable,
    this.removeAlphaIOS = defaultRemoveAlphaIOS,
    this.desaturateTintedToGrayscaleIOS = defaultDesaturateTintedToGrayscaleIOS,
    this.backgroundColor,
    this.backgroundColorIOS = defaultBackgroundColorIOS,
    this.webConfig,
    this.windowsConfig,
    this.macOSConfig,
    this.flavor,
    this.xcodeprojPath,
    this.iosLegacySizes = false,
    this.iosSingleSize = false,
    this.optimizePng = false,
    this.iosDisableLiquidGlass = false,
    this.nonSquareImageOk = false,
    this.linuxConfig,
    this.iosAlternateIcons,
    this.badge,
  }) : android = android ?? PlatformToggle.disabled(),
       ios = ios ?? PlatformToggle.disabled();

  /// Optional explicit flavor name set in the YAML (upstream #490).
  /// Resolution precedence at the call site: explicit `flavor:` > filename
  /// suffix > none.
  @JsonKey(name: 'flavor')
  final String? flavor;

  /// Optional Xcode project path override (upstream #543 + #637). When
  /// unset, iOS auto-detects from `ios/*.xcodeproj`; falls back to
  /// `ios/Runner.xcodeproj` when there are zero matches.
  @JsonKey(name: 'xcodeproj_path')
  final String? xcodeprojPath;

  /// When true, emit legacy 1x iOS sizes (`-20x20@1x`, `-29x29@1x`,
  /// `-40x40@1x`, `-76x76@1x`) alongside the modern set so the iPhone app
  /// switcher and older system surfaces find every size (upstream #661).
  /// Default false to preserve existing fork output.
  @JsonKey(name: 'ios_legacy_sizes')
  final bool iosLegacySizes;

  /// When true, the iOS writer emits only `AppIcon-1024x1024@1x.png` plus
  /// a minimal Contents.json (Xcode 14+ "single size" mode, upstream
  /// #592). Overrides [iosLegacySizes]. Default false.
  @JsonKey(name: 'ios_single_size')
  final bool iosSingleSize;

  /// When true, every PNG the generator writes uses the `image` package's
  /// max-compression encoder (slower; ~30–70 % smaller files). Upstream
  /// #139 / #199. Default false.
  @JsonKey(name: 'optimize_png')
  final bool optimizePng;

  /// When true, the iOS Contents.json carries the Liquid-Glass opt-out
  /// marker for Xcode 26+ (upstream #657). Stub: the exact Apple metadata
  /// key is under investigation and not yet emitted.
  @JsonKey(name: 'ios_disable_liquid_glass')
  final bool iosDisableLiquidGlass;

  /// When true, the doctor's "non-square source" warning is suppressed
  /// (upstream #214). Default false.
  @JsonKey(name: 'non_square_image_ok')
  final bool nonSquareImageOk;

  /// Linux platform config (upstream #666). Optional.
  @JsonKey(name: 'linux')
  final LinuxConfig? linuxConfig;

  /// iOS alternate-icon sets (upstream #92, phase 1).
  @JsonKey(name: 'ios_alternate_icons')
  final IosAlternateIconsConfig? iosAlternateIcons;

  /// Per-flavor environment-badge overlay (upstream #622, phase 1).
  @JsonKey(name: 'badge')
  final BadgeConfig? badge;

  /// Builds a fully-validated [Config] from a [PartialConfig], filling in
  /// defaults for omitted fields.
  ///
  /// Throws [InvalidConfigException] if any platform is enabled but no
  /// image source (`image_path`, `image_path_android`, or `image_path_ios`)
  /// is provided. Per-platform image paths inside `web` / `windows` /
  /// `macos` blocks satisfy the requirement for those platforms — but if
  /// the top-level android/ios toggle is enabled, a top-level / android /
  /// ios image path is still required.
  factory Config.fromPartial(PartialConfig partial) {
    final android = partial.android ?? PlatformToggle.disabled();
    final ios = partial.ios ?? PlatformToggle.disabled();
    final web = partial.webConfig;
    final windows = partial.windowsConfig;
    final macos = partial.macOSConfig;

    final hasAnyPlatform =
        android.isEnabled ||
        ios.isEnabled ||
        (web?.generate ?? false) ||
        (windows?.generate ?? false) ||
        (macos?.generate ?? false);

    bool isBlank(String? s) => s == null || s.isEmpty;

    final hasTopLevelImagePath = !isBlank(partial.imagePath);
    final hasAndroidImagePath = !isBlank(partial.imagePathAndroid);
    final hasIOSImagePath = !isBlank(partial.imagePathIOS);
    final hasWebImagePath = !isBlank(web?.imagePath);
    final hasWindowsImagePath = !isBlank(windows?.imagePath);
    final hasMacOSImagePath = !isBlank(macos?.imagePath);

    final hasAnyImagePath =
        hasTopLevelImagePath ||
        hasAndroidImagePath ||
        hasIOSImagePath ||
        hasWebImagePath ||
        hasWindowsImagePath ||
        hasMacOSImagePath;

    if (hasAnyPlatform && !hasAnyImagePath) {
      throw const InvalidConfigException(
        'image_path: ${constants.errorMissingImagePath}',
      );
    }

    // android/ios specifically require a top-level or android/ios image path
    // (per-platform web/windows/macos image_path doesn't satisfy them).
    final hasMobileImageSource =
        hasTopLevelImagePath || hasAndroidImagePath || hasIOSImagePath;
    if (android.isEnabled && !hasMobileImageSource) {
      throw const InvalidConfigException(
        'image_path / image_path_android: ${constants.errorMissingImagePath}',
      );
    }
    if (ios.isEnabled && !hasMobileImageSource) {
      throw const InvalidConfigException(
        'image_path / image_path_ios: ${constants.errorMissingImagePath}',
      );
    }

    // README contract: adaptive_icon_foreground without adaptive_icon_background
    // is a hard error. (The downstream pipeline would otherwise silently
    // skip adaptive-icon generation, which surprised users.)
    if (!isBlank(partial.adaptiveIconForeground) &&
        isBlank(partial.adaptiveIconBackground)) {
      throw const InvalidConfigException(
        'adaptive_icon_background: required when adaptive_icon_foreground '
        'is set (color "#RRGGBB" or path to a background image).',
      );
    }

    // adaptive_icon_foreground / _monochrome must be an image path; a hex
    // literal here would later be opened as a file and crash with
    // `FileSystemException: Cannot open file, path = '#FFFFFF'`
    // (upstream #175).
    void rejectHexImagePath(String field, String? value) {
      if (value == null || value.isEmpty) return;
      if (RegExp(r'^#?[0-9A-Fa-f]{3,8}$').hasMatch(value)) {
        throw InvalidConfigException(
          "$field: '$value' must be an image path; hex color literals are "
          'not valid here.',
        );
      }
    }

    rejectHexImagePath(
      'adaptive_icon_foreground',
      partial.adaptiveIconForeground,
    );
    rejectHexImagePath(
      'adaptive_icon_monochrome',
      partial.adaptiveIconMonochrome,
    );

    return Config(
      imagePath: partial.imagePath,
      android: partial.android,
      ios: partial.ios,
      imagePathAndroid: partial.imagePathAndroid,
      imagePathIOS: partial.imagePathIOS,
      imagePathIOSDarkTransparent: partial.imagePathIOSDarkTransparent,
      imagePathIOSTintedGrayscale: partial.imagePathIOSTintedGrayscale,
      adaptiveIconForeground: partial.adaptiveIconForeground,
      adaptiveIconForegroundInset:
          partial.adaptiveIconForegroundInset ??
          defaultAdaptiveIconForegroundInset,
      adaptiveIconBackground: partial.adaptiveIconBackground,
      adaptiveIconMonochrome: partial.adaptiveIconMonochrome,
      // NOTE: We intentionally do NOT default to
      // [constants.androidDefaultAndroidMinSDK] here. A null value means "user
      // omitted min_sdk_android"; the Android pipeline resolves it via
      // [android.resolveMinSdkAndroid] (explicit → autodetect → static
      // default + warning). Collapsing omission into 24 here would skip
      // gradle autodetection entirely.
      minSdkAndroid: partial.minSdkAndroid,
      copyMipmapXxxhdpiToDrawable:
          partial.copyMipmapXxxhdpiToDrawable ??
          defaultCopyMipmapXxxhdpiToDrawable,
      removeAlphaIOS: partial.removeAlphaIOS ?? defaultRemoveAlphaIOS,
      desaturateTintedToGrayscaleIOS:
          partial.desaturateTintedToGrayscaleIOS ??
          defaultDesaturateTintedToGrayscaleIOS,
      backgroundColor: partial.backgroundColor,
      backgroundColorIOS:
          partial.backgroundColorIOS ??
          partial.backgroundColor ??
          defaultBackgroundColorIOS,
      webConfig: partial.webConfig,
      windowsConfig: partial.windowsConfig,
      macOSConfig: partial.macOSConfig,
      flavor: partial.flavor,
      xcodeprojPath: partial.xcodeprojPath,
      iosLegacySizes: partial.iosLegacySizes ?? false,
      iosSingleSize: partial.iosSingleSize ?? false,
      optimizePng: partial.optimizePng ?? false,
      iosDisableLiquidGlass: partial.iosDisableLiquidGlass ?? false,
      nonSquareImageOk: partial.nonSquareImageOk ?? false,
      linuxConfig: partial.linuxConfig,
      iosAlternateIcons: partial.iosAlternateIcons,
      badge: partial.badge,
    );
  }

  /// Returns a [PartialConfig] holding the same values as this [Config].
  PartialConfig toPartial() {
    return PartialConfig(
      imagePath: imagePath,
      android: android,
      ios: ios,
      imagePathAndroid: imagePathAndroid,
      imagePathIOS: imagePathIOS,
      imagePathIOSDarkTransparent: imagePathIOSDarkTransparent,
      imagePathIOSTintedGrayscale: imagePathIOSTintedGrayscale,
      adaptiveIconForeground: adaptiveIconForeground,
      adaptiveIconForegroundInset: adaptiveIconForegroundInset,
      adaptiveIconBackground: adaptiveIconBackground,
      adaptiveIconMonochrome: adaptiveIconMonochrome,
      minSdkAndroid: minSdkAndroid,
      copyMipmapXxxhdpiToDrawable: copyMipmapXxxhdpiToDrawable,
      removeAlphaIOS: removeAlphaIOS,
      desaturateTintedToGrayscaleIOS: desaturateTintedToGrayscaleIOS,
      backgroundColor: backgroundColor,
      backgroundColorIOS: backgroundColorIOS,
      webConfig: webConfig,
      windowsConfig: windowsConfig,
      macOSConfig: macOSConfig,
      flavor: flavor,
      xcodeprojPath: xcodeprojPath,
      iosLegacySizes: iosLegacySizes,
      iosSingleSize: iosSingleSize,
      optimizePng: optimizePng,
      iosDisableLiquidGlass: iosDisableLiquidGlass,
      nonSquareImageOk: nonSquareImageOk,
      linuxConfig: linuxConfig,
      iosAlternateIcons: iosAlternateIcons,
      badge: badge,
    );
  }

  /// Creates [Config] for given [flavor] and [prefixPath]
  static Config? loadConfigFromFlavor(String flavor, String prefixPath) {
    return _getConfigFromPubspecYaml(
      prefix: prefixPath,
      pathToPubspecYamlFile: utils.flavorConfigFile(flavor),
    );
  }

  /// Loads flutter launcher icons configs from given [filePath]
  static Config? loadConfigFromPath(String filePath, String prefixPath) {
    return _getConfigFromPubspecYaml(
      prefix: prefixPath,
      pathToPubspecYamlFile: filePath,
    );
  }

  /// Loads flutter launcher icons config from `pubspec.yaml` file
  static Config? loadConfigFromPubSpec(String prefix) {
    return _getConfigFromPubspecYaml(
      prefix: prefix,
      pathToPubspecYamlFile: constants.pubspecFilePath,
    );
  }

  static Config? _getConfigFromPubspecYaml({
    required String pathToPubspecYamlFile,
    required String prefix,
  }) {
    final configFile = File(path.join(prefix, pathToPubspecYamlFile));
    if (!configFile.existsSync()) {
      return null;
    }
    final configContent = configFile.readAsStringSync();
    try {
      return yaml.checkedYamlDecode<Config?>(configContent, (
        Map<dynamic, dynamic>? json,
      ) {
        if (json != null) {
          // if we have flutter_icons configuration ...
          if (json['flutter_icons'] != null) {
            FLILogger.legacyWarning(
              'flutter_icons has been deprecated '
              'please use flutter_launcher_icons instead in your yaml files',
            );
            return Config.fromJson(json['flutter_icons']);
          }
          // if we have flutter_launcher_icons configuration ...
          if (json['flutter_launcher_icons'] != null) {
            return Config.fromJson(json['flutter_launcher_icons']);
          }
        }
        return null;
      }, allowNull: true);
    } on yaml.ParsedYamlException catch (e) {
      throw InvalidConfigException(e.formattedMessage);
    } catch (e) {
      rethrow;
    }
  }

  /// Generic image_path
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Tri-state toggle for the Android platform (disabled / enabled / named).
  @PlatformToggleConverter()
  final PlatformToggle android;

  /// Tri-state toggle for the iOS platform (disabled / enabled / named).
  @PlatformToggleConverter()
  final PlatformToggle ios;

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
  final int adaptiveIconForegroundInset;

  /// android adaptive_icon_background image
  @JsonKey(name: 'adaptive_icon_background')
  final String? adaptiveIconBackground;

  /// android adaptive_icon_monochrome image
  @JsonKey(name: 'adaptive_icon_monochrome')
  final String? adaptiveIconMonochrome;

  /// Android `min_sdk_android` as supplied by the user, or `null` when
  /// omitted.
  ///
  /// **This is the raw user value, not the effective resolved value.** Use
  /// `android.resolveMinSdkAndroid(...)` (in `lib/android.dart`) to get the
  /// effective integer (explicit → autodetect from `build.gradle[.kts]` →
  /// [constants.androidDefaultAndroidMinSDK] with a warning).
  @JsonKey(name: 'min_sdk_android')
  final int? minSdkAndroid;

  /// When `true`, the generated `mipmap-xxxhdpi/<icon>.png` is copied into
  /// the same flavor's `drawable/` folder under the same filename.
  ///
  /// Defaults to [defaultCopyMipmapXxxhdpiToDrawable] (`false`). Useful
  /// when notification icons or other XML resources need to reference the
  /// launcher icon as a drawable. Has no effect when Android icon
  /// generation is disabled.
  @JsonKey(name: 'copy_mipmap_xxxhdpi_to_drawable')
  final bool copyMipmapXxxhdpiToDrawable;

  /// IOS remove_alpha_ios
  @JsonKey(name: 'remove_alpha_ios')
  final bool removeAlphaIOS;

  /// IOS desaturate_tinted_to_grayscale
  @JsonKey(name: 'desaturate_tinted_to_grayscale_ios')
  final bool desaturateTintedToGrayscaleIOS;

  /// Generic hex background color used as the default for every platform's
  /// letter-box bars (upstream #214). Falls through to [backgroundColorIOS]
  /// and `web.background_color` when those aren't set explicitly; also
  /// enables letter-boxing for the Android non-adaptive mipmap path
  /// (which has no platform-specific background color of its own).
  /// Accepts `#RRGGBB` / `#RRGGBBAA`. Null → keep legacy squish where no
  /// platform-specific fallback exists.
  @JsonKey(name: 'background_color')
  final String? backgroundColor;

  /// IOS background_color_ios. Explicit value wins over [backgroundColor];
  /// when both are unset, defaults to [defaultBackgroundColorIOS] (#FFFFFF).
  @JsonKey(name: 'background_color_ios')
  final String backgroundColorIOS;

  /// Web platform config
  @JsonKey(name: 'web')
  final WebConfig? webConfig;

  /// Windows platform config
  @JsonKey(name: 'windows')
  final WindowsConfig? windowsConfig;

  /// MacOS platform config
  @JsonKey(name: 'macos')
  final MacOSConfig? macOSConfig;

  /// Creates [Config] icons from [json].
  ///
  /// This is implemented in terms of [Config.fromPartial] / [PartialConfig]:
  /// the JSON is first parsed into a [PartialConfig] (no defaults applied),
  /// then merged through [Config.fromPartial]. This preserves the original
  /// "validate immediately" behavior while sharing one schema definition.
  factory Config.fromJson(Map json) =>
      Config.fromPartial(PartialConfig.fromJson(json));

  /// whether or not there is configuration for adaptive icons for android
  bool get hasAndroidAdaptiveConfig =>
      hasAndroidConfig &&
      adaptiveIconForeground != null &&
      adaptiveIconBackground != null;

  /// whether or not there is configuration for monochrome icons for android
  bool get hasAndroidAdaptiveMonochromeConfig {
    return hasAndroidConfig && adaptiveIconMonochrome != null;
  }

  /// Checks if contains any platform config
  bool get hasPlatformConfig {
    return ios.isEnabled ||
        android.isEnabled ||
        webConfig != null ||
        windowsConfig != null ||
        macOSConfig != null;
  }

  /// Whether or not configuration for generating Web icons exist
  bool get hasWebConfig => webConfig != null;

  /// Whether or not configuration for generating Windows icons exist
  bool get hasWindowsConfig => windowsConfig != null;

  /// Whether or not configuration for generating MacOS icons exists
  bool get hasMacOSConfig => macOSConfig != null;

  /// Check to see if specified Android config is a string or bool
  /// String - Generate new launcher icon with the string specified
  /// bool - override the default flutter project icon
  bool get isCustomAndroidFile => android.isCustom;

  /// Custom Android icon name when [isCustomAndroidFile] is true.
  ///
  /// Returns an empty string when not custom (callers should gate on
  /// [isCustomAndroidFile] first).
  String get androidIconName => android.customIconName ?? '';

  /// Custom iOS icon name when the user supplied a string for `ios:`.
  ///
  /// Returns an empty string when not custom (callers should gate on
  /// [isCustomIOSFile] first).
  String get iosIconName => ios.customIconName ?? '';

  /// Whether the user supplied a custom string for `ios:`.
  bool get isCustomIOSFile => ios.isCustom;

  /// if we are needing a new Android icon
  bool get hasAndroidConfig => android.isEnabled;

  /// if we are needing a new iOS icon
  bool get hasIOSConfig => ios.isEnabled;

  /// Method for the retrieval of the Android icon path
  /// If image_path_android is found, this will be prioritised over the image_path
  /// value.
  String? getImagePathAndroid() => imagePathAndroid ?? imagePath;

  /// get the image path for IOS
  String? getImagePathIOS() => imagePathIOS ?? imagePath;

  /// Converts config to [Map]
  Map<String, dynamic> toJson() => _$ConfigToJson(this);

  @override
  String toString() => 'FlutterLauncherIconsConfig: ${toJson()}';
}
