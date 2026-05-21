import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Reads the bundled `app_icon.png` test asset. Used to seed sandbox
/// projects that exercise the actual icon-write path.
List<int> _readAssetBytes() {
  final imageFile = File(
    p.join(Directory.current.path, 'test', 'assets', 'app_icon.png'),
  );
  return imageFile.readAsBytesSync();
}

/// Creates a sandbox project at `<sandbox>/<name>` containing a web
/// scaffold and an app_icon.png. Returns the absolute project path.
///
/// Web is fully self-contained — no need for android/ios res scaffolds
/// — which keeps these tests fast.
Future<String> _makeWebSandbox(String name) async {
  final bytes = _readAssetBytes();
  await d.dir(name, [
    d.dir('web', [
      d.dir('icons'),
      d.file('index.html', templates.webIndexTemplate),
      d.file('manifest.json', templates.webManifestTemplate),
    ]),
    d.file('app_icon.png', bytes),
    d.file('pubspec.yaml', 'name: demo\n'),
  ]).create();
  return p.join(d.sandbox, name);
}

void main() {
  group('GenerateCommand — flag combinations', () {
    test('bare invocation runs `generate` (single-config pubspec)', () async {
      final bytes = _readAssetBytes();
      await d.dir('proj', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('app_icon.png', bytes),
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'proj');

      final code = await buildCommandRunner().run(
        effectiveArgs(['--prefix', dir]),
      );
      expect(code, 0);
      expect(
        File(p.join(dir, 'web', 'icons', 'Icon-192.png')).existsSync(),
        isTrue,
      );
    });

    test('--list-flavors prints and exits 0 without generating', () async {
      final dir = await _makeWebSandbox('list');
      await File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).writeAsString('''
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
''');
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--list-flavors',
      ]);
      expect(code, 0);
      // No icons generated.
      expect(
        File(p.join(dir, 'web', 'icons', 'Icon-192.png')).existsSync(),
        isFalse,
      );
    });

    test('--flavor dev builds only dev when consolidated has 3', () async {
      final dir = await _makeWebSandbox('one');
      await File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).writeAsString('''
version: 1
defaults:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
flavors:
  dev:
    web:
      background_color: "#111111"
  staging:
    web:
      background_color: "#222222"
  prod:
    web:
      background_color: "#333333"
''');
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--flavor',
        'dev',
      ]);
      expect(code, 0);
      // Web writes are flavor-agnostic so we can only assert side
      // effect existence, not per-flavor differentiation. The fact that
      // exit was 0 confirms preflight + single-flavor build path.
      expect(
        File(p.join(dir, 'web', 'icons', 'Icon-192.png')).existsSync(),
        isTrue,
      );
    });

    test('--flavor dev --flavor staging builds both', () async {
      final dir = await _makeWebSandbox('two');
      await File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).writeAsString('''
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
''');
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--flavor',
        'dev',
        '--flavor',
        'staging',
      ]);
      expect(code, 0);
    });

    test('--flavor nonexistent → exit 64', () async {
      final dir = await _makeWebSandbox('missing');
      await File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).writeAsString('''
version: 1
defaults:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
flavors:
  dev: {}
''');
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--flavor',
        'ghost',
      ]);
      expect(code, 64);
    });

    test('--all-flavors builds everything', () async {
      final dir = await _makeWebSandbox('all');
      await File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).writeAsString('''
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
''');
      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--all-flavors',
      ]);
      expect(code, 0);
    });

    test(
      'multi-flavor consolidated, neither flag → builds all (new default)',
      () async {
        final dir = await _makeWebSandbox('multi');
        await File(
          p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
        ).writeAsString('''
version: 1
defaults:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
flavors:
  dev: {}
  prod: {}
''');
        final code = await buildCommandRunner().run([
          'generate',
          '--prefix',
          dir,
        ]);
        expect(code, 0);
      },
    );

    test(
      'single-flavor consolidated, neither flag → builds it (ergonomic)',
      () async {
        final dir = await _makeWebSandbox('single_flavor');
        await File(
          p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
        ).writeAsString('''
version: 1
defaults:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
flavors:
  dev: {}
''');
        final code = await buildCommandRunner().run([
          'generate',
          '--prefix',
          dir,
        ]);
        expect(code, 0);
      },
    );

    test('single-config source + --flavor non-matching → exit 64', () async {
      final bytes = _readAssetBytes();
      await d.dir('proj_single', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('app_icon.png', bytes),
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_single');

      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
        '--flavor',
        'main',
      ]);
      expect(code, 64);
    });

    test('single-config source builds normally without --flavor', () async {
      final bytes = _readAssetBytes();
      await d.dir('proj_single2', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('app_icon.png', bytes),
        d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
'''),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_single2');

      final code = await buildCommandRunner().run([
        'generate',
        '--prefix',
        dir,
      ]);
      expect(code, 0);
    });
  });
}
