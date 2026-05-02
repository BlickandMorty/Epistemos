# R12c FSRS Swift/Rust Scheduler Wiring Deliberation - 2026-05-01

## Gate

Approved for the third R12 slice: wire `FSRSDecayStore.recordReview` to the Rust `fsrs` scheduler bridge when UniFFI bindings are available.

## Classification

Core/MAS-safe.

## Scope

- Import the `epistemos_coreFFI` module conditionally in `FSRSDecayState.swift`.
- Convert Swift `FSRSDecayRow` values to the R12b UniFFI bridge row shape.
- On review, prefer Rust `fsrsScheduleReview(...)` output for D/S/R updates.
- Preserve the existing safe fallback behavior if the bridge is unavailable or rejects input.
- Add focused Swift coverage proving `recordReview` receives a non-placeholder Rust scheduler memory update when the bridge is available.

## Allowed Write Scope

- `Epistemos/Engine/FSRSDecayState.swift`
- `EpistemosTests/FSRSDecayStateTests.swift`
- `docs/fusion/deliberation/r12c_fsrs_swift_rust_scheduler_wiring_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_022_2026_05_01.md`

## Explicit Non-Scope

- No generated UniFFI binding check-ins.
- No app bootstrap database wiring.
- No FSRS sidebar UI changes.
- No `epistemos-core/**` Rust edits beyond the completed R12b slice.
- No `graph-engine/**`, protected note editor files, protected graph renderer/controller files, project files, entitlements, branch, stash, staging, or commit edits.

## Evidence Before Edit

- R12a persists Swift FSRS rows to GRDB.
- R12b exposes `fsrsScheduleReview(...)` through `epistemos-core` UDL and passed Rust tests.
- `FSRSDecayStore.recordReview` still uses placeholder Swift logic that updates timestamp/grade/count and resets retrievability to `1.0`, but does not update difficulty/stability through the Rust scheduler.

## Decision

Wire only the review-update path in this slice. Keep `topAtRisk` and current Swift retrievability math unchanged until a separate UI/runtime verification pass can compare surfacing behavior with the Rust power curve.

## Test Plan

- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test`
- Keep the existing R12a persistence tests in the same focused suite.

## Stop Triggers

- Any need to check in generated Swift bindings.
- Any need to change app bootstrap or production database initialization.
- Any need to touch protected graph/editor/rendering paths.

## Result

Implemented and verified.

Changes landed:

- `FSRSDecayState.swift` conditionally imports `epistemos_coreFFI`.
- `FSRSRustSchedulerBridge` converts Swift rows to generated R12b UniFFI rows and calls `fsrsScheduleReview(...)`.
- `FSRSDecayStore.recordReview` now uses Rust scheduler output when available and falls back to the previous Swift placeholder update otherwise.
- `FSRSDecayStateTests` now proves `recordReview` gets a non-placeholder Rust memory-state update when the bridge is available.

Verification:

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test`
- Log: `/tmp/epistemos-r12c-fsrs-swift-rust-wiring-green-20260501.log`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_01-11-14--0500.xcresult`
- Exit code: `0`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: 11 tests passed in 1 suite.

Repair:

- Initial compile failed because Swift 6 default isolation inferred the private bridge enum as main-actor isolated.
- Marking the bridge enum and generated-row extension `nonisolated` fixed it.

Post-slice audits:

- Tracked-source diff check log: `/tmp/epistemos-r12c-diff-check-20260501.log`
- Touched-file trailing whitespace audit log: `/tmp/epistemos-r12c-trailing-whitespace-audit-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r12c-source-anti-pattern-audit-20260501.log`
- Source line audit log: `/tmp/epistemos-r12c-source-audit-20260501.log`
- Protected diff audit log: `/tmp/epistemos-r12c-protected-diff-audit-20260501.log`
