import 'package:flutter_launcher_icons_flavors/main.dart' as fli_main;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Behavior test for upstream issue #312.
/// See: issues/important/issue-312-config-files-inside-folder-not-picked-up.md
///
/// `getFlavors()` only scans the immediate prefix directory. Per-flavor
/// config files placed inside a subfolder (`config/generate_appicons/...`)
/// are NOT discovered. Documents the limitation that the fork still has
/// today; a future fix may add `--flavor-path` / recursive search.
void main() {
  group('issue #312: legacy flavor configs in a subfolder', () {
    test('getFlavors recursively finds configs in subfolders', () async {
      await d.dir('proj_312', [
        d.dir('config', [
          d.dir('generate_appicons', [
            d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
            d.file('flutter_launcher_icons-prod.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
          ]),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_312');

      final flavors = await fli_main.getFlavors(dir);
      expect(flavors, containsAll(['dev', 'prod']));
    });

    test('getFlavors skips noise directories (.dart_tool, build, .git)',
        () async {
      await d.dir('proj_312_noise', [
        d.dir('.dart_tool', [
          d.file('flutter_launcher_icons-noise.yaml', 'irrelevant'),
        ]),
        d.dir('build', [
          d.file('flutter_launcher_icons-noise2.yaml', 'irrelevant'),
        ]),
        d.file('flutter_launcher_icons-real.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_312_noise');

      final flavors = await fli_main.getFlavors(dir);
      expect(flavors, ['real']);
    });

    test('getFlavors does find configs at the prefix root', () async {
      await d.dir('proj_312_root', [
        d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_312_root');

      final flavors = await fli_main.getFlavors(dir);
      expect(flavors, contains('dev'));
    });
  });
}
