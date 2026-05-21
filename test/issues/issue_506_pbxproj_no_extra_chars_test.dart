import 'dart:io';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issues #506 and #636.
/// See:
///   issues/important/issue-506-ios-project-pbxproj-corruption.md
///   issues/important/issue-636-pbxproj-extra-characters.md
///
/// Running the iOS pbxproj writer must not append stray fragments
/// (e.g. `roject object */;` or `*/;\n}`) to the end of the file.
/// The byte length of the file may change only by the in-place
/// `ASSETCATALOG_COMPILER_APPICON_NAME` value substitution — the
/// trailing structure of the file must remain intact.
void main() {
  group('issue #506/#636: pbxproj must not gain stray trailing characters',
      () {
    test('no-op invocation leaves trailing structure intact', () async {
      const original = '''
// !\$*UTF8*\$!
{
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	rootObject = 97C146E61CF9000F007C117D /* Project object */;
}
''';
      await d.dir('proj_506', [
        d.dir('ios', [
          d.dir('Runner.xcodeproj', [
            d.file('project.pbxproj', original),
          ]),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_506');

      // flavor == null skips the `currentConfig.contains('-$flavor')` guard,
      // so this rewrites every ASSETCATALOG line in the section.
      await ios.changeIosLauncherIcon('AppIcon', null, prefixPath: dir);

      final contents = await File(
        p.join(dir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).readAsString();

      // The "rootObject = ... /* Project object */;" line must appear
      // exactly once. The #506 bug duplicated it (or a partial of it).
      expect(
        RegExp(r'/\* Project object \*/;').allMatches(contents).length,
        equals(1),
        reason: 'rootObject reference must appear exactly once',
      );
      expect(contents.trim().endsWith('}'), isTrue,
          reason: 'pbxproj must still end with closing brace');
      // Total opening braces must equal total closing braces — proxy
      // for "structure stayed intact".
      expect(
        '{'.allMatches(contents).length,
        equals('}'.allMatches(contents).length),
        reason: 'brace pairing must remain balanced after rewrite',
      );
    });

    test('repeated invocations are idempotent', () async {
      const original = '''
// !\$*UTF8*\$!
{
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	rootObject = 97C146E61CF9000F007C117D /* Project object */;
}
''';
      await d.dir('proj_506_idem', [
        d.dir('ios', [
          d.dir('Runner.xcodeproj', [
            d.file('project.pbxproj', original),
          ]),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_506_idem');
      final pbxprojPath =
          p.join(dir, 'ios', 'Runner.xcodeproj', 'project.pbxproj');

      await ios.changeIosLauncherIcon('AppIcon', null, prefixPath: dir);
      final firstPass = await File(pbxprojPath).readAsString();
      await ios.changeIosLauncherIcon('AppIcon', null, prefixPath: dir);
      final secondPass = await File(pbxprojPath).readAsString();

      // Running twice with the same input must yield byte-identical output.
      expect(secondPass, equals(firstPass));
    });
  });
}
