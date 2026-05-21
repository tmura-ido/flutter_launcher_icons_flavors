// ignore_for_file: public_member_api_docs, avoid_print
//
// Generates `flutter_launcher_icons_flavors.schema.json` at repo root.
//
// Run:
//     dart run tool/generate_schema.dart
//
// The schema is referenced by the auto-injected `# yaml-language-server:`
// directive at the top of every config file the tool touches, so editors
// (VS Code + Red Hat YAML, JetBrains IDEs natively) get autocomplete,
// hover docs, and inline validation without any per-project setup.
//
// Drift between this generator and the live config classes is caught by
// `test/schema/schema_drift_test.dart`, which constructs each
// `@JsonSerializable` class and asserts every `JsonKey` is represented
// here.

import 'dart:convert';
import 'dart:io';

void main() {
  final schema = _buildRootSchema();
  final encoded = const JsonEncoder.withIndent('  ').convert(schema);
  final out = File('flutter_launcher_icons_flavors.schema.json');
  out.writeAsStringSync('$encoded\n');
  print('Wrote ${out.path} (${encoded.length} bytes).');
}

const _schemaUrl =
    'https://raw.githubusercontent.com/tmura-ido/flutter_launcher_icons_flavors/master/flutter_launcher_icons_flavors.schema.json';

// =====================================================================
// Root: oneOf between the three accepted file shapes.
// =====================================================================
Map<String, dynamic> _buildRootSchema() {
  return <String, dynamic>{
    r'$schema': 'http://json-schema.org/draft-07/schema#',
    r'$id': _schemaUrl,
    'title': 'flutter_launcher_icons_flavors',
    'description':
        'Config schema for flutter_launcher_icons_flavors. Accepts the '
        'consolidated multi-flavor layout, the single-config layout, '
        'and the pubspec-inline layout.',
    'oneOf': <Map<String, dynamic>>[
      _consolidatedShape(),
      _singleConfigShape(),
      _pubspecInlineShape(),
    ],
    r'$defs': <String, dynamic>{
      'configFields': _configProperties(),
      'webConfig': _webConfigSchema(),
      'windowsConfig': _windowsConfigSchema(),
      'macosConfig': _macosConfigSchema(),
      'linuxConfig': _linuxConfigSchema(),
      'badgeConfig': _badgeConfigSchema(),
      'iosAlternateIconsConfig': _iosAlternateIconsSchema(),
      'trayIconConfig': _trayIconSchema(),
      'platformToggle': _platformToggleSchema(),
      'hexColor': _hexColorSchema(),
    },
  };
}

Map<String, dynamic> _consolidatedShape() => <String, dynamic>{
      'type': 'object',
      'description':
          'Consolidated multi-flavor file '
          '(`flutter_launcher_icons_flavors.yaml`).',
      'required': <String>['version', 'flavors'],
      'properties': <String, dynamic>{
        'version': <String, dynamic>{
          'description': 'Schema version. Must be 1 for 0.15.x.',
          'type': 'integer',
          'const': 1,
        },
        'defaults': <String, dynamic>{
          'description':
              'Shared base that is deep-merged into every flavor block.',
          r'$ref': '#/\$defs/configFields',
        },
        'flavors': <String, dynamic>{
          'description': 'Map of flavor name → flavor-specific overrides.',
          'type': 'object',
          'minProperties': 1,
          'additionalProperties': <String, dynamic>{
            r'$ref': '#/\$defs/configFields',
          },
        },
      },
      'additionalProperties': false,
    };

Map<String, dynamic> _singleConfigShape() => <String, dynamic>{
      'type': 'object',
      'description':
          'Flat single-config file (`flutter_launcher_icons.yaml` or '
          '`flutter_launcher_icons-<flavor>.yaml`).',
      'allOf': <Map<String, dynamic>>[
        <String, dynamic>{r'$ref': '#/\$defs/configFields'},
      ],
    };

