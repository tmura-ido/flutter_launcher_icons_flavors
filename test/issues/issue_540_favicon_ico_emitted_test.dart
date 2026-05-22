import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/web/web_icon_generator.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Regression for upstream issue #540 (umbrella for #152, #515, #635).
/// See: issues/approved/issue-540-favicon-ico.md
void main() {
  group('issue #540: web emits favicon.ico + favicon_path override', () {
    test('default: favicon.ico is emitted with 3 sizes', () async {
      final dir = await _makeSandbox('fav540');
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'app_icon.png',
        'web': {'generate': true, 'image_path': 'app_icon.png'},
      });
      final ctx = IconGeneratorContext(
        config: cfg,
        prefixPath: dir,
        logger: FLILogger(false),
      );
      await WebIconGenerator(ctx).createIcons();

      final ico = File(p.join(dir, 'web', 'favicon.ico'));
      expect(ico.existsSync(), isTrue);
      final decoded = decodeIco(ico.readAsBytesSync())!;
      expect(decoded.numFrames, 3);
    });

    test('generate_favicon: false skips the .ico', () async {
      final dir = await _makeSandbox('fav540_off');
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'app_icon.png',
        'web': {
          'generate': true,
          'image_path': 'app_icon.png',
          'generate_favicon': false,
        },
      });
      final ctx = IconGeneratorContext(
        config: cfg,
        prefixPath: dir,
        logger: FLILogger(false),
      );
      await WebIconGenerator(ctx).createIcons();

      expect(File(p.join(dir, 'web', 'favicon.ico')).existsSync(), isFalse);
      // PNG favicon still emitted.
      expect(File(p.join(dir, 'web', 'favicon.png')).existsSync(), isTrue);
    });

    test('favicon_path overrides the favicon source', () async {
      final dir = await _makeSandbox('fav540_path');
      // Add a second image (just bytes) to use as the favicon source.
      final altSrc = Image(width: 256, height: 256);
      for (final px in altSrc) {
        px.setRgba(255, 0, 0, 255);
      }
      File(p.join(dir, 'fav.png')).writeAsBytesSync(encodePng(altSrc));

      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'app_icon.png',
        'web': {
          'generate': true,
          'image_path': 'app_icon.png',
          'favicon_path': 'fav.png',
        },
      });
      final ctx = IconGeneratorContext(
        config: cfg,
        prefixPath: dir,
        logger: FLILogger(false),
      );
      await WebIconGenerator(ctx).createIcons();

      final pngFav = File(p.join(dir, 'web', 'favicon.png'));
      expect(pngFav.existsSync(), isTrue);
      // The favicon should be sourced from fav.png (red), so the pixel
      // ought to be red-dominant.
      final decoded = decodePng(pngFav.readAsBytesSync())!;
      expect(decoded.getPixel(0, 0).r, 255);
    });
  });
}

Future<String> _makeSandbox(String name) async {
  final assetBytes = File(
    p.join(Directory.current.path, 'test', 'assets', 'app_icon.png'),
  ).readAsBytesSync();
  await d.dir(name, [
    d.dir('web', [
      d.dir('icons'),
      d.file('index.html', templates.webIndexTemplate),
      d.file('manifest.json', templates.webManifestTemplate),
    ]),
    d.file('app_icon.png', assetBytes),
    d.file('pubspec.yaml', 'name: demo\n'),
  ]).create();
  return p.join(d.sandbox, name);
}
