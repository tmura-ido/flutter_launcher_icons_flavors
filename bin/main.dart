import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';

Future<void> main(List<String> arguments) async {
  stdout.writeln(
    'This entrypoint is deprecated. Use: dart run flutter_launcher_icons_flavors',
  );
  final runner = buildCommandRunner();
  final code = await runner.run(effectiveArgs(arguments)) ?? 0;
  exit(code);
}
