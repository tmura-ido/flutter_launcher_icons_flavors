import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

Future<String> _seed(String name, String content) async {
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
    d.file('flutter_launcher_icons_flavors.yaml', content),
  ]).create();
  return p.join(d.sandbox, name);
}

void main() {
  group('--all-flavors / repeated --flavor', () {
    const yaml = '''
version: 1
defaults:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
flavors:
  dev: {}
  staging: {}
  prod: {}
''';

    test('--all-flavors builds every flavor', () async {
      final dir = await _seed('af1', yaml);
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--all-flavors',
      ]);
      expect(code, 0);
    });

    test('--flavor a --flavor b builds the named subset', () async {
      final dir = await _seed('af2', yaml);
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--flavor',
        'dev',
        '--flavor',
        'prod',
      ]);
      expect(code, 0);
    });

    test('multi-flavor without selector builds all (new default)', () async {
      final dir = await _seed('af3', yaml);
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
      ]);
      expect(code, 0);
    });
  });
}
