// Tests for the top-level `background_color` field (upstream #214).
//
// `background_color` is the generic letter-box bar color, used as a fallback
// for `background_color_ios` and `web.background_color` and as the only
// source for the Android non-adaptive mipmap path (which has no
// platform-specific background config of its own).

import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

List<int> _redPng(int w, int h) {
  final src = Image(width: w, height: h);
  for (final px in src) {
    px.setRgba(255, 0, 0, 0xff);
  }
  return encodePng(src);
}

void main() {
  group('top-level background_color — schema', () {
    test('PartialConfig parses background_color and round-trips through JSON',
        () {
      final partial = PartialConfig.fromJson({
        'image_path': 'a.png',
        'background_color': '#0175C2',
      });
      expect(partial.backgroundColor, '#0175C2');
      expect(partial.toJson()['background_color'], '#0175C2');
    });

    test('Config.fromPartial stores background_color verbatim', () {
      final cfg = Config.fromJson({
        'image_path': 'a.png',
        'android': true,
        'background_color': '#123456',
      });
      expect(cfg.backgroundColor, '#123456');
    });

    test('Config defaults backgroundColor to null when unset', () {
      final cfg = Config.fromJson({'image_path': 'a.png', 'android': true});
      expect(cfg.backgroundColor, isNull);
    });
  });

  group('top-level background_color — fallback for iOS', () {
    test(
      'background_color flows into backgroundColorIOS when '
      'background_color_ios is unset',
      () {
        final cfg = Config.fromJson({
          'image_path': 'a.png',
          'ios': true,
          'background_color': '#0175C2',
        });
        expect(cfg.backgroundColorIOS, '#0175C2');
      },
    );

    test(
      'explicit background_color_ios wins over background_color',
      () {
        final cfg = Config.fromJson({
          'image_path': 'a.png',
          'ios': true,
          'background_color': '#0175C2',
          'background_color_ios': '#FF0000',
        });
        expect(cfg.backgroundColorIOS, '#FF0000');
      },
    );

    test('neither set → default #FFFFFF', () {
      final cfg = Config.fromJson({'image_path': 'a.png', 'ios': true});
      expect(cfg.backgroundColorIOS, Config.defaultBackgroundColorIOS);
    });
  });

  group('top-level background_color — Android non-adaptive mipmap', () {
    test(
      'mipmap icon top-left pixel matches background_color when set',
      () async {
        // 200x100 red source. With background_color=#0175C2, mipmap output
        // should letter-box vertically — the top-left pixel of any density
        // bucket sits inside the bar and should be Flutter blue.
        await d.dir('mip_bg', [
          d.file('app_icon.png', _redPng(200, 100)),
          d.dir('android', [
            d.dir('app', [
              d.dir('src', [
                d.dir('main', [
                  d.file(
                    'AndroidManifest.xml',
                    '<manifest package="demo"><application android:icon="@mipmap/ic_launcher"/></manifest>',
                  ),
                  d.dir('res', [
                    d.dir('mipmap-mdpi'),
                    d.dir('mipmap-hdpi'),
                    d.dir('mipmap-xhdpi'),
                    d.dir('mipmap-xxhdpi'),
                    d.dir('mipmap-xxxhdpi'),
                  ]),
                ]),
              ]),
            ]),
          ]),
          d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  min_sdk_android: 24
  image_path: app_icon.png
  background_color: "#0175C2"
'''),
        ]).create();
        final prefix = p.join(d.sandbox, 'mip_bg');

        final code = await buildCommandRunner().run(
          effectiveArgs(['--prefix', prefix]),
        );
        expect(code, 0, reason: 'generation should succeed');

        final out = decodePng(
          File(
            p.join(
              prefix,
              'android',
              'app',
              'src',
              'main',
              'res',
              'mipmap-xxxhdpi',
              'ic_launcher.png',
            ),
          ).readAsBytesSync(),
        )!;
        final corner = out.getPixel(0, 0);
        expect(corner.r, 0x01);
        expect(corner.g, 0x75);
        expect(corner.b, 0xc2);
      },
    );

    test(
      'without background_color the mipmap stays squished '
      '(legacy, with explicit non_square_image_ok opt-in)',
      () async {
        // `non_square_image_ok: true` is the documented opt-in for
        // "yes, I know the source will be squished, don't ask me at
        // generate time". Without it the generator's interactive
        // pre-flight prompt would fire — and since `dart test` running
        // from a developer's terminal inherits a real stdin, the prompt
        // would block the test. This test's INTENT is to verify the
        // writer's squish path, not the prompt UX, so opt in here.
        await d.dir('mip_no_bg', [
          d.file('app_icon.png', _redPng(200, 100)),
          d.dir('android', [
            d.dir('app', [
              d.dir('src', [
                d.dir('main', [
                  d.file(
                    'AndroidManifest.xml',
                    '<manifest package="demo"><application android:icon="@mipmap/ic_launcher"/></manifest>',
                  ),
                  d.dir('res', [
                    d.dir('mipmap-mdpi'),
                    d.dir('mipmap-hdpi'),
                    d.dir('mipmap-xhdpi'),
                    d.dir('mipmap-xxhdpi'),
                    d.dir('mipmap-xxxhdpi'),
                  ]),
                ]),
              ]),
            ]),
          ]),
          d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  android: true
  min_sdk_android: 24
  image_path: app_icon.png
  non_square_image_ok: true
'''),
        ]).create();
        final prefix = p.join(d.sandbox, 'mip_no_bg');

        final code = await buildCommandRunner().run(
          effectiveArgs(['--prefix', prefix]),
        );
        expect(code, 0);

        final out = decodePng(
          File(
            p.join(
              prefix,
              'android',
              'app',
              'src',
              'main',
              'res',
              'mipmap-xxxhdpi',
              'ic_launcher.png',
            ),
          ).readAsBytesSync(),
        )!;
        // Legacy squish → whole image is the red source.
        final corner = out.getPixel(0, 0);
        expect(corner.r, 255);
        expect(corner.g, 0);
        expect(corner.b, 0);
      },
    );
  });

  group('top-level background_color — Web fallback', () {
    test(
      'web letter-boxes with top-level background_color when '
      'web.background_color is not set',
      () async {
        await d.dir('web_topbg', [
          d.dir('web', [
            d.dir('icons'),
            d.file(
              'index.html',
              '<!doctype html><html><head></head><body></body></html>',
            ),
            d.file(
              'manifest.json',
              '{"name":"demo","short_name":"demo","icons":[]}',
            ),
          ]),
          d.file('app_icon.png', _redPng(200, 100)),
          d.file('pubspec.yaml', '''
name: demo
flutter_launcher_icons:
  image_path: app_icon.png
  background_color: "#0175C2"
  web:
    generate: true
    image_path: app_icon.png
'''),
        ]).create();
        final prefix = p.join(d.sandbox, 'web_topbg');

        final code = await buildCommandRunner().run(
          effectiveArgs(['--prefix', prefix]),
        );
        expect(code, 0);

        final out = decodePng(
          File(p.join(prefix, 'web', 'icons', 'Icon-192.png'))
              .readAsBytesSync(),
        )!;
        final corner = out.getPixel(0, 0);
        expect(corner.r, 0x01);
        expect(corner.g, 0x75);
        expect(corner.b, 0xc2);
      },
    );
  });
}
