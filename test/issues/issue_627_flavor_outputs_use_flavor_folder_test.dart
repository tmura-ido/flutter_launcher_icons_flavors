import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #627.
/// See: issues/important/issue-627-blank-icon-with-flavors.md
///
/// Blank-icon-with-flavors symptoms boil down to outputs overwriting
/// each other in `android/app/src/main/res`. The fork avoids that by
/// threading the flavor name through `androidResFolder(flavor)`. This
/// test exercises `createDefaultIcons` for two distinct flavors and
/// asserts each lands under its own `src/<flavor>/res/...` tree.
void main() {
  group('issue #627: flavor android outputs go to flavor-specific folders', () {
    test('createDefaultIcons writes to src/<flavor>/res per flavor', () async {
      // Use the bundled test asset (real PNG) — `decodeImageFile` rejects
      // ad-hoc bytes.
      final bytes = File(
        p.join(Directory.current.path, 'test', 'assets', 'app_icon.png'),
      ).readAsBytesSync();

      await d.dir('proj_627', [
        d.file('app_icon.png', bytes),
        d.dir('android', [
          d.dir('app', [
            d.dir('src', [
              d.dir('main', [
                d.file(
                  'AndroidManifest.xml',
                  '<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
                      'package="com.example.demo">'
                      '<application android:icon="@mipmap/ic_launcher" />'
                      '</manifest>',
                ),
              ]),
            ]),
          ]),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_627');

      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'app_icon.png',
        'android': true,
      });

      await android.createDefaultIcons(
        cfg,
        'dev',
        logger: FLILogger(false),
        prefixPath: dir,
      );
      await android.createDefaultIcons(
        cfg,
        'prod',
        logger: FLILogger(false),
        prefixPath: dir,
      );

      final devIcon = File(
        p.join(
          dir,
          'android',
          'app',
          'src',
          'dev',
          'res',
          'mipmap-xxxhdpi',
          'ic_launcher.png',
        ),
      );
      final prodIcon = File(
        p.join(
          dir,
          'android',
          'app',
          'src',
          'prod',
          'res',
          'mipmap-xxxhdpi',
          'ic_launcher.png',
        ),
      );
      expect(
        devIcon.existsSync(),
        isTrue,
        reason: 'dev flavor icon must land under src/dev/res',
      );
      expect(
        prodIcon.existsSync(),
        isTrue,
        reason: 'prod flavor icon must land under src/prod/res',
      );

      // The main/res tree should NOT have received either flavor's icon.
      final mainIcon = File(
        p.join(
          dir,
          'android',
          'app',
          'src',
          'main',
          'res',
          'mipmap-xxxhdpi',
          'ic_launcher.png',
        ),
      );
      expect(
        mainIcon.existsSync(),
        isFalse,
        reason: 'main/res must not be touched when flavor is provided',
      );
    });
  });
}
