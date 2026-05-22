import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/web/web_icon_generator.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Regression test for upstream issue #614 documenting the current
/// favicon-size behavior in the fork.
///
/// Today the favicon size is hard-coded at `kFaviconSize = 16`. The issue
/// requests this become configurable (default 32). Until that lands, this
/// test pins both the constant and the on-disk output size so any change
/// is intentional and reflected in both places.
void main() {
  group('issue #614: favicon size', () {
    test('kFaviconSize constant is 16 (current behavior)', () {
      expect(
        constants.kFaviconSize,
        16,
        reason:
            'If you change the favicon size, update this test and the '
            'README — see issue-614.',
      );
    });

    test(
      'generated web/favicon.png is exactly kFaviconSize x kFaviconSize',
      () async {
        final assetPath = p.join(
          Directory.current.path,
          'test',
          'assets',
          'app_icon.png',
        );
        final bytes = File(assetPath).readAsBytesSync();

        await d.dir('proj', [
          d.dir('web', [
            d.dir('icons'),
            d.file('index.html', templates.webIndexTemplate),
            d.file('manifest.json', templates.webManifestTemplate),
          ]),
          d.file('app_icon.png', bytes),
          d.file('pubspec.yaml', 'name: demo\n'),
          d.file('flutter_launcher_icons.yaml', templates.fliWebConfig),
        ]).create();
        final prefix = p.join(d.sandbox, 'proj');
        final cfg = Config.loadConfigFromPath(
          'flutter_launcher_icons.yaml',
          prefix,
        )!;
        final ctx = IconGeneratorContext(
          config: cfg,
          prefixPath: prefix,
          logger: FLILogger(false),
        );
        final gen = WebIconGenerator(ctx);
        expect(gen.validateRequirements(), isTrue);
        await gen.createIcons();

        final fav = File(p.join(prefix, 'web', 'favicon.png'));
        expect(fav.existsSync(), isTrue);
        final img = decodePng(await fav.readAsBytes())!;
        expect(img.width, constants.kFaviconSize);
        expect(img.height, constants.kFaviconSize);
      },
    );
  });
}
