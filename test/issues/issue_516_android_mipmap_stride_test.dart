import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression for upstream issue #516 / #520.
/// See: issues/approved/issue-516-rangeerror-index-9216.md
///
/// The crash signature `RangeError (index): Index out of range: index
/// should be less than 9216` (= 48*48*4) points to an off-by-one between
/// source-image stride and mipmap output buffer. The fork's Android
/// writer should handle arbitrary source dimensions without crashing.
void main() {
  group('issue #516 / #520: Android mipmap writer is stride-safe', () {
    for (final dims in const [[48, 48], [49, 49], [1024, 1024], [200, 400]]) {
      test('createDefaultIcons does not throw for source ${dims[0]}x${dims[1]}',
          () async {
        final src = Image(width: dims[0], height: dims[1]);
        for (final px in src) {
          px.setRgba(0x10, 0x20, 0x30, 0xFF);
        }

        await d.dir('proj516_${dims[0]}x${dims[1]}', [
          d.dir('android', [
            d.dir('app', [
              d.dir('src', [
                d.dir('main', [
                  d.file('AndroidManifest.xml',
                      '<manifest><application android:icon="@mipmap/ic_launcher"/></manifest>'),
                ]),
              ]),
            ]),
          ]),
          d.file('src.png', encodePng(src)),
          d.file('pubspec.yaml', 'name: demo\n'),
        ]).create();

        final prefix = p.join(d.sandbox, 'proj516_${dims[0]}x${dims[1]}');
        final cfg = Config.fromJson(<String, dynamic>{
          'image_path': 'src.png',
          'android': 'launcher_icon',
        });

        await expectLater(
          android.createDefaultIcons(
            cfg,
            null,
            logger: FLILogger(false),
            prefixPath: prefix,
          ),
          completes,
        );

        // Spot-check that the largest mipmap was written with the right
        // size (192 == xxxhdpi).
        final out = File(
          p.join(
            prefix,
            'android',
            'app',
            'src',
            'main',
            'res',
            'mipmap-xxxhdpi',
            'launcher_icon.png',
          ),
        );
        expect(out.existsSync(), isTrue);
        final decoded = decodePng(out.readAsBytesSync())!;
        expect(decoded.width, 192);
        expect(decoded.height, 192);
      });
    }
  });
}
