import 'dart:convert';
import 'dart:io';

import 'package:flutter_launcher_icons_flavored/android.dart' as android;
import 'package:flutter_launcher_icons_flavored/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Tests for [android.findAndroidGradleFile] and [android.minSdk] across the
/// fixture matrix described in plan/phase-2 §4.1–§4.2.
void main() {
  final fixturesRoot = path.join('test', 'fixtures', 'gradle');

  group('findAndroidGradleFile()', () {
    test('returns null when neither .gradle nor .gradle.kts exists', () async {
      final tempDir = Directory.systemTemp.createTempSync('fli_no_gradle_');
      try {
        final result = await android.findAndroidGradleFile(tempDir.path);
        expect(result, isNull);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('prefers .kts when both .kts and .gradle are present', () async {
      final fixture = path.join(fixturesRoot, 'both_kts_and_groovy');
      final result = await android.findAndroidGradleFile(fixture);
      expect(result, isNotNull);
      expect(result!.path, endsWith('.kts'));
    });
  });

  group('minSdk() — parameterized fixtures', () {
    final cases = <_MinSdkCase>[
      _MinSdkCase('groovy_basic', expected: 21),
      _MinSdkCase('groovy_with_eq', expected: 23),
      _MinSdkCase('kts_basic', expected: 24),
      _MinSdkCase('kts_call_form', expected: 26),
      // both present → KTS wins; KTS file says minSdk = 24.
      _MinSdkCase('both_kts_and_groovy', expected: 24),
    ];

    for (final c in cases) {
      test('${c.name} → ${c.expected}', () async {
        final fixturePath = path.join(fixturesRoot, c.name);
        final result = await android.minSdk(prefixPath: fixturePath);
        expect(result, equals(c.expected));
      });
    }
  });

  group('minSdk() — flutter.minSdkVersion indirection', () {
    test(
      'kts_with_flutter_ref → recurses into Flutter SDK gradle.kts (21)',
      () async {
        // The fixture's local.properties contains a placeholder
        // `__FLUTTER_SDK__` for the flutter.sdk path. We rewrite it to an
        // absolute path at test time so the recursion into
        // flutter_sdk/packages/flutter_tools/gradle/flutter.gradle.kts
        // resolves on any CI machine.
        final fixturePath = path.join(fixturesRoot, 'kts_with_flutter_ref');
        final flutterSdkAbs = path.absolute(
          path.join(fixturePath, 'flutter_sdk'),
        );
        final localProps = File(
          path.join(fixturePath, 'android', 'local.properties'),
        );
        final original = await localProps.readAsString();
        try {
          await localProps.writeAsString(
            original.replaceAll('__FLUTTER_SDK__', flutterSdkAbs),
          );
          final result = await android.minSdk(prefixPath: fixturePath);
          expect(result, equals(21));
        } finally {
          // Restore so the fixture file stays portable.
          await localProps.writeAsString(original);
        }
      },
    );

    test('kts_with_flutter_ref_localprops → falls back to '
        'flutter.minSdkVersion=21 in local.properties', () async {
      final fixturePath = path.join(
        fixturesRoot,
        'kts_with_flutter_ref_localprops',
      );
      final result = await android.minSdk(prefixPath: fixturePath);
      expect(result, equals(21));
    });
  });

  group('minSdk() — graceful failure', () {
    test('kts_with_version_catalog → returns null', () async {
      final fixturePath = path.join(fixturesRoot, 'kts_with_version_catalog');
      final result = await android.minSdk(prefixPath: fixturePath);
      expect(result, isNull);
    });

    test('convention_plugin → returns null', () async {
      final fixturePath = path.join(fixturesRoot, 'convention_plugin');
      final result = await android.minSdk(prefixPath: fixturePath);
      expect(result, isNull);
    });

    test('missing both gradle files and local.properties → null', () async {
      final tempDir = Directory.systemTemp.createTempSync('fli_no_gradle_');
      try {
        final result = await android.minSdk(prefixPath: tempDir.path);
        expect(result, isNull);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('resolveMinSdkAndroid() — warning emission on full fallback', () {
    // Reviewer follow-up: when both explicit user value AND gradle autodetect
    // fail, the static default (24) is used AND `errorMissingMinSdk` MUST be
    // surfaced via the logger so the user knows autodetection silently
    // failed. We assert this by injecting an in-memory IOSink into FLILogger
    // via the `stderrSinkForTesting` test seam — see lib/logger.dart.

    test('version-catalog fixture → warns with errorMissingMinSdk', () async {
      final fixturePath = path.join(
        path.join('test', 'fixtures', 'gradle'),
        'kts_with_version_catalog',
      );
      final buffer = StringBuffer();
      final logger = FLILogger(
        false,
        stderrSinkForTesting: _BufferedIOSink(buffer),
      );
      final resolved = await android.resolveMinSdkAndroid(
        prefixPath: fixturePath,
        logger: logger,
        explicit: null,
      );
      expect(resolved, equals(constants.androidDefaultAndroidMinSDK));
      expect(
        buffer.toString(),
        contains(constants.errorMissingMinSdk),
        reason:
            'Full-fallback path must emit errorMissingMinSdk via the logger '
            '(captured stderr was: $buffer)',
      );
    });

    test('convention-plugin fixture → warns with errorMissingMinSdk', () async {
      final fixturePath = path.join(
        path.join('test', 'fixtures', 'gradle'),
        'convention_plugin',
      );
      final buffer = StringBuffer();
      final logger = FLILogger(
        false,
        stderrSinkForTesting: _BufferedIOSink(buffer),
      );
      final resolved = await android.resolveMinSdkAndroid(
        prefixPath: fixturePath,
        logger: logger,
        explicit: null,
      );
      expect(resolved, equals(constants.androidDefaultAndroidMinSDK));
      expect(buffer.toString(), contains(constants.errorMissingMinSdk));
    });

    test(
      'explicit user value provided → no errorMissingMinSdk warning emitted',
      () async {
        // Sanity: when the user supplied a value, autodetect is skipped and
        // no warning should fire even if gradle would have failed.
        final fixturePath = path.join(
          path.join('test', 'fixtures', 'gradle'),
          'kts_with_version_catalog',
        );
        final buffer = StringBuffer();
        final logger = FLILogger(
          false,
          stderrSinkForTesting: _BufferedIOSink(buffer),
        );
        await android.resolveMinSdkAndroid(
          prefixPath: fixturePath,
          logger: logger,
          explicit: 21,
        );
        expect(
          buffer.toString(),
          isNot(contains(constants.errorMissingMinSdk)),
        );
      },
    );
  });
}

/// Minimal `IOSink` that writes into a `StringBuffer`. Used as a test seam
/// for `FLILogger.stderrSinkForTesting`. Only the methods FLILogger's
/// `warn`/`error` actually invoke (`writeln`) need to be meaningful; the
/// rest are no-ops sufficient for these tests.
class _BufferedIOSink implements IOSink {
  _BufferedIOSink(this._buffer);
  final StringBuffer _buffer;

  @override
  Encoding encoding = utf8;

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    var first = true;
    for (final o in objects) {
      if (!first) {
        _buffer.write(separator);
      }
      _buffer.write(o);
      first = false;
    }
  }

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void add(List<int> data) => _buffer.write(utf8.decode(data));

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

class _MinSdkCase {
  _MinSdkCase(this.name, {required this.expected});
  final String name;
  final int expected;
}
