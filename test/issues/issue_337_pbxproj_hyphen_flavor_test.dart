import 'dart:io';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #337.
/// See: issues/important/issue-337-ios-flavor-name-truncation-pbxproj.md
///
/// Flavor names containing hyphens (e.g. `flavor-qa-dev`) must end up
/// fully preserved AND properly quoted in
/// `ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-flavor-qa-dev";`.
/// The bug: the value was emitted unquoted and truncated at the first
/// hyphen (`= AppIcon-flavor;`), corrupting the Xcode project.
void main() {
  group(
    'issue #337: pbxproj appicon name truncation with hyphenated flavors',
    () {
      test(
        'changeIosLauncherIcon preserves full hyphenated flavor name and quotes it',
        () async {
          const flavor = 'flavor-qa-dev';
          const xcconfigName = 'Debug-$flavor';
          // Minimal pbxproj fragment exercising the XCBuildConfiguration
          // section that `changeIosLauncherIcon` mutates.
          const pbxproj =
              '''
// !\$*UTF8*\$!
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 9740EEB21CF90195004384FC /* $xcconfigName.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
''';
          await d.dir('proj_337', [
            d.dir('ios', [
              d.dir('Runner.xcodeproj', [d.file('project.pbxproj', pbxproj)]),
            ]),
          ]).create();
          final dir = p.join(d.sandbox, 'proj_337');

          await ios.changeIosLauncherIcon(
            '"AppIcon-$flavor"',
            flavor,
            prefixPath: dir,
          );

          final contents = await File(
            p.join(dir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
          ).readAsString();

          // Must contain the fully-quoted, fully-preserved value.
          expect(contents, contains('"AppIcon-$flavor";'));
          // Must NOT contain a truncated unquoted value.
          expect(contents, isNot(contains('= AppIcon-flavor;')));
        },
      );
    },
  );
}
