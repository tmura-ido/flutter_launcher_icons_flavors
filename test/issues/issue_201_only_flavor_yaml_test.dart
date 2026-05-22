import 'dart:io';

import 'package:flutter_launcher_icons_flavors/config/source_resolver.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #201.
/// See: issues/important/issue-201-flavor-yaml-not-found.md
///
/// Project with only `flutter_launcher_icons-<flavor>.yaml` (no base file)
/// must:
///  1. Be discovered as legacy multi-flavor source by `resolveSource`.
///  2. Accept an explicit `-f <relative path>` that resolves under the
///     `--prefix` directory.
void main() {
  group('issue #201: NoConfigFoundException / cannot open flavor yaml', () {
    test('resolveSource succeeds with only legacy per-flavor files', () async {
      await d.dir('proj_201_a', [
        d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_201_a');

      final resolved = resolveSource(prefixPath: dir, logger: FLILogger(false));
      expect(resolved.kind, ConfigSourceKind.legacyFlavors);
    });

    test('explicit -f relative path resolves under prefix', () async {
      await d.dir('proj_201_b', [
        d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_201_b');

      final resolved = resolveSource(
        prefixPath: dir,
        explicitFilePath: 'flutter_launcher_icons-dev.yaml',
        logger: FLILogger(false),
      );
      expect(resolved.kind, ConfigSourceKind.explicitFile);
      expect(File(resolved.path!).existsSync(), isTrue);
    });

    test(
      'missing -f path throws NoConfigFoundException with searched path',
      () async {
        await d.dir('proj_201_c', []).create();
        final dir = p.join(d.sandbox, 'proj_201_c');

        expect(
          () => resolveSource(
            prefixPath: dir,
            explicitFilePath: 'does-not-exist.yaml',
            logger: FLILogger(false),
          ),
          throwsA(isA<NoConfigFoundException>()),
        );
      },
    );
  });
}
