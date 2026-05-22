// End-to-end behavior tests for upstream issue #214 letter-boxing.
//
// `createResizedImage` ([lib/utils.dart]) now letter-boxes non-square sources
// when given a background color. Platform writers (iOS, Web, adaptive
// Android) pre-letter-box the decoded source once with the configured
// background so every generated icon size preserves aspect ratio.
//
// These tests drive each wired platform end-to-end (decode → letter-box →
// resize → encode → read back the PNG) and assert that the corner pixel of
// the output matches the configured background color — proof that the bars
// landed where letter-boxing would put them, not the squished source.

import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/command_runner.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Builds an in-memory PNG of [w]×[h] filled with solid red and returns
/// the encoded bytes — written into the sandbox by callers.
List<int> _redPng(int w, int h) {
  final src = Image(width: w, height: h);
  for (final px in src) {
    px.setRgba(255, 0, 0, 0xff);
  }
  return encodePng(src);
}

void main() {
  group('issue #214 — Web writer letter-boxes non-square sources', () {
    test('web.background_color makes the top-left of every generated icon '
        'match the configured background', () async {
      // 200×100 red source on a #0175C2 (Flutter blue) background.
      // Letter-boxing puts blue bars at the top and bottom of every
      // generated PNG, so the top-left pixel should be blue.
      await d.dir('web_letterbox', [
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
  web:
    generate: true
    image_path: app_icon.png
    background_color: "#0175C2"
    theme_color: "#0175C2"
'''),
      ]).create();
      final prefix = p.join(d.sandbox, 'web_letterbox');

      final code = await buildCommandRunner().run(
        effectiveArgs(['--prefix', prefix]),
      );
      expect(code, 0);

      final out = decodePng(
        File(p.join(prefix, 'web', 'icons', 'Icon-192.png')).readAsBytesSync(),
      )!;
      final corner = out.getPixel(0, 0);
      // #0175C2 → R=0x01, G=0x75, B=0xC2. Resize introduces sub-pixel
      // smoothing on the border between bar and content, so check the
      // very top-left corner (deep in the bar) for an exact match.
      expect(corner.r, 0x01);
      expect(corner.g, 0x75);
      expect(corner.b, 0xc2);
    });

    test('without web.background_color the legacy squish behavior is kept '
        '(top row stays red — no letter-boxing, with explicit '
        'non_square_image_ok opt-in)', () async {
      // `non_square_image_ok: true` declares "yes, squish is fine" and
      // bypasses the interactive pre-flight prompt added with #214 —
      // necessary so `dart test` from a real terminal doesn't block on
      // the prompt waiting for user input. The test's intent is the
      // writer's squish behavior, not the prompt UX.
      await d.dir('web_no_bg', [
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
  non_square_image_ok: true
  web:
    generate: true
    image_path: app_icon.png
'''),
      ]).create();
      final prefix = p.join(d.sandbox, 'web_no_bg');

      final code = await buildCommandRunner().run(
        effectiveArgs(['--prefix', prefix]),
      );
      expect(code, 0);

      final out = decodePng(
        File(p.join(prefix, 'web', 'icons', 'Icon-192.png')).readAsBytesSync(),
      )!;
      // Squish behavior preserved → entire output is the source color.
      final corner = out.getPixel(0, 0);
      expect(corner.r, 255);
      expect(corner.g, 0);
      expect(corner.b, 0);
    });
  });
}
