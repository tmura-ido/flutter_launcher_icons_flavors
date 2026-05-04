import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_launcher_icons_flavored/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'yaml_emit.dart';

/// `migrate` subcommand — converts legacy
/// `flutter_launcher_icons-<flavor>.yaml` files into a single
/// `flutter_launcher_icons_flavors.yaml`.
///
/// Defaults are non-destructive:
///   * Each legacy file is copied to `<original>.bak` (kept even with
///     `--in-place`).
///   * Originals are left in place unless `--in-place` is passed.
///   * An existing target is never overwritten unless `--force` is
///     passed.
class MigrateCommand extends Command<int> {
  /// Creates the parser.
  MigrateCommand() {
    argParser
      ..addOption(
        'prefix',
        abbr: 'p',
        help: 'Project prefix path. Defaults to the current directory.',
        defaultsTo: '.',
      )
      ..addFlag(
        'dry-run',
        help: 'Print the would-be YAML to stdout; do not write any files.',
        negatable: false,
      )
      ..addFlag(
        'in-place',
        help:
            'After writing the consolidated file, delete the legacy '
            'originals. The .bak copies are retained.',
        negatable: false,
      )
      ..addFlag(
        'force',
        help: 'Overwrite an existing flutter_launcher_icons_flavors.yaml.',
        negatable: false,
      );
  }

  @override
  String get name => 'migrate';

  @override
  String get description =>
      'Migrate legacy per-flavor flutter_launcher_icons-<flavor>.yaml '
      'files into a single flutter_launcher_icons_flavors.yaml.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final prefix = results['prefix'] as String;
    final dryRun = results['dry-run'] as bool;
    final inPlace = results['in-place'] as bool;
    final force = results['force'] as bool;
    // Verbose flag isn't on `migrate`'s parser; use a non-verbose
    // logger purely to access the stderr-routing `error()` helper.
    final logger = FLILogger(false);

    // 1. Discover legacy files.
    final legacy = _discoverLegacyFiles(prefix);
    if (legacy.isEmpty) {
      stdout.writeln(
        'ℹ No legacy flutter_launcher_icons-<flavor>.yaml files found in '
        '$prefix. Nothing to migrate.',
      );
      return 0;
    }

    // 2. Target existence check (skipped on --dry-run because we're not
    //    writing anything).
    final targetPath = p.join(prefix, constants.consolidatedFlavorsFileName);
    if (!dryRun && File(targetPath).existsSync() && !force) {
      logger.error(
        '$targetPath already exists. Re-run with --force to overwrite, '
        'or move/delete the file first.',
      );
      return 64;
    }

    // 3. Parse each legacy file.
    final flavorBlocks = <String, Map<String, dynamic>>{};
    for (final entry in legacy) {
      try {
        final block = _parseLegacyFile(entry.path);
        flavorBlocks[entry.flavor] = block;
      } on _MigrateParseException catch (e) {
        logger.error('Failed to parse ${entry.path}: ${e.message}');
        return 64;
      } on Exception catch (e) {
        logger.error('Failed to read ${entry.path}: $e');
        return 1;
      }
    }

    // 4. Build the output document.
    final doc = <String, dynamic>{
      'version': 1,
      'defaults': <String, dynamic>{},
      'flavors': flavorBlocks,
    };
    final yamlOut = emitYaml(doc);

    // 5. Compute promotion candidates (keys with identical values across
    //    every flavor block).
    final candidates = _computePromotionCandidates(flavorBlocks);

    // 6. Output / write.
    if (dryRun) {
      stdout.write(yamlOut);
      _printCandidatesReport(candidates);
      return 0;
    }

    // Backup originals before any destructive step.
    for (final entry in legacy) {
      try {
        File(entry.path).copySync('${entry.path}.bak');
      } on Exception catch (e) {
        logger.error('Failed to back up ${entry.path}: $e');
        return 1;
      }
    }

    try {
      File(targetPath).writeAsStringSync(yamlOut);
    } on Exception catch (e) {
      logger.error('Failed to write $targetPath: $e');
      return 1;
    }

    if (inPlace) {
      for (final entry in legacy) {
        try {
          File(entry.path).deleteSync();
        } on Exception catch (e) {
          logger.warn('Could not delete ${entry.path}: $e');
        }
      }
    }

