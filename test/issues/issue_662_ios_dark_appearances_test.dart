import 'dart:convert';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:test/test.dart';

/// Regression test for upstream issue #662.
/// See: issues/issue-662-ios-dark-icon-not-switching.md
///
/// When `image_path_ios_dark_transparent` is configured, the generated
/// `Contents.json` must include the dark variant entries with the
/// `appearances: [{appearance: "luminosity", value: "dark"}]` qualifier so
/// that the OS picks the right asset on dark-mode toggle and at install
/// time (`flutter install`). Confirms the JSON shape matches what Xcode /
/// the asset compiler expects.
void main() {
  group('issue #662: Contents.json carries dark appearance qualifier', () {
    test('dark icon entries include {appearance: luminosity, value: dark}', () {
      final body = ios.generateContentsFileAsString(
        'AppIcon',
        'AppIcon-Dark',
        null,
      );
      final json = jsonDecode(body) as Map<String, dynamic>;
      final images = (json['images'] as List).cast<Map<String, dynamic>>();
      final darkEntries = images
          .where((e) => (e['filename'] as String).contains('AppIcon-Dark'))
          .toList();
      expect(
        darkEntries,
        isNotEmpty,
        reason: 'dark icon filenames should appear in Contents.json',
      );
      // Every dark entry must declare the dark luminosity appearance.
      for (final e in darkEntries) {
        final apps = e['appearances'] as List?;
        expect(apps, isNotNull, reason: 'dark entry missing appearances: $e');
        expect(
          apps!.cast<Map<String, dynamic>>().any(
            (a) => a['appearance'] == 'luminosity' && a['value'] == 'dark',
          ),
          isTrue,
          reason: 'dark entry without {luminosity: dark}: $e',
        );
      }
    });

    test(
      'tinted icon entries include {appearance: luminosity, value: tinted}',
      () {
        final body = ios.generateContentsFileAsString(
          'AppIcon',
          null,
          'AppIcon-Tinted',
        );
        final json = jsonDecode(body) as Map<String, dynamic>;
        final images = (json['images'] as List).cast<Map<String, dynamic>>();
        final tintedEntries = images
            .where((e) => (e['filename'] as String).contains('AppIcon-Tinted'))
            .toList();
        expect(tintedEntries, isNotEmpty);
        for (final e in tintedEntries) {
          final apps = e['appearances'] as List?;
          expect(apps, isNotNull);
          expect(
            apps!.cast<Map<String, dynamic>>().any(
              (a) => a['appearance'] == 'luminosity' && a['value'] == 'tinted',
            ),
            isTrue,
          );
        }
      },
    );
  });
}
