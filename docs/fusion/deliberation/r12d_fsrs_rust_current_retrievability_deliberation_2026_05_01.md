# R12d FSRS Rust Current-Retrievability Deliberation - 2026-05-01

## Gate

Approved for a narrow follow-up to R12c: route Swift FSRS current-retrievability surfacing through the Rust `fsrs` bridge when generated bindings are available, while preserving the existing Swift approximation as fallback.

## Classification

Core/MAS-safe.

## Why This Slice

- R12b added the Rust `fsrs = "5.2.0"` bridge with `fsrs_row_current_retrievability`.
- R12c wired explicit review scheduling to Rust but intentionally left `topAtRisk` on the existing Swift retrievability formula.
- R13 is complete; R14/R15 are already marked shipped/foundation in `docs/MASTER_BUILD_PLAN.md`, and the repo already has UniFFI `=0.29.5` plus benchmark scaffolds.
- This is a smaller, user-facing correctness slice than jumping into high-risk graph-engine, rope, or agent-core follow-ups.

## Scope

- Add a Swift bridge method for Rust current retrievability.
- Make `FSRSRetrievability.current(for:now:)` prefer the Rust FSRS curve when `epistemos_coreFFI` is importable.
- Keep the Swift formula as fail-closed fallback.
- Add focused tests proving the Rust curve is used when available and the fallback remains deterministic.
- Update fusion floor/oversight docs.

## Allowed Write Scope

- `Epistemos/Engine/FSRSDecayState.swift`
- `EpistemosTests/FSRSDecayStateTests.swift`
- `docs/fusion/deliberation/r12d_fsrs_rust_current_retrievability_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_024_2026_05_01.md`

## Explicit Non-Scope

- No app bootstrap database wiring.
- No FSRS UI changes.
- No new Rust `fsrs_decay` API.
- No generated UniFFI binding check-ins.
- No graph-engine, protected editor, protected graph renderer/controller, project, entitlement, branch, stash, staging, or commit changes.

## Evidence Before Edit

- `Epistemos/Engine/FSRSDecayState.swift` has `FSRSRetrievability.current` using the Swift exponential approximation.
- `epistemos-core/src/fsrs_decay.rs` exposes `row_current(...)` through `fsrs_row_current_retrievability`.
- `Epistemos/Engine/FSRSDecayState.swift` already conditionally imports `epistemos_coreFFI` and has row conversion code for review scheduling.
- R12c floor note explicitly says Rust power-curve surfacing remains separate.

## Alternatives Considered

- Leave Swift formula forever: rejected because Rust bridge is now present and should be authoritative when available.
- Remove Swift formula: rejected because builds without generated UniFFI bindings still need deterministic fallback.
- Broaden into FSRS UI or app bootstrap DB configuration: rejected as separate user-facing/runtime slices.

## Tests And Logs

Planned command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test
```

Post-edit audits:
- `git diff --check`
- touched-file trailing whitespace audit
- source anti-pattern audit
- protected diff audit

## Rollback

Revert only the R12d edits to `FSRSDecayState.swift`, `FSRSDecayStateTests.swift`, and the R12d fusion docs. Keep R12a/R12b/R12c/R13 intact.

## Stop Triggers

- Generated bindings are required to be checked in.
- Existing FSRS persistence tests regress.
- Rust bridge failure removes fallback behavior.
- Any protected path becomes necessary.

## Result

Completed.

Changes:
- `FSRSRetrievability.current(for:now:)` now prefers `fsrsRowCurrentRetrievability(...)` through the generated `epistemos_coreFFI` bridge.
- Swift fallback remains in place for builds without generated UniFFI bindings or bridge failures.
- `FSRSRustSchedulerBridge` now shares the Swift-to-UniFFI row adapter between review scheduling and current retrievability.
- FSRS tests now assert the FSRS-6 Rust power curve when the bridge is importable, while preserving fallback expectations for non-bridge builds.

Verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test
```

- Log: `/tmp/epistemos-r12d-fsrs-rust-current-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_01-46-07--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `12` tests passed in `1` suite.

Known external noise:
- Xcode still reports SwiftLint command failures for `CodeEditTextView` and `CodeEditSourceEditor` after `** TEST SUCCEEDED **`; this matches prior focused runs and is not caused by R12d.

Post-slice audits:
- Diff check: `/tmp/epistemos-r12d-diff-check-20260501.log` - empty.
- Trailing whitespace audit: `/tmp/epistemos-r12d-trailing-whitespace-audit-20260501.log` - empty.
- Source anti-pattern audit: `/tmp/epistemos-r12d-source-anti-pattern-audit-20260501.log` - empty.
- Protected diff audit: `/tmp/epistemos-r12d-protected-diff-audit-20260501.log` - non-empty only for pre-existing `graph-engine/**` dirty files outside R12d scope.