    stdout.writeln('✓ Wrote $targetPath (${flavorBlocks.length} flavors)');
    _printCandidatesReport(candidates);
    return 0;
  }

  // ---------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------

  /// Returns the discovered legacy files sorted by flavor name.
  ///
  /// Sorting keeps the YAML output deterministic across filesystems
  /// whose `Directory.list` order is not stable.
  List<_LegacyEntry> _discoverLegacyFiles(String prefix) {
    final dir = Directory(prefix);
    if (!dir.existsSync()) {
      return const <_LegacyEntry>[];
    }
    final pattern = RegExp(constants.legacyFlavorConfigFilePattern);
    final out = <_LegacyEntry>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) {
        continue;
      }
      final basename = p.basename(entity.path);
      final match = pattern.firstMatch(basename);
      if (match == null) {
        continue;
      }
      out.add(_LegacyEntry(flavor: match.group(1)!, path: entity.path));
    }
    out.sort((a, b) => a.flavor.compareTo(b.flavor));
    return out;
  }

  /// Reads a legacy file and returns the inner
  /// `flutter_launcher_icons` (or deprecated `flutter_icons`) block
  /// converted to a plain `Map<String, dynamic>` tree.
  Map<String, dynamic> _parseLegacyFile(String filePath) {
    final content = File(filePath).readAsStringSync();
    final dynamic doc;
    try {
      doc = loadYaml(content);
    } on YamlException catch (e) {
      // Spec §1.3: an unparseable legacy file is a usage error (64),
      // not a runtime/IO failure (1). Wrap as `_MigrateParseException`
      // so it joins the existing 64 path in `run()`.
      throw _MigrateParseException('invalid YAML: ${e.message}');
    }
    if (doc == null) {
      throw const _MigrateParseException('file is empty.');
    }
    if (doc is! YamlMap) {
      throw const _MigrateParseException('top-level is not a mapping.');
    }
    final block = doc['flutter_launcher_icons'] ?? doc['flutter_icons'];
    if (block == null) {
      throw const _MigrateParseException(
        'no "flutter_launcher_icons" (or "flutter_icons") block found.',
      );
    }
    if (block is! YamlMap) {
      throw const _MigrateParseException(
        '"flutter_launcher_icons" block is not a mapping.',
      );
    }
    return _toPlainMap(block);
  }

  /// Recursively converts `YamlMap`/`YamlList` to plain Dart
  /// containers, normalizing keys to `String`.
  Map<String, dynamic> _toPlainMap(Map source) {
    final out = <String, dynamic>{};
    source.forEach((k, v) {
      out[k.toString()] = _convertValue(v);
    });
    return out;
  }

  Object? _convertValue(Object? v) {
    if (v == null) {
      return null;
    }
    if (v is Map) {
      return _toPlainMap(v);
    }
    if (v is List) {
      return v.map(_convertValue).toList();
    }
    return v;
  }

  /// Returns the keys whose values are present and identical across
  /// every flavor block. Compared with deep equality so structurally
  /// equivalent maps/lists also count.
  Map<String, dynamic> _computePromotionCandidates(
    Map<String, Map<String, dynamic>> flavorBlocks,
  ) {
    if (flavorBlocks.isEmpty) {
      return const <String, dynamic>{};
    }
    final blocks = flavorBlocks.values.toList();
    final candidateKeys = blocks.first.keys.toSet();
    for (var i = 1; i < blocks.length; i++) {
      candidateKeys.removeWhere((k) => !blocks[i].containsKey(k));
    }
    final out = <String, dynamic>{};
    for (final k in candidateKeys) {
      final ref = blocks.first[k];
      final identical = blocks.every((b) => _deepEquals(b[k], ref));
      if (identical) {
        out[k] = ref;
      }
    }
    return out;
  }

  bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) {
        return false;
      }
      for (final k in a.keys) {
        if (!b.containsKey(k)) {
          return false;
        }
        if (!_deepEquals(a[k], b[k])) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) {
        return false;
      }
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  void _printCandidatesReport(Map<String, dynamic> candidates) {
    if (candidates.isEmpty) {
      stdout.writeln(
        'ℹ No keys are identical across all flavors; the `defaults:` '
        'block was left empty.',
      );
      return;
    }
    stdout.writeln(
      'ℹ Candidates for promotion to defaults '
      '(identical across all flavors):',
    );
    final yaml = emitYaml(candidates);
    for (final line in yaml.split('\n')) {
      if (line.isEmpty) {
        continue;
      }
      stdout.writeln('    $line');
    }
    stdout.writeln(
      '  Move these into the `defaults:` block manually if desired.',
    );
  }
}

class _LegacyEntry {
  const _LegacyEntry({required this.flavor, required this.path});
  final String flavor;
  final String path;
}

class _MigrateParseException implements Exception {
  const _MigrateParseException(this.message);
  final String message;
}
