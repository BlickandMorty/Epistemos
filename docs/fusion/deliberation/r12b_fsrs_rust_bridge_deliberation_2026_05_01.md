# R12b FSRS Rust Bridge Deliberation - 2026-05-01

## Gate

Approved for the second R12 slice: add the Rust `fsrs = "5.2.0"` dependency to `epistemos-core` and expose a minimal UniFFI scheduling/retrievability bridge.

## Classification

Core/MAS-safe.

## Scope

- Add the `fsrs` crate to `epistemos-core`.
- Mirror the Swift `FSRSDecayRow` storage contract with Rust UniFFI-safe dictionaries.
- Expose Rust helpers for:
  - default FSRS parameters;
  - current retrievability using the crate's FSRS-6 decay constant;
  - row-current retrievability from `last_reviewed`;
  - review scheduling through `FSRS::next_states`.
- Add Rust unit tests for the bridge contract.

## Allowed Write Scope

- `epistemos-core/Cargo.toml`
- `epistemos-core/Cargo.lock`
- `epistemos-core/src/lib.rs`
- `epistemos-core/src/uniffi_exports.rs`
- `epistemos-core/src/fsrs_decay.rs`
- `epistemos-core/uniffi/epistemos_core.udl`
- `docs/fusion/deliberation/r12b_fsrs_rust_bridge_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_021_2026_05_01.md`

## Explicit Non-Scope

- No Swift app bootstrap wiring.
- No generated UniFFI binding check-ins.
- No FSRS sidebar UI changes.
- No `graph-engine/**`, protected note editor files, protected graph renderer/controller files, project files, entitlements, branch, stash, staging, or commit edits.

## Evidence Before Edit

- R12a added Swift GRDB persistence for the existing actor store and left Rust algorithm wiring as R12b.
- `epistemos-core` already exposes free functions through `src/uniffi_exports.rs` and `uniffi/epistemos_core.udl`.
- The `fsrs` crate exposes `FSRS::new(Some(&DEFAULT_PARAMETERS))`, `MemoryState`, `FSRS6_DEFAULT_DECAY`, `current_retrievability`, and `next_states`.

## Decision

Keep this slice Rust-only so the algorithm bridge can compile and test independently before Swift call sites are moved from the pure-Swift placeholder math to the Rust scheduler.

## Test Plan

- Run:
  `cd epistemos-core && cargo test fsrs_decay --lib`
- If UniFFI scaffolding compilation catches UDL/type mismatches, fix them in this slice.

## Stop Triggers

- Any need to regenerate checked-in Swift bindings.
- Any need to wire app bootstrap or UI.
- Any need to touch protected graph/editor/rendering paths.

## Result

Implemented and verified.

Changes landed:

- Added `fsrs = "5.2.0"` to `epistemos-core`.
- Added `FsrsMemoryState`, `FsrsDecayRow`, `FsrsReviewOutcome`, and `FsrsDecayError`.
- Added bridge functions for default parameters, current retrievability, row-current retrievability, and scheduling a review into an updated row.
- Added UDL declarations for the new dictionaries, error enum, and free functions.
- Added Rust unit coverage for FSRS-6 parameter shape, retrievability at stability, clock-skew clamping, review scheduling, invalid grades, nonfinite memory, and corrupt reviewed rows.

Verification:

- `cd epistemos-core && cargo test fsrs_decay --lib`
  - Log: `/tmp/epistemos-r12b-fsrs-rust-bridge-green-20260501.log`
  - Result: 7 tests passed; 0 failed.
- `cd epistemos-core && cargo test --lib`
  - Log: `/tmp/epistemos-r12b-epistemos-core-lib-test-20260501.log`
  - Result: 373 tests passed; 0 failed.
- `cd epistemos-core && cargo fmt -- --check`
  - Log: `/tmp/epistemos-r12b-cargo-fmt-check-20260501.log`
  - Result: clean.

Clippy evidence:

- `cd epistemos-core && cargo clippy --lib -- -D warnings`
  - Log: `/tmp/epistemos-r12b-cargo-clippy-20260501.log`
  - Result: blocked by pre-existing unrelated warnings; no `fsrs_decay` findings.

Post-slice audits:

- Tracked-source diff check log: `/tmp/epistemos-r12b-diff-check-20260501.log`
- Touched-file trailing whitespace audit log: `/tmp/epistemos-r12b-trailing-whitespace-audit-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r12b-source-anti-pattern-audit-20260501.log`
- Source line audit log: `/tmp/epistemos-r12b-source-audit-20260501.log`
- Protected diff audit log: `/tmp/epistemos-r12b-protected-diff-audit-20260501.log`
- Kimi read-only advisory log: `/tmp/epistemos-r12b-kimi-readonly-advisory-20260501.log`
