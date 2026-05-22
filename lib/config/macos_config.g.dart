// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macos_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MacOSConfig _$MacOSConfigFromJson(Map json) => $checkedCreate(
  'MacOSConfig',
  json,
  ($checkedConvert) {
    final val = MacOSConfig(
      generate: $checkedConvert('generate', (v) => v as bool? ?? false),
      imagePath: $checkedConvert('image_path', (v) => v as String?),
      padding: $checkedConvert('padding', (v) => v as bool? ?? false),
      darkImagePath: $checkedConvert('dark_image_path', (v) => v as String?),
      tintedImagePath: $checkedConvert(
        'tinted_image_path',
        (v) => v as String?,
      ),
      trayIcon: $checkedConvert(
        'tray_icon',
        (v) => v == null ? null : TrayIconConfig.fromJson(v as Map),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'imagePath': 'image_path',
    'darkImagePath': 'dark_image_path',
    'tintedImagePath': 'tinted_image_path',
    'trayIcon': 'tray_icon',
  },
);

Map<String, dynamic> _$MacOSConfigToJson(MacOSConfig instance) =>
    <String, dynamic>{
      'generate': instance.generate,
      'image_path': instance.imagePath,
      'padding': instance.padding,
      'dark_image_path': instance.darkImagePath,
      'tinted_image_path': instance.tintedImagePath,
      'tray_icon': instance.trayIcon,
    };
