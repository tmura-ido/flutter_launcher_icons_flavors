import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:test/test.dart';

/// Behavior test for upstream issue #432.
/// See: issues/issue-432-remove-alpha-ios-use-bg-color.md
///
/// Request: when `remove_alpha_ios: true` and no `background_color_ios` is
/// set, the iOS flatten step should fall back to `adaptive_icon_background`
/// (when that value is a hex color) before defaulting to white/black.
///
/// Today: `background_color_ios` defaults to `#ffffff` regardless of
/// whether `adaptive_icon_background` is set. This regression test asserts
/// the precedence rule the issue requests would apply once implemented.
void main() {
  group('issue #432: remove_alpha_ios falls back to adaptive_icon_background', () {
    test(
      'when remove_alpha_ios is true and only adaptive_icon_background is a hex color, '
      'resolveIosAlphaFlattenHex returns the adaptive bg',
      () {
        final cfg = Config.fromJson({
          'image_path': 'a.png',
          'ios': true,
          'android': true,
          'remove_alpha_ios': true,
          'adaptive_icon_background': '#26262D',
          'adaptive_icon_foreground': 'a.png',
        });
        expect(
          ios.resolveIosAlphaFlattenHex(cfg).toLowerCase(),
          equals('#26262d'),
        );
      },
    );

    test(
      'when adaptive_icon_background is a file path (not hex), fallback is white',
      () {
        final cfg = Config.fromJson({
          'image_path': 'a.png',
          'ios': true,
          'android': true,
          'remove_alpha_ios': true,
          'adaptive_icon_background': 'assets/bg.png',
          'adaptive_icon_foreground': 'a.png',
        });
        expect(
          ios.resolveIosAlphaFlattenHex(cfg).toLowerCase(),
          equals('#ffffff'),
        );
      },
    );

    test('when both background_color_ios and adaptive_icon_background are set, '
        'background_color_ios wins', () {
      final cfg = Config.fromJson({
        'image_path': 'a.png',
        'ios': true,
        'android': true,
        'remove_alpha_ios': true,
        'background_color_ios': '#112233',
        'adaptive_icon_background': '#445566',
        'adaptive_icon_foreground': 'a.png',
      });
      // Explicit ios bg always wins. This is already true today (the field
      // simply takes the explicit value); the regression here is to ensure
      // that any future fallback work doesn't break the explicit-wins rule.
      expect(cfg.backgroundColorIOS.toLowerCase(), '#112233');
      expect(
        ios.resolveIosAlphaFlattenHex(cfg).toLowerCase(),
        equals('#112233'),
      );
    });
  });
}
