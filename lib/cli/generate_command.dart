import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/flavors_config.dart';
import 'package:flutter_launcher_icons_flavors/config/source_resolver.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/main.dart' as fli_main;
import 'package:flutter_launcher_icons_flavors/utils/schema_injector.dart';
import 'package:path/path.dart' as p;

/// `generate` subcommand — the default action of the CLI.
///
/// This is the v0.15.0 home of the icon-generation flow. It accepts the
/// existing flag set (`-f`, `-p`, `-v`) plus the new flavor-management
/// flags introduced in Phase 4. Exit codes follow the contract
/// documented in plan §1.2:
///   * 0  — success.
///   * 1  — runtime/IO failure during generation.
///   * 64 — usage error (unknown flavor, conflicting flags such as
///          `--flavor` together with `--all-flavors`).
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
        'no-inject-schema',
        help:
            'Skip prepending the `# yaml-language-server: \$schema=...` '
            'directive to discovered config files.',
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
    final noInjectSchema = results['no-inject-schema'] as bool;

    // README contract: --flavor and --all-flavors are mutually exclusive.
    // Conflicting flags → usage error (64).
    if (flavors.isNotEmpty && allFlavors) {
      logger.error('Could not generate launcher icons');
      logger.error(
        '--flavor and --all-flavors are mutually exclusive; pass one or the other.',
      );
      return 64;
    }

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

    // 1b. Inject the YAML-language-server schema directive into every
    // config file we found. Idempotent; skips pubspec.yaml.
    await _injectSchemaIntoSources(
      resolved: resolved,
      prefix: prefix,
      logger: logger,
      skip: noInjectSchema,
    );

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
          strict: strict,
        );

      case ConfigSourceKind.legacyFlavors:
        return _runLegacyFlavors(
          prefix: prefix,
          logger: logger,
          requestedFlavors: flavors,
          allFlavors: allFlavors,
          listFlavors: listFlavors,
          continueOnError: continueOnError,
          strict: strict,
        );

      case ConfigSourceKind.singleFile:
        return _runSingleConfig(
          loader: () => Config.loadConfigFromPath(resolved.path!, ''),
          logger: logger,
          prefix: prefix,
          requestedFlavors: flavors,
          allFlavors: allFlavors,
          listFlavors: listFlavors,
          strict: strict,
        );

      case ConfigSourceKind.pubspecInline:
        return _runSingleConfig(
          loader: () => Config.loadConfigFromPubSpec(prefix),
          logger: logger,
          prefix: prefix,
          requestedFlavors: flavors,
          allFlavors: allFlavors,
          listFlavors: listFlavors,
          strict: strict,
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
      try {
        throw MixedConfigSourcesException(resolved.ignoredLegacy);
      } on MixedConfigSourcesException catch (e) {
        logger.error('Could not generate launcher icons');
        logger.error('$e');
        return 65;
      }
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
    } else {
      // Default behavior: with no selector, build every flavor declared
      // in the consolidated file. This mirrors the legacy multi-flavor
      // layout (which has always built all flavors by default) and
      // removes the "you must pass --flavor or --all-flavors" foot-gun.
      // Pass --flavor <name> to narrow.
      selected = available;
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

    // Snapshot native-side configuration state BEFORE generation,
    // because the Android pipeline creates `android/app/src/<flavor>/`
    // folders on demand and would mask a missing-folder check
    // performed after the fact.
    final detector = _FlavorGapDetector(prefix: prefix);
    final gaps = <_FlavorPlatformGap>[];
    for (final name in selected) {
      gaps.addAll(detector.missingForFlavor(name, resolvedConfigs[name]!));
    }
    if (allFlavors) {
      gaps.addAll(detector.extrasNotInConfig(available.toSet()));
    }

    // Generate sequentially. Track per-flavor outcomes for the summary.
    final failures = <String, Object>{};
    for (final name in selected) {
      stdout.writeln('\n### Flavor: $name');
      try {
        await fli_main.createIconsFromConfig(
          resolvedConfigs[name]!,
          logger,
          prefix,
          name,
          strict,
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
    _emitGapWarnings(gaps, logger);
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
    required bool strict,
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

    final detector = _FlavorGapDetector(prefix: prefix);
    final gaps = <_FlavorPlatformGap>[];
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
        // Snapshot native-side state BEFORE generation for this flavor;
        // the Android pipeline creates `android/app/src/<flavor>/` on
        // demand.
        gaps.addAll(detector.missingForFlavor(flavor, cfg));
        await fli_main.createIconsFromConfig(
          cfg,
          logger,
          prefix,
          flavor,
          strict,
        );
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

    if (allFlavors) {
      gaps.addAll(detector.extrasNotInConfig(discovered.toSet()));
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
    _emitGapWarnings(gaps, logger);
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
    required bool strict,
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
      await fli_main.createIconsFromConfig(
        cfg,
        logger,
        prefix,
        null,
        strict,
      );
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

  /// Prepends the `# yaml-language-server: $schema=...` directive to
  /// every config file the resolver found (the winner plus any
  /// shadowed legacy siblings). Idempotent, pubspec-safe.
  Future<void> _injectSchemaIntoSources({
    required ResolvedSource resolved,
    required String prefix,
    required FLILogger logger,
    required bool skip,
  }) async {
    if (skip) {
      return;
    }
    final paths = <String>{
      if (resolved.path != null) resolved.path!,
      ...resolved.ignoredLegacy,
    };
    if (resolved.kind == ConfigSourceKind.legacyFlavors) {
      // legacyFlavors resolves without a single winner path; inject
      // into every discovered per-flavor file.
      final discovered = await fli_main.getFlavors(prefix);
      for (final f in discovered) {
        paths.add(p.join(prefix, 'flutter_launcher_icons-$f.yaml'));
      }
    }
    for (final path in paths) {
      try {
        await ensureSchemaDirective(path, logger: logger);
      } on Exception catch (e) {
        logger.verbose('Schema injection skipped for $path: $e');
      }
    }
  }
}

// =====================================================================
// Missing / extra flavor configuration detection.
// =====================================================================

/// A single gap between the launcher icons configuration and the
/// project's native (Android/iOS) side.
///
/// Emitted as a one-line warning by [_emitGapWarnings].
class _FlavorPlatformGap {
  _FlavorPlatformGap({
    required this.flavor,
    required this.platform,
    required this.detail,
  });

  /// Flavor name (as appears in the launcher icons config or on the
  /// native side, depending on the gap kind).
  final String flavor;

  /// Either `'Android'` or `'iOS'`.
  final String platform;

  /// Human-readable explanation of the gap.
  final String detail;
}

/// Probes the project for missing / extra flavor configuration on the
/// native (Android/iOS) side. Caches `project.pbxproj` content so that
/// repeated calls do not re-read the file.
class _FlavorGapDetector {
  _FlavorGapDetector({required this.prefix});

  /// Project prefix path (same as `--prefix`).
  final String prefix;

  String? _pbxprojContent;
  bool _pbxprojRead = false;

  String? get _pbxproj {
    if (!_pbxprojRead) {
      _pbxprojRead = true;
      final f = File(p.join(prefix, constants.iosConfigFile));
      if (f.existsSync()) {
        _pbxprojContent = f.readAsStringSync();
      }
    }
    return _pbxprojContent;
  }

  /// Returns gaps where the [config] enables a platform for [flavor]
  /// but the matching native-side reference is absent.
  List<_FlavorPlatformGap> missingForFlavor(String flavor, Config config) {
    final gaps = <_FlavorPlatformGap>[];

    if (config.android.isEnabled) {
      final folder = Directory(p.join(prefix, 'android', 'app', 'src', flavor));
      if (!folder.existsSync()) {
        gaps.add(
          _FlavorPlatformGap(
            flavor: flavor,
            platform: 'Android',
            detail: 'no android/app/src/$flavor/ folder found',
          ),
        );
      }
    }

    if (config.ios.isEnabled) {
      final content = _pbxproj;
      if (content == null) {
        gaps.add(
          _FlavorPlatformGap(
            flavor: flavor,
            platform: 'iOS',
            detail: 'no ${constants.iosConfigFile} found',
          ),
        );
      } else if (!_pbxprojReferencesFlavor(content, flavor)) {
        gaps.add(
          _FlavorPlatformGap(
            flavor: flavor,
            platform: 'iOS',
            detail:
                'no -$flavor xcconfig reference in '
                '${constants.iosConfigFile}',
          ),
        );
      }
    }

    return gaps;
  }

  /// Returns gaps for native-side flavors that are NOT present in
  /// [configFlavors]. Intended for the `--all-flavors` flow.
  List<_FlavorPlatformGap> extrasNotInConfig(Set<String> configFlavors) {
    final gaps = <_FlavorPlatformGap>[];

    // Android: subfolders of `android/app/src/` other than the
    // built-in source sets (`main`, build types, test source sets).
    final androidSrcDir = Directory(p.join(prefix, 'android', 'app', 'src'));
    if (androidSrcDir.existsSync()) {
      const reserved = {
        'main',
        'debug',
        'release',
        'profile',
        'androidTest',
        'test',
      };
      final discovered = <String>[];
      for (final entity in androidSrcDir.listSync()) {
        if (entity is! Directory) {
          continue;
        }
        final name = p.basename(entity.path);
        if (reserved.contains(name)) {
          continue;
        }
        if (configFlavors.contains(name)) {
          continue;
        }
        discovered.add(name);
      }
      discovered.sort();
      for (final name in discovered) {
        gaps.add(
          _FlavorPlatformGap(
            flavor: name,
            platform: 'Android',
            detail:
                'android/app/src/$name/ folder exists but flavor is '
                'not declared in launcher icons config',
          ),
        );
      }
    }

    // iOS: candidate flavors extracted from `<BuildType>-<flavor>.xcconfig`
    // references in project.pbxproj. Restricted to the conventional
    // Flutter build types (Debug/Release/Profile) to avoid false
    // positives from CocoaPods-generated configs like
    // `Pods-Runner.debug.xcconfig`.
    final content = _pbxproj;
    if (content != null) {
      final regex = RegExp(
        r'/\*\s*(?:Debug|Release|Profile)-([A-Za-z0-9_-]+?)\.xcconfig\s*\*/',
      );
      final discovered = <String>{};
      for (final m in regex.allMatches(content)) {
        discovered.add(m.group(1)!);
      }
      final sorted = discovered.toList()..sort();
      for (final flavor in sorted) {
        if (configFlavors.contains(flavor)) {
          continue;
        }
        gaps.add(
          _FlavorPlatformGap(
            flavor: flavor,
            platform: 'iOS',
            detail:
                '${constants.iosConfigFile} references -$flavor '
                'xcconfig but flavor is not declared in launcher icons '
                'config',
          ),
        );
      }
    }

    return gaps;
  }

  /// Mirrors the matching rule used by `changeIosLauncherIcon` in
  /// `lib/ios.dart`: an xcconfig basename (the part before `.xcconfig`
  /// in a `/* X.xcconfig */` comment) must contain `-<flavor>` as a
  /// substring.
  static bool _pbxprojReferencesFlavor(String content, String flavor) {
    final regex = RegExp(r'/\*\s*([^/\s*]+)\.xcconfig\s*\*/');
    final needle = '-$flavor';
    for (final m in regex.allMatches(content)) {
      if (m.group(1)!.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}

void _emitGapWarnings(List<_FlavorPlatformGap> gaps, FLILogger logger) {
  if (gaps.isEmpty) {
    return;
  }
  for (final gap in gaps) {
    logger.warn('Flavor "${gap.flavor}" (${gap.platform}): ${gap.detail}.');
  }
}
