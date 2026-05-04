import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Real assets/app_icon.png bytes — used to seed sandboxes that need
/// a valid image so the success path actually exits 0.
List<int> _assetBytes() => File(
  p.join(Directory.current.path, 'test', 'assets', 'app_icon.png'),
).readAsBytesSync();

/// We trigger per-flavor generation failures by enabling android
/// with a missing `image_path`. `createDefaultIcons` synchronously
/// throws a `FileSystemException` from `decodeImageFile` → the
/// per-flavor catch in `GenerateCommand` sees a real propagated
/// error.
///
/// Web is intentionally NOT used here for the failure path because
/// `lib/abs/icon_generator.dart::generateIconsFor` swallows
/// per-platform exceptions and returns successfully even when the
/// underlying generator failed. That swallowing is unrelated to
/// `--continue-on-error` and is preserved for backward compatibility.
const _androidManifest =
    '<manifest><application android:icon="@mipmap/ic_launcher"/></manifest>';

void main() {
  group('--continue-on-error', () {
    test(
      'failures: hard mode → exit 1, soft mode → exit 1 (continues)',
      () async {
        const yaml = '''
version: 1
defaults:
  android: true
  image_path: "missing.png"
flavors:
  good:
    image_path: "still_missing_good.png"
  bad:
    image_path: "still_missing_bad.png"
''';
        await d.dir('coe', [
          d.dir('android', [
            d.dir('app', [
              d.dir('src', [
                d.dir('main', [
                  d.file('AndroidManifest.xml', _androidManifest),
                ]),
              ]),
            ]),
          ]),
          d.file('pubspec.yaml', 'name: demo\n'),
          d.file('flutter_launcher_icons_flavors.yaml', yaml),
        ]).create();
        final dir = p.join(d.sandbox, 'coe');

        // Hard mode: aborts on the first failure → exit 1.
        final hardCode = await buildCommandRunner().run([
          'generate',
          '--prefix',
          dir,
          '--all-flavors',
        ]);
        expect(hardCode, 1);

        // Soft mode: visits every flavor; every flavor still fails → exit 1.
        // The key behavior under test is that the runner doesn't bail on the
        // first failure — both flavors are attempted.
        final softCode = await buildCommandRunner().run([
          'generate',
          '--prefix',
          dir,
          '--all-flavors',
          '--continue-on-error',
        ]);
        expect(softCode, 1);
      },
    );

    test(
      'all flavors succeed → exit 0 even with --continue-on-error',
      () async {
        // Web generates a real, succeeding flavor. Two flavors share the
        // same valid image — both succeed → runner returns 0.
        const yaml = '''
version: 1
defaults:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
flavors:
  a: {}
  b: {}
''';
        await d.dir('coe_ok', [
          d.dir('web', [
            d.dir('icons'),
            d.file('index.html', templates.webIndexTemplate),
            d.file('manifest.json', templates.webManifestTemplate),
          ]),
          d.file('app_icon.png', _assetBytes()),
          d.file('pubspec.yaml', 'name: demo\n'),
          d.file('flutter_launcher_icons_flavors.yaml', yaml),
        ]).create();
        final code = await buildCommandRunner().run([
          'generate',
          '--prefix',
          p.join(d.sandbox, 'coe_ok'),
          '--all-flavors',
          '--continue-on-error',
        ]);
        expect(code, 0);
      },
    );
  });
}
