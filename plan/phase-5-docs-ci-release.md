# Phase 5 — Docs, CI, and Release

> **Read first:** `plan/README.md` for binding decisions, repo facts, and exit-code policy.
> **Depends on:** Phases 1–4 merged and green on CI.
> **Goal of this PR:** Ship `flutter_launcher_icons_flavored` v0.15.0 to pub.dev with rewritten docs, a dedicated flavors guide, a hardened CI matrix, and a clean release process. No behavior changes vs. Phase 4 — this PR is documentation, tooling, and the version bump.

---

## 1. Scope

In scope:
- Rewrite `README.md` for the renamed package and the consolidated flavors config.
- Add `doc/flavors.md` (long-form guide referenced from README).
- Add `doc/migration-0.15.md` (legacy → consolidated, min_sdk bump, package rename).
- Update `CHANGELOG.md` with the full 0.15.0 entry.
- Replace `.github/workflows/*` with a cross-platform matrix on Flutter `3.41.9` and `stable`.
- Add `pana` + `dart pub publish --dry-run` gates.
- Bump pubspec from `0.15.0-dev.1` → `0.15.0`, tag, publish.

Out of scope (deferred to 0.16+):
- `extends:` between flavors.
- Web/Linux/Windows launcher icon generation.
- Schema v2.

---

## 2. README.md rewrite

Replace the existing `README.md` with the following structure. Keep it skimmable; push depth into `doc/flavors.md`.

### Required sections (in order)

1. **Title + badges**
   - Title: `flutter_launcher_icons_flavored`
   - Badges: pub version, pub points, popularity, likes, CI status, license.
2. **One-paragraph description** — what the package does, that it is a flavor-aware fork of `flutter_launcher_icons`, and the supported platforms (Android, iOS, macOS, Web, Windows — match what the codebase actually generates today; do not promise Web/Win/Linux launcher icons if not implemented).
3. **Requirements**
   - Flutter `>= 3.41.9` (matches CI floor).
   - Dart SDK `>=3.0.0 <4.0.0`.
   - Android `minSdkVersion >= 24` (note this is the new default; see migration guide).
4. **Install**
   ```yaml
   dev_dependencies:
     flutter_launcher_icons_flavored: ^0.15.0
   ```
5. **Quick start (single-flavor)** — minimal `flutter_launcher_icons.yaml` example, then:
   ```
   dart run flutter_launcher_icons_flavored generate
   ```
6. **Multi-flavor (consolidated)** — point at `flutter_launcher_icons_flavors.yaml`, show a 2-flavor example with `defaults:` + `flavors:`, then:
   ```
   dart run flutter_launcher_icons_flavored generate --flavor dev
   dart run flutter_launcher_icons_flavored generate --all-flavors
   ```
   Explicitly state: with the consolidated file present and multiple flavors, omitting `--flavor`/`--all-flavors` exits **64**.
7. **Migrating from `flutter_launcher_icons`** — short blurb + link to `doc/migration-0.15.md`. Cover:
   - Package rename (import + dev_dependency change).
   - `flutter_icons:` pubspec key still works, prints a deprecation warning, removed in 0.17.
   - `min_sdk_android` default raised 21 → 24.
   - Legacy `flutter_launcher_icons-<flavor>.yaml` files still supported; coexistence rules (warn by default, `--strict` to error with exit 65).
   - `dart run flutter_launcher_icons_flavored migrate` automates conversion.
8. **CLI reference (one-liners only)** — `generate`, `migrate`, `doctor`. Link to Phase 4 doc-comments / `--help`.
9. **Configuration** — short table of top-level keys, link to `doc/flavors.md` for the full schema.
10. **Exit codes** — table: `0` success, `1` runtime error, `64` usage error, `65` config error.
11. **Contributing / License** — keep existing license; update repo URLs to renamed package if the GitHub repo is also renamed (confirm with user before editing repo URLs in pubspec).

### Things to remove from old README
- Any reference to the deleted `lib/pubspec_parser.dart`.
- Old `flutter_icons:` first-class examples (move to migration doc).
- Outdated min SDK 21 references.

