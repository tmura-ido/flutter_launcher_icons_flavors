import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Regression / supply-chain test for upstream issue #530 (and #571).
/// See: issues/easy/issue-530-archive-vulnerability.md
///
/// `package:image` transitively pulls `package:archive`. Older `archive`
/// versions (< 3.6.0) carry the vulnerabilities tracked as GHSA-9v85-q87q-g4vg
/// and GHSA-r285-q736-9v95. Verify the resolved `archive` in `pubspec.lock`
/// sits on a safe floor so dependabot stops yelling.
void main() {
  group('issue #530: archive transitive dep is on a safe version', () {
    test('pubspec.lock resolves archive >= 3.6.0', () {
      final lockPath = p.join(Directory.current.path, 'pubspec.lock');
      final lockFile = File(lockPath);
      if (!lockFile.existsSync()) {
        // pubspec.lock may not exist in fresh checkouts; nothing to verify.
        return;
      }
      final doc = loadYaml(lockFile.readAsStringSync()) as YamlMap;
      final packages = doc['packages'] as YamlMap?;
      expect(packages, isNotNull, reason: 'pubspec.lock has no packages map');
      final archive = packages!['archive'] as YamlMap?;
      expect(archive, isNotNull, reason: 'archive not present in pubspec.lock');
      final version = archive!['version'] as String;
      final parts = version.split('.').map(int.parse).toList();
      // semver compare against the 3.6.0 safe floor.
      final major = parts[0];
      final minor = parts.length > 1 ? parts[1] : 0;
      final isSafe = major > 3 || (major == 3 && minor >= 6);
      expect(
        isSafe,
        isTrue,
        reason:
            'resolved archive=$version is below the 3.6.0 safe floor '
            '(GHSA-9v85-q87q-g4vg / GHSA-r285-q736-9v95)',
      );
    });
  });
}
