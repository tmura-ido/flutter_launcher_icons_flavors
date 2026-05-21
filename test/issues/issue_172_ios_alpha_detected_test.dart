import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #172.
/// See: issues/approved/issue-172-ios-icons-transparent-alpha.md
///
/// Adds a helper that detects alpha pixels in a source image so doctor /
/// strict mode can warn that the App Store will reject the upload.
void main() {
  group('issue #172: source alpha detection helper', () {
    test('imageHasAlphaPixel returns false for fully opaque RGBA source', () {
      final src = Image(width: 4, height: 4, numChannels: 4);
      for (final px in src) {
        px.setRgba(255, 0, 0, 255);
      }
      expect(utils.imageHasAlphaPixel(src), isFalse);
    });

    test('imageHasAlphaPixel returns true for any transparent pixel', () {
      final src = Image(width: 4, height: 4, numChannels: 4);
      for (final px in src) {
        px.setRgba(255, 0, 0, 255);
      }
      // Make one pixel translucent.
      src.getPixel(0, 0).a = 200;
      expect(utils.imageHasAlphaPixel(src), isTrue);
    });

    test('imageHasAlphaPixel returns false for RGB (no alpha channel)', () {
      final src = Image(width: 4, height: 4, numChannels: 3);
      for (final px in src) {
        px.setRgb(255, 0, 0);
      }
      expect(utils.imageHasAlphaPixel(src), isFalse);
    });
  });
}
