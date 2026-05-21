import 'package:json_annotation/json_annotation.dart';

import 'tray_icon_config.dart';

part 'windows_config.g.dart';

/// The flutter_launcher_icons configuration set for Windows
@JsonSerializable(anyMap: true, checked: true)
class WindowsConfig {
  /// Specifies whether to generate icons for windows
  final bool generate;

  /// Image path for windows
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Size of the icon to generate
  @JsonKey(name: 'icon_size')
  final int? iconSize;

  /// Optional Windows system-tray icon (upstream #510). Phase 1: config
  /// schema only; emission lands separately.
  @JsonKey(name: 'tray_icon')
  final TrayIconConfig? trayIcon;

  /// Creates a instance of [WindowsConfig]
  const WindowsConfig({
    this.generate = false,
    this.imagePath,
    this.iconSize,
    this.trayIcon,
  });

  /// Creates [WindowsConfig] from [json]
  factory WindowsConfig.fromJson(Map json) => _$WindowsConfigFromJson(json);

  /// Creates [Map] from [WindowsConfig]
  Map toJson() => _$WindowsConfigToJson(this);

  @override
  String toString() => 'WindowsConfig: ${toJson()}';
}
