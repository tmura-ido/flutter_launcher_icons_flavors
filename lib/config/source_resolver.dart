import 'dart:io';

import 'package:flutter_launcher_icons_flavors/config/legacy_discovery.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Identifies which configuration source `flutter_launcher_icons` is
/// reading from for a given run.
enum ConfigSourceKind {
  /// User passed `--file <path>`.
  explicitFile,

  /// `flutter_launcher_icons_flavors.yaml` was found in the prefix dir.
  consolidatedFlavors,

  /// One or more legacy `flutter_launcher_icons-<flavor>.yaml` files.
  legacyFlavors,

  /// `flutter_launcher_icons.yaml` (single-config).
  singleFile,

  /// Inline `flutter_launcher_icons:` (or deprecated `flutter_icons:`)
  /// in `pubspec.yaml`.
  pubspecInline,
}

/// The outcome of [resolveSource]: which source was chosen and what
/// (if anything) was ignored along the way.
class ResolvedSource {
  /// Creates a [ResolvedSource].
  const ResolvedSource({
    required this.kind,
    this.path,
    this.ignoredLegacy = const <String>[],
    this.isMultiFlavor = false,
  });

  /// Selected source kind.
  final ConfigSourceKind kind;

  /// Filesystem path of the chosen file. `null` for [ConfigSourceKind.pubspecInline].
  final String? path;

  /// Legacy `flutter_launcher_icons-*.yaml` files that coexisted with the
  /// chosen source. Only populated for [ConfigSourceKind.consolidatedFlavors].
  /// Phase 4 may escalate this to an error via `--strict`.
  final List<String> ignoredLegacy;

  /// Whether the chosen file is a multi-flavor file (has a top-level
  /// `flavors:` key). Set by [resolveSource] for both
  /// [ConfigSourceKind.consolidatedFlavors] and [ConfigSourceKind.explicitFile]
  /// (after sniffing).
  final bool isMultiFlavor;
}

