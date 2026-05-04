import 'package:flutter_launcher_icons_flavored/main.dart' as fli;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('getFlavors honors prefixPath', () {
    test('only finds flavor files under the given prefix dir', () async {
      // Lay down a fake working tree:
      //   <sandbox>/subdir/flutter_launcher_icons-dev.yaml      (in-prefix)
      //   <sandbox>/flutter_launcher_icons-other.yaml           (out-of-prefix)
      await d.dir('subdir', [
        d.file(
          'flutter_launcher_icons-dev.yaml',
          'flutter_launcher_icons:\n  image_path: assets/icon.png\n',
        ),
      ]).create();
      await d
          .file(
            'flutter_launcher_icons-other.yaml',
            'flutter_launcher_icons:\n  image_path: assets/icon.png\n',
          )
          .create();

      final prefix = path.join(d.sandbox, 'subdir');
      final flavors = await fli.getFlavors(prefix);

      expect(flavors, equals(['dev']));
      expect(flavors, isNot(contains('other')));
    });

    test('returns empty list when prefix has no flavor files', () async {
      await d.dir('empty_prefix', []).create();
      final flavors = await fli.getFlavors(
        path.join(d.sandbox, 'empty_prefix'),
      );
      expect(flavors, isEmpty);
    });
  });
}
