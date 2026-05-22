import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';

Future<void> main(List<String> arguments) async {
  stdout.writeln(
    'This entrypoint is deprecated. Use: dart run flutter_launcher_icons_flavors',
  );
  exit(await runCli(arguments));
}
