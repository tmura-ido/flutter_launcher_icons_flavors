// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavors_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlavorsFile _$FlavorsFileFromJson(Map json) =>
    $checkedCreate('FlavorsFile', json, ($checkedConvert) {
      final val = FlavorsFile(
        version: $checkedConvert('version', (v) => (v as num).toInt()),
        defaults: $checkedConvert(
          'defaults',
          (v) => v == null ? null : PartialConfig.fromJson(v as Map),
        ),
        flavors: $checkedConvert(
          'flavors',
          (v) => (v as Map).map(
            (k, e) => MapEntry(k as String, PartialConfig.fromJson(e as Map)),
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FlavorsFileToJson(FlavorsFile instance) =>
    <String, dynamic>{
      'version': instance.version,
      'defaults': ?instance.defaults,
      'flavors': instance.flavors,
    };
