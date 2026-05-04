# Phase 1 — Internal refactor + project rename

> **Depends on**: nothing (start here).
> **User-visible behavior change**: only the package name (pubspec dependency rename). All existing configs and CLI invocations otherwise behave identically.
> **Goal**: pure refactor and rename under existing tests so subsequent phases can build on a clean foundation without bisect-coupling refactor with feature work.

---

## 0. Context (everything you need to know without reading other files)

You are working on the `flutter_launcher_icons` Dart package (current version 0.14.4) at the repo root. It generates iOS/Android/web/Windows/macOS launcher icons from a config file. We are upgrading to support Flutter 3.41.9 / Dart 3.10, adding a new consolidated multi-flavor config in later phases, and renaming the package.

Current state pertinent to this phase:

- Entry point: `bin/main.dart` → `lib/main.dart` (flat `ArgParser`, no subcommands).
- `lib/main.dart` `getFlavors()` lists `Directory('.')` for regex `^flutter_launcher_icons-(.*).yaml$`. `--prefix` is silently ignored — this is a real bug.
- `lib/android.dart` has a `// TODO(p-mazhnik): support prefixPath`. The same omission affects adaptive icons, mipmap XML, manifest writes, colors.xml, min_sdk lookup. iOS / web / windows / macos generators have similar half-threaded `prefixPath` support.
- `lib/config/config.dart` declares `Config` with implicit defaults (`adaptiveIconForegroundInset = 16`, `removeAlphaIOS = false`, etc.) and `dynamic android` / `dynamic ios` (path-or-bool). This makes "user omitted vs. user-set-to-default" indistinguishable, which later merge semantics need.
- `lib/constants.dart` uses string concatenation (`+ '/' +`) in places that should use `path.join`.
- `lib/utils.dart` decodes images with a falsely nullable `Future<Image?>` return type (already throws on null).
- `lib/pubspec_parser.dart` is dead code (no consumer outside its own file).
- `analysis_options.yaml` references obsolete lints (e.g. `package_api_docs`, `package_prefixed_library_names`, `prefer_generic_function_type_aliases`); has a stale `strong-mode: implicit-dynamic` block.
- Logger (`lib/logger.dart`) is minimal; bare `print` / `stderr.writeln` are scattered.

Binding decisions (do not deviate):

- Package rename: `flutter_launcher_icons` → **`flutter_launcher_icons_flavored`** in `pubspec.yaml` `name:`. Update all `import 'package:flutter_launcher_icons/...'` to `package:flutter_launcher_icons_flavored/...` across `lib/`, `bin/`, `test/`, `example/`.
- **Filenames the package consumes do NOT change.** `flutter_launcher_icons.yaml`, `flutter_launcher_icons-<flavor>.yaml`, `flutter_launcher_icons_flavors.yaml`, and the pubspec key `flutter_launcher_icons:` stay exactly as-is. Only the import name changes.
- Dart SDK floor raised to `>=3.8.0 <4.0.0` (required by json_serializable's null-aware-element output for `includeIfNull: false`; aligns with the project's Flutter 3.41.9 / Dart 3.10 target).
- Delete `lib/pubspec_parser.dart`.
- Do NOT change CLI subcommand structure here. Phase 4 introduces `CommandRunner`. In Phase 1 keep the existing flat `ArgParser`.
- Do NOT introduce the new flavors file or schema here. Phase 3.
- Do NOT change `androidDefaultAndroidMinSDK`. Phase 2.

---

## 1. In-scope work for Phase 1

### 1.1 Pubspec & rename

- `pubspec.yaml`:
  - `name: flutter_launcher_icons_flavored`
  - Bump version → `0.15.0-dev.1` (will become `0.15.0` at Phase 5).
  - Leave `homepage`/`repository`/`issue_tracker` URLs alone for now (maintainer will set them at release time in Phase 5).
  - Do not yet add `topics` / `screenshots` (Phase 2).
  - Do NOT add `funding:`.
- Rename all imports `package:flutter_launcher_icons/...` → `package:flutter_launcher_icons_flavored/...` everywhere in `lib/`, `bin/`, `test/`, `example/` (use grep + edit; verify zero remaining occurrences).
- Update any internal references that hard-code the package name in error messages / log strings to the new name **except** for filenames the tool consumes (those keep `flutter_launcher_icons.yaml` etc.).
- The `flutter_launcher_icons.code-workspace` file may be left as-is (not worth churn; optional rename).

### 1.2 Delete dead code

