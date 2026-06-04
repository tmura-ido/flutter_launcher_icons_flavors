import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart' as yaml;
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/flavors_file.dart';
import 'package:flutter_launcher_icons_flavors/config/macos_config.dart';
import 'package:flutter_launcher_icons_flavors/config/merge.dart';
import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:flutter_launcher_icons_flavors/config/web_config.dart';
import 'package:flutter_launcher_icons_flavors/config/windows_config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/utils/yaml_convert.dart';
import 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;

/// In-memory representation of a parsed and validated
/// `flutter_launcher_icons_flavors.yaml` file.
///
/// Per-flavor `PartialConfig`s are eagerly produced by deep-merging
/// `defaults` with each flavor's overrides at load time. Completeness
/// validation (the `Config.fromPartial` step) is deferred until
/// [resolve] so that one broken flavor doesn't block listing or
/// resolving the others.
class FlavorsConfig {
  FlavorsConfig._(this.source, this._partials);

  /// Absolute path of the source file (used in error messages).
  final String source;

  /// Map of flavor name → merged [PartialConfig]. Order matches the
  /// order keys appeared in the YAML source.
  final Map<String, PartialConfig> _partials;

  /// Iterable of all flavor names defined in the file.
  Iterable<String> get flavorNames => _partials.keys;

  /// Returns the merged [PartialConfig] for [name] without running the
  /// full `Config.fromPartial` validation.
  PartialConfig partialFor(String name) {
    final p = _partials[name];
    if (p == null) {
      throw UnknownFlavorException(name, _partials.keys.toList());
    }
    return p;
  }

  /// Resolves [name] into a fully-validated [Config].
  ///
  /// Throws [UnknownFlavorException] if [name] is not defined and
  /// [InvalidConfigException] if required fields are missing after the
  /// merge with `defaults`. The thrown `InvalidConfigException`'s
  /// message is rewritten so the offending field path is prefixed with
  /// `flavors.<name>.` — keeps error output unambiguous when the same
  /// project resolves multiple flavors.
  Config resolve(String name) {
    final partial = partialFor(name);
    try {
      return Config.fromPartial(partial);
    } on InvalidConfigException catch (e) {
      throw InvalidConfigException(_prefixFieldPath(e.message, name));
    }
  }

  /// Prepends `flavors.<name>.` to the leading "field:" segment of
  /// [message] (the convention `Config.fromPartial` uses, e.g.
  /// `image_path: Missing "image_path" or ...`). When [message] does
  /// not match that shape we fall back to a free-form prefix so the
  /// flavor is always surfaced.
  static String _prefixFieldPath(String? message, String flavor) {
    if (message == null || message.isEmpty) {
      return 'flavors.$flavor: invalid configuration';
    }
    final colon = message.indexOf(':');
    // Heuristic: only treat the prefix as a field path if it looks like
    // an identifier (no whitespace) — `Config.fromPartial` emits
    // `image_path: ...`, `image_path / image_path_android: ...`, etc.
    if (colon > 0) {
      final maybePath = message.substring(0, colon);
      final rest = message.substring(colon);
      if (!maybePath.contains('\n')) {
        return 'flavors.$flavor.$maybePath$rest';
      }
    }
    return 'flavors.$flavor: $message';
  }

