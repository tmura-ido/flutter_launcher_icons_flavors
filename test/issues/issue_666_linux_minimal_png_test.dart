import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/linux/linux_icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression for upstream issue #666 (umbrella for #186 / #604 / #629).
/// See: issues/approved/issue-666-basic-linux-png-support.md
void main() {
  group('issue #666: minimal Linux PNG support', () {
    test('writes a single PNG at the default Linux path', () async {
      final src = Image(width: 1024, height: 1024);
      for (final px in src) {
        px.setRgba(0x10, 0x20, 0x30, 0xFF);
      }
      await d.dir('proj666', [
        d.file('app_icon.png', encodePng(src)),
        d.file('pubspec.yaml', 'name: demo\n'),
      ]).create();
      final prefix = p.join(d.sandbox, 'proj666');

      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'app_icon.png',
        'linux': {'generate': true, 'image_path': 'app_icon.png'},
      });
      final ctx = IconGeneratorContext(
        config: cfg,
        prefixPath: prefix,
        logger: FLILogger(false),
      );
      final gen = LinuxIconGenerator(ctx);
      expect(gen.validateRequirements(), isTrue);
      expect(gen.isOptedIn, isTrue);
      await gen.createIcons();

      final out = File(
        p.join(prefix, 'linux', 'runner', 'resources', 'app_icon.png'),
      );
      expect(out.existsSync(), isTrue);
      final decoded = decodePng(out.readAsBytesSync())!;
      // Default icon_size is 256.
      expect(decoded.width, 256);
      expect(decoded.height, 256);
    });

    test('honors a custom icon_size and output_path', () async {
      final src = Image(width: 512, height: 512);
      for (final px in src) {
        px.setRgba(255, 0, 0, 255);
      }
      await d.dir('proj666_custom', [
        d.file('app_icon.png', encodePng(src)),
        d.file('pubspec.yaml', 'name: demo\n'),
      ]).create();
      final prefix = p.join(d.sandbox, 'proj666_custom');

      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'app_icon.png',
        'linux': {
          'generate': true,
          'image_path': 'app_icon.png',
          'icon_size': 128,
          'output_path': 'linux/data/icon.png',
        },
      });
      final ctx = IconGeneratorContext(
        config: cfg,
        prefixPath: prefix,
        logger: FLILogger(false),
      );
      final gen = LinuxIconGenerator(ctx);
      await gen.createIcons();

      final out = File(p.join(prefix, 'linux', 'data', 'icon.png'));
      expect(out.existsSync(), isTrue);
      final decoded = decodePng(out.readAsBytesSync())!;
      expect(decoded.width, 128);
    });

    test(
      'falls back to top-level image_path when linux.image_path unset',
      () async {
        final src = Image(width: 64, height: 64);
        for (final px in src) {
          px.setRgba(0, 255, 0, 255);
        }
        await d.dir('proj666_fb', [
          d.file('top.png', encodePng(src)),
          d.file('pubspec.yaml', 'name: demo\n'),
        ]).create();
        final prefix = p.join(d.sandbox, 'proj666_fb');

        final cfg = Config.fromJson(<String, dynamic>{
          'image_path': 'top.png',
          'linux': {'generate': true},
        });
        final ctx = IconGeneratorContext(
          config: cfg,
          prefixPath: prefix,
          logger: FLILogger(false),
        );
        final gen = LinuxIconGenerator(ctx);
        expect(gen.validateRequirements(), isTrue);
        await gen.createIcons();

        final out = File(
          p.join(prefix, 'linux', 'runner', 'resources', 'app_icon.png'),
        );
        expect(out.existsSync(), isTrue);
      },
    );
  });
}
