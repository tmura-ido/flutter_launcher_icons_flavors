# Phase 2 — Platform/probe hardening + `min_sdk_android` default bump

> **Depends on**: Phase 1 complete (rename done, `prefixPath` threading done, `PartialConfig` split exists).
> **User-visible behavior change**: Yes — Kotlin DSL projects now have working `min_sdk_android` autodetection; default `min_sdk_android` rises 21 → 24 (BREAKING for users on lower API levels who relied on the default).
> **Goal**: make autodetection actually work on modern Flutter projects, raise the floor to match modern defaults, and migrate generator hot paths to async I/O.

---

## 0. Context

You are working on the renamed Dart package `flutter_launcher_icons_flavors` (was `flutter_launcher_icons`) at the repo root. Phase 1 completed an internal refactor (no schema change); now Phase 2 hardens platform integrations.

Why this phase exists:

- Flutter 3.16+ projects default to Kotlin DSL `build.gradle.kts`. The current code hard-codes `android/app/build.gradle` (Groovy) and silently falls back to a bogus default when it can't find the file. Users on modern Flutter templates get wrong/missing `min_sdk_android` autodetection.
- Default `min_sdk_android` is currently **21**. Modern Flutter project templates use 24. Per user decision this is bumped to **24** (breaking).
- `decodeImageFile` was tightened in Phase 1; this phase migrates the generator hot paths (image read/write/decode) to async, which is a real perf win on multi-flavor runs (later phases).
- `pubspec.yaml` lacks `topics` and `screenshots`, hurting pub.dev score.

Binding decisions (do not deviate):

- Bump `androidDefaultAndroidMinSDK` from `21` → `24`.
- Add `topics: [icons, flutter, launcher, flavors, build]` and `screenshots:` to `pubspec.yaml`. **Do NOT add `funding:`.**
- Stay on `image: ^4.x` (no major bump).
- Keep `Config.loadConfigFromPath` and friends synchronous (do not async-ify config loading; only generator hot paths).

---

## 1. In-scope work for Phase 2

### 1.1 Kotlin DSL gradle support

Touch points: `lib/constants.dart`, `lib/android.dart`, and whatever helper currently extracts `min_sdk` from gradle (likely in `lib/android.dart` or a small helper).

- Replace the constant `androidGradleFile = 'android/app/build.gradle'` with a function `Future<File?> findAndroidGradleFile(String prefixPath)` that probes (in order):
  1. `<prefix>/android/app/build.gradle.kts`
  2. `<prefix>/android/app/build.gradle`
  3. Returns `null` if neither exists.
- Same pattern for the Flutter SDK gradle path (the file referenced for `flutter.minSdkVersion`): probe `flutter.gradle.kts` then `flutter.gradle`.
- Replace the `min_sdk` extraction regex with a function that tries multiple patterns in order until one matches:

  Groovy:
  - `/^\s*minSdkVersion\s+(\d+)\s*$/m`
  - `/^\s*minSdkVersion\s*=\s*(\d+)\s*$/m`
  - `/^\s*minSdk\s+(\d+)\s*$/m`
  - `/^\s*minSdk\s*=\s*(\d+)\s*$/m`
  - `/^\s*minSdkVersion\s+flutter\.minSdkVersion\s*$/m` → recurse into Flutter SDK gradle.

  Kotlin DSL:
  - `/^\s*minSdk\s*=\s*(\d+)\s*$/m`
  - `/^\s*minSdkVersion\s*=\s*(\d+)\s*$/m`
  - `/^\s*minSdk\(\s*(\d+)\s*\)\s*$/m`
  - `/^\s*minSdk\s*=\s*flutter\.minSdkVersion\s*$/m` → recurse.
- If recursion into Flutter's gradle file fails, fall back to `<prefix>/android/local.properties` for `flutter.minSdkVersion=...`.
- If all probes fail: emit a clear error using the new logger:
  > `could not auto-detect min_sdk_android from build.gradle/build.gradle.kts; specify min_sdk_android in your config`

  and return `null` rather than silently defaulting. Caller falls back to `androidDefaultAndroidMinSDK` (now 24).
