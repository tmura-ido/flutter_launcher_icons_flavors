// Tests for the interactive squish-confirmation prompt added for #214.
//
// The pre-flight pass detects non-square sources whose platform writer
// would silently squish them onto an N×N canvas, then asks the user once
// to approve. Non-interactive shells auto-approve to preserve legacy
// behavior; `--yes` (autoYes: true) skips the prompt; `non_square_image_ok`
// pre-approves at the config level (filtered out at find time).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_launcher_icons_flavors/cli/squish_prompt.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

List<int> _redPng(int w, int h) {
  final src = Image(width: w, height: h);
  for (final px in src) {
    px.setRgba(255, 0, 0, 0xff);
  }
  return encodePng(src);
}

/// Captures everything written to it as a single string for assertions.
class _CapturingSink implements IOSink {
  final StringBuffer buffer = StringBuffer();
  @override
  Encoding encoding = utf8;
  String get text => buffer.toString();

  @override
  void write(Object? o) => buffer.write(o);
  @override
  void writeln([Object? o = '']) => buffer.writeln(o);
  @override
  void writeAll(Iterable objects, [String sep = '']) =>
      buffer.writeAll(objects, sep);
  @override
  void writeCharCode(int c) => buffer.writeCharCode(c);
  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  Future close() async {}
  @override
  Future flush() async {}
  @override
  Future get done => Future.value();
}

void main() {
  group('findSquishCandidates', () {
    test('returns empty when nonSquareImageOk is true', () async {
      await d.dir('sq_ok', [
        d.file('icon.png', _redPng(200, 100)),
      ]).create();
      final cfg = Config.fromJson({
        'image_path': 'icon.png',
        'android': true,
        'non_square_image_ok': true,
      });
      final candidates = await findSquishCandidates(
        config: cfg,
        prefixPath: p.join(d.sandbox, 'sq_ok'),
      );
      expect(candidates, isEmpty);
    });

    test('returns empty when source is square (no squish needed)', () async {
      await d.dir('sq_square', [
        d.file('icon.png', _redPng(128, 128)),
      ]).create();
      final cfg = Config.fromJson({
        'image_path': 'icon.png',
        'android': true,
      });
      final candidates = await findSquishCandidates(
        config: cfg,
        prefixPath: p.join(d.sandbox, 'sq_square'),
      );
      expect(candidates, isEmpty);
    });

    test('flags Android mipmap when source is non-square and no bg', () async {
      await d.dir('sq_android', [
        d.file('icon.png', _redPng(200, 100)),
      ]).create();
      final cfg = Config.fromJson({
        'image_path': 'icon.png',
        'android': true,
      });
      final candidates = await findSquishCandidates(
        config: cfg,
        prefixPath: p.join(d.sandbox, 'sq_android'),
      );
      expect(candidates, hasLength(1));
      expect(candidates.first.platform, 'Android mipmap');
      expect(candidates.first.width, 200);
      expect(candidates.first.height, 100);
    });

    test('returns empty when top-level background_color is set', () async {
      await d.dir('sq_topbg', [
        d.file('icon.png', _redPng(200, 100)),
      ]).create();
      final cfg = Config.fromJson({
        'image_path': 'icon.png',
        'android': true,
        'background_color': '#0175C2',
      });
      final candidates = await findSquishCandidates(
        config: cfg,
        prefixPath: p.join(d.sandbox, 'sq_topbg'),
      );
      expect(candidates, isEmpty);
    });

    test('flags Web when neither web nor top-level bg is set', () async {
      await d.dir('sq_web', [
        d.file('icon.png', _redPng(200, 100)),
      ]).create();
      final cfg = Config.fromJson({
        'image_path': 'icon.png',
        'web': {'generate': true, 'image_path': 'icon.png'},
      });
      final candidates = await findSquishCandidates(
        config: cfg,
        prefixPath: p.join(d.sandbox, 'sq_web'),
      );
      expect(candidates.map((c) => c.platform), contains('Web'));
    });

    test(
      'flags adaptive foreground when adaptive_icon_background is a PNG path',
      () async {
        await d.dir('sq_adapt', [
          d.file('icon.png', _redPng(200, 100)),
          d.file('fg.png', _redPng(200, 100)),
          d.file('bg.png', _redPng(100, 100)),
        ]).create();
        final cfg = Config.fromJson({
          'image_path': 'icon.png',
          'android': true,
          'adaptive_icon_foreground': 'fg.png',
          'adaptive_icon_background': 'bg.png',
        });
        final candidates = await findSquishCandidates(
          config: cfg,
          prefixPath: p.join(d.sandbox, 'sq_adapt'),
        );
        expect(
          candidates.map((c) => c.platform),
          contains('Android adaptive foreground'),
        );
      },
    );

    test(
      'flags Windows / macOS / Linux which have no bg color in schema',
      () async {
        await d.dir('sq_desk', [
          d.file('icon.png', _redPng(200, 100)),
        ]).create();
        final cfg = Config.fromJson({
          'image_path': 'icon.png',
          'windows': {'generate': true, 'image_path': 'icon.png'},
          'macos': {'generate': true, 'image_path': 'icon.png'},
          'linux': {'generate': true, 'image_path': 'icon.png'},
        });
        final candidates = await findSquishCandidates(
          config: cfg,
          prefixPath: p.join(d.sandbox, 'sq_desk'),
        );
        expect(
          candidates.map((c) => c.platform),
          containsAll(<String>['Windows', 'macOS', 'Linux']),
        );
      },
    );
  });

  group('promptSquishApproval', () {
    test('noCandidates path returns immediately without writing', () async {
      final sink = _CapturingSink();
      final result = await promptSquishApproval(
        const [],
        autoYes: false,
        stdoutForTest: sink,
        hasTerminalForTest: true,
      );
      expect(result, SquishApproval.noCandidates);
      expect(sink.text, isEmpty);
    });

    test('autoYes short-circuits to approved without prompting', () async {
      final sink = _CapturingSink();
      final candidate = SquishCandidate(
        flavor: '',
        platform: 'Android mipmap',
        imagePath: '/tmp/icon.png',
        width: 200,
        height: 100,
      );
      final result = await promptSquishApproval(
        [candidate],
        autoYes: true,
        stdoutForTest: sink,
        hasTerminalForTest: true,
      );
      expect(result, SquishApproval.approved);
      // Nothing written — no prompt at all when autoYes.
      expect(sink.text, isEmpty);
    });

    test(
      'non-interactive (no TTY) auto-approves and writes a warning',
      () async {
        final sink = _CapturingSink();
        final candidate = SquishCandidate(
          flavor: '',
          platform: 'Android mipmap',
          imagePath: '/tmp/icon.png',
          width: 200,
          height: 100,
        );
        final result = await promptSquishApproval(
          [candidate],
          autoYes: false,
          stdoutForTest: sink,
          hasTerminalForTest: false,
        );
        expect(result, SquishApproval.approved);
        expect(sink.text, contains('Non-square source'));
        expect(sink.text, contains('Android mipmap'));
      },
    );

    test('candidate.toString includes flavor when present', () {
      final c = SquishCandidate(
        flavor: 'dev',
        platform: 'Web',
        imagePath: '/x/y.png',
        width: 200,
        height: 100,
      );
      expect(c.toString(), contains('[dev]'));
      expect(c.toString(), contains('Web'));
      expect(c.toString(), contains('200×100'));
    });
  });
}
