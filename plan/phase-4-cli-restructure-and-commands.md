# Phase 4 — CLI restructure: `CommandRunner`, new flags, `migrate` and `doctor`

> **Depends on**: Phase 3 complete (`FlavorsConfig`, `resolveSource`, deep merge all in place).
> **User-visible behavior change**: Yes — the CLI gains subcommands and several new flags. The bare invocation (`dart run flutter_launcher_icons_flavored`) still defaults to `generate` for back-compat. **The default behavior when a consolidated file has more than one flavor changes**: it now requires `--flavor` or `--all-flavors`. This is documented as a notable behavior change in 0.15.0.
> **Goal**: ship the production-ready CLI: subcommands, flag set, exit codes, `migrate`, `doctor`.

---

## 0. Context

You are working on the Dart package `flutter_launcher_icons_flavored`. Phases 1–3 prepared the foundations: typed config models, deep merge, `FlavorsConfig` loader, precedence resolver. Phase 4 finalizes the CLI surface.

Why this phase exists separately from Phase 3:

- The schema work in Phase 3 is independently valuable and testable; bundling the CLI restructure with it would balloon the diff and complicate review.
- `migrate` and `doctor` benefit from the schema + resolver already being stable.

Binding decisions (do not deviate):

- Migrate to `package:args` `CommandRunner`. Subcommands: `generate` (default), `migrate`, `doctor`.
- Bare invocation = `generate` for back-compat. (`dart run flutter_launcher_icons_flavored` still works as today.)
- New flags on `generate`: `--flavor` (repeatable), `--all-flavors`, `--list-flavors`, `--continue-on-error`, `--strict`.
- Existing flags preserved: `-f`/`--file`, `-p`/`--prefix`, `-v`/`--verbose`, `-h`/`--help`.
- Exit codes: `0` success, `1` runtime/IO failure, `64` CLI usage error, `65` config error.
- **Behavior change**: when consolidated file has >1 flavor and neither `--flavor` nor `--all-flavors` is given → exit 64 with a list of available flavors. Legacy mode still defaults to "build all" (preserves backward compat for users still on per-file flavors).
- `--strict` escalates the new+legacy coexistence warning to an exit-65 error.
- `migrate` is non-destructive by default (writes `.bak`), supports `--in-place`, `--dry-run`, `--force`.
- `doctor` only diagnoses; never writes.

---

## 1. In-scope work for Phase 4

### 1.1 `CommandRunner` migration

- New file `lib/cli/command_runner.dart`:
  ```dart
  CommandRunner<int> buildCommandRunner() {
    final runner = CommandRunner<int>(
      'flutter_launcher_icons_flavored',
      'Generate launcher icons for Flutter apps.',
    )
      ..addCommand(GenerateCommand())
      ..addCommand(MigrateCommand())
      ..addCommand(DoctorCommand());
    return runner;
  }
  ```
- The `int` return type is the desired exit code; the entry point converts it to `exit(code)`.
- `bin/main.dart` (and `bin/flutter_launcher_icons.dart` if kept):
  ```dart
  Future<void> main(List<String> args) async {
    final runner = buildCommandRunner();
    // Bare invocation (no args, or args don't start with a known subcommand) defaults to `generate`.
    final effective = _effectiveArgs(runner, args);
    final code = await runner.run(effective) ?? 0;
    exit(code);
  }
  ```
- `_effectiveArgs` prepends `'generate'` if and only if the first non-flag argument is not one of `generate|migrate|doctor|help`. This preserves all current invocations like `dart run flutter_launcher_icons_flavored -f my.yaml --prefix subdir`.

### 1.2 `GenerateCommand` (`lib/cli/generate_command.dart`)

- Args parser:
  - `-f`, `--file <path>` (existing)
  - `-p`, `--prefix <path>` (existing, defaults to `.`)
  - `--flavor <name>` (repeatable, multiple)
  - `--all-flavors` (flag)
  - `--list-flavors` (flag)
  - `--continue-on-error` (flag)
  - `--strict` (flag)
  - `-v`, `--verbose` (existing)
