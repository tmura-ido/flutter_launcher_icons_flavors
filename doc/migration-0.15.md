# Migrating to `flutter_launcher_icons_flavored` 0.15

Audience: existing `flutter_launcher_icons` users on 0.13.x or 0.14.x.

## TL;DR checklist

- [ ] Replace `flutter_launcher_icons` with `flutter_launcher_icons_flavored: ^0.15.0` in `dev_dependencies`.
- [ ] Update CLI invocations: `dart run flutter_launcher_icons` → `dart run flutter_launcher_icons_flavored generate`.
- [ ] If you used `flutter_icons:` in `pubspec.yaml`, move it to `flutter_launcher_icons.yaml` (the inline block is deprecated and prints a warning).
- [ ] Decide whether to bump `min_sdk_android` to **24** (new default) or pin the old **21** explicitly in your config.
- [ ] If you have multiple legacy `flutter_launcher_icons-<flavor>.yaml` files, run `dart run flutter_launcher_icons_flavored migrate` to consolidate them.

## Step 1 — Rename dependency

```diff
 dev_dependencies:
-  flutter_launcher_icons: ^0.14.4
+  flutter_launcher_icons_flavored: ^0.15.0
```

Then `flutter pub get`.

## Step 2 — Update CLI invocation

The bare-invocation behavior is preserved, but the canonical form now uses subcommands:

```diff
- dart run flutter_launcher_icons
+ dart run flutter_launcher_icons_flavored generate
```

```diff
- dart run flutter_launcher_icons -f my_config.yaml
+ dart run flutter_launcher_icons_flavored generate -f my_config.yaml
```

A plain `dart run flutter_launcher_icons_flavored` (no subcommand, no flags) still defaults to `generate`, but explicit subcommands are recommended in scripts and CI.

Search-and-replace targets in your codebase:

- Shell scripts / CI YAML: `flutter_launcher_icons` (the package binary name).
- Dart imports (rare; usually only test code): `package:flutter_launcher_icons/...` → `package:flutter_launcher_icons_flavored/...`.

## Step 3 — Decide on consolidated config

If you have **one** `flutter_launcher_icons.yaml` and no flavors: nothing to do here.

If you have multiple legacy `flutter_launcher_icons-<flavor>.yaml` files, preview the consolidation:

```shell
dart run flutter_launcher_icons_flavored migrate --dry-run
```

Inspect the printed YAML and the "promotion candidates" report. Then:

```shell
dart run flutter_launcher_icons_flavored migrate
```

This writes a single `flutter_launcher_icons_flavors.yaml`, copies each legacy file to `<name>.bak`, and leaves the originals in place. Add `--in-place` to delete the originals (backups kept) or `--force` to overwrite an existing target.

Full walkthrough: [`doc/flavors.md` §6](flavors.md#6-migration-walkthrough).

## Step 4 — `min_sdk_android` decision

The default for `min_sdk_android` was raised **21 → 24** in 0.15.0. This affects which adaptive-icon outputs are generated.

- If you're fine with 24 (matches Flutter's own recent defaults): no action needed.
- If you must support API 21–23, set it explicitly:

  ```yaml
  flutter_launcher_icons:
    min_sdk_android: 21
  ```

  Or in the consolidated file:

  ```yaml
  defaults:
    min_sdk_android: 21
  ```

## Step 5 — Replace `flutter_icons:` pubspec key

The inline `flutter_icons:` block in `pubspec.yaml` still works in 0.15.x, but each invocation prints a deprecation warning. **It will be removed in 0.17.**

Move it into a dedicated file:

```yaml
# flutter_launcher_icons.yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icon/icon.png"
  # ...your existing keys...
```

Then delete the `flutter_icons:` block from `pubspec.yaml`.

## Step 6 — Breaking changes table

| # | Change | Before | After |
| --- | --- | --- | --- |
| 1 | Package name | `flutter_launcher_icons` | `flutter_launcher_icons_flavored` |
| 2 | CLI canonical form | `dart run flutter_launcher_icons` | `dart run flutter_launcher_icons_flavored generate` |
| 3 | `min_sdk_android` default | `21` | `24` (set explicitly to override) |
| 4 | Multi-flavor consolidated config | single legacy `flutter_launcher_icons-<flavor>.yaml` per flavor (still supported) | single `flutter_launcher_icons_flavors.yaml` with `defaults:` + `flavors:` (preferred) |
| 5 | Multi-flavor flavor selection (consolidated only) | n/a | `--flavor <name>` or `--all-flavors` required when more than one flavor is defined; exits **64** otherwise |
| 6 | Bare invocation | runs generate | runs generate (compatibility shim) — but explicit subcommands are recommended |
| 7 | `flutter_icons:` in `pubspec.yaml` | first-class | deprecated with warning; removed in 0.17 |

## Step 7 — Non-breaking improvements

These come along for free; no config changes needed.

- **Kotlin DSL gradle support.** `android/app/build.gradle.kts` is parsed for `minSdk` alongside the Groovy `build.gradle`.
- **Async I/O on hot paths.** Icon resizing/encoding no longer blocks the event loop unnecessarily; faster on multi-flavor builds.
- **Better error messages.** Schema and validation failures now use exit code 65 (was 1) and print a clear "ERROR:" line.
- **`doctor` command.** `dart run flutter_launcher_icons_flavored doctor` reports Dart/Flutter versions, detected configs, source resolution, and any conflicts.
- **`--list-flavors` and `--continue-on-error`.** Inspect what would be built, or build everything and collect failures into a summary instead of stopping at the first one.
- **`--strict` flag.** Promote the legacy/consolidated coexistence warning to a fatal error (exit 65) — recommended in CI.
- **Path-handling fixes.** `getFlavors()` now respects `--prefix` (it previously hard-coded `Directory('.')`); path construction uses `package:path` everywhere.

## Step 8 — Verifying the migration

```shell
dart run flutter_launcher_icons_flavored doctor
dart run flutter_launcher_icons_flavored generate --all-flavors --strict
```

`doctor` should report a single resolved source with no conflicts, and `generate --all-flavors --strict` should succeed cleanly with no coexistence warnings.

If anything is unexpected, file an issue at [`tmura-ido/flutter_launcher_icons_flavored/issues`](https://github.com/tmura-ido/flutter_launcher_icons_flavored/issues).
