import 'dart:io';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #612.
/// See: issues/important/issue-612-ios-pbxproj-race-condition-across-flavors.md
///
/// The flavor matcher in `changeIosLauncherIcon` does
/// `currentConfig.contains('-$flavor')`. Two flavors sharing a prefix
/// (e.g. `style1` and `style10`) would cause an update for `style1` to
/// also match `style10`'s xcconfig (`Debug-style10.xcconfig` contains
/// `-style1`). The expected correct behavior is to anchor the match on
/// a delimiter so `style1` only matches `-style1.xcconfig` (or
/// `-style1-Debug.xcconfig`), NOT `-style10.xcconfig`.
void main() {
  group('issue #612: flavor prefix collision in pbxproj matcher', () {
    test('updating "style1" must not also overwrite "style10" line', () async {
      const pbxproj = '''
// !\$*UTF8*\$!
{
/* Begin XCBuildConfiguration section */
		AA01 /* Debug-style1 */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA1 /* Debug-style1.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug-style1;
		};
		AA02 /* Debug-style10 */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA2 /* Debug-style10.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug-style10;
		};
/* End XCBuildConfiguration section */
}
''';
      await d.dir('proj_612', [
        d.dir('ios', [
          d.dir('Runner.xcodeproj', [d.file('project.pbxproj', pbxproj)]),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_612');

      await ios.changeIosLauncherIcon(
        '"AppIcon-style1"',
        'style1',
        prefixPath: dir,
      );

      final contents = await File(
        p.join(dir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).readAsString();

      // style1 block must be updated.
      final style1Block = RegExp(
        r'Debug-style1\.xcconfig \*/;\s*\n\s*buildSettings = \{\s*\n\s*ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-style1";',
      );
      expect(
        style1Block.hasMatch(contents),
        isTrue,
        reason: 'style1 block must receive the AppIcon-style1 name',
      );

      // style10 block must remain on the original (untouched) value.
      final style10Untouched = RegExp(
        r'Debug-style10\.xcconfig \*/;\s*\n\s*buildSettings = \{\s*\n\s*ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
      );
      expect(
        style10Untouched.hasMatch(contents),
        isTrue,
        reason: 'style10 block must NOT be matched by style1 update',
      );
    });
  });
}
