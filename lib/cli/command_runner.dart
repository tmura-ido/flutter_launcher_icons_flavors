import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';

import 'doctor_command.dart';
import 'generate_command.dart';
import 'migrate_command.dart';

/// Subcommand names recognized by the runner. Used by `bin/main.dart`
/// to decide whether the bare-invocation default-to-`generate` shim
/// should fire.
const Set<String> knownSubcommands = {'generate', 'migrate', 'doctor', 'help'};

/// Builds the top-level [CommandRunner] for the
/// `flutter_launcher_icons_flavors` CLI.
///
/// Returning a `CommandRunner<int>` lets each subcommand return the
/// desired process exit code; the entry point (`bin/main.dart`)
/// translates that to `exit(code)`.
CommandRunner<int> buildCommandRunner() {
  final runner =
      CommandRunner<int>(
          'flutter_launcher_icons_flavors',
          'Generate launcher icons for Flutter apps.',
        )
        ..addCommand(GenerateCommand())
        ..addCommand(MigrateCommand())
        ..addCommand(DoctorCommand());
  return runner;
}

/// Returns the effective argument list for [args].
///
/// If [args] is empty, or its first non-flag token is not one of
/// [knownSubcommands], we prepend `'generate'` so that bare invocations
/// (`dart run flutter_launcher_icons_flavors -f my.yaml`) keep
/// behaving exactly as they did before the `CommandRunner` migration.
///
/// Two edge cases worth calling out:
///   * `--help` / `-h` at the top level still flows to the runner's
///     help — we only inject `generate` when the first non-flag arg
///     looks like an actual positional/option value.
///   * If the user really did invoke `generate` explicitly, we leave
///     the args untouched.
List<String> effectiveArgs(List<String> args) {
  if (args.isEmpty) {
    return const ['generate'];
  }
  // Top-level `--help` / `-h` should reach the runner unchanged so the
  // runner's own help banner fires.
  for (final a in args) {
    if (a == '--help' || a == '-h') {
      return args;
    }
    // Stop at the first non-flag token; that's the candidate
    // subcommand.
    if (!a.startsWith('-')) {
      if (knownSubcommands.contains(a)) {
        return args;
      }
      break;
    }
  }
  return ['generate', ...args];
}

/// Single entry point that wraps the [CommandRunner] with a top-level
/// [UsageException] catch so unknown options / unknown subcommands turn
/// into a clean **exit 64** instead of an uncaught exception with a
/// stack trace.
///
/// Use this from `bin/*.dart` and from tests that want to assert
/// usage-error exit codes. Tests that only exercise valid-arg paths can
/// still call `buildCommandRunner().run(...)` directly.
Future<int> runCli(List<String> args) async {
  try {
    return await buildCommandRunner().run(effectiveArgs(args)) ?? 0;
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    if (e.usage.isNotEmpty) {
      stderr.writeln('');
      stderr.writeln(e.usage);
    }
    return 64;
  }
}

/// Inspects a command's parsed [results] for stray positional arguments.
/// Returns `64` (and logs a clear error) when any are present; returns
/// `null` when the rest is empty so the caller can `return code ?? null`
/// patternlessly.
///
/// Every subcommand calls this at the start of its `run()` so a typo
/// like `dart run flutter_launcher_icons_flavors generate foobar` fails
/// loudly instead of silently dropping the unrecognized token.
int? rejectUnknownArgs(ArgResults results, FLILogger logger) {
  if (results.rest.isEmpty) {
    return null;
  }
  logger.error('Could not run command');
  logger.error(
    'Unknown argument(s): ${results.rest.join(', ')}. '
    'Use --help to see the supported flags.',
  );
  return 64;
}
