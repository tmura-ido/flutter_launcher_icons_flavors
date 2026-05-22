// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'partial_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PartialConfig _$PartialConfigFromJson(Map json) => $checkedCreate(
  'PartialConfig',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'flavor',
        'xcodeproj_path',
        'ios_legacy_sizes',
        'ios_single_size',
        'optimize_png',
        'ios_disable_liquid_glass',
        'non_square_image_ok',
        'image_path',
        'android',
        'ios',
        'image_path_android',
        'image_path_ios',
        'image_path_ios_dark_transparent',
        'image_path_ios_tinted_grayscale',
        'adaptive_icon_foreground',
        'adaptive_icon_foreground_inset',
        'adaptive_icon_background',
        'adaptive_icon_monochrome',
        'min_sdk_android',
        'copy_mipmap_xxxhdpi_to_drawable',
        'remove_alpha_ios',
        'desaturate_tinted_to_grayscale_ios',
        'background_color',
        'background_color_ios',
        'web',
        'windows',
        'macos',
        'linux',
        'ios_alternate_icons',
        'badge',
      ],
    );
    final val = PartialConfig(
      imagePath: $checkedConvert('image_path', (v) => v as String?),
      android: $checkedConvert(
        'android',
        (v) => const NullablePlatformToggleConverter().fromJson(v),
      ),
      ios: $checkedConvert(
        'ios',
        (v) => const NullablePlatformToggleConverter().fromJson(v),
      ),
      imagePathAndroid: $checkedConvert(
        'image_path_android',
        (v) => v as String?,
      ),
      imagePathIOS: $checkedConvert('image_path_ios', (v) => v as String?),
      imagePathIOSDarkTransparent: $checkedConvert(
        'image_path_ios_dark_transparent',
        (v) => v as String?,
      ),
      imagePathIOSTintedGrayscale: $checkedConvert(
        'image_path_ios_tinted_grayscale',
        (v) => v as String?,
      ),
      adaptiveIconForeground: $checkedConvert(
        'adaptive_icon_foreground',
        (v) => v as String?,
      ),
      adaptiveIconForegroundInset: $checkedConvert(
        'adaptive_icon_foreground_inset',
        (v) => (v as num?)?.toInt(),
      ),
      adaptiveIconBackground: $checkedConvert(
        'adaptive_icon_background',
        (v) => v as String?,
      ),
      adaptiveIconMonochrome: $checkedConvert(
        'adaptive_icon_monochrome',
        (v) => v as String?,
      ),
      minSdkAndroid: $checkedConvert(
        'min_sdk_android',
        (v) => (v as num?)?.toInt(),
      ),
      copyMipmapXxxhdpiToDrawable: $checkedConvert(
        'copy_mipmap_xxxhdpi_to_drawable',
        (v) => v as bool?,
      ),
      removeAlphaIOS: $checkedConvert('remove_alpha_ios', (v) => v as bool?),
      desaturateTintedToGrayscaleIOS: $checkedConvert(
        'desaturate_tinted_to_grayscale_ios',
        (v) => v as bool?,
      ),
      backgroundColor: $checkedConvert('background_color', (v) => v as String?),
      backgroundColorIOS: $checkedConvert(
        'background_color_ios',
        (v) => v as String?,
      ),
      webConfig: $checkedConvert(
        'web',
        (v) => v == null ? null : WebConfig.fromJson(v as Map),
      ),
      windowsConfig: $checkedConvert(
        'windows',
        (v) => v == null ? null : WindowsConfig.fromJson(v as Map),
      ),
      macOSConfig: $checkedConvert(
        'macos',
        (v) => v == null ? null : MacOSConfig.fromJson(v as Map),
      ),
      flavor: $checkedConvert('flavor', (v) => v as String?),
      xcodeprojPath: $checkedConvert('xcodeproj_path', (v) => v as String?),
      iosLegacySizes: $checkedConvert('ios_legacy_sizes', (v) => v as bool?),
      iosSingleSize: $checkedConvert('ios_single_size', (v) => v as bool?),
      optimizePng: $checkedConvert('optimize_png', (v) => v as bool?),
      iosDisableLiquidGlass: $checkedConvert(
        'ios_disable_liquid_glass',
        (v) => v as bool?,
      ),
      nonSquareImageOk: $checkedConvert(
        'non_square_image_ok',
        (v) => v as bool?,
      ),
      linuxConfig: $checkedConvert(
        'linux',
        (v) => v == null ? null : LinuxConfig.fromJson(v as Map),
      ),
      iosAlternateIcons: $checkedConvert(
        'ios_alternate_icons',
        (v) => v == null ? null : IosAlternateIconsConfig.fromJson(v as Map),
      ),
      badge: $checkedConvert(
        'badge',
        (v) => v == null ? null : BadgeConfig.fromJson(v as Map),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'imagePath': 'image_path',
    'imagePathAndroid': 'image_path_android',
    'imagePathIOS': 'image_path_ios',
    'imagePathIOSDarkTransparent': 'image_path_ios_dark_transparent',
    'imagePathIOSTintedGrayscale': 'image_path_ios_tinted_grayscale',
    'adaptiveIconForeground': 'adaptive_icon_foreground',
    'adaptiveIconForegroundInset': 'adaptive_icon_foreground_inset',
    'adaptiveIconBackground': 'adaptive_icon_background',
    'adaptiveIconMonochrome': 'adaptive_icon_monochrome',
    'minSdkAndroid': 'min_sdk_android',
    'copyMipmapXxxhdpiToDrawable': 'copy_mipmap_xxxhdpi_to_drawable',
    'removeAlphaIOS': 'remove_alpha_ios',
    'desaturateTintedToGrayscaleIOS': 'desaturate_tinted_to_grayscale_ios',
    'backgroundColor': 'background_color',
    'backgroundColorIOS': 'background_color_ios',
    'webConfig': 'web',
    'windowsConfig': 'windows',
    'macOSConfig': 'macos',
    'xcodeprojPath': 'xcodeproj_path',
    'iosLegacySizes': 'ios_legacy_sizes',
    'iosSingleSize': 'ios_single_size',
    'optimizePng': 'optimize_png',
    'iosDisableLiquidGlass': 'ios_disable_liquid_glass',
    'nonSquareImageOk': 'non_square_image_ok',
    'linuxConfig': 'linux',
    'iosAlternateIcons': 'ios_alternate_icons',
  },
);

