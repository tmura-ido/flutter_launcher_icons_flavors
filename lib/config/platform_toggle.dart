import 'package:json_annotation/json_annotation.dart';

/// A tri-state toggle modeling the YAML/JSON value of `android` / `ios`
/// configuration keys, which historically accept a `bool` or a `String`.
///
/// - A `bool false` (or absence / `null`) means the platform is disabled.
/// - A `bool true` means the platform is enabled with the default icon name.
/// - A non-empty `String` means the platform is enabled with a custom icon
///   name (e.g. `"ic_launcher_dev"`), and the existing default icon is kept.
class PlatformToggle {
  const PlatformToggle._(this._kind, this._iconName);

  /// Disabled — no icons will be generated for this platform.
  factory PlatformToggle.disabled() =>
      const PlatformToggle._(_PlatformToggleKind.disabled, null);

  /// Enabled with the default icon name. The existing icon is overwritten.
  factory PlatformToggle.enabled() =>
      const PlatformToggle._(_PlatformToggleKind.enabled, null);

  /// Enabled with a custom icon name. The existing icon is kept and a new
  /// icon with the given name is added.
  factory PlatformToggle.named(String iconName) {
    if (iconName.isEmpty) {
      throw ArgumentError.value(iconName, 'iconName', 'must not be empty');
    }
    return PlatformToggle._(_PlatformToggleKind.named, iconName);
  }

  final _PlatformToggleKind _kind;
  final String? _iconName;

  /// Whether this platform should have icons generated.
  bool get isEnabled => _kind != _PlatformToggleKind.disabled;

  /// Whether the user provided a custom icon name (and thus the existing
  /// default icon should be preserved).
  bool get isCustom => _kind == _PlatformToggleKind.named;

  /// The custom icon name if [isCustom], otherwise `null`.
  String? get customIconName => _iconName;

  /// Returns the JSON-friendly serialized form: `false`, `true`, or a
  /// `String` for custom names. This mirrors the input grammar accepted by
  /// [PlatformToggleConverter].
  Object toJson() {
    switch (_kind) {
      case _PlatformToggleKind.disabled:
        return false;
      case _PlatformToggleKind.enabled:
        return true;
      case _PlatformToggleKind.named:
        return _iconName!;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PlatformToggle &&
      other._kind == _kind &&
      other._iconName == _iconName;

  @override
  int get hashCode => Object.hash(_kind, _iconName);

  @override
  String toString() => 'PlatformToggle(${toJson()})';
}

enum _PlatformToggleKind { disabled, enabled, named }

/// `JsonConverter` for [PlatformToggle] that accepts the legacy bool-or-string
/// YAML grammar.
///
/// Accepted inputs:
/// - `null` or `false` → [PlatformToggle.disabled]
/// - `true` → [PlatformToggle.enabled]
/// - non-empty `String` → [PlatformToggle.named]
///
/// Anything else (numbers, lists, maps, empty strings) throws.
class PlatformToggleConverter
    implements JsonConverter<PlatformToggle, Object?> {
  /// Creates a converter instance.
  const PlatformToggleConverter();

  @override
  PlatformToggle fromJson(Object? json) {
    if (json == null || json == false) {
      return PlatformToggle.disabled();
    }
    if (json == true) {
      return PlatformToggle.enabled();
    }
    if (json is String) {
      if (json.isEmpty) {
        throw ArgumentError.value(
          json,
          'PlatformToggle',
          'icon name must not be empty',
        );
      }
      return PlatformToggle.named(json);
    }
    throw ArgumentError.value(
      json,
      'PlatformToggle',
      'expected bool, non-empty String, or null',
    );
  }

  @override
  Object toJson(PlatformToggle object) => object.toJson();
}

/// Nullable variant of [PlatformToggleConverter].
///
/// Unlike [PlatformToggleConverter], this converter preserves the
/// "user omitted" vs. "user wrote `false`" distinction:
///
/// - `null` (i.e. key absent or explicit `null`) → `null`
/// - `false` → [PlatformToggle.disabled]
/// - `true` → [PlatformToggle.enabled]
/// - non-empty `String` → [PlatformToggle.named]
///
/// Used by `PartialConfig` whose android/ios fields are intentionally
/// nullable to support later config-merge semantics. `Config` continues
/// to use the strict [PlatformToggleConverter].
class NullablePlatformToggleConverter
    implements JsonConverter<PlatformToggle?, Object?> {
  /// Creates a converter instance.
  const NullablePlatformToggleConverter();

  @override
  PlatformToggle? fromJson(Object? json) {
    if (json == null) {
      return null;
    }
    return const PlatformToggleConverter().fromJson(json);
  }

  @override
  Object? toJson(PlatformToggle? object) => object?.toJson();
}
