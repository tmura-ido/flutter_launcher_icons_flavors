import 'dart:convert';
import 'dart:io';

/// Minimal `IOSink` that writes into a `StringBuffer`. Used as a test seam
/// for `FLILogger.stderrSinkForTesting`. Only `writeln` is exercised by
/// `FLILogger.warn`/`error`; the rest are minimal but functional.
class BufferedIOSink implements IOSink {
  /// Creates a [BufferedIOSink] that writes into [_buffer].
  BufferedIOSink(this._buffer);
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
