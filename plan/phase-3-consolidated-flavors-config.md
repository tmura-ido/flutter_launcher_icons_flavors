# Phase 3 — Consolidated multi-flavor config (`flutter_launcher_icons_flavors.yaml`)

> **Depends on**: Phase 1 complete (`PartialConfig` exists). Phase 2 not strictly required but recommended.
> **User-visible behavior change**: Yes — a new config file format is recognized. All existing config files continue to work.
> **Goal**: introduce the new consolidated multi-flavor config schema, deep merge, and precedence resolver. CLI surface stays as in Phase 1 (flat `ArgParser`); subcommands and `--flavor` filtering arrive in Phase 4.

---

## 0. Context

You are working on the Dart package `flutter_launcher_icons_flavored`. Phases 1 and 2 set the stage. Phase 3 introduces the headline feature: a single file containing all flavor configurations with a shared base.

Why a new file format:

- Today users with multiple flavors must keep one `flutter_launcher_icons-<flavor>.yaml` per flavor in the project root, leading to clutter and duplicated config keys.
- The new `flutter_launcher_icons_flavors.yaml` consolidates all flavors with an optional shared `defaults:` block, yielding DRY configs.

Binding decisions (do not deviate):

- Filename: exactly `flutter_launcher_icons_flavors.yaml`. Filenames the package consumes do not change.
- Schema: top-level `version: 1` (required), optional `defaults:`, required non-empty `flavors:` map. Top-level only — do NOT wrap under `flutter_launcher_icons:`.
- Flavor name regex: `^[A-Za-z0-9][A-Za-z0-9_-]*$`. Case-sensitive. Cannot be `.` or `..` and cannot contain path separators.
- No `extends:` between flavors in 0.15.0. Two-level layering only: `defaults` → `flavor`.
- **Deep merge** with explicit `null` deletion. Maps merge recursively; scalars and lists replace; explicit YAML `null` deletes the key.
- Falsy override is honored: `defaults: { android: true }` + `flavors.dev: { android: false }` → `dev` has `android: false`.
- Validation timing: `defaults` and each flavor override are validated **structurally only**; the merged per-flavor config is validated **fully**.
- Precedence (first match wins): `--file` > `flutter_launcher_icons_flavors.yaml` > legacy `flutter_launcher_icons-*.yaml` > `flutter_launcher_icons.yaml` > pubspec inline.
- Coexistence policy: when both new and legacy files exist, default behavior is **use the new file + WARN** about ignored legacy files. The `--strict` flag (Phase 4) escalates this to an error. **In Phase 3 the `--strict` flag does not yet exist** — implement only the warn-by-default path; design the resolver so `--strict` can be wired in cleanly in Phase 4.
- Behavior when consolidated has >1 flavor and no `--flavor`/`--all-flavors` flag: in Phase 3, since neither flag exists yet, **default to building all flavors** (preserving current legacy behavior). Phase 4 changes this default to "require explicit `--flavor` or `--all-flavors`."

---

## 1. In-scope work for Phase 3

### 1.1 Schema model

- New file `lib/config/flavors_file.dart`:
  ```dart
  @JsonSerializable(anyMap: true, checked: true, includeIfNull: false)
  class FlavorsFile {
    const FlavorsFile({required this.version, this.defaults, required this.flavors});

    final int version;
    final PartialConfig? defaults;
    final Map<String, PartialConfig> flavors;

    factory FlavorsFile.fromJson(Map json) => _$FlavorsFileFromJson(json);
    Map<String, dynamic> toJson() => _$FlavorsFileToJson(this);
  }
  ```
- Generate `lib/config/flavors_file.g.dart` via `dart run build_runner build`.
- Validation in the constructor / a `validate()` method:
  - `version == 1` (else: clear error pointing to docs).
  - `flavors` non-empty.
  - Every flavor name matches `^[A-Za-z0-9][A-Za-z0-9_-]*$`, is not `.` or `..`, contains no path separators.
  - Duplicate flavor names → error (YAML parsers usually preserve last-wins but `checked_yaml` should flag duplicates; if not, post-validate by comparing key counts).
- Unknown-key handling:
  - Top-level keys other than `version` / `defaults` / `flavors` → log a warning via `FLILogger.warn` and ignore. (Forward-compat.)
  - Unknown keys inside `defaults` or any flavor block → error with field path. (Typo protection. `checked_yaml`'s `disallowUnrecognizedKeys` parameter handles this; configure `PartialConfig`'s annotation appropriately.)

### 1.2 Deep merge engine

