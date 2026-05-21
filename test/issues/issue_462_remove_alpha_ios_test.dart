import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:test/test.dart';

/// Regression test for upstream issue #462.
/// See: issues/important/issue-462-remove-alpha-ios-ignored.md
///
/// `remove_alpha_ios: true` must be parsed from both `flutter_icons:`
/// (legacy) and `flutter_launcher_icons:` blocks and surface as
/// [Config.removeAlphaIOS] == true. If the JSON parser swallows the
/// flag, the iOS pipeline silently keeps alpha and (more visibly)
/// re-prints the "Set remove_alpha_ios: true to remove it" warning
/// even when the user already set it.
void main() {
  group('issue #462: remove_alpha_ios flag is honored', () {
    test('Config.fromJson preserves remove_alpha_ios: true', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'ios': true,
        'remove_alpha_ios': true,
      });
      expect(cfg.removeAlphaIOS, isTrue);
    });

    test('Config.fromJson defaults remove_alpha_ios to false when omitted', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'ios': true,
      });
      expect(cfg.removeAlphaIOS, isFalse);
    });

    test('Config.fromJson preserves remove_alpha_ios: false', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'ios': true,
        'remove_alpha_ios': false,
      });
      expect(cfg.removeAlphaIOS, isFalse);
    });
  });
}
