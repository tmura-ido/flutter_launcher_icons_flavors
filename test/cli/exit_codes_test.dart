import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Verifies every documented exit code from plan §1.2 is reachable.
///
///   * 0  — successful generate (covered separately in
///          `generate_command_test.dart`).
///   * 1  — runtime/IO failure during generation. Triggered here by
///          giving `generate` a config that points at a missing image.
///   * 64 — usage error. Triggered by passing an unknown flavor.
///   * 65 — config / `NoConfigFoundException`. Triggered by running
///          `generate` against an empty directory.
void main() {
  group('exit codes — every documented code is reachable', () {
    test('64 — usage error (unknown flavor)', () async {
      await d.dir('ec64', [
        d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  android: true
  image_path: "assets/icon.png"
flavors:
  dev: {}
'''),
      ]).create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'ec64'),
        '--flavor',
        'ghost',
      ]);
      expect(code, 64);
    });

    test('65 — NoConfigFoundException', () async {
      await d.dir('ec65', []).create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'ec65'),
      ]);
      expect(code, 65);
    });

    test('1 — generation/IO failure (image file missing)', () async {
      await d.dir('ec1', [
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "missing.png"
'''),
        // android scaffolding so `generate` reaches image decode
        // before failing.
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
        p.join(d.sandbox, 'ec1'),
      ]);
      // Image file missing surfaces as a runtime IO error → exit 1.
      expect(code, 1);
    });

    test('65 — InvalidConfigException thrown DURING per-flavor generation '
        '(post-preflight) in consolidated multi-flavor flow', () async {
      // Regression for the reviewer-flagged Phase 4 deviation: the
      // per-flavor catch in _runConsolidated was bare and routed
      // every exception to exit 1. InvalidConfigException must
      // surface as a config error (65) per the exit-code matrix.
      //
      // Construction trick: a flavor with all platforms disabled and
      // no image_path passes Config.fromPartial validation
      // (hasAnyPlatform=false → no exception) but trips the
      // `hasPlatformConfig` guard at the top of
      // createIconsFromConfig, throwing InvalidConfigException
      // AFTER preflight.
      await d.dir('ec65b', [
        d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults: {}
flavors:
  empty1:
    android: false
    ios: false
  empty2:
    android: false
    ios: false
'''),
      ]).create();
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        p.join(d.sandbox, 'ec65b'),
        '--all-flavors',
      ]);
      expect(
        code,
        65,
        reason: 'InvalidConfigException post-preflight must map to 65',
      );
    });
  });
}
