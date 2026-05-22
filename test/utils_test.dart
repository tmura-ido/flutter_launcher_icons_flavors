import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('#areFSEntitiesExist', () {
    late String prefixPath;
    setUp(() async {
      prefixPath = path.join(d.sandbox, 'fli_test');
      await d.dir('fli_test', [
        d.file('file1.txt', 'contents1'),
        d.dir('dir1'),
      ]).create();
    });

    test('should return null when entities exist', () async {
      expect(
        utils.areFSEntitiesExist([
          path.join(prefixPath, 'file1.txt'),
          path.join(prefixPath, 'dir1'),
        ]),
        isNull,
      );
    });

    test('should return the file path that does not exist', () {
      final result = utils.areFSEntitiesExist([
        path.join(prefixPath, 'dir1'),
        path.join(prefixPath, 'file_that_does_not_exist.txt'),
      ]);
      expect(result, isNotNull);
      expect(
        result,
        equals(path.join(prefixPath, 'file_that_does_not_exist.txt')),
      );
    });

    test('should return the dir path that does not exist', () {
      final result = utils.areFSEntitiesExist([
        path.join(prefixPath, 'dir_that_does_not_exist'),
        path.join(prefixPath, 'file.txt'),
      ]);
      expect(result, isNotNull);
      expect(result, equals(path.join(prefixPath, 'dir_that_does_not_exist')));
    });

    test('should return the first entity path that does not exist', () {
      final result = utils.areFSEntitiesExist([
        path.join(prefixPath, 'dir_that_does_not_exist'),
        path.join(prefixPath, 'file_that_does_not_exist.txt'),
      ]);
      expect(result, isNotNull);
      expect(result, equals(path.join(prefixPath, 'dir_that_does_not_exist')));
    });
  });

  group('#createDirIfNotExist', () {
    setUpAll(() async {
      await d.dir('fli_test', [d.dir('dir_exists')]).create();
    });
    test('should create directory if it does not exist', () async {
      await expectLater(
        d.dir('fli_test', [d.dir('dir_that_does_not_exist')]).validate(),
        throwsException,
      );
      final result = await utils.createDirIfNotExist(
        path.join(d.sandbox, 'fli_test', 'dir_that_does_not_exist'),
      );
      expect(result.existsSync(), isTrue);
      await expectLater(
        d.dir('fli_test', [d.dir('dir_that_does_not_exist')]).validate(),
        completes,
      );
    });
    test('should return dir if it exist', () async {
      await expectLater(
        d.dir('fli_test', [d.dir('dir_exists')]).validate(),
        completes,
      );
      final result = await utils.createDirIfNotExist(
        path.join(d.sandbox, 'fli_test', 'dir_exists'),
      );
      expect(result.existsSync(), isTrue);
      await expectLater(
        d.dir('fli_test', [d.dir('dir_exists')]).validate(),
        completes,
      );
    });
  });

  group('#createFileIfNotExist', () {
    setUpAll(() async {
      await d.dir('fli_test', [d.file('file_exists.txt')]).create();
    });
    test('should create file if it does not exist', () async {
      await expectLater(
        d.dir('fli_test', [d.file('file_that_does_not_exist.txt')]).validate(),
        throwsException,
      );
      final result = await utils.createFileIfNotExist(
        path.join(d.sandbox, 'fli_test', 'file_that_does_not_exist.txt'),
      );
      expect(result.existsSync(), isTrue);
      await expectLater(
        d.dir('fli_test', [d.file('file_that_does_not_exist.txt')]).validate(),
        completes,
      );
    });
    test('should return file if it exist', () async {
      await expectLater(
        d.dir('fli_test', [d.file('file_exists.txt')]).validate(),
        completes,
      );
      final result = await utils.createFileIfNotExist(
        path.join(d.sandbox, 'fli_test', 'file_exists.txt'),
      );
      expect(result.existsSync(), isTrue);
      await expectLater(
        d.dir('fli_test', [d.file('file_exists.txt')]).validate(),
        completes,
      );
    });
  });

  group('#prettifyJsonEncode', () {
    test('should return prettified json string with 4-space indents', () {
      const expectedValue = r'''
{
    "key1": "value1",
    "key2": "value2"
}''';
      final result = utils.prettifyJsonEncode({
        'key1': 'value1',
        'key2': 'value2',
      });
      expect(result, equals(expectedValue));
    });
  });

  group('#parseHexColor', () {
    test('parses #RRGGBB with leading hash', () {
      final c = utils.parseHexColor('#FF8000');
      expect(c.r, 0xff);
      expect(c.g, 0x80);
      expect(c.b, 0x00);
      expect(c.a, 0xff);
    });

    test('parses RRGGBB without leading hash', () {
      final c = utils.parseHexColor('00FF00');
      expect(c.r, 0x00);
      expect(c.g, 0xff);
      expect(c.b, 0x00);
      expect(c.a, 0xff);
    });

    test('parses #AARRGGBB with alpha', () {
      // 0x80AABBCC → A=0x80, R=0xAA, G=0xBB, B=0xCC
      final c = utils.parseHexColor('#80AABBCC');
      expect(c.r, 0xaa);
      expect(c.g, 0xbb);
      expect(c.b, 0xcc);
      expect(c.a, 0x80);
    });

    test('throws InvalidConfigException on bad length', () {
      expect(
        () => utils.parseHexColor('#ABC'),
        throwsA(isA<InvalidConfigException>()),
      );
      expect(
        () => utils.parseHexColor('#1234567'),
        throwsA(isA<InvalidConfigException>()),
      );
    });
  });

  group('#letterBoxToSquare', () {
    test('returns the input unchanged when already square', () {
      final src = Image(width: 64, height: 64);
      final out = utils.letterBoxToSquare(src, ColorUint8.rgba(0, 0, 0, 0xff));
      expect(identical(out, src), isTrue);
    });

    test('pads wide source to a square canvas with bg bars top+bottom', () {
      // 100x40 red source on a white bg → 100x100 result.
      // Vertical bars (size - h)/2 = 30 above and below.
      final src = Image(width: 100, height: 40);
      for (final p in src) {
        p.setRgba(255, 0, 0, 0xff);
      }
      final out = utils.letterBoxToSquare(
        src,
        ColorUint8.rgba(255, 255, 255, 0xff),
      );
      expect(out.width, 100);
      expect(out.height, 100);
      // Top row is bg (white)
      final top = out.getPixel(50, 0);
      expect(top.r, 255);
      expect(top.g, 255);
      expect(top.b, 255);
      // Center row is the source (red)
      final center = out.getPixel(50, 50);
      expect(center.r, 255);
      expect(center.g, 0);
      expect(center.b, 0);
      // Bottom row is bg (white)
      final bottom = out.getPixel(50, 99);
      expect(bottom.r, 255);
      expect(bottom.g, 255);
      expect(bottom.b, 255);
    });

    test('pads tall source to a square canvas with bg bars left+right', () {
      final src = Image(width: 40, height: 100);
      for (final p in src) {
        p.setRgba(0, 0, 255, 0xff);
      }
      final out = utils.letterBoxToSquare(
        src,
        ColorUint8.rgba(0, 255, 0, 0xff),
      );
      expect(out.width, 100);
      expect(out.height, 100);
      // Left column is bg (green)
      final left = out.getPixel(0, 50);
      expect(left.g, 255);
      expect(left.r, 0);
      expect(left.b, 0);
      // Center column is the source (blue)
      final center = out.getPixel(50, 50);
      expect(center.b, 255);
      expect(center.r, 0);
      expect(center.g, 0);
    });

    test(
      'honors the alpha channel of the bg color (transparent letter-box)',
      () {
        final src = Image(width: 100, height: 40);
        for (final p in src) {
          p.setRgba(255, 0, 0, 0xff);
        }
        final out = utils.letterBoxToSquare(src, ColorUint8.rgba(0, 0, 0, 0));
        final top = out.getPixel(50, 0);
        expect(
          top.a,
          0,
          reason: 'transparent bg leaves bars fully transparent',
        );
      },
    );
  });
}