Map<String, dynamic> _pubspecInlineShape() => <String, dynamic>{
      'type': 'object',
      'description':
          'Pubspec inline (`pubspec.yaml` with `flutter_launcher_icons:` or '
          'deprecated `flutter_icons:` block).',
      'properties': <String, dynamic>{
        'flutter_launcher_icons': <String, dynamic>{
          r'$ref': '#/\$defs/configFields',
        },
        'flutter_icons': <String, dynamic>{
          'description': 'Deprecated; use `flutter_launcher_icons` instead.',
          r'$ref': '#/\$defs/configFields',
        },
      },
    };

// =====================================================================
// Config (the flat set of keys reused by every shape).
// =====================================================================
Map<String, dynamic> _configProperties() {
  return <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'image_path': <String, dynamic>{
        'description': 'Source PNG used by every enabled platform.',
        'type': 'string',
      },
      'image_path_android': <String, dynamic>{
        'description': 'Android-specific source override.',
        'type': 'string',
      },
      'image_path_ios': <String, dynamic>{
        'description': 'iOS-specific source override.',
        'type': 'string',
      },
      'image_path_ios_dark_transparent': <String, dynamic>{
        'description':
            'iOS 18+ dark-mode variant (transparent PNG composited over '
            'system background).',
        'type': 'string',
      },
      'image_path_ios_tinted_grayscale': <String, dynamic>{
        'description':
            'iOS 18+ tinted variant (grayscale PNG; iOS applies user tint).',
        'type': 'string',
      },
      'android': <String, dynamic>{
        'description':
            'Android platform toggle. `true` → default name `ic_launcher`; '
            'a string sets a custom resource name `[a-z0-9_]+`; `false` '
            'skips Android.',
        r'$ref': '#/\$defs/platformToggle',
      },
      'ios': <String, dynamic>{
        'description':
            'iOS platform toggle. `true` → default catalog name `AppIcon`; '
            'a string sets a custom catalog basename; `false` skips iOS.',
        r'$ref': '#/\$defs/platformToggle',
      },
      'min_sdk_android': <String, dynamic>{
        'description':
            'Android minSdk floor. Below 26, only legacy icons are emitted; '
            '26+ also produces adaptive icons. Default 24.',
        'type': 'integer',
        'minimum': 1,
      },
      'copy_mipmap_xxxhdpi_to_drawable': <String, dynamic>{
        'description':
            'Copy `mipmap-xxxhdpi/<icon>.png` into the same flavor’s '
            '`drawable/` folder. Useful for notification icons. Default false.',
        'type': 'boolean',
      },
      'adaptive_icon_background': <String, dynamic>{
        'description':
            'Adaptive-icon background. Either a hex color (`#RRGGBB`) or a '
            'path to a background image. Required when '
            '`adaptive_icon_foreground` is set.',
        'type': 'string',
      },
      'adaptive_icon_foreground': <String, dynamic>{
        'description':
            'Adaptive-icon foreground PNG. Keep logo in central 66 % '
            'safe-zone; outer 33 % is masked.',
        'type': 'string',
      },
      'adaptive_icon_foreground_inset': <String, dynamic>{
        'description':
            'Percentage of additional padding around the foreground. '
            'Default 16.',
        'type': 'integer',
        'minimum': 0,
        'maximum': 100,
      },
      'adaptive_icon_monochrome': <String, dynamic>{
        'description':
            'Android-13+ themed-icon foreground (white-on-transparent PNG).',
        'type': 'string',
      },
      'remove_alpha_ios': <String, dynamic>{
        'description':
            'Strip alpha channel before writing iOS icons. Required for '
            'App Store submission. Default false.',
        'type': 'boolean',
      },
      'background_color_ios': <String, dynamic>{
        'description':
            'Opaque background color used when `remove_alpha_ios: true`. '
            'Default `#FFFFFF`.',
        r'$ref': '#/\$defs/hexColor',
      },
      'desaturate_tinted_to_grayscale_ios': <String, dynamic>{
        'description':
            'Desaturate `image_path_ios_tinted_grayscale` automatically. '
            'Default false.',
        'type': 'boolean',
      },
      'flavor': <String, dynamic>{
        'description':
            'Explicit flavor name override. Wins over the filename-derived '
            'flavor (upstream #490).',
        'type': 'string',
      },
      'xcodeproj_path': <String, dynamic>{
        'description':
            'Optional Xcode project path. Default auto-detects '
            '`ios/*.xcodeproj`, falling back to `ios/Runner.xcodeproj`.',
        'type': 'string',
      },
      'ios_legacy_sizes': <String, dynamic>{
        'description':
            'Emit legacy 1x iOS sizes alongside the modern set so the app '
            'switcher / older surfaces find every size (upstream #661). '
            'Default false.',
        'type': 'boolean',
      },
      'ios_single_size': <String, dynamic>{
        'description':
            'Xcode 14+ "single size" mode: emit only the 1024×1024 marketing '
            'slot. Overrides `ios_legacy_sizes`. Default false.',
        'type': 'boolean',
      },
      'optimize_png': <String, dynamic>{
        'description':
            'Run every output PNG through max-compression encoding '
            '(slower; 30–70 % smaller files). Default false.',
        'type': 'boolean',
      },
      'ios_disable_liquid_glass': <String, dynamic>{
        'description':
            'Mark Contents.json for Xcode 26+ Liquid-Glass opt-out '
            '(upstream #657, stub). Default false.',
        'type': 'boolean',
      },
      'non_square_image_ok': <String, dynamic>{
        'description':
            'Suppress the doctor’s non-square source warning (upstream '
            '#214). Default false.',
        'type': 'boolean',
      },
      'web': <String, dynamic>{
        'description': 'Web platform config.',
        'oneOf': <Map<String, dynamic>>[
          <String, dynamic>{r'$ref': '#/\$defs/webConfig'},
          <String, dynamic>{'type': 'null'},
        ],
      },
      'windows': <String, dynamic>{
        'description': 'Windows platform config.',
        'oneOf': <Map<String, dynamic>>[
          <String, dynamic>{r'$ref': '#/\$defs/windowsConfig'},
          <String, dynamic>{'type': 'null'},
        ],
      },
      'macos': <String, dynamic>{
        'description': 'macOS platform config.',
        'oneOf': <Map<String, dynamic>>[
          <String, dynamic>{r'$ref': '#/\$defs/macosConfig'},
          <String, dynamic>{'type': 'null'},
        ],
      },
      'linux': <String, dynamic>{
        'description': 'Linux platform config (upstream #666).',
        'oneOf': <Map<String, dynamic>>[
          <String, dynamic>{r'$ref': '#/\$defs/linuxConfig'},
          <String, dynamic>{'type': 'null'},
        ],
      },
      'ios_alternate_icons': <String, dynamic>{
        'description': 'iOS alternate app-icon sets (upstream #92).',
        'oneOf': <Map<String, dynamic>>[
          <String, dynamic>{r'$ref': '#/\$defs/iosAlternateIconsConfig'},
          <String, dynamic>{'type': 'null'},
        ],
      },
      'badge': <String, dynamic>{
        'description': 'Per-flavor environment-badge overlay (upstream #622).',
        'oneOf': <Map<String, dynamic>>[
          <String, dynamic>{r'$ref': '#/\$defs/badgeConfig'},
          <String, dynamic>{'type': 'null'},
        ],
      },
    },
    'additionalProperties': false,
  };
}

