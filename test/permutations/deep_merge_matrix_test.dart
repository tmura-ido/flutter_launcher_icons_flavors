// Permutation matrix over `deepMerge` (lib/config/merge.dart) — the function
// the consolidated loader uses to layer each flavor's overrides onto the shared
// `defaults:` block.
//
// The centerpiece is a value-KIND × value-KIND sweep for a single key `k`:
//
//   base     ∈ {absent, int, string, list, map}
//   override ∈ {absent, null, int, string, list, map}
//
// → 5 × 6 = 30 permutations. For each we assert `deepMerge` against an
// INDEPENDENT oracle (`_expected`) that encodes the documented rule set:
//
//   * override absent              → base value passes through unchanged
//   * override is explicit `null`  → key is DELETED (regardless of base)
//   * base map  +  override map    → recursive key-wise merge (override wins)
//   * anything else                → override REPLACES wholesale
//                                     (scalars, lists, and map-vs-non-map)
//
// Base- and override-side values are deliberately distinct (`1` vs `9`,
// `'base'` vs `'override'`, …) so a "replace" that should have happened — but
// didn't — is observable. Each permutation also re-checks that neither input
// map was mutated. A handful of targeted tests then pin deeper invariants:
// multi-level recursion, nested deletion, lists-of-maps replacing wholesale,
// and a combined survive/replace/delete/add merge.
import 'package:flutter_launcher_icons_flavors/config/merge.dart';
import 'package:test/test.dart';

/// The value shapes a single key can take across the two inputs.
enum _Kind { absent, nullV, intV, strV, listV, mapV }

/// Base-side value for [k]. Only the value-carrying kinds are used as a base.
Object _baseVal(_Kind k) => switch (k) {
  _Kind.intV => 1,
  _Kind.strV => 'base',
  _Kind.listV => [1, 2, 3],
  _Kind.mapV => {'shared': 'base', 'b_only': 1},
  _ => throw ArgumentError('no base value for $k'),
};

/// Override-side value for [k] — distinct from [_baseVal] so a replace shows.
Object _ovVal(_Kind k) => switch (k) {
  _Kind.intV => 9,
  _Kind.strV => 'override',
  _Kind.listV => [9],
  _Kind.mapV => {'shared': 'override', 'o_only': 2},
  _ => throw ArgumentError('no override value for $k'),
};

const _baseKinds = [_Kind.absent, _Kind.intV, _Kind.strV, _Kind.listV, _Kind.mapV];
const _overrideKinds = [
  _Kind.absent,
  _Kind.nullV,
  _Kind.intV,
  _Kind.strV,
  _Kind.listV,
  _Kind.mapV,
];

Map<String, dynamic> _buildBase(_Kind bk) =>
    bk == _Kind.absent ? <String, dynamic>{} : <String, dynamic>{'k': _baseVal(bk)};

Map<String, dynamic> _buildOverride(_Kind ok) => switch (ok) {
  _Kind.absent => <String, dynamic>{},
  _Kind.nullV => <String, dynamic>{'k': null},
  _ => <String, dynamic>{'k': _ovVal(ok)},
};

/// Independent oracle for `deepMerge(base, override)` on the single key `k`.
Map<String, dynamic> _expected(_Kind bk, _Kind ok) {
  // Override does not mention `k` → base passes through unchanged.
  if (ok == _Kind.absent) {
    return bk == _Kind.absent ? {} : {'k': _baseVal(bk)};
  }
  // Explicit null deletes the key, whatever the base held.
  if (ok == _Kind.nullV) return {};
  // Two maps merge recursively (single level here → override wins per key,
  // base-only keys survive).
  if (bk == _Kind.mapV && ok == _Kind.mapV) {
    return {
      'k': {'shared': 'override', 'b_only': 1, 'o_only': 2},
    };
  }
  // Scalars, lists, and any map-vs-non-map mismatch: override replaces.
  return {'k': _ovVal(ok)};
}

void main() {
  group('deepMerge value-kind matrix (single key, 30 permutations)', () {
    for (final bk in _baseKinds) {
      for (final ok in _overrideKinds) {
        test('base=${bk.name} override=${ok.name}', () {
          final base = _buildBase(bk);
          final override = _buildOverride(ok);
          // Snapshots to detect input mutation (deepMerge must clone, never
          // alias or mutate its arguments).
          final baseSnapshot = _buildBase(bk);
          final overrideSnapshot = _buildOverride(ok);

          final result = deepMerge(base, override);

          expect(
            result,
            _expected(bk, ok),
            reason: 'base=${bk.name} override=${ok.name}',
          );
          expect(base, baseSnapshot, reason: 'deepMerge mutated its base input');
          expect(
            override,
            overrideSnapshot,
            reason: 'deepMerge mutated its override input',
          );
        });
      }
    }
  });

  group('deepMerge deep-structure invariants', () {
    test('recursion descends every level (3 deep), base-only keys survive', () {
      final result = deepMerge(
        {
          'a': {
            'b': {'c': 1, 'keep': true},
          },
        },
        {
          'a': {
            'b': {'c': 2},
          },
        },
      );
      expect(result, {
        'a': {
          'b': {'c': 2, 'keep': true},
        },
      });
    });

    test('explicit null deletes a key INSIDE a nested map', () {
      final result = deepMerge(
        {
          'web': {'generate': true, 'image_path': 'x.png'},
        },
        {
          'web': {'image_path': null},
        },
      );
      expect(result, {
        'web': {'generate': true},
      });
    });

    test('a list of maps is replaced wholesale, not merged element-wise', () {
      final result = deepMerge(
        {
          'icons': [
            {'x': 1},
          ],
        },
        {
          'icons': [
            {'y': 2},
          ],
        },
      );
      expect(result, {
        'icons': [
          {'y': 2},
        ],
      });
    });

    test('combined merge: survive + replace + delete + add + nested-merge', () {
      final result = deepMerge(
        {
          'a': 1,
          'b': 2,
          'c': 3,
          'nested': {'x': 1},
        },
        {
          'b': 20,
          'c': null,
          'd': 4,
          'nested': {'y': 2},
        },
      );
      expect(result, {
        'a': 1,
        'b': 20,
        'd': 4,
        'nested': {'x': 1, 'y': 2},
      });
    });
  });
}
