import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/config/flavors_config.dart';
import 'package:flutter_launcher_icons_flavors/config/legacy_discovery.dart';
import 'package:flutter_launcher_icons_flavors/config/source_resolver.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/src/version.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// `doctor` subcommand — diagnoses the current project's launcher-icons
/// setup. Pure read; never writes files.
///
/// Returns 0 unless we determine the project is genuinely broken (e.g.
/// no config found at all, or schema-invalid consolidated file). In
/// that case we still print the report and exit 65 so CI gates can
/// surface the problem.
class DoctorCommand extends Command<int> {
  /// Creates the parser.
  DoctorCommand() {
    argParser
      ..addOption(
        'prefix',
        abbr: 'p',
        help: 'Project prefix path. Defaults to the current directory.',
        defaultsTo: '.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Verbose: include each flavor\'s resolved config summary.',
        negatable: false,
      )
      ..addFlag(
        'strict',
        help:
            'Treat deprecation warnings (e.g. legacy `flutter_icons:` '
            'pubspec key) as fatal (exit 65).',
        negatable: false,
      );
  }

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Diagnose the project\'s launcher-icons setup. Read-only.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final prefix = results['prefix'] as String;
    final verbose = results['verbose'] as bool;
    final strict = results['strict'] as bool;
    final logger = FLILogger(verbose);

    var problemDetected = false;
    var deprecationDetected = false;

    final absolutePrefix = p.normalize(p.absolute(prefix));

    // 1. Tool version.
    stdout.writeln('flutter_launcher_icons_flavors doctor');
    stdout.writeln('  version: $packageVersion');

    // 2. Resolved prefix.
    stdout.writeln('  prefix:  $absolutePrefix');
    stdout.writeln('');

    // 3. Detected sources.
    stdout.writeln('Detected configuration sources:');
    final consolidatedPath = p.join(
      prefix,
      constants.consolidatedFlavorsFileName,
    );
    final singlePath = p.join(prefix, constants.singleConfigFileName);
    final pubspecPath = p.join(prefix, constants.pubspecFilePath);
    final legacyPaths = _findLegacyFiles(prefix);

    stdout.writeln(
      '  --file:                              [absent] (doctor takes no --file)',
    );
    _writeFoundLine(consolidatedPath, 'flutter_launcher_icons_flavors.yaml');
    if (legacyPaths.isEmpty) {
      stdout.writeln('  flutter_launcher_icons-<flavor>.yaml: [absent]');
    } else {
      stdout.writeln('  flutter_launcher_icons-<flavor>.yaml: [FOUND]');
      for (final lp in legacyPaths) {
        stdout.writeln('      - $lp');
      }
    }
    _writeFoundLine(singlePath, 'flutter_launcher_icons.yaml');

    final pubspecHas = _pubspecHasInline(pubspecPath);
    if (pubspecHas == _PubspecInline.absent) {
      stdout.writeln('  pubspec.yaml inline:                  [absent]');
    } else if (pubspecHas == _PubspecInline.flutterLauncherIcons) {
      stdout.writeln(
        '  pubspec.yaml inline:                  [FOUND] (flutter_launcher_icons)',
      );
    } else {
      stdout.writeln(
        '  pubspec.yaml inline:                  [FOUND] (flutter_icons — DEPRECATED)',
      );
    }
    stdout.writeln('');

    // 4 & 5. Precedence winner / ignored sources.
    ResolvedSource? resolved;
    try {
      resolved = resolveSource(prefixPath: prefix, logger: logger);
    } on NoConfigFoundException catch (e) {
      problemDetected = true;
      stdout.writeln('Precedence winner: NONE');
      stdout.writeln('  reason: $e');
      stdout.writeln('');
    }

