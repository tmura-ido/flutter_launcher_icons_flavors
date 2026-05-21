import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/macos/macos_icon_generator.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as p_d;

/// Regression for upstream issue #655.
/// See: issues/approved/issue-655-macos-padding-effective-design-area.md
///
/// `macos.padding: true` resizes the source to 824×824 and composites it
/// onto a 1024×1024 transparent canvas. Corner pixels of the 1024 slot
/// should be transparent; the interior should match the source color.
void main() {
  group('issue #655: macos.padding centers source on 1024 canvas', () {
    test('Config.MacOSConfig.padding defaults to false', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'macos': {'generate': true},
      });
      expect(cfg.macOSConfig?.padding, isFalse);
    });

    test('Config.MacOSConfig.padding round-trips through fromJson', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'macos': {'generate': true, 'padding': true},
      });
      expect(cfg.macOSConfig?.padding, isTrue);
    });

    test('1024 slot is transparent at the corners when padding: true',
        () async {
      // Solid red 1024×1024 source.
      final src = Image(width: 1024, height: 1024, numChannels: 4);
      for (final px in src) {
        px.setRgba(255, 0, 0, 255);
      }

      await p_d.dir('proj655', [
        p_d.dir('macos', [
          p_d.dir('Runner', [
            p_d.dir('Assets.xcassets', [
              p_d.dir('AppIcon.appiconset', [
                p_d.file('Contents.json', '{"images":[],"info":{}}'),
              ]),
            ]),
          ]),
        ]),
        p_d.file('src.png', encodePng(src)),
        p_d.file('pubspec.yaml', 'name: demo\n'),
      ]).create();

      final prefix = p.join(p_d.sandbox, 'proj655');
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'src.png',
        'macos': {
          'generate': true,
          'image_path': 'src.png',
          'padding': true,
        },
      });
      final ctx = IconGeneratorContext(
        config: cfg,
        prefixPath: prefix,
        logger: FLILogger(false),
      );
      final gen = MacOSIconGenerator(ctx);
      await gen.createIcons();

      // The 1024 slot is `app_icon_1024.png` per the macOS template.
      final out = File(
        p.join(
          prefix,
          'macos',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
          'app_icon_1024.png',
        ),
      );
      expect(out.existsSync(), isTrue);
      final decoded = decodePng(out.readAsBytesSync())!;
      // Corner pixels should be transparent.
      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.getPixel(1023, 0).a, 0);
      expect(decoded.getPixel(0, 1023).a, 0);
      expect(decoded.getPixel(1023, 1023).a, 0);
      // Center pixels should be the source red.
      expect(decoded.getPixel(512, 512).r, 255);
    });
  });
}
