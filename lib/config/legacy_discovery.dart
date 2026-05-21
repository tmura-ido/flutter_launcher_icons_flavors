/// Shared discovery for legacy `flutter_launcher_icons-<flavor>.yaml` files.
///
/// Several modules need the same operation — list every legacy per-flavor
/// config in a directory, optionally extracting the flavor name from the
/// filename. Centralizing it here keeps the regex (declared once in
/// `constants.legacyFlavorConfigFilePattern`), the deterministic sort order
/// and the `Directory` existence guard in a single place.
library;

import 'dart:io';

import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:path/path.dart' as p;

/// A single discovered legacy file.
class LegacyFlavorFile {
  /// Creates a [LegacyFlavorFile].
  const LegacyFlavorFile({required this.flavor, required this.path});

  /// The flavor name captured from the filename
  /// (`flutter_launcher_icons-<flavor>.yaml`).
  final String flavor;

  /// The absolute or relative path to the file, exactly as returned by
  /// [Directory.listSync].
  final String path;
}

/// Directory segments skipped during the recursive legacy-file scan.
/// Matches the skip set in `getFlavors` (lib/main.dart) for consistency.
const Set<String> _skipScanSegments = {
  '.dart_tool',
  'build',
  '.git',
  'node_modules',
  '.gradle',
  '.idea',
};

/// Returns every legacy `flutter_launcher_icons-<flavor>.yaml` file under
/// [prefixPath] (recursively, skipping noise like `.dart_tool`/`build`),
/// sorted by flavor name (ascending) for deterministic output across
/// filesystems whose directory iteration order is unstable.
///
/// Returns an empty list — never throws — when [prefixPath] does not exist.
List<LegacyFlavorFile> findLegacyFlavorFiles(String prefixPath) {
  final dir = Directory(prefixPath);
  if (!dir.existsSync()) {
    return const <LegacyFlavorFile>[];
  }
  final pattern = RegExp(constants.legacyFlavorConfigFilePattern);
  final out = <LegacyFlavorFile>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final rel = p.relative(entity.path, from: prefixPath);
    final segs = p.split(rel);
    if (segs.any(_skipScanSegments.contains)) {
      continue;
    }
    final match = pattern.firstMatch(p.basename(entity.path));
    if (match == null) {
      continue;
    }
    out.add(LegacyFlavorFile(flavor: match.group(1)!, path: entity.path));
  }
  out.sort((a, b) => a.flavor.compareTo(b.flavor));
  return out;
}

/// Convenience wrapper around [findLegacyFlavorFiles] that returns just the
/// file paths. Most callers only need this shape.
List<String> findLegacyFlavorPaths(String prefixPath) =>
    findLegacyFlavorFiles(prefixPath).map((f) => f.path).toList();
