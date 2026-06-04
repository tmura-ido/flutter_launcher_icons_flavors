// Structural spec checks for the iOS `Contents.json` builders in `lib/ios.dart`.
//
// `issue_153_..._test.dart` already verifies the *forward* direction — every
// filename referenced by Contents.json maps to a generated PNG template (no
// dangling references). This suite complements it with:
//   * the *reverse* direction — every generated template is referenced, so no
//     PNG is left on disk that Xcode flags as an "unassigned child";
//   * JSON validity + the `info` block (version 1, author "xcode");
//   * idiom/platform/appearance correctness, including the rule that the 1024
//     marketing slot is never dark- or tinted-qualified (upstream #587/#662).
import 'dart:convert';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:test/test.dart';

const _prefix = 'Icon-App';

void main() {
  group('Contents.json — JSON validity and info block', () {
    test('legacy output decodes and carries the xcode info block', () {
      final decoded =
          json.decode(ios.generateContentsFileAsString(_prefix, null, null))
              as Map<String, dynamic>;
      expect(decoded['images'], isA<List<dynamic>>());
      expect(decoded['info'], {'version': 1, 'author': 'xcode'});
    });

    test('modern output (dark+tinted) decodes and carries info', () {
      final decoded =
          json.decode(
                ios.generateContentsFileAsString(
                  _prefix,
                  '$_prefix-Dark',
                  '$_prefix-Tinted',
                ),
              )
              as Map<String, dynamic>;
      expect(decoded['images'], isA<List<dynamic>>());
      expect(decoded['info'], {'version': 1, 'author': 'xcode'});
    });
  });

  group('Contents.json — image list size + idiom/platform', () {
    test('legacy (pre-Xcode-14) list has 25 entries', () {
      expect(ios.createLegacyImageList(_prefix).length, 25);
    });

    test('modern base list has 17 entries', () {
      expect(ios.createImageList(_prefix, null, null).length, 17);
    });

    test('legacy entries carry neither platform nor appearances', () {
      for (final e in ios.createLegacyImageList(_prefix)) {
        expect(e.containsKey('platform'), isFalse);
        expect(e.containsKey('appearances'), isFalse);
      }
    });

    test('modern universal entries declare platform "ios"', () {
      final universal = ios
          .createImageList(_prefix, null, null)
          .where((e) => e['idiom'] == 'universal');
      expect(universal, isNotEmpty);
      for (final e in universal) {
        expect(e['platform'], 'ios');
      }
    });
  });

  group('Contents.json — no orphan PNGs (every template is referenced)', () {
    test('every legacyIosIcons template appears in the legacy list', () {
      final referenced = ios
          .createLegacyImageList(_prefix)
          .map((e) => e['filename'] as String)
          .toSet();
      for (final t in ios.legacyIosIcons) {
        expect(
          referenced,
          contains('$_prefix${t.name}.png'),
          reason: '${t.name} PNG is generated but never referenced',
        );
      }
    });

    test('every iosIcons template appears in the modern list', () {
      final referenced = ios
          .createImageList(_prefix, null, null)
          .map((e) => e['filename'] as String)
          .toSet();
      for (final t in ios.iosIcons) {
        expect(
          referenced,
          contains('$_prefix${t.name}.png'),
          reason: '${t.name} PNG is generated but never referenced',
        );
      }
    });
  });

  group('Contents.json — dark / tinted appearances', () {
    test('1024 marketing slot is never dark- or tinted-qualified', () {
      final marketing = ios
          .createImageList(_prefix, '$_prefix-Dark', '$_prefix-Tinted')
          .where((e) => e['idiom'] == 'ios-marketing');
      expect(marketing, isNotEmpty);
      for (final e in marketing) {
        expect(e.containsKey('appearances'), isFalse);
      }
    });

    test('dark variant adds luminosity=dark entries for the dark prefix', () {
      final dark = ios
          .createImageList(_prefix, '$_prefix-Dark', null)
          .where(
            (e) =>
                e.containsKey('appearances') &&
                (e['filename'] as String).startsWith('$_prefix-Dark'),
          )
          .toList();
      expect(dark, isNotEmpty);
      for (final e in dark) {
        expect(e['appearances'], [
          {'appearance': 'luminosity', 'value': 'dark'},
        ]);
      }
    });

    test('tinted variant adds luminosity=tinted entries for the tinted prefix', () {
      final tinted = ios
          .createImageList(_prefix, null, '$_prefix-Tinted')
          .where(
            (e) =>
                e.containsKey('appearances') &&
                (e['filename'] as String).startsWith('$_prefix-Tinted'),
          )
          .toList();
      expect(tinted, isNotEmpty);
      for (final e in tinted) {
        expect(e['appearances'], [
          {'appearance': 'luminosity', 'value': 'tinted'},
        ]);
      }
    });
  });
}
