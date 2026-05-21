/// Configuration for iOS alternate app-icon sets (upstream #92, phase 1).
///
/// When [enabled] is true, every entry under [icons] produces a separate
/// `<name>.appiconset/` directory under `ios/Runner/Assets.xcassets/`,
/// each with its own slice pass and Contents.json. Info.plist patching
/// (`CFBundleAlternateIcons`) is **phase 2** — until that lands, the
/// user wires Info.plist by hand. See README §iOS specifics.
class IosAlternateIconsConfig {
  /// Master switch.
  final bool enabled;

  /// Map of alternate-icon name → image source paths.
  final Map<String, IosAlternateIconEntry> icons;

  /// Creates an [IosAlternateIconsConfig].
  const IosAlternateIconsConfig({
    this.enabled = false,
    this.icons = const {},
  });

  /// Parses from a JSON/YAML map.
  factory IosAlternateIconsConfig.fromJson(Map json) {
    final enabled = json['enabled'] == true;
    final iconsRaw = json['icons'];
    final out = <String, IosAlternateIconEntry>{};
    if (iconsRaw is Map) {
      iconsRaw.forEach((k, v) {
        if (k is String && v is Map) {
          out[k] = IosAlternateIconEntry.fromJson(v);
        }
      });
    }
    return IosAlternateIconsConfig(enabled: enabled, icons: out);
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'icons': icons.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// One alternate icon entry.
class IosAlternateIconEntry {
  /// Primary source PNG.
  final String? imagePath;

  /// iOS-18 dark variant (optional).
  final String? imagePathDarkTransparent;

  /// iOS-18 tinted variant (optional).
  final String? imagePathTintedGrayscale;

  /// Creates an [IosAlternateIconEntry].
  const IosAlternateIconEntry({
    this.imagePath,
    this.imagePathDarkTransparent,
    this.imagePathTintedGrayscale,
  });

  /// Parses from a JSON map.
  factory IosAlternateIconEntry.fromJson(Map json) => IosAlternateIconEntry(
        imagePath: json['image_path'] as String?,
        imagePathDarkTransparent:
            json['image_path_dark_transparent'] as String?,
        imagePathTintedGrayscale:
            json['image_path_tinted_grayscale'] as String?,
      );

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'image_path': imagePath,
        'image_path_dark_transparent': imagePathDarkTransparent,
        'image_path_tinted_grayscale': imagePathTintedGrayscale,
      };
}
