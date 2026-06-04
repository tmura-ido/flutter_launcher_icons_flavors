// Whole-suite test health report. Runs `dart test --reporter=json` over the
// ENTIRE suite (every *_test.dart file — not just test/permutations) and prints
// the status of every test file: pass / fail / skip counts per file, overall
// totals, and the name + one-line reason of each failing test.
//
// Companion to tool/failing_tests.dart: that one distills ONLY failures; this
// one shows every file so you can confirm the whole suite actually ran and see
// overall health at a glance. Per-file load/compile errors are surfaced too.
//
// Usage:
//   dart run tool/test_report.dart                 # whole suite, every file
//   dart run tool/test_report.dart -q              # only failing files + totals
//   dart run tool/test_report.dart test/cli        # scope to a path
//   dart run tool/test_report.dart test/all_tests.dart
// Forwards any non-(-q/--quiet) arg to `dart test`. Exit 0 if all pass else 1.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var quiet = false;
  final passthrough = <String>[];
  for (final a in args) {
    if (a == '-q' || a == '--quiet') {
      quiet = true;
    } else {
      passthrough.add(a);
    }
  }
  final testArgs = <String>['test', '--reporter=json', ...passthrough];
  stderr.writeln('\$ dart ${testArgs.join(' ')}\n');
  final proc = await Process.start(Platform.resolvedExecutable, testArgs);

  final suitePaths = <int, String>{}; // suiteId -> path
  final testSuite = <int, int>{}; // testId -> suiteId
  final testNames = <int, String>{}; // testId -> name
  final errorOf = <int, String>{}; // testId -> distilled first error line
  final failNames = <int, List<int>>{}; // suiteId -> failing testIds
  final passCount = <int, int>{}; // suiteId -> #passed
  final failCount = <int, int>{}; // suiteId -> #failed
  final skipCount = <int, int>{}; // suiteId -> #skipped
  final loadError = <int>{}; // suiteIds with a load/compile/setUp error

  final stderrBuf = StringBuffer();
  proc.stderr.transform(utf8.decoder).listen(stderrBuf.write);

  final stream = proc.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter());
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
        final id = s['id'] as int;
        suitePaths[id] = (s['path'] as String?) ?? '<unknown>';
        passCount.putIfAbsent(id, () => 0);
        failCount.putIfAbsent(id, () => 0);
        skipCount.putIfAbsent(id, () => 0);
      case 'testStart':
        final t = e['test'] as Map<String, dynamic>;
        final id = t['id'] as int;
        testNames[id] = (t['name'] as String?)?.trim() ?? '<unnamed>';
        final sid = t['suiteID'];
        if (sid is int) testSuite[id] = sid;
      case 'error':
        final id = e['testID'] as int?;
        if (id == null) break;
        errorOf[id] ??= _distill((e['error'] as String?) ?? '');
      case 'testDone':
        final id = e['testID'] as int?;
        if (id == null) break;
        final sid = testSuite[id];
        if (e['hidden'] == true) {
          // A hidden "loading ..." / setUpAll test that fails means the whole
          // file could not load/compile (or a fixture blew up).
          if (e['result'] != 'success' && sid != null) loadError.add(sid);
          break;
        }
        if (sid == null) break;
        if (e['skipped'] == true) {
          skipCount[sid] = (skipCount[sid] ?? 0) + 1;
        } else if (e['result'] == 'success') {
          passCount[sid] = (passCount[sid] ?? 0) + 1;
        } else {
          failCount[sid] = (failCount[sid] ?? 0) + 1;
          (failNames[sid] ??= []).add(id);
        }
    }
  }
  final runnerExit = await proc.exitCode;

  bool isBad(int id) => (failCount[id] ?? 0) > 0 || loadError.contains(id);

  final ids = suitePaths.keys.toList();
  var totalPass = 0, totalFail = 0, totalSkip = 0, filesWithFail = 0;
  for (final id in ids) {
    totalPass += passCount[id] ?? 0;
    totalFail += failCount[id] ?? 0;
    totalSkip += skipCount[id] ?? 0;
    if (isBad(id)) filesWithFail++;
  }

  // Display order: failing files first, then alphabetical by path.
  final display = ids.toList()
    ..sort((a, b) {
      final ba = isBad(a), bb = isBad(b);
      if (ba != bb) return ba ? -1 : 1;
      return suitePaths[a]!.compareTo(suitePaths[b]!);
    });

  String row(int id) {
    final p = passCount[id] ?? 0;
    final f = failCount[id] ?? 0;
    final s = skipCount[id] ?? 0;
    final mark = isBad(id) ? '✕' : '✓';
    final parts = <String>[];
    if (loadError.contains(id)) parts.add('LOAD ERROR');
    if (p > 0) parts.add('$p passed');
    if (f > 0) parts.add('$f failed');
    if (s > 0) parts.add('$s skipped');
    if (parts.isEmpty) parts.add('no tests');
    return '  $mark ${suitePaths[id]}  —  ${parts.join(', ')}';
  }

  for (final id in display) {
    if (quiet && !isBad(id)) continue;
    stdout.writeln(row(id));
  }

  final ok = totalFail == 0 && loadError.isEmpty;
  stdout.writeln(
    '\n${ok ? '✓' : '✕'} $totalPass passing, $totalFail failing'
    '${totalSkip > 0 ? ', $totalSkip skipped' : ''} '
    'across ${ids.length} files'
    '${filesWithFail > 0 ? ' ($filesWithFail with failures)' : ''}.',
  );

  final bad = display.where(isBad).toList();
  if (bad.isNotEmpty) {
    stdout.writeln('\nFailing tests:');
    for (final id in bad) {
      stdout.writeln('  ${suitePaths[id]}');
      if (loadError.contains(id)) {
        stdout.writeln('     ↳ failed to load/compile or a fixture threw');
      }
      for (final tid in failNames[id] ?? const <int>[]) {
        stdout.writeln('     - ${testNames[tid] ?? '<unnamed>'}');
        final reason = errorOf[tid] ?? '';
        if (reason.isNotEmpty) stdout.writeln('         ↳ $reason');
      }
    }
  }

  if (runnerExit != 0 && ok) {
    stdout.writeln(
      '\n⚠ test runner exited $runnerExit with no per-test failures '
      '(likely a load/compile error):',
    );
    if (stderrBuf.isNotEmpty) stderr.write(stderrBuf);
  }

  exit(ok && runnerExit == 0 ? 0 : 1);
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
