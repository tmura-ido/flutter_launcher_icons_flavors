import 'package:flutter_launcher_icons_flavored/config/partial_config.dart';
import 'package:json_annotation/json_annotation.dart';

part 'flavors_file.g.dart';

/// Schema model for the consolidated multi-flavor config file
/// (`flutter_launcher_icons_flavors.yaml`).
///
/// Top-level layout:
///
/// ```yaml
/// version: 1
/// defaults: # optional
///   image_path: assets/icon.png
/// flavors:  # required, non-empty
///   dev:
///     android: true
///   prod:
///     android: ic_launcher
/// ```
///
/// Structural validation is deferred to [validate]; per-flavor completeness
/// validation is handled by `Config.fromPartial` at resolution time.
///
/// Note: [disallowUnrecognizedKeys] is **not** enabled here at the top
/// level — Phase 3 forwards-compat policy is to warn-and-ignore unknown
/// top-level keys (handled by the loader). Unknown keys *inside*
/// `defaults` or any flavor block flow into [PartialConfig], which has
/// `disallowUnrecognizedKeys: true` and will throw.
@JsonSerializable(anyMap: true, checked: true, includeIfNull: false)
class FlavorsFile {
  /// Creates a new [FlavorsFile].
  const FlavorsFile({
    required this.version,
    this.defaults,
    required this.flavors,
  });

  /// Schema version. Must be `1` for 0.15.x.
  final int version;

  /// Optional shared base merged into every flavor.
  final PartialConfig? defaults;

  /// Required non-empty map of flavor name → flavor-specific overrides.
  final Map<String, PartialConfig> flavors;

  /// Decodes from JSON / YAML map.
  factory FlavorsFile.fromJson(Map json) => _$FlavorsFileFromJson(json);

  /// Encodes to JSON.
  Map<String, dynamic> toJson() => _$FlavorsFileToJson(this);
}
