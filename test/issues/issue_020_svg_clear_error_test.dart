import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:test/test.dart';

/// Regression for upstream issue #020.
/// See: issues/approved/issue-020-svg-source-support.md
///
/// Full SVG rasterization is a future feature gated on a vector
/// renderer dependency. Phase 1 (this fix): SVG sources surface a
/// friendly `InvalidConfigException` instead of failing deep inside
/// `decodeImage` with a confusing null/RangeError.
void main() {
  group('issue #020: SVG sources are rejected with a friendly error', () {
    test('decodeImageFile on .svg throws InvalidConfigException', () {
      expect(
        () => utils.decodeImageFile('assets/logo.svg'),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.toString(),
            'toString',
            allOf(contains('logo.svg'), contains('SVG'), contains('PNG')),
          ),
        ),
      );
    });

    test('case-insensitive: .SVG is also rejected', () {
      expect(
        () => utils.decodeImageFile('assets/LOGO.SVG'),
        throwsA(isA<InvalidConfigException>()),
      );
    });
  });
}
