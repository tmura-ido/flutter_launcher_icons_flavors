// Full permutation of the three Android adaptive-icon source options against
// their three possible states each:
//
//   adaptive_icon_foreground  ∈ {absent, image-path, hex-literal}
//   adaptive_icon_background  ∈ {absent, image-path, hex-literal}
//   adaptive_icon_monochrome  ∈ {absent, image-path, hex-literal}
//
// → 3 × 3 × 3 = 27 permutations. For each, we assert accept/reject of
// `Config.fromJson`. The expected outcome is computed from the documented
// rules in `Config.fromPartial`:
//
//   1. `adaptive_icon_foreground` set while `adaptive_icon_background` is
//      blank is a hard error (background is required alongside a foreground).
//   2. `adaptive_icon_foreground` must be an image PATH — a hex color literal
//      there is rejected (upstream #175).
//   3. `adaptive_icon_monochrome` must likewise be an image path, never a hex
//      literal.
//   4. `adaptive_icon_background` MAY be a hex literal OR an image path.
//
// All cases enable android + a top-level image_path so the platform/image
// checks pass and we isolate the adaptive-icon rules.
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:test/test.dart';

/// The state a single adaptive-icon key can take in the permutation.
enum _State { absent, path, hex }

const _pathValue = 'assets/layer.png';
const _hexValue = '#FF8800';

String? _value(_State s) => switch (s) {
  _State.absent => null,
  _State.path => _pathValue,
  _State.hex => _hexValue,
};

/// Oracle: returns true when the documented rules require an
/// `InvalidConfigException` for the given combination.
bool _expectThrow(_State fg, _State bg, _State mono) {
  // Rule 1 — foreground present but background blank.
  if (fg != _State.absent && bg == _State.absent) return true;
  // Rule 2 — foreground must be a path, not a hex literal.
  if (fg == _State.hex) return true;
  // Rule 3 — monochrome must be a path, not a hex literal.
  if (mono == _State.hex) return true;
  return false;
}

void main() {
  group('Adaptive-icon option permutation matrix (27 combinations)', () {
    for (final fg in _State.values) {
      for (final bg in _State.values) {
        for (final mono in _State.values) {
          final label =
              'fg=${fg.name} bg=${bg.name} mono=${mono.name}';
          test(label, () {
            final map = <String, dynamic>{
              'image_path': 'assets/icon.png',
              'android': true,
            };
            final fgV = _value(fg);
            final bgV = _value(bg);
            final monoV = _value(mono);
            if (fgV != null) map['adaptive_icon_foreground'] = fgV;
            if (bgV != null) map['adaptive_icon_background'] = bgV;
            if (monoV != null) map['adaptive_icon_monochrome'] = monoV;

            if (_expectThrow(fg, bg, mono)) {
              expect(
                () => Config.fromJson(map),
                throwsA(isA<InvalidConfigException>()),
                reason: 'expected rejection for $label',
              );
            } else {
              expect(
                () => Config.fromJson(map),
                returnsNormally,
                reason: 'expected acceptance for $label',
              );
            }
          });
        }
      }
    }
  });

  // A few targeted message-content checks for the canonical error paths,
  // so a regression that swaps the messages is also caught.
  group('Adaptive-icon error messages', () {
    test('foreground path without background → mentions background', () {
      expect(
        () => Config.fromJson({
          'image_path': 'assets/icon.png',
          'android': true,
          'adaptive_icon_foreground': _pathValue,
        }),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.toString(),
            'message',
            contains('adaptive_icon_background'),
          ),
        ),
      );
    });

    test('foreground hex literal (with a valid background) → must be a path', () {
      expect(
        () => Config.fromJson({
          'image_path': 'assets/icon.png',
          'android': true,
          'adaptive_icon_foreground': _hexValue,
          'adaptive_icon_background': _pathValue,
        }),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.toString(),
            'message',
            contains('image path'),
          ),
        ),
      );
    });
  });
}
