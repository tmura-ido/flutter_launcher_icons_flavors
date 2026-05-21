import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:test/test.dart';

/// Behavior / bug-doc test for upstream issue #214.
/// See: issues/issue-214-non-square-images-squished.md
///
/// Today `createResizedImage` always produces an N×N image regardless of
/// the source aspect ratio, which visibly squishes non-square sources.
/// The desired behavior is either to (a) reject non-square inputs in
/// `--strict` mode, or (b) letter-box the source to a square canvas
/// before resizing. Either way the result should preserve the original
/// aspect ratio of the visible content.
void main() {
  group('issue #214: non-square sources should not be squished', () {
    test(
      'createResizedImage on a 710x599 source preserves aspect ratio',
      () {
        // A red 710x599 source. After resizing to 100x100, the resulting
        // pixels should not be a uniform red square — they should be
        // letter-boxed (transparent/background bars top+bottom or
        // left+right) so that the original aspect ratio is preserved.
        final src = Image(width: 710, height: 599);
        for (final p in src) {
          p.setRgba(255, 0, 0, 255);
        }

        final resized = utils.createResizedImage(100, src);
        expect(resized.width, equals(100));
        expect(resized.height, equals(100));

        // Letter-boxing implies the top or bottom rows contain pixels
        // that are NOT the original red — they are transparent or the
        // configured background color. A correctly letter-boxed image
        // will therefore have at least one non-red pixel along the very
        // top row.
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
      },
      skip: 'bug — see issue-214, will fail until letter-boxing lands',
    );
  });
}
