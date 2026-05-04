# Flavors guide

`flutter_launcher_icons_flavored` adds a consolidated, deep-merged configuration file for multi-flavor Flutter projects. This guide is the long-form reference; the [README](../README.md) has the quick start.

## 1. Why a consolidated file

Pre-0.15 multi-flavor setups required **one YAML file per flavor** in your repo root: `flutter_launcher_icons-dev.yaml`, `flutter_launcher_icons-staging.yaml`, `flutter_launcher_icons-prod.yaml`, etc. Shared values (Android filename, `min_sdk_android`, iOS alpha rules) had to be copy-pasted across every file, and adding a flavor meant adding another root-level file.

The consolidated `flutter_launcher_icons_flavors.yaml` solves that:

- **Single source of truth** — every flavor lives in one file.
- **Deep-merged `defaults:`** — shared values are written once and inherited by every flavor.
- **Explicit `null` deletes** — a flavor can opt out of an inherited key.
- **Fewer files in the repo root** — adding a flavor is one new map entry.

The legacy per-flavor files are still supported (with a deprecation warning when both layouts coexist) and the `migrate` command automates conversion.

## 2. Schema reference

Full annotated example covering every supported key:

```yaml
# REQUIRED. Schema version. Currently always 1.
version: 1

# OPTIONAL. Same shape as a single-flavor config block. Every key here is
# deep-merged into every flavor below.
defaults:
  android: "launcher_icon"          # bool | filename string
  ios: true                         # bool | filename string
  image_path: "assets/icon/base.png"
  min_sdk_android: 24               # default 24 in 0.15.0+
  remove_alpha_ios: true
  background_color_ios: "#ffffff"

  # Adaptive icon defaults (Android 8+).
  adaptive_icon_background: "#0175C2"
  adaptive_icon_foreground: "assets/icon/fg.png"
  adaptive_icon_foreground_inset: 16
  adaptive_icon_monochrome: "assets/icon/mono.png"

  # iOS 18+ variants.
  image_path_ios_dark_transparent: "assets/icon/dark.png"
  image_path_ios_tinted_grayscale: "assets/icon/tinted.png"
  desaturate_tinted_to_grayscale_ios: false

  web:
    generate: true
    image_path: "assets/icon/web.png"
    background_color: "#ffffff"
    theme_color: "#0175C2"

  windows:
    generate: true
    image_path: "assets/icon/win.png"
    icon_size: 48                   # 48..256

  macos:
    generate: true
    image_path: "assets/icon/macos.png"

# REQUIRED. Map of flavor name -> per-flavor config block.
# Flavor name regex: ^[A-Za-z0-9][A-Za-z0-9_-]*$
flavors:
  dev:
    image_path: "assets/icon/icon-dev.png"
    adaptive_icon_background: "#FF8800"

  staging:
    image_path: "assets/icon/icon-staging.png"

  prod:
    image_path: "assets/icon/icon-prod.png"
    # Disable web generation for prod, even though defaults enable it.
    web: null
```

Per-flavor blocks accept **the same keys as `defaults:`**.

## 3. Deep merge semantics

The `defaults:` block is merged into each flavor block before the resulting config is validated and used.

Rules:

1. **Maps merge recursively.** `defaults.web.background_color` and `flavors.dev.web.theme_color` both end up in the resolved `web` block.
2. **Scalars and lists override wholesale.** A flavor's `image_path` replaces the default `image_path`; lists do not concatenate.
3. **Explicit `null` in a flavor deletes the inherited key.** Use this to turn off an inherited platform or feature.

### Worked example: deletion via `null`

Given:

```yaml
defaults:
  adaptive_icon_background: "#FFFFFF"
  web:
    generate: true
    image_path: "assets/web.png"

flavors:
  prod:
    adaptive_icon_background: null   # delete; no adaptive bg for prod
    web: null                         # disable web entirely for prod
  dev: {}                              # inherits both defaults verbatim
```

Resolved configs:

```yaml
prod:
  # adaptive_icon_background: <absent>
  # web: <absent>

dev:
  adaptive_icon_background: "#FFFFFF"
  web:
    generate: true
    image_path: "assets/web.png"
```

If you instead want to **override** rather than **delete**, supply a value:

```yaml
flavors:
  prod:
    adaptive_icon_background: "#000000"   # override, not delete
```

## 4. Source resolution precedence

When you run `generate`, the CLI picks exactly one source. The first match wins:

