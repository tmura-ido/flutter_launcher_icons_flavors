import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:test/test.dart';

/// Behavior test for upstream issue #443.
/// See: issues/important/issue-443-flavors-output-path.md
///
/// Users want to be able to point `android:` at a per-flavor res path
/// (e.g. `"android/app/src/dev/res/launcher_icon"`). Today
/// `isAndroidIconNameCorrectFormat` rejects any value containing a
/// slash with `InvalidAndroidIconNameException`. The right long-term fix
/// is splitting path from name (see #626). This test documents today's
/// behavior so a follow-up fix is detected when the validator loosens
/// or a separate `android_output_dir` key is introduced.
void main() {
  group('issue #443: android icon name rejects slashes', () {
    test('values containing a slash throw InvalidAndroidIconNameException', () {
      expect(
        () => android.isAndroidIconNameCorrectFormat(
          'android/app/src/dev/res/launcher_icon',
        ),
        throwsA(isA<InvalidAndroidIconNameException>()),
      );
    });

    test('lowercase identifier names pass validation', () {
      expect(
        android.isAndroidIconNameCorrectFormat('ic_launcher_dev'),
        isTrue,
      );
    });
  });
}
