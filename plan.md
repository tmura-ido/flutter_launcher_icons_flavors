# `flutter_launcher_icons_flavors` — Upgrade & Consolidated Flavors Plan

> **Project rename**: `flutter_launcher_icons` → **`flutter_launcher_icons_flavors`** (per maintainer decision).
> Target release: **0.15.0** (additive minor; full backward compatibility for config schema).
> Target toolchain: **Flutter 3.41.9 / Dart 3.10** (CI-verified).
> Status: planning. This document is the executable spec for the change. Implementers should follow it phase by phase; each phase is independently revertable.

This plan is the synthesized output of a three-round multi-model design council (Claude Opus 4.7, GPT-5.5, Gemini 3.1 Pro). Convergence and resolved disagreements are recorded at the end of the document for traceability. User decisions on §13.3 open questions are folded in throughout.

---

## 0. User-confirmed decisions (binding)

These were settled during planning and are reflected in the plan below:

1. **Funding**: do not add `funding:` to pubspec in 0.15.0. Revisit in a future release.
2. **`flutter_icons:` deprecated pubspec key**: keep accepting it with a warning until 0.17.
3. **Flavor-name regex**: `^[A-Za-z0-9][A-Za-z0-9_-]*$` (allows `prod-eu`, `stagingV2`).
4. **`min_sdk_android` default**: **break** the legacy default and raise from 21 → **24**. This is a breaking change; reflected in the changelog and bumped to a 0.15.0 entry called out under "Breaking changes." Users on lower SDKs must specify `min_sdk_android` explicitly.
5. **`lib/pubspec_parser.dart`**: dead code; delete in PR 1.
6. **Project rename**: `flutter_launcher_icons` → `flutter_launcher_icons_flavors`. Pubspec `name:`, repository links, README headings, command name, and example imports all change. Existing users migrating from `flutter_launcher_icons` get a documented migration path. Filenames the package *consumes* (`flutter_launcher_icons.yaml`, `flutter_launcher_icons-<flavor>.yaml`, `flutter_launcher_icons_flavors.yaml`) **stay unchanged** so 0.14.x configs continue to work without edits.

---

## 1. Goals & non-goals

