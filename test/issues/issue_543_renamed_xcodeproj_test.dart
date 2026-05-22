import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/ios.dart' as ios;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression for upstream issue #543 + #637.
/// See:
///   issues/approved/issue-543-rename-runner-project.md
///   issues/approved/issue-637-xcodeproj-path-ignored-with-flavors.md
///
/// `resolveIosPbxprojPath` should:
///   - honor `xcodeproj_path` explicitly when set,
///   - else auto-detect when exactly one `*.xcodeproj` exists,
///   - else error clearly when multiple exist,
///   - else fall back to `ios/Runner.xcodeproj/project.pbxproj`.
void main() {
  group('issue #543/#637: xcodeproj_path resolution', () {
    test('explicit xcodeproj_path wins (path includes project.pbxproj)', () {
      expect(
        ios.resolveIosPbxprojPath(
          prefixPath: '.',
          explicit: 'ios/MyApp.xcodeproj/project.pbxproj',
        ),
        'ios/MyApp.xcodeproj/project.pbxproj',
      );
    });

    test(
      'explicit xcodeproj_path as directory has project.pbxproj appended',
      () {
        final got = ios.resolveIosPbxprojPath(
          prefixPath: '.',
          explicit: 'ios/MyApp.xcodeproj',
        );
        expect(got, p.join('ios/MyApp.xcodeproj', 'project.pbxproj'));
      },
    );

    test('single ios/*.xcodeproj is auto-detected', () async {
      await d.dir('proj543_single', [
        d.dir('ios', [
          d.dir('MyApp.xcodeproj', [d.file('project.pbxproj', '// ...')]),
        ]),
      ]).create();
      final prefix = p.join(d.sandbox, 'proj543_single');

      final got = ios.resolveIosPbxprojPath(prefixPath: prefix);
      expect(got, p.join('ios', 'MyApp.xcodeproj', 'project.pbxproj'));
    });

    test('multiple ios/*.xcodeproj raises an InvalidConfigException', () async {
      await d.dir('proj543_multi', [
        d.dir('ios', [
          d.dir('MyApp.xcodeproj', [d.file('project.pbxproj', '// ...')]),
          d.dir('Runner.xcodeproj', [d.file('project.pbxproj', '// ...')]),
        ]),
      ]).create();
      final prefix = p.join(d.sandbox, 'proj543_multi');

      expect(
        () => ios.resolveIosPbxprojPath(prefixPath: prefix),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.toString(),
            'toString',
            allOf(contains('MyApp.xcodeproj'), contains('Runner.xcodeproj')),
          ),
        ),
      );
    });

    test(
      'zero matches falls back to ios/Runner.xcodeproj/project.pbxproj',
      () async {
        await d.dir('proj543_none', [d.dir('ios')]).create();
        final prefix = p.join(d.sandbox, 'proj543_none');

        final got = ios.resolveIosPbxprojPath(prefixPath: prefix);
        expect(got, 'ios/Runner.xcodeproj/project.pbxproj');
      },
    );
  });
}
