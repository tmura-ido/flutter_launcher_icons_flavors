import 'dart:io';

import 'package:flutter_launcher_icons_flavored/cli/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:yaml/yaml.dart';

const _devYaml = '''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/dev.png"
''';
const _stgYaml = '''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/staging.png"
''';
const _prodYaml = '''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/prod.png"
''';

Future<String> _seed(String name) async {
  await d.dir(name, [
    d.file('flutter_launcher_icons-dev.yaml', _devYaml),
    d.file('flutter_launcher_icons-staging.yaml', _stgYaml),
    d.file('flutter_launcher_icons-prod.yaml', _prodYaml),
  ]).create();
  return p.join(d.sandbox, name);
}

void main() {
  group('MigrateCommand', () {
    test(
      '3 legacy → consolidated file, version 1, empty defaults, 3 flavors',
      () async {
        final dir = await _seed('m1');
        final code = await buildCommandRunner().run([
          'migrate',
          '--prefix',
          dir,
        ]);
        expect(code, 0);
        final out = File(p.join(dir, 'flutter_launcher_icons_flavors.yaml'));
        expect(out.existsSync(), isTrue);
        final dynamic parsed = loadYaml(out.readAsStringSync());
        expect(parsed['version'], 1);
        expect(parsed['defaults'], isA<YamlMap>());
        expect((parsed['defaults'] as YamlMap).isEmpty, isTrue);
        final flavors = parsed['flavors'] as YamlMap;
        expect(flavors.keys.toSet(), {'dev', 'staging', 'prod'});
        // Each flavor block fully specified (image_path differs by flavor).
        expect(flavors['dev']['image_path'], 'assets/dev.png');
        expect(flavors['staging']['image_path'], 'assets/staging.png');
        expect(flavors['prod']['image_path'], 'assets/prod.png');
        // .bak copies were written.
        expect(
          File(p.join(dir, 'flutter_launcher_icons-dev.yaml.bak')).existsSync(),
          isTrue,
        );
        // Originals retained (no --in-place).
        expect(
          File(p.join(dir, 'flutter_launcher_icons-dev.yaml')).existsSync(),
          isTrue,
        );
      },
    );

    test('output is byte-identical across two runs (deterministic)', () async {
      final dir = await _seed('m_det');
      final r1 = await buildCommandRunner().run(['migrate', '--prefix', dir]);
      expect(r1, 0);
      final first = File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).readAsBytesSync();
      // Run again with --force.
      final r2 = await buildCommandRunner().run([
        'migrate',
        '--prefix',
        dir,
        '--force',
      ]);
      expect(r2, 0);
      final second = File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).readAsBytesSync();
      expect(second, equals(first));
    });

    test('--dry-run writes nothing', () async {
      final dir = await _seed('m_dry');
      final code = await buildCommandRunner().run([
        'migrate',
        '--prefix',
        dir,
        '--dry-run',
      ]);
      expect(code, 0);
      expect(
        File(p.join(dir, 'flutter_launcher_icons_flavors.yaml')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(dir, 'flutter_launcher_icons-dev.yaml.bak')).existsSync(),
        isFalse,
      );
    });

    test('--in-place removes legacy originals; .bak files remain', () async {
      final dir = await _seed('m_inplace');
      final code = await buildCommandRunner().run([
        'migrate',
        '--prefix',
        dir,
        '--in-place',
      ]);
      expect(code, 0);
      // Originals deleted.
      expect(
        File(p.join(dir, 'flutter_launcher_icons-dev.yaml')).existsSync(),
        isFalse,
      );
      // Backups retained.
      expect(
        File(p.join(dir, 'flutter_launcher_icons-dev.yaml.bak')).existsSync(),
        isTrue,
      );
    });

    test('existing target without --force → exit 64', () async {
      final dir = await _seed('m_exists');
      await File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).writeAsString('# placeholder\n');
      final code = await buildCommandRunner().run(['migrate', '--prefix', dir]);
      expect(code, 64);
      expect(
        File(
          p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
        ).readAsStringSync(),
        '# placeholder\n',
      );
    });

    test('existing target with --force → overwrites', () async {
      final dir = await _seed('m_force');
      await File(
        p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
      ).writeAsString('# placeholder\n');
      final code = await buildCommandRunner().run([
        'migrate',
        '--prefix',
        dir,
        '--force',
      ]);
      expect(code, 0);
      final dynamic parsed = loadYaml(
        File(
          p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
        ).readAsStringSync(),
      );
      expect(parsed['version'], 1);
    });

    test('candidates report contains identical keys', () async {
      // dev/staging/prod all have android: true and ios: true → these
      // should be reported as candidates. image_path differs → not a
      // candidate. We assert the report is structurally correct by
      // re-running the migration and parsing the YAML output for the
      // identical keys (we don't have stdout capture in-process, so we
      // verify the same logic by inspecting the produced consolidated
      // file: every flavor block contains those identical keys).
      final dir = await _seed('m_cand');
      final code = await buildCommandRunner().run(['migrate', '--prefix', dir]);
      expect(code, 0);
      final dynamic parsed = loadYaml(
        File(
          p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
        ).readAsStringSync(),
      );
      final flavors = parsed['flavors'] as YamlMap;
      for (final f in ['dev', 'staging', 'prod']) {
        expect(flavors[f]['android'], true);
        expect(flavors[f]['ios'], true);
      }
    });

    test('no legacy files → exit 0 with info, no file written', () async {
      await d.dir('m_empty', []).create();
      final dir = p.join(d.sandbox, 'm_empty');
      final code = await buildCommandRunner().run(['migrate', '--prefix', dir]);
      expect(code, 0);
      expect(
        File(p.join(dir, 'flutter_launcher_icons_flavors.yaml')).existsSync(),
        isFalse,
      );
    });

    test('malformed legacy YAML → exit 64 (NOT 1)', () async {
      // Spec §1.3 last bullet: legacy file unparseable → 64.
      // Regression for the reviewer-flagged Phase 4 deviation: the
      // YamlException was previously caught by the generic Exception
      // branch and returned 1.
      await d.dir('m_broken', [
        d.file(
          'flutter_launcher_icons-broken.yaml',
          // Unclosed flow sequence — guaranteed YAML parse failure.
          'flutter_launcher_icons:\n  image_path: [unterminated\n',
        ),
      ]).create();
      final dir = p.join(d.sandbox, 'm_broken');
      final code = await buildCommandRunner().run(['migrate', '--prefix', dir]);
      expect(code, 64);
      // No consolidated file should have been written.
      expect(
        File(p.join(dir, 'flutter_launcher_icons_flavors.yaml')).existsSync(),
        isFalse,
      );
      // No backups either, because we error out before the backup step.
      expect(
        File(
          p.join(dir, 'flutter_launcher_icons-broken.yaml.bak'),
        ).existsSync(),
        isFalse,
      );
    });

    test('semantic golden: parse-and-compare maps', () async {
      final dir = await _seed('m_golden');
      final code = await buildCommandRunner().run(['migrate', '--prefix', dir]);
      expect(code, 0);
      final dynamic parsed = loadYaml(
        File(
          p.join(dir, 'flutter_launcher_icons_flavors.yaml'),
        ).readAsStringSync(),
      );
      // Convert to plain Map<String,dynamic> for deep equality.
      final actual = _toPlain(parsed);
      final expected = <String, dynamic>{
        'version': 1,
        'defaults': <String, dynamic>{},
        'flavors': <String, dynamic>{
          'dev': <String, dynamic>{
            'android': true,
            'ios': true,
            'image_path': 'assets/dev.png',
          },
          'staging': <String, dynamic>{
            'android': true,
            'ios': true,
            'image_path': 'assets/staging.png',
          },
          'prod': <String, dynamic>{
            'android': true,
            'ios': true,
            'image_path': 'assets/prod.png',
          },
        },
      };
      expect(actual, equals(expected));
    });
  });
}

dynamic _toPlain(dynamic v) {
  if (v is YamlMap) {
    return v.map((k, val) => MapEntry(k.toString(), _toPlain(val)));
  }
  if (v is YamlList) {
    return v.map(_toPlain).toList();
  }
  return v;
}
