import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:test/test.dart';

/// Behavior test for upstream issue #637.
/// See: issues/important/issue-637-xcodeproj-path-ignored-with-flavors.md
///
/// `xcodeproj_path` is a documented per-flavor override in the wider
/// flutter_launcher_icons ecosystem, but the fork has zero plumbing
/// for it. `lib/constants.dart` hard-codes
/// `'ios/Runner.xcodeproj/project.pbxproj'`, and the
/// `disallowUnrecognizedKeys: true` flag on `PartialConfig` would
/// reject the key outright. This test documents both gaps.
void main() {
  group('issue #637: xcodeproj_path is not plumbed through', () {
    test('iosConfigFile is the hard-coded Runner.xcodeproj path', () {
      expect(constants.iosConfigFile, 'ios/Runner.xcodeproj/project.pbxproj');
    });

    test('PartialConfig.fromJson accepts and round-trips `xcodeproj_path`',
        () {
      final p = PartialConfig.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
        'xcodeproj_path': 'ios/MyApp.xcodeproj',
      });
      expect(p.xcodeprojPath, 'ios/MyApp.xcodeproj');
    });
  });
}
