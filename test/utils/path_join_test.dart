import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('path.join based constants', () {
    test('androidAdaptiveXmlFolder uses platform separator', () {
      final p = constants.androidAdaptiveXmlFolder('dev');
      // Path uses the platform separator. On posix this is '/', on Windows
      // it is '\\'. Either way: no double-separators.
      expect(p, isNot(contains('//')));
      expect(p, isNot(contains(r'\\')));
      // Equivalent to the joined components, normalized.
      expect(
        path.equals(
          p,
          path.join('android', 'app', 'src', 'dev', 'res', 'mipmap-anydpi-v26'),
        ),
        isTrue,
      );
    });

    test('androidAdaptiveXmlFolder(null) defaults to main', () {
      final p = constants.androidAdaptiveXmlFolder(null);
      expect(
        path.equals(
          p,
          path.join(
            'android',
            'app',
            'src',
            'main',
            'res',
            'mipmap-anydpi-v26',
          ),
        ),
        isTrue,
      );
    });

    test('androidResFolder + androidColorsFile compose correctly', () {
      expect(
        path.equals(
          constants.androidColorsFile('dev'),
          path.join(constants.androidResFolder('dev'), 'values', 'colors.xml'),
        ),
        isTrue,
      );
    });

    test('joining works with windows-style path separator', () {
      // Cross-platform check: path.windows.join produces backslashes; the
      // resulting path round-trips back to the same components.
      final p = path.windows.join(
        'android',
        'app',
        'src',
        'main',
        'res',
        'mipmap-anydpi-v26',
      );
      expect(p, contains(r'\'));
      expect(p, isNot(contains('/')));
      expect(p.split(r'\').last, 'mipmap-anydpi-v26');
    });
  });
}
