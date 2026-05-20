# flutter_launcher_icons_flavors

[![pub version](https://img.shields.io/pub/v/flutter_launcher_icons_flavors.svg)](https://pub.dev/packages/flutter_launcher_icons_flavors)
[![pub points](https://img.shields.io/pub/points/flutter_launcher_icons_flavors)](https://pub.dev/packages/flutter_launcher_icons_flavors/score)
[![popularity](https://img.shields.io/pub/popularity/flutter_launcher_icons_flavors)](https://pub.dev/packages/flutter_launcher_icons_flavors/score)
[![likes](https://img.shields.io/pub/likes/flutter_launcher_icons_flavors)](https://pub.dev/packages/flutter_launcher_icons_flavors/score)
[![CI](https://github.com/tmura-ido/flutter_launcher_icons_flavors/actions/workflows/ci.yml/badge.svg)](https://github.com/tmura-ido/flutter_launcher_icons_flavors/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A command-line tool that generates Flutter launcher icons for **Android, iOS, macOS, Web, and Windows** from a single source image — or per-platform overrides, or per-flavor overrides, or any combination.

`flutter_launcher_icons_flavors` is a **flavor-aware fork** of [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons). Compared to the upstream package, it adds:

- A **consolidated multi-flavor config** (`flutter_launcher_icons_flavors.yaml`) so all flavors live in one file with shared `defaults:` and per-flavor overrides — no more `flutter_launcher_icons-prod.yaml` + `flutter_launcher_icons-staging.yaml` + `flutter_launcher_icons-dev.yaml` zoo.
- A **`doctor` subcommand** that reports SDK versions, every config it can see, source-resolution precedence, and any conflicts — invaluable for triaging "why did it pick *that* file?" issues.
- A **`migrate` subcommand** that auto-converts the legacy one-file-per-flavor layout into the consolidated format, with a "promotion candidates" report for keys identical across all flavors.
- A **`--strict` flag** that promotes coexistence warnings (legacy + consolidated configs side-by-side) into hard exit-65 errors, for CI gates.
- **First-class macOS support**, monochrome adaptive icons, iOS 18 dark/tinted variants, and a `copy_mipmap_xxxhdpi_to_drawable` Android convenience flag.
- A modern **Dart `>=3.8.0`** baseline, async I/O on all hot paths, and a `min_sdk_android` default bumped from **21 → 24** to match Flutter's own minimum.

---

## Table of contents

- [Requirements](#requirements)
- [Install](#install)
- [Quick start (single-flavor)](#quick-start-single-flavor)
- [Multi-flavor (consolidated)](#multi-flavor-consolidated)
- [Legacy multi-flavor layout](#legacy-multi-flavor-layout)
- [CLI reference](#cli-reference)
  - [`generate`](#generate)
  - [`migrate`](#migrate)
  - [`doctor`](#doctor)
- [Configuration schema](#configuration-schema)
  - [Top-level keys](#top-level-keys)
  - [Android adaptive icons](#android-adaptive-icons)
  - [iOS specifics](#ios-specifics)
  - [Web](#web)
  - [Windows](#windows)
  - [macOS](#macos)
- [Source-resolution precedence](#source-resolution-precedence)
- [Deep-merge rules (multi-flavor)](#deep-merge-rules-multi-flavor)
- [Exit codes](#exit-codes)
- [Migrating from `flutter_launcher_icons`](#migrating-from-flutter_launcher_icons)
- [Troubleshooting / FAQ](#troubleshooting--faq)
- [Contributing](#contributing)
- [License](#license)

---

## Requirements

- **Flutter** `>= 3.41.9` (matches the CI floor; older versions may work but are not exercised).
- **Dart SDK** `>=3.8.0 <4.0.0`.
- **Android** `minSdkVersion >= 24` (new default). If you must stay on `21`, set `min_sdk_android: 21` explicitly in your config.
- A **PNG source image** for each icon (RGBA is fine; alpha is handled per-platform).
  - Android adaptive icons want the **foreground** to be ≥ `108 × 108 dp` (recommended `1024 × 1024 px`).
  - iOS App Store wants a **1024 × 1024 px** non-transparent square.

## Install

Add as a dev-dependency:

```yaml
dev_dependencies:
  flutter_launcher_icons_flavors: ^0.15.0
```

Then:

```shell
flutter pub get
```

> The tool only runs at build time; there is no runtime dependency. Listing it under `dependencies:` is harmless but unnecessary and inflates your release bundle's dependency report.

---

## Quick start (single-flavor)

Create `flutter_launcher_icons.yaml` in your project root:

```yaml
flutter_launcher_icons:
  # Source image. Used by every enabled platform unless overridden below.
  image_path: "assets/icon/icon.png"

  # Android: emit `launcher_icon.png` into every mipmap density bucket and
  # wire up `android:icon="@mipmap/launcher_icon"` in AndroidManifest.xml.
  android: "launcher_icon"
  min_sdk_android: 24
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/icon-foreground.png"
  adaptive_icon_monochrome: "assets/icon/icon-monochrome.png"  # Android 13+ themed icon

  # iOS: emit every Apple-required size into Assets.xcassets/AppIcon.appiconset
  # and update Contents.json. App Store demands no alpha — see remove_alpha_ios.
  ios: true
  remove_alpha_ios: true
  background_color_ios: "#FFFFFF"

  # Web: emit favicon + PWA icons into web/icons/ and update manifest.json.
  web:
    generate: true
    image_path: "assets/icon/icon.png"
    background_color: "#FFFFFF"
    theme_color: "#0175C2"

  # Windows: emit windows/runner/resources/app_icon.ico.
  windows:
    generate: true
    image_path: "assets/icon/icon.png"
    icon_size: 48   # 48 ≤ N ≤ 256, default 48

  # macOS: emit every required size into macos/Runner/Assets.xcassets/AppIcon.appiconset.
  macos:
    generate: true
    image_path: "assets/icon/icon.png"
```

Run:

```shell
dart run flutter_launcher_icons_flavors generate
```

(`generate` is the default subcommand — `dart run flutter_launcher_icons_flavors` with no args is equivalent.)

Expected output:

```text
• Creating default icons Android
• Overwriting the default Android launcher icon with a new icon
• Overwriting default iOS launcher icon with new icon
Creating Icons for Web...
Creating Icons for Windows...
Creating Icons for macOS...

✓ Successfully generated launcher icons
```

Commit the generated icon files to your repo. Re-run any time you change `image_path` or the per-platform options.

---

## Multi-flavor (consolidated)

For projects with build flavors (`dev`, `staging`, `prod`, etc.), use a single `flutter_launcher_icons_flavors.yaml` instead of one config per flavor. Keys in `defaults:` are deep-merged into every flavor; per-flavor blocks override and may set explicit `null` to **delete** an inherited key.

```yaml
# flutter_launcher_icons_flavors.yaml
version: 1

defaults:
  android: "launcher_icon"
  ios: true
  min_sdk_android: 24
  remove_alpha_ios: true
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/foreground-default.png"
  web:
    generate: true
    background_color: "#FFFFFF"
    theme_color: "#0175C2"

flavors:
  dev:
    image_path: "assets/icon/icon-dev.png"
    adaptive_icon_background: "#FF8800"           # override default
    adaptive_icon_foreground: "assets/icon/fg-dev.png"
    web:
      image_path: "assets/icon/icon-dev.png"

  staging:
    image_path: "assets/icon/icon-staging.png"
    adaptive_icon_background: "#9933CC"
    adaptive_icon_foreground: "assets/icon/fg-staging.png"
    web:
      image_path: "assets/icon/icon-staging.png"

  prod:
    image_path: "assets/icon/icon-prod.png"
    adaptive_icon_background: "#0175C2"
    adaptive_icon_foreground: "assets/icon/fg-prod.png"
    web:
      image_path: "assets/icon/icon-prod.png"
      theme_color: "#003E70"                      # override default
    macos:
      generate: true
      image_path: "assets/icon/icon-prod.png"     # only prod ships a macOS app
```

Build a single flavor, a subset, or all of them:

```shell
dart run flutter_launcher_icons_flavors generate                       # all flavors
dart run flutter_launcher_icons_flavors generate --flavor dev
dart run flutter_launcher_icons_flavors generate --flavor dev --flavor staging
dart run flutter_launcher_icons_flavors generate --all-flavors         # equivalent to no flag
```

> **Default behavior:** with the consolidated file present, omitting both `--flavor` and `--all-flavors` builds **every** flavor declared in the file. This matches the legacy per-flavor-file layout and the principle of least surprise. Pass `--flavor <name>` (repeatable) to narrow.

### Deleting an inherited default

Set the key to explicit `null` (YAML `~` works too):

```yaml
defaults:
  windows:
    generate: true
    image_path: "assets/icon/icon.png"

flavors:
  dev:
    windows: ~          # no Windows icons for dev flavor
```

This is materially different from omitting the key (which keeps the default). See [Deep-merge rules](#deep-merge-rules-multi-flavor).

### Listing what's available

```shell
dart run flutter_launcher_icons_flavors generate --list-flavors
```

Prints the flavors declared in the consolidated file (or discovered as legacy per-flavor files) and exits.

---

## Legacy multi-flavor layout

The original `flutter_launcher_icons` convention — one `flutter_launcher_icons-<flavor>.yaml` per flavor — **still works** in 0.15.x.

```text
project/
├── flutter_launcher_icons-dev.yaml
├── flutter_launcher_icons-staging.yaml
└── flutter_launcher_icons-prod.yaml
```

Running `generate` discovers every matching file and builds them all by default (no `--flavor` required, matching the upstream behavior).

If a `flutter_launcher_icons_flavors.yaml` is *also* present, the consolidated file wins and a warning is emitted listing the ignored legacy files. Use `--strict` to escalate that warning to an exit-65 error in CI:

```shell
dart run flutter_launcher_icons_flavors generate --strict
```

Convert the legacy files into the consolidated format automatically:

```shell
dart run flutter_launcher_icons_flavors migrate
```

See [`migrate`](#migrate) below.

---

## CLI reference

The package ships a single binary with three subcommands plus a default-subcommand shortcut.

| Subcommand | Default? | Purpose |
| --- | --- | --- |
| [`generate`](#generate) | ✓ | Produce launcher icons from a config file. |
| [`migrate`](#migrate) |  | Convert legacy per-flavor files into a consolidated file. |
| [`doctor`](#doctor) |  | Report environment, detected configs, conflicts, and resolved source. |

Top-level help:

```shell
dart run flutter_launcher_icons_flavors --help
dart run flutter_launcher_icons_flavors <subcommand> --help
```

### `generate`

```shell
dart run flutter_launcher_icons_flavors generate [flags]
```

| Flag | Type | Default | Meaning |
| --- | --- | --- | --- |
| `-f`, `--file <path>` | `String` | auto-discover | Explicit config file. Wins over every auto-discovered source. Path may be absolute or relative to `--prefix`. |
| `-p`, `--prefix <path>` | `String` | `.` | Project root for config discovery, asset resolution, and platform-folder writes. Useful in monorepos and tests. |
| `--flavor <name>` | repeatable | none | Build only the listed flavor(s). Each occurrence adds one name. When omitted (and `--all-flavors` is not passed), every flavor in the source is built. |
| `--all-flavors` | flag | `false` | Build every flavor discovered in the chosen source. Equivalent to passing no selector at all (kept for explicitness and CI clarity). Mutually exclusive with `--flavor`. |
| `--list-flavors` | flag | `false` | Print the available flavor names and exit. |
| `--continue-on-error` | flag | `false` | Don't stop at the first failing flavor; report a summary at the end. Exit code is the maximum severity seen. |
| `--strict` | flag | `false` | Promote the "consolidated + legacy coexisting" warning to an exit-65 error. Recommended in CI. |
| `-v`, `--verbose` | flag | `false` | Extra diagnostics. |

### `migrate`

```shell
dart run flutter_launcher_icons_flavors migrate [flags]
```

Converts every `flutter_launcher_icons-<flavor>.yaml` in `--prefix` into a single `flutter_launcher_icons_flavors.yaml`. Defaults are non-destructive:

- Each legacy file is **backed up** to `<original>.bak`.
- The originals are **left in place** unless `--in-place` is passed.
- An existing `flutter_launcher_icons_flavors.yaml` is **never overwritten** unless `--force` is passed.

After writing the file, `migrate` prints a **promotion candidates** report — every key whose value is identical across all flavors. Move those into the `defaults:` block by hand if you want the output further DRYed.

| Flag | Type | Default | Meaning |
| --- | --- | --- | --- |
| `-p`, `--prefix <path>` | `String` | `.` | Project root. |
| `--dry-run` | flag | `false` | Print the resulting YAML to stdout, write nothing. |
| `--in-place` | flag | `false` | Delete the legacy files after a successful migration. `.bak` copies are still kept. |
| `--force` | flag | `false` | Overwrite an existing `flutter_launcher_icons_flavors.yaml`. |

### `doctor`

```shell
dart run flutter_launcher_icons_flavors doctor [-p <prefix>] [-v]
```

Read-only diagnostic. Prints:

1. Package version + resolved prefix.
2. Every config source the resolver considered, and whether each was found.
3. The **winner** (which file `generate` would actually load) and the **reason** it won.
4. Any **ignored** sources (e.g. legacy files shadowed by a consolidated file).
5. The list of flavors discovered, with per-flavor platform toggles when `-v` is passed.
6. Android Gradle detection: which `build.gradle{.kts}` was found and what `min_sdk_android` was auto-detected (including the matched pattern).
7. Any **deprecated keys** still in use (e.g. `flutter_icons:` in `pubspec.yaml`).

Exits **0** unless the project is actually broken (no config at all, or an unparseable consolidated file), in which case it exits **65** so CI gates can surface the problem.

---

## Configuration schema

All examples below show the **single-flavor** `flutter_launcher_icons.yaml` form. The same keys work inside `defaults:` or any flavor block in the consolidated `flutter_launcher_icons_flavors.yaml`.

### Top-level keys

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `image_path` | `String` | — | Source PNG used by every enabled platform unless overridden. |
| `image_path_android` | `String` | `image_path` | Android-specific source override. |
| `image_path_ios` | `String` | `image_path` | iOS-specific source override. |
| `android` | `bool` \| `String` | `false` | `true` uses the default filename `ic_launcher`; a string sets the filename (without extension); `false` skips Android. |
| `ios` | `bool` \| `String` | `false` | `true` uses the default Asset Catalog name `AppIcon`; a string sets it; `false` skips iOS. |
| `min_sdk_android` | `int` | `24` | Android minSdk floor. Below 26, only legacy icons are emitted; at 26+, adaptive icons too. **Default changed from 21 → 24 in 0.15.0.** |
| `copy_mipmap_xxxhdpi_to_drawable` | `bool` | `false` | If `true`, copies the generated `mipmap-xxxhdpi/<icon>.png` into the same flavor's `drawable/` folder under the same filename. Useful when other code (notifications, widgets) needs the icon as a `drawable` resource. |

### Android adaptive icons

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `adaptive_icon_background` | `String` | — | Either a color (`#RRGGBB`) or a path to a background image. Required when an adaptive foreground is set. |
| `adaptive_icon_foreground` | `String` | — | Path to a foreground image. Should be a square PNG with the icon's safe zone in the central 66 % (Android masks the outer 33 %). |
| `adaptive_icon_foreground_inset` | `int` (0–100) | `16` | Percentage of additional padding around the foreground. Increase if your foreground feels too tight to the mask edge. |
| `adaptive_icon_monochrome` | `String` | — | Path to a Android-13+ themed-icon foreground (white-on-transparent PNG). Used when the user enables themed icons on their device. |

If `adaptive_icon_foreground` is set but `adaptive_icon_background` is not, the build fails with a clear error.

### iOS specifics

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `remove_alpha_ios` | `bool` | `false` | Strip the alpha channel before writing the icon. The App Store **rejects icons with alpha**; set this to `true` for the production build. |
| `background_color_ios` | `String` (`#RRGGBB`) | `#FFFFFF` | Color used as the opaque background when `remove_alpha_ios` is `true`. |
| `image_path_ios_dark_transparent` | `String` | — | iOS 18+ dark-mode variant. Transparent PNG; iOS composites it over the system background. |
| `image_path_ios_tinted_grayscale` | `String` | — | iOS 18+ tinted variant. Already-grayscale PNG; iOS applies the user-chosen tint. |
| `desaturate_tinted_to_grayscale_ios` | `bool` | `false` | If `true`, the tool desaturates `image_path_ios_tinted_grayscale` for you so you can ship a single colored source. |

### Web

```yaml
web:
  generate: true
  image_path: "assets/icon/icon.png"
  background_color: "#FFFFFF"
  theme_color: "#0175C2"
```

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `generate` | `bool` | `false` | Master switch. Without it, the rest of the `web:` block is ignored. |
| `image_path` | `String` | top-level `image_path` | Source PNG. |
| `background_color` | `String` (`#RRGGBB`) | — | Written into `web/manifest.json` under `background_color`. |
| `theme_color` | `String` (`#RRGGBB`) | — | Written into `web/manifest.json` under `theme_color`. |

Outputs: `web/favicon.png`, `web/icons/Icon-192.png`, `web/icons/Icon-512.png`, `web/icons/Icon-maskable-192.png`, `web/icons/Icon-maskable-512.png`, and the updated `web/manifest.json` with `<link>` references rewritten.

### Windows

```yaml
windows:
  generate: true
  image_path: "assets/icon/icon.png"
  icon_size: 48
```

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `generate` | `bool` | `false` | Master switch. |
| `image_path` | `String` | top-level `image_path` | Source PNG. |
| `icon_size` | `int` (48–256) | `48` | Resolution of the embedded `.ico` representations. |

Outputs: `windows/runner/resources/app_icon.ico`.

### macOS

```yaml
macos:
  generate: true
  image_path: "assets/icon/icon.png"
```

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `generate` | `bool` | `false` | Master switch. |
| `image_path` | `String` | top-level `image_path` | Source PNG. |

Outputs: every Apple-required size into `macos/Runner/Assets.xcassets/AppIcon.appiconset/`, plus an updated `Contents.json`.

---

## Source-resolution precedence

When you run `generate` (without `--file`), the resolver searches for a config in this order and stops at the first hit:

1. `--file <path>` — explicit. Missing file is a hard error (exit 65).
2. `<prefix>/flutter_launcher_icons_flavors.yaml` — **consolidated multi-flavor**.
3. `<prefix>/flutter_launcher_icons-*.yaml` — **legacy multi-flavor** (zero or more files).
4. `<prefix>/flutter_launcher_icons.yaml` — **single-config**.
5. `<prefix>/pubspec.yaml` with a top-level `flutter_launcher_icons:` (or deprecated `flutter_icons:`) block — **pubspec inline**.

If none match, the resolver throws `NoConfigFoundException` and exits **65**.

When a **consolidated** file coexists with **legacy** files (case 2 + 3), the consolidated file wins, the legacy files are ignored, and a warning is emitted. `--strict` escalates that warning to an exit-65 error — useful in CI to force a clean migration.

Run `doctor` to see exactly which source the resolver picked and why.

---

## Deep-merge rules (multi-flavor)

When resolving a flavor in the consolidated file, the loader deep-merges `defaults:` and the flavor block as follows:

- **Maps** merge **recursively**, key by key. `defaults.web.background_color = "#FFFFFF"` and `flavors.dev.web = { theme_color: "#FF0000" }` produce `{ background_color: "#FFFFFF", theme_color: "#FF0000" }` for `dev`.
- **Scalars** in the flavor block **replace** the inherited value.
- **Lists** in the flavor block **replace** the inherited list (no element merging — this would be ambiguous).
- **Explicit `null`** (or YAML `~`) **deletes** the inherited key. This is the only way to *turn off* a default per-flavor; omitting the key keeps the default.

Examples:

```yaml
defaults:
  android: "launcher_icon"
  web:
    generate: true
    background_color: "#FFFFFF"
    theme_color: "#000000"

flavors:
  prod:
    web:
      theme_color: "#003E70"
    # Resolves to:
    #   android: "launcher_icon"          (inherited)
    #   web:
    #     generate: true                  (inherited)
    #     background_color: "#FFFFFF"     (inherited)
    #     theme_color: "#003E70"          (overridden)

  internal:
    android: ~
    # Resolves to:
    #   web:
    #     generate: true
    #     background_color: "#FFFFFF"
    #     theme_color: "#000000"
    # (android key is deleted; Android icons are NOT generated for `internal`.)
```


---

## Exit codes

| Code | Meaning |
| --- | --- |
| **0** | Success. |
| **1** | Runtime / I/O failure during generation (e.g. source PNG missing, disk full, asset write failed). |
| **64** | Usage error. Unknown flavor, conflicting flags (`--flavor` + `--all-flavors`), unparseable legacy file during `migrate`, etc. |
| **65** | Configuration error. Schema validation failed, no config found, `--strict` coexistence, or `doctor` detected a genuinely broken project. |

Exit-code convention follows `sysexits.h`: **64 = the user did something wrong**, **65 = the data is wrong**, **1 = the runtime barfed**.

---

## Migrating from `flutter_launcher_icons`

1. **Rename the dependency.** Replace `flutter_launcher_icons:` with `flutter_launcher_icons_flavors:` in `dev_dependencies`, run `flutter pub get`.
2. **Update CLI invocations.** `dart run flutter_launcher_icons` → `dart run flutter_launcher_icons_flavors generate` (or just `dart run flutter_launcher_icons_flavors` — `generate` is the default subcommand).
3. **Move `pubspec.yaml` blocks.** The `flutter_icons:` block in `pubspec.yaml` still works but prints a deprecation warning. It will be **removed in 0.17**. Move it to a top-level `flutter_launcher_icons.yaml` file.
4. **Audit `min_sdk_android`.** The default rose **21 → 24**. If you must keep `21`, set `min_sdk_android: 21` explicitly. Run `doctor` to see what is currently in effect.
5. **(Optional) Consolidate flavors.** If you used the legacy `flutter_launcher_icons-<flavor>.yaml` layout, run `dart run flutter_launcher_icons_flavors migrate` to convert it. Originals are kept (`.bak`) and not deleted unless you pass `--in-place`.
6. **(Optional) Gate CI with `--strict`.** Add `dart run flutter_launcher_icons_flavors generate --strict` to your CI to catch a half-migrated state where both the consolidated file and legacy files exist.


---

## Troubleshooting / FAQ

**Q. I ran `generate` and nothing happened.**
You probably have no enabled platform. Set at least one of `android`, `ios`, `web.generate`, `windows.generate`, or `macos.generate` to a truthy value. Run `doctor` to see what the tool thinks it should do.

**Q. `doctor` says my Android `min_sdk_android` is "not auto-detected".**
The detector reads `android/app/build.gradle` and `build.gradle.kts` and accepts patterns like `minSdkVersion 24`, `minSdk = 24`, and `minSdk = flutter.minSdkVersion` (the last one is recursively resolved via `local.properties` → `flutter.sdk`). If you use a version catalog (`libs.versions.toml`) or a convention plugin, the detector can't see your value — set `min_sdk_android` explicitly in your config.

**Q. The tool wrote my Android icon but `flutter run` still shows the old one.**
Run `flutter clean` and rebuild. Android caches the manifest aggressively, and Gradle won't pick up a new mipmap unless the cache is cleared.

**Q. iOS App Store Connect rejects my icon with "alpha channel".**
Set `remove_alpha_ios: true` and (optionally) `background_color_ios: "#FFFFFF"`. Re-run `generate` and re-upload.

**Q. How does `generate` choose what to build when I don't pass any selector?**
With no `--flavor` and no `--all-flavors`, the consolidated file builds **every** flavor declared in `flavors:`. The legacy per-flavor-file layout does the same. Pass `--flavor <name>` (repeatable) to narrow.

**Q. `migrate` says "no `flutter_launcher_icons` block found" in one of my legacy files.**
Old versions of the upstream tool also accepted `flutter_icons:` as the inner block — `migrate` supports both. If your file uses a different top-level key, fix it by hand.

**Q. How do I disable a platform for one flavor only?**
Set the key to explicit `null`:

```yaml
defaults:
  windows:
    generate: true
flavors:
  internal:
    windows: ~
```

**Q. Can I generate icons for a flavor whose name contains hyphens / dots / unicode?**
Yes; the loader accepts any non-empty YAML string as a flavor key. The legacy file-discovery regex (`flutter_launcher_icons-<flavor>.yaml`) is also permissive — any non-empty string between the dash and `.yaml` is captured as the flavor name. We recommend sticking to `[A-Za-z0-9_-]+` to stay friendly with Gradle and Xcode flavor names.

---

## Contributing

Issues and PRs welcome at [`tmura-ido/flutter_launcher_icons_flavors`](https://github.com/tmura-ido/flutter_launcher_icons_flavors).

Local development checklist:

```shell
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

CI matrix: `{ubuntu, macos, windows} × {Flutter 3.41.9, stable}`, plus `pana` and `dart pub publish --dry-run` on the Linux + 3.41.9 cell. PRs must be green on every cell. The `main` branch is protected — required checks include all matrix cells, linear history, and signed commits.

The repo also ships three example projects under [`example/`](example/):

- [`default_example/`](example/default_example/) — single-config workflow.
- [`flavors/`](example/flavors/) — legacy per-flavor layout (one file per flavor).
- [`flavors_consolidated/`](example/flavors_consolidated/) — modern consolidated layout.

Run each example's `flutter create .` before invoking the tool.

---

## License

MIT. See [`LICENSE`](LICENSE).

### Special thanks

- Brendan Duncan for the underlying [`image`](https://pub.dev/packages/image) package.
- The original `flutter_launcher_icons` maintainers and contributors — this fork stands on years of their work.
