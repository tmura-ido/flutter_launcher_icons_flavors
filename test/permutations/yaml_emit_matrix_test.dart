// Coverage for the hand-rolled YAML emitter used by `migrate` (lib/cli/
// yaml_emit.dart) — previously exercised only indirectly through the migrate
// command. The headline test is a round-trip property: anything emitYaml
// writes must parse back (via the real YAML parser) to the exact input tree.
// That single property guards key sorting, string quoting, null/empty
// handling, nesting, and list emission all at once.
import 'package:flutter_launcher_icons_flavors/cli/yaml_emit.dart';
import 'package:flutter_launcher_icons_flavors/utils/yaml_convert.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('emitYaml — scalar / structural encoding', () {
    test('keys are emitted alphabetically within a block', () {
      final out = emitYaml({'b': 1, 'a': 2, 'c': 3});
      expect(out.indexOf('a:') < out.indexOf('b:'), isTrue);
      expect(out.indexOf('b:') < out.indexOf('c:'), isTrue);
    });

    test('strings are double-quoted', () {
      expect(emitYaml({'k': 'v'}), contains('k: "v"'));
    });

    test('a string that looks like a bool/number stays quoted', () {
      expect(emitYaml({'k': 'true'}), contains('k: "true"'));
      expect(emitYaml({'k': '123'}), contains('k: "123"'));
    });

    test('bools are unquoted true/false', () {
      expect(emitYaml({'k': true}), contains('k: true'));
      expect(emitYaml({'k': false}), contains('k: false'));
    });

    test('ints render as decimal literals', () {
      expect(emitYaml({'k': 42}), contains('k: 42'));
    });

    test('null collapses to a bare key', () {
      expect(emitYaml({'k': null}), contains('k:\n'));
    });

    test('empty map renders {} and empty list renders []', () {
      expect(emitYaml({'k': <String, dynamic>{}}), contains('k: {}'));
      expect(emitYaml({'k': <dynamic>[]}), contains('k: []'));
    });

    test('backslash and double-quote are escaped inside strings', () {
      expect(emitYaml({'k': r'a\b"c'}), contains(r'k: "a\\b\"c"'));
    });

    test('document ends with exactly one trailing newline', () {
      final out = emitYaml({'a': 1});
      expect(out.endsWith('\n'), isTrue);
      expect(out.endsWith('\n\n'), isFalse);
    });
  });

  group('emitYaml round-trips through the real YAML parser', () {
    final fixtures = <String, Map<String, dynamic>>{
      'flat scalars': {
        'version': 1,
        'name': 'demo',
        'enabled': true,
        'note': null,
      },
      'consolidated-config shape': {
        'version': 1,
        'defaults': {'android': true, 'image_path': 'i.png'},
        'flavors': {
          'dev': {'ios': true},
          'prod': {'android': 'ic_prod'},
        },
      },
      'strings that look like other types stay strings': {
        'a': 'true',
        'b': '123',
        'c': 'yes',
        'd': 'null',
      },
      'list of scalars': {
        'sizes': [16, 32, 48],
      },
      'list of maps': {
        'items': [
          {'name': 'a', 'size': 1},
          {'name': 'b', 'size': 2},
        ],
      },
      'empty containers': {'m': <String, dynamic>{}, 'l': <dynamic>[]},
    };
    for (final entry in fixtures.entries) {
      test(entry.key, () {
        final yaml = emitYaml(entry.value);
        final parsed = yamlToPlainMap(loadYaml(yaml));
        expect(parsed, entry.value);
      });
    }
  });
}
