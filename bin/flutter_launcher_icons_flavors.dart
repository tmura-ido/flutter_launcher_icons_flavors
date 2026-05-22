import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart';
import 'package:flutter_launcher_icons_flavors/src/version.dart';

Future<void> main(List<String> arguments) async {
  stdout.writeln(introMessage(packageVersion));
  exit(await runCli(arguments));
}
