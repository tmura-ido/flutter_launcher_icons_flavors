import 'dart:convert';
import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/macos/macos_icon_generator.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression for upstream issue #660.
/// See: issues/approved/issue-660-macos-tahoe-themed-background.md
///
/// Mirrors the iOS dark/tinted catalog pattern on macOS.
void main() {
  group('issue #660: macOS dark/tinted appearance entries', () {
    test(
      'dark + tinted images produce *_dark / *_tinted PNGs and Contents.json',
      () async {
        final src = Image(width: 1024, height: 1024);
        for (final px in src) {
          px.setRgba(255, 255, 255, 255);
        }
        final dark = Image(width: 1024, height: 1024);
        for (final px in dark) {
          px.setRgba(0, 0, 0, 255);
        }
        final tinted = Image(width: 1024, height: 1024);
        for (final px in tinted) {
          px.setRgba(128, 128, 128, 255);
        }

        await d.dir('proj660', [
          d.dir('macos', [
            d.dir('Runner', [
              d.dir('Assets.xcassets', [
                d.dir('AppIcon.appiconset', [
                  d.file('Contents.json', '{"images":[],"info":{}}'),
                ]),
              ]),
            ]),
          ]),
          d.file('light.png', encodePng(src)),
          d.file('dark.png', encodePng(dark)),
          d.file('tinted.png', encodePng(tinted)),
          d.file('pubspec.yaml', 'name: demo\n'),
        ]).create();
        final prefix = p.join(d.sandbox, 'proj660');

        final cfg = Config.fromJson(<String, dynamic>{
          'image_path': 'light.png',
          'macos': {
            'generate': true,
            'image_path': 'light.png',
            'dark_image_path': 'dark.png',
            'tinted_image_path': 'tinted.png',
          },
        });
        final ctx = IconGeneratorContext(
          config: cfg,
          prefixPath: prefix,
          logger: FLILogger(false),
        );
        final gen = MacOSIconGenerator(ctx);
        await gen.createIcons();

        // Spot-check a couple of variant PNGs.
        final darkFile = File(
          p.join(
            prefix,
            'macos',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
            'app_icon_1024_dark.png',
          ),
        );
        expect(darkFile.existsSync(), isTrue);
        final tintedFile = File(
          p.join(
            prefix,
            'macos',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
            'app_icon_1024_tinted.png',
          ),
        );
        expect(tintedFile.existsSync(), isTrue);

        // Contents.json should now have appearance qualifiers.
        final contentsFile = File(
          p.join(
            prefix,
            'macos',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
            'Contents.json',
          ),
        );
        final contents =
            jsonDecode(contentsFile.readAsStringSync()) as Map<String, dynamic>;
        final images = contents['images'] as List;
        // Should contain entries with appearances: luminosity/dark
        bool foundDark = false;
        bool foundTinted = false;
        for (final entry in images) {
          final map = entry as Map<String, dynamic>;
          final appearances = map['appearances'] as List?;
          if (appearances != null && appearances.isNotEmpty) {
            final first = appearances.first as Map;
            if (first['value'] == 'dark') foundDark = true;
            if (first['value'] == 'tinted') foundTinted = true;
          }
        }
        expect(foundDark, isTrue);
        expect(foundTinted, isTrue);
      },
    );
  });
}
