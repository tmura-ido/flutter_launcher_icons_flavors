// Distilled failing-test reporter. Runs `dart test --reporter=json`, prints
// ONLY failing tests grouped by file with a one/two-line reason.
// Usage:
//   dart run tool/failing_tests.dart                 # whole suite
//   dart run tool/failing_tests.dart test/permutations
//   dart run tool/failing_tests.dart --full          # include full stack traces
// Forwards any non-(--full/-f) arg to `dart test`. Exit 0 if all pass else 1.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var full = false;
  final passthrough = <String>[];
  for (final a in args) {
    if (a == '--full' || a == '-f') {
      full = true;
    } else {
      passthrough.add(a);
    }
  }
  final testArgs = <String>['test', '--reporter=json', ...passthrough];
  stderr.writeln('\$ dart ${testArgs.join(' ')}\n');
  final proc = await Process.start(Platform.resolvedExecutable, testArgs);
  final suitePaths = <int, String>{};
  final testNames = <int, String>{};
  final testSuite = <int, int>{};
  final firstLines = <int, String>{};
  final fullErrors = <int, String>{};
  var passed = 0;
  var skipped = 0;
  final failed = <int>[];
  final stderrBuf = StringBuffer();
  proc.stderr.transform(utf8.decoder).listen(stderrBuf.write);
  final stream =
      proc.stdout.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in stream) {
    if (line.isEmpty || line.codeUnitAt(0) != 0x7B /* { */ ) continue;
    final Map<String, dynamic> e;
    try {
      e = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
    switch (e['type']) {
      case 'suite':
        final s = e['suite'] as Map<String, dynamic>;
        suitePaths[s['id'] as int] = (s['path'] as String?) ?? '<unknown>';
      case 'testStart':
        final t = e['test'] as Map<String, dynamic>;
        final id = t['id'] as int;
        testNames[id] = (t['name'] as String?)?.trim() ?? '<unnamed>';
        final sid = t['suiteID'];
        if (sid is int) testSuite[id] = sid;
      case 'error':
        final id = e['testID'] as int?;
        if (id == null) break;
        final msg = (e['error'] as String?) ?? '';
        final st = (e['stackTrace'] as String?) ?? '';
        firstLines[id] ??= _distill(msg);
        fullErrors[id] ??= st.isEmpty ? msg : '$msg\n$st';
      case 'testDone':
        final id = e['testID'] as int?;
        if (id == null) break;
        if (e['hidden'] == true) break;
        if (e['skipped'] == true) {
          skipped++;
        } else if (e['result'] == 'success') {
          passed++;
        } else {
          failed.add(id);
        }
    }
  }
  final runnerExit = await proc.exitCode;
  if (failed.isEmpty) {
    final extra = skipped > 0 ? ', $skipped skipped' : '';
    stdout.writeln('✓ All tests passed ($passed passing$extra).');
    if (runnerExit != 0) {
      stdout.writeln(
        '\n⚠ test runner exited $runnerExit with no per-test failures '
        '(likely a load/compile error):',
      );
      if (stderrBuf.isNotEmpty) stderr.write(stderrBuf);
    }
    exit(runnerExit == 0 ? 0 : 1);
  }
  failed.sort((a, b) {
    final pa = suitePaths[testSuite[a]] ?? '';
    final pb = suitePaths[testSuite[b]] ?? '';
    final byPath = pa.compareTo(pb);
    return byPath != 0 ? byPath : a.compareTo(b);
  });
  stdout.writeln('✕ ${failed.length} FAILING:\n');
  var n = 0;
  String? currentSuite;
  for (final id in failed) {
    final path = suitePaths[testSuite[id]] ?? '<unknown>';
    if (path != currentSuite) {
      currentSuite = path;
      stdout.writeln(path);
    }
    n++;
    stdout.writeln('  ${'$n'.padLeft(3)}. ${testNames[id] ?? '<unnamed>'}');
    if (full) {
      for (final l in (fullErrors[id] ?? '').split('\n')) {
        stdout.writeln('       $l');
      }
    } else {
      final reason = firstLines[id] ?? '';
      if (reason.isNotEmpty) stdout.writeln('       ↳ $reason');
    }
  }
  final extra = skipped > 0 ? ', $skipped skipped' : '';
  stdout.writeln('\n$passed passing, ${failed.length} failing$extra.');
  exit(1);
}

String _distill(String error) {
  final lines = error
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .take(2)
      .map((l) => _cap(l.trim(), 160))
      .toList();
  return lines.join('  ·  ');
}

String _cap(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';
