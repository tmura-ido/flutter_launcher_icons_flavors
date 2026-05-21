import 'dart:io';

import 'package:flutter_launcher_icons_flavors/config/source_resolver.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression / behavior test for upstream issue #198.
/// See: issues/important/issue-198-base-yaml-ignored-with-flavor.md
///
/// When a base `flutter_launcher_icons.yaml` AND legacy
/// `flutter_launcher_icons-<flavor>.yaml` coexist, the legacy multi-flavor
/// branch wins. Documents the trade-off: with legacy files present the base
/// is treated as a separate "main" flavor and is NOT auto-included alongside
/// the named flavors.
void main() {
  group('issue #198: base flutter_launcher_icons.yaml with legacy flavor', () {
    test('legacy flavors are discovered when base file is also present',
        () async {
      await d.dir('proj_198', [
        d.file('flutter_launcher_icons.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
        d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_198');

      // Confirm resolveSource picks the legacy multi-flavor branch when
      // both base and at least one legacy file are present.
      final resolved = resolveSource(
        prefixPath: dir,
        logger: FLILogger(false),
      );
      expect(resolved.kind, ConfigSourceKind.legacyFlavors);
      // Confirm `flutter_launcher_icons.yaml` is still on disk (not deleted),
      // documenting the user-visible state.
      expect(
        File(p.join(dir, 'flutter_launcher_icons.yaml')).existsSync(),
        isTrue,
      );
    });
  });
}
