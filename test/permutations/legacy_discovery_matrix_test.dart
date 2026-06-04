// Coverage for legacy per-flavor config discovery (lib/config/
// legacy_discovery.dart). It feeds source resolution and the migrate command;
// previously only exercised transitively through those callers.
import 'package:flutter_launcher_icons_flavors/config/legacy_discovery.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('findLegacyFlavorFiles', () {
    test('missing directory → empty list (never throws)', () {
      expect(
        findLegacyFlavorFiles(p.join(d.sandbox, 'does_not_exist')),
        isEmpty,
      );
    });

    test('extracts flavor names from filenames, sorted ascending', () async {
      await d.dir('proj', [
        d.file('flutter_launcher_icons-prod.yaml', 'x: 1'),
        d.file('flutter_launcher_icons-dev.yaml', 'x: 1'),
        d.file('flutter_launcher_icons-staging.yaml', 'x: 1'),
      ]).create();
      final found = findLegacyFlavorFiles(p.join(d.sandbox, 'proj'));
      expect(found.map((f) => f.flavor).toList(), ['dev', 'prod', 'staging']);
    });

    test('ignores the base config and unrelated yaml files', () async {
      await d.dir('proj2', [
        d.file('flutter_launcher_icons.yaml', 'x: 1'),
        d.file('flutter_launcher_icons_flavors.yaml', 'x: 1'),
        d.file('random.yaml', 'x: 1'),
        d.file('flutter_launcher_icons-real.yaml', 'x: 1'),
      ]).create();
      final found = findLegacyFlavorPaths(p.join(d.sandbox, 'proj2'));
      expect(found.length, 1);
      expect(found.single, endsWith('flutter_launcher_icons-real.yaml'));
    });

    test('skips noise directories (.dart_tool, build, .git)', () async {
      await d.dir('proj3', [
        d.file('flutter_launcher_icons-keep.yaml', 'x: 1'),
        d.dir('build', [d.file('flutter_launcher_icons-skip.yaml', 'x: 1')]),
        d.dir('.dart_tool', [
          d.file('flutter_launcher_icons-skip2.yaml', 'x: 1'),
        ]),
        d.dir('.git', [d.file('flutter_launcher_icons-skip3.yaml', 'x: 1')]),
      ]).create();
      final found = findLegacyFlavorFiles(p.join(d.sandbox, 'proj3'));
      expect(found.map((f) => f.flavor).toList(), ['keep']);
    });

    test('recurses into ordinary subdirectories', () async {
      await d.dir('proj4', [
        d.dir('config', [
          d.file('flutter_launcher_icons-nested.yaml', 'x: 1'),
        ]),
      ]).create();
      final found = findLegacyFlavorFiles(p.join(d.sandbox, 'proj4'));
      expect(found.map((f) => f.flavor).toList(), ['nested']);
    });

    test('findLegacyFlavorPaths returns just the paths', () async {
      await d.dir('proj5', [
        d.file('flutter_launcher_icons-only.yaml', 'x: 1'),
      ]).create();
      final paths = findLegacyFlavorPaths(p.join(d.sandbox, 'proj5'));
      expect(paths, hasLength(1));
      expect(paths.single, endsWith('flutter_launcher_icons-only.yaml'));
    });
  });
}
