// A lightweight smoke test that exercises every public `package:` import of
// the renamed package. If any rename was missed, this file fails to compile.

// ignore_for_file: unused_import

import 'package:flutter_launcher_icons_flavored/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavored/android.dart';
import 'package:flutter_launcher_icons_flavored/config/config.dart';
import 'package:flutter_launcher_icons_flavored/config/macos_config.dart';
import 'package:flutter_launcher_icons_flavored/config/partial_config.dart';
import 'package:flutter_launcher_icons_flavored/config/platform_toggle.dart';
import 'package:flutter_launcher_icons_flavored/config/web_config.dart';
import 'package:flutter_launcher_icons_flavored/config/windows_config.dart';
import 'package:flutter_launcher_icons_flavored/constants.dart';
import 'package:flutter_launcher_icons_flavored/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavored/ios.dart';
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:flutter_launcher_icons_flavored/macos/macos_icon_generator.dart';
import 'package:flutter_launcher_icons_flavored/main.dart';
import 'package:flutter_launcher_icons_flavored/src/version.dart';
import 'package:flutter_launcher_icons_flavored/utils.dart';
import 'package:flutter_launcher_icons_flavored/web/web_icon_generator.dart';
import 'package:flutter_launcher_icons_flavored/windows/windows_icon_generator.dart';
import 'package:test/test.dart';

void main() {
  test('renamed package imports resolve', () {
    // The presence of this test compiling is the assertion. We add one
    // trivial expectation so the test runner reports a passing test.
    expect(packageVersion, isNotEmpty);
  });
}
