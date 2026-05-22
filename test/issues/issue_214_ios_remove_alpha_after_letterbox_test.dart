// Regression for the iOS pipeline ordering bug discovered while wiring
// `background_color` letter-boxing into iOS:
//
//   background_color: "#00FFFFFF"   # transparent white
//   remove_alpha_ios: true
//   <non-square source>
//
// produced an App-Store-rejected marketing icon with TRANSPARENT
// letter-box bars. Root cause: `remove_alpha_ios` ran BEFORE letter-box,
// so the bars added afterwards were never alpha-blended / stripped.
//
// Fix in `lib/ios.dart`: letter-box first, then remove_alpha_ios. This
// test pins the new order so the bug can't regress.

import 'dart:io';

import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// A 200×100 RED RGBA source PNG — fully opaque pixels. The letter-box
/// step will introduce vertical bars in the configured background color
/// (or transparent, depending on the test's config).
List<int> _redPngRgba(int w, int h) {
  final src = Image(width: w, height: h, numChannels: 4);
  for (final px in src) {
    px.setRgba(255, 0, 0, 0xff);
  }
  return encodePng(src);
}

/// Minimal pbxproj sufficient for `changeIosLauncherIcon` to terminate
/// cleanly. Copied from issue_514_ios_background_color_pixels_test.dart.
const String _minimalPbxproj = '''
// !\$*UTF8*\$!
{
  objects = {
/* Begin XCBuildConfiguration section */
    1 = {
      isa = XCBuildConfiguration;
      baseConfigurationReference = X /* Release.xcconfig */;
      buildSettings = {
        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
      };
    };
/* End XCBuildConfiguration section */
  };
}
''';

Future<String> _scaffold(String name, List<int> pngBytes) async {
  await d.dir(name, [
    d.file('src.png', pngBytes),
    d.dir('ios', [
      d.dir('Runner', [
        d.dir('Assets.xcassets', [d.dir('AppIcon.appiconset')]),
      ]),
      d.dir('Runner.xcodeproj', [d.file('project.pbxproj', _minimalPbxproj)]),
    ]),
  ]).create();
  return p.join(d.sandbox, name);
}

Future<Image> _readMarketingIcon(String prefix) async {
  final out = File(
    p.join(
      prefix,
      'ios',
      'Runner',
      'Assets.xcassets',
      'AppIcon.appiconset',
      'Icon-App-1024x1024@1x.png',
    ),
  );
  expect(out.existsSync(), isTrue, reason: 'marketing icon must be written');
  return decodeImage(await out.readAsBytes())!;
}

void main() {
  group('issue #214: iOS remove_alpha runs AFTER letter-box', () {
    test('transparent letter-box color + remove_alpha_ios still produces a '
        'fully opaque marketing icon (App Store compliant)', () async {
      final prefix = await _scaffold(
        'ios_alpha_after_lb',
        _redPngRgba(200, 100),
      );
      final cfg = Config.fromJson({
        'ios': true,
        'image_path': 'src.png',
        'background_color': '#00FFFFFF', // transparent white
        'remove_alpha_ios': true,
      });

      await ios.createIcons(
        cfg,
        null,
        logger: FLILogger(false),
        prefixPath: prefix,
      );

      final out = await _readMarketingIcon(prefix);
      // The alpha channel must be stripped entirely (numChannels: 3),
      // matching the contract that App Store-bound icons carry no
      // alpha metadata.
      expect(
        out.numChannels,
        3,
        reason: 'remove_alpha_ios must strip the alpha channel',
      );
      // And no pixel may be transparent. Sample the top-left corner —
      // the very place where the bug used to leave bars at alpha=0.
      // The opaque-image check is also exhaustive: scan the whole
      // first row + first column.
      for (var x = 0; x < out.width; x++) {
        final px = out.getPixel(x, 0);
        expect(
          px.a,
          255,
          reason: 'top row pixel ($x, 0) must be opaque (a=255)',
        );
      }
      for (var y = 0; y < out.height; y++) {
        final px = out.getPixel(0, y);
        expect(
          px.a,
          255,
          reason: 'left column pixel (0, $y) must be opaque (a=255)',
        );
      }
    });

    test('opaque background_color_ios + remove_alpha_ios fills bars with '
        'that color (non-square source)', () async {
      final prefix = await _scaffold('ios_opaque_lb', _redPngRgba(200, 100));
      final cfg = Config.fromJson({
        'ios': true,
        'image_path': 'src.png',
        'background_color_ios': '#0175C2', // Flutter blue, opaque
        'remove_alpha_ios': true,
      });

      await ios.createIcons(
        cfg,
        null,
        logger: FLILogger(false),
        prefixPath: prefix,
      );

      final out = await _readMarketingIcon(prefix);
      expect(out.numChannels, 3);
      // Top-left sits deep inside the letter-box bar.
      final corner = out.getPixel(0, 0);
      expect(corner.r, 0x01);
      expect(corner.g, 0x75);
      expect(corner.b, 0xc2);
    });

    test('transparent background_color + transparent background_color_ios + '
        'source containing alpha pixels still yields a fully opaque iOS '
        'marketing icon (remove_alpha_ios contract)', () async {
      // 200×100 source — top half red opaque, bottom half fully
      // transparent. Exercises BOTH branches of `_alphaBlend`:
      //   - opaque pixels (fg.a > 0) → blended → forced to a=0xff
      //   - transparent pixels (fg.a == 0) → returns bg (also a=0)
      // and the letter-box step adds extra fully-transparent bars
      // because the bg color is alpha=0.
      //
      // The contract under test: `remove_alpha_ios: true` MUST drop
      // the alpha channel via `convert(numChannels: 3)`, so even when
      // every color in the resolution chain is alpha=0 the final
      // PNG is encoded as opaque RGB.
      final src = Image(width: 200, height: 100, numChannels: 4);
      for (var y = 0; y < src.height; y++) {
        for (var x = 0; x < src.width; x++) {
          final alpha = y < src.height ~/ 2 ? 0xff : 0;
          src.setPixelRgba(x, y, 255, 0, 0, alpha);
        }
      }

      final prefix = await _scaffold('ios_all_transparent_bg', encodePng(src));
      final cfg = Config.fromJson({
        'ios': true,
        'image_path': 'src.png',
        'background_color': '#00FFFFFF',
        'background_color_ios': '#00FFFFFF',
        'remove_alpha_ios': true,
      });

      await ios.createIcons(
        cfg,
        null,
        logger: FLILogger(false),
        prefixPath: prefix,
      );

      final out = await _readMarketingIcon(prefix);
      // Primary contract: the alpha channel is stripped entirely.
      expect(
        out.numChannels,
        3,
        reason:
            'remove_alpha_ios must strip the alpha channel even when '
            'every bg in the resolution chain is alpha=0',
      );
      // Belt-and-braces: sample the corners (in the letter-box bars),
      // the center (in the originally-opaque half), and one point in
      // the originally-transparent half — none may read as transparent.
      final samples = <Map<String, int>>[
        {'x': 0, 'y': 0},
        {'x': out.width - 1, 'y': 0},
        {'x': 0, 'y': out.height - 1},
        {'x': out.width - 1, 'y': out.height - 1},
        {'x': out.width ~/ 2, 'y': out.height ~/ 2},
        {'x': out.width ~/ 2, 'y': (out.height * 3) ~/ 4},
      ];
      for (final s in samples) {
        final px = out.getPixel(s['x']!, s['y']!);
        expect(
          px.a,
          255,
          reason:
              'pixel (${s['x']}, ${s['y']}) must be opaque after '
              'remove_alpha_ios',
        );
      }
    });
  });
}
