// Permutation matrix over the `generate` CLI flag surface, asserting the
// documented process exit codes:
//
//   0  — success (here: short-circuiting actions like --list-flavors)
//   64 — usage error (conflicting / invalid flag combinations)
//   65 — config error (no config found)
//
// Flags under test: --flavor (repeatable), --all-flavors, --list-flavors,
// --strict, --yes, --verbose, plus unknown options. We deliberately drive
// only the pre-generation decision paths (usage validation, source
// resolution, flavor listing) so the matrix stays fast and deterministic and
// never depends on real image files.
import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// A consolidated multi-flavor project (two flavors: dev, prod).
Future<String> _consolidatedDir() async {
  await d.dir('consolidated', [
    d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
defaults:
  android: true
  image_path: "assets/icon.png"
flavors:
  dev: {}
  prod: {}
'''),
  ]).create();
  return p.join(d.sandbox, 'consolidated');
}

/// A single-config project (inline pubspec block, no flavors).
Future<String> _singleConfigDir() async {
  await d.dir('single', [
    d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "assets/icon.png"
'''),
  ]).create();
  return p.join(d.sandbox, 'single');
}

/// An empty project (no config of any kind).
Future<String> _emptyDir() async {
  await d.dir('empty', []).create();
  return p.join(d.sandbox, 'empty');
}

void main() {
  group('CLI flag matrix — consolidated multi-flavor source', () {
    test('--list-flavors → 0', () async {
      final dir = await _consolidatedDir();
      expect(await runCli(['generate', '-p', dir, '--list-flavors']), 0);
    });

    test('--flavor dev --all-flavors → 64 (mutually exclusive)', () async {
      final dir = await _consolidatedDir();
      expect(
        await runCli([
          'generate',
          '-p',
          dir,
          '--flavor',
          'dev',
          '--all-flavors',
        ]),
        64,
      );
    });

    test('--flavor ghost (unknown) → 64', () async {
      final dir = await _consolidatedDir();
      expect(
        await runCli(['generate', '-p', dir, '--flavor', 'ghost']),
        64,
      );
    });

    test('--flavor dev --flavor ghost (one unknown) → 64', () async {
      final dir = await _consolidatedDir();
      expect(
        await runCli([
          'generate',
          '-p',
          dir,
          '--flavor',
          'dev',
          '--flavor',
          'ghost',
        ]),
        64,
      );
    });

    test('--all-flavors --list-flavors → 0 (list short-circuits)', () async {
      final dir = await _consolidatedDir();
      expect(
        await runCli(['generate', '-p', dir, '--all-flavors', '--list-flavors']),
        0,
      );
    });

    test('--list-flavors --verbose → 0 (verbose is orthogonal)', () async {
      final dir = await _consolidatedDir();
      expect(
        await runCli(['generate', '-p', dir, '--list-flavors', '-v']),
        0,
      );
    });
  });

  group('CLI flag matrix — single-config source', () {
    test('--list-flavors → 0 (reports no flavors)', () async {
      final dir = await _singleConfigDir();
      expect(await runCli(['generate', '-p', dir, '--list-flavors']), 0);
    });

    test('--flavor dev → 64 (no flavors with a single-config source)', () async {
      final dir = await _singleConfigDir();
      expect(await runCli(['generate', '-p', dir, '--flavor', 'dev']), 64);
    });
  });

  group('CLI flag matrix — no config present', () {
    test('bare generate → 65 (no config found)', () async {
      final dir = await _emptyDir();
      expect(await runCli(['generate', '-p', dir]), 65);
    });

    test('--flavor x → 65 (source resolution fails before flavor check)', () async {
      final dir = await _emptyDir();
      expect(await runCli(['generate', '-p', dir, '--flavor', 'x']), 65);
    });

    test(
      '--flavor x --all-flavors → 64 (mutual-exclusion wins over no-config)',
      () async {
        // The conflicting-flag check runs BEFORE source resolution, so this
        // is a usage error (64), not a config error (65), even with no config.
        final dir = await _emptyDir();
        expect(
          await runCli([
            'generate',
            '-p',
            dir,
            '--flavor',
            'x',
            '--all-flavors',
          ]),
          64,
        );
      },
    );
  });

  group('CLI flag matrix — unknown flags', () {
    test('unknown long option → 64', () async {
      expect(await runCli(['generate', '--no-such-flag']), 64);
    });

    test('unknown short option → 64', () async {
      expect(await runCli(['generate', '-Z']), 64);
    });
  });
}
