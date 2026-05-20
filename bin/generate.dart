// Deprecated entrypoint.
//
// In the original `flutter_launcher_icons` package, this binary lived at
// `bin/generate.dart` and could be invoked as
// `flutter pub run flutter_launcher_icons:generate` to scaffold a starter
// `flutter_launcher_icons.yaml`.
//
// In the `flutter_launcher_icons_flavors` fork, `generate` is the **default
// subcommand of the main CLI** — it produces launcher icons, not scaffolding.
// Keeping a separate top-level `generate.dart` would either shadow the new
// subcommand name or silently behave differently depending on how it was
// invoked. Both options are footguns, so this binary is now a thin
// deprecation shim that redirects the user to the unified entrypoint.
//
// Scaffolding a starter YAML is not currently a supported feature; track
// https://github.com/tmura-ido/flutter_launcher_icons_flavors if you need it
// re-introduced.
import 'dart:io';

void main(List<String> arguments) {
  stderr.writeln(
    'flutter_launcher_icons_flavors: the standalone `generate` entrypoint '
    '(`dart run flutter_launcher_icons_flavors:generate`) is deprecated.\n\n'
    'Use the unified CLI instead:\n'
    '  dart run flutter_launcher_icons_flavors           # default = generate\n'
    '  dart run flutter_launcher_icons_flavors generate  # explicit\n'
    '  dart run flutter_launcher_icons_flavors --help    # list subcommands\n\n'
    'See README.md for the full migration guide.',
  );
  exit(64);
}
