import 'dart:io';

import 'package:flutter_launcher_icons_flavored/cli/command_runner.dart';
import 'package:flutter_launcher_icons_flavored/constants.dart';
import 'package:flutter_launcher_icons_flavored/src/version.dart';

Future<void> main(List<String> arguments) async {
  stdout.writeln(introMessage(packageVersion));
  final runner = buildCommandRunner();
  final code = await runner.run(effectiveArgs(arguments)) ?? 0;
  exit(code);
}
