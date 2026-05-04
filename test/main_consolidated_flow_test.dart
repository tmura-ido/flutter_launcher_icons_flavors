import 'dart:io';

import 'package:flutter_launcher_icons_flavored/main.dart' as fli_main;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'templates.dart' as templates;

void main() {
  group('createIconsFromArguments — consolidated multi-flavor', () {
    test(
      'two web-flavored builds via consolidated file produce icons for each flavor',
      () async {
        final imageFile = File(
          path.join(Directory.current.path, 'test', 'assets', 'app_icon.png'),
        );
        expect(imageFile.existsSync(), isTrue);
        final imageBytes = imageFile.readAsBytesSync();

        await d.dir('proj', [
          // Web is fully self-contained — no need for android/ios scaffolds.
          // Note: web generation writes to <prefix>/web/icons (single
          // directory) regardless of flavor, so this primarily exercises
          // the multi-flavor preflight + per-flavor resolve paths in
          // main.dart. Each flavor overrides only the background color.
          d.dir('web', [
            d.dir('icons'),
            d.file('index.html', templates.webIndexTemplate),
            d.file('manifest.json', templates.webManifestTemplate),
          ]),
          d.file('app_icon.png', imageBytes),
          d.file('pubspec.yaml', 'name: demo\n'),
          d.file('flutter_launcher_icons_flavors.yaml', '''
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
  prod:
    web:
      background_color: "#222222"
'''),
        ]).create();

        final projDir = path.join(d.sandbox, 'proj');

        // Run the actual CLI entry point. Preflight passes both flavors
        // before any I/O; if validation failed we'd see exit(65) and the
        // test process would die.
        //
        // Phase 4 behavior change: a multi-flavor consolidated file now
        // requires `--all-flavors` (or one or more `--flavor`) to select
        // which flavors to build. Previously the default was "build
        // everything"; that ergonomic shortcut moved behind the explicit
        // flag so users don't accidentally generate every flavor when
        // they meant just one.
        await fli_main.createIconsFromArguments([
          '--prefix',
          projDir,
          '--all-flavors',
        ]);

        // Both flavors produced web icons (latter writes overwrite the
        // former since web output paths are flavor-agnostic, but
        // existence is what we assert here).
        expect(
          File(path.join(projDir, 'web', 'icons', 'Icon-192.png')).existsSync(),
          isTrue,
        );
        expect(
          File(path.join(projDir, 'web', 'icons', 'Icon-512.png')).existsSync(),
          isTrue,
        );
        expect(
          File(path.join(projDir, 'web', 'favicon.png')).existsSync(),
          isTrue,
        );
      },
    );
  });
}
