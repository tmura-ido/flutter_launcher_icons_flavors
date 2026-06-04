import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:flutter_launcher_icons_flavors/main.dart'
    show defaultConfigFile;
import 'package:flutter_launcher_icons_flavors/main.dart' as main_dart;
import 'package:path/path.dart' show join;
import 'package:test/test.dart';

// Unit tests for main.dart
void main() {
  // Anchor for the temp working dirs used by the "config file from args"
  // group below. Captured once at suite-load time; the group feeds these
  // dirs to the loader via `--prefix` and never mutates the process-global
  // `Directory.current` (which is shared across concurrently-running test
  // suites — mutating it here used to yank sibling suites into the wrong
  // directory and fail them with flaky PathNotFoundExceptions).
  final String projectRoot = Directory.current.path;

  test('iOS icon list is correct size', () {
    expect(ios.iosIcons.length, 16);
  });

  test('iOS legacy icon list is correct size', () {
    expect(ios.legacyIosIcons.length, 21);
  });

  test('Android icon list is correct size', () {
    expect(android.androidIcons.length, 5);
  });

  test(
    'iOS image list used to generate legacy Contents.json for icon directory is correct size (no dark or tinted icons)',
    () {
      expect(ios.createLegacyImageList('blah').length, 25);
    },
  );

  test(
    'iOS image list used to generate Contents.json for icon directory is correct size (with dark icon)',
    () {
      expect(
        ios.createImageList('blah', 'dark-blah', null).length,
        16 * 2 + 1,
      ); // 16 normal, 16 dark icons + 1 marketing icon
    },
  );

  test(
    'iOS image list used to generate Contents.json for icon directory is correct size (with tinted icon)',
    () {
      expect(
        ios.createImageList('blah', null, 'tinted-blah').length,
        16 * 2 + 1,
      ); // 16 normal, 16 tinted icons + 1 marketing icon
    },
  );

  test(
    'iOS image list used to generate Contents.json for icon directory is correct size (with dark and tinted icon)',
    () {
      expect(
        ios.createImageList('blah', 'dark-blah', 'tinted-blah').length,
        16 * 3 + 1,
      ); // 16 normal, 16 dark, 16 tinted icons + 1 marketing icon
    },
  );

  group('config file from args', () {
    // Create mini parser with only the wanted option, mocking the real one
    final ArgParser parser = ArgParser()
      ..addOption(
        main_dart.fileOption,
        abbr: 'f',
        defaultsTo: defaultConfigFile,
      )
      ..addOption(main_dart.prefixOption, abbr: 'p', defaultsTo: '.');
    final String testDir = join(
      projectRoot,
      '.dart_tool',
      'flutter_launcher_icons',
      'test',
      'config_file',
    );

    // Returns a fresh, absolute working dir. We pass this to the loader via
    // `--prefix` instead of chdir-ing: `loadConfigFromPath` /
    // `loadConfigFromPubSpec` already resolve every path under the prefix, so
    // no `Directory.current` mutation is needed (and mutating it would flake
    // sibling suites — see the note in main() above).
    Future<String> workDir(String name) async {
      final dir = Directory(join(testDir, name));
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await dir.create(recursive: true);
      return dir.path;
    }

    test('default', () async {
      final dir = await workDir('default');
      await File(join(dir, 'flutter_launcher_icons.yaml')).writeAsString('''
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon.png"
''');
      final ArgResults argResults = parser.parse(<String>['-p', dir]);
      final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
      expect(config, isNotNull);
      expect(config!.android.isEnabled, isTrue);
    });
    test('default_use_pubspec', () async {
      final dir = await workDir('pubspec_only');
      await File(join(dir, 'pubspec.yaml')).writeAsString('''
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon.png"
''');
      ArgResults argResults = parser.parse(<String>['-p', dir]);
      final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
      expect(config, isNotNull);
      expect(config!.ios.isEnabled, isFalse);

      // read pubspec if provided file is not found
      argResults = parser.parse(<String>['-p', dir, '-f', defaultConfigFile]);
      expect(main_dart.loadConfigFileFromArgResults(argResults), isNotNull);
    });

    test('custom', () async {
      final dir = await workDir('custom');
      await File(join(dir, 'custom.yaml')).writeAsString('''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon.png"
''');
      // explicit --file resolves the custom config under the prefix
      ArgResults argResults = parser.parse(<String>[
        '-p',
        dir,
        '-f',
        'custom.yaml',
      ]);
      final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
      expect(config, isNotNull);
      expect(config!.ios.isEnabled, isTrue);

      // no --file: default lookup finds neither flutter_launcher_icons.yaml
      // nor pubspec.yaml under the prefix, so it should fail
      argResults = parser.parse(<String>['-p', dir]);
      expect(main_dart.loadConfigFileFromArgResults(argResults), isNull);

      // or missing file
      argResults = parser.parse(<String>[
        '-p',
        dir,
        '-f',
        'missing_custom.yaml',
      ]);
      expect(main_dart.loadConfigFileFromArgResults(argResults), isNull);
    });
  });

  test('image_path is in config', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': true,
      'ios': true,
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(
      config.getImagePathAndroid(),
      equals('assets/images/icon-710x599.png'),
    );
    expect(config.getImagePathIOS(), equals('assets/images/icon-710x599.png'));
    final Map<String, dynamic> flutterIconsConfigAndroid = <String, dynamic>{
      'image_path_android': 'assets/images/icon-710x599.png',
      'android': true,
      'ios': true,
    };
    final configAndroid = Config.fromJson(flutterIconsConfigAndroid);
    expect(
      configAndroid.getImagePathAndroid(),
      equals('assets/images/icon-710x599.png'),
    );
    expect(configAndroid.getImagePathIOS(), isNull);
    final Map<String, dynamic> flutterIconsConfigBoth = <String, dynamic>{
      'image_path_android': 'assets/images/icon-android.png',
      'image_path_ios': 'assets/images/icon-ios.png',
      'android': true,
      'ios': true,
    };
    final configBoth = Config.fromJson(flutterIconsConfigBoth);
    expect(
      configBoth.getImagePathAndroid(),
      equals('assets/images/icon-android.png'),
    );
    expect(configBoth.getImagePathIOS(), equals('assets/images/icon-ios.png'));
  });

  test('At least one platform is in config file', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': true,
      'ios': true,
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasPlatformConfig, isTrue);
  });

  test('No platform specified in config', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasPlatformConfig, isFalse);
  });

  test('No new Android icon needed - android: false', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': false,
      'ios': true,
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasAndroidConfig, isFalse);
  });

  test('No new Android icon needed - no Android config', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'ios': true,
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasAndroidConfig, isFalse);
  });

  test('No new iOS icon needed - ios: false', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': true,
      'ios': false,
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasIOSConfig, isFalse);
  });

  test('No new iOS icon needed - no iOS config', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': true,
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasIOSConfig, isFalse);
  });
}
