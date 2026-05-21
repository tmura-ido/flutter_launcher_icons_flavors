import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #214.
/// See: issues/approved/issue-214-non-square-images-squished.md
///
/// Adds a helper + opt-out config field so doctor / strict mode can warn
/// about non-square sources. Default generation behavior is unchanged.
void main() {
  group('issue #214: non-square source detection', () {
    test('isNonSquare returns true for 710x599', () {
      final src = Image(width: 710, height: 599);
      expect(utils.isNonSquare(src), isTrue);
    });

    test('isNonSquare returns false for 512x512', () {
      final src = Image(width: 512, height: 512);
      expect(utils.isNonSquare(src), isFalse);
    });

    test('Config.nonSquareImageOk defaults to false', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
      });
      expect(cfg.nonSquareImageOk, isFalse);
    });

    test('Config.nonSquareImageOk round-trips through fromJson', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'non_square_image_ok': true,
      });
      expect(cfg.nonSquareImageOk, isTrue);
    });
  });
}
