import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #592.
/// See: issues/approved/issue-592-single-size-ios-icons.md
///
/// `ios_single_size: true` shrinks the iOS asset catalog to just the
/// 1024×1024 marketing slot for Xcode 14+ projects, saving bundle space
/// (especially in multi-flavor builds).
void main() {
  group('issue #592: ios_single_size config flag', () {
    test('Config.iosSingleSize defaults to false', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
      });
      expect(cfg.iosSingleSize, isFalse);
    });

    test('Config.iosSingleSize round-trips through fromJson', () {
      final cfg = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'ios': true,
        'ios_single_size': true,
      });
      expect(cfg.iosSingleSize, isTrue);
    });
  });
}
