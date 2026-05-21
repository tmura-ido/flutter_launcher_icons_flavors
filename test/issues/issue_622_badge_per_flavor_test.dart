import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #622 (phase 1: config schema).
/// See: issues/approved/issue-622-environment-badge-on-app-icon.md
///
/// Phase 1: the `badge:` block parses and round-trips. The renderer + the
/// bundled TTF font ship separately (require a new package asset).
void main() {
  group('issue #622: badge config schema (phase 1)', () {
    test('badge block parses with all fields', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'badge': {
          'text': 'DEV',
          'color': '#FF0000',
          'background_color': '#000000',
          'position': 'tr',
          'font_size_pct': 18,
          'font_family': 'RobotoMono',
          'padding_pct': 4,
        },
      });
      final badge = cfg.badge!;
      expect(badge.text, 'DEV');
      expect(badge.color, '#FF0000');
      expect(badge.backgroundColor, '#000000');
      expect(badge.position, 'tr');
      expect(badge.fontSizePct, 18);
      expect(badge.fontFamily, 'RobotoMono');
      expect(badge.paddingPct, 4);
    });

    test('badge block uses sensible defaults when fields omitted', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'badge': {'text': 'STG'},
      });
      final badge = cfg.badge!;
      expect(badge.text, 'STG');
      expect(badge.position, 'tr');
      expect(badge.fontSizePct, 18);
      expect(badge.paddingPct, 4);
    });

    test('badge is optional', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
      });
      expect(cfg.badge, isNull);
    });
  });
}
