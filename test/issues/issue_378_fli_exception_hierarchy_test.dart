import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #378.
/// See: issues/approved/issue-378-better-error-handling-fli-exception.md
///
/// Every fork-thrown exception should extend `FLIException` so callers can
/// `catch (FLIException e)` once and surface `e.info` consistently.
void main() {
  group('issue #378: every named exception is an FLIException', () {
    test('InvalidConfigException is an FLIException', () {
      const e = InvalidConfigException('bad');
      expect(e, isA<FLIException>());
      expect(e.info, 'bad');
    });

    test('InvalidAndroidIconNameException is an FLIException', () {
      const e = InvalidAndroidIconNameException('bad-name');
      expect(e, isA<FLIException>());
      expect(e.info, 'bad-name');
    });

    test('NoConfigFoundException is an FLIException', () {
      const e = NoConfigFoundException('nothing-here');
      expect(e, isA<FLIException>());
      expect(e.info, 'nothing-here');
    });

    test('NoDecoderForImageFormatException is an FLIException', () {
      const e = NoDecoderForImageFormatException('not-a-png');
      expect(e, isA<FLIException>());
      expect(e.info, 'not-a-png');
    });

    test('MixedConfigSourcesException is an FLIException', () {
      const e = MixedConfigSourcesException(['legacy.yaml']);
      expect(e, isA<FLIException>());
      expect(e.info, contains('legacy.yaml'));
    });

    test('UnknownFlavorException is an FLIException', () {
      const e = UnknownFlavorException('x', ['a', 'b']);
      expect(e, isA<FLIException>());
      expect(e.info, contains('x'));
      expect(e.info, contains('a'));
    });

    test('InvalidFlavorsFileException is an FLIException', () {
      const e = InvalidFlavorsFileException(
        'oops',
        path: 'f.yaml',
        flavor: 'dev',
        keyPath: 'flavors.dev.web',
      );
      expect(e, isA<FLIException>());
      expect(e.info, allOf(contains('oops'), contains('flavors.dev.web')));
    });

    test('caller can catch FLIException uniformly', () {
      void throwIt() => throw const InvalidConfigException('boom');
      FLIException? caught;
      try {
        throwIt();
      } on FLIException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.info, 'boom');
    });
  });
}