  /// Loads and validates a consolidated multi-flavor config file.
  ///
  /// Returns `null` when [filePath] does not exist. Throws
  /// [InvalidFlavorsFileException] for schema errors.
  ///
  /// [logger] receives a warning for any unknown top-level keys
  /// (forward-compat; the keys are otherwise ignored).
  static FlavorsConfig? load(String filePath, {required FLILogger logger}) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return null;
    }

    final content = file.readAsStringSync();

    // Parse raw YAML once so we can both warn about unknown top-level keys
    // and feed the same map into checked_yaml for typed parsing.
    final Map<String, dynamic> rawMap;
    try {
      rawMap = _parseYamlAsMap(content, filePath);
    } on InvalidFlavorsFileException {
      rethrow;
    }

    // Warn about unknown top-level keys (forward-compat).
    const knownTopLevel = {'version', 'defaults', 'flavors'};
    final unknownTop = rawMap.keys
        .where((k) => !knownTopLevel.contains(k))
        .toList();
    if (unknownTop.isNotEmpty) {
      logger.warn(
        'Unknown top-level key(s) in $filePath: ${unknownTop.join(', ')}. '
        'Ignoring (forward-compat).',
      );
    }

    // Typed parse with checked_yaml for nice line-numbered errors.
    final FlavorsFile parsed;
    try {
      parsed = yaml.checkedYamlDecode<FlavorsFile>(
        content,
        (json) => FlavorsFile.fromJson(json!),
      );
    } on yaml.ParsedYamlException catch (e) {
      throw InvalidFlavorsFileException(
        e.formattedMessage ?? e.message,
        path: filePath,
      );
    }

    _validateStructure(parsed, filePath: filePath, rawMap: rawMap);

    // Deep-merge defaults into each flavor.
    //
    // CRITICAL: we merge at the **raw YAML** layer (not via
    // PartialConfig.toJson) so that "user omitted a key" stays distinct
    // from "user set a key to null/false". A typed-object roundtrip would
    // collapse omissions into explicit defaults (e.g. WebConfig.generate
    // defaults to false in the constructor), causing flavor overrides to
    // wipe out keys they never touched.
    final rawDefaults = _asStringKeyedMap(rawMap['defaults']);
    final rawFlavors = _asStringKeyedMap(rawMap['flavors']) ?? const {};

    // Reject typos in nested platform-config blocks BEFORE merging, so we
    // can attribute them to either `defaults.<platform>.<bad>` or
    // `flavors.<name>.<platform>.<bad>`. This protection is scoped to the
    // consolidated multi-flavor loader; the legacy single-config path
    // (`Config.loadConfigFromPath` / `loadConfigFromPubSpec`) intentionally
    // stays permissive to preserve backward compatibility.
    if (rawDefaults != null) {
      _validateNestedPlatformKeys(
        rawDefaults,
        path: filePath,
        keyPathPrefix: 'defaults',
      );
    }
    for (final flavorName in parsed.flavors.keys) {
      final rawOverride = _asStringKeyedMap(rawFlavors[flavorName]);
      if (rawOverride != null) {
        _validateNestedPlatformKeys(
          rawOverride,
          path: filePath,
          flavor: flavorName,
          keyPathPrefix: 'flavors.$flavorName',
        );
      }
    }

    final partials = <String, PartialConfig>{};
    for (final flavorName in parsed.flavors.keys) {
      final rawOverride =
          _asStringKeyedMap(rawFlavors[flavorName]) ?? <String, dynamic>{};
      final mergedJson = deepMerge(
        rawDefaults ?? <String, dynamic>{},
        rawOverride,
      );
      try {
        partials[flavorName] = PartialConfig.fromJson(mergedJson);
      } on yaml.ParsedYamlException catch (e) {
        throw InvalidFlavorsFileException(
          e.formattedMessage ?? e.message,
          path: filePath,
          flavor: flavorName,
        );
      } on CheckedFromJsonException catch (e) {
        throw InvalidFlavorsFileException(
          e.message ?? 'invalid value',
          path: filePath,
          flavor: flavorName,
          keyPath: e.key,
        );
      }
    }

    return FlavorsConfig._(filePath, partials);
  }

  /// Recursively converts a raw YAML/JSON object into plain
  /// `Map<String, dynamic>` / `List` / scalar shapes so it can be safely
  /// fed into `deepMerge` and `PartialConfig.fromJson`.
  ///
  /// `package:yaml` yields `YamlMap` / `YamlList` instances with `dynamic`
  /// keys; this function flattens those into the JSON-shaped tree the
  /// rest of the pipeline expects.
  static Map<String, dynamic>? _asStringKeyedMap(Object? raw) =>
      yamlToPlainMap(raw);

  /// Parses [content] and returns the top-level map.
  static Map<String, dynamic> _parseYamlAsMap(String content, String path) {
    try {
      final decoded = yaml.checkedYamlDecode<Map<String, dynamic>>(content, (
        json,
      ) {
        if (json == null) {
          return <String, dynamic>{};
        }
        return Map<String, dynamic>.from(
          json.map((k, v) => MapEntry(k.toString(), v)),
        );
      });
      return decoded;
    } on yaml.ParsedYamlException catch (e) {
      throw InvalidFlavorsFileException(
        e.formattedMessage ?? e.message,
        path: path,
      );
    }
  }

  /// Structural validation: version, flavor names, no duplicates, etc.
  ///
  /// `checked_yaml` already verifies the shape (required `version`,
  /// `flavors` is a map, etc.); this layer enforces business rules.
  static void _validateStructure(
    FlavorsFile parsed, {
    required String filePath,
    required Map<String, dynamic> rawMap,
  }) {
    if (parsed.version != 1) {
      throw InvalidFlavorsFileException(
        'Unsupported version: ${parsed.version}. '
        'Only version 1 is supported in this release.',
        path: filePath,
        keyPath: 'version',
      );
    }

    if (parsed.flavors.isEmpty) {
      throw InvalidFlavorsFileException(
        '`flavors` is empty. At least one flavor must be defined.',
        path: filePath,
        keyPath: 'flavors',
      );
    }

    final namePattern = RegExp(constants.flavorNamePattern);
    for (final name in parsed.flavors.keys) {
      if (name.isEmpty) {
        throw InvalidFlavorsFileException(
          'Empty flavor name is not allowed.',
          path: filePath,
          keyPath: 'flavors',
        );
      }
      if (name == '.' || name == '..') {
        throw InvalidFlavorsFileException(
          'Flavor name "$name" is reserved.',
          path: filePath,
          flavor: name,
          keyPath: 'flavors.$name',
        );
      }
      if (name.contains('/') || name.contains('\\')) {
        throw InvalidFlavorsFileException(
          'Flavor name "$name" must not contain path separators.',
          path: filePath,
          flavor: name,
          keyPath: 'flavors.$name',
        );
      }
      if (!namePattern.hasMatch(name)) {
        throw InvalidFlavorsFileException(
          'Invalid flavor name "$name". '
          'Names must match ${constants.flavorNamePattern}.',
          path: filePath,
          flavor: name,
          keyPath: 'flavors.$name',
        );
      }
    }

    // Duplicate flavor name detection lives in the YAML parser, not
    // here: `package:yaml` (used via `checked_yaml`) throws
    // `YamlException: Duplicate mapping key` at parse time, which we
    // wrap into `InvalidFlavorsFileException` in `load`. A second pass
    // over the raw map is unnecessary and was removed as dead code.
  }

  /// Allowed key sets for the nested platform-config blocks, derived
  /// directly from each platform config class instead of being
  /// hand-maintained — so the allow-list can never drift from the schema
  /// the single-config path actually accepts.
  ///
  /// Each class's generated `toJson()` emits every `@JsonKey` name
  /// unconditionally (null-valued fields included), so a
  /// default-constructed instance enumerates the platform's full key
  /// surface. When a config class gains or renames a key, it flows
  /// through here on the next build with no manual edit. This is the
  /// invariant pinned by
  /// `test/permutations/platform_subconfig_keys_test.dart`.
  ///
  /// `linux` is intentionally absent: like the single-config path, the
  /// consolidated loader leaves `linux` blocks unchecked (the "control
  /// group" in that same test). Adding `LinuxConfig` here would start
  /// validating them.
  static final Map<String, Set<String>> _allowedNestedKeys = {
    'web': _platformKeys(const WebConfig().toJson()),
    'windows': _platformKeys(const WindowsConfig().toJson()),
    'macos': _platformKeys(const MacOSConfig().toJson()),
  };

  /// Collects the serialized key names of a platform config's `toJson()`
  /// map as a `Set<String>`. (`WindowsConfig.toJson()` is typed as a bare
  /// `Map`, so keys are normalized to `String`.)
  static Set<String> _platformKeys(Map json) =>
      json.keys.map((k) => k.toString()).toSet();

  /// Rejects unknown keys inside the `web` / `windows` / `macos` blocks
  /// of [block] (a raw YAML map representing either `defaults` or a
  /// flavor's overrides). The top-level `PartialConfig` keys are
  /// already covered by `disallowUnrecognizedKeys: true` on its
  /// `@JsonSerializable` annotation; this complements that for the
  /// nested platform sub-blocks (which are intentionally permissive in
  /// the legacy single-config path).
  static void _validateNestedPlatformKeys(
    Map<String, dynamic> block, {
    required String path,
    required String keyPathPrefix,
    String? flavor,
  }) {
    for (final entry in _allowedNestedKeys.entries) {
      final platform = entry.key;
      final allowed = entry.value;
      final raw = block[platform];
      if (raw is! Map) {
        continue;
      }
      for (final k in raw.keys) {
        final ks = k.toString();
        if (!allowed.contains(ks)) {
          throw InvalidFlavorsFileException(
            'Unknown key "$ks" in $platform block. '
            'Allowed: ${allowed.join(', ')}.',
            path: path,
            flavor: flavor,
            keyPath: '$keyPathPrefix.$platform.$ks',
          );
        }
      }
    }
  }
}
