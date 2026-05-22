import 'package:flutter_launcher_icons_flavors/android.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #91.
/// See: issues/approved/issue-091-android-vector-drawable-foreground.md
///
/// Vector drawable (.xml) sources used to crash deep inside the `image`
/// package with `getter 'width' was called on null`. The fork should now
/// reject them at config time with an `InvalidConfigException` naming the
/// field and the path.
void main() {
  group('issue #91: .xml adaptive foreground -> clear FLIException', () {
    test(
      'rejectVectorDrawableSource throws InvalidConfigException for .xml',
      () {
        expect(
          () => rejectVectorDrawableSource(
            field: 'adaptive_icon_foreground',
            value: 'assets/foo.xml',
          ),
          throwsA(
            isA<InvalidConfigException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('adaptive_icon_foreground'),
                contains('assets/foo.xml'),
                contains('vector drawable'),
              ),
            ),
          ),
        );
      },
    );

    test('case-insensitive: .XML is also rejected', () {
      expect(
        () => rejectVectorDrawableSource(
          field: 'adaptive_icon_monochrome',
          value: 'assets/MONO.XML',
        ),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('PNG sources pass through without throwing', () {
      expect(
        () => rejectVectorDrawableSource(
          field: 'adaptive_icon_foreground',
          value: 'assets/foreground.png',
        ),
        returnsNormally,
      );
    });
  });
}