    if (resolved != null) {
      stdout.writeln('Precedence winner: ${_kindLabel(resolved.kind)}');
      if (resolved.path != null) {
        stdout.writeln('  path: ${resolved.path}');
      }
      stdout.writeln('  reason: ${_winnerReason(resolved.kind)}');
      stdout.writeln('');
      if (resolved.ignoredLegacy.isNotEmpty) {
        stdout.writeln('Ignored due to precedence:');
        for (final ig in resolved.ignoredLegacy) {
          stdout.writeln('  - $ig');
        }
        stdout.writeln(
          '  (`generate` would emit the coexistence warning; '
          '`--strict` would escalate to exit 65.)',
        );
        stdout.writeln('');
      } else {
        stdout.writeln('Ignored due to precedence: none');
        stdout.writeln('');
      }

      // 6. Parsed flavors.
      problemDetected |= _reportFlavors(
        resolved: resolved,
        prefix: prefix,
        verbose: verbose,
        logger: logger,
      );
    }

    // 7. Android Gradle detection.
    await _reportGradle(prefix);

    // 8. Deprecated key usage.
    if (pubspecHas == _PubspecInline.flutterIcons) {
      deprecationDetected = true;
      stdout.writeln('Deprecated keys:');
      stdout.writeln(
        "  ⚠ Deprecated key 'flutter_icons:' in pubspec.yaml — rename to "
        "'flutter_launcher_icons:' or migrate to "
        'flutter_launcher_icons_flavors.yaml.',
      );
    } else {
      stdout.writeln('Deprecated keys: none detected');
    }

