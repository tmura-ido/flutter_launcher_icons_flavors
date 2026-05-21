import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:test/test.dart';

/// Regression / behavior test for upstream issue #166.
/// See: issues/easy/issue-166-endswith-null-from-bad-color.md
///
/// When the user writes an unquoted hex literal as
/// `adaptive_icon_background: #000000`, YAML parses the `#` as a comment
/// start and the value becomes null. The legacy tool crashed deep in
/// `endsWith` with `NoSuchMethodError`. The fork's config validator should
/// reject this state early with `InvalidConfigException`.
void main() {
  group('issue #166: adaptive_icon_background null from unquoted #', () {
    test(
      'foreground set but background null -> InvalidConfigException, '
      'not NoSuchMethodError',
      () {
        // Simulates what `checked_yaml` produces when the user writes
        //   adaptive_icon_background: #000000     (unquoted)
        // i.e. background ends up as null in the parsed map.
        final input = <String, dynamic>{
          'android': true,
          'image_path': 'assets/icon.png',
          'adaptive_icon_foreground': 'assets/fg.png',
          'adaptive_icon_background': null,
        };
        expect(
          () => Config.fromJson(input),
          throwsA(isA<InvalidConfigException>()),
        );
      },
    );

    test(
      'error message mentions adaptive_icon_background so the user can fix '
      'the quoting',
      () {
        final input = <String, dynamic>{
          'android': true,
          'image_path': 'assets/icon.png',
          'adaptive_icon_foreground': 'assets/fg.png',
          'adaptive_icon_background': null,
        };
        expect(
          () => Config.fromJson(input),
          throwsA(
            isA<InvalidConfigException>().having(
              (e) => e.toString(),
              'message',
              contains('adaptive_icon_background'),
            ),
          ),
        );
      },
    );
  });
}
