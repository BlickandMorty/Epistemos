# R12a FSRS GRDB Persistence Deliberation - 2026-05-01

## Gate

Approved for the first R12 slice: persist the existing Swift `FSRSDecayStore` contract to GRDB without changing UI behavior or introducing the Rust `fsrs` algorithm yet.

## Classification

Core/MAS-safe.

## Scope

- Add an idempotent GRDB schema for `fsrs_state`.
- Keep `FSRSDecayStore` as the app-facing actor and preserve its current async API.
- Add optional database-writer injection so tests and future app bootstrap can attach a `DatabaseQueue` or `DatabasePool`.
- Persist `ensure`, `upsert`, `recordReview`, `bulkUpsert`, and `reset` mutations when a writer is configured.
- Load existing rows when persistence is configured.
- Add focused tests proving migration, row round-trip, review persistence, reset deletion, and existing in-memory semantics.

## Allowed Write Scope

- `Epistemos/Engine/FSRSDecayState.swift`
- `EpistemosTests/FSRSDecayStateTests.swift`
- `docs/fusion/deliberation/r12a_fsrs_grdb_persistence_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_020_2026_05_01.md`

## Explicit Non-Scope

- No Rust `fsrs` crate dependency or UniFFI changes in this slice.
- No `epistemos-core/**`, `agent_core/**`, `graph-engine/**`, generated bindings, `.xcodeproj`, `project.yml`, entitlements, branch, stash, staging, or commit edits.
- No FSRS sidebar UI changes.
- No manual runtime verification in this slice.

## Evidence Before Edit

- `Epistemos/Engine/FSRSDecayState.swift` already defines `FSRSDecayRow`, `FSRSRetrievability`, and actor-isolated `FSRSDecayStore`.
- The header still says Rust persistence is deferred and the actor currently stores rows only in memory.
- Existing tests cover pure retrievability math, actor idempotency, review counters, and top-at-risk ordering.

## Decision

Land persistence as R12a so the app gets durable FSRS state without coupling the schema migration to the heavier Rust algorithm/UniFFI dependency. R12b will wire `fsrs = "5.2.0"` and the Rust state-machine bridge after this storage contract is green.

## Test Plan

- Add failing focused tests for:
  - idempotent GRDB migration;
  - persisted row round-trip through a second store instance;
  - `recordReview` persistence;
  - `reset` deleting database rows.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test`

## Stop Triggers

- Any need to change app bootstrap wiring.
- Any need to regenerate UniFFI bindings.
- Any need to touch protected graph/editor/Rust renderer paths or generated artifacts.

## Result

Implemented and verified.

Changes landed:

- `FSRSDecayDatabase` now owns the idempotent `fsrs_state` GRDB migration and retrievability index.
- `FSRSDecayStore.configurePersistence(_:)` migrates a supplied database writer and reloads persisted rows into the actor.
- Store mutations now persist when configured: `ensure`, `upsert`, `recordReview`, `bulkUpsert`, and `reset`.
- Focused tests cover migration idempotency, persisted row reload, review persistence, reset deletion, and the existing in-memory semantics.

Verification:

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test`
- Log: `/tmp/epistemos-r12a-fsrs-grdb-green-20260501.log`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_00-49-58--0500.xcresult`
- Exit code: `0`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: 10 tests passed in 1 suite.

Post-slice audits:

- Tracked-source diff check log: `/tmp/epistemos-r12a-diff-check-20260501.log`
- Touched-file trailing whitespace audit log: `/tmp/epistemos-r12a-trailing-whitespace-audit-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r12a-source-anti-pattern-audit-20260501.log`
- Source line audit log: `/tmp/epistemos-r12a-source-audit-20260501.log`
- Protected diff audit log: `/tmp/epistemos-r12a-protected-diff-audit-20260501.log`
