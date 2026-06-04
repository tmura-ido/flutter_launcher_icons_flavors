// Permutation coverage of the two hex-color helpers that the config layer and
// every platform writer share:
//
//   * `isHexColorLiteral(v)` — classifies a string as "a color" vs. "a path".
//   * `parseHexColor(v)`     — turns that string into an actual color.
//
// These two MUST agree: any value classified as a color literal has to be
// parseable as one, otherwise a config value sails through validation (it is
// "a color") and then explodes at render time (it cannot be parsed). The
// `classify ⇒ parseable` group below pins that invariant down across every
// accepted length.
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:test/test.dart';

void main() {
  group('parseHexColor — valid forms', () {
    test('#RRGGBB (hashed) → opaque', () {
      final c = utils.parseHexColor('#FF8000');
      expect([c.r, c.g, c.b, c.a], [0xff, 0x80, 0x00, 0xff]);
    });
    test('RRGGBB (unhashed) → opaque', () {
      final c = utils.parseHexColor('00FF00');
      expect([c.r, c.g, c.b, c.a], [0x00, 0xff, 0x00, 0xff]);
    });
    test('#AARRGGBB (hashed, alpha) → alpha honored', () {
      final c = utils.parseHexColor('#80AABBCC');
      expect([c.r, c.g, c.b, c.a], [0xaa, 0xbb, 0xcc, 0x80]);
    });
    test('AARRGGBB (unhashed, alpha)', () {
      final c = utils.parseHexColor('80AABBCC');
      expect([c.r, c.g, c.b, c.a], [0xaa, 0xbb, 0xcc, 0x80]);
    });
  });

  group('parseHexColor — invalid lengths raise InvalidConfigException', () {
    // 3 and 4 digits are now valid shorthand (expanded by parseHexColor); the
    // remaining off-lengths still have no color interpretation and must throw.
    for (final v in ['#f', '#ff', '#fffff', '#fffffff']) {
      test('"$v" (${v.replaceAll('#', '').length} digits)', () {
        expect(
          () => utils.parseHexColor(v),
          throwsA(isA<InvalidConfigException>()),
        );
      });
    }
  });

  group('parseHexColor — malformed digits at a valid length', () {
    // The docstring promises "Throws InvalidConfigException for malformed
    // input", but the implementation only length-checks before calling
    // int.parse — so non-hex digits surface a raw FormatException instead.
    // This pins the documented contract; it fails until parseHexColor
    // validates the digits too.
    for (final v in ['#gggggg', '#zzzzzzzz']) {
      test('"$v" → InvalidConfigException (per docstring)', () {
        expect(
          () => utils.parseHexColor(v),
          throwsA(isA<InvalidConfigException>()),
          reason:
              'parseHexColor only validates length, not hex digits — "$v" '
              'throws a raw FormatException instead of InvalidConfigException.',
        );
      });
    }
  });

  group('isHexColorLiteral — classification matrix', () {
    const expectations = <String, bool>{
      '#fff': true, // #RGB shorthand
      '#ffff': true, // #RGBA shorthand
      '#fffff': false, // 5 digits — not a valid color form
      '#ffffff': true,
      '#fffffff': false, // 7 digits — not a valid color form
      '#ffffffff': true,
      'abcdef': true,
      'ABC': true,
      '#ab': false, // only 2 hex digits
      '#fffffffff': false, // 9 digits — too long
      '#xyz': false, // non-hex
      '': false,
      '#': false,
      'assets/icon.png': false,
    };
    expectations.forEach((value, expected) {
      test('"$value" → $expected', () {
        expect(utils.isHexColorLiteral(value), expected);
      });
    });
  });

  group('invariant: classify ⇒ parseable (no color accepted then unparseable)',
      () {
    // Every length isHexColorLiteral accepts (3, 4, 6, 8 hex digits) must also
    // be parseable by parseHexColor. This used to break: 3/4 were classified
    // as colors but parseHexColor rejected them, so `background_color: "#fff"`
    // passed validation and then crashed the writer. The fix makes 3/4 parse
    // (shorthand expansion) and drops 5/7 from classification (the loop below
    // skips any value the classifier rejects).
    for (final v in ['#fff', '#ffff', '#fffff', '#ffffff', '#fffffff', '#ffffffff']) {
      test('"$v": classified-as-color implies parseable', () {
        if (!utils.isHexColorLiteral(v)) return; // not classified — skip
        expect(
          () => utils.parseHexColor(v),
          returnsNormally,
          reason:
              '"$v" is accepted by isHexColorLiteral but rejected by '
              'parseHexColor — the two helpers disagree on what a valid hex '
              'color is.',
        );
      });
    }
  });
}