    if (problemDetected) {
      return 65;
    }
    if (strict && deprecationDetected) {
      return 65;
    }
    return 0;
  }

  // ---------------------------------------------------------------------

  void _writeFoundLine(String path, String label) {
    final pad = label.padRight(36);
    if (File(path).existsSync()) {
      stdout.writeln('  $pad: [FOUND] $path');
    } else {
      stdout.writeln('  $pad: [absent]');
    }
  }

  List<String> _findLegacyFiles(String prefix) => findLegacyFlavorPaths(prefix);

  _PubspecInline _pubspecHasInline(String pubspecPath) {
    final file = File(pubspecPath);
    if (!file.existsSync()) {
      return _PubspecInline.absent;
    }
    try {
      final dynamic doc = loadYaml(file.readAsStringSync());
      if (doc is YamlMap) {
        if (doc['flutter_launcher_icons'] != null) {
          return _PubspecInline.flutterLauncherIcons;
        }
        if (doc['flutter_icons'] != null) {
          return _PubspecInline.flutterIcons;
        }
      }
    } catch (_) {
      // Treat parse failures as absent for the report; `generate` will
      // surface the real error.
    }
    return _PubspecInline.absent;
  }

  String _kindLabel(ConfigSourceKind kind) {
    switch (kind) {
      case ConfigSourceKind.consolidatedFlavors:
        return 'consolidated multi-flavor file';
      case ConfigSourceKind.legacyFlavors:
        return 'legacy per-flavor files';
      case ConfigSourceKind.singleFile:
        return 'single config file';
      case ConfigSourceKind.pubspecInline:
        return 'pubspec.yaml inline';
      case ConfigSourceKind.explicitFile:
        return 'explicit --file';
    }
  }

  String _winnerReason(ConfigSourceKind kind) {
    switch (kind) {
      case ConfigSourceKind.consolidatedFlavors:
        return 'flutter_launcher_icons_flavors.yaml found at the prefix.';
      case ConfigSourceKind.legacyFlavors:
        return 'no consolidated file; legacy per-flavor files present.';
      case ConfigSourceKind.singleFile:
        return 'no flavors; single flutter_launcher_icons.yaml found.';
      case ConfigSourceKind.pubspecInline:
        return 'no other source; pubspec.yaml has an inline config block.';
      case ConfigSourceKind.explicitFile:
        return 'user passed --file (not applicable to doctor).';
    }
  }

  /// Returns true if a problem was detected.
  bool _reportFlavors({
    required ResolvedSource resolved,
    required String prefix,
    required bool verbose,
    required FLILogger logger,
  }) {
    var problem = false;
    stdout.writeln('Flavors:');
    switch (resolved.kind) {
      case ConfigSourceKind.consolidatedFlavors:
      case ConfigSourceKind.explicitFile:
        if (resolved.path == null) {
          stdout.writeln('  (no path)');
          stdout.writeln('');
          return problem;
        }
        try {
          final cfg = FlavorsConfig.load(resolved.path!, logger: logger);
          if (cfg == null) {
            stdout.writeln('  (file disappeared between checks)');
            problem = true;
          } else {
            for (final name in cfg.flavorNames) {
              stdout.writeln('  - $name');
              if (verbose) {
                try {
                  final c = cfg.resolve(name);
                  stdout.writeln(
                    '      android=${c.android.isEnabled} '
                    'ios=${c.ios.isEnabled} '
                    'min_sdk_android=${c.minSdkAndroid ?? "(unset)"} '
                    'web=${c.hasWebConfig} '
                    'windows=${c.hasWindowsConfig} '
                    'macos=${c.hasMacOSConfig}',
                  );
                } on Exception catch (e) {
                  problem = true;
                  stdout.writeln('      ✕ resolve failed: $e');
                }
              }
            }
          }
        } on Exception catch (e) {
          problem = true;
          stdout.writeln('  ✕ failed to load flavors file: $e');
        }
        break;
      case ConfigSourceKind.legacyFlavors:
        final names = findLegacyFlavorFiles(prefix).map((e) => e.flavor).toList()
          ..sort();
        for (final n in names) {
          stdout.writeln('  - $n');
        }
        break;
      case ConfigSourceKind.singleFile:
      case ConfigSourceKind.pubspecInline:
        stdout.writeln('  (single-config source; no flavors)');
        break;
    }
    stdout.writeln('');
    return problem;
  }

  Future<void> _reportGradle(String prefix) async {
    stdout.writeln('Android Gradle:');
    final file = await android.findAndroidGradleFile(prefix);
    if (file == null) {
      stdout.writeln('  detected file: none');
      stdout.writeln(
        '  min_sdk_android: not auto-detected — '
        '${constants.errorMissingMinSdk}',
      );
      stdout.writeln(
        '  (Static default ${constants.androidDefaultAndroidMinSDK} would '
        'be used at generation time.)',
      );
      stdout.writeln('');
      return;
    }
    stdout.writeln('  detected file: ${file.path}');
    final detection = await android.detectMinSdkAndroid(prefixPath: prefix);
    if (detection.value == null && detection.matchedLabel == null) {
      stdout.writeln(
        '  min_sdk_android: could not auto-detect '
        '(version catalog or convention plugin?). '
        'Specify min_sdk_android in your config.',
      );
      stdout.writeln(
        '  (Static default ${constants.androidDefaultAndroidMinSDK} would '
        'be used at generation time.)',
      );
    } else if (detection.value == null) {
      // Pattern matched (e.g. `flutter.minSdkVersion` indirection) but
      // recursion couldn't land a value.
      stdout.writeln(
        '  min_sdk_android: indirection detected but unresolved '
        '(check local.properties / flutter.sdk path).',
      );
      stdout.writeln('  matched pattern: ${detection.matchedLabel}');
      stdout.writeln(
        '  (Static default ${constants.androidDefaultAndroidMinSDK} would '
        'be used at generation time.)',
      );
    } else {
      stdout.writeln('  min_sdk_android: ${detection.value}');
      if (detection.matchedLabel != null) {
        stdout.writeln('  matched pattern: ${detection.matchedLabel}');
      } else {
        stdout.writeln('  matched pattern: (from local.properties)');
      }
    }
    stdout.writeln('');
  }
}

enum _PubspecInline { absent, flutterLauncherIcons, flutterIcons }
