import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:test/test.dart';

/// Regression test for upstream issues #616, #617, #665.
/// See:
///   issues/important/issue-616-non-png-adaptive-background-incorrect-structure.md
///   issues/important/issue-617-pr-fix-non-png-adaptive-background.md
///   issues/important/issue-665-adaptive-bg-image-written-to-colors-xml.md
///
/// `isAdaptiveIconConfigPngFile` currently uses `endsWith('.png')`. A
/// `.jpg` / `.jpeg` / `.webp` path is therefore mis-classified as a hex
/// color and routed into `colors.xml`, producing
/// `<color name="ic_launcher_background">assets/images/background.jpg</color>`
/// which breaks `mergeDebugResources`. The expected correct behavior is
/// to treat any image-like path (or any existing file) as an image, not
/// a color.
void main() {
  group(
    'issue #616/#617/#665: non-PNG adaptive_icon_background classification',
    () {
      test('PNG path is correctly classified as an image', () {
        expect(android.isAdaptiveIconConfigPngFile('assets/bg.png'), isTrue);
      });

      test('hex color is correctly classified as NOT an image', () {
        expect(android.isAdaptiveIconConfigPngFile('#FFFFFF'), isFalse);
      });

      test('jpg path is treated as an image (not a hex color)', () {
        expect(android.isAdaptiveIconConfigPngFile('assets/bg.jpg'), isTrue);
      });

      test('jpeg path is treated as an image (not a hex color)', () {
        expect(android.isAdaptiveIconConfigPngFile('assets/bg.jpeg'), isTrue);
      });

      test('webp path is treated as an image (not a hex color)', () {
        expect(android.isAdaptiveIconConfigPngFile('assets/bg.webp'), isTrue);
      });

      test('shorthand hex (#RGB) is correctly classified as NOT an image', () {
        expect(android.isAdaptiveIconConfigPngFile('#fff'), isFalse);
      });

      test('alpha hex (#AARRGGBB) is correctly classified as NOT an image', () {
        expect(android.isAdaptiveIconConfigPngFile('#80FF00FF'), isFalse);
      });

      test('unhashed hex is also a color (not an image)', () {
        expect(android.isAdaptiveIconConfigPngFile('FFFFFF'), isFalse);
      });
    },
  );
}
