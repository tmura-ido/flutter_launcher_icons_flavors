// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{
  'flavor': instance.flavor,
  'xcodeproj_path': instance.xcodeprojPath,
  'ios_legacy_sizes': instance.iosLegacySizes,
  'ios_single_size': instance.iosSingleSize,
  'optimize_png': instance.optimizePng,
  'ios_disable_liquid_glass': instance.iosDisableLiquidGlass,
  'non_square_image_ok': instance.nonSquareImageOk,
  'linux': instance.linuxConfig?.toJson(),
  'ios_alternate_icons': instance.iosAlternateIcons?.toJson(),
  'badge': instance.badge?.toJson(),
  'image_path': instance.imagePath,
  'android': const PlatformToggleConverter().toJson(instance.android),
  'ios': const PlatformToggleConverter().toJson(instance.ios),
  'image_path_android': instance.imagePathAndroid,
  'image_path_ios': instance.imagePathIOS,
  'image_path_ios_dark_transparent': instance.imagePathIOSDarkTransparent,
  'image_path_ios_tinted_grayscale': instance.imagePathIOSTintedGrayscale,
  'adaptive_icon_foreground': instance.adaptiveIconForeground,
  'adaptive_icon_foreground_inset': instance.adaptiveIconForegroundInset,
  'adaptive_icon_background': instance.adaptiveIconBackground,
  'adaptive_icon_monochrome': instance.adaptiveIconMonochrome,
  'min_sdk_android': instance.minSdkAndroid,
  'copy_mipmap_xxxhdpi_to_drawable': instance.copyMipmapXxxhdpiToDrawable,
  'remove_alpha_ios': instance.removeAlphaIOS,
  'desaturate_tinted_to_grayscale_ios': instance.desaturateTintedToGrayscaleIOS,
  'background_color': instance.backgroundColor,
  'background_color_ios': instance.backgroundColorIOS,
  'web': instance.webConfig?.toJson(),
  'windows': instance.windowsConfig?.toJson(),
  'macos': instance.macOSConfig?.toJson(),
};
