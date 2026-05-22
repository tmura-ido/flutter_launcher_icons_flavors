import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #632.
/// See: issues/issue-632-android-icon-name-ignored.md
///
/// `android: "ic_launcher"` is documented to use that string as the
/// generated resource name. The upstream report was that files were still
/// written as `launcher_icon`. The fork's `Config.androidIconName` is
/// surfaced through `isCustomAndroidFile`; this test confirms the value is
/// preserved and used end-to-end across:
///   - `config.androidIconName` parsing
///   - mipmap PNG filenames written by `createDefaultIcons`
///   - the `android:icon=` attribute in the rewritten manifest
void main() {
  group('issue #632: android: "<name>" is honored end-to-end', () {
    test('Config exposes the literal custom name', () {
      final cfg = Config.fromJson({
        'image_path': 'a.png',
        'android': 'ic_launcher_custom',
      });
      expect(cfg.isCustomAndroidFile, isTrue);
      expect(cfg.androidIconName, 'ic_launcher_custom');
    });

    test('createDefaultIcons writes <name>.png into each mipmap-* directory '
        'and updates AndroidManifest.xml to @mipmap/<name>', () async {
      // Build a tiny 1x1 source PNG.
      final src = Image(width: 1, height: 1);
      src.getPixel(0, 0).setRgba(255, 255, 255, 255);

      const customName = 'ic_my_brand';

      await d.dir('proj', [
        d.file('a.png', encodePng(src)),
        d.dir('android', [
          d.dir('app', [
            d.dir('src', [
              d.dir('main', [
                d.file(
                  'AndroidManifest.xml',
                  '<?xml version="1.0" encoding="utf-8"?>\n'
                      '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
                      '  <application android:icon="@mipmap/ic_launcher"/>\n'
                      '</manifest>\n',
                ),
                d.dir('res'),
              ]),
            ]),
          ]),
        ]),
      ]).create();

      final prefix = p.join(d.sandbox, 'proj');
      final cfg = Config.fromJson({
        'image_path': 'a.png',
        'android': customName,
      });

      await android.createDefaultIcons(
        cfg,
        null,
        logger: FLILogger(false),
        prefixPath: prefix,
      );

      // (1) Custom-named files should land in every mipmap-* dir.
      for (final t in android.androidIcons) {
        final f = File(
          p.join(
            prefix,
            constants.androidResFolder(null),
            t.directoryName,
            '$customName.png',
          ),
        );
        expect(
          f.existsSync(),
          isTrue,
          reason:
              'Expected $customName.png in ${t.directoryName} when '
              'android: "$customName"',
        );
      }

      // (2) AndroidManifest.xml must reference @mipmap/<customName>.
      final manifest = File(
        p.join(prefix, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      ).readAsStringSync();
      expect(manifest, contains('@mipmap/$customName'));
      expect(manifest, isNot(contains('@mipmap/ic_launcher"')));
    });
  });
}
