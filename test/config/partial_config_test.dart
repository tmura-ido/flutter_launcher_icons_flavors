import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:flutter_launcher_icons_flavors/config/platform_toggle.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('PartialConfig', () {
    test('parses partial map with only image_path set', () {
      final partial = PartialConfig.fromJson({'image_path': 'assets/icon.png'});
      expect(partial.imagePath, 'assets/icon.png');
      // NullablePlatformToggleConverter preserves the user-omitted distinction:
      // an absent android/ios key yields null (not disabled()).
      expect(partial.android, isNull);
      expect(partial.ios, isNull);
      expect(partial.imagePathAndroid, isNull);
      expect(partial.imagePathIOS, isNull);
      expect(partial.adaptiveIconForeground, isNull);
      expect(partial.adaptiveIconForegroundInset, isNull);
      expect(partial.minSdkAndroid, isNull);
      expect(partial.removeAlphaIOS, isNull);
      expect(partial.desaturateTintedToGrayscaleIOS, isNull);
      expect(partial.backgroundColorIOS, isNull);
      expect(partial.webConfig, isNull);
      expect(partial.windowsConfig, isNull);
      expect(partial.macOSConfig, isNull);
    });

    test('explicit android: false is distinct from omitted android', () {
      final omitted = PartialConfig.fromJson({'image_path': 'assets/icon.png'});
      final explicitFalse = PartialConfig.fromJson({
        'image_path': 'assets/icon.png',
        'android': false,
      });
      expect(omitted.android, isNull);
      expect(explicitFalse.android, equals(PlatformToggle.disabled()));
    });

    test(
      'sparse PartialConfig.toJson() omits nulls (includeIfNull: false)',
      () {
        final partial = PartialConfig.fromJson({
          'image_path': 'assets/icon.png',
        });
        // With includeIfNull: false, the toJson map should ONLY contain the
        // explicitly-set key. No null entries.
        expect(partial.toJson(), equals({'image_path': 'assets/icon.png'}));
      },
    );

    test('round-trips fully-specified scalar fields', () {
      final input = <String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': 'ic_launcher_dev',
        'ios': true,
        'image_path_android': 'assets/a.png',
        'image_path_ios': 'assets/i.png',
        'image_path_ios_dark_transparent': 'assets/i_dark.png',
        'image_path_ios_tinted_grayscale': 'assets/i_tinted.png',
        'adaptive_icon_foreground': 'assets/fg.png',
        'adaptive_icon_foreground_inset': 12,
        'adaptive_icon_background': 'assets/bg.png',
        'adaptive_icon_monochrome': 'assets/mono.png',
        'min_sdk_android': 24,
        'remove_alpha_ios': true,
        'desaturate_tinted_to_grayscale_ios': true,
        'background_color_ios': '#abcdef',
      };
      final partial = PartialConfig.fromJson(input);
      final out = partial.toJson();
      // With includeIfNull: false, full map equality holds: nothing extra,
      // nothing missing.
      expect(out, equals(input));
    });

    test(
      'Config.fromJson(map).toPartial().toJson() preserves scalar fields',
      () {
        final input = <String, dynamic>{
          'image_path': 'assets/icon.png',
          'android': 'ic_launcher_dev',
          'ios': true,
          'image_path_android': 'assets/a.png',
          'image_path_ios': 'assets/i.png',
          'adaptive_icon_foreground': 'assets/fg.png',
          'adaptive_icon_foreground_inset': 12,
          'adaptive_icon_background': 'assets/bg.png',
          'min_sdk_android': 24,
          'remove_alpha_ios': true,
          'desaturate_tinted_to_grayscale_ios': true,
          'background_color_ios': '#abcdef',
        };
        final config = Config.fromJson(input);
        final out = config.toPartial().toJson();
        for (final entry in input.entries) {
          expect(out[entry.key], entry.value, reason: 'key=${entry.key}');
        }
      },
    );

    test('Config defaults are applied when fields are omitted', () {
      final config = Config.fromJson({'image_path': 'assets/icon.png'});
      expect(
        config.adaptiveIconForegroundInset,
        Config.defaultAdaptiveIconForegroundInset,
      );
      expect(config.removeAlphaIOS, Config.defaultRemoveAlphaIOS);
      expect(
        config.desaturateTintedToGrayscaleIOS,
        Config.defaultDesaturateTintedToGrayscaleIOS,
      );
      expect(config.backgroundColorIOS, Config.defaultBackgroundColorIOS);
      expect(config.android, equals(PlatformToggle.disabled()));
      expect(config.ios, equals(PlatformToggle.disabled()));
    });
  });

  group('Config.fromPartial validation', () {
    test('throws InvalidConfigException when android enabled but no image', () {
      expect(
        () => Config.fromJson({'android': true}),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.toString(),
            'message',
            contains('image_path'),
          ),
        ),
      );
    });

    test('throws InvalidConfigException when ios enabled but no image', () {
      expect(
        () => Config.fromJson({'ios': true}),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.toString(),
            'message',
            contains('image_path'),
          ),
        ),
      );
    });

    test('throws when web.generate is true but no image_path anywhere', () {
      expect(
        () => Config.fromJson({
          'web': {'generate': true},
        }),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('accepts android enabled with top-level image_path', () {
      expect(
        () =>
            Config.fromJson({'image_path': 'assets/icon.png', 'android': true}),
        returnsNormally,
      );
    });

    test('accepts android enabled with image_path_android only', () {
      expect(
        () => Config.fromJson({
          'image_path_android': 'assets/icon.png',
          'android': true,
        }),
        returnsNormally,
      );
    });

    test('accepts ios enabled with image_path_ios only', () {
      expect(
        () =>
            Config.fromJson({'image_path_ios': 'assets/icon.png', 'ios': true}),
        returnsNormally,
      );
    });

    test('android: false alone (no platforms enabled) does not throw', () {
      expect(() => Config.fromJson({'android': false}), returnsNormally);
    });

    test('web with its own image_path satisfies validation for web only', () {
      expect(
        () => Config.fromJson({
          'web': {'generate': true, 'image_path': 'assets/icon.png'},
        }),
        returnsNormally,
      );
    });

    test('android enabled but only web image_path -> throws', () {
      // web.imagePath does NOT satisfy the android requirement.
      expect(
        () => Config.fromJson({
          'android': true,
          'web': {'generate': true, 'image_path': 'assets/icon.png'},
        }),
        throwsA(isA<InvalidConfigException>()),
      );
    });
  });
}