- Document explicit limitations in code comments and (later, Phase 5) in README:
  - Version catalogs (`libs.versions.toml`) are not parsed. User must specify `min_sdk_android` explicitly.
  - Convention plugins are not parsed. Same.

### 1.2 `min_sdk_android` default 21 → 24 (BREAKING)

- `lib/constants.dart`:
  ```dart
  // BREAKING (0.15.0): bumped from 21 to 24 to match modern Flutter project defaults.
  // See plan §6.9. Users targeting lower API levels must specify min_sdk_android explicitly.
  const int androidDefaultAndroidMinSDK = 24;
  ```
- Update any test fixture / golden value that depended on the old `21` default.
- Add a regression test: `Config.fromJson({...without min_sdk_android})` → resolved `Config.minSdkAndroid == 24`. Explicit `min_sdk_android: 21` overrides to 21.

### 1.3 Async generator hot paths

Scope: image read / decode / encode / write only. Do NOT async-ify `Config.loadConfigFromPath` or any other config-loading static factory.

- `lib/utils.dart`:
  - `decodeImageFile` already returns `Future<Image>` after Phase 1. Confirm it uses `await File(path).readAsBytes()` (async), not `readAsBytesSync`.
  - Audit `createFileIfNotExist` and `createDirIfNotExist` — keep their existing sync existence check (per the lint rationale, but update the comment) and use async `create`.
- `lib/android.dart`, `lib/ios.dart`, `lib/web/**`, `lib/windows/**`, `lib/macos/**`:
  - Replace any `File(...).writeAsBytesSync(...)` with `await File(...).writeAsBytes(...)`.
  - Replace any sync image encode (`encodePng(...)` then `writeAsBytesSync`) with the async write equivalent.
  - Where a method becomes async-only, propagate `async`/`await` up the call chain; update return types to `Future<void>` consistently.
  - The `Future.wait([...])` patterns already in `lib/main.dart` should now actually overlap I/O.

### 1.4 Pubspec metadata

- `pubspec.yaml` add:
  ```yaml
  topics:
    - icons
    - flutter
    - launcher
    - flavors
    - build
  screenshots:
    - description: 'Adaptive launcher icons generated for Android'
      path: doc/screenshots/adaptive.png
  ```
- Create `doc/screenshots/adaptive.png` — use a small placeholder if no real screenshot is available; sized appropriately for pub.dev (1280×640 or square 800×800 works). If you cannot create the asset, comment out the `screenshots:` block with a `# TODO(release):` note instead of leaving a broken reference.
- **Do NOT add `funding:`** (deferred per user decision).

### 1.5 Stale `avoid_slow_async_io` comments

- `lib/utils.dart` `createFileIfNotExist` / `createDirIfNotExist` carry a comment:
  > `// Using the sync method here due to 'avoid_slow_async_io' lint suggestion.`

  Replace with a clearer rationale that does not mislead future readers:
  > `// existsSync is intentional: this is on the CLI startup path where blocking briefly is preferable to the overhead of a microtask. Image I/O hot paths use the async equivalents.`

---

## 2. Out of scope

- Do NOT introduce the new `flutter_launcher_icons_flavors.yaml` schema. Phase 3.
- Do NOT introduce `CommandRunner` or new CLI flags. Phase 4.
- Do NOT touch `README.md` or `CHANGELOG.md` (Phase 5 owns docs/release).
- Do NOT bump dependency majors (`image`, `args`, etc.). Patch bumps OK if needed for Dart 3.10 compatibility; otherwise leave alone.
- Do NOT change Dart SDK floor.

---

## 3. File-by-file change list

