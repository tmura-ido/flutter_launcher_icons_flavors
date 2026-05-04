import 'package:args/command_runner.dart';

import 'doctor_command.dart';
import 'generate_command.dart';
import 'migrate_command.dart';

/// Subcommand names recognized by the runner. Used by `bin/main.dart`
/// to decide whether the bare-invocation default-to-`generate` shim
/// should fire.
const Set<String> knownSubcommands = {'generate', 'migrate', 'doctor', 'help'};

/// Builds the top-level [CommandRunner] for the
/// `flutter_launcher_icons_flavored` CLI.
///
/// Returning a `CommandRunner<int>` lets each subcommand return the
/// desired process exit code; the entry point (`bin/main.dart`)
/// translates that to `exit(code)`.
CommandRunner<int> buildCommandRunner() {
  final runner =
      CommandRunner<int>(
          'flutter_launcher_icons_flavored',
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
/// (`dart run flutter_launcher_icons_flavored -f my.yaml`) keep
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
