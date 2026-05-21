import 'package:json_annotation/json_annotation.dart';

import 'tray_icon_config.dart';

part 'linux_config.g.dart';

/// The flutter_launcher_icons configuration set for Linux (upstream #666 /
/// #186 / #604 / #629).
///
/// Minimal v1: writes a single PNG to a known path under `linux/`. No
/// `.desktop` rewriting, no hicolor multi-size set, no Flatpak/Snap.
@JsonSerializable(anyMap: true, checked: true)
class LinuxConfig {
  /// Master switch.
  @JsonKey()
  final bool generate;

  /// Source image path. Falls back to the top-level `image_path` if unset.
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Single output PNG size. Default 256, covers most launcher use cases.
  @JsonKey(name: 'icon_size')
  final int iconSize;

  /// Output path for the generated PNG. Default
  /// `linux/runner/resources/app_icon.png`.
  @JsonKey(name: 'output_path')
  final String? outputPath;

  /// Optional Linux tray icon (upstream #510). Phase 1: config schema
  /// only; emission lands separately. Default sizes follow the
  /// StatusNotifierItem convention (22/24/32/48).
  @JsonKey(name: 'tray_icon')
  final TrayIconConfig? trayIcon;

  /// Creates an instance of [LinuxConfig].
  const LinuxConfig({
    this.generate = false,
    this.imagePath,
    this.iconSize = 256,
    this.outputPath,
    this.trayIcon,
  });

  /// Creates [LinuxConfig] from [json].
  factory LinuxConfig.fromJson(Map json) => _$LinuxConfigFromJson(json);

  /// Serializes to a JSON-friendly map.
  Map<String, dynamic> toJson() => _$LinuxConfigToJson(this);

  @override
  String toString() => 'LinuxConfig: ${toJson()}';
}
