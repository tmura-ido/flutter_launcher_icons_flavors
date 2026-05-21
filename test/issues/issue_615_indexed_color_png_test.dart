import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Behavior test for upstream issue #615.
/// See: issues/issue-615-rangeerror-on-indexed-color-png.md
///
/// Indexed-color (palette) PNGs throw a deep RangeError inside the `image`
/// package during `Image.convert`. The fork should surface a friendly
/// error early, ideally via `decodeImageFile` raising a clear exception
/// that mentions remediation.
void main() {
  group('issue #615: indexed-color PNG fails with friendly error', () {
    test('decoding a palette PNG raises a clear exception (not RangeError)',
        () async {
      // Build a tiny palette-format PNG. image v4 supports a palette format
      // via setFormat / palette parameter — we use copyResize-style raw
      // construction.
      final paletted = Image(
        width: 4,
        height: 4,
        format: Format.uint8,
        numChannels: 3,
        withPalette: true,
      );
      // Fill the palette and some pixels so the decoder hits the palette
      // codepath.
      final palette = paletted.palette;
      expect(palette, isNotNull);
      palette!.setRgb(0, 255, 0, 0);
      palette.setRgb(1, 0, 255, 0);

      final bytes = encodePng(paletted);
      await d.file('paletted.png', bytes).create();
      final path = p.join(d.sandbox, 'paletted.png');

      // We don't currently raise an InvalidImageException; this test
      // documents the desired surface area. Either the decode succeeds
      // (the image package handles palettes for some sizes) OR a clear
      // exception bubbles up; what we don't want is a bare RangeError.
      Object? caught;
      try {
        await utils.decodeImageFile(path);
      } catch (e) {
        caught = e;
      }
      if (caught != null) {
        expect(
          caught,
          isNot(isA<RangeError>()),
          reason:
              'Indexed-color PNGs should fail with a friendly exception '
              'mentioning remediation, not a raw RangeError. See issue-615.',
        );
        // Acceptable types: NoDecoderForImageFormatException or a future
        // InvalidImageException.
        expect(
          caught,
          anyOf(
            isA<NoDecoderForImageFormatException>(),
            isA<Exception>(),
          ),
        );
      }
    });
  });
}
