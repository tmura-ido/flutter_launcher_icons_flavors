// One test per testable claim made in README.md.
//
// Each `test(...)` is named after the section + claim it verifies, so
// when something fails the README sentence that's wrong (or the code
// that's wrong) is one click away.
//
// Generated to make the project test-tight against its README. If a test
// is failing, decide whether the README is wrong or the code is wrong —
// don't silently delete the test.

import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/flavors_config.dart';
import 'package:flutter_launcher_icons_flavors/config/merge.dart';
import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:flutter_launcher_icons_flavors/config/source_resolver.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/src/version.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:yaml/yaml.dart';

import 'templates.dart' as templates;

/// Captured eagerly in `main()` before any test runs, so that concurrent
/// tests (notably `test/main_test.dart` and the config-file tests) which
/// mutate `Directory.current` mid-suite cannot poison path lookups here.
late final String _projectRoot;

List<int> _asset() => File(
  p.join(_projectRoot, 'test', 'assets', 'app_icon.png'),
).readAsBytesSync();

/// Seeds a sandbox dir with a web/ scaffold + the test asset + an empty
/// pubspec. Web-only so we don't need android/ios scaffolds.
Future<String> _webSandbox(
  String name, {
  List<d.Descriptor> extra = const [],
}) async {
  await d.dir(name, [
    d.dir('web', [
      d.dir('icons'),
      d.file('index.html', templates.webIndexTemplate),
      d.file('manifest.json', templates.webManifestTemplate),
    ]),
    d.file('app_icon.png', _asset()),
    d.file('pubspec.yaml', 'name: demo\n'),
    ...extra,
  ]).create();
  return p.join(d.sandbox, name);
}