/// Resolves which config source to use, following documented precedence:
///
/// 1. `--file <path>` (explicit; hard error if missing).
/// 2. `<prefix>/flutter_launcher_icons_flavors.yaml`.
/// 3. Any `<prefix>/flutter_launcher_icons-*.yaml` (legacy multi-flavor).
/// 4. `<prefix>/flutter_launcher_icons.yaml` (single-config).
/// 5. `<prefix>/pubspec.yaml` with a `flutter_launcher_icons:` /
///    `flutter_icons:` block.
///
/// Throws [NoConfigFoundException] if none of the above exist.
ResolvedSource resolveSource({
  required String prefixPath,
  String? explicitFilePath,
  required FLILogger logger,
}) {
  // (1) Explicit --file wins. No fallback.
  if (explicitFilePath != null) {
    final resolved = _resolveExplicitPath(prefixPath, explicitFilePath);
    final file = File(resolved);
    if (!file.existsSync()) {
      throw NoConfigFoundException(
        'Config file not found: $resolved (passed via --file).',
      );
    }
    final isMulti = _sniffMultiFlavor(file);
    return ResolvedSource(
      kind: ConfigSourceKind.explicitFile,
      path: resolved,
      isMultiFlavor: isMulti,
    );
  }

  // (2) Consolidated multi-flavor file.
  final consolidatedPath = path.join(
    prefixPath,
    constants.consolidatedFlavorsFileName,
  );
  if (File(consolidatedPath).existsSync()) {
    final ignoredLegacy = findLegacyFlavorPaths(prefixPath);
    if (ignoredLegacy.isNotEmpty) {
      logger.warn(
        'Both $consolidatedPath and legacy '
        'flutter_launcher_icons-<flavor>.yaml file(s) were found:\n  '
        '${ignoredLegacy.join('\n  ')}\n'
        'The consolidated file wins; legacy files are ignored. '
        'Run `dart run flutter_launcher_icons_flavors migrate` to '
        'consolidate them (coming in 0.15.x), or delete the legacy '
        'files to silence this warning.',
      );
    }
    return ResolvedSource(
      kind: ConfigSourceKind.consolidatedFlavors,
      path: consolidatedPath,
      ignoredLegacy: ignoredLegacy,
      isMultiFlavor: true,
    );
  }

  // (3) Legacy multi-flavor.
  final legacyFiles = findLegacyFlavorPaths(prefixPath);
  if (legacyFiles.isNotEmpty) {
    logger.warn(
      'Found legacy flutter_launcher_icons-<flavor>.yaml file(s). '
      'Consider migrating to a single ${constants.consolidatedFlavorsFileName} '
      'file. (Migration tooling arrives in a later 0.15.x release.)',
    );
    return ResolvedSource(
      kind: ConfigSourceKind.legacyFlavors,
      path: prefixPath,
    );
  }

  // (4) Single-config file.
  final singlePath = path.join(prefixPath, constants.singleConfigFileName);
  if (File(singlePath).existsSync()) {
    return ResolvedSource(kind: ConfigSourceKind.singleFile, path: singlePath);
  }

  // (5) pubspec inline.
  final pubspecPath = path.join(prefixPath, constants.pubspecFilePath);
  if (File(pubspecPath).existsSync() && _pubspecHasInlineConfig(pubspecPath)) {
    return ResolvedSource(
      kind: ConfigSourceKind.pubspecInline,
      path: pubspecPath,
    );
  }

  // Last-ditch friendly message: if there are no configs at the prefix but
  // there are legacy-style files anywhere under it (e.g. in `config/`),
  // list them so the user knows what to point `--file` at (upstream #279).
  final discovered = findLegacyFlavorFiles(prefixPath);
  if (discovered.isNotEmpty) {
    final lines = discovered
        .map((f) => '  - ${f.path} (flavor: ${f.flavor})')
        .join('\n');
    throw NoConfigFoundException(
      'No base flutter_launcher_icons config found in $prefixPath, but '
      'discovered ${discovered.length} flavor config(s):\n$lines\n'
      'Re-run with `--file <path>` or move one of these to the project '
      'root, or pass `--flavor <name>` / `--all-flavors` if you have a '
      'consolidated config elsewhere.',
    );
  }

  throw const NoConfigFoundException(
    'No flutter_launcher_icons config found '
    '(checked flutter_launcher_icons_flavors.yaml, '
    'flutter_launcher_icons-<flavor>.yaml, flutter_launcher_icons.yaml, '
    'and pubspec.yaml). Use --file to point at a custom config.',
  );
}

/// Resolves [explicitFilePath] relative to [prefixPath] unless it is
/// already absolute.
String _resolveExplicitPath(String prefixPath, String explicitFilePath) {
  if (path.isAbsolute(explicitFilePath)) {
    return explicitFilePath;
  }
  return path.join(prefixPath, explicitFilePath);
}

/// Sniffs whether a YAML file has a top-level `flavors:` mapping (i.e.
/// is a consolidated multi-flavor file regardless of filename).
bool _sniffMultiFlavor(File file) {
  try {
    final doc = loadYaml(file.readAsStringSync());
    if (doc is YamlMap) {
      final flavors = doc['flavors'];
      return flavors is YamlMap;
    }
  } catch (_) {
    // If we can't parse it here, let downstream loaders surface the
    // real error.
  }
  return false;
}

/// Detects whether `pubspec.yaml` has an inline
/// `flutter_launcher_icons:` (or deprecated `flutter_icons:`) block.
bool _pubspecHasInlineConfig(String pubspecPath) {
  try {
    final doc = loadYaml(File(pubspecPath).readAsStringSync());
    if (doc is YamlMap) {
      return doc['flutter_launcher_icons'] != null ||
          doc['flutter_icons'] != null;
    }
  } catch (_) {
    // ignore
  }
  return false;
}
