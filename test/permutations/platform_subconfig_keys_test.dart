// Parity matrix: every documented key of the per-platform sub-config blocks
// (`web` / `windows` / `macos` / `linux`) is exercised through BOTH config
// entry points:
//
//   * single-config  → `Config.fromJson({...})`
//   * consolidated   → `FlavorsConfig.load(flutter_launcher_icons_flavors.yaml)`
//
// CONTRACT: a key that is valid in a single-config file must be equally valid
// in a consolidated multi-flavor file. The two loaders should accept the same
// schema.
//
// The consolidated loader runs a hand-maintained allow-list
// (`_allowedNestedKeys` in `lib/config/flavors_config.dart`) over the nested
// platform blocks. If that allow-list has drifted out of sync with the actual
// `WebConfig` / `WindowsConfig` / `MacOSConfig` classes, valid keys are
// rejected ONLY in the consolidated path — and the corresponding
// `consolidated accepts ...` test below fails while its `single-config
// accepts ...` twin passes. That asymmetry is the signal.
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/config/flavors_config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

typedef _KeyCase = ({String platform, String key, Object? value});

/// One representative value per documented sub-config key, beyond the
/// structural `generate` / `image_path` that every block already carries.
final List<_KeyCase> _cases = [
  // ---- WebConfig (lib/config/web_config.dart) ----
  (platform: 'web', key: 'background_color', value: '#0175C2'),
  (platform: 'web', key: 'theme_color', value: '#000000'),
  (platform: 'web', key: 'output_path', value: 'web_dev'),
  (platform: 'web', key: 'generate_favicon', value: false),
  (platform: 'web', key: 'favicon_path', value: 'favicon.png'),
  (platform: 'web', key: 'favicon_size', value: 32),
  // ---- WindowsConfig (lib/config/windows_config.dart) ----
  (platform: 'windows', key: 'icon_size', value: 48),
  (platform: 'windows', key: 'tray_icon', value: {'image_path': 'tray.png'}),
  // ---- MacOSConfig (lib/config/macos_config.dart) ----
  (platform: 'macos', key: 'padding', value: true),
  (platform: 'macos', key: 'dark_image_path', value: 'dark.png'),
  (platform: 'macos', key: 'tinted_image_path', value: 'tinted.png'),
  (
    platform: 'macos',
    key: 'tray_icon',
    value: {'template_image_path': 'tmpl.png'},
  ),
  // ---- LinuxConfig (lib/config/linux_config.dart) — control group ----
  // `linux` is intentionally NOT in the consolidated allow-list, so these
  // pass through unchecked in both paths (the contrast makes the drift in
  // the other three blocks obvious).
  (platform: 'linux', key: 'icon_size', value: 256),
  (platform: 'linux', key: 'output_path', value: 'linux/runner/app.png'),
  (platform: 'linux', key: 'tray_icon', value: {'image_path': 'tray.png'}),
];

Map<String, dynamic> _singleConfigMap(_KeyCase c) => {
  c.platform: <String, dynamic>{
    'generate': true,
    'image_path': 'i.png',
    c.key: c.value,
  },
};

String _consolidatedYaml(_KeyCase c) {
  final b = StringBuffer()
    ..writeln('version: 1')
    ..writeln('flavors:')
    ..writeln('  dev:')
    ..writeln('    image_path: "i.png"')
    ..writeln('    ${c.platform}:')
    ..writeln('      generate: true')
    ..writeln('      image_path: "i.png"');
  _emit(b, c.key, c.value, 6);
  return b.toString();
}

void _emit(StringBuffer b, String key, Object? value, int indent) {
  final pad = ' ' * indent;
  if (value is Map) {
    b.writeln('$pad$key:');
    value.forEach((k, v) => _emit(b, k.toString(), v, indent + 2));
  } else if (value is String) {
    b.writeln('$pad$key: "$value"');
  } else {
    b.writeln('$pad$key: $value');
  }
}

void main() {
  group('single-config accepts every documented sub-config key', () {
    for (final c in _cases) {
      test('${c.platform}.${c.key}', () {
        expect(() => Config.fromJson(_singleConfigMap(c)), returnsNormally);
      });
    }
  });

  group(
    'consolidated flavors accepts every documented sub-config key '
    '(parity with single-config)',
    () {
      for (final c in _cases) {
        test('${c.platform}.${c.key}', () async {
          await d.file('cfg.yaml', _consolidatedYaml(c)).create();
          final path = p.join(d.sandbox, 'cfg.yaml');
          expect(
            () {
              final cfg = FlavorsConfig.load(path, logger: FLILogger(false))!;
              cfg.resolve('dev');
            },
            returnsNormally,
            reason:
                '`${c.platform}.${c.key}` is valid in a single-config file '
                'but rejected by the consolidated loader — the '
                '_allowedNestedKeys allow-list in flavors_config.dart is out '
                'of sync with ${c.platform == 'web'
                    ? 'WebConfig'
                    : c.platform == 'windows'
                    ? 'WindowsConfig'
                    : 'MacOSConfig'}.',
          );
        });
      }
    },
  );
}
