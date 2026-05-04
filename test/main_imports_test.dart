// A lightweight smoke test that exercises every public `package:` import of
// the renamed package. If any rename was missed, this file fails to compile.

// ignore_for_file: unused_import

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/android.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/macos_config.dart';
import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:flutter_launcher_icons_flavors/config/platform_toggle.dart';
import 'package:flutter_launcher_icons_flavors/config/web_config.dart';
import 'package:flutter_launcher_icons_flavors/config/windows_config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/ios.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/macos/macos_icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/main.dart';
import 'package:flutter_launcher_icons_flavors/src/version.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart';
import 'package:flutter_launcher_icons_flavors/web/web_icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/windows/windows_icon_generator.dart';
import 'package:test/test.dart';

void main() {
  test('renamed package imports resolve', () {
    // The presence of this test compiling is the assertion. We add one
    // trivial expectation so the test runner reports a passing test.
    expect(packageVersion, isNotEmpty);
  });
}
