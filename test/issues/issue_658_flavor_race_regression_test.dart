import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression for upstream issue #658 (bundled into #626).
/// See: issues/approved/issue-626-android-flavor-resource-folder.md
///
/// Two flavors running back-to-back must each land in their own
/// `src/<flavor>/res/` tree with their own icon bytes. The fork's
/// `androidResFolder(flavor)` plumbing makes this true; this test is the
/// regression guard so it stays true.
void main() {
  group('issue #658: flavor outputs do not overwrite each other', () {
    test('two flavors back-to-back keep distinct icon bytes', () async {
      // Build two source images with distinct colors.
      Image makeSrc(int r, int g, int b) {
        final img = Image(width: 192, height: 192);
        for (final px in img) {
          px.setRgba(r, g, b, 255);
        }
        return img;
      }

      final stgBytes = encodePng(makeSrc(255, 0, 0));
      final prdBytes = encodePng(makeSrc(0, 255, 0));

      await d.dir('proj_658', [
        d.file('stg.png', stgBytes),
        d.file('prd.png', prdBytes),
        d.dir('android', [
          d.dir('app', [
            d.dir('src', [
              d.dir('main', [
                d.file(
                  'AndroidManifest.xml',
                  '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                      '<application android:icon="@mipmap/ic_launcher"/>'
                      '</manifest>',
                ),
              ]),
            ]),
          ]),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_658');

      final stgCfg = Config.fromJson(<String, dynamic>{
        'image_path': 'stg.png',
        'android': true,
      });
      final prdCfg = Config.fromJson(<String, dynamic>{
        'image_path': 'prd.png',
        'android': true,
      });

      await android.createDefaultIcons(
        stgCfg,
        'stg',
        logger: FLILogger(false),
        prefixPath: dir,
      );
      await android.createDefaultIcons(
        prdCfg,
        'prd',
        logger: FLILogger(false),
        prefixPath: dir,
      );

      final stgOut = File(
        p.join(
          dir,
          'android',
          'app',
          'src',
          'stg',
          'res',
          'mipmap-xxxhdpi',
          'ic_launcher.png',
        ),
      );
      final prdOut = File(
        p.join(
          dir,
          'android',
          'app',
          'src',
          'prd',
          'res',
          'mipmap-xxxhdpi',
          'ic_launcher.png',
        ),
      );
      expect(stgOut.existsSync(), isTrue);
      expect(prdOut.existsSync(), isTrue);

      final stgPixel = decodePng(stgOut.readAsBytesSync())!.getPixel(0, 0);
      final prdPixel = decodePng(prdOut.readAsBytesSync())!.getPixel(0, 0);
      // stg = red, prd = green.
      expect(stgPixel.r, 255);
      expect(stgPixel.g, 0);
      expect(prdPixel.r, 0);
      expect(prdPixel.g, 255);
    });
  });
}
