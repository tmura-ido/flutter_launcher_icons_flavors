import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Regression test for upstream issue #385 (and #626/#658).
/// See:
///   issues/important/issue-385-flavor-icon-not-applied.md
///   issues/important/issue-626-android-flavor-resource-folder.md
///   issues/important/issue-658-wrong-flavor-icon-in-release.md
///
/// `constants.androidResFolder(flavor)` MUST resolve to
/// `android/app/src/<flavor>/res` when a flavor is supplied, and to
/// `android/app/src/main/res` only when no flavor is given. The fork's
/// per-flavor android pipeline depends on this for correct Android
/// flavor builds.
void main() {
  group('issue #385/#626/#658: android resource folder is per-flavor', () {
    test('androidResFolder(null) → src/main/res', () {
      expect(
        p.equals(
          constants.androidResFolder(null),
          p.join('android', 'app', 'src', 'main', 'res'),
        ),
        isTrue,
      );
    });

    test('androidResFolder("dev") → src/dev/res', () {
      expect(
        p.equals(
          constants.androidResFolder('dev'),
          p.join('android', 'app', 'src', 'dev', 'res'),
        ),
        isTrue,
      );
    });

    test('androidColorsFile("dev") nests under src/dev/res/values', () {
      expect(
        p.equals(
          constants.androidColorsFile('dev'),
          p.join('android', 'app', 'src', 'dev', 'res', 'values', 'colors.xml'),
        ),
        isTrue,
      );
    });

    test('androidAdaptiveXmlFolder("prod") nests under src/prod/res', () {
      expect(
        p.equals(
          constants.androidAdaptiveXmlFolder('prod'),
          p.join('android', 'app', 'src', 'prod', 'res', 'mipmap-anydpi-v26'),
        ),
        isTrue,
      );
    });
  });
}
