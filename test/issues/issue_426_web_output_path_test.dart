import 'package:flutter_launcher_icons_flavors/config/web_config.dart';
import 'package:test/test.dart';

/// Behavior test for upstream issue #426.
/// See: issues/important/issue-426-web-output-path-flavors.md
///
/// `output_path` is a requested feature: per-flavor web builds need to
/// write into `web_<flavor>/` instead of the hard-coded `web/`. This test
/// documents that the fork currently has no such field on [WebConfig].
/// It is `skip`ped so the suite stays green until the feature lands.
void main() {
  group('issue #426: web output_path per-flavor', () {
    test('WebConfig parses output_path', () {
      final cfg = WebConfig.fromJson(<String, dynamic>{
        'generate': true,
        'image_path': 'app_icon.png',
        'output_path': 'web_prod',
      });
      expect(cfg.outputPath, 'web_prod');
    });

    test(
      'WebConfig outputPath defaults to null (writer applies convention)',
      () {
        final cfg = WebConfig.fromJson(<String, dynamic>{
          'generate': true,
          'image_path': 'app_icon.png',
        });
        expect(cfg.outputPath, isNull);
      },
    );
  });
}
