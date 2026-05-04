import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_launcher_icons_flavored/config/config.dart';
import 'package:flutter_launcher_icons_flavored/config/flavors_config.dart';
import 'package:flutter_launcher_icons_flavored/config/source_resolver.dart';
import 'package:flutter_launcher_icons_flavored/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:flutter_launcher_icons_flavored/main.dart' as fli_main;

/// `generate` subcommand — the default action of the CLI.
///
/// This is the v0.15.0 home of the icon-generation flow. It accepts the
/// existing flag set (`-f`, `-p`, `-v`) plus the new flavor-management
/// flags introduced in Phase 4. Exit codes follow the contract
/// documented in plan §1.2:
///   * 0  — success.
///   * 1  — runtime/IO failure during generation.
///   * 64 — usage error (unknown flavor, conflicting flags,
///          multi-flavor consolidated without `--flavor`/`--all-flavors`).
///   * 65 — config validation error / strict-mode coexistence /
///          preflight failure / `NoConfigFoundException`.
class GenerateCommand extends Command<int> {
  /// Creates the parser. We declare every option ourselves rather than
  /// inheriting from a shared base because the doctor/migrate commands
  /// have a distinct (smaller) flag surface.
  GenerateCommand() {
    argParser
      ..addOption(
        'file',
        abbr: 'f',
        help:
            'Path to a config file '
            '(overrides the default search order).',
      )
      ..addOption(
        'prefix',
        abbr: 'p',
        help: 'Project prefix path. Defaults to the current directory.',
        defaultsTo: '.',
      )
      ..addMultiOption(
        'flavor',
        help: 'Build only the named flavor. Repeat to build multiple.',
        valueHelp: 'name',
      )
      ..addFlag(
        'all-flavors',
        help: 'Build every flavor defined by the consolidated config.',
        negatable: false,
      )
      ..addFlag(
        'list-flavors',
        help: 'Print discovered flavors and exit without generating.',
        negatable: false,
      )
      ..addFlag(
        'continue-on-error',
        help:
            'When generating multiple flavors, log per-flavor failures '
            'and continue. Exits 1 with a summary if any failed.',
        negatable: false,
      )
      ..addFlag(
        'strict',
        help:
            'Treat the new+legacy config coexistence warning as a fatal '
            'error (exit 65).',
        negatable: false,
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Enable verbose logging.',
        negatable: false,
      );
  }

  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generate launcher icons (default subcommand). '
      'Supports single-config, legacy per-flavor files, and the new '
      'consolidated flutter_launcher_icons_flavors.yaml.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final verbose = results['verbose'] as bool;
    final logger = FLILogger(verbose);
    final prefix = results['prefix'] as String;
    final explicit = results['file'] as String?;
    final flavors = (results['flavor'] as List<dynamic>).cast<String>();
    final allFlavors = results['all-flavors'] as bool;
    final listFlavors = results['list-flavors'] as bool;
    final continueOnError = results['continue-on-error'] as bool;
    final strict = results['strict'] as bool;

    // 1. Resolve which config source to use.
    final ResolvedSource resolved;
    try {
      resolved = resolveSource(
        prefixPath: prefix,
        explicitFilePath: explicit,
        logger: logger,
      );
    } on NoConfigFoundException catch (e) {
      logger.error('Could not generate launcher icons');
      logger.error('$e');
      return 65;
    }