Map<String, dynamic> _webConfigSchema() => <String, dynamic>{
      'type': 'object',
      'description': 'Web platform config.',
      'properties': <String, dynamic>{
        'generate': <String, dynamic>{
          'description': 'Master switch for web icon generation.',
          'type': 'boolean',
        },
        'image_path': <String, dynamic>{
          'description': 'Source PNG override; falls back to top-level.',
          'type': 'string',
        },
        'background_color': <String, dynamic>{
          'description': 'manifest.json `background_color`.',
          r'$ref': '#/\$defs/hexColor',
        },
        'theme_color': <String, dynamic>{
          'description': 'manifest.json `theme_color`.',
          r'$ref': '#/\$defs/hexColor',
        },
        'output_path': <String, dynamic>{
          'description':
              'Output directory. Defaults to `web_<flavor>/` if flavor is '
              'active, else `web/` (upstream #426).',
          'type': 'string',
        },
        'generate_favicon': <String, dynamic>{
          'description':
              'Emit multi-size `favicon.ico` alongside `favicon.png`. '
              'Default true.',
          'type': 'boolean',
        },
        'favicon_path': <String, dynamic>{
          'description':
              'Favicon source override. Falls back to `image_path`, then '
              'top-level `image_path`.',
          'type': 'string',
        },
        'favicon_size': <String, dynamic>{
          'description': 'PNG favicon side length in pixels. Default 16.',
          'type': 'integer',
          'minimum': 1,
        },
      },
      'additionalProperties': false,
    };

