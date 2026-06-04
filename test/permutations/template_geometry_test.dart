// Spec-grounded geometry invariants for every platform's icon template table.
// These are the "wrong pixel size / wrong density bucket" guards: a typo in
// any size table (iOS, Android mipmap, Android adaptive, macOS, web) is caught
// here instead of shipping mis-sized icons.
//
// Sources of truth:
//   * iOS asset-catalog scale rule: a slot's pixel size == point size × scale.
//   * Android density buckets: mdpi=1×, hdpi=1.5×, xhdpi=2×, xxhdpi=3×,
//     xxxhdpi=4× of a 48dp launcher baseline (108dp for adaptive layers).
//   * macOS .iconset: filename is app_icon_<pixels>.png where pixels=size×scale.
//   * PWA manifest icon entry shape (web.dev maskable-icon guidance).
import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:flutter_launcher_icons_flavors/macos/macos_icon_template.dart';
import 'package:flutter_launcher_icons_flavors/web/web_template.dart';
import 'package:test/test.dart';

final _iosName = RegExp(r'^-(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)@(\d+)x$');

void main() {
  group('iOS template geometry — pixel size == point size × scale', () {
    final lists = {
      'legacyIosIcons': ios.legacyIosIcons,
      'iosIcons': ios.iosIcons,
    };
    for (final entry in lists.entries) {
      for (final t in entry.value) {
        test('${entry.key} ${t.name} → ${t.size}px', () {
          final m = _iosName.firstMatch(t.name);
          expect(m, isNotNull, reason: '"${t.name}" is not in -WxH@Sx form');
          final w = double.parse(m!.group(1)!);
          final h = double.parse(m.group(2)!);
          final scale = int.parse(m.group(3)!);
          expect(w, h, reason: 'iOS catalog slots are square');
          expect(t.size, (w * scale).round());
        });
      }
      test('${entry.key}: names unique, includes the 1024 marketing slot', () {
        final names = entry.value.map((t) => t.name).toList();
        expect(names.toSet().length, names.length);
        expect(names, contains('-1024x1024@1x'));
      });
    }
  });

  group('Android mipmap density geometry (48dp launcher baseline)', () {
    const expected = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    test('androidIcons matches the standard density buckets', () {
      final actual = {
        for (final t in android.androidIcons) t.directoryName: t.size,
      };
      expect(actual, expected);
    });
    test('densities scale from mdpi by {1, 1.5, 2, 3, 4}', () {
      final mdpi = expected['mipmap-mdpi']!;
      expect(expected['mipmap-hdpi']! / mdpi, 1.5);
      expect(expected['mipmap-xhdpi']! / mdpi, 2);
      expect(expected['mipmap-xxhdpi']! / mdpi, 3);
      expect(expected['mipmap-xxxhdpi']! / mdpi, 4);
    });
  });

  group('Android adaptive foreground geometry (108dp baseline)', () {
    const expected = {
      'drawable-mdpi': 108,
      'drawable-hdpi': 162,
      'drawable-xhdpi': 216,
      'drawable-xxhdpi': 324,
      'drawable-xxxhdpi': 432,
    };
    test('adaptiveForegroundIcons matches the adaptive density buckets', () {
      final actual = {
        for (final t in android.adaptiveForegroundIcons)
          t.directoryName: t.size,
      };
      expect(actual, expected);
    });
    test('each adaptive size is its mipmap counterpart × 2.25 (108/48)', () {
      String density(String dir) => dir.split('-').last;
      final mip = {
        for (final t in android.androidIcons) density(t.directoryName): t.size,
      };
      final adp = {
        for (final t in android.adaptiveForegroundIcons)
          density(t.directoryName): t.size,
      };
      for (final d in mip.keys) {
        expect(adp[d]! / mip[d]!, closeTo(2.25, 1e-9), reason: d);
      }
    });
  });

  group('macOS .iconset template contract', () {
    const cases = [(16, 1), (16, 2), (32, 1), (128, 2), (256, 1), (512, 2)];
    for (final (size, scale) in cases) {
      test('MacOSIconTemplate($size, $scale)', () {
        final t = MacOSIconTemplate(size, scale);
        final px = size * scale;
        expect(t.scaledSize, px);
        expect(t.iconFile, 'app_icon_$px.png');
        expect(t.iconContent, {
          'size': '${size}x$size',
          'idiom': 'mac',
          'filename': 'app_icon_$px.png',
          'scale': '${scale}x',
        });
      });
    }
    test('16@2x and 32@1x reuse one 32px file (Apple iconset dedup)', () {
      expect(
        const MacOSIconTemplate(16, 2).iconFile,
        const MacOSIconTemplate(32, 1).iconFile,
      );
    });
  });

  group('Web PWA icon template contract', () {
    test('non-maskable 192 → plain manifest entry', () {
      const t = WebIconTemplate(size: 192);
      expect(t.iconFile, 'Icon-192.png');
      expect(t.iconManifest, {
        'src': 'icons/Icon-192.png',
        'sizes': '192x192',
        'type': 'image/png',
      });
    });
    test('maskable 512 → manifest entry carries purpose:maskable', () {
      const t = WebIconTemplate(size: 512, maskable: true);
      expect(t.iconFile, 'Icon-maskable-512.png');
      expect(t.iconManifest, {
        'src': 'icons/Icon-maskable-512.png',
        'sizes': '512x512',
        'type': 'image/png',
        'purpose': 'maskable',
      });
    });
  });
}
