import 'dart:convert';

import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:test/test.dart';

/// Regression test for upstream issue #110.
/// See: issues/issue-110-ios-app-store-icon-wrong-filename.md
///
/// The iOS Contents.json entry for the App Store marketing icon must
/// reference a 1024x1024 PNG at scale 1x with idiom `ios-marketing`.
/// Historically this entry pointed at the 83.5@2x file with scale 2x,
/// causing Xcode to report an unassigned App Store icon at upload.
void main() {
  group('issue #110: iOS marketing icon Contents.json mapping', () {
    test('legacy image list has 1024x1024 @1x ios-marketing entry', () {
      const prefix = 'Icon-App';
      final imageList = ios.createLegacyImageList(prefix);
      final marketing = imageList.where((e) => e['idiom'] == 'ios-marketing');
      expect(marketing, hasLength(1));
      final entry = marketing.single;
      expect(entry['size'], equals('1024x1024'));
      expect(entry['scale'], equals('1x'));
      expect(entry['filename'], equals('$prefix-1024x1024@1x.png'));
    });

    test('modern image list has 1024x1024 @1x ios-marketing entry', () {
      const prefix = 'Icon-App';
      final imageList = ios.createImageList(prefix, null, null);
      final marketing = imageList.where((e) => e['idiom'] == 'ios-marketing');
      expect(marketing, hasLength(1));
      final entry = marketing.single;
      expect(entry['size'], equals('1024x1024'));
      expect(entry['scale'], equals('1x'));
      expect(entry['filename'], equals('$prefix-1024x1024@1x.png'));
    });

    test(
      'generateContentsFileAsString encodes the marketing entry at 1024@1x',
      () {
        final raw = ios.generateContentsFileAsString('Icon-App', null, null);
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final images = (decoded['images'] as List).cast<Map<String, dynamic>>();
        final marketing = images.where((e) => e['idiom'] == 'ios-marketing');
        expect(marketing, hasLength(1));
        expect(marketing.single['size'], equals('1024x1024'));
        expect(marketing.single['scale'], equals('1x'));
      },
    );

    test('IosIconTemplate for 1024 has size 1024 and @1x suffix', () {
      final marketing1024 = ios.iosIcons.where((t) => t.size == 1024);
      expect(marketing1024, hasLength(1));
      expect(marketing1024.single.name, equals('-1024x1024@1x'));

      final legacyMarketing = ios.legacyIosIcons.where((t) => t.size == 1024);
      expect(legacyMarketing, hasLength(1));
      expect(legacyMarketing.single.name, equals('-1024x1024@1x'));
    });
  });
}
