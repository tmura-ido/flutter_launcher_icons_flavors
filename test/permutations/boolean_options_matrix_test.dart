// Completeness matrix over every boolean top-level config option.
//
// For each boolean key we assert, in one data-driven sweep:
//   * the default value when the key is omitted,
//   * that an explicit `true` round-trips to the typed getter,
//   * that an explicit `false` round-trips to the typed getter,
//   * that a non-boolean value is rejected with `CheckedFromJsonException`
//     (the schema is type-checked).
//
// This is the "no boolean option silently ignored / mistyped" guard.
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;
import 'package:test/test.dart';

typedef _BoolOpt = ({
  String key,
  bool Function(Config) read,
  bool defaultValue,
});

final List<_BoolOpt> _boolOptions = [
  (
    key: 'copy_mipmap_xxxhdpi_to_drawable',
    read: (Config c) => c.copyMipmapXxxhdpiToDrawable,
    defaultValue: false,
  ),
  (
    key: 'remove_alpha_ios',
    read: (Config c) => c.removeAlphaIOS,
    defaultValue: false,
  ),
  (
    key: 'desaturate_tinted_to_grayscale_ios',
    read: (Config c) => c.desaturateTintedToGrayscaleIOS,
    defaultValue: false,
  ),
  (
    key: 'ios_legacy_sizes',
    read: (Config c) => c.iosLegacySizes,
    defaultValue: false,
  ),
  (
    key: 'ios_single_size',
    read: (Config c) => c.iosSingleSize,
    defaultValue: false,
  ),
  (key: 'optimize_png', read: (Config c) => c.optimizePng, defaultValue: false),
  (
    key: 'ios_disable_liquid_glass',
    read: (Config c) => c.iosDisableLiquidGlass,
    defaultValue: false,
  ),
  (
    key: 'non_square_image_ok',
    read: (Config c) => c.nonSquareImageOk,
    defaultValue: false,
  ),
];

Map<String, dynamic> _base() => {'image_path': 'assets/icon.png', 'android': true};

void main() {
  group('Boolean option matrix', () {
    for (final opt in _boolOptions) {
      test('${opt.key}: default == ${opt.defaultValue}', () {
        final c = Config.fromJson(_base());
        expect(opt.read(c), opt.defaultValue);
      });

      test('${opt.key}: explicit true round-trips', () {
        final c = Config.fromJson(_base()..[opt.key] = true);
        expect(opt.read(c), isTrue);
      });

      test('${opt.key}: explicit false round-trips', () {
        final c = Config.fromJson(_base()..[opt.key] = false);
        expect(opt.read(c), isFalse);
      });

      test('${opt.key}: non-boolean value is rejected', () {
        expect(
          () => Config.fromJson(_base()..[opt.key] = 'not-a-bool'),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    }
  });
}
