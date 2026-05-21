import 'package:json_annotation/json_annotation.dart';

import 'tray_icon_config.dart';

part 'macos_config.g.dart';

/// The flutter_launcher_icons configuration set for MacOS
@JsonSerializable(anyMap: true, checked: true)
class MacOSConfig {
  /// Specifies whether to generate icons for macos
  @JsonKey()
  final bool generate;

  /// Image path for macos
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// When true, the macOS pipeline resizes the source to 824×824 and
  /// composites it onto a 1024×1024 transparent canvas before slicing,
  /// matching Apple's recommended effective-design area (upstream #655).
  @JsonKey()
  final bool padding;

  /// Optional source for the macOS dark-mode appearance variant
  /// (upstream #660). Falls back to [imagePath] if unset.
  @JsonKey(name: 'dark_image_path')
  final String? darkImagePath;

  /// Optional source for the macOS tinted appearance variant
  /// (upstream #660). Falls back to [imagePath] if unset.
  @JsonKey(name: 'tinted_image_path')
  final String? tintedImagePath;

  /// Optional macOS system-tray icon (upstream #510). Phase 1: config
  /// schema only; emission lands separately. The macOS writer refuses to
  /// default `template_image_path` to the colored launcher image.
  @JsonKey(name: 'tray_icon')
  final TrayIconConfig? trayIcon;

  /// Creates a instance of [MacOSConfig]
  const MacOSConfig({
    this.generate = false,
    this.imagePath,
    this.padding = false,
    this.darkImagePath,
    this.tintedImagePath,
    this.trayIcon,
  });

  /// Creates [MacOSConfig] from [json]
  factory MacOSConfig.fromJson(Map json) => _$MacOSConfigFromJson(json);

  /// Creates [Map] from [MacOSConfig]
  Map<String, dynamic> toJson() => _$MacOSConfigToJson(this);

  @override
  String toString() => '$runtimeType: ${toJson()}';
}