- Run:
  1. Construct `FLILogger` with verbose flag.
  2. Resolve source via `resolveSource(prefixPath: prefix, explicitFilePath: file)`.
  3. If `--list-flavors`: print discovered flavors from the chosen source and exit 0. (For single-config sources, print nothing or a single line "no flavors; single config".)
  4. If chosen source is `consolidatedFlavors` (or `--file` pointing to a multi-flavor file):
     - Load via `FlavorsConfig.load(path)`.
     - Compute selected flavors:
       - `--flavor a --flavor b` → `[a, b]`. Each must exist in the file or exit 64.
       - `--all-flavors` → all flavors.
       - Neither, single-flavor file → that one.
       - Neither, multi-flavor file → exit 64 with a clear message listing available flavors.
     - **Preflight**: call `flavorsConfig.resolve(name)` for every selected flavor. If any throws → log error with field path, exit 65 (no files written).
     - If preflight passed but `ignoredLegacy` from the resolver is non-empty:
       - If `--strict`: exit 65 with `MixedConfigSourcesException`.
       - Else: warning was already logged by the resolver; continue.
     - Generate icons for each flavor in sequence. On failure:
       - Default: log error, abort with exit 1, return summary.
       - With `--continue-on-error`: log error, mark flavor as failed, continue, exit 1 at end with summary listing successes/failures.
  5. If chosen source is `legacyFlavors`:
     - Discover the legacy files (existing behavior).
     - If `--flavor` is given, filter: only build legacy files matching the names. Missing → exit 64 with available names list.
     - Else build all (preserves current behavior).
     - `--all-flavors` is a no-op here (not an error; logs an info note).
     - `--continue-on-error` semantics same as consolidated.
     - Emits the deprecation warning (already from resolver).
  6. If chosen source is `singleFile`, `pubspecInline`, or `explicitFile` pointing to a single config: build single config (existing behavior). `--flavor` with a non-matching name → exit 64. `--all-flavors`/`--list-flavors` → no-op for singles (info note).
- Exit codes:
  - `0` success.
  - `1` generation/IO failure (image decode/write, file system).
  - `64` usage error (unknown flavor, conflicting flags, multi-flavor consolidated without `--flavor`/`--all-flavors`).
  - `65` config validation error / strict-mode coexistence / preflight failure / `NoConfigFoundException`.

### 1.3 `MigrateCommand` (`lib/cli/migrate_command.dart`)

- Args:
  - `-p`, `--prefix <path>` (default `.`)
  - `--dry-run` (flag)
  - `--in-place` (flag)
  - `--force` (flag) — overwrite existing `flutter_launcher_icons_flavors.yaml`.
- Behavior:
  1. Discover legacy files (`<prefix>/flutter_launcher_icons-*.yaml`).
  2. If none found → exit 0 with info "no legacy flavor files found; nothing to migrate."
  3. If `<prefix>/flutter_launcher_icons_flavors.yaml` already exists:
     - With `--force` → proceed (will overwrite).
     - Else → exit 64 with message recommending `--force` if intentional.
  4. Parse each legacy file (extracting `flutter_launcher_icons` / `flutter_icons` block).
  5. Compose a new `FlavorsFile` shape:
     - `version: 1`
     - `defaults:` left **empty** (per binding decision: no auto-extraction).
     - `flavors:` map with each flavor as a fully-specified block.
  6. Compute "candidates for promotion to defaults": keys whose values are identical across **all** flavors. Print a report after the write:
     ```
     ✓ Wrote flutter_launcher_icons_flavors.yaml (3 flavors)
     ℹ Candidates for promotion to defaults (identical across all flavors):
         android: true
         ios: true
         remove_alpha_ios: true
       Move these into the `defaults:` block manually if desired.
     ```
  7. If `--dry-run`: print the would-be YAML to stdout, do not write any files. Print the candidates report. Exit 0.
  8. Else: write `<prefix>/flutter_launcher_icons_flavors.yaml`. For each legacy file, copy to `<original>.bak` (sibling). Then:
     - With `--in-place`: delete the originals (the `.bak` copies remain as safety).
     - Else: leave originals in place.
