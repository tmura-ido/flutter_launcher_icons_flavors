import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Regression / dependency-compat test for upstream issue #619.
/// See: issues/easy/issue-619-archive-4-incompatibility.md
///
/// Upstream `flutter_launcher_icons` historically forced `archive ^3`
/// via `image ^4.2.0`, which blocked consumer projects already on
/// `archive ^4`. The fork's lockfile should resolve `archive` to a
/// version compatible with `^4` so consumers are not blocked.
void main() {
  group('issue #619: resolved archive is compatible with ^4', () {
    test('pubspec.lock resolves archive major >= 4', () {
      final lockPath = p.join(Directory.current.path, 'pubspec.lock');
      final lockFile = File(lockPath);
      if (!lockFile.existsSync()) {
        return;
      }
      final doc = loadYaml(lockFile.readAsStringSync()) as YamlMap;
      final packages = doc['packages'] as YamlMap?;
      expect(packages, isNotNull);
      final archive = packages!['archive'] as YamlMap?;
      expect(archive, isNotNull, reason: 'archive not present in pubspec.lock');
      final version = archive!['version'] as String;
      final major = int.parse(version.split('.').first);
      expect(
        major >= 4,
        isTrue,
        reason:
            'archive=$version still pinned to <4; consumers on '
            'archive ^4 will be blocked. See issue #619.',
      );
    });
  });
}
