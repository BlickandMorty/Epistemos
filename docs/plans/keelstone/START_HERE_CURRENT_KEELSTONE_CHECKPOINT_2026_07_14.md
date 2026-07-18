# Start Here — Current Keelstone Checkpoint — 2026-07-14

This is the small human/agent resume file. Do not use the giant Keelstone
evidence log as a normal Epdoc editing surface.

## Why this exists

`KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md` is an append-only release
evidence log, not a regular note. It is currently about 58k words / 473 KB
because it preserves resource preflights, failed and passing test runs, exact
artifact paths, SHA-256 log hashes, owner steers, release constraints, and safe
resumption boundaries across crashes and restarts.

Epdoc must eventually handle very large Markdown safely, but the evidence log
should be treated as archival audit material. Open this checkpoint first.

## Current execution key

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

## Current branch / HEAD

- Branch: `feat/goose-surface`
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`

## Current narrow work in flight

Owner steer: the deprecated `InferenceState` identity should be gone unless
proved required by helper/foundation/embedding paths.

Current implementation state:

- `Epistemos/State/InferenceState.swift` has been replaced in the working tree
  by `Epistemos/State/ProductRuntimeState.swift`.
- `Epistemos/State/InferenceState+RouteProfiles.swift` has been replaced by
  `Epistemos/State/ProductRuntimeState+RouteProfiles.swift`.
- `Epistemos.xcodeproj/project.pbxproj` now points at
  `State/ProductRuntimeState+RouteProfiles.swift`.
- `project.yml` was corrected after R48 exposed a stale exclude entry.

## Latest focused test result

R48 command:

```bash
EPISTEMOS_PRODUCT_EDITION=FREE_V1 xcodebuild test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -derivedDataPath /tmp/Epistemos-FreeV1-Regressions-R48 \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: failed by exactly one stale source/config guard:

- `AppStoreKeelstoneLaneTests.freeV1ExcludesProviderBrandingAndLeafRuntimeSources()`
- Expected `State/ProductRuntimeState+RouteProfiles.swift`.
- `project.yml` still contained `State/InferenceState+RouteProfiles.swift`.

That stale `project.yml` entry was patched.

R49 result:

- Command: same focused Free V1 App Store Keelstone regression batch as R48,
  with derived data at `/tmp/Epistemos-FreeV1-Regressions-R49`.
- Result: `** TEST SUCCEEDED **`.
- Summary: 186 tests passed, 0 failed, 0 skipped, 4 suites.
- xcresult:
  `/tmp/Epistemos-FreeV1-Regressions-R49/Logs/Test/Test-Epistemos-AppStore-2026.07.14_21-21-26--0500.xcresult`
- Log SHA-256:
  `6f54c991afc07de238441d2bf1927ab418943a180f0c18fb635d17eb7f0fb6f6`

R50 result:

- Command: same focused Free V1 App Store Keelstone regression batch as R49,
  with derived data at `/tmp/Epistemos-FreeV1-Regressions-R50`.
- Result: failed during compile after the first large-Epdoc hot-path patch.
- Failure: `EpdocEditorPerformancePolicy.smallDocumentStatusJSONByteLimit`
  was referenced from a nonisolated context while the type was still
  main-actor-isolated by default.
- Correction: `EpdocEditorPerformancePolicy` was made `nonisolated`.

R51 result:

- Command: same focused Free V1 App Store Keelstone regression batch as R49,
  with derived data at `/tmp/Epistemos-FreeV1-Regressions-R51`.
- Result: `** TEST SUCCEEDED **`.
- Summary: 186 tests passed, 0 failed, 0 skipped, 4 suites.
- xcresult:
  `/tmp/Epistemos-FreeV1-Regressions-R51/Logs/Test/Test-Epistemos-AppStore-2026.07.14_21-51-29--0500.xcresult`

R52 result:

- Intended command: standalone `EpistemosTests/EpdocEditorBridgeTests` and
  `EpistemosTests/EpdocVisibilitySourceGuardTests`.
- Result: no tests executed.
- Reason: the current Xcode project exposes `Epistemos-AppStore`,
  `EpistemosAppStoreKeelstoneTests`, widgets, and MarkEdit schemes/targets;
  `EpistemosTests` is not a member of the available project test scheme in this
  checkout state.
- Follow-up: the runnable Keelstone App Store source guard was expanded with
  the new large-doc deferred-full-snapshot contract.

R53 result:

- Command: same focused Free V1 App Store Keelstone regression batch as R49,
  with derived data at `/tmp/Epistemos-FreeV1-Regressions-R53`.
