import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Behavior / bug-doc test for upstream issue #132.
/// See: issues/issue-132-adaptive-bg-invalid-color.md
///
/// When the user passes a malformed `adaptive_icon_background` value
/// (not a `#RRGGBB`/`#AARRGGBB` literal and not a `.png` path), the
/// tool currently writes the raw value into `colors.xml`, producing an
/// AAPT `invalid color` build break. A fix should validate the value
/// before touching `colors.xml`.
void main() {
  group('issue #132: adaptive_icon_background invalid color', () {
    test('updateColorsFile rejects non-hex, non-path values', () async {
      // Arrange: create an empty colors.xml in a sandbox.
      await d.file('colors.xml', '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
</resources>
''').create();
      final colorsFile = File(path.join(d.sandbox, 'colors.xml'));

      // Act + Assert: an obviously-malformed value should throw rather
      // than be written verbatim into the resource file.
      expect(
        () => android.updateColorsFile(colorsFile, 'not-a-color'),
        throwsA(isA<Exception>()),
        reason: 'malformed colors must not be silently written',
      );
    });

    test('updateColorsFile rejects an asset path masquerading as a color',
        () async {
      await d.file('colors.xml', '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
</resources>
''').create();
      final colorsFile = File(path.join(d.sandbox, 'colors.xml'));

      expect(
        () => android.updateColorsFile(
          colorsFile,
          'assets/icon/background-does-not-exist.jpg',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('valid hex literal is accepted', () async {
      await d.file('colors.xml', '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
</resources>
''').create();
      final colorsFile = File(path.join(d.sandbox, 'colors.xml'));

      await android.updateColorsFile(colorsFile, '#FF000000');
      final updated = await colorsFile.readAsString();
      expect(updated, contains('#FF000000'));
      expect(updated, contains('ic_launcher_background'));
    });
  });
}
