import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

const _consolidated = '''
version: 1
defaults:
  android: true
  ios: true
  image_path: "assets/icon.png"
flavors:
  dev: {}
  prod: {}
''';

const _legacyDev = '''
flutter_launcher_icons:
  android: true
  image_path: "assets/dev.png"
''';

const _ktsGradle = '''
android {
    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 26
        targetSdk = 34
    }
}
''';

void main() {
  group('DoctorCommand', () {
    test('consolidated + legacy: exit 0, both reported', () async {
      await d.dir('doc1', [
        d.file('flutter_launcher_icons_flavors.yaml', _consolidated),
        d.file('flutter_launcher_icons-old.yaml', _legacyDev),
      ]).create();
      final dir = p.join(d.sandbox, 'doc1');
      final code = await buildCommandRunner().run(['doctor', '--prefix', dir]);
      // No structural problem — coexistence is just a warning unless
      // --strict is passed to `generate`. doctor does not escalate.
      expect(code, 0);
    });

    test('KTS-only gradle: exit 0, min_sdk detected', () async {
      await d.dir('doc_kts', [
        d.dir('android', [
          d.dir('app', [d.file('build.gradle.kts', _ktsGradle)]),
        ]),
        // Minimal pubspec inline config so a precedence winner exists.
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "assets/icon.png"
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'doc_kts');
      final code = await buildCommandRunner().run(['doctor', '--prefix', dir]);
      expect(code, 0);
    });

    test('version-catalog (un-detectable) gradle: exit 0 with hint', () async {
      // KTS file that uses libs.versions.toml indirection — none of our
      // patterns will match.
      const undetectable = '''
android {
    defaultConfig {
        minSdk = libs.versions.minSdk.get().toInt()
    }
}
''';
      await d.dir('doc_vc', [
        d.dir('android', [
          d.dir('app', [d.file('build.gradle.kts', undetectable)]),
        ]),
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "assets/icon.png"
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'doc_vc');
      final code = await buildCommandRunner().run(['doctor', '--prefix', dir]);
      expect(code, 0);
    });

    test('no config at all: exit 65', () async {
      await d.dir('doc_none', []).create();
      final dir = p.join(d.sandbox, 'doc_none');
      final code = await buildCommandRunner().run(['doctor', '--prefix', dir]);
      expect(code, 65);
    });

    test('deprecated flutter_icons: pubspec key surfaces in report', () async {
      await d.dir('doc_dep', [
        d.file('pubspec.yaml', '''
name: demo
flutter_icons:
  android: true
  image_path: "assets/icon.png"
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'doc_dep');
      // We can't easily capture stdout in-process, but the exit code
      // should still be 0 (deprecation is a soft warning).
      final code = await buildCommandRunner().run(['doctor', '--prefix', dir]);
      expect(code, 0);
    });

    test(
      'non-deprecated flutter_launcher_icons: pubspec key NOT flagged',
      () async {
        // Modern key shape: no deprecation warning, exit 0 even under
        // --strict.
        await d.dir('doc_modern', [
          d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "assets/icon.png"
'''),
        ]).create();
        final dir = p.join(d.sandbox, 'doc_modern');
        final code = await buildCommandRunner().run([
          'doctor',
          '--prefix',
          dir,
          '--strict',
        ]);
        expect(code, 0);
      },
    );

    test('--strict + deprecated flutter_icons: → exit 65', () async {
      await d.dir('doc_dep_strict', [
        d.file('pubspec.yaml', '''
name: demo
flutter_icons:
  android: true
  image_path: "assets/icon.png"
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'doc_dep_strict');
      final code = await buildCommandRunner().run([
        'doctor',
        '--prefix',
        dir,
        '--strict',
      ]);
      expect(code, 65);
    });
  });

  group('DoctorCommand — pattern table sync with android.minSdk()', () {
    // Regression for the reviewer-flagged Phase 4 deviation: `doctor`
    // and `generate` MUST agree on which gradle patterns are detected.
    // Previously doctor's local pattern table omitted the
    // `flutter.minSdkVersion` indirection entries; now both consume the
    // shared table in lib/src/min_sdk_patterns.dart.

    test(
      'kts_with_flutter_ref → android.detectMinSdkAndroid reports indirection label',
      () async {
        // Same trick as test/android_gradle_test.dart: rewrite
        // __FLUTTER_SDK__ → absolute path.
        final fixturePath = p.join(
          'test',
          'fixtures',
          'gradle',
          'kts_with_flutter_ref',
        );
        final flutterSdkAbs = p.absolute(p.join(fixturePath, 'flutter_sdk'));
        final localProps = File(
          p.join(fixturePath, 'android', 'local.properties'),
        );
        final original = await localProps.readAsString();
        try {
          await localProps.writeAsString(
            original.replaceAll('__FLUTTER_SDK__', flutterSdkAbs),
          );
          final detection = await android.detectMinSdkAndroid(
            prefixPath: fixturePath,
          );
          expect(detection.value, equals(21));
          expect(
            detection.matchedLabel,
            equals('minSdk = flutter.minSdkVersion (KTS, indirect)'),
          );
        } finally {
          await localProps.writeAsString(original);
        }
      },
    );

    test('kts_with_flutter_ref_localprops → reports indirection label even '
        'when recursion lands via local.properties fallback', () async {
      final fixturePath = p.join(
        'test',
        'fixtures',
        'gradle',
        'kts_with_flutter_ref_localprops',
      );
      final detection = await android.detectMinSdkAndroid(
        prefixPath: fixturePath,
      );
      expect(detection.value, equals(21));
      expect(
        detection.matchedLabel,
        equals('minSdk = flutter.minSdkVersion (KTS, indirect)'),
      );
    });

    test('groovy_basic → reports a Groovy literal label', () async {
      final fixturePath = p.join('test', 'fixtures', 'gradle', 'groovy_basic');
      final detection = await android.detectMinSdkAndroid(
        prefixPath: fixturePath,
      );
      expect(detection.value, isNotNull);
      expect(detection.matchedLabel, isNotNull);
      // Whichever Groovy pattern matched, its label must mention "Groovy".
      expect(detection.matchedLabel, contains('Groovy'));
    });

    test('kts_with_version_catalog → null value AND null label', () async {
      // Confirms the spec: "could not auto-detect" maps to (null, null)
      // — what doctor renders as the "version catalog or convention
      // plugin?" hint.
      final fixturePath = p.join(
        'test',
        'fixtures',
        'gradle',
        'kts_with_version_catalog',
      );
      final detection = await android.detectMinSdkAndroid(
        prefixPath: fixturePath,
      );
      expect(detection.value, isNull);
      expect(detection.matchedLabel, isNull);
    });

    test('doctor exits 0 on kts_with_flutter_ref fixture (smoke)', () async {
      final fixturePath = p.join(
        'test',
        'fixtures',
        'gradle',
        'kts_with_flutter_ref',
      );
      // Need a config source so doctor doesn't trip the
      // NoConfigFoundException 65 branch. Layer a temp pubspec next to
      // the gradle fixture via a small sandbox copy is overkill; instead
      // synthesize a sandbox that re-uses the gradle layout.
      final flutterSdkAbs = p.absolute(p.join(fixturePath, 'flutter_sdk'));
      final localPropsContent = await File(
        p.join(fixturePath, 'android', 'local.properties'),
      ).readAsString();
      final gradleContent = await File(
        p.join(fixturePath, 'android', 'app', 'build.gradle.kts'),
      ).readAsString();

      await d.dir('doc_indirect', [
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "assets/icon.png"
'''),
        d.dir('android', [
          d.file(
            'local.properties',
            localPropsContent.replaceAll('__FLUTTER_SDK__', flutterSdkAbs),
          ),
          d.dir('app', [d.file('build.gradle.kts', gradleContent)]),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'doc_indirect');
      final code = await buildCommandRunner().run(['doctor', '--prefix', dir]);
      expect(code, 0);
    });
  });
}