---

## 3. `doc/flavors.md`

New file. Sections:

1. **Why a consolidated file** — single source of truth, deep-merged defaults, fewer YAML files in repo root.
2. **Schema reference** — full annotated example covering every supported key. Mirror the schema defined in `plan/phase-3-consolidated-flavors-config.md` §3. Document:
   - `version: 1` (required, integer).
   - `defaults:` (optional map, same shape as a single-flavor config).
   - `flavors:` (required map, key = flavor name matching `^[A-Za-z0-9][A-Za-z0-9_-]*$`).
   - Per-flavor block accepts the same keys as `defaults`.
3. **Deep merge semantics** — explicit rules:
   - Maps merge recursively.
   - Scalars and lists in a flavor override defaults wholesale.
   - Explicit `null` in a flavor **deletes** the inherited key (give a worked example: `adaptive_icon_background: null`).
4. **Source resolution precedence** — restate the Phase 3 precedence list:
   1. `flutter_launcher_icons_flavors.yaml`
   2. `flutter_launcher_icons-<flavor>.yaml`
   3. `flutter_launcher_icons.yaml`
   4. `flutter_icons:` block in `pubspec.yaml` (deprecated).
5. **Coexistence and `--strict`** — what the warning looks like, when to use `--strict`, exit 65 example.
6. **Migration walkthrough** — run `migrate`, inspect diff, commit. Show before/after for a 3-flavor project. Mention the "promotion candidates" report and that auto-promotion to `defaults:` is intentionally **not** done.
7. **Troubleshooting** — common errors:
   - Invalid flavor name → exit 65 with regex shown.
   - Unknown top-level key → exit 65.
   - Missing `--flavor`/`--all-flavors` with multi-flavor consolidated config → exit 64.

---

## 4. `doc/migration-0.15.md`

New file. Audience: existing `flutter_launcher_icons` users. Sections:

1. **TL;DR checklist** (5 bullets max).
2. **Step 1 — Rename dependency** (`flutter_launcher_icons` → `flutter_launcher_icons_flavored`). Show pubspec diff.
3. **Step 2 — Update CLI invocation** (`dart run flutter_launcher_icons` → `dart run flutter_launcher_icons_flavored generate`).
4. **Step 3 — Decide on consolidated config** — run `migrate --dry-run`, then `migrate`.
5. **Step 4 — Bump `min_sdk_android`** — if you must stay on 21–23, set it explicitly in your config; otherwise accept the new default of 24.
6. **Step 5 — Replace `flutter_icons:` pubspec key** — moved to its own file; deprecation warning until 0.17.
7. **Breaking changes table** — one row per break with before/after.
8. **Non-breaking improvements** — KTS gradle support, async I/O, better error messages, `doctor` command.

---

## 5. CHANGELOG.md — 0.15.0 entry

Replace the top of `CHANGELOG.md` with:

```markdown
## 0.15.0

### Breaking
- Renamed package to `flutter_launcher_icons_flavored`. Update `dev_dependencies` and `dart run` invocations.
- Default `min_sdk_android` raised from 21 to 24. Set it explicitly in config to keep the old value.
- CLI restructured under subcommands: `generate`, `migrate`, `doctor`. The bare `dart run flutter_launcher_icons_flavored` now prints help; pass `generate` to keep prior behavior.
- With the consolidated `flutter_launcher_icons_flavors.yaml` present and more than one flavor defined, `generate` requires `--flavor <name>` or `--all-flavors`. Exits 64 otherwise. Legacy `flutter_launcher_icons-<flavor>.yaml` workflows are unchanged and still build all flavors by default.

### Added
- Consolidated multi-flavor config file `flutter_launcher_icons_flavors.yaml` with `defaults:` deep-merged into each flavor, and explicit `null` to delete inherited keys.
- `migrate` command converts legacy `flutter_launcher_icons-<flavor>.yaml` files into the consolidated format and prints a "promotion candidates" report.
- `doctor` command reports SDK versions, detected configs, conflicts, and the resolved source for each flavor.
- `--strict` flag on `generate` promotes coexistence warnings to errors (exit 65).
- Kotlin DSL (`build.gradle.kts`) support for Android `minSdk` parsing.

### Fixed
- `getFlavors()` now respects `--prefix` (previously hard-coded `Directory('.')`).
- `prefixPath` is now threaded through Android icon generation (resolves the `// TODO(p-mazhnik)` in `lib/android.dart`).
- Path construction uses `package:path` instead of string concatenation.
- `Config.android` / `Config.ios` are no longer typed `dynamic`.
- `decodeImageFile` return type corrected (no longer falsely nullable).