### Goals
1. Officially support Flutter 3.41.9 / Dart 3.10 (CI-verified).
2. Introduce a single consolidated multi-flavor config file: **`flutter_launcher_icons_flavors.yaml`**.
3. Rename the published package to **`flutter_launcher_icons_flavors`**.
4. Fix accumulated tech debt discovered during planning (see §10).
5. Ship production-ready: deterministic precedence, typed schema where it matters, clear errors, real tests, real CI.
6. **Full backward compatibility** for existing config files: every 0.14.x config schema continues to be parsed, with at most a deprecation warning. (The package import name is changing; that's a one-time pubspec edit for users.)

### Non-goals (deferred)
- Removing the deprecated `flutter_icons:` pubspec key (target 0.17).
- Schema v2 / breaking changes to the config schema itself.
- Multi-level inheritance (`extends:` between flavors). Wait for user demand.
- Image-package major bump (stay on `image: ^4.x`).
- Bumping the Dart SDK floor unless a concrete dependency forces it.
- Adding `funding:` metadata (deferred per user decision).

---

## 2. New consolidated flavors file

### 2.1 Filename and discovery

Exactly: **`flutter_launcher_icons_flavors.yaml`** at the project root (or under `--prefix`).

### 2.2 Schema (v0.15.0)

```yaml
# flutter_launcher_icons_flavors.yaml
version: 1                              # required; enables future schema evolution

defaults:                               # optional; partial config applied to every flavor
  image_path: "assets/icon/base.png"
  android: true
  ios: true
  min_sdk_android: 24
  remove_alpha_ios: true
  adaptive_icon_background: "#ffffff"

flavors:                                # required; non-empty map<flavor_name, partial config>
  dev:
    image_path: "assets/icon/dev.png"
    android: "ic_launcher_dev"          # custom drawable name
    adaptive_icon_foreground: "assets/icon/dev_fg.png"

  staging:
    image_path: "assets/icon/staging.png"

  prod:
    image_path: "assets/icon/prod.png"
    adaptive_icon_foreground: "assets/icon/prod_fg.png"
    web:
      generate: true
      image_path: "assets/icon/prod_web.png"
```

Notes:
- `version: 1` is **required**. Unknown versions → clear error pointing to migration docs.
- `defaults` is optional. Any key valid in single-config `flutter_launcher_icons.yaml` is valid here. It is parsed as a *partial* config (no required-field enforcement on its own).
- `flavors` is required, non-empty.
- Flavor names: `^[A-Za-z0-9][A-Za-z0-9_-]*$`, case-sensitive, may not be `.` or `..`, may not contain path separators. Duplicate names → error.
- **No `extends:` between flavors in 0.15.0.** Only `defaults` → `flavor` two-level layering.
- The new file does **not** wrap its content under `flutter_launcher_icons:` — `defaults`/`flavors`/`version` are top-level.

### 2.3 Merge semantics (deep merge with explicit deletion)

Resolution for each flavor `<name>`:
1. Start from `defaults` (or empty map if absent).
2. Deep-merge `flavors[<name>]` over the result.
3. Validate the resolved map as a full `Config`.

Rules:
- **Maps merge recursively** (key-wise).
- **Scalars and lists replace** wholesale.
- **Explicit `null` deletes** an inherited key:
  ```yaml
  defaults:
    adaptive_icon_background: "#ffffff"
  flavors:
    dev:
      adaptive_icon_background: ~        # YAML null → removes the key from resolved config
  ```
- **Falsy override is honored**: `defaults: { android: true }` + `flavors.dev: { android: false }` → `dev` has `android: false`. Test this explicitly.
- A flavor block must be a YAML map. Empty map (`flavors: { dev: {} }`) is allowed.

Why deep merge: nested platform blocks (`web`, `windows`, `macos`, adaptive-icon group) make shallow merge effectively useless.

### 2.4 Validation policy

- Parse the file with `checked_yaml` for type-and-line-number diagnostics.
- Validate `defaults` and each flavor override **structurally** (types, allowed keys) — not for required-field completeness.
- Deep-merge `defaults` + each `flavors[*]`.
- Validate each resolved per-flavor `Config` for **completeness** (required fields, at least one platform, image path existence, min_sdk plausibility).
- **Unknown keys**:
  - Unknown top-level keys (next to `version`/`defaults`/`flavors`) → warning (forward-compat).
  - Unknown keys *inside* `defaults` or any flavor block → error (typo protection).
- Error messages must always state: source file, flavor name (when applicable), and whether the issue arose in `defaults`, the flavor override, or the merged result.

---

## 3. Precedence (single source of truth)

When the CLI runs, config sources resolve in this order — **first match wins**:

1. `--file <path>` (explicit user override). If the file's top-level contains `flavors:`, treat as multi-flavor; otherwise single-config.
2. `flutter_launcher_icons_flavors.yaml` in `<prefix>` → **multi-flavor mode (NEW)**.
3. Any `flutter_launcher_icons-*.yaml` files in `<prefix>` → **legacy multi-flavor mode** (with deprecation warning).
4. `flutter_launcher_icons.yaml` in `<prefix>` → single-config mode.
5. `pubspec.yaml` → top-level `flutter_launcher_icons:` key (or deprecated `flutter_icons:` with existing warning) → single-config mode.
6. Otherwise → `NoConfigFoundException`, exit 65.

### 3.1 Coexistence policy (new file + legacy `-<flavor>.yaml` both present)

- **Default**: use the new file; emit a loud `WARNING:` listing legacy files being ignored, recommend `dart run flutter_launcher_icons_flavors migrate`.
- **`--strict` flag** (and config-level `strict: true`): coexistence becomes a hard error (exit 65). Teams that want CI-fail-on-drift opt in.

Rationale: a hard error by default would break developers who `git pull` a branch introducing the new file while their working tree still has legacy files. The warning + `--strict` opt-in resolves that without silently shadowing edits.

### 3.2 `--flavor` interaction with sources

- `--flavor <name>` (repeatable) **filters which flavors are built** out of the chosen source. It does *not* change which source is chosen.
- With `--file <path>`: `--file` selects the source; `--flavor` filters within it. Mismatch → exit 64.
- With legacy `-<flavor>.yaml` files: `--flavor dev` builds only `flutter_launcher_icons-dev.yaml`. Missing → exit 64 with available names.
- With single-config sources: passing a non-matching `--flavor` → exit 64.

### 3.3 Default build behavior when multiple flavors are discovered

- **New consolidated file**:
  - 1 flavor → build it.
  - >1 flavor and no `--flavor`/`--all-flavors` → exit 64 with clear message + available flavors list. Prevents accidental 50-flavor white-label builds. Use `--all-flavors` to opt in to "build everything".
- **Legacy mode**: unchanged — default builds **all** flavors found (backward compatibility).
- **Single-config**: build it (unchanged).

### 3.4 Partial-failure semantics

- Default: **fail-fast**. First failure aborts; already-written files left as-is (icon generation is not transactional).
- `--continue-on-error`: log failures, continue, exit non-zero with summary.
- A **preflight pass** validates *all* selected flavor configs (parse + resolve + validate) **before** any image generation begins. If any fails preflight → exit 65, no files written.

---

## 4. CLI redesign

### 4.1 Subcommands (via `package:args` `CommandRunner`)

Bare invocation defaults to `generate` for back-compat. Command name reflects the rename:
`dart run flutter_launcher_icons_flavors ...`

| Subcommand | Purpose |
|---|---|
| `generate` (default) | Generate icons. Honors precedence + flag set. |
| `migrate` | Convert legacy multi-file flavor layout to `flutter_launcher_icons_flavors.yaml`. Non-destructive by default. |
| `doctor` | Diagnose without generating: detected sources, precedence winner, parsed flavors, ignored files, deprecated keys, gradle/Flutter detection. |

### 4.2 Flags (on `generate`)

| Flag | Description |
|---|---|
| `-f`, `--file <path>` | Explicit config path (existing). |
| `-p`, `--prefix <path>` | Project prefix (existing). **Now actually threaded through flavor discovery** (fixes a current bug). |
| `--flavor <name>` | Build only the named flavor. Repeatable. |
| `--all-flavors` | Build every flavor in the consolidated file. Required when consolidated has >1 flavor and no `--flavor`. |
| `--list-flavors` | Print discovered flavors and exit 0. |
| `--continue-on-error` | Don't abort on first flavor failure; report summary. |
| `--strict` | Fail (exit 65) on new+legacy coexistence instead of warning. |
| `-v`, `--verbose` | Verbose logging. |
| `-h`, `--help` | Help. |

### 4.3 Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. |
| `1` | Generic runtime / I/O failure. |
| `64` | CLI usage error (bad flags, unknown flavor, conflicting options). |
| `65` | Configuration error (parse, validation, missing config, coexistence under `--strict`). |

### 4.4 `migrate` subcommand

`dart run flutter_launcher_icons_flavors migrate`:

1. Discovers `flutter_launcher_icons-*.yaml` (respects `--prefix`).
2. Parses each, extracting the `flutter_launcher_icons` / `flutter_icons` block.
3. **Writes `flutter_launcher_icons_flavors.yaml`** with each flavor as a fully-specified block (no automatic `defaults` extraction).
4. Prints a **"candidates for promotion to defaults" report** listing keys that have identical values across all flavors. User manually promotes them.
5. Backs up originals to `<original>.bak`. Flags:
   - `--in-place` — delete legacy files after verified successful write.
   - `--dry-run` — print would-be output to stdout; touch nothing.
   - `--force` — overwrite an existing `flutter_launcher_icons_flavors.yaml`.

### 4.5 `doctor` subcommand

Prints, in order: tool version; resolved `--prefix`; detected config sources; precedence winner (with reason); ignored sources (warnings); parsed flavor list; detected Android Gradle file (`build.gradle` / `build.gradle.kts` / neither); detected `min_sdk_android` and how; deprecated key usage. Exits 0 unless something is genuinely broken (then 65).

---

## 5. Internal refactor: typed config & merging

### 5.1 `PartialConfig` + `Config` split

Today `Config` declares fields with implicit defaults — impossible to tell whether a user *omitted* a key or *explicitly set it to the default*, which merge semantics need.

Introduce two types:
- **`PartialConfig`** — every field nullable, `json_serializable` with `includeIfNull: false`. Used for parsing, merging, migration tooling.
- **`Config`** — resolved, fully-populated, validated. Constructed via `Config.fromPartial(PartialConfig)` which fills defaults and throws `InvalidConfigException` (with field path) for missing required fields.

`Config.fromJson(Map)` keeps working for backward compat: internally produces a `PartialConfig`, then `Config.fromPartial`.

Sequenced as PR #1 (pure refactor under existing tests, no user-visible change) to avoid bisect coupling with schema work.

### 5.2 Typed `PlatformToggle` (replaces `dynamic android`/`dynamic ios`)

```dart
class PlatformToggle {
  const PlatformToggle._(this._kind, this._iconName);
  factory PlatformToggle.disabled() = _disabled;
  factory PlatformToggle.enabled() = _enabled;
  factory PlatformToggle.named(String iconName) = _named;
  // accessors: isEnabled, customIconName (nullable)
}
```

A `JsonConverter<PlatformToggle, Object>` accepts `bool` or `String`. **Permissive on input** (preserves backward compat), strict only on internal API. Public getters (`isCustomAndroidFile`, `isNeedingNewAndroidIcon`) keep their current names.

### 5.3 What gets validated, when

| Source | What is parsed | What is validated |
|---|---|---|
| `defaults` block | Structural (types, allowed keys) | NOT validated for completeness |
| Each `flavors[*]` block | Structural | NOT for completeness |
| Resolved per-flavor merge | n/a | **Full validation** |
| Single-config (legacy paths) | Structural | Full validation immediately (existing behavior preserved) |
| Unknown keys | Top-level: warn. Inside known blocks: error | — |

`checked_yaml` line-numbers preserved for parse-time errors. Merge-time errors carry source file + flavor name + key path (`flavors.dev.adaptive_icon_foreground`).

---

## 6. Bug fixes (mandatory in 0.15.0)

Each gets a regression test.

### 6.1 `getFlavors()` ignores `--prefix`
`lib/main.dart` lists `Directory('.')` instead of `Directory(prefixPath)`. Fix: accept `prefixPath`, use `Directory(prefixPath).list()`.

### 6.2 `prefixPath` not threaded through generators
`lib/android.dart` has `// TODO(p-mazhnik): support prefixPath`. Same affects adaptive icons, mipmap XML, manifest writes, colors.xml, min_sdk lookup. Fix: thread `prefixPath` through every generator entry point; resolve all paths via `path.join(prefixPath, ...)`.

### 6.3 Hard-coded `android/app/build.gradle` (no Kotlin DSL support)
Modern Flutter projects use `build.gradle.kts`; current `min_sdk_android` autodetection silently fails.

Fix:
- Probe `android/app/build.gradle.kts` first (Flutter 3.16+ default), fall back to `.gradle`.
- Regex covers Groovy and KTS forms:
  - Groovy: `minSdkVersion 21`, `minSdkVersion = 21`, `minSdk 21`, `minSdk = 21`, `minSdkVersion flutter.minSdkVersion`.
  - Kotlin DSL: `minSdk = 21`, `minSdkVersion = 21`, `minSdk(21)`, `minSdk = flutter.minSdkVersion`.
- If the value resolves to `flutter.minSdkVersion`, fall through to `local.properties` / Flutter SDK gradle (probe both `flutter.gradle` and `flutter.gradle.kts`).
- Parse failure: emit clear actionable error (`could not auto-detect min_sdk_android; specify min_sdk_android in your config`). Do not silently default.
- **Documented limitation**: version catalogs (`libs.versions.toml`) and convention plugins are out of scope; doctor reports this.

Fixtures under `test/fixtures/gradle/`: `groovy_basic/`, `kts_basic/`, `kts_with_flutter_ref/`, `kts_with_version_catalog/` (graceful fail), `convention_plugin/` (graceful fail).

### 6.4 String concatenation instead of `path.join`
`lib/constants.dart` `androidResFolder(flavor) + 'mipmap-anydpi-v26/'`; `lib/android.dart` similar. Replace with `path.join`. Add Windows tests.

### 6.5 Stale `avoid_slow_async_io` comments
`lib/utils.dart`: update comments. Migrate generator hot paths (image read/write/decode) to async. Keep config *loading* synchronous (preserves static-factory APIs).

### 6.6 `decodeImageFile` falsely nullable
Tighten to `Future<Image>` non-nullable (already throws on null).

### 6.7 `analysis_options.yaml` references obsolete lints
- Adopt `package:lints/recommended.yaml` via `include:`.
- Drop `strong-mode: implicit-dynamic` (removed in modern analyzer).
- Remove rules deleted/renamed in modern Dart.
- Run `dart analyze --fatal-infos` clean.

### 6.8 Pub.dev metadata gaps
Add `topics`, `screenshots` to `pubspec.yaml`. **Do not add `funding`** (deferred per user decision).

### 6.9 `androidDefaultAndroidMinSDK` raised 21 → 24 (BREAKING)
Per user decision. Reflected as a breaking change in CHANGELOG and README upgrade notes. Users who target SDK <24 must specify `min_sdk_android` explicitly.

### 6.10 Delete `lib/pubspec_parser.dart`
Dead code per user decision. Remove the file and any dangling imports.

### 6.11 Project rename to `flutter_launcher_icons_flavors`
- `pubspec.yaml`: `name: flutter_launcher_icons_flavors`, update `homepage`/`repository`/`issue_tracker` to the new repo (final URL TBD by maintainer).
- All `import 'package:flutter_launcher_icons/...'` → `import 'package:flutter_launcher_icons_flavors/...'` across `lib/`, `bin/`, `test/`, `example/`.
- `bin/main.dart` invocation becomes `dart run flutter_launcher_icons_flavors`.
- README rewrites the package name everywhere; adds a top-of-readme migration callout for users of the original `flutter_launcher_icons`.
- **Filenames the package consumes do not change** — `flutter_launcher_icons.yaml`, `flutter_launcher_icons-<flavor>.yaml`, `flutter_launcher_icons_flavors.yaml`, and the pubspec key `flutter_launcher_icons:` all remain. This means existing users only edit their `dependencies:` block; no config edits required.

---

## 7. File-by-file edit list

| File | Change |
|---|---|
| `pubspec.yaml` | `name: flutter_launcher_icons_flavors`. Bump version → `0.15.0`. Verify SDK constraint. Update `homepage`/`repository`/`issue_tracker`. Add `topics`, `screenshots`. (No `funding`.) |
| `analysis_options.yaml` | `include: package:lints/recommended.yaml`. Remove dead rules. Drop `strong-mode` block. |
| `bin/main.dart` | Thin wrapper that constructs `CommandRunner` and dispatches. Update package import to new name. |
| `lib/main.dart` | Refactored: precedence resolver, `CommandRunner` setup, exit-code handling. |
| `lib/cli/` (NEW) | `command_runner.dart`, `generate_command.dart`, `migrate_command.dart`, `doctor_command.dart`. |
| `lib/config/config.dart` | Split into `PartialConfig` + `Config`. Validation in `Config.fromPartial`. |
| `lib/config/partial_config.dart` (NEW) | Nullable mirror of `Config` for parsing/merging. |
| `lib/config/platform_toggle.dart` (NEW) | `PlatformToggle` + `JsonConverter`. |
| `lib/config/flavors_config.dart` (NEW) | `FlavorsConfig.load(prefixPath)`, deep-merge engine, validation orchestration. |
| `lib/config/merge.dart` (NEW) | Pure deep-merge function with documented null-deletion + falsy-override semantics. |
| `lib/migrate/migrator.dart` (NEW) | Legacy → consolidated converter. |
| `lib/constants.dart` | Replace string concat with `path.join`. Make Android gradle path a function that probes `.kts`/`.gradle`. **Bump `androidDefaultAndroidMinSDK = 24`.** |
| `lib/android.dart` | Thread `prefixPath`. KTS regex. `path.join` everywhere. Fix mipmap folder concat. |
| `lib/ios.dart`, `lib/web/`, `lib/windows/`, `lib/macos/` | Thread `prefixPath`; `path.join`; async hot paths. |
| `lib/utils.dart` | Non-nullable `decodeImageFile`. Updated comments. |
| `lib/logger.dart` | Levels: error / warn / info / verbose. Respect `NO_COLOR`. Used everywhere instead of bare `print`/`stderr.writeln`. |
| `lib/custom_exceptions.dart` | Add `MixedConfigSourcesException`, `UnknownFlavorException`. |
| `lib/pubspec_parser.dart` | **Delete.** Remove imports. |
| All `import 'package:flutter_launcher_icons/...'` | Rename to `flutter_launcher_icons_flavors`. |
| `test/**` | New suites per §8. Update package imports for rename. |
| `test/fixtures/**` (NEW) | Gradle fixtures, sample multi-flavor files, golden migrate inputs/outputs. |
| `example/**` | Update pubspec dependency entries to `flutter_launcher_icons_flavors: ^0.15.0` (path or version). Update generation commands. |
| `README.md` | Top-of-readme rename callout + migration-from-`flutter_launcher_icons` instructions. New "Multi-flavor (consolidated)" section. Migration guide for legacy multi-file. Precedence table. Exit-code table. **Note about `min_sdk_android` default raise.** |
| `doc/flavors.md` (NEW) | Schema reference, merge semantics, examples, troubleshooting. |
| `CHANGELOG.md` | 0.15.0 entry (see §11) including Breaking changes section. |
| `.github/workflows/ci.yaml` | Matrix update (see §9). |
| `flutter_launcher_icons.code-workspace` | Optional rename to match (low priority). |

---

## 8. Test plan

### 8.1 Unit tests
- `test/config/merge_test.dart` — deep merge: maps recurse, scalars/lists replace, null deletion, falsy override (`android: false` over `android: true`), unknown-key handling.
- `test/config/partial_config_test.dart` — parsing partial YAML; round-trip via `toJson`.
- `test/config/platform_toggle_test.dart` — bool/string/null inputs, JSON round-trip.
- `test/config/flavors_config_test.dart` — full schema parse, missing `version`, missing `flavors`, invalid flavor names, duplicate flavor names, empty `flavors`, `version: 999` rejection, single-flavor short-form.
- `test/config/precedence_test.dart` — exhaustive matrix using `test_descriptor`:

| --file | new file | legacy files | single yaml | pubspec inline | Expected winner |
|---|---|---|---|---|---|
| (set) | yes | yes | yes | yes | --file |
| — | yes | yes | yes | yes | new file + WARN |
| — | yes | yes | yes | yes | (with `--strict`) → exit 65 |
| — | no | yes | yes | yes | legacy + DEPRECATION WARN |
| — | no | no | yes | yes | single |
| — | no | no | no | yes | pubspec |
| — | no | no | no | no | exit 65 |

- `test/cli/flavor_filter_test.dart` — `--flavor` repeated, missing flavor, mismatch with `--file`.
- `test/cli/exit_codes_test.dart` — every documented exit code reachable.
- `test/cli/strict_test.dart` — `--strict` upgrades coexistence warning to error 65.
- `test/cli/all_flavors_test.dart` — consolidated >1 flavor without `--flavor`/`--all-flavors` → exit 64; with `--all-flavors` → builds all.
- `test/cli/continue_on_error_test.dart` — failure of one flavor doesn't abort, summary printed.
- `test/android_gradle_test.dart` — Groovy / KTS / KTS+`flutter.minSdkVersion` / version-catalog (graceful fail) / convention-plugin (graceful fail).
- `test/android_min_sdk_default_test.dart` — confirms new default 24 is applied when unspecified, and that explicit user value still wins.
- `test/utils/path_join_test.dart` — Windows backslashes, double-slash, `prefixPath` variants.
- `test/utils/prefix_threading_test.dart` — running with `--prefix subdir` for: legacy flavors, new flavors, single config, generator outputs.

### 8.2 Migration tests
- `test/migrate/golden_test.dart` — input fixture set of 3 legacy files → expected consolidated output. YAML compared semantically.
- `test/migrate/dry_run_test.dart` — touches no files.
- `test/migrate/in_place_test.dart` — deletes originals only on successful write; `.bak` exists otherwise.
- `test/migrate/refuses_overwrite_test.dart` — refuses if target exists; `--force` overrides.

### 8.3 Doctor tests
- `test/doctor/output_test.dart` — golden output for several project layouts.

### 8.4 Integration smoke tests (`example/`)
- Existing examples must continue to pass (after pubspec dependency-name update).
- Add `example/flavors_consolidated/` with the new file, exercised in CI.

---

## 9. CI matrix

`.github/workflows/ci.yaml`:

```yaml
strategy:
  fail-fast: false
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    flutter: ['3.41.9', 'stable']
```

Steps per job:
1. `subosito/flutter-action` with the matrix Flutter version.
2. `flutter pub get`.
3. `dart format --set-exit-if-changed .`.
4. `dart analyze --fatal-infos`.
5. `dart test --coverage=coverage`.
6. Run `example/default_example` and `example/flavors_consolidated` smoke generation (verify output files exist and decode).

Add a `pana` job (informational, non-blocking) and a publish-dry-run job on tagged commits.

---

## 10. Tech-debt findings folded into 0.15.0

1. `getFlavors()` ignores `--prefix` — §6.1.
2. `prefixPath` not threaded through Android generators — §6.2.
3. No Kotlin DSL `build.gradle.kts` support; min_sdk autodetection broken — §6.3.
4. String concatenation instead of `path.join` — §6.4.
5. Stale `avoid_slow_async_io` rationale; mixed sync/async I/O — §6.5.
6. `decodeImageFile` falsely nullable — §6.6.
7. `analysis_options.yaml` references obsolete/removed lints — §6.7.
8. `Config.android`/`Config.ios` typed `dynamic` — §5.2.
9. `Config` cannot distinguish unset vs. default-set — §5.1.
10. Bare `print`/`stderr.writeln` instead of leveled logger — `lib/logger.dart` upgrade.
11. `lib/pubspec_parser.dart` dead/duplicative — **delete** (§6.10).
12. `pubspec.yaml` lacks `topics`/`screenshots` — §6.8.
13. README still documents per-file flavor convention as the only path — §11.
14. No CI matrix; no Flutter 3.41.9 verification — §9.
15. Tests exist but coverage of flavors / Windows paths / KTS is shallow — §8.
16. Deprecated `flutter_icons` key handling silent until parse — explicit deprecation warning preserved; removal scheduled for 0.17.
17. Default `min_sdk_android = 21` is below modern Flutter minimums — **bump to 24** (§6.9).
18. Project name does not signal flavor focus — **rename to `flutter_launcher_icons_flavors`** (§6.11).

---

## 11. Documentation

### 11.1 README rewrite outline

1. **Top callout**: "This package was renamed from `flutter_launcher_icons` to `flutter_launcher_icons_flavors`. To migrate, update your `dev_dependencies:` entry. Config files do not need to change."
2. Quick start (single config) — unchanged behavior, lightly modernized.
3. Configuration reference — unchanged keys, with a note pointing to the flavors guide. Call out new `min_sdk_android` default of 24.
4. **Multi-flavor projects (recommended): `flutter_launcher_icons_flavors.yaml`** — full schema example, merge semantics, `--flavor` / `--all-flavors` usage.
5. **Migrating from legacy `flutter_launcher_icons-<flavor>.yaml`** — side-by-side example, `dart run flutter_launcher_icons_flavors migrate` walkthrough.
6. Precedence table (§3 verbatim).
7. CLI reference (`generate`, `migrate`, `doctor`, all flags).
8. Exit codes table (§4.3 verbatim).
9. Troubleshooting: `--strict` mode, KTS limitations, version catalogs, convention plugins, monorepos with `--prefix`.

### 11.2 New `doc/flavors.md`

Deep-dive companion: schema reference, merge rules with worked examples (including null-deletion and falsy-override), validation rules, common pitfalls, FAQ.

### 11.3 `CHANGELOG.md` entry for 0.15.0

```
## 0.15.0

### Breaking changes
- Package renamed from `flutter_launcher_icons` to `flutter_launcher_icons_flavors`.
  Update your `dev_dependencies:` entry. Config files (pubspec key, .yaml filenames)
  remain unchanged.
- Default `min_sdk_android` raised from 21 to 24, matching modern Flutter project
  defaults. Projects targeting older API levels must specify `min_sdk_android`
  explicitly in their config.

### Added
- New consolidated multi-flavor config file `flutter_launcher_icons_flavors.yaml`
  with `version`, optional `defaults`, and required `flavors:` map.
- `--flavor <name>` (repeatable), `--all-flavors`, `--list-flavors`,
  `--continue-on-error`, `--strict` CLI flags.
- New subcommands: `migrate` (convert legacy multi-file flavor layout) and
  `doctor` (diagnose configuration/discovery without generating).
- Android Kotlin DSL (`build.gradle.kts`) detection for `min_sdk_android`.
- Documented exit codes (0/1/64/65).
- pub.dev metadata: `topics`, `screenshots`.

### Changed
- Internal config model split into `PartialConfig` (nullable, for merging)
  and `Config` (resolved, validated). Public APIs unchanged.
- `Config.android` / `Config.ios` now backed by typed `PlatformToggle` while
  remaining permissive on input (bool or String) for full backward compatibility.
- Logger gains levels (error/warn/info/verbose); replaces bare prints.
- Adopted `package:lints/recommended.yaml`.
- CI matrix expanded: ubuntu/macos/windows × Flutter 3.41.9 + stable.

### Fixed
- `--prefix` was silently ignored by flavor discovery (`getFlavors`).
- `--prefix` was not threaded through Android icon generators.
- Path concatenation used string `+ '/'` in several places; now `path.join`.
- `min_sdk_android` autodetection failed on Flutter 3.16+ KTS-based projects.
- `decodeImageFile` falsely typed as nullable.

### Removed
- `lib/pubspec_parser.dart` (dead code).

### Deprecated
- Per-file `flutter_launcher_icons-<flavor>.yaml` layout. Continues to work
  for now; emits a deprecation warning. Run
  `dart run flutter_launcher_icons_flavors migrate` to convert.
  Removal targeted for 0.17.
- `flutter_icons:` pubspec key (already deprecated since 0.13.1) — removal
  remains targeted for 0.17.

### Backward compatibility (config files)
- Every 0.14.x config file format continues to work in 0.15.0 with at most a
  deprecation warning. The only required user change is the package name in
  pubspec dev_dependencies.
```

---

## 12. Phased delivery (5 PRs, each independently revertable)

**PR 1 — Internal refactor + rename (no schema change).**
- Pubspec rename to `flutter_launcher_icons_flavors`.
- Update all `package:flutter_launcher_icons/...` imports to new name.
- `PartialConfig` / `Config` split.
- `PlatformToggle` (replacing `dynamic`).
- Logger upgrade.
- Thread `prefixPath` through all generators; fix `getFlavors` prefix bug.
- `path.join` everywhere.
- Delete `lib/pubspec_parser.dart`.
- `analysis_options.yaml` modernization.
- All existing tests must pass unchanged. New regression tests for prefix + path.

**PR 2 — Platform/probe hardening + min_sdk default bump.**
- Kotlin DSL gradle support + fixtures.
- Async I/O on generator hot paths.
- `decodeImageFile` non-nullable.
- pub.dev metadata (`topics`, `screenshots`).
- **Bump `androidDefaultAndroidMinSDK = 24`** + tests + README note.

**PR 3 — Consolidated multi-flavor config.**
- Schema, parser, merge engine, validation orchestration.
- Precedence resolver including `--strict`.
- Tests: schema, merge, precedence matrix, validation policy.

**PR 4 — CLI restructure + commands.**
- `CommandRunner` migration with `generate` (default), `migrate`, `doctor`.
- New flags: `--flavor`, `--all-flavors`, `--list-flavors`, `--continue-on-error`, `--strict`.
- Exit-code policy.
- `migrate` and `doctor` implementations + golden tests.

**PR 5 — Docs, CI, release.**
- README rewrite (rename callout + flavors section + `min_sdk_android` note) + `doc/flavors.md`.
- CHANGELOG.
- CI matrix.
- `pub publish --dry-run` clean.
- Tag `v0.15.0`, publish to pub.dev as `flutter_launcher_icons_flavors`.

---

## 13. Convergence, resolved disagreements, and unresolved items

### 13.1 Convergence (high confidence — all three council members agreed)

- Ship as **0.15.0**. Additive minor for the schema (rename + min_sdk bump are the breaking pieces).
- Add `--flavor` and `--list-flavors` flags.
- Fix `getFlavors()` prefix bug.
- Add Kotlin DSL gradle support with regex fallback for both forms; document brittle cases (version catalogs, convention plugins).
- Replace string concatenation with `path.join`. Add Windows-path tests.
- Adopt `package:lints/recommended.yaml`; drop dead rules.
- `pubspec.yaml`: add `topics`, `screenshots`.
- CI matrix on Flutter 3.41.9 + latest stable.
- Test the precedence matrix end-to-end.

### 13.2 Resolved disagreements (a clear winner emerged)

| # | Disagreement | Resolution | Reasoning |
|---|---|---|---|
| 1 | Shallow vs. deep merge | **Deep merge** with explicit `null` deletion | Shallow merge would force users to repeat full nested platform blocks per flavor; ~100 lines well-tested code is not over-engineering for the headline feature. Gemini conceded. |
| 2 | Schema wraps under `flutter_launcher_icons:` (GPT) vs. top-level `defaults`/`flavors`/`version` (Claude/Gemini) | **Top-level keys** | The file name already declares its purpose; wrapping is redundant. |
| 3 | `extends:` between flavors (Claude original) | **Drop for 0.15.0** | Both peers correctly flagged it as over-engineered with contradictory "single-level" vs "8-level cap" wording. Defer; revisit on user demand. |
| 4 | New + legacy coexistence: hard error vs silent precedence vs build both | **Warning by default + `--strict` opt-in** | Hard error breaks `git pull` workflows; silent precedence hides edits; building both is duplicate-icons footgun. Middle path was unanimously chosen in Round 3. |
| 5 | Migrate command's auto-`defaults` extraction | **Migrate emits fully-specified flavor blocks; prints "candidates for promotion to defaults" report** | Auto-intersection produces surprising defaults from copy-pasted legacy files. |
| 6 | Default consolidated build behavior with >1 flavor | **Require `--flavor` or `--all-flavors`** | Default-build-all is dangerous for white-label apps with many flavors. Legacy mode keeps build-all default for backward compat. |
| 7 | Exit code surface | **Lean: 0/1/64/65** | The 64/65/66/70/78 set was over-engineered maintenance burden. |
| 8 | Dart SDK floor bump | **Hold floor at current `>=3.0.0 <4.0.0` constraint** | Bumping was unjustified; only move if a forced dependency requires it. |
| 9 | `image` package bump | **Stay on `^4.x` (do not raise to `^4.5.0`)** | No CVE or required API drives a bump. |
| 10 | Strict typed `bool|String` converter immediately | **Permissive on input, strict on internal API** | Backward compatibility requirement trumps stricter input validation. |
| 11 | Async I/O scope | **Async only for generator hot paths**; keep config loading sync | Avoids ripple refactor of `Config.loadConfigFromPath` etc. |
| 12 | `version: 1` in new schema | **Required** | Cheap insurance. One required key. |

### 13.3 User-confirmed decisions (formerly open questions)

| # | Question | User decision |
|---|---|---|
| 1 | Add `funding:` to pubspec? | **No** — defer to a future release. |
| 2 | Keep deprecated `flutter_icons:` key with warning until 0.17? | **Yes**. |
| 3 | Flavor-name regex `^[A-Za-z0-9][A-Za-z0-9_-]*$`? | **Yes**. |
| 4 | `min_sdk_android` default 21 → 24? | **Yes — break and bump to 24.** Documented as a breaking change. |
| 5 | Delete dead `lib/pubspec_parser.dart`? | **Yes — remove.** |
| 6 | Project rename? | **Yes — rename to `flutter_launcher_icons_flavors`.** |

### 13.4 Items still requiring maintainer action at release time

- Confirm/secure pub.dev ownership of the name `flutter_launcher_icons_flavors` before tagging.
- Confirm new repository URL (or keep the same repo and rename via GitHub) before updating `homepage`/`repository`/`issue_tracker` in `pubspec.yaml`.
- Maintainer to perform `pub publish` after PR 5 merges.
