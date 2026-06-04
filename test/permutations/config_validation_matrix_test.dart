// Permutation matrix over the *platform-enablement × image-source* option
// space of `Config.fromJson` (a.k.a. `Config.fromPartial`).
//
// This is the validation core: which combinations of `android` / `ios`
// toggles and `image_path*` sources are accepted, and which raise
// `InvalidConfigException`. The accept/reject expectations below are derived
// by hand from the documented contract in `lib/config/config.dart`
// (`Config.fromPartial`):
//
//   * hasAnyPlatform = android.enabled || ios.enabled || web.generate ||
//                      windows.generate || macos.generate
//   * A platform being enabled with NO image source anywhere is an error.
//   * `android` / `ios` specifically require a *mobile* image source
//     (top-level `image_path`, `image_path_android`, or `image_path_ios`);
//     a per-platform `web`/`windows`/`macos` image_path does NOT satisfy
//     them.
//   * `web`/`windows`/`macos` are satisfied by their own nested `image_path`.
//
// Each case is a `(label, map)` pair so a failure names the exact permutation.
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:test/test.dart';

const _img = 'assets/icon.png';

/// Configs that MUST validate cleanly.
final List<(String, Map<String, dynamic>)> _accepted = [
  ('empty config (no platforms, no images)', {}),
  ('image_path only, no platforms enabled', {'image_path': _img}),
  ('android:false + ios:false (both explicitly off)', {
    'android': false,
    'ios': false,
  }),
  ('android:true + top-level image_path', {'android': true, 'image_path': _img}),
  ('android:true + image_path_android', {
    'android': true,
    'image_path_android': _img,
  }),
  // Per the contract, image_path_ios counts as a "mobile" source and so
  // satisfies an enabled android platform too.
  ('android:true + image_path_ios (ios img satisfies android)', {
    'android': true,
    'image_path_ios': _img,
  }),
  ('ios:true + top-level image_path', {'ios': true, 'image_path': _img}),
  ('ios:true + image_path_ios', {'ios': true, 'image_path_ios': _img}),
  ('ios:true + image_path_android (android img satisfies ios)', {
    'ios': true,
    'image_path_android': _img,
  }),
  ('android:"ic_dev" (named) + image_path', {
    'android': 'ic_dev',
    'image_path': _img,
  }),
  ('ios:"AltIcon" (named) + image_path', {'ios': 'AltIcon', 'image_path': _img}),
  ('android:true + ios:true + image_path', {
    'android': true,
    'ios': true,
    'image_path': _img,
  }),
  ('web.generate + web.image_path (self-satisfied)', {
    'web': {'generate': true, 'image_path': _img},
  }),
  ('windows.generate + windows.image_path (self-satisfied)', {
    'windows': {'generate': true, 'image_path': _img},
  }),
  ('macos.generate + macos.image_path (self-satisfied)', {
    'macos': {'generate': true, 'image_path': _img},
  }),
  ('web.generate + top-level image_path (top satisfies web)', {
    'image_path': _img,
    'web': {'generate': true},
  }),
  ('android:true + web self-satisfied + image_path_android', {
    'android': true,
    'image_path_android': _img,
    'web': {'generate': true, 'image_path': _img},
  }),
];

/// Configs that MUST raise `InvalidConfigException`.
final List<(String, Map<String, dynamic>)> _rejected = [
  ('android:true with no image anywhere', {'android': true}),
  ('ios:true with no image anywhere', {'ios': true}),
  ('android:true + ios:true with no image', {'android': true, 'ios': true}),
  ('android:"ic_dev" (named) with no image', {'android': 'ic_dev'}),
  ('web.generate with no image anywhere', {
    'web': {'generate': true},
  }),
  ('windows.generate with no image anywhere', {
    'windows': {'generate': true},
  }),
  ('macos.generate with no image anywhere', {
    'macos': {'generate': true},
  }),
  ('android:true but only a web image_path (web img != mobile)', {
    'android': true,
    'web': {'generate': true, 'image_path': _img},
  }),
  ('ios:true but only a web image_path (web img != mobile)', {
    'ios': true,
    'web': {'generate': true, 'image_path': _img},
  }),
  ('android:true but only a windows image_path (windows img != mobile)', {
    'android': true,
    'windows': {'generate': true, 'image_path': _img},
  }),
];

void main() {
  group('Config validation matrix — accepted permutations', () {
    for (final (label, map) in _accepted) {
      test('accepts: $label', () {
        expect(() => Config.fromJson(map), returnsNormally);
      });
    }
  });

  group('Config validation matrix — rejected permutations', () {
    for (final (label, map) in _rejected) {
      test('rejects: $label', () {
        expect(
          () => Config.fromJson(map),
          throwsA(isA<InvalidConfigException>()),
        );
      });
    }
  });
}
