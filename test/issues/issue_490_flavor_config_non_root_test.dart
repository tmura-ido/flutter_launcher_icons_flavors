import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:test/test.dart';

/// Behavior test for upstream issue #490.
/// See: issues/important/issue-490-flavor-config-non-root.md
///
/// When a single legacy `flutter_launcher_icons-<flavor>.yaml` lives
/// outside the project root, the fork's [Config] schema has no way for
/// the user to assert "this file is the X flavor". The requested fix
/// is an explicit `flavor:` key in [PartialConfig] / [Config] that
/// overrides any filename-derived flavor name.
///
/// This test will fail (and thereby document the gap) until the schema
/// learns about `flavor`.
void main() {
  group('issue #490: explicit `flavor:` key in legacy single-flavor file', () {
    test('PartialConfig.fromJson accepts and round-trips a `flavor` key',
        () {
      final p = PartialConfig.fromJson(<String, dynamic>{
        'image_path': 'assets/icon.png',
        'android': true,
        'flavor': 'dev',
      });
      expect(p.flavor, 'dev');
      // disallowUnrecognizedKeys still rejects truly unknown keys.
      expect(
        () => PartialConfig.fromJson(<String, dynamic>{
          'image_path': 'x.png',
          'gibberish_key': true,
        }),
        throwsA(anything),
      );
    });
  });
}
