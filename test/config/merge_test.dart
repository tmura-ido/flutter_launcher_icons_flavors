import 'package:flutter_launcher_icons_flavors/config/merge.dart';
import 'package:test/test.dart';

void main() {
  group('deepMerge', () {
    test('empty base, populated override → override wins', () {
      final result = deepMerge({}, {'a': 1, 'b': 'x'});
      expect(result, {'a': 1, 'b': 'x'});
    });

    test('populated base, empty override → base preserved', () {
      final result = deepMerge({'a': 1, 'b': 'x'}, {});
      expect(result, {'a': 1, 'b': 'x'});
    });

    test('overlapping scalar → override wins', () {
      final result = deepMerge({'a': 1}, {'a': 2});
      expect(result, {'a': 2});
    });

    test('overlapping map → recursive merge (deep, not shallow)', () {
      final base = {
        'web': {'generate': true, 'image_path': 'a.png'},
      };
      final override = {
        'web': {'image_path': 'b.png'},
      };
      final result = deepMerge(base, override);
      expect(result, {
        'web': {'generate': true, 'image_path': 'b.png'},
      });
    });

    test('overlapping list → override list replaces wholesale', () {
      final base = {
        'sizes': [1, 2, 3],
      };
      final override = {
        'sizes': [9],
      };
      final result = deepMerge(base, override);
      expect(result, {
        'sizes': [9],
      });
    });

    test('explicit null in override → key removed from result', () {
      final result = deepMerge({'a': 1, 'b': 2}, {'b': null});
      expect(result, {'a': 1});
    });

    test('falsy override is honored (the classic shallow-merge bug)', () {
      final result = deepMerge({'android': true}, {'android': false});
      expect(result, {'android': false});
    });

    test('nested map deletion: web: null removes the whole map', () {
      final base = {
        'web': {'generate': true, 'image_path': 'x'},
      };
      final override = {'web': null};
      final result = deepMerge(base, override);
      expect(result, isEmpty);
    });

    test('adding a fresh key from override', () {
      final result = deepMerge({'a': 1}, {'b': 2});
      expect(result, {'a': 1, 'b': 2});
    });

    test('does not mutate inputs', () {
      final base = <String, dynamic>{
        'a': {'x': 1},
      };
      final override = <String, dynamic>{
        'a': {'y': 2},
      };
      final baseSnapshot = {
        'a': {'x': 1},
      };
      final overrideSnapshot = {
        'a': {'y': 2},
      };
      deepMerge(base, override);
      expect(base, baseSnapshot);
      expect(override, overrideSnapshot);
    });
  });
}
