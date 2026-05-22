// One-step "after you bumped pubspec" syncer.
//
//   dart run tool/sync_version.dart
//
// Reads the version from pubspec.yaml and rewrites:
//   * lib/src/version.dart    (mirrors `build_version` output)
//   * README.md install snippet (`flutter_launcher_icons_flavors: ^X.Y.Z`)
//
// Idempotent — exits 0 with no changes if everything is already in sync.
// Exits non-zero if the README install snippet can't be found.

import 'dart:io';

import 'package:yaml/yaml.dart';

void main() {
  final version =
      (loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap)['version']
          as String;

  final changed = <String>[];

  final versionFile = File('lib/src/version.dart');
  final newVersionDart =
      "// Generated code. Do not modify.\nconst packageVersion = '$version';\n";
  if (!versionFile.existsSync() ||
      versionFile.readAsStringSync() != newVersionDart) {
    versionFile.writeAsStringSync(newVersionDart);
    changed.add('lib/src/version.dart');
  }

  final readmeFile = File('README.md');
  final readme = readmeFile.readAsStringSync();
  final pattern = RegExp(r'flutter_launcher_icons_flavors:\s*\^\d+\.\d+\.\d+');
  if (!pattern.hasMatch(readme)) {
    stderr.writeln(
      'error: README.md install snippet not found '
      '(expected "flutter_launcher_icons_flavors: ^X.Y.Z")',
    );
    exit(1);
  }
  final patched = readme.replaceAll(
    pattern,
    'flutter_launcher_icons_flavors: ^$version',
  );
  if (patched != readme) {
    readmeFile.writeAsStringSync(patched);
    changed.add('README.md');
  }

  if (changed.isEmpty) {
    stdout.writeln('already in sync at $version');
  } else {
    stdout.writeln('synced to $version: ${changed.join(', ')}');
  }
}