| File | Action |
|---|---|
| `pubspec.yaml` | Add `topics:` and `screenshots:`. (Version stays at `0.15.0-dev.1`.) |
| `lib/constants.dart` | Bump `androidDefaultAndroidMinSDK` to 24 (with comment). Replace `androidGradleFile` constant with `findAndroidGradleFile(prefixPath)` function. Same for `androidFlutterGardlePath`. |
| `lib/android.dart` | Use `findAndroidGradleFile`. New regex set for Groovy + KTS `min_sdk` extraction. Async I/O for image writes. Updated error message on parse failure. |
| `lib/ios.dart` | Async I/O for image writes. |
| `lib/web/**` | Async I/O. |
| `lib/windows/**` | Async I/O. |
| `lib/macos/**` | Async I/O. |
| `lib/utils.dart` | Update misleading comments. Confirm `decodeImageFile` async. |
| `doc/screenshots/adaptive.png` (NEW) | Placeholder image, OR comment out `screenshots:` with TODO. |
| `test/fixtures/gradle/` (NEW) | Fixture projects, see §4. |
| `test/android_gradle_test.dart` (NEW) | Tests for KTS / Groovy / fallbacks / failures. |
| `test/android_min_sdk_default_test.dart` (NEW) | Tests for 24 default + explicit override. |

---

## 4. Tests to add (Phase 2)

### 4.1 Gradle fixtures under `test/fixtures/gradle/`

Each fixture is a minimal directory tree containing only the files needed to test detection:

- `groovy_basic/android/app/build.gradle` with `minSdkVersion 21`.
- `groovy_with_eq/android/app/build.gradle` with `minSdk = 23`.
- `kts_basic/android/app/build.gradle.kts` with `minSdk = 24`.
- `kts_call_form/android/app/build.gradle.kts` with `minSdk(26)`.
- `kts_with_flutter_ref/android/app/build.gradle.kts` with `minSdk = flutter.minSdkVersion` plus a `flutter_sdk/packages/flutter_tools/gradle/flutter.gradle.kts` containing a numeric `minSdk = 21`. (Also include a `local.properties` fallback variant.)
- `kts_with_version_catalog/android/app/build.gradle.kts` referencing `libs.versions.minSdk.get().toInt()` — expected: graceful failure with actionable error.
- `convention_plugin/android/app/build.gradle.kts` that delegates to a convention plugin — expected: graceful failure.

### 4.2 `test/android_gradle_test.dart`

Parameterized over the fixtures above:
- `groovy_basic` → 21
- `groovy_with_eq` → 23
- `kts_basic` → 24
- `kts_call_form` → 26
- `kts_with_flutter_ref` → 21 (resolved via flutter.gradle.kts)
- `kts_with_version_catalog` → throws/returns-null with clear message; logged warning matches expected substring.
- `convention_plugin` → same graceful failure path.
- Missing both files → returns `null`, error message matches expected substring.
- Both `.kts` and `.gradle` present → `.kts` wins.

### 4.3 `test/android_min_sdk_default_test.dart`

- Empty config → `Config.minSdkAndroid == 24` (the new default).
- `min_sdk_android: 21` → resolved to 21.
- `min_sdk_android: 24` → resolved to 24.
- Explicit override is honored regardless of gradle autodetection.

### 4.4 Async I/O smoke

- Existing example `example/default_example/` continues to generate icons end-to-end. Run via `dart run flutter_launcher_icons_flavors` and verify output PNGs exist and are decodable.
- (Performance is not asserted — just correctness.)

---

## 5. Definition of Done — self-check

- [ ] `dart pub get` / `dart run build_runner build` clean.
- [ ] `dart format --set-exit-if-changed .` clean.
- [ ] `dart analyze --fatal-infos` clean.
- [ ] `dart test` — all tests pass, including new gradle fixtures and min_sdk default tests.
- [ ] `androidDefaultAndroidMinSDK` is `24` in `lib/constants.dart`.
- [ ] `findAndroidGradleFile(prefixPath)` exists and is exclusively used by callers (no remaining hard-coded `android/app/build.gradle` strings outside that function).
- [ ] `pubspec.yaml` contains `topics:` (5 entries). Either contains `screenshots:` (with the asset checked in) OR contains a `# TODO(release): screenshots` placeholder comment.
- [ ] `pubspec.yaml` does NOT contain `funding:`.
- [ ] No `writeAsBytesSync(` or `readAsBytesSync(` remains in any generator file under `lib/android.dart`, `lib/ios.dart`, `lib/web/`, `lib/windows/`, `lib/macos/`. (`lib/utils.dart` may keep `existsSync` per the rationale comment.)
- [ ] `example/default_example` end-to-end generation works.
- [ ] CHANGELOG.md / README.md untouched.

If anything fails, stop and report. Phase 3 should not start until this is green.