### Removed
- Dead `lib/pubspec_parser.dart`.

### Deprecated
- `flutter_icons:` block in `pubspec.yaml`. Still works in 0.15.x with a warning; removed in 0.17.

### Internal
- Added `PartialConfig` / `PlatformToggle` types.
- Async I/O on icon-generation hot paths.
- CI now runs on Ubuntu, macOS, and Windows against Flutter 3.41.9 and stable.
- Added `pana` and `dart pub publish --dry-run` gates.
```

---

## 6. CI matrix — `.github/workflows/`

Replace existing workflows with two files.

### 6.1 `.github/workflows/ci.yml`

Triggers: `push` to any branch, `pull_request` to `main`.

Matrix:
- `os: [ubuntu-latest, macos-latest, windows-latest]`
- `flutter: ['3.41.9', 'stable']`
- `fail-fast: false`

Steps per job:
1. `actions/checkout@v4`.
2. `subosito/flutter-action@v2` with the matrix `flutter` channel/version.
3. `flutter --version` (sanity).
4. `dart pub get`.
5. `dart format --output=none --set-exit-if-changed .`.
6. `dart analyze --fatal-infos`.
7. `dart test --reporter=expanded`.
8. **Linux + Flutter 3.41.9 only** (gate via `if:`):
   - `dart pub global activate pana`.
   - `pana --no-warning --exit-code-threshold 0` (fail on any pana issue).
   - `dart pub publish --dry-run`.

Cache: `subosito/flutter-action`'s built-in cache plus `actions/cache` keyed on `pubspec.lock` for `~/.pub-cache`.

### 6.2 `.github/workflows/release.yml`

Triggers: `push` of tags matching `v*.*.*`.

Steps:
1. Checkout.
2. Setup Dart/Flutter at `3.41.9`.
3. `dart pub get`.
4. `dart analyze --fatal-infos`, `dart test`.
5. `dart pub publish --dry-run`.
6. Publish via **OIDC** using `dart-lang/setup-dart@v1` (no long-lived tokens). Required workflow permissions:
   ```yaml
   permissions:
     id-token: write   # required for OIDC
     contents: write   # required for action-gh-release
   ```
   Then `dart pub publish --force`. The pub.dev publisher must be configured to trust `github.com/<owner>/flutter_launcher_icons_flavored` on the `release.yml` workflow before the first tag push (see §11 pre-release check).
7. `softprops/action-gh-release@v2` to create a GitHub Release with the CHANGELOG section auto-extracted.

### 6.3 Branch protection (manual, document in PR description)
- Require `ci.yml` matrix to pass on `main`.
- Require linear history.
- Require signed commits (if user already enforces).

---

## 7. Pubspec final touches

By Phase 5 the pubspec already has the renamed `name`, the `topics`, and `screenshots` from Phase 2. In this PR:

- Bump `version: 0.15.0-dev.1` → `version: 0.15.0`.
- Set pubspec URLs to the renamed repo:
  - `homepage: https://github.com/<owner>/flutter_launcher_icons_flavored`
  - `repository: https://github.com/<owner>/flutter_launcher_icons_flavored`
  - `issue_tracker: https://github.com/<owner>/flutter_launcher_icons_flavored/issues`
  (Confirm `<owner>` with user — repo is confirmed renamed but owner not yet captured in plan.)
- Confirm `description` is 60–180 chars (pana enforces this).
- Do **not** add a `funding:` field (per binding decision in `plan/README.md`).

---

## 8. Pre-release verification checklist

