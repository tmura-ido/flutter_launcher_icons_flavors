import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:test/test.dart';

/// Regression / consistency test for upstream issue #153.
/// See: issues/issue-153-ios-unassigned-children.md
///
/// Xcode warns about "unassigned children" when a PNG exists on disk in
/// the AppIcon set but the Contents.json does not reference it. The
/// inverse — Contents.json references a file that was never written —
/// also breaks. This test verifies that every filename listed in the
/// generated Contents.json maps to a file the writer actually creates
/// (one of `iosIcons` for the modern set or `legacyIosIcons` for the
/// pre-Xcode-14 set).
void main() {
  group('issue #153: iOS Contents.json has no unassigned children', () {
    test(
      'every modern Contents.json filename matches an iosIcons template',
      () {
        const prefix = 'Icon-App';
        final templateNames = ios.iosIcons
            .map((t) => '$prefix${t.name}.png')
            .toSet();
        final imageList = ios.createImageList(prefix, null, null);
        for (final entry in imageList) {
          expect(
            templateNames,
            contains(entry['filename']),
            reason:
                'Contents.json entry ${entry['filename']} is not produced '
                'by any IosIconTemplate in iosIcons',
          );
        }
      },
    );

    test(
      'every legacy Contents.json filename matches a legacyIosIcons template',
      () {
        const prefix = 'Icon-App';
        final templateNames = ios.legacyIosIcons
            .map((t) => '$prefix${t.name}.png')
            .toSet();
        final imageList = ios.createLegacyImageList(prefix);
        for (final entry in imageList) {
          expect(
            templateNames,
            contains(entry['filename']),
            reason:
                'Legacy Contents.json entry ${entry['filename']} is not '
                'produced by any IosIconTemplate in legacyIosIcons',
          );
        }
      },
    );

    test('modern iOS image list drops legacy 50/57/72 sizes', () {
      // The modern (Xcode 14+) Asset Catalog format uses the
      // universal/ios idiom and a smaller set of sizes; the 50/57/72
      // entries are gone. Without this guarantee, an upgrade would
      // either leave stale PNGs on disk (issue #153) or list filenames
      // that no longer exist on disk.
      final imageList = ios.createImageList('Icon-App', null, null);
      for (final entry in imageList) {
        expect(entry['size'], isNot(equals('50x50')));
        expect(entry['size'], isNot(equals('57x57')));
        expect(entry['size'], isNot(equals('72x72')));
      }
    });
  });
}