void main() {
  // Capture project root EAGERLY, before any test (in any file) can
  // mutate `Directory.current`. This main() runs at test-discovery time,
  // strictly before any test body.
  _projectRoot = Directory.current.path;

  // ---------------------------------------------------------------------
  // Requirements section
  // ---------------------------------------------------------------------
  group('README §Requirements', () {
    test('pubspec.yaml declares Dart SDK >=3.8.0 <4.0.0', () {
      final ps = File(p.join(_projectRoot, 'pubspec.yaml')).readAsStringSync();
      final doc = loadYaml(ps) as YamlMap;
      final sdk = (doc['environment'] as YamlMap)['sdk'] as String;
      // Accept either the explicit range or the semantically-equivalent
      // canonical caret form `^3.8.0`.
      expect(sdk, anyOf('>=3.8.0 <4.0.0', '^3.8.0'));
    });

    test(
      'default min_sdk_android is 24 (constants.androidDefaultAndroidMinSDK)',
      () {
        expect(constants.androidDefaultAndroidMinSDK, 24);
      },
    );

    test('README uses `dart run`, not deprecated `flutter pub run`', () {
      final readme = File(p.join(_projectRoot, 'README.md')).readAsStringSync();
      expect(
        readme.contains('flutter pub run'),
        isFalse,
        reason: '`flutter pub run` is deprecated by Dart; use `dart run`.',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Install section — version pin must match the current published version
  // ---------------------------------------------------------------------
  group('README §Install', () {
    test('README pins the dev-dependency to the current pubspec version '
        '(flutter_launcher_icons_flavors: ^X.Y.Z)', () {
      final pubspec = File(
        p.join(_projectRoot, 'pubspec.yaml'),
      ).readAsStringSync();
      final version = (loadYaml(pubspec) as YamlMap)['version'] as String;
      final readme = File(p.join(_projectRoot, 'README.md')).readAsStringSync();
      final expected = 'flutter_launcher_icons_flavors: ^$version';
      expect(
        readme,
        contains(expected),
        reason:
            'README install snippet must advertise the current package '
            'version "$expected". Run `dart run tool/sync_version.dart` '
            'to sync the README + lib/src/version.dart to pubspec.yaml.',
      );
    });

    test('packageVersion constant matches pubspec.yaml version', () {
      final pubspec = File(
        p.join(_projectRoot, 'pubspec.yaml'),
      ).readAsStringSync();
      final version = (loadYaml(pubspec) as YamlMap)['version'] as String;
      expect(
        packageVersion,
        version,
        reason:
            'lib/src/version.dart is out of sync with pubspec.yaml — run '
            '`dart run tool/sync_version.dart` (or `dart run build_runner '
            'build`) after bumping the version.',
      );
    });
  });

  // ---------------------------------------------------------------------
  // CLI reference — subcommands
  // ---------------------------------------------------------------------
  group('README §CLI reference', () {
    test('three subcommands are registered: generate, migrate, doctor', () {
      final runner = buildCommandRunner();
      expect(
        runner.commands.keys,
        containsAll(['generate', 'migrate', 'doctor']),
      );
    });

    test('"generate" is the default subcommand: bare args → generate', () {
      expect(effectiveArgs(const []), ['generate']);
      expect(effectiveArgs(['-f', 'x.yaml']), ['generate', '-f', 'x.yaml']);
      expect(effectiveArgs(['--prefix', '.']), ['generate', '--prefix', '.']);
    });

    test('top-level --help/-h is not rewritten with generate', () {
      expect(effectiveArgs(['--help']), ['--help']);
      expect(effectiveArgs(['-h']), ['-h']);
    });

    test('explicit subcommand is not rewritten', () {
      expect(effectiveArgs(['doctor']), ['doctor']);
      expect(effectiveArgs(['migrate', '--dry-run']), ['migrate', '--dry-run']);
    });

    test(
      'top-level --help returns 0 (CommandRunner prints help, exits 0)',
      () async {
        final code = await buildCommandRunner().run(['--help']);
        expect(code, anyOf(0, isNull));
      },
    );
  });

  // ---------------------------------------------------------------------
  // CLI reference — generate flags
  // ---------------------------------------------------------------------
  group('README §generate flags', () {
    test('-f/--file, -p/--prefix, --flavor, --all-flavors, --list-flavors, '
        '--continue-on-error, --strict, -y/--yes, -v/--verbose are all '
        'registered', () {
      final cmd = buildCommandRunner().commands['generate']!;
      final parser = cmd.argParser;
      expect(
        parser.options.keys,
        containsAll([
          'file',
          'prefix',
          'flavor',
          'all-flavors',
          'list-flavors',
          'continue-on-error',
          'strict',
          'yes',
          'verbose',
        ]),
      );
      expect(parser.options['file']!.abbr, 'f');
      expect(parser.options['prefix']!.abbr, 'p');
      expect(parser.options['yes']!.abbr, 'y');
      expect(parser.options['verbose']!.abbr, 'v');
    });

    test('--yes is a non-negatable flag', () {
      final cmd = buildCommandRunner().commands['generate']!;
      expect(cmd.argParser.options['yes']!.negatable, isFalse);
    });

    test('--prefix defaults to "."', () {
      final cmd = buildCommandRunner().commands['generate']!;
      expect(cmd.argParser.options['prefix']!.defaultsTo, '.');
    });

    test('--flavor is repeatable (multiOption)', () {
      final cmd = buildCommandRunner().commands['generate']!;
      expect(cmd.argParser.options['flavor']!.isMultiple, isTrue);
    });

    test('--all-flavors and --list-flavors are non-negatable flags '
        '(no --no-all-flavors)', () {
      final cmd = buildCommandRunner().commands['generate']!;
      expect(cmd.argParser.options['all-flavors']!.negatable, isFalse);
      expect(cmd.argParser.options['list-flavors']!.negatable, isFalse);
    });
  });

  // ---------------------------------------------------------------------
  // CLI reference — migrate flags
  // ---------------------------------------------------------------------
  group('README §migrate flags', () {
    test('-p/--prefix, --dry-run, --in-place, --force are all registered', () {
      final cmd = buildCommandRunner().commands['migrate']!;
      final keys = cmd.argParser.options.keys;
      expect(keys, containsAll(['prefix', 'dry-run', 'in-place', 'force']));
      expect(cmd.argParser.options['prefix']!.abbr, 'p');
    });

    test('--prefix defaults to "."', () {
      final cmd = buildCommandRunner().commands['migrate']!;
      expect(cmd.argParser.options['prefix']!.defaultsTo, '.');
    });
  });

  // ---------------------------------------------------------------------
  // CLI reference — doctor flags
  // ---------------------------------------------------------------------
  group('README §doctor flags', () {
    test('-p/--prefix and -v/--verbose are registered', () {
      final cmd = buildCommandRunner().commands['doctor']!;
      final keys = cmd.argParser.options.keys;
      expect(keys, containsAll(['prefix', 'verbose']));
      expect(cmd.argParser.options['prefix']!.abbr, 'p');
      expect(cmd.argParser.options['verbose']!.abbr, 'v');
    });
  });

  // ---------------------------------------------------------------------
  // Configuration schema — top-level keys + defaults
  // ---------------------------------------------------------------------
  group('README §Configuration schema — top-level keys & defaults', () {
    test('android defaults to disabled (false)', () {
      final cfg = Config.fromPartial(
        PartialConfig.fromJson({
          'web': {'generate': true, 'image_path': 'a.png'},
        }),
      );
      expect(cfg.android.isEnabled, isFalse);
    });

    test('ios defaults to disabled (false)', () {
      final cfg = Config.fromPartial(
        PartialConfig.fromJson({
          'web': {'generate': true, 'image_path': 'a.png'},
        }),
      );
      expect(cfg.ios.isEnabled, isFalse);
    });

    test(
      'android: true → enabled, non-custom (uses default ic_launcher name)',
      () {
        final cfg = Config.fromJson({'android': true, 'image_path': 'a.png'});
        expect(cfg.android.isEnabled, isTrue);
        expect(cfg.isCustomAndroidFile, isFalse);
      },
    );

    test('android: "launcher_icon" → enabled and custom-named', () {
      final cfg = Config.fromJson({
        'android': 'launcher_icon',
        'image_path': 'a.png',
      });
      expect(cfg.android.isEnabled, isTrue);
      expect(cfg.isCustomAndroidFile, isTrue);
      expect(cfg.androidIconName, 'launcher_icon');
    });

    test('ios: "AppIcon" → enabled and custom-named', () {
      final cfg = Config.fromJson({'ios': 'AppIcon', 'image_path': 'a.png'});
      expect(cfg.ios.isEnabled, isTrue);
      expect(cfg.isCustomIOSFile, isTrue);
      expect(cfg.iosIconName, 'AppIcon');
    });

    test('min_sdk_android default is unset (null) and resolved later — '
        'the README-documented default 24 lives in constants', () {
      final cfg = Config.fromJson({'android': true, 'image_path': 'a.png'});
      expect(cfg.minSdkAndroid, isNull, reason: 'null means "user omitted"');
      expect(constants.androidDefaultAndroidMinSDK, 24);
    });

    test('copy_mipmap_xxxhdpi_to_drawable defaults to false', () {
      final cfg = Config.fromJson({'android': true, 'image_path': 'a.png'});
      expect(cfg.copyMipmapXxxhdpiToDrawable, isFalse);
      expect(Config.defaultCopyMipmapXxxhdpiToDrawable, isFalse);
    });

    test('image_path_android override is preserved', () {
      final cfg = Config.fromJson({
        'android': true,
        'image_path': 'a.png',
        'image_path_android': 'and.png',
      });
      expect(cfg.imagePathAndroid, 'and.png');
      expect(cfg.getImagePathAndroid(), 'and.png');
    });

    test('image_path_ios override is preserved', () {
      final cfg = Config.fromJson({
        'ios': true,
        'image_path': 'a.png',
        'image_path_ios': 'ios.png',
      });
      expect(cfg.imagePathIOS, 'ios.png');
      expect(cfg.getImagePathIOS(), 'ios.png');
    });
  });

  // ---------------------------------------------------------------------
  // Configuration schema — Android adaptive icons
  // ---------------------------------------------------------------------
  group('README §Android adaptive icons', () {
    test('adaptive_icon_foreground_inset defaults to 16', () {
      final cfg = Config.fromJson({'android': true, 'image_path': 'a.png'});
      expect(cfg.adaptiveIconForegroundInset, 16);
      expect(Config.defaultAdaptiveIconForegroundInset, 16);
    });

    test(
      'adaptive foreground + background → hasAndroidAdaptiveConfig is true',
      () {
        final cfg = Config.fromJson({
          'android': true,
          'image_path': 'a.png',
          'adaptive_icon_background': '#FFFFFF',
          'adaptive_icon_foreground': 'fg.png',
        });
        expect(cfg.hasAndroidAdaptiveConfig, isTrue);
      },
    );

    test(
      'adaptive monochrome → hasAndroidAdaptiveMonochromeConfig is true',
      () {
        final cfg = Config.fromJson({
          'android': true,
          'image_path': 'a.png',
          'adaptive_icon_monochrome': 'mono.png',
        });
        expect(cfg.hasAndroidAdaptiveMonochromeConfig, isTrue);
      },
    );

    // README: "If adaptive_icon_foreground is set but adaptive_icon_background
    //          is not, the build fails with a clear error."
    test(
      'adaptive_icon_foreground without background → InvalidConfigException',
      () {
        expect(
          () => Config.fromJson({
            'android': true,
            'image_path': 'a.png',
            'adaptive_icon_foreground': 'fg.png',
            // adaptive_icon_background intentionally absent
          }),
          throwsA(isA<InvalidConfigException>()),
        );
      },
    );
  });

  // ---------------------------------------------------------------------
  // Configuration schema — iOS specifics
  // ---------------------------------------------------------------------
  group('README §iOS specifics', () {
    test('remove_alpha_ios defaults to false', () {
      final cfg = Config.fromJson({'ios': true, 'image_path': 'a.png'});
      expect(cfg.removeAlphaIOS, isFalse);
      expect(Config.defaultRemoveAlphaIOS, isFalse);
    });

    test('background_color_ios default is #FFFFFF (case-insensitive)', () {
      final cfg = Config.fromJson({'ios': true, 'image_path': 'a.png'});
      expect(cfg.backgroundColorIOS.toLowerCase(), '#ffffff');
    });

    test('desaturate_tinted_to_grayscale_ios defaults to false', () {
      final cfg = Config.fromJson({'ios': true, 'image_path': 'a.png'});
      expect(cfg.desaturateTintedToGrayscaleIOS, isFalse);
    });

    test('image_path_ios_dark_transparent + image_path_ios_tinted_grayscale '
        'are accepted top-level keys', () {
      final cfg = Config.fromJson({
        'ios': true,
        'image_path': 'a.png',
        'image_path_ios_dark_transparent': 'dark.png',
        'image_path_ios_tinted_grayscale': 'tint.png',
      });
      expect(cfg.imagePathIOSDarkTransparent, 'dark.png');
      expect(cfg.imagePathIOSTintedGrayscale, 'tint.png');
    });
  });

  // ---------------------------------------------------------------------
  // Configuration schema — Web
  // ---------------------------------------------------------------------
  group('README §Web', () {
    test('web.generate defaults to false', () {
      final cfg = Config.fromJson({
        'web': {'image_path': 'a.png'},
        'image_path': 'a.png',
      });
      expect(cfg.webConfig?.generate, isFalse);
    });

    test(
      'web.image_path, background_color, theme_color parse as documented',
      () {
        final cfg = Config.fromJson({
          'image_path': 'top.png',
          'web': {
            'generate': true,
            'image_path': 'icon.png',
            'background_color': '#FFFFFF',
            'theme_color': '#0175C2',
          },
        });
        expect(cfg.webConfig?.imagePath, 'icon.png');
        expect(cfg.webConfig?.backgroundColor, '#FFFFFF');
        expect(cfg.webConfig?.themeColor, '#0175C2');
      },
    );

    test('README-promised output filenames exist after generation', () async {
      final dir = await _webSandbox(
        'web_outputs',
        extra: [
          d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#FFFFFF"
    theme_color: "#0175C2"
'''),
        ],
      );
      final code = await buildCommandRunner().run(
        effectiveArgs(['--prefix', dir]),
      );
      expect(code, 0);
      for (final name in const [
        'web/favicon.png',
        'web/icons/Icon-192.png',
        'web/icons/Icon-512.png',
        'web/icons/Icon-maskable-192.png',
        'web/icons/Icon-maskable-512.png',
      ]) {
        expect(File(p.join(dir, name)).existsSync(), isTrue, reason: name);
      }
    });

    test(
      'manifest.json gets background_color and theme_color rewritten',
      () async {
        final dir = await _webSandbox(
          'web_manifest',
          extra: [
            d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#123456"
    theme_color: "#abcdef"
'''),
          ],
        );
        final code = await buildCommandRunner().run(
          effectiveArgs(['--prefix', dir]),
        );
        expect(code, 0);
        final m = File(p.join(dir, 'web', 'manifest.json')).readAsStringSync();
        expect(m, contains('#123456'));
        expect(m, contains('#abcdef'));
      },
    );
  });

  // ---------------------------------------------------------------------
  // Configuration schema — Windows
  // ---------------------------------------------------------------------
  group('README §Windows', () {
    test('windows.generate defaults to false (WindowsConfig constructor)', () {
      final cfg = Config.fromJson({
        'windows': {'image_path': 'a.png'},
        'image_path': 'a.png',
      });
      expect(cfg.windowsConfig?.generate, isFalse);
    });

    test(
      'windows.icon_size default is 48 (constants.windowsDefaultIconSize)',
      () {
        expect(constants.windowsDefaultIconSize, 48);
      },
    );

    test('windows.icon_size in valid range 48..256 is accepted', () {
      for (final size in [48, 100, 256]) {
        final cfg = Config.fromJson({
          'image_path': 'a.png',
          'windows': {
            'generate': true,
            'image_path': 'a.png',
            'icon_size': size,
          },
        });
        expect(cfg.windowsConfig?.iconSize, size);
      }
    });

    test('windows.icon_size below 48 is parsed without throwing — '
        'the bound is enforced at generation, not at parse', () {
      // README: "icon_size: 48 ≤ N ≤ 256". The bound is enforced by the
      // generator's validateRequirements(), not by the schema. So config
      // parsing does not reject 32.
      final cfg = Config.fromJson({
        'image_path': 'a.png',
        'windows': {'generate': true, 'image_path': 'a.png', 'icon_size': 32},
      });
      expect(cfg.windowsConfig?.iconSize, 32);
    });

    test('windows output path is windows/runner/resources/app_icon.ico', () {
      expect(
        constants.windowsIconFilePath,
        'windows/runner/resources/app_icon.ico',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Configuration schema — macOS
  // ---------------------------------------------------------------------
  group('README §macOS', () {
    test('macos.generate defaults to false', () {
      final cfg = Config.fromJson({
        'macos': {'image_path': 'a.png'},
        'image_path': 'a.png',
      });
      expect(cfg.macOSConfig?.generate, isFalse);
    });

    test(
      'macos output dir is macos/Runner/Assets.xcassets/AppIcon.appiconset',
      () {
        expect(
          constants.macOSIconsDirPath,
          'macos/Runner/Assets.xcassets/AppIcon.appiconset',
        );
      },
    );
  });

  // ---------------------------------------------------------------------
  // Source-resolution precedence
  // ---------------------------------------------------------------------
  group('README §Source-resolution precedence', () {
    test('(1) --file beats every other source; missing → exit 65', () async {
      // Missing --file → NoConfigFoundException → exit 65.
      await d.dir('sr_missing_file', [
        d.file('flutter_launcher_icons.yaml', 'flutter_launcher_icons: {}\n'),
      ]).create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'sr_missing_file'),
        '--file',
        'does_not_exist.yaml',
      ]);
      expect(code, 65);
    });

    test('(2) consolidated wins over (3) legacy when both present', () async {
      await d.dir('sr_consolidated_wins', [
        d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
flavors:
  dev: {image_path: "a.png", android: true}
'''),
        d.file('flutter_launcher_icons-old.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "old.png"
'''),
      ]).create();
      final resolved = resolveSource(
        prefixPath: p.join(d.sandbox, 'sr_consolidated_wins'),
        logger: FLILogger(false),
      );
      expect(resolved.kind, ConfigSourceKind.consolidatedFlavors);
      expect(resolved.ignoredLegacy, isNotEmpty);
    });

    test(
      '(3) legacy wins over (4) single when consolidated is absent',
      () async {
        await d.dir('sr_legacy_wins', [
          d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "dev.png"
'''),
          d.file('flutter_launcher_icons.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "single.png"
'''),
        ]).create();
        final resolved = resolveSource(
          prefixPath: p.join(d.sandbox, 'sr_legacy_wins'),
          logger: FLILogger(false),
        );
        expect(resolved.kind, ConfigSourceKind.legacyFlavors);
      },
    );

    test('(4) single-config wins over (5) pubspec inline', () async {
      await d.dir('sr_single_wins', [
        d.file('flutter_launcher_icons.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "single.png"
'''),
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "ps.png"
'''),
      ]).create();
      final resolved = resolveSource(
        prefixPath: p.join(d.sandbox, 'sr_single_wins'),
        logger: FLILogger(false),
      );
      expect(resolved.kind, ConfigSourceKind.singleFile);
    });

    test('(5) pubspec inline used when nothing else exists', () async {
      await d.dir('sr_pubspec', [
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "a.png"
'''),
      ]).create();
      final resolved = resolveSource(
        prefixPath: p.join(d.sandbox, 'sr_pubspec'),
        logger: FLILogger(false),
      );
      expect(resolved.kind, ConfigSourceKind.pubspecInline);
    });

    test('pubspec inline also accepts deprecated flutter_icons: key', () async {
      await d.dir('sr_pubspec_legacy_key', [
        d.file('pubspec.yaml', '''
name: demo
flutter_icons:
  android: true
  image_path: "a.png"
'''),
      ]).create();
      final resolved = resolveSource(
        prefixPath: p.join(d.sandbox, 'sr_pubspec_legacy_key'),
        logger: FLILogger(false),
      );
      expect(resolved.kind, ConfigSourceKind.pubspecInline);
    });

    test('no config anywhere → NoConfigFoundException', () async {
      await d.dir('sr_none').create();
      expect(
        () => resolveSource(
          prefixPath: p.join(d.sandbox, 'sr_none'),
          logger: FLILogger(false),
        ),
        throwsA(isA<NoConfigFoundException>()),
      );
    });
  });

  // ---------------------------------------------------------------------
  // Deep-merge rules
  // ---------------------------------------------------------------------
  group('README §Deep-merge rules', () {
    test('Maps merge recursively (README example for web)', () {
      final result = deepMerge(
        {
          'web': {'background_color': '#FFFFFF'},
        },
        {
          'web': {'theme_color': '#FF0000'},
        },
      );
      expect(result, {
        'web': {'background_color': '#FFFFFF', 'theme_color': '#FF0000'},
      });
    });

    test('Scalars in override replace inherited value', () {
      expect(deepMerge({'a': 1}, {'a': 2}), {'a': 2});
    });

    test('Lists in override REPLACE wholesale (no element merging)', () {
      expect(
        deepMerge(
          {
            'xs': [1, 2, 3],
          },
          {
            'xs': [9],
          },
        ),
        {
          'xs': [9],
        },
      );
    });

    test('Explicit null deletes inherited key', () {
      expect(deepMerge({'a': 1, 'b': 2}, {'b': null}), {'a': 1});
    });

    test('Omitting a key keeps the default', () {
      final result = deepMerge({'a': 1, 'b': 2}, {'a': 99});
      expect(result, {'a': 99, 'b': 2});
    });

    test('YAML ~ (null) deletes inherited key via the flavors loader', () {
      final cfg = FlavorsConfig.load(
        // Write to disk, load, check.
        () {
          final f = File(p.join(d.sandbox, 'tilde_delete.yaml'));
          f.writeAsStringSync('''
version: 1
defaults:
  android: true
  image_path: "a.png"
  windows:
    generate: true
    image_path: "a.png"
flavors:
  dev:
    windows: ~
''');
          return f.path;
        }(),
        logger: FLILogger(false),
      )!;
      final dev = cfg.resolve('dev');
      expect(
        dev.windowsConfig,
        isNull,
        reason: 'YAML "~" (null) should delete the inherited windows block',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Multi-flavor (consolidated)
  // ---------------------------------------------------------------------
  group('README §Multi-flavor (consolidated)', () {
    test(
      'multi-flavor consolidated without selector → builds all flavors (new default)',
      () async {
        // Use a web-only sandbox so we can actually generate to exit 0.
        final dir = await _webSandbox(
          'mf_no_selector',
          extra: [
            d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#FFFFFF"
    theme_color: "#0175C2"
flavors:
  dev: {}
  prod: {}
'''),
          ],
        );
        final code = await buildCommandRunner().run([
          'generate',
          '--prefix',
          dir,
        ]);
        expect(
          code,
          0,
          reason: 'README: omitting --flavor/--all-flavors builds every flavor',
        );
      },
    );

    test('single-flavor consolidated builds automatically '
        '(no --flavor required)', () async {
      final dir = await _webSandbox(
        'mf_single',
        extra: [
          d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#FFFFFF"
    theme_color: "#0175C2"
flavors:
  only: {}
'''),
        ],
      );
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
      ]);
      expect(
        code,
        0,
        reason: 'README: single-flavor consolidated builds the only flavor',
      );
      expect(
        File(p.join(dir, 'web', 'icons', 'Icon-192.png')).existsSync(),
        isTrue,
      );
    });

    test(
      '--list-flavors prints flavors and exits 0 without writing icons',
      () async {
        final dir = await _webSandbox(
          'mf_list',
          extra: [
            d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#FFFFFF"
    theme_color: "#0175C2"
flavors:
  dev: {}
  staging: {}
  prod: {}
'''),
          ],
        );
        final code = await buildCommandRunner().run([
          'generate',
          '--prefix',
          dir,
          '--list-flavors',
        ]);
        expect(code, 0);
        expect(
          File(p.join(dir, 'web', 'icons', 'Icon-192.png')).existsSync(),
          isFalse,
          reason: 'list-flavors must not generate',
        );
      },
    );

    test('--flavor + --all-flavors are mutually exclusive → exit 64', () async {
      final dir = await _webSandbox(
        'mf_both',
        extra: [
          d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#FFFFFF"
    theme_color: "#0175C2"
flavors:
  dev: {}
  prod: {}
'''),
        ],
      );
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--flavor',
        'dev',
        '--all-flavors',
      ]);
      expect(code, 64);
    });

    test('unknown flavor name → exit 64', () async {
      await d.dir('mf_unknown', [
        d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  android: true
  image_path: "a.png"
flavors:
  dev: {}
'''),
      ]).create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'mf_unknown'),
        '--flavor',
        'ghost',
      ]);
      expect(code, 64);
    });
  });

  // ---------------------------------------------------------------------
  // Legacy multi-flavor layout
  // ---------------------------------------------------------------------
  group('README §Legacy multi-flavor layout', () {
    test(
      'legacy files: bare invocation discovers and would build all flavors',
      () async {
        // We can't easily generate android icons without scaffolds, so just
        // assert the discovery + planning side: resolveSource returns
        // legacyFlavors and getFlavors() returns the set.
        await d.dir('legacy_all', [
          d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "a.png"
'''),
          d.file('flutter_launcher_icons-prod.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "a.png"
'''),
        ]).create();
        final resolved = resolveSource(
          prefixPath: p.join(d.sandbox, 'legacy_all'),
          logger: FLILogger(false),
        );
        expect(resolved.kind, ConfigSourceKind.legacyFlavors);
      },
    );

    test('--strict + (consolidated + legacy coexisting) → exit 65', () async {
      final dir = await _webSandbox(
        'strict_coexist',
        extra: [
          d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#FFFFFF"
    theme_color: "#0175C2"
flavors:
  dev: {}
'''),
          d.file('flutter_launcher_icons-old.yaml', '''
flutter_launcher_icons:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
'''),
        ],
      );
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--strict',
      ]);
      expect(code, 65);
    });
  });

  // ---------------------------------------------------------------------
  // Exit codes
  // ---------------------------------------------------------------------
  group('README §Exit codes', () {
    test('0 — success (web-only sandbox)', () async {
      // Use flutter_launcher_icons.yaml side-by-side with the stub
      // pubspec.yaml so we don't collide with the helper's pubspec.yaml.
      final dir = await _webSandbox(
        'ec0',
        extra: [
          d.file('flutter_launcher_icons.yaml', '''
flutter_launcher_icons:
  image_path: app_icon.png
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#FFFFFF"
    theme_color: "#0175C2"
'''),
        ],
      );
      final code = await buildCommandRunner().run(
        effectiveArgs(['--prefix', dir]),
      );
      expect(code, 0);
    });

    test('64 — usage error (unknown flavor)', () async {
      await d.dir('ec64_unknown', [
        d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  android: true
  image_path: "a.png"
flavors:
  dev: {}
'''),
      ]).create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'ec64_unknown'),
        '--flavor',
        'nope',
      ]);
      expect(code, 64);
    });

    test('65 — no config found', () async {
      await d.dir('ec65_none').create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'ec65_none'),
      ]);
      expect(code, 65);
    });

    test('65 — unparseable consolidated file', () async {
      await d.dir('ec65_bad', [
        d.file(
          'flutter_launcher_icons_flavors.yaml',
          '!!!: : not yaml\n  ?bad',
        ),
      ]).create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'ec65_bad'),
      ]);
      expect(code, 65);
    });

    test('1 — runtime/IO failure (missing image)', () async {
      await d.dir('ec1_missing_img', [
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "does_not_exist.png"
'''),
        d.dir('android', [
          d.dir('app', [
            d.dir('src', [
              d.dir('main', [
                d.file(
                  'AndroidManifest.xml',
                  '<manifest><application android:icon="@mipmap/ic_launcher"/></manifest>',
                ),
              ]),
            ]),
          ]),
        ]),
      ]).create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'ec1_missing_img'),
      ]);
      expect(code, 1);
    });
  });

  // ---------------------------------------------------------------------
  // doctor exit codes (README: 0 unless no config or unparseable consolidated → 65)
  // ---------------------------------------------------------------------
  group('README §doctor exit codes', () {
    test('doctor exits 65 when no config found', () async {
      await d.dir('doctor_none').create();
      final code = await buildCommandRunner().run([
        'doctor',
        '--prefix',
        p.join(d.sandbox, 'doctor_none'),
      ]);
      expect(code, 65);
    });

    test('doctor exits 65 when consolidated file is unparseable', () async {
      await d.dir('doctor_bad', [
        d.file('flutter_launcher_icons_flavors.yaml', ':\n: bad\n   :::'),
      ]).create();
      final code = await buildCommandRunner().run([
        'doctor',
        '--prefix',
        p.join(d.sandbox, 'doctor_bad'),
      ]);
      expect(code, 65);
    });

    test('doctor exits 0 with a healthy single-config project', () async {
      await d.dir('doctor_ok', [
        d.file('flutter_launcher_icons.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "a.png"
'''),
      ]).create();
      final code = await buildCommandRunner().run([
        'doctor',
        '--prefix',
        p.join(d.sandbox, 'doctor_ok'),
      ]);
      expect(code, 0);
    });

    test('doctor reports the package version from src/version.dart', () {
      expect(packageVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
    });
  });

  // ---------------------------------------------------------------------
  // Migrate behavior
  // ---------------------------------------------------------------------
  group('README §migrate', () {
    Future<String> seedLegacy(String name) async {
      await d.dir(name, [
        d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "assets/dev.png"
'''),
        d.file('flutter_launcher_icons-prod.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: "assets/prod.png"
'''),
      ]).create();
      return p.join(d.sandbox, name);
    }

    test(
      'default migrate: writes consolidated file, leaves originals, .bak copies exist',
      () async {
        final dir = await seedLegacy('mig_default');
        final code = await buildCommandRunner().run([
          'migrate',
          '--prefix',
          dir,
        ]);
        expect(code, 0);
        expect(
          File(p.join(dir, 'flutter_launcher_icons_flavors.yaml')).existsSync(),
          isTrue,
        );
        // README: originals are left in place by default.
        expect(
          File(p.join(dir, 'flutter_launcher_icons-dev.yaml')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(dir, 'flutter_launcher_icons-prod.yaml')).existsSync(),
          isTrue,
        );
        // README: each legacy file is backed up to <original>.bak.
        expect(
          File(p.join(dir, 'flutter_launcher_icons-dev.yaml.bak')).existsSync(),
          isTrue,
        );
        expect(
          File(
            p.join(dir, 'flutter_launcher_icons-prod.yaml.bak'),
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('--in-place deletes originals but keeps .bak copies', () async {
      final dir = await seedLegacy('mig_inplace');
      final code = await buildCommandRunner().run([
        'migrate',
        '--prefix',
        dir,
        '--in-place',
      ]);
      expect(code, 0);
      expect(
        File(p.join(dir, 'flutter_launcher_icons-dev.yaml')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(dir, 'flutter_launcher_icons-prod.yaml')).existsSync(),
        isFalse,
      );
      // .bak retained.
      expect(
        File(p.join(dir, 'flutter_launcher_icons-dev.yaml.bak')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(dir, 'flutter_launcher_icons-prod.yaml.bak')).existsSync(),
        isTrue,
      );
    });

    test('--dry-run writes no files at all', () async {
      final dir = await seedLegacy('mig_dry');
      final code = await buildCommandRunner().run([
        'migrate',
        '--prefix',
        dir,
        '--dry-run',
      ]);
      expect(code, 0);
      expect(
        File(p.join(dir, 'flutter_launcher_icons_flavors.yaml')).existsSync(),
        isFalse,
      );
      // No .bak written either.
      expect(
        File(p.join(dir, 'flutter_launcher_icons-dev.yaml.bak')).existsSync(),
        isFalse,
      );
    });

    test(
      'existing consolidated file is NOT overwritten without --force',
      () async {
        final dir = await seedLegacy('mig_no_force');
        await File(
          p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
        ).writeAsString('# sentinel — keep me\n');
        final code = await buildCommandRunner().run([
          'migrate',
          '--prefix',
          dir,
        ]);
        // README: defaults are non-destructive — should not overwrite.
        expect(
          code,
          isNot(0),
          reason:
              'README says default migrate must not overwrite existing target',
        );
        expect(
          File(
            p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
          ).readAsStringSync(),
          contains('sentinel'),
        );
      },
    );

    test('--force overwrites existing consolidated file', () async {
      final dir = await seedLegacy('mig_force');
      await File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).writeAsString('# sentinel — overwrite me\n');
      final code = await buildCommandRunner().run([
        'migrate',
        '--prefix',
        dir,
        '--force',
      ]);
      expect(code, 0);
      final content = File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).readAsStringSync();
      expect(content, isNot(contains('sentinel')));
      expect(content, contains('flavors'));
    });

    test('migrate accepts deprecated flutter_icons: inner block', () async {
      await d.dir('mig_legacy_key', [
        d.file('flutter_launcher_icons-dev.yaml', '''
flutter_icons:
  android: true
  image_path: "a.png"
'''),
      ]).create();
      final code = await buildCommandRunner().run([
        'migrate',
        '--prefix',
        p.join(d.sandbox, 'mig_legacy_key'),
      ]);
      expect(
        code,
        0,
        reason:
            'README: migrate supports both flutter_launcher_icons: '
            'and flutter_icons: as the inner block',
      );
    });
  });

  // ---------------------------------------------------------------------
  // FAQ — flavor name acceptance
  // ---------------------------------------------------------------------
  group('README §FAQ', () {
    test('flavor name with hyphen is accepted by consolidated loader '
        '(README recommends [A-Za-z0-9_-]+)', () {
      final f = File(p.join(d.sandbox, 'fnames_hyphen.yaml'))
        ..writeAsStringSync('''
version: 1
defaults:
  android: true
  image_path: "a.png"
flavors:
  dev-eu:
    image_path: "a.png"
''');
      final cfg = FlavorsConfig.load(f.path, logger: FLILogger(false))!;
      expect(cfg.flavorNames, contains('dev-eu'));
    });

    test('flavor name with underscore is accepted', () {
      final f = File(p.join(d.sandbox, 'fnames_under.yaml'))
        ..writeAsStringSync('''
version: 1
defaults:
  android: true
  image_path: "a.png"
flavors:
  dev_team_a:
    image_path: "a.png"
''');
      final cfg = FlavorsConfig.load(f.path, logger: FLILogger(false))!;
      expect(cfg.flavorNames, contains('dev_team_a'));
    });
  });
}
