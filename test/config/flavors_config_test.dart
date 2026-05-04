import 'package:flutter_launcher_icons_flavored/config/flavors_config.dart';
import 'package:flutter_launcher_icons_flavored/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('FlavorsConfig', () {
    test('load returns null when file is absent', () {
      final missing = p.join(d.sandbox, 'no_such_file.yaml');
      expect(FlavorsConfig.load(missing, logger: FLILogger(false)), isNull);
    });

    test('resolve produces a fully-populated Config after merge', () async {
      await d.file('a.yaml', '''
version: 1
defaults:
  image_path: assets/icon.png
  android: true
flavors:
  dev:
    ios: true
  prod:
    android: ic_prod
''').create();

      final cfg = FlavorsConfig.load(
        p.join(d.sandbox, 'a.yaml'),
        logger: FLILogger(false),
      )!;

      expect(cfg.flavorNames, containsAll(['dev', 'prod']));

      final dev = cfg.resolve('dev');
      expect(dev.imagePath, 'assets/icon.png');
      expect(dev.android.isEnabled, isTrue);
      expect(dev.ios.isEnabled, isTrue);

      final prod = cfg.resolve('prod');
      expect(prod.imagePath, 'assets/icon.png');
      expect(prod.android.isEnabled, isTrue);
      expect(prod.android.isCustom, isTrue);
      expect(prod.android.customIconName, 'ic_prod');
      expect(prod.ios.isEnabled, isFalse);
    });

    test('resolve(unknown) throws UnknownFlavorException with names', () async {
      await d.file('b.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
''').create();
      final cfg = FlavorsConfig.load(
        p.join(d.sandbox, 'b.yaml'),
        logger: FLILogger(false),
      )!;

      expect(
        () => cfg.resolve('staging'),
        throwsA(
          isA<UnknownFlavorException>()
              .having((e) => e.requestedName, 'requestedName', 'staging')
              .having((e) => e.availableNames, 'availableNames', ['dev']),
        ),
      );
    });

    test(
      'resolve on a flavor missing required image_path throws InvalidConfigException',
      () async {
        await d.file('c.yaml', '''
version: 1
flavors:
  ok:
    android: true
    image_path: assets/icon.png
  broken:
    android: true
''').create();
        final cfg = FlavorsConfig.load(
          p.join(d.sandbox, 'c.yaml'),
          logger: FLILogger(false),
        )!;

        // Healthy flavor still works.
        expect(() => cfg.resolve('ok'), returnsNormally);

        expect(
          () => cfg.resolve('broken'),
          throwsA(
            isA<InvalidConfigException>().having(
              (e) => e.message,
              'message',
              // resolve() prefixes the field path with `flavors.<name>.`
              // so multi-flavor preflight errors stay attributable.
              contains('flavors.broken.'),
            ),
          ),
        );
      },
    );

    test(
      'falsy override end-to-end (defaults: android: true → flavor: false)',
      () async {
        await d.file('d.yaml', '''
version: 1
defaults:
  android: true
  ios: true
  image_path: assets/icon.png
flavors:
  webonly:
    android: false
    ios: false
    web:
      generate: true
      image_path: assets/icon.png
      background_color: "#fff"
      theme_color: "#000"
''').create();
        final cfg = FlavorsConfig.load(
          p.join(d.sandbox, 'd.yaml'),
          logger: FLILogger(false),
        )!;

        final resolved = cfg.resolve('webonly');
        expect(resolved.android.isEnabled, isFalse);
        expect(resolved.ios.isEnabled, isFalse);
        expect(resolved.hasWebConfig, isTrue);
      },
    );
  });
}
