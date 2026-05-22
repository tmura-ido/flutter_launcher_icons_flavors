/// Shared tray-icon configuration shape (upstream #510, phase 1).
///
/// Each desktop platform's existing config block gains a `tray_icon`
/// sub-block. macOS requires a `template_image_path` (a monochrome
/// silhouette with alpha) — falling back to the colored launcher image is
/// explicitly refused because the result looks wrong.
///
/// Phase 1 (this issue) ships the **config schema** only. Writers land
/// alongside the platform-specific tray asset generators.
class TrayIconConfig {
  /// Source image for non-macOS tray icons. Falls back to the platform's
  /// existing `image_path` when null.
  final String? imagePath;

  /// macOS template image (monochrome silhouette with alpha). The macOS
  /// writer refuses to default this to the colored launcher image.
  final String? templateImagePath;

  /// Embedded sizes for the tray ICO (Windows), `imageset` 1x/2x (macOS),
  /// or per-size PNGs (Linux).
  final List<int> sizes;

  /// Output path. Defaults per platform:
  ///   Windows: `windows/runner/resources/tray.ico`
  ///   macOS:   `macos/Runner/Assets.xcassets/TrayIcon.imageset`
  ///   Linux:   `linux/runner/resources/tray/`
  final String? output;

  /// Creates a [TrayIconConfig].
  const TrayIconConfig({
    this.imagePath,
    this.templateImagePath,
    this.sizes = const [],
    this.output,
  });

  /// Parses from a JSON map.
  factory TrayIconConfig.fromJson(Map json) {
    final sizesRaw = json['sizes'];
    final sizes = <int>[];
    if (sizesRaw is List) {
      for (final v in sizesRaw) {
        if (v is num) sizes.add(v.toInt());
      }
    }
    return TrayIconConfig(
      imagePath: json['image_path'] as String?,
      templateImagePath: json['template_image_path'] as String?,
      sizes: sizes,
      output: json['output'] as String?,
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'image_path': imagePath,
    'template_image_path': templateImagePath,
    'sizes': sizes,
    'output': output,
  };
}
