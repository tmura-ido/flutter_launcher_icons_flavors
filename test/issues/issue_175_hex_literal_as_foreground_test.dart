import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:test/test.dart';

/// Regression / behavior test for upstream issue #175.
/// See: issues/easy/issue-175-color-parsed-as-path.md
///
/// When both adaptive_icon_background and adaptive_icon_foreground are set
/// to hex color literals like `"#ffffff"`, the foreground value is later
/// treated as a file path and the pipeline crashes with a confusing
/// `FileSystemException: Cannot open file, path = '#ffffff'`. The fork
/// should reject hex literals for `adaptive_icon_foreground` early with a
/// clear `InvalidConfigException`.
void main() {
  group('issue #175: hex literal for adaptive_icon_foreground', () {
    test(
      'hex literal for adaptive_icon_foreground -> InvalidConfigException',
      () {
        final input = <String, dynamic>{
          'android': true,
          'image_path': 'assets/icon.png',
          'adaptive_icon_background': '#ffffff',
          'adaptive_icon_foreground': '#ffffff',
        };
        expect(
          () => Config.fromJson(input),
          throwsA(isA<InvalidConfigException>()),
        );
      },
    );

    test(
      'hex literal for adaptive_icon_monochrome -> InvalidConfigException',
      () {
        final input = <String, dynamic>{
          'android': true,
          'image_path': 'assets/icon.png',
          'adaptive_icon_background': '#ffffff',
          'adaptive_icon_foreground': 'assets/fg.png',
          'adaptive_icon_monochrome': '#abc',
        };
        expect(
          () => Config.fromJson(input),
          throwsA(isA<InvalidConfigException>()),
        );
      },
    );

    test('PNG path for adaptive_icon_foreground is accepted', () {
      final input = <String, dynamic>{
        'android': true,
        'image_path': 'assets/icon.png',
        'adaptive_icon_background': '#ffffff',
        'adaptive_icon_foreground': 'assets/fg.png',
      };
      expect(() => Config.fromJson(input), returnsNormally);
    });
  });
}