- New file `lib/config/merge.dart`:
  ```dart
  /// Deep-merges [override] onto [base]. Both must already be JSON-shaped maps
  /// (parsed YAML). Returns a new map; does not mutate inputs.
  ///
  /// Rules:
  /// - Maps merge recursively (key-wise).
  /// - Scalars and lists in [override] replace those in [base].
  /// - Explicit `null` in [override] deletes the key from the result.
  /// - Keys present only in [base] survive unchanged.
  /// - Keys present only in [override] are added (unless their value is `null`,
  ///   in which case they are absent from the result).
  Map<String, dynamic> deepMerge(Map<String, dynamic> base, Map<String, dynamic> override);
  ```
- Operate on raw `Map<String, dynamic>` produced by `yaml.checkedYamlDecode` (or via `PartialConfig.toJson()` round-trip). Do not try to merge `PartialConfig` objects directly — merging at the JSON layer is simpler and less error-prone.
- Pure function. Heavily tested.

### 1.3 Flavor resolution

- New file `lib/config/flavors_config.dart`:
  ```dart
  class FlavorsConfig {
    FlavorsConfig._(this.source, this._partials);

    /// Absolute path of the source file (for error messages).
    final String source;

    /// Map flavor name → resolved PartialConfig (after deep merge of defaults).
    final Map<String, PartialConfig> _partials;

    Iterable<String> get flavorNames => _partials.keys;

    /// Resolves and validates [name] into a fully-populated [Config].
    Config resolve(String name) {
      final partial = _partials[name];
      if (partial == null) throw UnknownFlavorException(name, _partials.keys.toList());
      return Config.fromPartial(partial); // throws InvalidConfigException with field path on missing required fields
    }

    /// Returns null if [filePath] does not exist. Throws on parse / structural errors.
    static FlavorsConfig? load(String filePath);
  }
  ```
- `load`:
  1. If file doesn't exist → return `null`.
  2. Parse with `checked_yaml` → `FlavorsFile`.
  3. Validate (`version`, flavor names, etc.).
  4. For each flavor: deep-merge `defaults?.toJson() ?? {}` with `flavors[name].toJson()`, then `PartialConfig.fromJson(merged)`. Cache.
  5. Return `FlavorsConfig`. Do NOT validate completeness (`Config.fromPartial`) eagerly — deferred to `resolve(name)` so unrelated flavors don't block one another at load time. (But still call `Config.fromPartial` during a **preflight pass** before any generation; see §1.5.)

### 1.4 Precedence resolver

- New file `lib/config/source_resolver.dart` (or extend existing `Config` static methods):
  ```dart
  enum ConfigSourceKind {
    explicitFile,            // --file <path>
    consolidatedFlavors,     // flutter_launcher_icons_flavors.yaml
    legacyFlavors,           // flutter_launcher_icons-*.yaml
    singleFile,              // flutter_launcher_icons.yaml
    pubspecInline,           // flutter_launcher_icons: in pubspec.yaml
  }

  class ResolvedSource {
    final ConfigSourceKind kind;
    final String? path;                 // null for pubspec inline
    final List<String> ignoredLegacy;   // legacy files coexisting; for warning
  }

  /// Resolves which config source to use following the documented precedence.
  /// Throws NoConfigFoundException if none found.
  ResolvedSource resolveSource({
    required String prefixPath,
    String? explicitFilePath,
    required FLILogger logger,
  });
  ```