Run locally on a clean clone before tagging:

1. `dart pub get`
2. `dart format --output=none --set-exit-if-changed .`
3. `dart analyze --fatal-infos`
4. `dart test`
5. `dart pub global activate pana && pana --no-warning` — target score: **140/140**, or document any unavoidable deduction in the PR.
6. `dart pub publish --dry-run` — must report zero warnings.
7. Smoke test in a throwaway Flutter app:
   - Add `flutter_launcher_icons_flavored: ^0.15.0` from a local `path:` override.
   - Run `generate`, `migrate --dry-run`, `doctor`.
   - Verify Android (KTS + Groovy), iOS, and at least one of macOS/Web outputs.
8. Re-run smoke test on macOS and Windows runners (the CI matrix covers this, but do one manual pass).

---

## 9. Release procedure

1. Open Phase 5 PR. CI green on all 6 matrix cells.
2. Squash-merge to `main`.
3. From `main`: `git tag v0.15.0 && git push origin v0.15.0`.
4. `release.yml` publishes to pub.dev and creates the GitHub Release.
5. Verify the package page on pub.dev:
   - Score ≥ 140.
   - Topics render.
   - Screenshots render.
   - README renders without broken links to `doc/flavors.md` / `doc/migration-0.15.md` (pub.dev serves these from the package tarball).
6. Post-release: open a tracking issue for 0.16 (`extends:` between flavors, schema v2 exploration).

---

## 10. Files touched in this PR

- `README.md` — full rewrite.
- `doc/flavors.md` — new.
- `doc/migration-0.15.md` — new.
- `CHANGELOG.md` — prepend 0.15.0 entry.
- `.github/workflows/ci.yml` — replace.
- `.github/workflows/release.yml` — new (or replace if one exists).
- `pubspec.yaml` — version bump only.
- Delete any stale `.github/workflows/*.yml` not listed above.

No `lib/` or `test/` changes in this PR. If any are needed, they belong in a Phase 1–4 follow-up, not here.

---

## 11. Acceptance criteria

- [ ] CI matrix green on Ubuntu/macOS/Windows × Flutter 3.41.9/stable.
- [ ] `pana` reports ≥ 140/140 (or documented deduction).
- [ ] `dart pub publish --dry-run` clean.
- [ ] README renders correctly on pub.dev preview.
- [ ] `doc/flavors.md` and `doc/migration-0.15.md` linked from README and reachable on pub.dev.
- [ ] CHANGELOG 0.15.0 entry matches §5 verbatim (modulo last-minute fixes).
- [ ] Tag `v0.15.0` published; GitHub Release created; pub.dev shows 0.15.0 within 10 minutes of tag.
- [ ] Tracking issue for 0.16 opened.

---

## 12. Pre-release blockers (must clear before tagging `v0.15.0`)

These are not optional. Tagging without them will cause `release.yml` to fail or publish to the wrong place.

1. **pub.dev publisher claim.** The package name `flutter_launcher_icons_flavored` must be owned by a pub.dev publisher (verified domain or Google account) controlled by the user.
2. **OIDC trust configured on pub.dev.** Under the publisher's "Automated publishing" settings, add a trust entry for:
   - Repository: `<owner>/flutter_launcher_icons_flavored`
   - Workflow: `.github/workflows/release.yml`
   - Tag pattern: `v*.*.*`
3. **First publish dry-run from `main`** — run `dart pub publish --dry-run` on the merged Phase 5 commit; must report zero warnings.
4. **Confirm `<owner>` for pubspec URLs** — capture the GitHub org/user name and substitute into the three URL fields in §7.

---

## 13. Open questions for the user (resolve before merging)

All Phase 5 open questions resolved as of plan revision:
- Repo: renamed to `flutter_launcher_icons_flavored` ✅
- Publish method: OIDC via `dart-lang/setup-dart@v1` ✅
- Publisher claim: **not yet configured** — see §11 blocker #1 and #2.

Remaining unknown: GitHub `<owner>` (org or user) for the renamed repo. Capture before editing `pubspec.yaml` URLs in §7.
