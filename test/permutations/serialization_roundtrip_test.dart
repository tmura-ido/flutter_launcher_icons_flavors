// Property-style round-trip tests: deserialize → serialize → deserialize must
// be stable, and documented keys must survive the trip. This catches
// serialization asymmetries (a field read but not written, or written under a
// different key) across the whole config object graph — including the
// hand-written `toJson`/`fromJson` of BadgeConfig / IosAlternateIconsConfig /
// TrayIconConfig, which don't get the json_serializable round-trip for free.
import 'package:flutter_launcher_icons_flavors/config/badge_config.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/ios_alternate_icons_config.dart';
import 'package:flutter_launcher_icons_flavors/config/linux_config.dart';
import 'package:flutter_launcher_icons_flavors/config/macos_config.dart';
import 'package:flutter_launcher_icons_flavors/config/tray_icon_config.dart';
import 'package:flutter_launcher_icons_flavors/config/web_config.dart';
import 'package:flutter_launcher_icons_flavors/config/windows_config.dart';
import 'package:test/test.dart';

void main() {
  // The complete set of keys the config schema actually declares (mirrors the
  // @JsonKey(name:) annotations on PartialConfig / Config). `Config.toJson()`
  // must not emit anything outside this set.
  const declaredConfigKeys = {
    'flavor',
    'xcodeproj_path',
    'ios_legacy_sizes',
    'ios_single_size',
    'optimize_png',
    'ios_disable_liquid_glass',
    'non_square_image_ok',
    'linux',
    'ios_alternate_icons',
    'badge',
    'image_path',
    'android',
    'ios',
    'image_path_android',
    'image_path_ios',
    'image_path_ios_dark_transparent',
    'image_path_ios_tinted_grayscale',
    'adaptive_icon_foreground',
    'adaptive_icon_foreground_inset',
    'adaptive_icon_background',
    'adaptive_icon_monochrome',
    'min_sdk_android',
    'copy_mipmap_xxxhdpi_to_drawable',
    'remove_alpha_ios',
    'desaturate_tinted_to_grayscale_ios',
    'background_color',
    'background_color_ios',
    'web',
    'windows',
    'macos',
  };

  final fixtures = <String, Map<String, dynamic>>{
    'minimal android': {'image_path': 'i.png', 'android': true},
    'named ios (custom icon)': {'image_path': 'i.png', 'ios': 'AltIcon'},
    'full mobile + adaptive': {
      'image_path': 'i.png',
      'android': true,
      'ios': true,
      'adaptive_icon_foreground': 'fg.png',
      'adaptive_icon_background': '#FF8800',
      'adaptive_icon_monochrome': 'mono.png',
      'adaptive_icon_foreground_inset': 20,
      'min_sdk_android': 21,
      'remove_alpha_ios': true,
      'optimize_png': true,
      'ios_legacy_sizes': true,
      'background_color_ios': '#abcdef',
    },
    'multi-platform desktop+web': {
      'image_path': 'i.png',
      'web': {
        'generate': true,
        'image_path': 'i.png',
        'output_path': 'web_x',
        'favicon_size': 32,
      },
      'windows': {'generate': true, 'image_path': 'i.png', 'icon_size': 48},
      'macos': {'generate': true, 'image_path': 'i.png', 'padding': true},
      'linux': {'generate': true, 'image_path': 'i.png', 'icon_size': 256},
    },
  };

  group('Config round-trips through its own JSON', () {
    // Each fixture asserts two linked properties:
    //   (1) Config.toJson() emits ONLY declared schema keys. Today it leaks
    //       computed getters (hasAndroidConfig, isCustomAndroidFile,
    //       androidIconName, …) because config.g.dart serializes them — only
    //       resolvedAdaptiveBackgroundColor carries
    //       @JsonKey(includeToJson: false); the rest were missed.
    //   (2) The serialized map is therefore not re-parseable: PartialConfig's
    //       disallowUnrecognizedKeys rejects the leaked keys, so a config can't
    //       round-trip through its own JSON.
    // Both pass once the derived getters are excluded from toJson.
    for (final entry in fixtures.entries) {
      test(entry.key, () {
        final once = Config.fromJson(entry.value).toJson();
        final extras = once.keys.toSet().difference(declaredConfigKeys);
        expect(
          extras,
          isEmpty,
          reason: 'Config.toJson() leaks non-config keys (derived getters): '
              '$extras',
        );
        expect(
          () => Config.fromJson(once),
          returnsNormally,
          reason: 'Config.toJson() output must be valid Config.fromJson() input',
        );
        expect(Config.fromJson(once).toJson(), once);
      });
    }
  });

  group('json_serializable sub-configs round-trip (scalar keys)', () {
    test('WebConfig preserves every documented scalar key', () {
      final src = {
        'generate': true,
        'image_path': 'i.png',
        'background_color': '#0175C2',
        'theme_color': '#000000',
        'output_path': 'web_x',
        'generate_favicon': false,
        'favicon_path': 'fav.png',
        'favicon_size': 32,
      };
      final once = WebConfig.fromJson(src).toJson();
      expect(WebConfig.fromJson(once).toJson(), once);
      expect(once['output_path'], 'web_x');
      expect(once['favicon_size'], 32);
      expect(once['generate_favicon'], false);
    });

    test('WindowsConfig preserves generate/image_path/icon_size', () {
      final src = {'generate': true, 'image_path': 'i.png', 'icon_size': 48};
      final once = WindowsConfig.fromJson(src).toJson();
      expect(WindowsConfig.fromJson(once).toJson(), once);
      expect(once['icon_size'], 48);
    });

    test('MacOSConfig preserves padding + appearance image paths', () {
      final src = {
        'generate': true,
        'image_path': 'i.png',
        'padding': true,
        'dark_image_path': 'd.png',
        'tinted_image_path': 't.png',
      };
      final once = MacOSConfig.fromJson(src).toJson();
      expect(MacOSConfig.fromJson(once).toJson(), once);
      expect(once['padding'], true);
      expect(once['dark_image_path'], 'd.png');
    });

    test('LinuxConfig preserves icon_size + output_path + default size', () {
      expect(const LinuxConfig().iconSize, 256);
      final src = {
        'generate': true,
        'image_path': 'i.png',
        'icon_size': 128,
        'output_path': 'linux/app.png',
      };
      final once = LinuxConfig.fromJson(src).toJson();
      expect(LinuxConfig.fromJson(once).toJson(), once);
      expect(once['icon_size'], 128);
    });
  });

  group('hand-written sub-configs round-trip', () {
    test('BadgeConfig applies documented defaults and round-trips', () {
      final b = BadgeConfig.fromJson({'text': 'BETA'});
      expect(b.position, 'tr');
      expect(b.fontSizePct, 18);
      expect(b.paddingPct, 4);
      final once = b.toJson();
      expect(BadgeConfig.fromJson(once).toJson(), once);
    });

    test('BadgeConfig preserves every explicitly-set field', () {
      final src = {
        'text': 'DEV',
        'color': '#FFFFFF',
        'background_color': '#FF0000',
        'position': 'bottomright',
        'font_size_pct': 22,
        'font_family': 'RobotoMono',
        'padding_pct': 6,
      };
      final once = BadgeConfig.fromJson(src).toJson();
      expect(BadgeConfig.fromJson(once).toJson(), once);
      expect(once['position'], 'bottomright');
      expect(once['font_size_pct'], 22);
    });

    test('IosAlternateIconsConfig round-trips nested entries', () {
      final c = IosAlternateIconsConfig.fromJson({
        'enabled': true,
        'icons': {
          'red': {'image_path': 'r.png'},
          'blue': {
            'image_path': 'b.png',
            'image_path_dark_transparent': 'b_dark.png',
          },
        },
      });
      expect(c.enabled, isTrue);
      expect(c.icons.keys, containsAll(['red', 'blue']));
      final once = c.toJson();
      expect(IosAlternateIconsConfig.fromJson(once).toJson(), once);
    });

    test('TrayIconConfig round-trips sizes + paths, defaults sizes to []', () {
      expect(const TrayIconConfig().sizes, isEmpty);
      final t = TrayIconConfig.fromJson({
        'image_path': 't.png',
        'template_image_path': 'tmpl.png',
        'sizes': [16, 32, 48],
        'output': 'out/tray.ico',
      });
      expect(t.sizes, [16, 32, 48]);
      final once = t.toJson();
      expect(TrayIconConfig.fromJson(once).toJson(), once);
    });
  });
}
