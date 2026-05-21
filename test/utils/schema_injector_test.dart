import 'dart:io';

import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/utils/schema_injector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('ensureSchemaDirective', () {
    final logger = FLILogger(false);

    test('injects directive into a YAML file without one', () async {
      await d.file('cfg.yaml', 'version: 1\nflavors:\n  dev: {}\n').create();
      final path = p.join(d.sandbox, 'cfg.yaml');

      final wrote = await ensureSchemaDirective(path, logger: logger);

      expect(wrote, isTrue);
      final contents = await File(path).readAsString();
      expect(contents, startsWith('# yaml-language-server: \$schema='));
      // Original content preserved after the directive + blank line.
      expect(contents, contains('\nversion: 1\nflavors:\n  dev: {}\n'));
    });

    test('is idempotent — second call writes nothing', () async {
      await d.file('cfg.yaml', 'version: 1\n').create();
      final path = p.join(d.sandbox, 'cfg.yaml');

      final first = await ensureSchemaDirective(path, logger: logger);
      final firstContents = await File(path).readAsString();
      final second = await ensureSchemaDirective(path, logger: logger);
      final secondContents = await File(path).readAsString();

      expect(first, isTrue);
      expect(second, isFalse, reason: 'should detect existing directive');
      expect(secondContents, equals(firstContents));
    });

    test('skips file when user already set a different schema URL', () async {
      const userDirective =
          '# yaml-language-server: \$schema=./my-custom-schema.json';
      await d.file('cfg.yaml', '$userDirective\nversion: 1\n').create();
      final path = p.join(d.sandbox, 'cfg.yaml');

      final wrote = await ensureSchemaDirective(path, logger: logger);

      expect(wrote, isFalse);
      final contents = await File(path).readAsString();
      expect(contents, startsWith(userDirective));
      expect(contents, isNot(contains('raw.githubusercontent.com')));
    });

    test('returns false for non-existent file', () async {
      final wrote = await ensureSchemaDirective(
        p.join(d.sandbox, 'does-not-exist.yaml'),
        logger: logger,
      );

      expect(wrote, isFalse);
    });

    test('leaves pubspec.yaml untouched', () async {
      await d.file('pubspec.yaml', 'name: foo\nversion: 1.0.0\n').create();
      final path = p.join(d.sandbox, 'pubspec.yaml');

      final wrote = await ensureSchemaDirective(path, logger: logger);

      expect(wrote, isFalse);
      final contents = await File(path).readAsString();
      expect(contents, isNot(contains('yaml-language-server')));
    });

    test('skip=true is a no-op even on a fresh file', () async {
      await d.file('cfg.yaml', 'version: 1\n').create();
      final path = p.join(d.sandbox, 'cfg.yaml');

      final wrote = await ensureSchemaDirective(
        path,
        logger: logger,
        skip: true,
      );

      expect(wrote, isFalse);
      final contents = await File(path).readAsString();
      expect(contents, isNot(contains('yaml-language-server')));
    });

    test('handles empty file without a stray blank line', () async {
      await d.file('cfg.yaml', '').create();
      final path = p.join(d.sandbox, 'cfg.yaml');

      final wrote = await ensureSchemaDirective(path, logger: logger);

      expect(wrote, isTrue);
      final contents = await File(path).readAsString();
      // No blank line before nothing — directive + newline is enough.
      expect(contents, '$schemaDirective\n');
    });
  });
}
