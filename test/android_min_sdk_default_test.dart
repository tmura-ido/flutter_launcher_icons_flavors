import 'dart:io';

import 'package:flutter_launcher_icons_flavored/android.dart' as android;
import 'package:flutter_launcher_icons_flavored/config/config.dart';
import 'package:flutter_launcher_icons_flavored/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Phase 2 §1.2 + reviewer follow-up — `androidDefaultAndroidMinSDK` was bumped
/// to 24 *and* the autodetect pipeline is now wired into the resolver. These
/// tests pin both the new constant and the resolution order:
///
///   explicit user value → autodetect from gradle → static default (with warn)
void main() {
  group('androidDefaultAndroidMinSDK (Phase 2 §1.2)', () {
    test('is 24', () {
      expect(constants.androidDefaultAndroidMinSDK, equals(24));
    });
  });

  group('Config.fromJson — min_sdk_android raw value', () {
    test('omitted min_sdk_android → Config.minSdkAndroid is null '
        '(resolution deferred to pipeline)', () {
      final config = Config.fromJson({
        'image_path': 'assets/icon.png',
        'android': true,
      });
      expect(config.minSdkAndroid, isNull);
    });

    test('explicit min_sdk_android: 21 → preserved as 21', () {
      final config = Config.fromJson({
        'image_path': 'assets/icon.png',
        'android': true,
        'min_sdk_android': 21,
      });
      expect(config.minSdkAndroid, equals(21));
    });

    test('explicit min_sdk_android: 24 → preserved as 24', () {
      final config = Config.fromJson({
        'image_path': 'assets/icon.png',
        'android': true,
        'min_sdk_android': 24,
      });
      expect(config.minSdkAndroid, equals(24));
    });

    test('explicit values are passed through verbatim, not clamped', () {
      final c19 = Config.fromJson({
        'image_path': 'a.png',
        'android': true,
        'min_sdk_android': 19,
      });
      expect(c19.minSdkAndroid, 19);

      final c30 = Config.fromJson({
        'image_path': 'a.png',
        'android': true,
        'min_sdk_android': 30,
      });
      expect(c30.minSdkAndroid, 30);
    });
  });

  group('Config() default constructor', () {
    test('uses null for minSdkAndroid when omitted (no implicit default)', () {
      final config = Config(imagePath: 'assets/icon.png');
      expect(config.minSdkAndroid, isNull);
    });
  });

  group('android.resolveMinSdkAndroid — resolution order', () {
    final fixturesRoot = path.join('test', 'fixtures', 'gradle');
    late FLILogger logger;

    setUp(() {
      logger = FLILogger(false);
    });

    test('explicit user value wins, autodetect is skipped', () async {
      // The fixture would autodetect 24, but the explicit 21 overrides it.
      final fixturePath = path.join(fixturesRoot, 'kts_basic');
      final resolved = await android.resolveMinSdkAndroid(
        prefixPath: fixturePath,
        logger: logger,
        explicit: 21,
      );
      expect(resolved, equals(21));
    });

    test('omitted + gradle says 26 → 26 (autodetect succeeds)', () async {
      final fixturePath = path.join(fixturesRoot, 'kts_call_form');
      final resolved = await android.resolveMinSdkAndroid(
        prefixPath: fixturePath,
        logger: logger,
        explicit: null,
      );
      expect(resolved, equals(26));
    });

    test('omitted + gradle says 23 → 23', () async {
      final fixturePath = path.join(fixturesRoot, 'groovy_with_eq');
      final resolved = await android.resolveMinSdkAndroid(
        prefixPath: fixturePath,
        logger: logger,
        explicit: null,
      );
      expect(resolved, equals(23));
    });

    test('omitted + no gradle at all → falls back to '
        'androidDefaultAndroidMinSDK (24)', () async {
      final tempDir = Directory.systemTemp.createTempSync('fli_resolve_');
      try {
        final resolved = await android.resolveMinSdkAndroid(
          prefixPath: tempDir.path,
          logger: logger,
          explicit: null,
        );
        expect(resolved, equals(constants.androidDefaultAndroidMinSDK));
        expect(resolved, equals(24));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'omitted + unparseable gradle (version catalog) → 24 fallback',
      () async {
        final fixturePath = path.join(fixturesRoot, 'kts_with_version_catalog');
        final resolved = await android.resolveMinSdkAndroid(
          prefixPath: fixturePath,
          logger: logger,
          explicit: null,
        );
        expect(resolved, equals(24));
      },
    );

    test(
      'omitted + unparseable gradle (convention plugin) → 24 fallback',
      () async {
        final fixturePath = path.join(fixturesRoot, 'convention_plugin');
        final resolved = await android.resolveMinSdkAndroid(
          prefixPath: fixturePath,
          logger: logger,
          explicit: null,
        );
        expect(resolved, equals(24));
      },
    );
  });
}
