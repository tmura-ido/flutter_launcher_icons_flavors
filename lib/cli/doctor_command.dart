import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart'
    show rejectUnknownArgs;
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

    // Reject stray positional args before doing anything else.
    final rejectCode = rejectUnknownArgs(results, logger);
    if (rejectCode != null) {
      return rejectCode;
    }

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

    // 8. Image-path existence per resolved flavor (read-only check).
    if (resolved != null) {
      _reportImagePaths(resolved: resolved, prefix: prefix, logger: logger);
    }

    // 9. Web index.html FLI marker check.
    if (resolved != null) {
      _reportWebIndexMarkers(
        resolved: resolved,
        prefix: prefix,
        logger: logger,
      );
    }

    // 10. Deprecated key usage.
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
        final names = findLegacyFlavorFiles(
          prefix,
        ).map((e) => e.flavor).toList()..sort();
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

  /// Reports missing image_path / image_path_android / image_path_ios /
  /// web.image_path / windows.image_path / macos.image_path for each
  /// resolved flavor. Pure read; warnings only.
  void _reportImagePaths({
    required ResolvedSource resolved,
    required String prefix,
    required FLILogger logger,
  }) {
    stdout.writeln('Image paths:');
    final pairs = <List<String>>[];
    try {
      switch (resolved.kind) {
        case ConfigSourceKind.consolidatedFlavors:
        case ConfigSourceKind.explicitFile:
          if (resolved.path == null) {
            stdout.writeln('  (no config path)');
            stdout.writeln('');
            return;
          }
          final cfg = FlavorsConfig.load(resolved.path!, logger: logger);
          if (cfg == null) {
            stdout.writeln('  (file disappeared)');
            stdout.writeln('');
            return;
          }
          for (final name in cfg.flavorNames) {
            final c = cfg.resolve(name);
            _collectImagePathsFromConfig(name, c, pairs);
          }
          break;
        case ConfigSourceKind.legacyFlavors:
        case ConfigSourceKind.singleFile:
        case ConfigSourceKind.pubspecInline:
          stdout.writeln(
            '  (image-path checks limited to consolidated config sources)',
          );
          stdout.writeln('');
          return;
      }
    } on Exception catch (e) {
      stdout.writeln('  ✕ failed to enumerate image paths: $e');
      stdout.writeln('');
      return;
    }

    if (pairs.isEmpty) {
      stdout.writeln('  (no image paths configured)');
      stdout.writeln('');
      return;
    }

    for (final pair in pairs) {
      final label = pair[0];
      final rel = pair[1];
      final full = p.join(prefix, rel);
      if (File(full).existsSync()) {
        stdout.writeln('  ✓ $label: $rel');
      } else {
        stdout.writeln('  ⚠ $label: $rel — file not found at $full');
      }
    }
    stdout.writeln('');
  }

  void _collectImagePathsFromConfig(
    String flavor,
    dynamic c,
    List<List<String>> out,
  ) {
    void add(String key, String? value) {
      if (value != null && value.isNotEmpty) {
        out.add(['$flavor.$key', value]);
      }
    }

    add('image_path', c.imagePath as String?);
    add('image_path_android', c.imagePathAndroid as String?);
    add('image_path_ios', c.imagePathIOS as String?);
    add('adaptive_icon_foreground', c.adaptiveIconForeground as String?);
    add('adaptive_icon_background', c.adaptiveIconBackground as String?);
    add('adaptive_icon_monochrome', c.adaptiveIconMonochrome as String?);
    add('web.image_path', c.webConfig?.imagePath as String?);
    add('windows.image_path', c.windowsConfig?.imagePath as String?);
    add('macos.image_path', c.macOSConfig?.imagePath as String?);
  }

  /// Warns when a Web config is declared but `web/index.html` lacks the
  /// `<!--FLI-->` marker block that `generate` populates.
  void _reportWebIndexMarkers({
    required ResolvedSource resolved,
    required String prefix,
    required FLILogger logger,
  }) {
    bool anyWebConfig;
    try {
      anyWebConfig = _resolvedHasWebConfig(resolved, logger);
    } on Exception {
      return;
    }
    if (!anyWebConfig) {
      return;
    }
    stdout.writeln('Web index.html:');
    final indexPath = p.join(prefix, constants.webIndexFilePath);
    final indexFile = File(indexPath);
    if (!indexFile.existsSync()) {
      stdout.writeln('  ⚠ $indexPath not found (web target enabled).');
      stdout.writeln('');
      return;
    }
    final contents = indexFile.readAsStringSync();
    if (contents.contains('<!--FLI-->')) {
      stdout.writeln('  ✓ FLI meta-tag markers present in $indexPath');
    } else {
      stdout.writeln(
        '  ⚠ $indexPath has no <!--FLI--> markers. '
        'Run `generate` to inject the PWA meta tags, '
        'or add them manually.',
      );
    }
    stdout.writeln('');
  }

  bool _resolvedHasWebConfig(ResolvedSource resolved, FLILogger logger) {
    switch (resolved.kind) {
      case ConfigSourceKind.consolidatedFlavors:
      case ConfigSourceKind.explicitFile:
        if (resolved.path == null) {
          return false;
        }
        final cfg = FlavorsConfig.load(resolved.path!, logger: logger);
        if (cfg == null) {
          return false;
        }
        for (final name in cfg.flavorNames) {
          if (cfg.resolve(name).hasWebConfig) {
            return true;
          }
        }
        return false;
      case ConfigSourceKind.legacyFlavors:
      case ConfigSourceKind.singleFile:
      case ConfigSourceKind.pubspecInline:
        return false;
    }
  }
}

enum _PubspecInline { absent, flutterLauncherIcons, flutterIcons }
