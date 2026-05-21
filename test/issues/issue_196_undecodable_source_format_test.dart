import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #196.
/// See: issues/issue-196-width-null-on-ico-input.md
///
/// Pointing `image_path` at a file the `image` package cannot decode
/// (e.g. an `.ico`, or any file with the wrong magic bytes) used to
/// crash with `NoSuchMethodError: The getter 'width' was called on
/// null`. The fork should surface a clean
/// [NoDecoderForImageFormatException] instead.
void main() {
  group('issue #196: undecodable source produces a typed error', () {
    test(
      'decoding a non-image file throws NoDecoderForImageFormatException',
      () async {
        await d.file(
          'fake.ico',
          'not actually a valid .ico — just garbage bytes',
        ).create();
        final p = path.join(d.sandbox, 'fake.ico');
        expect(
          utils.decodeImageFile(p),
          throwsA(isA<NoDecoderForImageFormatException>()),
          reason: 'should not produce a null-receiver NoSuchMethodError',
        );
      },
    );

    test(
      'NoDecoderForImageFormatException error message includes the path',
      () async {
        await d.file('mystery.bin', 'garbage').create();
        final p = path.join(d.sandbox, 'mystery.bin');
        try {
          await utils.decodeImageFile(p);
          fail('expected NoDecoderForImageFormatException');
        } on NoDecoderForImageFormatException catch (e) {
          expect(e.toString(), contains('mystery.bin'));
        }
      },
    );
  });
}
