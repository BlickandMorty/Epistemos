# Codex / Kimi Oversight Round 020 - 2026-05-01

## Slice

R12a FSRS GRDB Persistence.

## Scope

- `Epistemos/Engine/FSRSDecayState.swift`
- `EpistemosTests/FSRSDecayStateTests.swift`
- `docs/fusion/deliberation/r12a_fsrs_grdb_persistence_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Decision

Approved for the first R12 storage slice only: persist the existing Swift FSRS decay contract to GRDB, without introducing the Rust `fsrs` crate, UniFFI, app bootstrap wiring, or UI work.

## Kimi Work

- Kimi did not edit code in this round.
- Codex kept this slice local because the change is a schema/persistence boundary and needed tight compile-test feedback.
- Kimi remains available for a future R12b research/build pass once the Rust `fsrs` bridge scope is separately gated.

## Codex Implementation

- Added `FSRSDecayDatabase` with an idempotent `fsrs_state` migration and retrievability index.
- Added a private GRDB row adapter that maps the public `FSRSDecayRow` contract to database columns.
- Added explicit `configurePersistence(_:)` support to `FSRSDecayStore`, preserving the existing actor API.
- Persisted `ensure`, `upsert`, `recordReview`, `bulkUpsert`, and `reset` when a writer is configured.
- Added focused tests for migration idempotency, row reload through a second store, review persistence, and reset deletion.

## Test Results

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test`
- Log: `/tmp/epistemos-r12a-fsrs-grdb-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_00-49-58--0500.xcresult`
- Exit code: `0`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: 10 tests passed in 1 suite.

## Guardrails

- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` Rust edits were made by this slice.
- No `project.yml`, `.xcodeproj`, entitlements, generated artifacts, branch, stash, staging, or commit edits were made by this slice.
- `git diff --check` on touched tracked R12a files is clean.
- Source anti-pattern audit found no `try!`, force unwrap marker, `DispatchQueue.main.asyncAfter`, `repeatForever`, `loadBody()`, direct per-keystroke text assignment, or new `needsVaultSync = true` use in touched source.

## Risks

- App bootstrap does not yet configure `FSRSDecayStore` with a production database writer; this slice only proves the durable store contract.
- The Rust `fsrs = "5.2.0"` algorithm bridge remains R12b scope.
- Manual runtime verification was intentionally deferred because no UI/bootstrap surface was wired in this slice.
- Xcode still prints SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; the focused test exited `0`, and this remains existing package-plugin noise.
