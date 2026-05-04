import 'dart:convert';
import 'dart:io';

import 'package:flutter_launcher_icons_flavored/config/flavors_config.dart';
import 'package:flutter_launcher_icons_flavored/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Helper: writes a flavors yaml at `<sandbox>/<filename>` and loads it.
Future<FlavorsConfig?> _load(
  String filename,
  String content, {
  FLILogger? logger,
}) async {
  await d.file(filename, content).create();
  return FlavorsConfig.load(
    p.join(d.sandbox, filename),
    logger: logger ?? FLILogger(false),
  );
}

void main() {
  group('FlavorsFile schema validation', () {
    test('minimal valid file (single flavor, no defaults)', () async {
      final cfg = await _load('a.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
''');
      expect(cfg, isNotNull);
      expect(cfg!.flavorNames, ['dev']);
    });

    test('missing version → error', () async {
      await expectLater(
        _load('b.yaml', '''
flavors:
  dev:
    android: true
'''),
        throwsA(isA<InvalidFlavorsFileException>()),
      );
    });

    test('version: 2 → error mentioning supported version', () async {
      await expectLater(
        _load('c.yaml', '''
version: 2
flavors:
  dev:
    android: true
'''),
        throwsA(
          isA<InvalidFlavorsFileException>().having(
            (e) => e.message,
            'message',
            contains('version'),
          ),
        ),
      );
    });

    test('missing flavors → error', () async {
      await expectLater(
        _load('d.yaml', '''
version: 1
'''),
        throwsA(isA<InvalidFlavorsFileException>()),
      );
    });

    test('empty flavors map → error', () async {
      await expectLater(
        _load('e.yaml', '''
version: 1
flavors: {}
'''),
        throwsA(
          isA<InvalidFlavorsFileException>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('invalid flavor name with space → error', () async {
      await expectLater(
        _load('f.yaml', '''
version: 1
flavors:
  "flavor with space":
    android: true
'''),
        throwsA(isA<InvalidFlavorsFileException>()),
      );
    });

    test('invalid flavor name "../escape" → error', () async {
      await expectLater(
        _load('g.yaml', '''
version: 1
flavors:
  "../escape":
    android: true
'''),
        throwsA(isA<InvalidFlavorsFileException>()),
      );
    });

    test('invalid flavor name "." → error', () async {
      await expectLater(
        _load('h.yaml', '''
version: 1
flavors:
  ".":
    android: true
'''),
        throwsA(isA<InvalidFlavorsFileException>()),
      );
    });

    test('invalid flavor name with leading underscore → error', () async {
      await expectLater(
        _load('i.yaml', '''
version: 1
flavors:
  _bad:
    android: true
'''),
        throwsA(isA<InvalidFlavorsFileException>()),
      );
    });

    test('unknown top-level key → warning logged, parse succeeds', () async {
      final stderrSink = _CapturingSink();
      final logger = FLILogger(false, stderrSinkForTesting: stderrSink);
      final cfg = await _load('j.yaml', '''
version: 1
extras: {}
flavors:
  dev:
    android: true
    image_path: assets/icon.png
''', logger: logger);
      expect(cfg, isNotNull);
      expect(stderrSink.text, contains('Unknown top-level key'));
      expect(stderrSink.text, contains('extras'));
    });

    test('unknown nested key inside flavor → error with key path', () async {
      await expectLater(
        _load('k.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
    bogus_typo: 123
'''),
        throwsA(isA<InvalidFlavorsFileException>()),
      );
    });

    test('unknown nested key inside defaults → error', () async {
      await expectLater(
        _load('l.yaml', '''
version: 1
defaults:
  bogus_default: 1
flavors:
  dev:
    android: true
'''),
        throwsA(isA<InvalidFlavorsFileException>()),
      );
    });

    test(
      'image_path + image_path_android both present → parses (validation deferred)',
      () async {
        final cfg = await _load('m.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
    image_path_android: assets/android.png
''');
        expect(cfg, isNotNull);
        // Resolve does the full Config validation.
        expect(() => cfg!.resolve('dev'), returnsNormally);
      },
    );

    test(
      'unknown key inside flavors.<name>.web → error with key path',
      () async {
        await expectLater(
          _load('n.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
    web:
      generate: true
      image_path: assets/icon.png
      background_color: "#fff"
      theme_color: "#000"
      gnerate: true
'''),
          throwsA(
            isA<InvalidFlavorsFileException>()
                .having((e) => e.flavor, 'flavor', 'dev')
                .having((e) => e.keyPath, 'keyPath', 'flavors.dev.web.gnerate')
                .having((e) => e.message, 'message', contains('gnerate')),
          ),
        );
      },
    );

    test('unknown key inside defaults.windows → error with key path', () async {
      await expectLater(
        _load('o.yaml', '''
version: 1
defaults:
  windows:
    generate: true
    image_path: assets/icon.png
    bogus: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
'''),
        throwsA(
          isA<InvalidFlavorsFileException>()
              .having((e) => e.flavor, 'flavor', isNull)
              .having((e) => e.keyPath, 'keyPath', 'defaults.windows.bogus'),
        ),
      );
    });

    test('unknown key inside flavors.<name>.macos → error', () async {
      await expectLater(
        _load('p.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
    macos:
      generate: true
      image_path: assets/icon.png
      icon_size: 512
'''),
        throwsA(
          isA<InvalidFlavorsFileException>()
              .having((e) => e.flavor, 'flavor', 'dev')
              .having(
                (e) => e.keyPath,
                'keyPath',
                'flavors.dev.macos.icon_size',
              ),
        ),
      );
    });

    test('valid nested platform keys still pass', () async {
      final cfg = await _load('q.yaml', '''
version: 1
defaults:
  image_path: assets/icon.png
flavors:
  dev:
    android: true
    web:
      generate: true
      image_path: assets/icon.png
      background_color: "#ffffff"
      theme_color: "#000000"
    windows:
      generate: true
      image_path: assets/icon.png
      icon_size: 256
    macos:
      generate: true
      image_path: assets/icon.png
''');
      expect(cfg, isNotNull);
      expect(() => cfg!.resolve('dev'), returnsNormally);
    });

    test(
      'duplicate flavor name → YAML parser error wrapped as InvalidFlavorsFileException',
      () async {
        // `package:yaml` rejects duplicate mapping keys at parse time;
        // we verify that error is wrapped (not surfaced as a raw
        // YamlException) so callers only need to catch our type.
        await expectLater(
          _load('r.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/a.png
  dev:
    ios: true
    image_path: assets/b.png
'''),
          throwsA(
            isA<InvalidFlavorsFileException>().having(
              (e) => e.message,
              'message',
              contains('Duplicate'),
            ),
          ),
        );
      },
    );
  });
}

class _CapturingSink implements IOSink {
  final StringBuffer _buf = StringBuffer();

  String get text => _buf.toString();

  @override
  Encoding encoding = utf8;

  @override
  void writeln([Object? object = '']) => _buf.writeln(object);

  @override
  void write(Object? object) => _buf.write(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    var first = true;
    for (final o in objects) {
      if (!first) {
        _buf.write(separator);
      }
      _buf.write(o);
      first = false;
    }
  }

  @override
  void writeCharCode(int charCode) => _buf.writeCharCode(charCode);

  @override
  void add(List<int> data) => _buf.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.forEach(add);
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done async {}

  @override
  Future<void> flush() async {}
}
