import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #657.
/// See: issues/approved/issue-657-ios-26-liquid-glass-opt-out.md
///
/// Adds the `ios_disable_liquid_glass` config field. The Contents.json
/// emitter is still investigating the exact Apple metadata key; this
/// test asserts the field parses correctly so the future emitter has
/// somewhere to read from.
void main() {
  group('issue #657: ios_disable_liquid_glass config flag', () {
    test('Config.iosDisableLiquidGlass defaults to false', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
      });
      expect(cfg.iosDisableLiquidGlass, isFalse);
    });

    test('Config.iosDisableLiquidGlass round-trips through fromJson', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
        'ios_disable_liquid_glass': true,
      });
      expect(cfg.iosDisableLiquidGlass, isTrue);
    });
  });
}
