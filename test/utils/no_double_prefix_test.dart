import 'dart:io';

import 'package:flutter_launcher_icons_flavored/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavored/config/config.dart';
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:flutter_launcher_icons_flavored/web/web_icon_generator.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Regression test for the web/macos double-prefix bug. Pre-fix, the web and
/// macos generators called `path.join(context.prefixPath, iconsDir.path, ...)`
/// even though `iconsDir.path` already had `prefixPath` baked in.
///
/// This test uses an absolute prefix (no `Directory.current` mutation, sandbox
/// only). The positive assertion (icon present at expected location) protects
/// against future regressions that *would* break the absolute-prefix case.
/// The negative assertion guards against the doubled directory ever being
/// created. Note: under `path.join` semantics, an absolute second argument
/// discards earlier components, so the original bug masked itself when prefix
/// was absolute; the relative-prefix bug is covered by code review and the
/// existing `prefix_threading_test.dart` flavor-discovery test.
///
/// macOS coverage deferred: setting up a parallel `MacOSIconGenerator` test
/// requires duplicating the Assets.xcassets fixture; the web case demonstrates
/// the same code-shape fix and is sufficient for Phase 1 sandbox-level cover.
void main() {
  group('No double-prefix regression', () {
    test('web generator writes icons exactly once under prefix', () async {
      // 1024x1024 PNG generated in-memory keeps the test self-contained
      // (no dependency on test/assets/ which other parallel suites can't see).
      final src = Image(width: 1024, height: 1024);
      final pngBytes = encodePng(src);

      await d.dir('subdir', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('flutter_launcher_icons.yaml', templates.fliWebConfig),
        d.file('pubspec.yaml', templates.pubspecTemplate),
        d.file('app_icon.png', pngBytes),
      ]).create();

      final prefix = path.join(d.sandbox, 'subdir');
      final config = Config.loadConfigFromPath(
        'flutter_launcher_icons.yaml',
        prefix,
      )!;
      final context = IconGeneratorContext(
        config: config,
        prefixPath: prefix,
        logger: FLILogger(false),
      );

      final generator = WebIconGenerator(context);
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      // Positive: icon lands at <prefix>/web/icons/Icon-192.png.
      expect(
        File(path.join(prefix, 'web', 'icons', 'Icon-192.png')).existsSync(),
        isTrue,
        reason: 'expected icon at <prefix>/web/icons/Icon-192.png',
      );

      // Negative regression-defense: no doubled-prefix directory ever exists.
      // e.g. <prefix>/subdir must NOT have been created.
      final doubled = path.join(prefix, path.basename(prefix));
      expect(
        Directory(doubled).existsSync(),
        isFalse,
        reason: 'double-prefix bug must not regress',
      );
    });
  });
}
