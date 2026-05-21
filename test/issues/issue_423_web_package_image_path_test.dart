import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/web/web_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Regression for upstream issue #423.
/// See: issues/approved/issue-423-web-package-path.md
///
/// Web `image_path` with a `packages/<pkg>/...` prefix used to be opened as
/// `/packages/<pkg>/...` (leading slash) and crash with `FileSystemException`.
/// Android handles this case correctly; the web writer should too.
void main() {
  group('issue #423: web image_path with packages/ prefix', () {
    test('web generator resolves a packages/<pkg>/... source without crashing',
        () async {
      final assetPath = path.join(Directory.current.path, 'test', 'assets');
      final imageBytes =
          File(path.join(assetPath, 'app_icon.png')).readAsBytesSync();

      await d.dir('fli_pkg_test', [
        d.dir('packages', [
          d.dir('flutter_utils', [
            d.dir('assets', [d.file('mtc_launcher_icon.png', imageBytes)]),
          ]),
        ]),
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('flutter_launcher_icons.yaml', '''
flutter_launcher_icons:
  web:
    generate: true
    image_path: "packages/flutter_utils/assets/mtc_launcher_icon.png"
'''),
        d.file('pubspec.yaml', templates.pubspecTemplate),
      ]).create();

      final prefixPath = path.join(d.sandbox, 'fli_pkg_test');
      final config = Config.loadConfigFromPath(
        'flutter_launcher_icons.yaml',
        prefixPath,
      )!;
      final context = IconGeneratorContext(
        config: config,
        prefixPath: prefixPath,
        logger: FLILogger(false),
      );
      final generator = WebIconGenerator(context);

      expect(generator.validateRequirements(), isTrue);
      await expectLater(generator.createIcons(), completes);

      // Sanity-check at least one expected output exists.
      expect(
        File(path.join(prefixPath, 'web', 'favicon.png')).existsSync(),
        isTrue,
      );
    });
  });
}