- Preflight before Xcode: branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, dirty count 349, swap used
  about 2.8 GiB, free memory 56%, pages throttled 0, about 459 GiB available
  on `/` and `/tmp`, no competing Xcode/compiler/Epistemos/model process.
- Result: `** TEST SUCCEEDED **`.
- Summary: 186 tests passed, 0 failed, 0 skipped, 4 suites.
- xcresult:
  `/tmp/Epistemos-FreeV1-Regressions-R53/Logs/Test/Test-Epistemos-AppStore-2026.07.14_22-00-39--0500.xcresult`
- Rebuilt Tiptap editor bundle digest:
  `Epistemos/Resources/Editor/editor.js.br`
  SHA-256 `ab440069ed15bef6c4ad991145cda25d053b624f208158bf00308da8fd83c2b0`.

R54 result:

- Command: same focused Free V1 App Store Keelstone regression batch as R49,
  with derived data at `/tmp/Epistemos-FreeV1-Regressions-R54`.
- Preflight before Xcode: branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, dirty count 349, swap used
  about 2.9 GiB, free memory 61%, pages throttled 0, about 458 GiB available
  on `/` and `/tmp`, no competing Xcode/compiler/Epistemos/model process.
- Result: `** TEST SUCCEEDED **`.
- Summary: 186 tests passed, 0 failed, 0 skipped, 4 suites.
- xcresult:
  `/tmp/Epistemos-FreeV1-Regressions-R54/Logs/Test/Test-Epistemos-AppStore-2026.07.14_22-31-03--0500.xcresult`
- Rebuilt Tiptap editor bundle digest:
  `Epistemos/Resources/Editor/editor.js.br`
  SHA-256 `4b4a96498b312f28e35da51e6a3d4f00a254990eb391de6c1520b708c829f014`.

R55 result:

- Command: same focused Free V1 App Store Keelstone regression batch as R49,
  with derived data at `/tmp/Epistemos-FreeV1-Regressions-R55`.
- Preflight before Xcode: branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, dirty count 349, swap used
  about 3.2 GiB, free memory 62%, pages throttled 0, about 456 GiB available
  on `/` and `/tmp`, no competing Xcode/compiler/Epistemos/model process.
- Result: `** TEST SUCCEEDED **`.
- Summary: 186 tests passed, 0 failed, 0 skipped, 4 suites.
- xcresult:
  `/tmp/Epistemos-FreeV1-Regressions-R55/Logs/Test/Test-Epistemos-AppStore-2026.07.14_22-39-49--0500.xcresult`
- Current rebuilt Tiptap editor bundle digest:
  `Epistemos/Resources/Editor/editor.js.br`
  SHA-256 `4b4a96498b312f28e35da51e6a3d4f00a254990eb391de6c1520b708c829f014`.
- This run includes the large-document source guards that keep ordinary Epdoc
  Markdown-projection typing off full JSON/status snapshots, defer full
  Markdown snapshots for large documents when writeback is unavailable, avoid
  duplicate `textBetween` scans unless Markdown serialization returns an empty
  body, and preserve the existing surface-switch regression guards.

R56 result:

- Command: same focused Free V1 App Store Keelstone regression batch as R49,
  with derived data at `/tmp/Epistemos-FreeV1-Regressions-R56`.
- Preflight before Xcode: branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, dirty count 349, swap used
  about 3.2 GiB, free memory 57%, pages throttled 0, about 454 GiB available
  on `/` and `/tmp`, no competing Xcode/compiler/Epistemos/model process.
- Result: `** TEST SUCCEEDED **`.
- Summary: 186 tests passed, 0 failed, 0 skipped, 4 suites.
- xcresult:
  `/tmp/Epistemos-FreeV1-Regressions-R56/Logs/Test/Test-Epistemos-AppStore-2026.07.14_22-49-18--0500.xcresult`
- Current rebuilt Tiptap editor bundle digest:
  `Epistemos/Resources/Editor/editor.js.br`
  SHA-256 `bb28e96db3e826b97edff9d858e7924311c71f3091b0385f217c4351944ebd44`.
- This run adds the missing snapshot-flush guard: when the editor is in
  Markdown-projection mode, `requestDocumentSnapshot` no longer emits a full
  `JSON.stringify(editor.getJSON())` mirror before the Markdown snapshot. JSON
  snapshots remain available for true JSON/Epdoc package mode.

## Immediate next action

The narrow Free V1 compile/source-guard proof remains green after the first
large-Epdoc hot-path patch, the lazy-snapshot/source-guard patch, and the
Markdown-projection snapshot-flush JSON-mirror removal. The next work item is
still the live/manual large-Epdoc performance/save/surface-switch blocker.

