import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/windows/windows_icon_generator.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Behavior test for upstream issue #573.
/// See: issues/issue-573-windows-ico-low-quality.md
///
/// Windows shell picks the best-matching size embedded in the ICO. If only
/// the configured size is embedded, smaller contexts (taskbar at 16/24/32)
/// down-rescale a 256px image and look blurry. The fix would be to embed
/// the standard pyramid (16,24,32,48,64,128,256).
void main() {
  group('issue #573: windows ICO embeds multiple sizes for shell rescaling', () {
    test('generated .ico contains more than one image (multi-size pyramid)',
        () async {
      // Seed a 256x256 source so we have enough resolution.
      final src = Image(width: 256, height: 256);
      // Fill non-transparent so encoders don't optimize anything away.
      for (final px in src) {
        px.setRgba(0x10, 0x20, 0x30, 0xFF);
      }

      await d.dir('proj', [
        d.dir('windows'),
        d.file('app_icon.png', encodePng(src)),
        d.file('pubspec.yaml', 'name: demo\n'),
      ]).create();
      final prefix = p.join(d.sandbox, 'proj');

      final cfg = Config.fromJson({
        'image_path': 'app_icon.png',
        'windows': {
          'generate': true,
          'image_path': 'app_icon.png',
          'icon_size': 256,
        },
      });
      final ctx = IconGeneratorContext(
        config: cfg,
        prefixPath: prefix,
        logger: FLILogger(false),
      );
      final gen = WindowsIconGenerator(ctx);
      expect(gen.validateRequirements(), isTrue);
      await gen.createIcons();

      final ico = File(p.join(prefix, 'windows', 'runner', 'resources',
          'app_icon.ico'));
      expect(ico.existsSync(), isTrue, reason: 'ico should be generated');

      final decoded = decodeIco(await ico.readAsBytes());
      expect(decoded, isNotNull);
      // image package's IcoDecoder exposes numFrames where >1 means the
      // file is a multi-image ICO.
      expect(
        decoded!.numFrames,
        greaterThan(1),
        reason:
            'Windows shell expects multi-size ICOs (16/24/32/48/...); '
            'a single-size ICO scales poorly in the taskbar.',
      );
    });

    test('icon_size cap reduces the embedded set (icon_size: 64 → 5 sizes)',
        () async {
      final src = Image(width: 256, height: 256);
      for (final px in src) {
        px.setRgba(0x10, 0x20, 0x30, 0xFF);
      }

      await d.dir('proj64', [
        d.dir('windows'),
        d.file('app_icon.png', encodePng(src)),
        d.file('pubspec.yaml', 'name: demo\n'),
      ]).create();
      final prefix = p.join(d.sandbox, 'proj64');

      final cfg = Config.fromJson({
        'image_path': 'app_icon.png',
        'windows': {
          'generate': true,
          'image_path': 'app_icon.png',
          'icon_size': 64,
        },
      });
      final ctx = IconGeneratorContext(
        config: cfg,
        prefixPath: prefix,
        logger: FLILogger(false),
      );
      final gen = WindowsIconGenerator(ctx);
      await gen.createIcons();

      final ico = File(
        p.join(prefix, 'windows', 'runner', 'resources', 'app_icon.ico'),
      );
      final decoded = decodeIco(await ico.readAsBytes());
      expect(decoded, isNotNull);
      // pyramid up to 64 → 16, 24, 32, 48, 64
      expect(decoded!.numFrames, 5);
    });
  });
}
