import 'dart:io';

import 'package:flutter_launcher_icons_flavored/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavored/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('decodeImageFile', () {
    test('returns non-null Image for a valid PNG file', () async {
      // Generate a small valid PNG inside the sandbox so this test is
      // robust against other suites mutating Directory.current.
      final src = Image(width: 4, height: 4);
      await d.file('icon.png', encodePng(src)).create();
      final p = path.join(d.sandbox, 'icon.png');

      final image = await utils.decodeImageFile(p);
      expect(image, isA<Image>());
      expect(image.width, equals(4));
      expect(image.height, equals(4));
    });

    test(
      'throws NoDecoderForImageFormatException for unrecognized file',
      () async {
        await d.file('not_an_image.txt', 'this is not an image').create();
        final p = path.join(d.sandbox, 'not_an_image.txt');
        expect(
          utils.decodeImageFile(p),
          throwsA(isA<NoDecoderForImageFormatException>()),
        );
      },
    );

    test('throws FileSystemException for missing file', () async {
      final p = path.join(d.sandbox, 'does_not_exist.png');
      expect(utils.decodeImageFile(p), throwsA(isA<FileSystemException>()));
    });
  });
}
