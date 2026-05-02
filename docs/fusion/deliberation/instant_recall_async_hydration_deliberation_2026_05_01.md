# InstantRecall Async Hydration Deliberation - 2026-05-01

## Scope

Make vault-wide InstantRecall hydration async-only and ensure async recall searches trigger the same lazy initial snapshot hydration as the synchronous search path.

## Authority And Evidence

- `AGENTS.md` requires performance to be architectural: avoid expensive work on hot paths and move vault-wide work off the MainActor.
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` already has `rebuildIndexAsync(notes:)`, detached snapshot rebuilding, and `hydrateInitialSnapshotIfNeeded()`.
- `Epistemos/State/ContextualShadowsState.swift` calls `instantRecall.searchAsync(...)`, so async search must participate in initial hydration.
- `rg -n "rebuildIndex\\(|indexBatch\\(" Epistemos EpistemosTests --glob '*.swift'` found no production callers of `InstantRecallService.rebuildIndex(notes:)` or `indexBatch(notes:)`; the only remaining `rebuildIndex()` result is the unrelated `VaultSyncService.rebuildIndex()`.
- `EpistemosTests/RuntimeValidationTests.swift` already guards against reintroducing `instantRecallService.rebuildIndex(notes: notes)` in vault sync.

## Decision

- Retain the synchronous `indexBatch(notes:)` and `rebuildIndex(notes:)` symbols only as unavailable compile-time diagnostics.
- Preserve `indexNote(noteId:text:)` for per-note updates.
- Call `hydrateInitialSnapshotIfNeeded()` from `searchAsync(query:topK:)` before the detached search so first async recall use seeds the vault snapshot without blocking the MainActor.
- Replace the sync rebuild test with async rebuild coverage and add an async search hydration regression test.

## Allowed Files

- `Epistemos/KnowledgeFusion/InstantRecallService.swift`
- `EpistemosTests/InstantRecallTests.swift`
- `docs/fusion/deliberation/instant_recall_async_hydration_deliberation_2026_05_01.md`

## Protected Files

No protected editor, graph renderer, graph physics, generated library, or build artifact paths are required.

## Verification

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/InstantRecallServiceTests test | tee /tmp/epistemos-instant-recall-async-hydration-20260501-type.log
```

Result:

- Swift Testing: 18 tests in 1 suite passed.
- Suite: `InstantRecall - Service`.
- New case passed: `Async search triggers lazy initial snapshot hydration`.
- Xcode result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-49-35--0500.xcresult`.
- Xcode printed the inherited SwiftLint plugin failures for `CodeEditSourceEditor` and `CodeEditTextView` after the successful test run; this is existing package-plugin debt, not caused by this slice.

## Rollback

Revert the InstantRecall service/test/doc commit. The async rebuild path remains the canonical implementation if a later caller needs to be rewired.

## Stop Triggers

- A production caller needs sync vault-wide InstantRecall rebuild.
- Async search blocks on snapshot rebuild before returning.
- Contextual Shadows loses first-use recall hydration.
- Focused InstantRecall tests fail.
