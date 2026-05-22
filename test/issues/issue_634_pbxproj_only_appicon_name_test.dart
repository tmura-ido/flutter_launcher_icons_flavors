import 'dart:io';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #634.
/// See: issues/important/issue-634-pbxproj-corruption-flavors.md
///
/// `changeIosLauncherIcon` uses `line.contains('ASSETCATALOG')` to decide
/// which line to overwrite. That substring also appears in
/// `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` — a
/// boolean setting that must stay `YES`. The bug is that running the
/// generator clobbers it with `AppIcon-staging`, breaking Xcode.
///
/// The expected correct behavior: only the line matching the exact key
/// `ASSETCATALOG_COMPILER_APPICON_NAME` is rewritten.
void main() {
  group(
    'issue #634: pbxproj must only mutate ASSETCATALOG_COMPILER_APPICON_NAME',
    () {
      test('unrelated ASSETCATALOG_* settings are preserved', () async {
        const pbxproj = '''
// !\$*UTF8*\$!
{
/* Begin XCBuildConfiguration section */
		AA01 /* Debug-staging */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA1 /* Debug-staging.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
			};
			name = Debug-staging;
		};
/* End XCBuildConfiguration section */
}
''';
        await d.dir('proj_634', [
          d.dir('ios', [
            d.dir('Runner.xcodeproj', [d.file('project.pbxproj', pbxproj)]),
          ]),
        ]).create();
        final dir = p.join(d.sandbox, 'proj_634');

        await ios.changeIosLauncherIcon(
          '"AppIcon-staging"',
          'staging',
          prefixPath: dir,
        );

        final contents = await File(
          p.join(dir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
        ).readAsString();

        // The APPICON_NAME line must be updated.
        expect(
          contents,
          contains('ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-staging";'),
        );
        // The GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS line must stay YES.
        expect(
          contents,
          contains(
            'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
          ),
        );
      });
    },
  );
}
