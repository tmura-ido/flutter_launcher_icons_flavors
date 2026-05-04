# Implementation plan — phase index

This directory splits the master plan ([`../plan.md`](../plan.md)) into 5 self-contained phase files. **Each phase is executable independently** in a fresh agent/editor context — no need to load the others.

| Phase | File | Title | Depends on |
|---|---|---|---|
| 1 | [`phase-1-internal-refactor-and-rename.md`](phase-1-internal-refactor-and-rename.md) | Internal refactor + project rename (no schema change) | — |
| 2 | [`phase-2-platform-hardening-and-min-sdk-bump.md`](phase-2-platform-hardening-and-min-sdk-bump.md) | Platform/probe hardening + `min_sdk_android` default bump | Phase 1 |
| 3 | [`phase-3-consolidated-flavors-config.md`](phase-3-consolidated-flavors-config.md) | New `flutter_launcher_icons_flavors.yaml` consolidated config | Phase 1 (Phase 2 not strictly required) |
| 4 | [`phase-4-cli-restructure-and-commands.md`](phase-4-cli-restructure-and-commands.md) | CLI restructure: `CommandRunner`, `migrate`, `doctor` | Phase 3 |
| 5 | [`phase-5-docs-ci-release.md`](phase-5-docs-ci-release.md) | Docs, CI matrix, release of 0.15.0 | Phases 1–4 |

## How to run a phase in a fresh context

Open a new agent session with this repo as the working directory and provide the relevant phase file as the only instruction. Each phase file contains:

- The minimum repo context the executor needs.
- All user-confirmed decisions relevant to that phase.
- A precise scope (in/out).
- File-by-file edit list.
- Test plan.
- Definition of Done / acceptance criteria.
- A self-test checklist before marking the phase complete.

Suggested prompt for each phase:

> Implement the work described in `plan/phase-N-*.md`. Stay strictly within scope. Do not start work outside the phase. Before finishing, run through the Definition of Done checklist at the bottom and report results.

## Binding decisions (apply to every phase)

1. Package rename: `flutter_launcher_icons` → **`flutter_launcher_icons_flavors`**.
2. Default `min_sdk_android` raised 21 → **24** (breaking).
3. Deprecated `flutter_icons:` pubspec key continues to work with a warning until 0.17.
4. Delete dead file `lib/pubspec_parser.dart`.
5. No `funding:` field in `pubspec.yaml` for 0.15.0.
6. Flavor name regex: `^[A-Za-z0-9][A-Za-z0-9_-]*$`.
7. Dart SDK floor raised to `>=3.8.0 <4.0.0` (required by json_serializable's null-aware-element output for `includeIfNull: false` and aligns with the project's Flutter 3.41.9 / Dart 3.10 target).
8. `image` stays on `^4.x` (no major bump).
9. Filenames the package *consumes* do **not** change: `flutter_launcher_icons.yaml`, `flutter_launcher_icons-<flavor>.yaml`, `flutter_launcher_icons_flavors.yaml`, and pubspec key `flutter_launcher_icons:` remain.

## Repository facts (current state, v0.14.4)

- Package name: `flutter_launcher_icons` (will be renamed in Phase 1).
- Entry point: `bin/main.dart` → `lib/main.dart` → uses `package:args` `ArgParser` (flat).
- Flavor handling: `lib/main.dart` `getFlavors()` scans `Directory('.')` for regex `^flutter_launcher_icons-(.*).yaml$`. `--prefix` is **silently ignored** by this scan (bug).
- Config model: `lib/config/config.dart`, `@JsonSerializable(anyMap: true, checked: true)`. `android` and `ios` are `dynamic` (path-or-bool).
- Generators: `lib/android.dart`, `lib/ios.dart`, `lib/web/`, `lib/windows/`, `lib/macos/`. `lib/android.dart` has `// TODO(p-mazhnik): support prefixPath`.
- Constants: `lib/constants.dart` uses string concat (`+ '/' +`) instead of `path.join`. Hard-codes `android/app/build.gradle` (no `.kts` support).
- Dead code: `lib/pubspec_parser.dart` (delete in Phase 1).
- Tests: `test/` exists; coverage of flavors / Windows paths / Kotlin DSL is shallow.
- `analysis_options.yaml` references obsolete lints (issue #598 partially addressed).

## Master plan reference

See [`../plan.md`](../plan.md) for full rationale, council deliberation, and resolved disagreements.
