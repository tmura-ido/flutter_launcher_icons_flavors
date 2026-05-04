import 'dart:io';

import 'package:cli_util/cli_logging.dart';

export 'package:cli_util/cli_logging.dart' show Progress;

/// Whether the environment requests no ANSI color codes.
///
/// See https://no-color.org/.
bool get _noColorEnv {
  final v = Platform.environment['NO_COLOR'];
  return v != null && v.isNotEmpty;
}

/// Flutter Launcher Icons Logger.
///
/// Wraps `package:cli_util` `Logger` with leveled methods. Honors the
/// `NO_COLOR` environment variable.
class FLILogger {
  /// Returns true if this is a verbose logger.
  final bool isVerbose;

  /// Optional override sink for `error`/`warn` output. When non-null, those
  /// methods write here instead of going through `cli_util`'s `Logger.stderr`.
  /// This exists exclusively as a test seam so unit tests can assert that a
  /// specific warning was emitted (cli_util's `Logger.standard()` writes to
  /// the real `io.stderr` and is not redirectable via `IOOverrides` since
  /// `IOOverrides.stderr` requires a `Stdout` return type).
  ///
  /// Production callers MUST leave this null.
  final IOSink? stderrSinkForTesting;

  late final Logger _logger;

  /// Gives access to internal logger.
  Logger get rawLogger => _logger;

  /// Creates an instance of [FLILogger].
  ///
  /// In case [isVerbose] is `true`, it logs all the [verbose] logs to console.
  ///
  /// [stderrSinkForTesting] is a test-only seam; production callers should
  /// leave it null.
  FLILogger(this.isVerbose, {this.stderrSinkForTesting}) {
    final ansi = Ansi(!_noColorEnv && Ansi.terminalSupportsAnsi);
    _logger = isVerbose
        ? Logger.verbose(ansi: ansi)
        : Logger.standard(ansi: ansi);
  }

  /// Logs an error message to stderr, prefixed with `✕ ERROR`.
  void error(Object? message) {
    final formatted = '✕ ERROR ${_safeString(message)}';
    if (stderrSinkForTesting != null) {
      stderrSinkForTesting!.writeln(formatted);
    } else {
      _logger.stderr(formatted);
    }
  }

  /// Logs a warning to stderr, prefixed with `⚠ WARNING`.
  void warn(Object? message) {
    final formatted = '⚠ WARNING ${_safeString(message)}';
    if (stderrSinkForTesting != null) {
      stderrSinkForTesting!.writeln(formatted);
    } else {
      _logger.stderr(formatted);
    }
  }

  /// Logs an informational message to stdout.
  void info(Object? message) => _logger.stdout(_safeString(message));

  /// Prints to console only when [isVerbose] is true.
  void verbose(Object? message) => _logger.trace(_safeString(message));

  /// Shows progress in console.
  Progress progress(String message) => _logger.progress(message);

  /// Emits a one-shot legacy/deprecation warning to stderr.
  ///
  /// Used by code paths that don't have a [FLILogger] instance available
  /// (e.g. static constructors). Honors `NO_COLOR`.
  static void legacyWarning(String message) {
    stderr.writeln('⚠ WARNING $message');
  }

  static String _safeString(Object? message) =>
      message == null ? '' : message.toString();
}
