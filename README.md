# flutter_launcher_icons_flavored

[![pub version](https://img.shields.io/pub/v/flutter_launcher_icons_flavored.svg)](https://pub.dev/packages/flutter_launcher_icons_flavored)
[![pub points](https://img.shields.io/pub/points/flutter_launcher_icons_flavored)](https://pub.dev/packages/flutter_launcher_icons_flavored/score)
[![popularity](https://img.shields.io/pub/popularity/flutter_launcher_icons_flavored)](https://pub.dev/packages/flutter_launcher_icons_flavored/score)
[![likes](https://img.shields.io/pub/likes/flutter_launcher_icons_flavored)](https://pub.dev/packages/flutter_launcher_icons_flavored/score)
[![CI](https://github.com/tmura-ido/flutter_launcher_icons_flavored/actions/workflows/ci.yml/badge.svg)](https://github.com/tmura-ido/flutter_launcher_icons_flavored/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A command-line tool that generates Flutter launcher icons for **Android, iOS, macOS, Web, and Windows** from a single image (or per-platform overrides). This is a **flavor-aware fork of [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)** that adds first-class support for Flutter build flavors via a consolidated `flutter_launcher_icons_flavors.yaml` file, deep-merged defaults, a `doctor` diagnostic command, and an automated `migrate` command for legacy multi-file flavor setups.

## Requirements

- Flutter `>= 3.41.9` (matches the CI floor).
- Dart SDK `>=3.8.0 <4.0.0`.
- Android `minSdkVersion >= 24` (new default — see [migration guide](doc/migration-0.15.md)).

## Install

```yaml
dev_dependencies:
  flutter_launcher_icons_flavored: ^0.15.0
```

Then `flutter pub get`.

## Quick start (single-flavor)

Create `flutter_launcher_icons.yaml` in your project root:

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "assets/icon/icon-foreground.png"
  min_sdk_android: 24
  web:
    generate: true
    image_path: "assets/icon/icon.png"
    background_color: "#ffffff"
    theme_color: "#0175C2"
  windows:
    generate: true
    image_path: "assets/icon/icon.png"
    icon_size: 48
  macos:
    generate: true
    image_path: "assets/icon/icon.png"
```

Run:

```shell
dart run flutter_launcher_icons_flavored generate
```

## Multi-flavor (consolidated)

For multi-flavor projects, use a single `flutter_launcher_icons_flavors.yaml`. Keys in `defaults:` are deep-merged into every flavor; per-flavor blocks override and may set explicit `null` to **delete** an inherited key.

```yaml
version: 1

defaults:
  android: "launcher_icon"
  ios: true
  min_sdk_android: 24
  remove_alpha_ios: true

flavors:
  dev:
    image_path: "assets/icon/icon-dev.png"
    adaptive_icon_background: "#FF8800"
    adaptive_icon_foreground: "assets/icon/fg-dev.png"

  prod:
    image_path: "assets/icon/icon-prod.png"
    adaptive_icon_background: "#0175C2"
    adaptive_icon_foreground: "assets/icon/fg-prod.png"
```

Build a single flavor or all of them:

```shell
dart run flutter_launcher_icons_flavored generate --flavor dev
dart run flutter_launcher_icons_flavored generate --all-flavors
```

> **Note:** With the consolidated file present and **more than one** flavor defined, omitting both `--flavor` and `--all-flavors` exits **64** (usage error). Single-flavor consolidated files build the only flavor automatically.

See [`doc/flavors.md`](doc/flavors.md) for the full schema, deep-merge rules, source-resolution precedence, and troubleshooting.

## Migrating from `flutter_launcher_icons`

Short version:

1. Replace `flutter_launcher_icons:` with `flutter_launcher_icons_flavored:` in `dev_dependencies`.
2. Update CLI invocations: `dart run flutter_launcher_icons` → `dart run flutter_launcher_icons_flavored generate`.
3. The `flutter_icons:` block in `pubspec.yaml` still works but prints a deprecation warning. **It will be removed in 0.17.** Move it to `flutter_launcher_icons.yaml`.
4. The `min_sdk_android` default was raised **21 → 24**. Set it explicitly to keep the old value.
5. Legacy `flutter_launcher_icons-<flavor>.yaml` files still work. When both legacy and consolidated files exist, the consolidated file wins and a warning is printed (use `--strict` to escalate to exit 65).
6. Run `dart run flutter_launcher_icons_flavored migrate` to convert legacy files into the consolidated format automatically.

Full guide: [`doc/migration-0.15.md`](doc/migration-0.15.md).

## CLI reference

| Command | What it does |
| --- | --- |
| `generate` | Generate launcher icons. Default subcommand. Supports `-f <file>`, `-p <prefix>`, `--flavor <name>` (repeatable), `--all-flavors`, `--list-flavors`, `--continue-on-error`, `--strict`, `-v`. |
| `migrate` | Convert legacy `flutter_launcher_icons-<flavor>.yaml` files into a single `flutter_launcher_icons_flavors.yaml`. Supports `--dry-run`, `--in-place`, `--force`. |
| `doctor` | Report Dart/Flutter versions, detected configs, source resolution, and any conflicts. |

Run `dart run flutter_launcher_icons_flavored <command> --help` for the full flag list.

## Configuration

Top-level keys (single-flavor `flutter_launcher_icons.yaml`):

| Key | Purpose |
| --- | --- |
| `image_path` | Default source icon (used by all platforms unless overridden). |
| `android` | `true` / `false` / output filename. |
| `ios` | `true` / `false` / output filename. |
| `image_path_android`, `image_path_ios` | Per-platform source overrides. |
| `min_sdk_android` | Android minSdk floor used to choose adaptive-icon output. Default: **24**. |
| `adaptive_icon_background` | Color (`#RRGGBB`) or image asset for adaptive-icon background. |
| `adaptive_icon_foreground` | Image asset for adaptive-icon foreground. |
| `adaptive_icon_foreground_inset` | Foreground padding in % (default 16). |
| `adaptive_icon_monochrome` | Image asset for Android 13+ themed icon. |
| `remove_alpha_ios`, `background_color_ios` | iOS alpha-channel handling. |
| `image_path_ios_dark_transparent`, `image_path_ios_tinted_grayscale`, `desaturate_tinted_to_grayscale_ios` | iOS 18+ dark/tinted variants. |
| `web` | `{ generate, image_path, background_color, theme_color }`. |
| `windows` | `{ generate, image_path, icon_size }` (48–256, default 48). |
| `macos` | `{ generate, image_path }`. |

Multi-flavor extra keys (consolidated file): `version: 1` (required), `defaults:` (optional), `flavors:` (required, map of flavor name → per-flavor block).

Full schema with annotated examples: [`doc/flavors.md`](doc/flavors.md).

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success. |
| 1 | Runtime / I/O failure during generation. |
| 64 | Usage error (unknown flavor, conflicting flags, multi-flavor consolidated config without `--flavor`/`--all-flavors`). |
| 65 | Configuration error (schema validation, missing config, `--strict` coexistence). |

## Contributing

Issues and PRs welcome at [`tmura-ido/flutter_launcher_icons_flavored`](https://github.com/tmura-ido/flutter_launcher_icons_flavored).

Local development:

```shell
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

CI runs the matrix `{ubuntu, macos, windows} × {Flutter 3.41.9, stable}` plus `pana` and `dart pub publish --dry-run` on the Linux + 3.41.9 cell. The `main` branch is protected — PRs must be green on every matrix cell, and the recommended branch-protection settings are: require all CI checks to pass, require linear history, and require signed commits.

## License

MIT. See [`LICENSE`](LICENSE).

### Special thanks

- Brendan Duncan for the underlying [`image`](https://pub.dev/packages/image) package.
- The original `flutter_launcher_icons` maintainers and contributors.
