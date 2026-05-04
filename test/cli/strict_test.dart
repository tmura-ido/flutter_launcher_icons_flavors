import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

const _flavorsYaml = '''
version: 1
defaults:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
flavors:
  dev: {}
''';

const _legacyYaml = '''
flutter_launcher_icons:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
''';

Future<String> _seedCoexistence(String name) async {
  final imageFile = File(
    p.join(Directory.current.path, 'test', 'assets', 'app_icon.png'),
  );
  final bytes = imageFile.readAsBytesSync();
  await d.dir(name, [
    d.dir('web', [
      d.dir('icons'),
      d.file('index.html', templates.webIndexTemplate),
      d.file('manifest.json', templates.webManifestTemplate),
    ]),
    d.file('app_icon.png', bytes),
    d.file('pubspec.yaml', 'name: demo\n'),
    d.file('flutter_launcher_icons_flavors.yaml', _flavorsYaml),
    d.file('flutter_launcher_icons-old.yaml', _legacyYaml),
  ]).create();
  return p.join(d.sandbox, name);
}

void main() {
  group('--strict', () {
    test(
      'coexistence without --strict → warning + exit 0 after generation',
      () async {
        final dir = await _seedCoexistence('strict_off');
        final code = await buildCommandRunner().run([
          'generate',
          '--prefix',
          dir,
        ]);
        expect(code, 0);
      },
    );

    test('coexistence with --strict → exit 65, no files written', () async {
      final dir = await _seedCoexistence('strict_on');
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--strict',
      ]);
      expect(code, 65);
      // No web icons written.
      expect(
        File(p.join(dir, 'web', 'icons', 'Icon-192.png')).existsSync(),
        isFalse,
      );
    });

    test('--strict no-op when no coexistence', () async {
      final imageFile = File(
        p.join(Directory.current.path, 'test', 'assets', 'app_icon.png'),
      );
      final bytes = imageFile.readAsBytesSync();
      await d.dir('strict_none', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('app_icon.png', bytes),
        d.file('pubspec.yaml', 'name: demo\n'),
        d.file('flutter_launcher_icons_flavors.yaml', _flavorsYaml),
      ]).create();
      final dir = p.join(d.sandbox, 'strict_none');
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--strict',
      ]);
      expect(code, 0);
    });
  });
}
