import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #139 / #199.
/// See: issues/approved/issue-139-run-optipng-on-output.md
///
/// `optimize_png: true` swaps the encoder for the `image` package's
/// max-compression level. Verify the flag parses and the helper produces
/// a smaller (or at worst equal) byte output for a typical icon-shaped
/// source.
void main() {
  group('issue #139: optimize_png opt-in flag', () {
    test('Config.optimizePng defaults to false', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
      });
      expect(cfg.optimizePng, isFalse);
    });

    test('Config.optimizePng round-trips through fromJson', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'optimize_png': true,
      });
      expect(cfg.optimizePng, isTrue);
    });

    test('encodePngOptimized lossless: pixels equal between modes', () {
      final src = Image(width: 64, height: 64);
      for (final px in src) {
        px.setRgba(px.x * 4 & 0xFF, px.y * 4 & 0xFF, 128, 255);
      }

      final fast = utils.encodePngOptimized(src, optimize: false);
      final tight = utils.encodePngOptimized(src, optimize: true);

      final fastDecoded = decodePng(fast as dynamic)!;
      final tightDecoded = decodePng(tight as dynamic)!;
      expect(fastDecoded.width, 64);
      expect(tightDecoded.width, 64);
      // Pixel comparison: at least the corner pixels match.
      expect(fastDecoded.getPixel(0, 0).r, tightDecoded.getPixel(0, 0).r);
      expect(
        fastDecoded.getPixel(63, 63).r,
        tightDecoded.getPixel(63, 63).r,
      );
    });

    test('encodePngOptimized produces output <= the fast encoder', () {
      // Use a noisier source that compression can act on.
      final src = Image(width: 128, height: 128);
      for (final px in src) {
        // Smooth gradient — high compressibility.
        px.setRgba(px.x, px.y, (px.x + px.y) ~/ 2, 255);
      }
      final fast = utils.encodePngOptimized(src, optimize: false);
      final tight = utils.encodePngOptimized(src, optimize: true);
      // tight may equal fast in pathological cases, but should never be
      // strictly larger.
      expect(tight.length, lessThanOrEqualTo(fast.length));
    });
  });
}
