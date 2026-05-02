# Codex / Kimi Oversight Round 022 - 2026-05-01

## Slice

R12c FSRS Swift/Rust Scheduler Wiring.

## Scope

- `Epistemos/Engine/FSRSDecayState.swift`
- `EpistemosTests/FSRSDecayStateTests.swift`
- `docs/fusion/deliberation/r12c_fsrs_swift_rust_scheduler_wiring_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Decision

Approved for Swift store wiring only: `FSRSDecayStore.recordReview` now prefers the Rust `fsrsScheduleReview(...)` bridge when the generated UniFFI module is available, while preserving the prior Swift placeholder update as fallback.

## Kimi Work

- Kimi did not edit this slice.
- R12c used the R12b Kimi read-only advisory only as background context.
- Codex performed all edits, compile repair, and verification.

## Codex Implementation

- Added conditional `epistemos_coreFFI` import to `FSRSDecayState.swift`.
- Added a private nonisolated bridge that converts Swift `FSRSDecayRow` values to the generated R12b UniFFI row shape.
- Wired `recordReview` to use Rust `fsrsScheduleReview(...)` output for difficulty/stability/retrievability updates when available.
- Preserved the previous timestamp/grade/review-count update as a fail-closed fallback.
- Added a focused Swift test proving the bridge-backed review updates memory stability away from the placeholder initial state.

## Test Results

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test`
- Log: `/tmp/epistemos-r12c-fsrs-swift-rust-wiring-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_01-11-14--0500.xcresult`
- Exit code: `0`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: 11 tests passed in 1 suite.

## Repair Notes

- First Xcode pass failed because Swift 6 default isolation inferred the private bridge enum as main-actor isolated.
- Fixed by marking the bridge enum and generated-row extension `nonisolated`.
- The rerun passed.

## Guardrails

- No generated UniFFI bindings were checked in.
- No app bootstrap database wiring or FSRS UI changed.
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` edits were made by this slice.
- No project file, entitlement, branch, stash, staging, or commit edits were made by this slice.

## Risks

- `topAtRisk` still uses the existing Swift retrievability formula; switching surfacing to the Rust FSRS-6 power curve should be a separate behavior/audit slice.
- Xcode still prints SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing package-plugin noise.
