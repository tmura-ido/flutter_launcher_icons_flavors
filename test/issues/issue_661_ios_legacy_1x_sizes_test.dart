import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:test/test.dart';

/// Regression test for upstream issue #661.
/// See: issues/important/issue-661-ios-app-switcher-uses-default-icon.md
///
/// When dark/tinted variants are enabled, the iOS pipeline currently
/// switches to the smaller `iosIcons` list, which omits several legacy
/// 1x sizes (`-20x20@1x`, `-29x29@1x`, `-40x40@1x`, `-76x76@1x`). The
/// iPhone app-switcher and a few other system surfaces still ask for
/// those 1x assets, falling back to the default Flutter icon when
/// they are missing.
///
/// Expected behavior (post-fix): the light/default catalog always
/// contains the union of legacy + modern sizes; the dark/tinted slice
/// can stay on the modern subset.
void main() {
  group('issue #661: legacy 1x sizes are present', () {
    test('legacyIosIcons covers the missing 1x sizes', () {
      const wanted = ['-20x20@1x', '-29x29@1x', '-40x40@1x', '-76x76@1x'];
      final legacyNames = ios.legacyIosIcons.map((t) => t.name).toSet();
      for (final name in wanted) {
        expect(legacyNames, contains(name),
            reason: 'legacyIosIcons should contain $name');
      }
    });

    test('Config.iosLegacySizes flag defaults to false', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
      });
      expect(cfg.iosLegacySizes, isFalse);
    });

    test('Config.iosLegacySizes round-trips through fromJson', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
        'ios_legacy_sizes': true,
      });
      expect(cfg.iosLegacySizes, isTrue);
    });
  });
}