- Exit codes: `0` success, `1` runtime/IO, `64` usage (legacy file unparseable, target exists without `--force`), `65` config invalid.
- Use a deterministic YAML emitter — sort keys alphabetically inside each block to make the output stable for golden tests.

### 1.4 `DoctorCommand` (`lib/cli/doctor_command.dart`)

- Args:
  - `-p`, `--prefix <path>` (default `.`)
  - `-v`, `--verbose`
- Behavior: pure read; never writes. Prints a structured report. Returns 0 unless something is genuinely broken (then 65 with the same report).

  Report sections, in order:
  1. Tool version (read from `lib/src/version.dart`).
  2. Resolved `--prefix` (absolute path).
  3. Detected config sources, each: `[FOUND]` / `[absent]`:
     - `--file` (always absent here since doctor has no `--file`).
     - `flutter_launcher_icons_flavors.yaml`
     - any `flutter_launcher_icons-*.yaml` (list each)
     - `flutter_launcher_icons.yaml`
     - `pubspec.yaml` flutter_launcher_icons / flutter_icons key
  4. Precedence winner — name and reason.
  5. Sources ignored due to precedence — list with the warning text that `generate` would emit.
  6. Parsed flavor list (for the winning source). In `--verbose`: print each resolved `Config` summary (platforms enabled, `min_sdk_android`, etc.).
  7. Android Gradle detection:
     - Detected file (`build.gradle.kts` / `build.gradle` / none).
     - Detected `min_sdk_android` value and the regex pattern that matched (or "default 24 used", or "could not auto-detect — specify min_sdk_android in your config").
  8. Deprecated key usage (`flutter_icons:` in pubspec).
- Even if precedence winner has invalid configs, doctor reports them but does not abort generation (it never generates).

### 1.5 Update `lib/main.dart`

- The legacy `createIconsFromArguments(List<String>)` becomes a thin shim that delegates to `buildCommandRunner().run(...)`. Or remove it entirely if no remaining caller exists outside `bin/`. Verify by searching for its imports.

### 1.6 `--strict` wiring

- The `MixedConfigSourcesException` defined in Phase 3 becomes throwable in Phase 4. `GenerateCommand` consults `--strict`. `resolveSource` already returns `ignoredLegacy`; the command (not the resolver) decides whether to escalate.

---

## 2. Out of scope

- README / CHANGELOG content (Phase 5).
- Pubspec version bump from `-dev.1` to `0.15.0` (Phase 5).
- CI matrix changes (Phase 5).

---

## 3. File-by-file change list

| File | Action |
|---|---|
| `lib/cli/command_runner.dart` (NEW) | `buildCommandRunner` factory. |
| `lib/cli/generate_command.dart` (NEW) | `GenerateCommand`. |
| `lib/cli/migrate_command.dart` (NEW) | `MigrateCommand`. |
| `lib/cli/doctor_command.dart` (NEW) | `DoctorCommand`. |
| `lib/cli/yaml_emit.dart` (NEW, optional) | Deterministic YAML emitter for `migrate` (alphabetized, stable quoting). Or use a third-party emitter if cleaner. |
| `bin/main.dart` | Switch to `buildCommandRunner`. Bare-invocation default-to-`generate` shim. |
| `bin/flutter_launcher_icons.dart` | Same. |
| `bin/generate.dart` | Decide: keep as-is (generates a config template via `build_version` mechanism) OR fold into `MigrateCommand`/scaffolder. Default: keep as-is; only fix the package-name reference if any. |
| `lib/main.dart` | Slim down `createIconsFromArguments` or remove if unused. |
| `lib/custom_exceptions.dart` | `MixedConfigSourcesException` becomes used (was defined in Phase 3). |
| `test/cli/generate_command_test.dart` (NEW) | Subcommand parsing + flag combinations + exit codes. |
| `test/cli/migrate_command_test.dart` (NEW) | Migrate behaviors. |
| `test/cli/doctor_command_test.dart` (NEW) | Doctor output goldens. |
| `test/cli/exit_codes_test.dart` (NEW) | Every documented exit code is reachable. |
| `test/cli/strict_test.dart` (NEW) | `--strict` upgrades coexistence warning to error. |
| `test/cli/all_flavors_test.dart` (NEW) | Multi-flavor consolidated default behavior + `--all-flavors` + repeated `--flavor`. |
| `test/cli/continue_on_error_test.dart` (NEW) | Failure of one flavor doesn't abort, summary printed. |

