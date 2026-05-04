import 'package:checked_yaml/checked_yaml.dart';
import 'package:flutter_launcher_icons_flavored/config/config.dart';
import 'package:flutter_launcher_icons_flavored/config/platform_toggle.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformToggleConverter', () {
    const c = PlatformToggleConverter();

    test('false -> disabled', () {
      final t = c.fromJson(false);
      expect(t, equals(PlatformToggle.disabled()));
      expect(t.isEnabled, isFalse);
    });

    test('null -> disabled', () {
      final t = c.fromJson(null);
      expect(t, equals(PlatformToggle.disabled()));
      expect(t.isEnabled, isFalse);
    });

    test('true -> enabled, isCustom == false', () {
      final t = c.fromJson(true);
      expect(t, equals(PlatformToggle.enabled()));
      expect(t.isEnabled, isTrue);
      expect(t.isCustom, isFalse);
      expect(t.customIconName, isNull);
    });

    test('non-empty String -> named', () {
      final t = c.fromJson('ic_launcher_dev');
      expect(t.isEnabled, isTrue);
      expect(t.isCustom, isTrue);
      expect(t.customIconName, 'ic_launcher_dev');
    });

    test('empty String throws', () {
      expect(() => c.fromJson(''), throwsArgumentError);
    });

    test('number throws', () {
      expect(() => c.fromJson(42), throwsArgumentError);
    });

    test('list throws', () {
      expect(() => c.fromJson([1, 2, 3]), throwsArgumentError);
    });

    test('map throws', () {
      expect(() => c.fromJson({'foo': 'bar'}), throwsArgumentError);
    });

    test('JSON round-trip: disabled -> false', () {
      expect(PlatformToggle.disabled().toJson(), false);
    });

    test('JSON round-trip: enabled -> true', () {
      expect(PlatformToggle.enabled().toJson(), true);
    });

    test('JSON round-trip: named("x") -> "x"', () {
      expect(PlatformToggle.named('x').toJson(), 'x');
    });
  });

  group('Config integration', () {
    test('android: "ic_launcher_dev" -> isCustomAndroidFile == true', () {
      final config = Config.fromJson({
        'image_path': 'assets/icon.png',
        'android': 'ic_launcher_dev',
      });
      expect(config.isCustomAndroidFile, isTrue);
      expect(config.androidIconName, 'ic_launcher_dev');
      expect(config.android.isEnabled, isTrue);
    });

    test('ios: true -> not custom', () {
      final config = Config.fromJson({
        'image_path': 'assets/icon.png',
        'ios': true,
      });
      expect(config.isCustomIOSFile, isFalse);
      expect(config.iosIconName, '');
      expect(config.ios.isEnabled, isTrue);
    });

    test('checked yaml surfaces offending key on bad value', () {
      // checkedYamlDecode wraps converter ArgumentErrors in
      // CheckedFromJsonException with the offending key path.
      const yamlSource = '''
image_path: assets/icon.png
android: 42
''';
      expect(
        () => checkedYamlDecode<Config>(yamlSource, (m) => Config.fromJson(m!)),
        throwsA(
          isA<ParsedYamlException>().having(
            (e) => e.toString(),
            'toString',
            contains('android'),
          ),
        ),
      );
    });
  });
}
