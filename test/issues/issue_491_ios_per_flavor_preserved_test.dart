import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/flavors_config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #491.
/// See: issues/important/issue-491-ios-multi-flavor-not-generated.md
///
/// Per-flavor configs that enable `ios: true` MUST surface
/// `Config.hasIOSConfig == true` so the iOS pipeline (and not the
/// "No platform provided" error path) is invoked. Covers both:
///   1. Legacy single-flavor YAML (`Config.fromJson`).
///   2. Consolidated multi-flavor YAML (`FlavorsConfig.resolve`).
void main() {
  group('issue #491: iOS platform is preserved per flavor', () {
    test('legacy per-flavor config preserves hasIOSConfig', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'ios': true,
      });
      expect(cfg.hasIOSConfig, isTrue);
      expect(cfg.hasPlatformConfig, isTrue);
    });

    test('consolidated flavor resolves with hasIOSConfig true', () async {
      await d.file('cfg_491.yaml', '''
version: 1
defaults:
  image_path: assets/icon.png
  android: true
  ios: true
flavors:
  criocabin: {}
  evco: {}
''').create();

      final loaded = FlavorsConfig.load(
        p.join(d.sandbox, 'cfg_491.yaml'),
        logger: FLILogger(false),
      )!;

      for (final name in ['criocabin', 'evco']) {
        final resolved = loaded.resolve(name);
        expect(resolved.hasIOSConfig, isTrue, reason: 'iOS for $name');
        expect(resolved.hasAndroidConfig, isTrue, reason: 'android for $name');
        expect(resolved.hasPlatformConfig, isTrue, reason: 'platform $name');
      }
    });
  });
}