---

## 4. Tests to add (Phase 4)

### 4.1 `test/cli/generate_command_test.dart`

- Bare invocation works (defaults to `generate`).
- `--list-flavors` prints flavors and exits 0 without generating.
- `--flavor dev` builds only dev when consolidated has dev/staging/prod.
- `--flavor dev --flavor staging` builds both.
- `--flavor nonexistent` → exit 64 listing available flavors.
- `--all-flavors` builds everything.
- Multi-flavor consolidated, neither flag → exit 64 with available list.
- Single-flavor consolidated, neither flag → builds the one flavor (ergonomic).
- Single-config source + `--flavor` non-matching → exit 64.
- Single-config source + `--flavor main` (or whatever matches) → builds normally.

### 4.2 `test/cli/migrate_command_test.dart`

- 3 legacy files → produces `flutter_launcher_icons_flavors.yaml` with 3 flavors fully specified, empty `defaults`, version: 1.
- Output is deterministic (run twice, byte-identical).
- `--dry-run` writes nothing, prints YAML.
- `--in-place` deletes legacy files; `.bak` copies remain.
- Existing target without `--force` → exit 64.
- Existing target with `--force` → overwrites.
- "Candidates for promotion" report appears with correct identical keys.
- Golden test: a fixture set of 3 legacy files compared semantically (parse-and-compare maps, not stringly).

### 4.3 `test/cli/doctor_command_test.dart`

- Project with consolidated file + legacy files: doctor prints both, marks consolidated as winner, lists legacy as ignored.
- Project with KTS-only gradle: doctor reports `build.gradle.kts` and detected `min_sdk`.
- Project with version-catalog gradle: doctor reports detection failure with actionable hint.
- Project with no config at all: doctor still runs (prints "no config found"), exits 65.
- Golden output for several layouts.

### 4.4 `test/cli/strict_test.dart`

- New file + legacy files coexisting, no flag → warning, exit 0 (after generation).
- Same with `--strict` → exit 65, no files written.

### 4.5 `test/cli/all_flavors_test.dart` and `continue_on_error_test.dart`

- Covered above.

### 4.6 `test/cli/exit_codes_test.dart`

- Each documented code (`0`, `1`, `64`, `65`) is reachable via specific scenarios.

---

## 5. Definition of Done — self-check

- [ ] `dart pub get` clean.
- [ ] `dart format --set-exit-if-changed .` clean.
- [ ] `dart analyze --fatal-infos` clean.
- [ ] `dart test` — all tests pass.
- [ ] Bare invocation (`dart run flutter_launcher_icons_flavored`) defaults to `generate` and behaves identically to current 0.14.4 for users with a single `flutter_launcher_icons.yaml` or pubspec inline config.
- [ ] `dart run flutter_launcher_icons_flavored migrate --dry-run` works on a fixture project.
- [ ] `dart run flutter_launcher_icons_flavored doctor` works on a fixture project.
- [ ] `--strict` is a no-op when no coexistence; escalates to exit 65 when coexistence present.
- [ ] Multi-flavor consolidated without `--flavor`/`--all-flavors` exits 64 with a clear available-flavors list.
- [ ] Repeated `--flavor a --flavor b` works.
- [ ] `--list-flavors` prints discovered names and exits 0 (no generation).
- [ ] `--continue-on-error` surfaces a per-flavor summary at the end and exits 1 if any failed.
- [ ] CHANGELOG.md / README.md untouched (Phase 5 owns them).
- [ ] pubspec version still `0.15.0-dev.1`.

If anything fails, stop and report. Phase 5 should not start until this is green.
