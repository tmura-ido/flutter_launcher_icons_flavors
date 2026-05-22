import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:test/test.dart';

/// Behavior test for upstream issue #535.
/// See: issues/issue-535-transparent-adaptive-background.md
///
/// `adaptive_icon_background: "#00000000"` should be persisted verbatim
/// (alpha component preserved) when written to `colors.xml`. Android's
/// color resources accept `#AARRGGBB`, so dropping the alpha component
/// silently turns transparent backgrounds into opaque black.
void main() {
  group(
    'issue #535: transparent adaptive_icon_background is preserved in colors.xml',
    () {
      test(
        'updateColorsFile writes the literal hex with alpha preserved',
        () async {
          final tmp = Directory.systemTemp.createTempSync('issue535_');
          try {
            final colors = File('${tmp.path}/colors.xml');
            // Seed an empty <resources/> document — the same starting point
            // updateColorsXmlFile would write via createNewColorsFile.
            await colors.writeAsString(
              '<?xml version="1.0" encoding="utf-8"?>\n'
              '<resources>\n'
              '</resources>\n',
            );

            await android.updateColorsFile(colors, '#00000000');

            final body = await colors.readAsString();
            expect(
              body,
              contains('#00000000'),
              reason:
                  'Transparent (fully-alpha-zero) backgrounds should round-trip '
                  'into the generated colors.xml unchanged.',
            );
          } finally {
            tmp.deleteSync(recursive: true);
          }
        },
      );

      test(
        'updating an existing color entry preserves the new alpha',
        () async {
          final tmp = Directory.systemTemp.createTempSync('issue535b_');
          try {
            final colors = File('${tmp.path}/colors.xml');
            await colors.writeAsString(
              '<?xml version="1.0" encoding="utf-8"?>\n'
              '<resources>\n'
              '    <color name="ic_launcher_background">#FFFFFFFF</color>\n'
              '</resources>\n',
            );

            await android.updateColorsFile(colors, '#00000000');

            final body = await colors.readAsString();
            expect(body, contains('#00000000'));
            expect(body, isNot(contains('#FFFFFFFF')));
          } finally {
            tmp.deleteSync(recursive: true);
          }
        },
      );
    },
  );
}
