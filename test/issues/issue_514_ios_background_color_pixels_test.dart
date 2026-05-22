import 'dart:io';

import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issues #514 (green border) and #560
/// (background_color_ios producing black instead of configured color).
///
/// Both issues stem from the iOS alpha-removal compositor in `lib/ios.dart`.
/// If `_alphaBlend` honors `background_color_ios` correctly, fully-transparent
/// source pixels should be replaced by exactly the configured colour.
void main() {
  group('issue #514 / #560: iOS remove_alpha_ios uses configured bg color', () {
    test(
      'a fully transparent source pixel is replaced with background_color_ios',
      () async {
        // Build a 1024x1024 fully transparent RGBA source PNG so every pixel
        // hits the alpha-replacement branch in _alphaBlend.
        final src = Image(width: 1024, height: 1024, numChannels: 4);
        // image package's Image() initializes to (0,0,0,0); be explicit
        // anyway so the test does not depend on default initialization.
        for (final pixel in src) {
          pixel.setRgba(0, 0, 0, 0);
        }

        // ios.createIcons reads `iosConfigFile` (project.pbxproj) and rewrites
        // the AppIcon catalog. Seed a minimal but well-formed sandbox.
        await d.dir('proj', [
          d.file('src.png', encodePng(src)),
          d.dir('ios', [
            d.dir('Runner', [
              d.dir('Assets.xcassets', [d.dir('AppIcon.appiconset')]),
            ]),
            d.dir('Runner.xcodeproj', [
              d.file('project.pbxproj', _minimalPbxproj),
            ]),
          ]),
        ]).create();

        final prefix = p.join(d.sandbox, 'proj');
        final cfg = Config.fromJson({
          'ios': true,
          'image_path': 'src.png',
          'remove_alpha_ios': true,
          'background_color_ios': '#FF5722',
        });

        await ios.createIcons(
          cfg,
          null,
          logger: FLILogger(false),
          prefixPath: prefix,
        );

        // The 1024x1024 marketing icon is one of the outputs and uses the
        // original source resolution, so any rounding-error edge effects
        // are avoided.
        final outFile = File(
          p.join(
            prefix,
            'ios',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
            'Icon-App-1024x1024@1x.png',
          ),
        );
        expect(
          outFile.existsSync(),
          isTrue,
          reason: 'iOS pipeline must emit the 1024 marketing icon',
        );

        final out = decodeImage(await outFile.readAsBytes())!;
        // Pull a corner pixel. The whole source is transparent, so the
        // compositor must have replaced every pixel with the configured bg.
        final px = out.getPixel(0, 0);
        expect(
          px.r.toInt(),
          0xFF,
          reason: 'red channel should be 0xFF for #FF5722',
        );
        expect(
          px.g.toInt(),
          0x57,
          reason: 'green channel should be 0x57 for #FF5722',
        );
        expect(
          px.b.toInt(),
          0x22,
          reason: 'blue channel should be 0x22 for #FF5722',
        );
        // The image should be opaque post alpha removal (numChannels: 3).
        expect(
          out.numChannels,
          3,
          reason: 'remove_alpha_ios must strip the alpha channel',
        );
      },
    );
  });
}

/// Minimal `project.pbxproj` snippet sufficient for `changeIosLauncherIcon`
/// to walk an XCBuildConfiguration section without crashing. The contents
/// don't matter for this pixel-level test — only that the file exists and
/// parses one configuration block so the rewriter terminates cleanly.
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
