import 'dart:io';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #565.
/// See: issues/important/issue-565-flavor-pbxproj-corruption.md
///
/// Multi-flavor sequential generation must be idempotent on pbxproj.
/// Running production then staging then production again must NOT
/// accumulate garbage; the final file must remain parseable and match
/// what a single combined generation would produce.
void main() {
  group('issue #565: multi-flavor pbxproj idempotency', () {
    test('sequential flavor updates are idempotent', () async {
      const pbxproj = '''
// !\$*UTF8*\$!
{
/* Begin XCBuildConfiguration section */
		AA01 /* Debug-production */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA1 /* Debug-production.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug-production;
		};
		AA02 /* Debug-staging */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA2 /* Debug-staging.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug-staging;
		};
/* End XCBuildConfiguration section */
	rootObject = AA00 /* Project object */;
}
''';
      await d.dir('proj_565', [
        d.dir('ios', [
          d.dir('Runner.xcodeproj', [d.file('project.pbxproj', pbxproj)]),
        ]),
      ]).create();
      final dir = p.join(d.sandbox, 'proj_565');
      final pbxprojPath = p.join(
        dir,
        'ios',
        'Runner.xcodeproj',
        'project.pbxproj',
      );

      // First wave: production then staging.
      await ios.changeIosLauncherIcon(
        '"AppIcon-production"',
        'production',
        prefixPath: dir,
      );
      await ios.changeIosLauncherIcon(
        '"AppIcon-staging"',
        'staging',
        prefixPath: dir,
      );
      final afterFirstWave = await File(pbxprojPath).readAsString();

      // Second wave: same updates again.
      await ios.changeIosLauncherIcon(
        '"AppIcon-production"',
        'production',
        prefixPath: dir,
      );
      await ios.changeIosLauncherIcon(
        '"AppIcon-staging"',
        'staging',
        prefixPath: dir,
      );
      final afterSecondWave = await File(pbxprojPath).readAsString();

      expect(
        afterSecondWave,
        equals(afterFirstWave),
        reason: 'sequential flavor pbxproj edits must be idempotent',
      );

      // Each flavor must have ended with its own catalog name.
      expect(afterSecondWave, contains('"AppIcon-production";'));
      expect(afterSecondWave, contains('"AppIcon-staging";'));
    });
  });
}