1. **`flutter_launcher_icons_flavors.yaml`** — the consolidated file (this guide's subject).
2. **`flutter_launcher_icons-<flavor>.yaml`** — legacy per-flavor files (matched by glob).
3. **`flutter_launcher_icons.yaml`** — single-flavor config.
4. **`flutter_icons:` block in `pubspec.yaml`** — deprecated in 0.15.x; removed in 0.17.

`-f <path>` / `--file <path>` bypasses discovery entirely and loads the named file (which may itself be either a single-config or a consolidated multi-flavor file).

## 5. Coexistence and `--strict`

If both a `flutter_launcher_icons_flavors.yaml` **and** legacy `flutter_launcher_icons-<flavor>.yaml` files are present in the prefix directory, the consolidated file is used and a warning is printed:

```
warning: ignoring legacy config files because flutter_launcher_icons_flavors.yaml is present:
  - flutter_launcher_icons-dev.yaml
  - flutter_launcher_icons-prod.yaml
Run `dart run flutter_launcher_icons_flavored migrate` to merge them, or delete the legacy files.
```

Pass `--strict` to escalate this warning to a fatal error (exit code **65**):

```shell
dart run flutter_launcher_icons_flavored generate --all-flavors --strict
```

This is the recommended setting for CI: it makes leftover legacy files an explicit failure rather than a silent ignore.

## 6. Migration walkthrough

### Step 1 — Inspect

```shell
dart run flutter_launcher_icons_flavored migrate --dry-run
```

This prints the YAML that *would* be written to `flutter_launcher_icons_flavors.yaml`, plus a **promotion candidates** report listing keys whose values are identical across every flavor block. Auto-promotion to `defaults:` is intentionally **not** done — you decide which candidates are real shared defaults and which are coincidental matches.

### Step 2 — Apply

```shell
dart run flutter_launcher_icons_flavored migrate
```

Writes `flutter_launcher_icons_flavors.yaml`. Each legacy file is copied to `<original>.bak` first; the originals are left in place. Pass `--in-place` to delete the originals after writing (the `.bak` copies are kept regardless). Pass `--force` to overwrite an existing `flutter_launcher_icons_flavors.yaml`.

### Before / after

Before — three files in the repo root:

```yaml
# flutter_launcher_icons-dev.yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  min_sdk_android: 24
  image_path: "assets/icon-dev.png"
```

```yaml
# flutter_launcher_icons-staging.yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  min_sdk_android: 24
  image_path: "assets/icon-staging.png"
```

```yaml
# flutter_launcher_icons-prod.yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  min_sdk_android: 24
  image_path: "assets/icon-prod.png"
```

After — one file:

```yaml
# flutter_launcher_icons_flavors.yaml
version: 1
defaults: {}    # promotion candidates: android, ios, min_sdk_android
flavors:
  dev:
    android: "launcher_icon"
    ios: true
    min_sdk_android: 24
    image_path: "assets/icon-dev.png"
  staging:
    android: "launcher_icon"
    ios: true
    min_sdk_android: 24
    image_path: "assets/icon-staging.png"
  prod:
    android: "launcher_icon"
    ios: true
    min_sdk_android: 24
    image_path: "assets/icon-prod.png"
```

After moving the candidates into `defaults:` manually:

```yaml
version: 1
defaults:
  android: "launcher_icon"
  ios: true
  min_sdk_android: 24
flavors:
  dev:
    image_path: "assets/icon-dev.png"
  staging:
    image_path: "assets/icon-staging.png"
  prod:
    image_path: "assets/icon-prod.png"
```

Then commit and delete the `.bak` files when you're satisfied.

## 7. Troubleshooting

### Invalid flavor name → exit 65

Flavor keys must match `^[A-Za-z0-9][A-Za-z0-9_-]*$`. A key like `flavors.foo bar:` (with a space) or `flavors._dev:` (leading underscore) fails validation:

```
ERROR: Invalid flavor name "_dev". Must match ^[A-Za-z0-9][A-Za-z0-9_-]*$.
```

### Unknown top-level key → exit 65

Only `version`, `defaults`, and `flavors` are allowed at the top level of `flutter_launcher_icons_flavors.yaml`. A typo like `defualts:` is reported as:

```
ERROR: Unknown top-level key "defualts" in flutter_launcher_icons_flavors.yaml.
       Allowed: version, defaults, flavors.
```

### Missing `--flavor` / `--all-flavors` → exit 64

With a multi-flavor consolidated file present, you must pick which flavor(s) to build:

```
ERROR: Multiple flavors are defined in flutter_launcher_icons_flavors.yaml.
       Pass --flavor <name> (repeatable) or --all-flavors to choose.
       Available: dev, staging, prod
```

Single-flavor consolidated files (one entry under `flavors:`) build the only flavor automatically.

### Unknown flavor on `--flavor` → exit 64

```
ERROR: Unknown flavor(s): qa. Available: dev, staging, prod
```

### Legacy + consolidated coexistence with `--strict` → exit 65

See [§5 Coexistence and `--strict`](#5-coexistence-and---strict).
