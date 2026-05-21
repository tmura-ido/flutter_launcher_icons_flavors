// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebConfig _$WebConfigFromJson(Map json) => $checkedCreate(
  'WebConfig',
  json,
  ($checkedConvert) {
    final val = WebConfig(
      generate: $checkedConvert('generate', (v) => v as bool? ?? false),
      imagePath: $checkedConvert('image_path', (v) => v as String?),
      backgroundColor: $checkedConvert('background_color', (v) => v as String?),
      themeColor: $checkedConvert('theme_color', (v) => v as String?),
      outputPath: $checkedConvert('output_path', (v) => v as String?),
      generateFavicon:
          $checkedConvert('generate_favicon', (v) => v as bool? ?? true),
      faviconPath: $checkedConvert('favicon_path', (v) => v as String?),
      faviconSize:
          $checkedConvert('favicon_size', (v) => (v as num?)?.toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'imagePath': 'image_path',
    'backgroundColor': 'background_color',
    'themeColor': 'theme_color',
    'outputPath': 'output_path',
    'generateFavicon': 'generate_favicon',
    'faviconPath': 'favicon_path',
    'faviconSize': 'favicon_size',
  },
);

Map<String, dynamic> _$WebConfigToJson(WebConfig instance) => <String, dynamic>{
  'generate': instance.generate,
  'image_path': instance.imagePath,
  'background_color': instance.backgroundColor,
  'theme_color': instance.themeColor,
  'output_path': instance.outputPath,
  'generate_favicon': instance.generateFavicon,
  'favicon_path': instance.faviconPath,
  'favicon_size': instance.faviconSize,
};