Map<String, dynamic> _windowsConfigSchema() => <String, dynamic>{
      'type': 'object',
      'description': 'Windows platform config.',
      'properties': <String, dynamic>{
        'generate': <String, dynamic>{
          'description': 'Master switch for Windows icon generation.',
          'type': 'boolean',
        },
        'image_path': <String, dynamic>{
          'description': 'Source PNG override; falls back to top-level.',
          'type': 'string',
        },
        'icon_size': <String, dynamic>{
          'description':
              'Max embedded size for the multi-image ICO. Default 48; range 48–256.',
          'type': 'integer',
          'minimum': 48,
          'maximum': 256,
        },
        'tray_icon': <String, dynamic>{r'$ref': '#/\$defs/trayIconConfig'},
      },
      'additionalProperties': false,
    };

Map<String, dynamic> _macosConfigSchema() => <String, dynamic>{
      'type': 'object',
      'description': 'macOS platform config.',
      'properties': <String, dynamic>{
        'generate': <String, dynamic>{
          'description': 'Master switch for macOS icon generation.',
          'type': 'boolean',
        },
        'image_path': <String, dynamic>{
          'description': 'Source PNG override; falls back to top-level.',
          'type': 'string',
        },
        'padding': <String, dynamic>{
          'description':
              'Resize source to 824×824 on a 1024×1024 transparent canvas '
              '(Apple’s recommended effective-design area, upstream #655). '
              'Default false.',
          'type': 'boolean',
        },
        'dark_image_path': <String, dynamic>{
          'description':
              'Source for the macOS dark-mode appearance variant '
              '(upstream #660).',
          'type': 'string',
        },
        'tinted_image_path': <String, dynamic>{
          'description':
              'Source for the macOS tinted appearance variant '
              '(upstream #660).',
          'type': 'string',
        },
        'tray_icon': <String, dynamic>{r'$ref': '#/\$defs/trayIconConfig'},
      },
      'additionalProperties': false,
    };

Map<String, dynamic> _linuxConfigSchema() => <String, dynamic>{
      'type': 'object',
      'description': 'Linux platform config (upstream #666).',
      'properties': <String, dynamic>{
        'generate': <String, dynamic>{
          'description': 'Master switch for Linux icon generation.',
          'type': 'boolean',
        },
        'image_path': <String, dynamic>{
          'description': 'Source PNG override; falls back to top-level.',
          'type': 'string',
        },
        'icon_size': <String, dynamic>{
          'description': 'Output PNG side length. Default 256.',
          'type': 'integer',
          'minimum': 1,
        },
        'output_path': <String, dynamic>{
          'description':
              'Output path for the PNG. Default '
              '`linux/runner/resources/app_icon.png`.',
          'type': 'string',
        },
        'tray_icon': <String, dynamic>{r'$ref': '#/\$defs/trayIconConfig'},
      },
      'additionalProperties': false,
    };

