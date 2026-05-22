// Behavior contract: unknown CLI arguments are rejected with exit 64.
//
// Two failure modes are covered:
//
//   1. Unknown OPTIONS (`--foobar`) — caught by the args package via
//      UsageException; `runCli` wraps that into a clean exit 64 so the
//      user sees a message instead of a Dart stack trace.
//
//   2. Unknown POSITIONAL arguments (`generate foobar`) — silently
//      ignored by `args` (they land in `argResults.rest`); every
//      subcommand now calls `rejectUnknownArgs` to fail fast with
//      exit 64.

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:test/test.dart';

void main() {
  group('CLI rejects unknown arguments', () {
    // ---- unknown options ----------------------------------------------
    test('unknown long option on `generate` → exit 64', () async {
      final code = await runCli(['generate', '--foobar']);
      expect(code, 64);
    });

    test('unknown short option on `generate` → exit 64', () async {
      final code = await runCli(['generate', '-Q']);
      expect(code, 64);
    });

    test('unknown option on `migrate` → exit 64', () async {
      final code = await runCli(['migrate', '--foobar']);
      expect(code, 64);
    });

    test('unknown option on `doctor` → exit 64', () async {
      final code = await runCli(['doctor', '--foobar']);
      expect(code, 64);
    });

    test('unknown top-level option (bare invocation) → exit 64', () async {
      // Bare invocations route through `effectiveArgs`, which prepends
      // `generate`. The unknown option still has to fail.
      final code = await runCli(['--foobar']);
      expect(code, 64);
    });

    // ---- unknown positional args --------------------------------------
    test(
      'unknown positional arg on `generate` → exit 64 (no silent drop)',
      () async {
        final code = await runCli(['generate', 'foobar']);
        expect(code, 64);
      },
    );

    test('multiple unknown positional args on `generate` → exit 64', () async {
      final code = await runCli(['generate', 'foo', 'bar', 'baz']);
      expect(code, 64);
    });

    test('unknown positional arg on `migrate` → exit 64', () async {
      final code = await runCli(['migrate', 'foobar']);
      expect(code, 64);
    });

    test('unknown positional arg on `doctor` → exit 64', () async {
      final code = await runCli(['doctor', 'foobar']);
      expect(code, 64);
    });

    test('bare unknown subcommand → exit 64 (routed via effectiveArgs into '
        'generate, then caught as a stray positional)', () async {
      // `flutter_launcher_icons_flavors foobar` becomes
      // `generate foobar`, which is now a positional-arg error.
      final code = await runCli(['foobar']);
      expect(code, 64);
    });

    // ---- happy path still works ---------------------------------------
    test(
      '--help still exits 0 (smoke check that we did not break it)',
      () async {
        final code = await runCli(['--help']);
        expect(code, anyOf(0, isNull));
      },
    );
  });
}
