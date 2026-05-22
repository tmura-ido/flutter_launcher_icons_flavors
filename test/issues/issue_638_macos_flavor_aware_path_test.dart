import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:test/test.dart';

/// Behavior test for upstream issue #638.
/// See: issues/important/issue-638-macos-ignores-flavors.md
///
/// The current macOS implementation writes to the single
/// `constants.macOSIconsDirPath` and `constants.macOSContentsFilePath`
/// regardless of flavor. iOS uses per-flavor `AppIcon-<flavor>` asset
/// sets — macOS should mirror that to achieve flavor parity.
///
/// The test asserts the eventual contract: a flavor-aware helper
/// (parallel to `androidResFolder(flavor)`) must exist. It will fail
/// today because `constants` exposes only the flavor-agnostic paths.
void main() {
  group('issue #638: macOS paths are not flavor-aware', () {
    test('today: macOS paths are flavor-agnostic constants', () {
      // Document today's reality: there is exactly one global path.
      expect(
        constants.macOSIconsDirPath,
        'macos/Runner/Assets.xcassets/AppIcon.appiconset',
      );
      expect(
        constants.macOSContentsFilePath,
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
      );
    });

    test('macOSIconsDirPathFor(null) returns the default AppIcon path', () {
      expect(constants.macOSIconsDirPathFor(null), constants.macOSIconsDirPath);
    });

    test(
      'macOSIconsDirPathFor("dev") returns the per-flavor asset-set path',
      () {
        expect(
          constants.macOSIconsDirPathFor('dev'),
          'macos/Runner/Assets.xcassets/AppIcon-dev.appiconset',
        );
      },
    );

    test('macOSContentsFilePathFor mirrors the icons-dir path', () {
      expect(
        constants.macOSContentsFilePathFor('prod'),
        'macos/Runner/Assets.xcassets/AppIcon-prod.appiconset/Contents.json',
      );
    });
  });
}
