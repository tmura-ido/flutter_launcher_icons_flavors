import 'package:flutter_launcher_icons_flavors/config/source_resolver.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression for upstream issue #279.
/// See: issues/approved/issue-279-flavors-not-detected.md
///
/// When the user has only flavor configs (no base file, no pubspec block),
/// the resolver's last-resort error should list the discovered flavor files
/// instead of just saying "no config found".
void main() {
  group('issue #279: legacy flavor configs are discovered everywhere', () {
    test(
      'resolveSource finds subfolder legacy configs (no exception)',
      () async {
        // No pubspec, no base config, no legacy at root — but flavor files
        // exist in a subfolder. Resolver should find them, not throw.
        await d.dir('proj_279', [
          d.dir('config', [
            d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
            d.file('flutter_launcher_icons-prod.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: app_icon.png
'''),
          ]),
        ]).create();
        final dir = p.join(d.sandbox, 'proj_279');

        final resolved = resolveSource(
          prefixPath: dir,
          logger: FLILogger(false),
        );
        expect(resolved.kind, ConfigSourceKind.legacyFlavors);
      },
    );

    test('NoConfigFoundException fires when truly no config exists', () async {
      await d.dir('proj_279_empty', []).create();
      final dir = p.join(d.sandbox, 'proj_279_empty');

      expect(
        () => resolveSource(prefixPath: dir, logger: FLILogger(false)),
        throwsA(isA<NoConfigFoundException>()),
      );
    });

    test(
      'NoConfigFoundException message has actionable hint with --file',
      () async {
        await d.dir('proj_279_empty2', [
          d.file('readme.txt', 'no config here'),
        ]).create();
        final dir = p.join(d.sandbox, 'proj_279_empty2');

        try {
          resolveSource(prefixPath: dir, logger: FLILogger(false));
          fail('expected NoConfigFoundException');
        } on NoConfigFoundException catch (e) {
          expect(e.toString(), contains('--file'));
        }
      },
    );
  });
}