- Delete `lib/pubspec_parser.dart`.
- Remove any `import` of it (search `package:flutter_launcher_icons*/pubspec_parser.dart`). If any test imports it, delete that test (it's dead).

### 1.3 `PartialConfig` + `Config` split

Goal: enable later merge semantics without forcing them now. Public API unchanged.

- New file `lib/config/partial_config.dart`:
  - `@JsonSerializable(anyMap: true, checked: true, includeIfNull: false)` class `PartialConfig` mirroring every field of `Config` but with **all fields nullable**.
  - Generated via `json_serializable` (run `dart run build_runner build`).
  - No defaults applied. No required-field validation.
  - Must round-trip: `Config.fromJson(map).toPartial().toJson() == map` for fully-specified inputs.
- Refactor `lib/config/config.dart`:
  - Add `Config.fromPartial(PartialConfig partial)` factory that fills defaults (current implicit defaults move here as constants on the class) and **validates**: throws `InvalidConfigException` with field path for missing required fields.
  - Existing `Config.fromJson(Map)` becomes `Config.fromPartial(PartialConfig.fromJson(map))` — preserves backward compatible behavior (full validation immediately).
  - Add `Config.toPartial()` returning a `PartialConfig` with the same field values.
  - Public getters (`hasAndroidAdaptiveConfig`, `isCustomAndroidFile`, `isNeedingNewAndroidIcon`, etc.) remain on `Config` and keep their existing names and behavior.

### 1.4 `PlatformToggle` (replaces `dynamic` android/ios at the type level)

Goal: remove `dynamic` from internal call sites while accepting the same bool-or-string YAML inputs.

- New file `lib/config/platform_toggle.dart`:
  ```dart
  class PlatformToggle {
    const PlatformToggle._(this._kind, this._iconName);
    factory PlatformToggle.disabled() => const PlatformToggle._(_Kind.disabled, null);
    factory PlatformToggle.enabled() => const PlatformToggle._(_Kind.enabled, null);
    factory PlatformToggle.named(String iconName) => PlatformToggle._(_Kind.named, iconName);

    final _Kind _kind;
    final String? _iconName;

    bool get isEnabled => _kind != _Kind.disabled;
    bool get isCustom => _kind == _Kind.named;
    String? get customIconName => _iconName;
  }

  enum _Kind { disabled, enabled, named }
  ```
- A `JsonConverter<PlatformToggle, Object>` (`PlatformToggleConverter`) that:
  - Accepts `bool false` → `disabled()`.
  - Accepts `bool true` → `enabled()`.
  - Accepts non-empty `String` → `named(value)`.
  - Accepts `null` → `disabled()`.
  - Anything else → throws `CheckedFromJsonException` with the offending key.
  - Serializes back to `bool`/`String`.
- In `Config` and `PartialConfig`, type the `android` and `ios` fields as `PlatformToggle?` (nullable in `PartialConfig`, non-null with default `disabled()` in `Config`) annotated with `@PlatformToggleConverter()`. Keep public getters `isCustomAndroidFile`, `isNeedingNewAndroidIcon`, etc., delegating to the toggle.
- The `dynamic` typed fields are **removed** from the internal model. External users who pass bool/String values continue to work because the converter is permissive.

### 1.5 Logger upgrade

- `lib/logger.dart`: extend `FLILogger` with leveled methods:
  - `error(String)` → stderr, prefixed `✕ ERROR`.
  - `warn(String)` → stderr, prefixed `⚠ WARNING`.
  - `info(String)` → stdout.
  - `verbose(String)` → stdout when `--verbose`, otherwise suppressed (existing behavior).
- Honor the `NO_COLOR` env var (skip ANSI codes if set).
- Replace **every** call to bare `print(...)` and `stderr.writeln(...)` in `lib/` and `bin/` with the appropriate logger call. (Tests may continue using `print` for fixtures.)

### 1.6 `--prefix` correctness (the real bug)

- `lib/main.dart` `getFlavors()`: change signature to `Future<List<String>> getFlavors(String prefixPath)`. Replace `Directory('.')` with `Directory(prefixPath)`. Update the caller.
- Thread `prefixPath` (positional or named, your call — be consistent) through every generator entry point that touches the filesystem:
  - `android.dart`: `createDefaultIcons`, `createAdaptiveIcons`, `createAdaptiveMonochromeIcons`, `createMipmapXmlFile`, `overwriteExistingIcons`, `_saveNewImages`, min_sdk lookup, `colors.xml` writes, manifest writes.
  - `ios.dart`: image write paths, Contents.json path, pbxproj read.
  - `web/`, `windows/`, `macos/`: their respective root-relative paths.
- Resolve every filesystem path via `path.join(prefixPath, '<relative>')`. Remove the `// TODO(p-mazhnik): support prefixPath` comment.
- Add a regression test: running `--prefix subdir` for a project with both legacy `flutter_launcher_icons-dev.yaml` under `subdir/` and a default config under `./` discovers the flavor inside `subdir/` and ignores the one in `./`.

### 1.7 `path.join` everywhere

- Replace string concatenation in `lib/constants.dart`:
  - `androidResFolder(flavor) + 'mipmap-anydpi-v26/'` → `path.join(androidResFolder(flavor), 'mipmap-anydpi-v26')`.
  - All similar `+ '/'` patterns.
- Same sweep in `lib/android.dart` and any other generator that builds paths by concatenation.
- Add a Windows-path test: paths produced under simulated Windows separators round-trip cleanly.

### 1.8 `decodeImageFile` non-nullable

- `lib/utils.dart`: change return type from `Future<Image?>` to `Future<Image>`. Body already throws on null; just remove the `?`. Update all call sites.

### 1.9 `analysis_options.yaml` modernization

- Replace top-level `analyzer:` block — drop the `strong-mode:` subsection (`implicit-dynamic` was removed from modern analyzers).
- Add at the top:
  ```yaml
  include: package:lints/recommended.yaml
  ```
- Remove rules from the `linter.rules:` list that are deprecated/removed in current Dart releases. Concretely audit and remove if present:
  - `package_api_docs`
  - `package_prefixed_library_names`
  - `prefer_generic_function_type_aliases`
  - `unnecessary_new`
  - `prefer_void_to_null` (verify; remove only if removed from current Dart)
  - `avoid_returning_null_for_void` (verify)
  - any other lint that triggers an analyzer warning about being deprecated/removed
- Add `dev_dependency: lints: ^5.0.0` (or current major) to `pubspec.yaml`.
- Run `dart analyze --fatal-infos` and resolve everything. Use `// ignore: <rule> reason: <why>` only with explicit rationale comments.

---

## 2. Out of scope (do NOT do here)

- Do NOT introduce `CommandRunner` / subcommands. Phase 4.
- Do NOT introduce `flutter_launcher_icons_flavors.yaml` parsing or schema. Phase 3.
- Do NOT add `--flavor`, `--all-flavors`, `--list-flavors`, `--strict`, `--continue-on-error`, `--file` semantics changes. Phases 3–4.
- Do NOT add Kotlin DSL (`build.gradle.kts`) support. Phase 2.
- Do NOT bump `androidDefaultAndroidMinSDK`. Phase 2.
- Do NOT add `topics`/`screenshots` to pubspec. Phase 2.
- Do NOT migrate generator hot paths to async. Phase 2.
- Do NOT touch `README.md` / `CHANGELOG.md` content beyond what is necessary to keep the build green (you may, however, add a one-line `> _Internal refactor in progress; full release notes forthcoming._` to CHANGELOG if you wish — strictly optional).

---

## 3. File-by-file change list

| File | Action |
|---|---|
| `pubspec.yaml` | `name:` → `flutter_launcher_icons_flavored`. Bump to `0.15.0-dev.1`. Add `lints` dev dep. |
| `analysis_options.yaml` | `include: package:lints/recommended.yaml`. Remove dead rules. Drop `strong-mode` block. |
| `lib/main.dart` | Update imports. Update `getFlavors()` to take `prefixPath`. Update logger usage. |
| `bin/main.dart` | Update imports only. (CommandRunner is Phase 4.) |
| `bin/generate.dart` | Update imports. |
| `bin/flutter_launcher_icons.dart` | Update imports. (Note: filename unchanged for backward compat of `dart run` invocation; consider whether to keep this binary; if removing, update CHANGELOG. Default: keep, just fix imports.) |
| `lib/config/config.dart` | Refactor: `Config.fromPartial`, `Config.toPartial`. Type `android`/`ios` as `PlatformToggle`. |
| `lib/config/partial_config.dart` (NEW) | Nullable mirror of `Config`. |
| `lib/config/partial_config.g.dart` (generated) | `dart run build_runner build`. |
| `lib/config/platform_toggle.dart` (NEW) | Sealed-style class + `JsonConverter`. |
| `lib/config/config.g.dart` | Regenerate. |
| `lib/constants.dart` | Replace string-concat with `path.join`. |
| `lib/android.dart` | Thread `prefixPath`. `path.join`. Remove TODO. Update logger usage. |
| `lib/ios.dart`, `lib/web/**`, `lib/windows/**`, `lib/macos/**` | Thread `prefixPath`. `path.join`. Logger. |
| `lib/utils.dart` | `decodeImageFile` returns non-null `Future<Image>`. Update call sites. Logger. |
| `lib/logger.dart` | Add levels. Honor `NO_COLOR`. |
| `lib/pubspec_parser.dart` | **Delete.** |
| `lib/custom_exceptions.dart` | Update imports if any (probably none needed). |
| `test/**/*.dart` | Update package imports. Add Phase-1 regression tests (see §4). |
| `example/**/pubspec.yaml` | Update `dev_dependencies:` to `flutter_launcher_icons_flavored: ^0.15.0-dev.1` (path or version, your call — `path: ../../` is fine for in-repo examples). |

---

## 4. Tests to add (Phase 1)

All under `test/`. Target: every Phase 1 change has a regression or unit test. Existing tests must continue to pass after the rename.

- `test/config/partial_config_test.dart`:
  - Parses partial YAML (only `image_path` set, all other fields null).
  - Round-trips: `PartialConfig.fromJson(map).toJson()` equals the input map for fully-specified inputs.
  - `Config.fromJson(map).toPartial().toJson()` equals the input for fully-specified inputs.
- `test/config/platform_toggle_test.dart`:
  - `false` → `disabled()`, `isEnabled == false`.
  - `true` → `enabled()`, `isEnabled == true`, `isCustom == false`.
  - `"ic_launcher_dev"` → `named(...)`, `customIconName == "ic_launcher_dev"`.
  - `null` → `disabled()`.
  - Number/list/object → throws `CheckedFromJsonException` with the offending key path.
  - JSON round-trip: `disabled()` → `false`, `enabled()` → `true`, `named("x")` → `"x"`.
  - `Config.fromJson({"android": "ic_launcher_dev", ...})` produces `isCustomAndroidFile == true` (existing behavior preserved).
- `test/utils/prefix_threading_test.dart` (use `test_descriptor`):
  - Lay down `subdir/flutter_launcher_icons-dev.yaml` and `./flutter_launcher_icons-other.yaml`.
  - Run with `--prefix subdir` and assert: discovered flavors == `[dev]`, generators write under `subdir/...`.
- `test/utils/path_join_test.dart`:
  - `androidAdaptiveXmlFolder('dev')` produces a path with no double-slashes and uses the platform separator.
  - Round-trip with simulated Windows separators (use `path.windows` in a parameterized test).
- `test/utils/decode_image_file_test.dart`:
  - Returns non-null `Future<Image>` for valid file.
  - Throws `NoDecoderForImageFormatException` for an unrecognized file (existing behavior, but now without `?`).
- `test/main_imports_test.dart` (lightweight):
  - A trivial test that `import 'package:flutter_launcher_icons_flavored/...';` resolves. This catches missed renames.

---

## 5. Definition of Done — self-check before marking phase complete

Run through this list and report results.

- [ ] `dart pub get` succeeds.
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds.
- [ ] `dart format --set-exit-if-changed .` succeeds.
- [ ] `dart analyze --fatal-infos` reports zero issues.
- [ ] `dart test` — full suite passes. Existing tests continue to pass; new Phase-1 tests pass.
- [ ] `grep -rn 'package:flutter_launcher_icons/' lib bin test example` returns zero matches (rename complete). On Windows PowerShell: `Select-String -Path lib,bin,test,example -Recurse -Pattern 'package:flutter_launcher_icons/'`.
- [ ] `grep -rn 'TODO.*prefixPath' lib` returns zero matches.
- [ ] `grep -rn "+ '/'" lib bin` returns zero matches (path.join everywhere).
- [ ] `print(` and `stderr.writeln(` no longer appear in `lib/` or `bin/` (except logger.dart itself).
- [ ] `lib/pubspec_parser.dart` is deleted.
- [ ] `pubspec.yaml` `name` is `flutter_launcher_icons_flavored`, version is `0.15.0-dev.1`.
- [ ] `pubspec.yaml` does NOT contain a `funding:` field.
- [ ] No uses of `dynamic` for the `android`/`ios` config field types remain in `lib/config/`.
- [ ] All examples in `example/` build (`dart pub get` from each example directory succeeds; smoke-run the default example to ensure icons still generate).
- [ ] CHANGELOG.md / README.md untouched (Phase 5 owns them).

If anything fails, stop and report. Do not proceed to Phase 2 until this checklist is green.