Map<String, dynamic> _badgeConfigSchema() => <String, dynamic>{
      'type': 'object',
      'description':
          'Environment-badge overlay (upstream #622, phase 1: schema only).',
      'required': <String>['text'],
      'properties': <String, dynamic>{
        'text': <String, dynamic>{
          'description': 'Badge text. Empty/whitespace triggers a warning.',
          'type': 'string',
        },
        'color': <String, dynamic>{
          'description': 'Text color. Default `#FFFFFF`.',
          r'$ref': '#/\$defs/hexColor',
        },
        'background_color': <String, dynamic>{
          'description': 'Solid pill/banner background color.',
          r'$ref': '#/\$defs/hexColor',
        },
        'position': <String, dynamic>{
          'description': 'Badge position on the icon.',
          'type': 'string',
          'enum': <String>[
            'tl',
            'topleft',
            'tr',
            'topright',
            'bl',
            'bottomleft',
            'br',
            'bottomright',
            'banner-top',
            'banner-bottom',
          ],
          'default': 'tr',
        },
        'font_size_pct': <String, dynamic>{
          'description': 'Font size as % of image height. Default 18.',
          'type': 'integer',
          'minimum': 1,
          'maximum': 100,
        },
        'font_family': <String, dynamic>{
          'description':
              'Built-in font name (`Roboto`, `RobotoMono`, `Inter`) or path '
              'to a `.ttf` file.',
          'type': 'string',
        },
        'padding_pct': <String, dynamic>{
          'description':
              'Padding from edge as % of image height. Default 4.',
          'type': 'integer',
          'minimum': 0,
          'maximum': 100,
        },
      },
      'additionalProperties': false,
    };

Map<String, dynamic> _iosAlternateIconsSchema() => <String, dynamic>{
      'type': 'object',
      'description': 'iOS alternate app-icon sets (upstream #92).',
      'properties': <String, dynamic>{
        'enabled': <String, dynamic>{
          'description': 'Master switch.',
          'type': 'boolean',
        },
        'icons': <String, dynamic>{
          'description':
              'Map of alternate-icon name → image source paths. Each entry '
              'produces a separate `<name>.appiconset/` directory.',
          'type': 'object',
          'additionalProperties': <String, dynamic>{
            'type': 'object',
            'properties': <String, dynamic>{
              'image_path': <String, dynamic>{
                'description': 'Primary source PNG.',
                'type': 'string',
              },
              'image_path_dark_transparent': <String, dynamic>{
                'description': 'iOS-18 dark variant (optional).',
                'type': 'string',
              },
              'image_path_tinted_grayscale': <String, dynamic>{
                'description': 'iOS-18 tinted variant (optional).',
                'type': 'string',
              },
            },
            'additionalProperties': false,
          },
        },
      },
      'additionalProperties': false,
    };

Map<String, dynamic> _trayIconSchema() => <String, dynamic>{
      'type': 'object',
      'description':
          'Desktop tray icon config (upstream #510, phase 1: schema only).',
      'properties': <String, dynamic>{
        'image_path': <String, dynamic>{
          'description':
              'Source image (non-macOS). Falls back to the platform’s '
              '`image_path`.',
          'type': 'string',
        },
        'template_image_path': <String, dynamic>{
          'description':
              'macOS template image (monochrome silhouette with alpha). '
              'The macOS writer refuses to default to the colored launcher '
              'image.',
          'type': 'string',
        },
        'sizes': <String, dynamic>{
          'description':
              'Embedded sizes (Windows ICO / macOS imageset / Linux PNGs).',
          'type': 'array',
          'items': <String, dynamic>{'type': 'integer', 'minimum': 1},
        },
        'output': <String, dynamic>{
          'description':
              'Output path. Defaults per-platform: '
              '`windows/runner/resources/tray.ico`, '
              '`macos/Runner/Assets.xcassets/TrayIcon.imageset`, '
              '`linux/runner/resources/tray/`.',
          'type': 'string',
        },
      },
      'additionalProperties': false,
    };

Map<String, dynamic> _platformToggleSchema() => <String, dynamic>{
      'description':
          'Tri-state platform toggle. `false` disables, `true` uses the '
          'default name, a string sets a custom resource/catalog name.',
      'oneOf': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'boolean'},
        <String, dynamic>{'type': 'string', 'minLength': 1},
        <String, dynamic>{'type': 'null'},
      ],
    };

Map<String, dynamic> _hexColorSchema() => <String, dynamic>{
      'description': 'Hex color string, `#RGB`, `#RRGGBB`, or `#RRGGBBAA`.',
      'type': 'string',
      'pattern': r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    };
