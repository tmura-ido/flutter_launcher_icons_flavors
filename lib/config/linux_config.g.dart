// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linux_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinuxConfig _$LinuxConfigFromJson(Map json) => $checkedCreate(
  'LinuxConfig',
  json,
  ($checkedConvert) {
    final val = LinuxConfig(
      generate: $checkedConvert('generate', (v) => v as bool? ?? false),
      imagePath: $checkedConvert('image_path', (v) => v as String?),
      iconSize:
          $checkedConvert('icon_size', (v) => (v as num?)?.toInt() ?? 256),
      outputPath: $checkedConvert('output_path', (v) => v as String?),
      trayIcon: $checkedConvert(
        'tray_icon',
        (v) => v == null ? null : TrayIconConfig.fromJson(v as Map),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'imagePath': 'image_path',
    'iconSize': 'icon_size',
    'outputPath': 'output_path',
    'trayIcon': 'tray_icon',
  },
);

Map<String, dynamic> _$LinuxConfigToJson(LinuxConfig instance) =>
    <String, dynamic>{
      'generate': instance.generate,
      'image_path': instance.imagePath,
      'icon_size': instance.iconSize,
      'output_path': instance.outputPath,
      'tray_icon': instance.trayIcon?.toJson(),
    };
