import 'dart:io';

import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/main.dart' as fli_main;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Regression test for upstream issue #550.
/// See: issues/issue-550-not-all-futures-awaited.md
///
/// All public entry points should fully await their I/O. This test
/// asserts that by the time `createIconsFromConfig` returns, every output
/// file is already on disk — no late-firing futures.
void main() {
  group('issue #550: createIconsFromConfig awaits all spawned futures', () {
    test(
      'after await, every promised web output is on disk (no late writes)',
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

        await fli_main.createIconsFromConfig(cfg, FLILogger(false), prefix);

        // Assert SYNCHRONOUSLY (no further awaits) that every promised
        // output is present. Any late future would cause this to fail.
        for (final relative in const [
          'web/favicon.png',
          'web/icons/Icon-192.png',
          'web/icons/Icon-512.png',
          'web/icons/Icon-maskable-192.png',
          'web/icons/Icon-maskable-512.png',
          'web/manifest.json',
        ]) {
          expect(
            File(p.join(prefix, relative)).existsSync(),
            isTrue,
            reason:
                '$relative should exist by the time createIconsFromConfig '
                'completes (see issue-550).',
          );
        }
      },
    );
  });
}
