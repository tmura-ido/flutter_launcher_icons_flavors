import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/web/web_icon_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Regression / behavior test for upstream issue #633.
/// See: issues/easy/issue-633-web-platform-requirements-failed.md
///
/// When `web.generate: true` is set but no `web.image_path` is given, the
/// generator should fall back to the top-level `image_path` rather than
/// emit the misleading "Requirements failed for platform Web. Skipped".
void main() {
  group('issue #633: web image_path falls back to top-level image_path', () {
    test('validateRequirements() returns true when only top-level image_path '
        'is set', () async {
      final assetPath = p.join(Directory.current.path, 'test', 'assets');
      final imageBytes = File(
        p.join(assetPath, 'app_icon.png'),
      ).readAsBytesSync();

      await d.dir('issue_633', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('app_icon.png', imageBytes),
        d.file('pubspec.yaml', 'name: demo\n'),
      ]).create();
      final prefixPath = p.join(d.sandbox, 'issue_633');

      // Config with TOP-LEVEL image_path only — web block has no image_path.
      final config = Config.fromJson(<String, dynamic>{
        'image_path': 'app_icon.png',
        'web': {'generate': true},
      });

      final context = IconGeneratorContext(
        config: config,
        prefixPath: prefixPath,
        logger: FLILogger(false),
      );
      final generator = WebIconGenerator(context);
      expect(
        generator.validateRequirements(),
        isTrue,
        reason:
            'WebIconGenerator should fall back to top-level image_path '
            'when web.image_path is omitted (see issue #633).',
      );
    });
  });
}
