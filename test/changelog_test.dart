// Asserts CHANGELOG.md has an entry for the current pubspec version.
//
// Mirrors the warning `dart pub publish` emits ("X.Y.Z is not mentioned
// in `CHANGELOG.md`.") and the heading shape the release workflow's awk
// extractor expects when building the GitHub release notes (see
// .github/workflows/release.yml).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Captured eagerly in `main()` before any test runs, so concurrent
/// tests that mutate `Directory.current` can't poison path lookups
/// here when this file is aggregated via test/all_tests.dart.
late final String _projectRoot;

void main() {
  _projectRoot = Directory.current.path;

  group('CHANGELOG', () {
    test(
      'contains a "## <version>" heading for the current pubspec version',
      () {
        final pubspec = File(
          p.join(_projectRoot, 'pubspec.yaml'),
        ).readAsStringSync();
        final version = (loadYaml(pubspec) as YamlMap)['version'] as String;

        final changelog = File(
          p.join(_projectRoot, 'CHANGELOG.md'),
        ).readAsStringSync();

        // Same shape release.yml's awk uses: `^## <version>` followed by
        // end-of-line or whitespace (typically " (YYYY-MM-DD)").
        final pattern = RegExp(
          '^## ${RegExp.escape(version)}(\$|\\s)',
          multiLine: true,
        );

        expect(
          pattern.hasMatch(changelog),
          isTrue,
          reason:
              'CHANGELOG.md is missing a "## $version" heading. '
              '`dart pub publish --dry-run` warns "$version is not '
              'mentioned in `CHANGELOG.md`." without it, and the release '
              'workflow uses this heading to extract the GitHub release '
              'notes. Add a section to CHANGELOG.md before bumping.',
        );
      },
    );
  });
}
