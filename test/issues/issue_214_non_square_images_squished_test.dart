import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:test/test.dart';

/// Behavior test for upstream issue #214.
///
/// `createResizedImage` letter-boxes non-square sources when given a
/// background color, preserving aspect ratio instead of squishing. Without
/// a background color the legacy squish behavior is kept for backwards
/// compatibility.
void main() {
  group('issue #214: non-square sources should not be squished', () {
    test('createResizedImage on a 710x599 source preserves aspect ratio '
        'when a background color is supplied', () {
      // A red 710x599 source. After resizing to 100x100 with a white
      // background, the result should be letter-boxed: red pixels in the
      // centered horizontal band and white bars on the short axis (top
      // and bottom).
      final src = Image(width: 710, height: 599);
      for (final p in src) {
        p.setRgba(255, 0, 0, 255);
      }

      final resized = utils.createResizedImage(
        100,
        src,
        backgroundColor: ColorUint8.rgba(255, 255, 255, 255),
      );
      expect(resized.width, equals(100));
      expect(resized.height, equals(100));

      // Letter-boxing means the top row should NOT be uniformly red —
      // it should contain the background color (or be transparent).
      bool topRowAllRed = true;
      for (var x = 0; x < resized.width; x++) {
        final p = resized.getPixel(x, 0);
        if (p.r != 255 || p.g != 0 || p.b != 0) {
          topRowAllRed = false;
          break;
        }
      }
      expect(
        topRowAllRed,
        isFalse,
        reason: 'a letter-boxed resize should leave bars on the short axis',
      );
    });

    test(
      'createResizedImage without backgroundColor keeps legacy squish behavior',
      () {
        // No background color → no letter-boxing → the entire 100×100
        // output is red (the source color), preserving the existing
        // default for callers that have not opted in.
        final src = Image(width: 710, height: 599);
        for (final p in src) {
          p.setRgba(255, 0, 0, 255);
        }

        final resized = utils.createResizedImage(100, src);
        expect(resized.width, equals(100));
        expect(resized.height, equals(100));

        final p = resized.getPixel(0, 0);
        expect(p.r, 255);
        expect(p.g, 0);
        expect(p.b, 0);
      },
    );
  });
}
