// Permutation matrix over the `android` × `ios` platform-toggle grammar,
// exercised through BOTH config entry points:
//
//   * strict   → `Config.fromJson(...)`        — materializes through
//     `Config.fromPartial`, whose `PlatformToggleConverter` semantics collapse
//     a `null`/absent toggle to *disabled*.
//   * nullable → `PartialConfig.fromJson(...)` — uses
//     `NullablePlatformToggleConverter`, which *preserves* `null` so the merge
//     layer can later tell "user omitted" from "user wrote false".
//
// For every (android, ios) ∈ {null, false, true, "name"}² (16 combinations) we
// assert the resulting `PlatformToggle` state on each path. Then we sweep the
// invalid grammar (empty string, number, list, map) and assert both paths
// reject it with `CheckedFromJsonException` (the schema is `checked: true`).
//
// Each case names the exact permutation so a failure points straight at the
// offending input.
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/partial_config.dart';
import 'package:flutter_launcher_icons_flavors/config/platform_toggle.dart';
import 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;
import 'package:test/test.dart';

/// The four legal grammar inputs a platform toggle accepts.
enum _Toggle { nul, off, on, named }

const _customName = 'ic_launcher_custom';

/// The raw JSON value each grammar input deserializes from.
Object? _json(_Toggle t) => switch (t) {
  _Toggle.nul => null,
  _Toggle.off => false,
  _Toggle.on => true,
  _Toggle.named => _customName,
};

/// Expected toggle on the strict (`Config`) path — `null` collapses to
/// disabled.
PlatformToggle _expectStrict(_Toggle t) => switch (t) {
  _Toggle.nul => PlatformToggle.disabled(),
  _Toggle.off => PlatformToggle.disabled(),
  _Toggle.on => PlatformToggle.enabled(),
  _Toggle.named => PlatformToggle.named(_customName),
};

/// Expected toggle on the nullable (`PartialConfig`) path — `null` is
/// preserved as `null`.
PlatformToggle? _expectNullable(_Toggle t) => switch (t) {
  _Toggle.nul => null,
  _Toggle.off => PlatformToggle.disabled(),
  _Toggle.on => PlatformToggle.enabled(),
  _Toggle.named => PlatformToggle.named(_customName),
};

void main() {
  group('Platform-toggle matrix — Config.fromJson (strict, null→disabled)', () {
    for (final a in _Toggle.values) {
      for (final i in _Toggle.values) {
        test('android=${a.name} ios=${i.name}', () {
          // A top-level image_path keeps any *enabled* platform past the
          // image-source requirement so we isolate the toggle behavior.
          final cfg = Config.fromJson(<String, dynamic>{
            'image_path': 'assets/icon.png',
            'android': _json(a),
            'ios': _json(i),
          });
          final expA = _expectStrict(a);
          final expI = _expectStrict(i);
          expect(cfg.android, expA, reason: 'android=${a.name}');
          expect(cfg.ios, expI, reason: 'ios=${i.name}');
          // The Config-level derived getters must stay wired to the toggle.
          expect(cfg.hasAndroidConfig, expA.isEnabled);
          expect(cfg.isCustomAndroidFile, expA.isCustom);
          expect(cfg.androidIconName, expA.customIconName ?? '');
          expect(cfg.hasIOSConfig, expI.isEnabled);
          expect(cfg.isCustomIOSFile, expI.isCustom);
          expect(cfg.iosIconName, expI.customIconName ?? '');
        });
      }
    }
  });

  group(
    'Platform-toggle matrix — PartialConfig.fromJson (nullable, null preserved)',
    () {
      for (final a in _Toggle.values) {
        for (final i in _Toggle.values) {
          test('android=${a.name} ios=${i.name}', () {
            final partial = PartialConfig.fromJson(<String, dynamic>{
              'android': _json(a),
              'ios': _json(i),
            });
            expect(partial.android, _expectNullable(a), reason: 'android');
            expect(partial.ios, _expectNullable(i), reason: 'ios');
          });
        }
      }
    },
  );

  group('Platform-toggle grammar — invalid inputs are rejected', () {
    // null/false/true/String are the only legal shapes; everything else must
    // be a checked-schema error, not a silently-coerced value.
    final invalid = <String, Object>{
      'empty string': '',
      'number': 42,
      'list': [1, 2, 3],
      'map': {'foo': 'bar'},
    };
    for (final entry in invalid.entries) {
      final label = entry.key;
      final value = entry.value;

      test('Config.fromJson android=$label → CheckedFromJsonException', () {
        expect(
          () => Config.fromJson({
            'image_path': 'assets/icon.png',
            'android': value,
          }),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
      test('Config.fromJson ios=$label → CheckedFromJsonException', () {
        expect(
          () => Config.fromJson({
            'image_path': 'assets/icon.png',
            'ios': value,
          }),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
      test('PartialConfig.fromJson android=$label → CheckedFromJsonException',
          () {
        expect(
          () => PartialConfig.fromJson({'android': value}),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
      test('PartialConfig.fromJson ios=$label → CheckedFromJsonException', () {
        expect(
          () => PartialConfig.fromJson({'ios': value}),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    }
  });
}
