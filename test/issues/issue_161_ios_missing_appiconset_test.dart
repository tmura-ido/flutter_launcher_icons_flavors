import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression for upstream issue #161.
/// See: issues/approved/issue-161-ios-missing-target-file.md
///
/// When `AppIcon.appiconset/` is missing the iOS writer used to throw a
/// bare `FileSystemException`. It now throws an `InvalidConfigException`
/// that mentions the expected path and suggests `flutter create .`.
void main() {
  group('issue #161: missing iOS appiconset surfaces a friendly error', () {
    test('overwriteDefaultIcons fails fast with appiconset hint', () async {
      // Sandbox without an `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
      // directory.
      await d.dir('proj_161', []).create();
      final prefix = p.join(d.sandbox, 'proj_161');

      final img = Image(width: 16, height: 16);
      expect(
        () => ios.overwriteDefaultIcons(
          ios.legacyIosIcons.first,
          img,
          '',
          prefix,
        ),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.toString(),
            'toString',
            allOf(contains('AppIcon.appiconset'), contains('flutter create')),
          ),
        ),
      );
    });
  });
}
