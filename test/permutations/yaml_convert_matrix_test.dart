// Coverage for the YAML→plain boundary converter (lib/utils/yaml_convert.dart),
// the function every config loader funnels `package:yaml` output through before
// handing it to deepMerge / PartialConfig.fromJson. Previously only exercised
// transitively; these tests pin its contract directly.
import 'package:flutter_launcher_icons_flavors/utils/yaml_convert.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('yamlToPlainMap', () {
    test('null input → null', () {
      expect(yamlToPlainMap(null), isNull);
    });

    test('non-map scalar → null', () {
      expect(yamlToPlainMap(42), isNull);
    });

    test('non-map list → null', () {
      expect(yamlToPlainMap([1, 2]), isNull);
    });

    test('YamlMap → plain Map<String, dynamic> with String keys', () {
      final plain = yamlToPlainMap(loadYaml('a: 1\nb: two\nc: true'));
      expect(plain, {'a': 1, 'b': 'two', 'c': true});
      expect(plain, isA<Map<String, dynamic>>());
    });

    test('nested YamlMap is recursively flattened', () {
      final plain = yamlToPlainMap(
        loadYaml('web:\n  generate: true\n  image_path: i.png'),
      )!;
      expect(plain['web'], isA<Map<String, dynamic>>());
      expect(plain['web'], {'generate': true, 'image_path': 'i.png'});
    });

    test('YamlList becomes a plain List', () {
      final plain = yamlToPlainMap(loadYaml('sizes:\n  - 16\n  - 32'))!;
      expect(plain['sizes'], isA<List<dynamic>>());
      expect(plain['sizes'], [16, 32]);
    });

    test('non-String keys are stringified', () {
      final plain = yamlToPlainMap(loadYaml('1: one\n2: two'))!;
      expect(plain.keys.toSet(), {'1', '2'});
      expect(plain['1'], 'one');
    });

    test('explicit null value passes through', () {
      final plain = yamlToPlainMap(loadYaml('a: 1\nb:'))!;
      expect(plain.containsKey('b'), isTrue);
      expect(plain['b'], isNull);
    });
  });

  group('yamlToPlainValue', () {
    test('scalars pass through unchanged', () {
      expect(yamlToPlainValue(5), 5);
      expect(yamlToPlainValue('x'), 'x');
      expect(yamlToPlainValue(true), isTrue);
      expect(yamlToPlainValue(null), isNull);
    });

    test('deeply nested map → list → map is fully converted', () {
      final plain = yamlToPlainMap(loadYaml('root:\n  - name: a\n  - name: b'))!;
      expect(plain['root'], [
        {'name': 'a'},
        {'name': 'b'},
      ]);
      expect((plain['root'] as List).first, isA<Map<String, dynamic>>());
    });
  });
}
