import 'dart:convert';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:test/test.dart';

/// Regression test for upstream issue #587.
/// See: issues/important/issue-587-appicon-tinted-folder.md
///
/// Xcode 16 expects the dark and tinted variants inside the same
/// `AppIcon.appiconset` catalog as the light/default variant, NOT in a
/// separate `AppIcon-Tinted/` catalog. The fork already merges them via
/// [ios.generateContentsFileAsString] / [ios.modifyDefaultContentsFile];
/// this test asserts the behavior holds for each individual combination
/// of dark / tinted (regression against #587).
void main() {
  group(
    'issue #587: tinted/dark variants share the single AppIcon catalog',
    () {
      test('tinted-only generates appearances inside same catalog', () {
        final json = ios.generateContentsFileAsString(
          'Icon-App',
          null,
          'Icon-App-Tinted',
        );
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final images = (decoded['images'] as List).cast<Map<String, dynamic>>();

        // At least one image entry must carry the tinted appearance.
        final tinted = images.where((img) {
          final appearances = img['appearances'] as List?;
          if (appearances == null) {
            return false;
          }
          return appearances.any(
            (a) =>
                (a as Map)['appearance'] == 'luminosity' &&
                a['value'] == 'tinted',
          );
        });
        expect(
          tinted,
          isNotEmpty,
          reason: 'tinted appearance entries must be present',
        );

        // Every filename must live inside the single AppIcon catalog —
        // i.e. start with the same base prefix ("Icon-App" or
        // "Icon-App-Tinted") and NOT introduce a separate catalog path.
        for (final img in images) {
          final name = img['filename'] as String;
          expect(
            name.startsWith('Icon-App-') || name.startsWith('Icon-App'),
            isTrue,
            reason: 'filename "$name" must stay within one catalog',
          );
        }
      });

      test('dark-only generates appearances inside same catalog', () {
        final json = ios.generateContentsFileAsString(
          'Icon-App',
          'Icon-App-Dark',
          null,
        );
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final images = (decoded['images'] as List).cast<Map<String, dynamic>>();

        final dark = images.where((img) {
          final appearances = img['appearances'] as List?;
          if (appearances == null) {
            return false;
          }
          return appearances.any(
            (a) =>
                (a as Map)['appearance'] == 'luminosity' &&
                a['value'] == 'dark',
          );
        });
        expect(
          dark,
          isNotEmpty,
          reason: 'dark appearance entries must be present',
        );
      });

      test(
        'dark + tinted together generate both appearance kinds in one catalog',
        () {
          final json = ios.generateContentsFileAsString(
            'Icon-App',
            'Icon-App-Dark',
            'Icon-App-Tinted',
          );
          final decoded = jsonDecode(json) as Map<String, dynamic>;
          final images = (decoded['images'] as List)
              .cast<Map<String, dynamic>>();

          final hasDark = images.any((img) {
            final appearances = img['appearances'] as List?;
            return appearances != null &&
                appearances.any(
                  (a) =>
                      (a as Map)['appearance'] == 'luminosity' &&
                      a['value'] == 'dark',
                );
          });
          final hasTinted = images.any((img) {
            final appearances = img['appearances'] as List?;
            return appearances != null &&
                appearances.any(
                  (a) =>
                      (a as Map)['appearance'] == 'luminosity' &&
                      a['value'] == 'tinted',
                );
          });
          expect(hasDark, isTrue);
          expect(hasTinted, isTrue);
        },
      );
    },
  );
}
