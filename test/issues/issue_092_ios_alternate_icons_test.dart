import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #92 (phase 1).
/// See: issues/approved/issue-092-ios-alternate-app-icons.md
///
/// Phase 1: config schema only. Asset emission lands separately; Info.plist
/// patching is phase 2 (bundled with #612 pbxproj rewrite).
void main() {
  group('issue #92: ios_alternate_icons config schema (phase 1)', () {
    test('schema parses with enabled + multiple icon entries', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
        'ios_alternate_icons': {
          'enabled': true,
          'icons': {
            'red': {'image_path': 'assets/icon-red.png'},
            'blue': {
              'image_path': 'assets/icon-blue.png',
              'image_path_dark_transparent': 'assets/icon-blue-dark.png',
              'image_path_tinted_grayscale': 'assets/icon-blue-tinted.png',
            },
          },
        },
      });
      expect(cfg.iosAlternateIcons, isNotNull);
      expect(cfg.iosAlternateIcons!.enabled, isTrue);
      expect(cfg.iosAlternateIcons!.icons.keys.toSet(), {'red', 'blue'});
      expect(cfg.iosAlternateIcons!.icons['red']!.imagePath,
          'assets/icon-red.png');
      expect(cfg.iosAlternateIcons!.icons['blue']!.imagePathDarkTransparent,
          'assets/icon-blue-dark.png');
      expect(cfg.iosAlternateIcons!.icons['blue']!.imagePathTintedGrayscale,
          'assets/icon-blue-tinted.png');
    });

    test('schema is optional (omitted entirely is fine)', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
      });
      expect(cfg.iosAlternateIcons, isNull);
    });

    test('enabled: false is parsed without icons', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
        'ios_alternate_icons': {'enabled': false},
      });
      expect(cfg.iosAlternateIcons!.enabled, isFalse);
      expect(cfg.iosAlternateIcons!.icons, isEmpty);
    });
  });
}
