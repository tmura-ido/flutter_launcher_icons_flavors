// Coverage for the alpha-blend helpers (lib/utils/color_utils.dart) that back
// the iOS `remove_alpha_ios` flatten path. Pure math, previously untested.
import 'package:flutter_launcher_icons_flavors/utils/color_utils.dart';
import 'package:image/image.dart';
import 'package:test/test.dart';

void main() {
  group('blendColorsThroughForegroundAlpha (source-over)', () {
    test('opaque foreground wins entirely', () {
      final out = ColorUtils.blendColorsThroughForegroundAlpha(
        ColorUint8.rgba(10, 20, 30, 255),
        ColorUint8.rgba(0, 0, 0, 255),
      );
      expect([out.r, out.g, out.b, out.a], [10, 20, 30, 255]);
    });

    test('fully transparent foreground yields the background', () {
      final out = ColorUtils.blendColorsThroughForegroundAlpha(
        ColorUint8.rgba(10, 20, 30, 0),
        ColorUint8.rgba(100, 110, 120, 255),
      );
      expect([out.r, out.g, out.b, out.a], [100, 110, 120, 255]);
    });

    test('50% foreground over black is ~half intensity, stays opaque', () {
      final out = ColorUtils.blendColorsThroughForegroundAlpha(
        ColorUint8.rgba(200, 200, 200, 128),
        ColorUint8.rgba(0, 0, 0, 255),
      );
      // 200 * 128/255 ≈ 100.4 → 100
      expect(out.r, 100);
      expect(out.a, 255);
    });
  });

  group('makeOpaque', () {
    test('already-opaque color is returned as-is (same instance)', () {
      final c = ColorUint8.rgba(1, 2, 3, 255);
      expect(identical(ColorUtils.makeOpaque(c), c), isTrue);
    });

    test('transparent color over the default white background → white', () {
      final out = ColorUtils.makeOpaque(ColorUint8.rgba(0, 0, 0, 0));
      expect([out.r, out.g, out.b, out.a], [255, 255, 255, 255]);
    });

    test('transparent color over a custom opaque background', () {
      final out = ColorUtils.makeOpaque(
        ColorUint8.rgba(0, 0, 0, 0),
        background: ColorUint8.rgb(10, 20, 30),
      );
      expect([out.r, out.g, out.b, out.a], [10, 20, 30, 255]);
    });

    test('does not mutate the caller-supplied background argument', () {
      // makeOpaque force-opaques a non-opaque background before blending.
      // Doing that in place mutates the caller's Color — a function that
      // computes a blended color should not have that side effect.
      final bg = ColorUint8.rgba(10, 20, 30, 128);
      ColorUtils.makeOpaque(ColorUint8.rgba(0, 0, 0, 0), background: bg);
      expect(
        bg.a,
        128,
        reason: 'makeOpaque mutated its background argument to opaque in place',
      );
    });
  });
}
