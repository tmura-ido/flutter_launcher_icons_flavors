import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #552.
/// See: issues/approved/issue-552-printstatus-bypasses-logger.md
///
/// Library consumers need a quiet `FLILogger` for embedded use; export and
/// verify a `NoopLogger` whose methods are silent.
void main() {
  group('issue #552: NoopLogger is a silent FLILogger', () {
    test('NoopLogger is a FLILogger', () {
      expect(NoopLogger(), isA<FLILogger>());
    });

    test('all logger methods are silent (do not throw)', () {
      final logger = NoopLogger();
      expect(() => logger.info('hi'), returnsNormally);
      expect(() => logger.warn('hi'), returnsNormally);
      expect(() => logger.error('hi'), returnsNormally);
      expect(() => logger.verbose('hi'), returnsNormally);
      final p = logger.progress('working');
      expect(() => p.finish(), returnsNormally);
      expect(() => p.cancel(), returnsNormally);
    });
  });
}