- Behavior:
  1. If `explicitFilePath != null` → return `explicitFile` with that path. (No fallback. Hard error if file doesn't exist.)
  2. If `<prefix>/flutter_launcher_icons_flavors.yaml` exists:
     - Discover any coexisting legacy files (`flutter_launcher_icons-*.yaml`) under `<prefix>` → put in `ignoredLegacy`.
     - If `ignoredLegacy` is non-empty: emit `logger.warn(...)` listing them and recommending `dart run flutter_launcher_icons_flavored migrate` (the `migrate` subcommand arrives in Phase 4; until then the warning still references it as the future remediation path).
     - Return `consolidatedFlavors`.
  3. Else if any `<prefix>/flutter_launcher_icons-*.yaml` exists → return `legacyFlavors` and emit a deprecation warning recommending the new file.
  4. Else if `<prefix>/flutter_launcher_icons.yaml` exists → return `singleFile`.
  5. Else if `<prefix>/pubspec.yaml` has a `flutter_launcher_icons:` (or deprecated `flutter_icons:`) key → return `pubspecInline`.
  6. Else throw `NoConfigFoundException`.
- The `--file` short-circuit: when `explicitFilePath` is given, after loading the file, sniff whether it has a top-level `flavors:` key. If so, treat it as a multi-flavor file (use `FlavorsConfig` to load it). Otherwise treat as single-config.

### 1.5 Wire into existing `lib/main.dart` `createIconsFromArguments`

- Replace the existing `getFlavors() / loadConfigFileFromArgResults` flow with:
  1. Call `resolveSource(...)`.
  2. Switch on `kind`:
     - `consolidatedFlavors` (or `explicitFile` pointing to a multi-flavor file): call `FlavorsConfig.load(path)`. Default behavior in Phase 3 is "build all flavors" (Phase 4 changes this default). For each flavor name: `final cfg = flavorsConfig.resolve(name);` then call existing `createIconsFromConfig(cfg, logger, prefixPath, name)`.
     - `legacyFlavors`: existing behavior (loop over discovered files). Keep emitting the deprecation warning.
     - `singleFile`, `pubspecInline`, `explicitFile` pointing to single-config file: existing behavior.
- **Preflight pass**: before generating any icons in `consolidatedFlavors` mode, iterate over every selected flavor and call `flavorsConfig.resolve(name)` (which validates). If any throw, abort with exit 65 — no files written.
- New exception `lib/custom_exceptions.dart`:
  - `MixedConfigSourcesException(List<String> ignoredLegacy)` — for use by Phase 4's `--strict` path. Define it now even though it's unused; document.
  - `UnknownFlavorException(String requestedName, List<String> availableNames)`.
  - `InvalidFlavorsFileException(String message, {String? path, String? flavor, String? keyPath})` — thrown for schema / merge / validation errors.

### 1.6 Backward-compat: `--file` pointing to multi-flavor file

- If a user passes `--file my_flavors.yaml` and that file has top-level `flavors:`, it is treated as multi-flavor. (Lets users keep the consolidated file under any name in monorepos.)

---

## 2. Out of scope

- `--flavor`, `--all-flavors`, `--list-flavors`, `--strict`, `--continue-on-error` flags. Phase 4.
- `migrate` and `doctor` subcommands. Phase 4.
- `CommandRunner` migration. Phase 4.
- Changing the default behavior on consolidated >1 flavor to require an explicit flag. Phase 4 (Phase 3 keeps build-all default).
- README / CHANGELOG content (Phase 5). You may add a stub note to CHANGELOG if helpful but Phase 5 owns the canonical entry.
- Bumping pubspec version beyond `0.15.0-dev.1`.

---

## 3. File-by-file change list

| File | Action |
|---|---|
| `lib/config/flavors_file.dart` (NEW) | `FlavorsFile` model + JSON serialization. |
| `lib/config/flavors_file.g.dart` (NEW, generated) | `dart run build_runner build`. |
| `lib/config/merge.dart` (NEW) | `deepMerge` pure function. |
| `lib/config/flavors_config.dart` (NEW) | `FlavorsConfig` loader + per-flavor resolver. |
| `lib/config/source_resolver.dart` (NEW) | `resolveSource` precedence logic. |
| `lib/config/config.dart` | Optional: extract any shared constants the resolver needs (e.g. file name `flutter_launcher_icons_flavors.yaml`). |
| `lib/constants.dart` | Add constants: `consolidatedFlavorsFileName = 'flutter_launcher_icons_flavors.yaml'`, `singleConfigFileName = 'flutter_launcher_icons.yaml'`, regex pattern for legacy. |
| `lib/main.dart` | Rewire flow through `resolveSource` and `FlavorsConfig`. Preserve existing behavior for non-consolidated paths. |
| `lib/custom_exceptions.dart` | Add `MixedConfigSourcesException`, `UnknownFlavorException`, `InvalidFlavorsFileException`. |
| `test/config/merge_test.dart` (NEW) | Deep merge tests. |
| `test/config/flavors_file_test.dart` (NEW) | Schema parse / validation tests. |
| `test/config/flavors_config_test.dart` (NEW) | Loader / resolve / preflight tests. |
| `test/config/source_resolver_test.dart` (NEW) | Precedence matrix using `test_descriptor`. |
| `test/main_consolidated_flow_test.dart` (NEW) | End-to-end: lay down a consolidated file, run `createIconsFromArguments`, assert each flavor's outputs are written. |

---

## 4. Tests to add (Phase 3)

### 4.1 `test/config/merge_test.dart`

- Empty base, populated override → override.
- Populated base, empty override → base.
- Overlapping scalar → override wins.
- Overlapping map → recursive merge (assert deep, not shallow).
- Overlapping list → override list replaces wholesale (no concatenation).
- Explicit `null` in override → key removed from result.
- Falsy override (`base: { android: true }`, `override: { android: false }`) → result has `android: false` (the classic shallow-merge bug).
- Nested map deletion: `base: { web: { generate: true, image_path: 'x' } }` + `override: { web: null }` → `web` is removed.
- Adding a fresh key from override.

### 4.2 `test/config/flavors_file_test.dart`

- Minimal valid file (`version: 1`, single flavor, no `defaults`).
- Missing `version` → error.
- `version: 2` → error mentioning supported version.
- Missing `flavors` → error.
- Empty `flavors: {}` → error.
- Invalid flavor name (`'flavor with space'`, `'../escape'`, `'.'`, empty string, leading `_`) → error.
- Duplicate flavor name → error.
- Unknown top-level key (`extras: {}`) → warning logged, parse succeeds.
- Unknown key inside `defaults` or a flavor → error with key path.
- Both `image_path` and platform-specific paths in same flavor → parses (validation deferred).

### 4.3 `test/config/flavors_config_test.dart`

- Load returns `null` when file absent.
- `load(...).resolve('dev')` produces a fully-populated `Config` after merging with `defaults`.
- `resolve('nonexistent')` → `UnknownFlavorException` listing available names.
- Preflight: simulate one flavor missing required fields; assert that calling `resolve` on it throws `InvalidConfigException` with a field path that mentions the flavor name (`flavors.broken.image_path`).
- Falsy override end-to-end: `defaults: { android: true }`, `flavors.dev: { android: false }` → resolved `Config.android` is the disabled `PlatformToggle`.

### 4.4 `test/config/source_resolver_test.dart`

Use `test_descriptor` to lay down combinations under a fresh temp dir; assert the chosen `ResolvedSource.kind` and any `ignoredLegacy`/warnings:

| Layout | Expected kind | Ignored legacy? | Warning? |
|---|---|---|---|
| `--file=custom.yaml` (file exists, has `flavors:`) | explicitFile | — | no |
| `--file=custom.yaml` (single config) | explicitFile | — | no |
| `--file=custom.yaml` (file missing) | exception | — | — |
| only `flutter_launcher_icons_flavors.yaml` | consolidatedFlavors | empty | no |
| consolidated + `flutter_launcher_icons-dev.yaml` | consolidatedFlavors | `[dev]` | yes (mentions `migrate`) |
| only legacy `flutter_launcher_icons-dev.yaml` | legacyFlavors | empty | yes (deprecation) |
| only `flutter_launcher_icons.yaml` | singleFile | — | no |
| only pubspec inline | pubspecInline | — | no |
| pubspec inline + single yaml | singleFile (single wins per documented precedence) | — | no |
| nothing | exception | — | — |

### 4.5 `test/main_consolidated_flow_test.dart`

- Lay down a complete project skeleton (icon image, pubspec, android/ios stubs) plus a `flutter_launcher_icons_flavors.yaml` with 2 flavors.
- Run `createIconsFromArguments(['--prefix', tempDir.path])`.
- Assert: both flavors generated their expected files; preflight passed; logger emitted no warnings (no legacy coexistence).

---

## 5. Definition of Done — self-check

- [ ] `dart pub get` / `dart run build_runner build` clean.
- [ ] `dart format --set-exit-if-changed .` clean.
- [ ] `dart analyze --fatal-infos` clean.
- [ ] `dart test` — all tests pass, including new merge / flavors-file / flavors-config / source-resolver / consolidated-flow suites.
- [ ] Existing single-config and legacy-multi-flavor flows continue to work (existing tests still green).
- [ ] `lib/config/flavors_file.dart`, `lib/config/merge.dart`, `lib/config/flavors_config.dart`, `lib/config/source_resolver.dart` exist and are exported only via existing `package:flutter_launcher_icons_flavored/...` paths.
- [ ] No reference to `--strict`, `--flavor`, `--all-flavors`, `migrate`, or `doctor` in code yet (those are Phase 4).
- [ ] Coexistence of new + legacy files emits a clear warning at runtime; the new file wins. Verified via end-to-end test.
- [ ] CHANGELOG.md / README.md untouched (Phase 5 owns them).
- [ ] pubspec version still `0.15.0-dev.1`.

If anything fails, stop and report. Phase 4 should not start until this is green.
