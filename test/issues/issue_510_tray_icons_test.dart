import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/tray_icon_config.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #510 (phase 1: config schema).
/// See: issues/approved/issue-510-tray-icons.md
///
/// Each desktop platform's existing config block gains an optional
/// `tray_icon` sub-block. Phase 1 (this test) verifies the schema parses;
/// per-platform writers land separately.
void main() {
  group('issue #510: tray_icon config schema parses on each platform', () {
    test('Windows: tray_icon block parses with sizes + output', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/x.png',
        'windows': {
          'generate': true,
          'image_path': 'assets/x.png',
          'tray_icon': {
            'image_path': 'assets/x.png',
            'sizes': [16, 24, 32, 48],
            'output': 'windows/runner/resources/tray.ico',
          },
        },
      });
      final tray = cfg.windowsConfig!.trayIcon!;
      expect(tray.imagePath, 'assets/x.png');
      expect(tray.sizes, [16, 24, 32, 48]);
      expect(tray.output, 'windows/runner/resources/tray.ico');
    });

    test('macOS: tray_icon block parses with template_image_path', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/x.png',
        'macos': {
          'generate': true,
          'image_path': 'assets/x.png',
          'tray_icon': {
            'template_image_path': 'assets/tray_template.png',
            'sizes': [16, 32],
          },
        },
      });
      final tray = cfg.macOSConfig!.trayIcon!;
      expect(tray.templateImagePath, 'assets/tray_template.png');
      expect(tray.sizes, [16, 32]);
    });

    test('Linux: tray_icon block parses with sizes', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/x.png',
        'linux': {
          'generate': true,
          'image_path': 'assets/x.png',
          'tray_icon': {
            'image_path': 'assets/x.png',
            'sizes': [22, 24, 32, 48],
          },
        },
      });
      final tray = cfg.linuxConfig!.trayIcon!;
      expect(tray.imagePath, 'assets/x.png');
      expect(tray.sizes, [22, 24, 32, 48]);
    });

    test('tray_icon block is optional on every platform', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/x.png',
        'windows': {'generate': true, 'image_path': 'assets/x.png'},
        'macos': {'generate': true, 'image_path': 'assets/x.png'},
        'linux': {'generate': true, 'image_path': 'assets/x.png'},
      });
      expect(cfg.windowsConfig!.trayIcon, isNull);
      expect(cfg.macOSConfig!.trayIcon, isNull);
      expect(cfg.linuxConfig!.trayIcon, isNull);
    });

    test('TrayIconConfig.toJson round-trips', () {
      const tray = TrayIconConfig(
        imagePath: 'a.png',
        templateImagePath: 'b.png',
        sizes: [16, 32],
        output: 'out',
      );
      final json = tray.toJson();
      expect(json['image_path'], 'a.png');
      expect(json['template_image_path'], 'b.png');
      expect(json['sizes'], [16, 32]);
      expect(json['output'], 'out');
    });
  });
}