Do not archive, launch release runtime matrix, run models, request providers, or
touch secrets while the large-Epdoc blocker is unresolved.

## Newly explicit blocker from owner

The owner pasted/opened the giant Keelstone evidence Markdown in Epdoc and
observed serious behavior:

- large Markdown editing hangs/lags badly;
- save failed or appeared unavailable;
- switching away from Epdoc to other surfaces became impossible once content
  was present.

This is now a real Epdoc performance/data-integrity blocker. Large documents
like the Keelstone evidence log are legitimate stress-test targets and should
be used to prove Epdoc quality. The safety rule is not “avoid large docs”; it is
“test them deliberately with disposable copies or generated fixtures, never by
casually mutating the canonical evidence log itself.”

The target quality bar is: Epdoc can open, scroll, type, save, and switch
surfaces on a roughly 50k–70k-word Markdown document without hanging, trapping
the user on one surface, losing content, or corrupting formatting.

Current owner evidence is sufficient to classify this as a real optimization
and release-readiness blocker: super-large word counts already produced visible
lag/hang behavior and interaction failure. The implementation response must be
performance work, not a documentation warning. Optimize the Epdoc large-document
path, including projection, status calculation, save coalescing, surface-switch
admission, rendering, and any main-actor full-document work discovered during
source inspection.

## 2026-07-14 owner steer: remove live complexity work if it is only old chrome

Owner excerpt:

> rempove the complexity thing i dont think in eed that if its just hte
> cmplexiy meter thign thats deprecated or idk if its an lold name for a new
> mecahnism but please start getting these thngs fixed as u go please.

Interpretation:

- The live Epdoc editing surface should not run deprecated complexity-meter or
  inspector work during ordinary typing/opening/surface switching.
- The package/graph complexity calculator may remain only where it is still a
  durable metadata/query/graph mechanism, but it must not sit on the hot editor
  path.
- Large-document status should use lightweight `documentStatsChanged` counts
  and small-document initial fallback only; no full ProseMirror complexity
  breakdown should be scheduled from live `contentDidChange`.

Acceptance checks:

- `contentDidChange` does not schedule `EpdocComplexityCalculator.breakdown`.
- Initial status fallback is bounded for small JSON only.
- The duplicated text word count inside `EpdocComplexityCalculator` is removed.
- Focused App Store Keelstone regression and Epdoc bridge/source guards are
  rerun before claiming the blocker fixed.

Implemented source-level response so far:

- Markdown-projection mode no longer posts full ProseMirror JSON on ordinary
  typing.
- Ordinary Markdown typing prefers minimal writeback regions instead of full
  Markdown snapshots.
- For large Markdown-projection documents, if minimal writeback cannot be
  produced, the full Markdown snapshot is deferred to a slower idle cadence
  instead of running inside the typing debounce.
- Swift chrome now uses live JS `documentStatsChanged` for word/character
  counts and keeps the old full JSON walk bounded to small initial fallback
  only.
- Empty writeback-only messages no longer overwrite the host's latest known
  non-empty Markdown snapshot.
- If applying a writeback patch fails and the fallback body is empty while the
  cached body is non-empty, the save pipeline refuses to overwrite real
  content with emptiness.
- Explicit save/surface-switch flush still may request a full Markdown
  snapshot, but the direct snapshot provider now avoids the extra full
  `textBetween` scan unless the Markdown serializer returns an empty body.
- The JSON parse/mirror is not required for normal same-file surface switching
  when Epdoc is projecting Markdown. Surface switching should reconcile the
  canonical Markdown file through the current Markdown snapshot or minimal
  writeback, not by keeping a full ProseMirror JSON shadow in the hot path.
- `requestDocumentSnapshot` now suppresses full `editor.getJSON()` snapshots in
  Markdown-projection mode. JSON snapshots remain for true JSON/Epdoc package
  loads and small/status/debug cases where they are explicitly bounded.

Unproven verification debt:

- No manual/runtime large-document pass has been completed yet on a disposable
  copy of `KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`.
- The app has not yet been visually/runtime-proven to open, scroll, type, save,
  and switch among Epdoc/Source/Prose/Preview on a 50k–70k-word Markdown file
  without hanging or disappearing text.
- Do not claim the blocker fixed until that finite runtime matrix is green.

## MarkEdit status

MarkEdit visual parity has not been satisfied. The owner reports the app still
looks the same. Do not claim restricted-host MarkEdit Source/Preview fidelity
until there is side-by-side visual/manual evidence.
