import 'package:flutter_launcher_icons_flavored/config/source_resolver.dart';
import 'package:flutter_launcher_icons_flavored/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../sink_helper.dart';

void main() {
  group('resolveSource precedence', () {
    String prefix() => d.sandbox;

    ({FLILogger logger, StringBuffer buf}) makeLogger() {
      final buf = StringBuffer();
      final logger = FLILogger(
        false,
        stderrSinkForTesting: BufferedIOSink(buf),
      );
      return (logger: logger, buf: buf);
    }

    test(
      '--file=custom.yaml (multi-flavor) → explicitFile, isMultiFlavor=true',
      () async {
        await d.file('custom.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
''').create();
        final l = makeLogger();
        final r = resolveSource(
          prefixPath: prefix(),
          explicitFilePath: p.join(prefix(), 'custom.yaml'),
          logger: l.logger,
        );
        expect(r.kind, ConfigSourceKind.explicitFile);
        expect(r.isMultiFlavor, isTrue);
        expect(l.buf.toString(), isEmpty);
      },
    );

    test(
      '--file=custom.yaml (single config) → explicitFile, isMultiFlavor=false',
      () async {
        await d.file('custom.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: assets/icon.png
''').create();
        final l = makeLogger();
        final r = resolveSource(
          prefixPath: prefix(),
          explicitFilePath: p.join(prefix(), 'custom.yaml'),
          logger: l.logger,
        );
        expect(r.kind, ConfigSourceKind.explicitFile);
        expect(r.isMultiFlavor, isFalse);
        expect(l.buf.toString(), isEmpty);
      },
    );

    test('--file=missing.yaml → NoConfigFoundException', () async {
      final l = makeLogger();
      expect(
        () => resolveSource(
          prefixPath: prefix(),
          explicitFilePath: p.join(prefix(), 'missing.yaml'),
          logger: l.logger,
        ),
        throwsA(isA<NoConfigFoundException>()),
      );
    });

    test('only consolidated → consolidatedFlavors, no warning', () async {
      await d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
''').create();
      final l = makeLogger();
      final r = resolveSource(prefixPath: prefix(), logger: l.logger);
      expect(r.kind, ConfigSourceKind.consolidatedFlavors);
      expect(r.ignoredLegacy, isEmpty);
      expect(r.isMultiFlavor, isTrue);
      expect(l.buf.toString(), isEmpty);
    });

    test(
      'consolidated + legacy → consolidatedFlavors, ignoredLegacy populated, warn mentions migrate',
      () async {
        await d.dir('p', [
          d.file('flutter_launcher_icons_flavors.yaml', '''
version: 1
flavors:
  dev:
    android: true
    image_path: assets/icon.png
'''),
          d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: assets/icon.png
'''),
        ]).create();
        final l = makeLogger();
        final r = resolveSource(
          prefixPath: p.join(prefix(), 'p'),
          logger: l.logger,
        );
        expect(r.kind, ConfigSourceKind.consolidatedFlavors);
        expect(r.ignoredLegacy.length, 1);
        expect(
          r.ignoredLegacy.single,
          contains('flutter_launcher_icons-dev.yaml'),
        );
        expect(l.buf.toString(), contains('migrate'));
      },
    );

    test('only legacy → legacyFlavors with deprecation warning', () async {
      await d.dir('q', [
        d.file('flutter_launcher_icons-dev.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: assets/icon.png
'''),
      ]).create();
      final l = makeLogger();
      final r = resolveSource(
        prefixPath: p.join(prefix(), 'q'),
        logger: l.logger,
      );
      expect(r.kind, ConfigSourceKind.legacyFlavors);
      expect(l.buf.toString(), contains('legacy'));
    });

    test('only single yaml → singleFile, no warning', () async {
      await d.dir('r', [
        d.file('flutter_launcher_icons.yaml', '''
flutter_launcher_icons:
  android: true
  image_path: assets/icon.png
'''),
      ]).create();
      final l = makeLogger();
      final r = resolveSource(
        prefixPath: p.join(prefix(), 'r'),
        logger: l.logger,
      );
      expect(r.kind, ConfigSourceKind.singleFile);
      expect(l.buf.toString(), isEmpty);
    });

    test('only pubspec inline → pubspecInline', () async {
      await d.dir('s', [
        d.file('pubspec.yaml', '''
name: example
flutter_launcher_icons:
  android: true
  image_path: assets/icon.png
'''),
      ]).create();
      final l = makeLogger();
      final r = resolveSource(
        prefixPath: p.join(prefix(), 's'),
        logger: l.logger,
      );
      expect(r.kind, ConfigSourceKind.pubspecInline);
    });

    test(
      'pubspec inline + single yaml → singleFile wins (per documented precedence)',
      () async {
        await d.dir('t', [
          d.file('pubspec.yaml', '''
name: example
flutter_launcher_icons:
  android: true
  image_path: assets/icon.png
'''),
          d.file('flutter_launcher_icons.yaml', '''
flutter_launcher_icons:
  ios: true
  image_path: assets/icon.png
'''),
        ]).create();
        final l = makeLogger();
        final r = resolveSource(
          prefixPath: p.join(prefix(), 't'),
          logger: l.logger,
        );
        expect(r.kind, ConfigSourceKind.singleFile);
      },
    );

    test('nothing → NoConfigFoundException', () async {
      await d.dir('empty', []).create();
      final l = makeLogger();
      expect(
        () => resolveSource(
          prefixPath: p.join(prefix(), 'empty'),
          logger: l.logger,
        ),
        throwsA(isA<NoConfigFoundException>()),
      );
    });
  });
}
