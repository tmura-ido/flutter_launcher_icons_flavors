import 'package:flutter_launcher_icons_flavors/main.dart' as fli_main;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression for upstream issue #648 (companion to #312).
/// See: issues/important/issue-648-flavor-config-files-in-subdirectories.md
///
/// After the #312 fix `getFlavors` recursively scans the prefix directory
/// (skipping `.dart_tool` / `build` / `.git` / `node_modules` noise). Configs
/// organized in `appicons/` (or any other subfolder) are now discovered.
void main() {
  group('issue #648: flavor configs in subdirectories are discovered', () {
    test('getFlavors recurses into appicons/', () async {
      await d.dir('proj_648', [
        d.dir('appicons', [
          d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_648');

      final flavors = await fli_main.getFlavors(dir);
      expect(flavors, ['dev']);
    });
  });
}