Map<String, dynamic> _$PartialConfigToJson(
  PartialConfig instance,
) => <String, dynamic>{
  'flavor': ?instance.flavor,
  'xcodeproj_path': ?instance.xcodeprojPath,
  'ios_legacy_sizes': ?instance.iosLegacySizes,
  'ios_single_size': ?instance.iosSingleSize,
  'optimize_png': ?instance.optimizePng,
  'ios_disable_liquid_glass': ?instance.iosDisableLiquidGlass,
  'non_square_image_ok': ?instance.nonSquareImageOk,
  'image_path': ?instance.imagePath,
  'android': ?const NullablePlatformToggleConverter().toJson(instance.android),
  'ios': ?const NullablePlatformToggleConverter().toJson(instance.ios),
  'image_path_android': ?instance.imagePathAndroid,
  'image_path_ios': ?instance.imagePathIOS,
  'image_path_ios_dark_transparent': ?instance.imagePathIOSDarkTransparent,
  'image_path_ios_tinted_grayscale': ?instance.imagePathIOSTintedGrayscale,
  'adaptive_icon_foreground': ?instance.adaptiveIconForeground,
  'adaptive_icon_foreground_inset': ?instance.adaptiveIconForegroundInset,
  'adaptive_icon_background': ?instance.adaptiveIconBackground,
  'adaptive_icon_monochrome': ?instance.adaptiveIconMonochrome,
  'min_sdk_android': ?instance.minSdkAndroid,
  'copy_mipmap_xxxhdpi_to_drawable': ?instance.copyMipmapXxxhdpiToDrawable,
  'remove_alpha_ios': ?instance.removeAlphaIOS,
  'desaturate_tinted_to_grayscale_ios':
      ?instance.desaturateTintedToGrayscaleIOS,
  'background_color': ?instance.backgroundColor,
  'background_color_ios': ?instance.backgroundColorIOS,
  'web': ?instance.webConfig,
  'windows': ?instance.windowsConfig,
  'macos': ?instance.macOSConfig,
  'linux': ?instance.linuxConfig,
  'ios_alternate_icons': ?instance.iosAlternateIcons,
  'badge': ?instance.badge,
};
