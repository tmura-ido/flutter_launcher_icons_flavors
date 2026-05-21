# Handoff — issue triage & approval session

> **Implementation complete on 2026-05-21.** All ~55 approved issues have been implemented (or closed as no-ops). The `issues/approved/` folder is empty.
>
> **Implementation summary (this session):**
> - **Docs only (6):** #667 link audit, #513 dart-run audit, #144 adaptive sizing, #146 resource-name clarification, #416 source-image table, #116 file layout.
> - **No-ops verified (11):** #091 (config-time XML reject + test), #177, #306, #326, #328 (README cleanup section), #466, #532 (README troubleshooting), #615 (test un-skipped), #616, #617, #658.
> - **Small fixes (5):** #665+#132+#175 (hex regex detector + foreground reject), #423 (web packages/ path — already correct), #573 (multi-image ICO), #476 (skip unconfigured-platform headers).
> - **Medium features (15):** #312+#490+#279 (recursive discovery + `flavor:` key + friendly error), #378 (`FLIException` base), #552 (`NoopLogger`), #426 (web `output_path` + per-flavor convention), #137/#214/#172 (helpers for non-square + alpha detection), #432 (iOS alpha-fill precedence chain), #139 (`optimize_png`), #161 (iOS missing appiconset friendly error), #537 (README + notification docs), #543+#637 (`xcodeproj_path` + auto-detect), #661 (`ios_legacy_sizes`), #528, #592 (`ios.single_size`), #657 (`ios.disable_liquid_glass` stub).
> - **Larger features (15):** #655 (`macos.padding`), #660 (macOS dark/tinted), #666 (Linux PNG support + `LinuxConfig`), #540 (favicon.ico + `favicon_path`), #516 (regression test only — no bug in fork), #626 (already shipping), #638 (flavor-aware macOS paths + Contents.json self-check), #092 phase 1 (alternate-icons schema), #612 (pbxproj prefix-anchored matcher + exact key match — also closes #634), #510 phase 1 (tray-icon schema), #622 phase 1 (badge schema), #560 (already covered by test 514), #020 (clear SVG error — full rasterization deferred), #130 (already has `example/flavors/` + `example/flavors_consolidated/`).
>
> **Test count:** 376 passing, 1 skipped (`#587` tinted-only single catalog — long-standing skip).
>
> **Deliberately deferred (require external deps or major work, beyond this session's scope):**
> - #020 SVG rasterization — needs `jovial_svg` (or equivalent) dependency + per-size cache. Today: clear error at decode.
> - #092 phase 2 — iOS `Info.plist` `CFBundleAlternateIcons` patching (gated on #612's structural editor in a future session).
> - #130 CI smoke-test job for the example projects.
> - #510 phase 2 — Windows/macOS/Linux tray-icon writers (schema lands now, emission is per-platform code).
> - #612 full structural pbxproj parser + atomic write + per-file mutex — current session shipped the prefix-anchored matcher + exact key match, which closes the documented race for the reported cases but is not a full rewrite.
> - #622 phase 2 — badge renderer + bundled TTF font asset.
> - #657 — emit Apple's Liquid Glass opt-out metadata key once it's identified.
> - #543/#637 — pbxproj rewriter still treats `xcodeproj_path` and the iOS auto-detection as a single-file edit (acceptable for the current scope; the structural-edit follow-up would consolidate).
>
> See git log + new `test/issues/issue_*` files for traceability.
>
> **Suggested implementation order — tackle these clusters together:**
> - **iOS structural editor cluster** (single pbxproj rewrite unblocks the rest): #612 (pbxproj structural rewrite + atomic write + per-file mutex) → #637 (`xcodeproj_path` field) + #543 (auto-detect `ios/*.xcodeproj` glob) → #092 phase 2 + #643 (Info.plist `CFBundleAlternateIcons` patching) → #161 (writer pre-check for missing `AppIcon.appiconset`) → #560 (compositor honors `background_color_ios`) → #432 (alpha-fill precedence chain) → #172 (doctor + --strict alpha detection).
> - **Foundational refactors (land first; many other approvals depend on these)**: #378 (`FLIException` base) → #552 (route all `print`/`printStatus` through logger + export `NoopLogger`).
> - **Android adaptive bg classification**: #665 (hex regex detector) closes #132 + #148 + #616 + #617.
> - **Flavor discovery / non-root configs**: #312 + #490 → #279 (no-config friendly error scans flavor siblings).
> - **macOS first-class**: #638 (per-flavor asset set + pbxproj rewrite) → #655 (`macos.padding`) → #660 (dark/tinted variants, mirrors iOS pattern) → closes #532 + #564 via Contents.json self-check + README cache note.
> - **Web favicon**: #540 (favicon.ico + `web.favicon_path`) bundles #152 + #515 + #635; ships alongside #423 (web `packages/` path fix).
> - **Linux scaffolding**: #666 (minimal PNG generator) unblocks #186 + #604 + #629 + the Linux side of #510 (tray icons).
> - **SVG + badge (fork's marquee multi-flavor features)**: #020 (SVG with per-size rasterization + hash cache) → #622 (`badge:` block) share the source-loader / cache helper.
> - **Image quality**: #139 (+ #199 duplicate) `optimize_png` opt-in; #214 (non-square doctor + --strict); #573 (verify/strengthen multi-image ICO test).
> - **Android writer bug**: #516 (+ #520 duplicate) stride/dimension audit in mipmap writer.
> - **Examples + docs**: #130 (`example/flavors/` + `example/legacy_flavors/`) — large scaffolding task; ships independently and smoke-tests everything above.
>
> Many issues approved as **no-ops** (clear close + reasoning in their annotation): #341, #463, #532, #564, #602, #615, #91, #249, #306, #326, #177, #531, #219, #291, #150, #160, #176, #233, #317, #328, #373, #394, #511, #556, #510 (tray was upgraded to a full cross-platform approval), and the `dynamic icon switching` family. Read the relevant approved `.md` before deciding to skip — most cite an existing test or an already-approved alternative.

Pick up from here in a fresh session. This document is the source of truth; do not assume earlier-session memory.

## Project

`flutter_launcher_icons_flavors` (a heavily-modified fork of `fluttercommunity/flutter_launcher_icons`). Root: `C:\Users\User\GitHub\flutter_launcher_icons_flavors`. Read `README.md` and `CHANGELOG.md` for what the fork already supports vs. upstream.

## What's already been done

1. **478 upstream issues triaged** → 115 written to `issues/*.md` with `upstream`, `title`, `state`, `labels`, `category`, `priority` frontmatter and a "Suggested action" body.
2. **42 regression tests written** in `test/issues/issue_<NNN>_<slug>_test.dart`, wired into `test/all_tests.dart`. 60 pass, 18 are `skip:`-marked (documenting unfixed bugs that should pass once a fix lands).
3. **27 issue files deleted** because their tests asserted the fork's correct behavior and passed (bug doesn't apply to fork).
4. **28 issues approved** with concrete fix decisions appended to each `.md`. They live in `issues/approved/`. **A future AI will read this folder and implement the fixes.**

## Folders right now

- `issues/approved/` — 28 files. Each has an `## Approved fix:` (or `## Approved action:`) section appended. Action items, scope, and test references inside. **DO NOT modify these.**
- `issues/` (root) — 60 files left to triage with the user.
- `issues/important/` — empty.
- `issues/easy/` — empty.

## Your job in this session

Go through the remaining 60 root issues with the user, **one issue per `AskUserQuestion`** (up to 4 questions per phase, ~15 phases total). For each issue:

1. **Read the `.md` file** (also Grep `lib/` to confirm the code path still exists; many old issues are already obsolete).
2. **Ask one question** with the structure:
   - Question text: a 1–3 sentence explanation of what happened + where in code.
   - Options (2–4): each option is a candidate fix or `No-op`. Mark the recommended one as `(Recommended)`.
3. **On the user's answer**: append a `## Approved fix: <chosen option>` section to the issue `.md` (use `Edit` tool). Include implementation notes, file paths, test references.
4. **Move the file** to `issues/approved/` with `mv`.

### Phase cadence

User asked for "small phases" — 3–4 questions per phase, then wait for answers. Don't dump all 60 at once. Group by theme where it makes sense (multi-select for related docs items is fine; the user accepted that pattern in Phase 4).

### When to bundle vs separate

- **Same root cause across multiple issues** → bundle them under one approval (e.g. #612 + #634 + #636 all became "structural pbxproj rewrite"; #665 + #616 + #617 became "hex regex detector"). Mention the duplicates in the bundled approval.
- **Related but distinct fields/keys** → ask separately, but offer "bundle into #XXX" as an option (e.g. #175 reuses #665's hex detector but for a different key).
- **Already-fixed in fork** → recommend `No-op` and verify with Grep/test. Cite the existing test that covers it.
- **Defer when downstream** → if the issue's fix depends on an already-approved one, offer "Defer until #YYY lands". This is what #466 became (deferred behind #490 + #312).

### Critical: already-approved fixes that affect future answers

When asking about a new issue, check whether one of these already-approved fixes covers it. If so, recommend "bundle into #XXX" or "defer until #XXX lands":

- **#665 (hex regex helper)** — adds `_isHexColorLiteral` detector for adaptive_icon_background classification. Reusable for any other field that takes color-or-path.
- **#612 (pbxproj structural rewrite + atomic write)** — replaces line-scan iOS pbxproj editor. Any issue that touches `project.pbxproj` should bundle into this or wait for it.
- **#637 (xcodeproj_path Config field)** — replaces hardcoded `ios/Runner.xcodeproj/project.pbxproj`. Pairs with #612.
- **#626 (Android per-flavor `src/<flavor>/res/`)** — when flavor is active, all Android output is routed to flavor-scoped dirs. Resolves #658 (race) automatically. Pattern likely applies to any "flavor X overwrites flavor Y" complaint.
- **#638 (macOS flavor-aware: per-flavor asset set + pbxproj rewrite)** — same pattern as iOS. macOS issues that depend on flavor handling should reference this.
- **#312 (honor directory prefix in `-f` glob; covers all 3 file variants)** — discovery in subfolders. #257 was folded in.
- **#490 (explicit `flavor:` key, filename + key, key wins)** — explicit flavor identification. Pairs with #312.
- **#092 (iOS alternate icons, phase 1)** — asset-set generation only; Info.plist patching is phase 2 (bundled with #612's structural editing).
- **#426 (web output_path: convention + explicit override)** — `web_<flavor>/` auto when flavor active, `web.output_path` overrides.
- **#661 (`ios_legacy_sizes: true` opt-in flag)** — user chose the config-flag approach over forcing the union.

## Issue-file annotation format

```markdown
[existing frontmatter and body left intact]

---

## Approved fix: <one-line title matching the chosen option>

[implementation outline: numbered steps]
[file paths to touch]
[notes on bundling / dependencies on other approved fixes]
[test reference: `test/issues/issue_<NNN>_<slug>_test.dart` + whether it's currently passing or `skip:`-marked]
```

For no-ops:

```markdown
## Approved action: No-op — <reason>

[verification: cite the existing test or code that proves the fork is correct]
[explicit "No code change required. Close."]
```

## Test conventions

- New tests go in `test/issues/issue_<NNN>_<short_snake_slug>_test.dart` (snake_case, not kebab — Dart filenames).
- Imports go into `test/all_tests.dart` so the aggregate runner picks them up.
- Style: `package:test/test.dart`, optionally `package:test_descriptor/test_descriptor.dart` for sandboxed file fixtures, simple `group/test/expect`.
- For currently-failing regressions, use `skip: 'bug — see issue #XXX, will fail until fix lands'` so the suite stays green.
- DO NOT modify `lib/` or pre-existing tests in this session — that's the next AI's job.
- Sanity check after writing: `dart analyze test/issues/` should report `No issues found!`.

## Remaining 60 root issues to triage

```
issue-020-svg-source-support.md
issue-091-android-vector-drawable-foreground.md
issue-130-example-flavors-project.md
issue-132-adaptive-bg-invalid-color.md
issue-139-run-optipng-on-output.md
issue-148-adaptive-bg-as-image-path.md
issue-150-build-runner-integration.md
issue-152-favicon-for-web.md
issue-160-ios-quick-actions-icons.md
issue-161-ios-missing-target-file.md
issue-172-ios-icons-transparent-alpha.md
issue-176-generate-custom-sizes.md
issue-177-dynamic-icon-switching.md
issue-186-linux-desktop-support.md
issue-199-optimize-generated-images.md
issue-214-non-square-images-squished.md
issue-219-android-notification-icon.md
issue-233-apple-watch-icons.md
issue-249-android-icon-no-inset-padding.md
issue-279-flavors-not-detected.md
issue-291-android-notification-icon.md
issue-306-android-12-background-color-inconsistent.md
issue-317-run-as-builder.md
issue-326-android-round-icons-square-inside.md
issue-328-delete-old-generated-icons.md
issue-341-ios-icon-not-changing.md
issue-373-new-config-schema.md
issue-378-better-error-handling-fli-exception.md
issue-394-refactor-android-ios-new-schema.md
issue-423-web-package-path.md
issue-432-remove-alpha-ios-use-bg-color.md
issue-463-macos-rounded-icons.md
issue-510-tray-icons.md
issue-511-url-image-sources.md
issue-515-separate-favicon-source.md
issue-516-rangeerror-index-9216.md
issue-520-rangeerror-index-out-of-range.md
issue-528-unnecessary-ios-icons.md
issue-531-dynamic-icon-switching.md
issue-532-macos-icon-not-changing.md
issue-537-android-push-notification-icon.md
issue-540-favicon-ico.md
issue-543-rename-runner-project.md
issue-552-printstatus-bypasses-logger.md
issue-556-icon-blur.md
issue-560-background-color-ios-black.md
issue-564-macos-icon-not-refreshing.md
issue-573-windows-ico-low-quality.md
issue-592-single-size-ios-icons.md
issue-602-ios-dark-icon-not-shown-after-flutter-install.md
issue-604-linux-desktop-support.md
issue-615-rangeerror-on-indexed-color-png.md
issue-622-environment-badge-on-app-icon.md
issue-629-linux-platform-support.md
issue-635-separate-favicon-from-pwa-icon.md
issue-643-multiple-ios-icons-for-app-store.md
issue-655-macos-padding-effective-design-area.md
issue-657-ios-26-liquid-glass-opt-out.md
issue-660-macos-tahoe-themed-background.md
issue-666-basic-linux-png-support.md
```

### Theme clusters likely to bundle

- **Linux platform support**: #186, #604, #629, #666 — same feature, four asks. Likely one approved decision covers all.
- **Adaptive bg duplicates of #665**: #132, #148 — already covered by approved #665 hex helper. Probably no-ops.
- **Dynamic icon switching**: #177, #531 — same feature.
- **Android notification icon**: #219, #291, #537 — fork already has `copy_mipmap_xxxhdpi_to_drawable`. Likely docs.
- **macOS Apple HIG / themed background**: #463, #655, #660 — modern macOS design rules.
- **Favicon variants**: #515, #540, #635 — separate favicon source / favicon.ico / favicon vs PWA.
- **iOS dark/tinted edge cases**: #592, #602 — relate to existing fork support.
- **RangeError clusters**: #516, #520, #615 — image-decode failures with unusual PNG formats.
- **Refactor proposals**: #373, #378, #394 — schema/architecture changes; user may prefer No-op + roadmap note.
- **iOS Liquid Glass / iOS 26**: #657 — new platform asks.
- **Pure feature requests with no clear contract**: #020 (SVG), #091 (vector drawable), #150 (build_runner), #176 (custom sizes), #199/#139 (optipng), #160 (quick actions), #233 (Apple Watch), #317 (builder), #510 (tray), #511 (URL), #622 (badge), #643 (App Store multi-icon). User may consistently no-op these or defer.

## Rules

- **Don't fix code.** Approved decisions are just plans. The next-next AI implements them by reading `issues/approved/`.
- **Don't modify approved files.** They're frozen.
- **Always include test references** in approved annotations — say which test file the fix unblocks and whether it's currently `skip:`-marked.
- **Convert relative dates to absolute** in any session-memory writes (current date is 2026-05-21).
- **Use `Edit` for appending** approved sections; use `Write` only for the rare lost-file recovery (see notes below).

## Known traps

- **`Edit` can fail silently** if the `old_string` doesn't match exactly. Three no-op files (151, 404, 571) were lost mid-session and one (#257) was moved without its approval annotation. Both fixed by recreating with `Write`. After every Edit + `mv` pair, **verify `ls approved/ | wc -l` matches expectation** before moving on.
- **PowerShell quirks** — the bash tool works fine for `mv`, `ls`, `find`. PowerShell is also available but watch for the differences noted in the system prompt.
- **`rtk find`** doesn't support compound predicates. Use `Glob` instead for finding files across the project.

## Final deliverable (end of triage)

When all 60 are triaged + approved, leave a short note at the top of `issues/HANDOFF.md` (this file) saying:

> Triage complete on YYYY-MM-DD. `issues/approved/` contains N decisions. Next AI: implement from `issues/approved/`, one issue per branch/PR; un-skip the corresponding `test/issues/issue_<NNN>_*_test.dart` when the fix lands. Reference clusters of related approved fixes (e.g. #612 + #637 + #092-phase-2 all touch the iOS structural editor) for implementation order.

Then end goal: `issues/` (root), `important/`, and `easy/` should all be empty.

group remaining issues by theme.