    // 2. Dispatch by source kind.
    switch (resolved.kind) {
      case ConfigSourceKind.consolidatedFlavors:
        return _runConsolidated(
          resolved: resolved,
          logger: logger,
          prefix: prefix,
          requestedFlavors: flavors,
          allFlavors: allFlavors,
          listFlavors: listFlavors,
          continueOnError: continueOnError,
          strict: strict,
        );

      case ConfigSourceKind.explicitFile:
        if (resolved.isMultiFlavor) {
          return _runConsolidated(
            resolved: resolved,
            logger: logger,
            prefix: prefix,
            requestedFlavors: flavors,
            allFlavors: allFlavors,
            listFlavors: listFlavors,
            continueOnError: continueOnError,
            strict: strict,
          );
        }
        return _runSingleConfig(
          loader: () => Config.loadConfigFromPath(resolved.path!, ''),
          logger: logger,
          prefix: prefix,
          requestedFlavors: flavors,
          allFlavors: allFlavors,
          listFlavors: listFlavors,
        );

      case ConfigSourceKind.legacyFlavors:
        return _runLegacyFlavors(
          prefix: prefix,
          logger: logger,
          requestedFlavors: flavors,
          allFlavors: allFlavors,
          listFlavors: listFlavors,
          continueOnError: continueOnError,
        );

      case ConfigSourceKind.singleFile:
        return _runSingleConfig(
          loader: () => Config.loadConfigFromPath(resolved.path!, ''),
          logger: logger,
          prefix: prefix,
          requestedFlavors: flavors,
          allFlavors: allFlavors,
          listFlavors: listFlavors,
        );

      case ConfigSourceKind.pubspecInline:
        return _runSingleConfig(
          loader: () => Config.loadConfigFromPubSpec(prefix),
          logger: logger,
          prefix: prefix,
          requestedFlavors: flavors,
          allFlavors: allFlavors,
          listFlavors: listFlavors,
        );
    }
  }

  // ---------------------------------------------------------------------
  // Consolidated (new) multi-flavor flow.
  // ---------------------------------------------------------------------
  Future<int> _runConsolidated({
    required ResolvedSource resolved,
    required FLILogger logger,
    required String prefix,
    required List<String> requestedFlavors,
    required bool allFlavors,
    required bool listFlavors,
    required bool continueOnError,
    required bool strict,
  }) async {
    final FlavorsConfig? flavorsConfig;
    try {
      flavorsConfig = FlavorsConfig.load(resolved.path!, logger: logger);
    } on Exception catch (e) {
      logger.error('Could not generate launcher icons');
      logger.error('$e');
      return 65;
    }
    if (flavorsConfig == null) {
      logger.error('Could not generate launcher icons');
      logger.error('Config file disappeared: ${resolved.path}');
      return 65;
    }

    final available = flavorsConfig.flavorNames.toList();

    // --list-flavors short-circuits everything else.
    if (listFlavors) {
      stdout.writeln('Flavors in ${resolved.path}:');
      for (final name in available) {
        stdout.writeln('  - $name');
      }
      return 0;
    }

    // --strict: escalate the coexistence warning to a hard error.
    if (strict && resolved.ignoredLegacy.isNotEmpty) {
      logger.error('Could not generate launcher icons');
      logger.error('${MixedConfigSourcesException(resolved.ignoredLegacy)}');
      return 65;
    }

    // Compute the selected flavor set.
    final List<String> selected;
    if (requestedFlavors.isNotEmpty) {
      // Validate each requested name BEFORE we start writing.
      final unknown = requestedFlavors
          .where((n) => !available.contains(n))
          .toList();
      if (unknown.isNotEmpty) {
        logger.error('Could not generate launcher icons');
        logger.error(
          'Unknown flavor(s): ${unknown.join(', ')}. '
          'Available: ${available.join(', ')}',
        );
        return 64;
      }
      selected = requestedFlavors;
    } else if (allFlavors) {
      selected = available;
    } else if (available.length == 1) {
      // Ergonomic build: a single-flavor consolidated file does not
      // require an explicit selector.
      selected = available;
    } else {
      logger.error('Could not generate launcher icons');
      logger.error(
        'Multiple flavors are defined in ${resolved.path}. '
        'Pass --flavor <name> (repeatable) or --all-flavors to choose. '
        'Available: ${available.join(', ')}',
      );
      return 64;
    }

    // Preflight: validate every selected flavor BEFORE doing any I/O.
    final resolvedConfigs = <String, Config>{};
    try {
      for (final name in selected) {
        resolvedConfigs[name] = flavorsConfig.resolve(name);
      }
    } on Exception catch (e) {
      logger.error('Could not generate launcher icons');
      logger.error('$e');
      return 65;
    }

    // Generate sequentially. Track per-flavor outcomes for the summary.
    final failures = <String, Object>{};
    for (final name in selected) {
      stdout.writeln('\nFlavor: $name');
      try {
        await fli_main.createIconsFromConfig(
          resolvedConfigs[name]!,
          logger,
          prefix,
          name,
        );
      } on InvalidConfigException catch (e) {
        // Spec exit-code matrix: schema/validation failures are config
        // errors (65), not runtime failures (1). Mirror the
        // single-config branch.
        if (!continueOnError) {
          logger.error('Could not generate launcher icons for $name');
          logger.error('$e');
          return 65;
        }
        failures[name] = e;
        logger.error('Flavor "$name" failed: $e');
      } catch (e) {
        if (!continueOnError) {
          logger.error('Could not generate launcher icons for $name');
          logger.error('$e');
          return 1;
        }
        failures[name] = e;
        logger.error('Flavor "$name" failed: $e');
      }
    }

    if (failures.isNotEmpty) {
      stdout.writeln('\nGeneration summary:');
      for (final name in selected) {
        if (failures.containsKey(name)) {
          stdout.writeln('  ✕ $name — ${failures[name]}');
        } else {
          stdout.writeln('  ✓ $name');
        }
      }
      // If every failure is a config validation error, exit 65;
      // otherwise the most-severe runtime failure dominates → 1.
      final allConfig = failures.values.every(
        (e) => e is InvalidConfigException,
      );
      return allConfig ? 65 : 1;
    }
    stdout.writeln('\n✓ Successfully generated launcher icons for flavors');
    return 0;
  }

  // ---------------------------------------------------------------------
  // Legacy multi-flavor flow.
  // ---------------------------------------------------------------------
  Future<int> _runLegacyFlavors({
    required String prefix,
    required FLILogger logger,
    required List<String> requestedFlavors,
    required bool allFlavors,
    required bool listFlavors,
    required bool continueOnError,
  }) async {
    final discovered = await fli_main.getFlavors(prefix);
    discovered.sort();

    if (listFlavors) {
      stdout.writeln('Legacy flavors in $prefix:');
      for (final f in discovered) {
        stdout.writeln('  - $f');
      }
      return 0;
    }

    if (allFlavors) {
      logger.info(
        '--all-flavors is the default for legacy flavor files; flag is a no-op.',
      );
    }

    final List<String> selected;
    if (requestedFlavors.isNotEmpty) {
      final unknown = requestedFlavors
          .where((n) => !discovered.contains(n))
          .toList();
      if (unknown.isNotEmpty) {
        logger.error('Could not generate launcher icons');
        logger.error(
          'Unknown flavor(s): ${unknown.join(', ')}. '
          'Available: ${discovered.join(', ')}',
        );
        return 64;
      }
      selected = requestedFlavors;
    } else {
      selected = discovered;
    }

    final failures = <String, Object>{};
    for (final flavor in selected) {
      stdout.writeln('\nFlavor: $flavor');
      try {
        final cfg = Config.loadConfigFromFlavor(flavor, prefix);
        if (cfg == null) {
          throw NoConfigFoundException(
            'No configuration found for $flavor flavor.',
          );
        }
        await fli_main.createIconsFromConfig(cfg, logger, prefix, flavor);
      } catch (e) {
        if (!continueOnError) {
          logger.error('Could not generate launcher icons for $flavor');
          logger.error('$e');
          return 1;
        }
        failures[flavor] = e;
        logger.error('Flavor "$flavor" failed: $e');
      }
    }

    if (failures.isNotEmpty) {
      stdout.writeln('\nGeneration summary:');
      for (final f in selected) {
        if (failures.containsKey(f)) {
          stdout.writeln('  ✕ $f — ${failures[f]}');
        } else {
          stdout.writeln('  ✓ $f');
        }
      }
      return 1;
    }
    stdout.writeln('\n✓ Successfully generated launcher icons for flavors');
    return 0;
  }

  // ---------------------------------------------------------------------
  // Single-config flow (single file or pubspec inline).
  // ---------------------------------------------------------------------
  Future<int> _runSingleConfig({
    required Config? Function() loader,
    required FLILogger logger,
    required String prefix,
    required List<String> requestedFlavors,
    required bool allFlavors,
    required bool listFlavors,
  }) async {
    if (listFlavors) {
      stdout.writeln('No flavors; this project uses a single-config source.');
      return 0;
    }
    if (allFlavors) {
      logger.info(
        '--all-flavors has no effect on single-config sources; flag is a no-op.',
      );
    }
    if (requestedFlavors.isNotEmpty) {
      logger.error('Could not generate launcher icons');
      logger.error(
        'No flavors are defined; --flavor cannot be used with a '
        'single-config source.',
      );
      return 64;
    }

    final Config? cfg;
    try {
      cfg = loader();
    } on Exception catch (e) {
      logger.error('Could not generate launcher icons');
      logger.error('$e');
      return 65;
    }
    if (cfg == null) {
      logger.error('Could not generate launcher icons');
      logger.error(
        const NoConfigFoundException('No configuration found.').toString(),
      );
      return 65;
    }
    try {
      await fli_main.createIconsFromConfig(cfg, logger, prefix);
      stdout.writeln('\n✓ Successfully generated launcher icons');
      return 0;
    } on InvalidConfigException catch (e) {
      logger.error('Could not generate launcher icons');
      logger.error('$e');
      return 65;
    } catch (e) {
      logger.error('Could not generate launcher icons');
      logger.error('$e');
      return 1;
    }
  }
}
