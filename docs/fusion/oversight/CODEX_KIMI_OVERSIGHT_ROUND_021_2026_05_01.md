# Codex / Kimi Oversight Round 021 - 2026-05-01

## Slice

R12b FSRS Rust Bridge.

## Scope

- `epistemos-core/Cargo.toml`
- `epistemos-core/Cargo.lock`
- `epistemos-core/src/lib.rs`
- `epistemos-core/src/uniffi_exports.rs`
- `epistemos-core/src/fsrs_decay.rs`
- `epistemos-core/uniffi/epistemos_core.udl`
- `docs/fusion/deliberation/r12b_fsrs_rust_bridge_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Decision

Approved for a Rust-only R12b bridge: add `fsrs = "5.2.0"` to `epistemos-core`, expose typed UniFFI-safe FSRS decay rows, and verify the scheduler bridge before any Swift bootstrap/UI wiring.

## Kimi Work

- Kimi was invoked in terminal read-only advisory mode.
- First invocation hit the step cap without useful output.
- Second invocation ran from `/tmp` and returned an API/edge-case/test plan in `/tmp/epistemos-r12b-kimi-readonly-advisory-20260501.log`.
- Codex used Kimi's output as a cross-check only; Codex performed the code edits and verification.

## Codex Implementation

- Added the `fsrs` crate dependency and corresponding lockfile updates.
- Added `epistemos-core/src/fsrs_decay.rs`.
- Exposed `FsrsMemoryState`, `FsrsDecayRow`, `FsrsReviewOutcome`, and `FsrsDecayError` through the crate root and UDL.
- Added free functions:
  - `fsrs_default_parameters`
  - `fsrs_current_retrievability`
  - `fsrs_row_current_retrievability`
  - `fsrs_schedule_review`
- Validated finite timestamps, memory bounds, retrievability bounds, grade bounds, and desired-retention bounds.
- Kept the bridge stateless and deterministic; no app bootstrap wiring or generated Swift binding check-ins.

## Test Results

Focused bridge test:

- Command:
  `cd epistemos-core && cargo test fsrs_decay --lib`
- Log: `/tmp/epistemos-r12b-fsrs-rust-bridge-green-20260501.log`
- Result: 7 tests passed; 0 failed.

Full epistemos-core lib test:

- Command:
  `cd epistemos-core && cargo test --lib`
- Log: `/tmp/epistemos-r12b-epistemos-core-lib-test-20260501.log`
- Result: 373 tests passed; 0 failed.

Formatting:

- Command:
  `cd epistemos-core && cargo fmt -- --check`
- Log: `/tmp/epistemos-r12b-cargo-fmt-check-20260501.log`
- Result: clean.

Clippy:

- Command:
  `cd epistemos-core && cargo clippy --lib -- -D warnings`
- Log: `/tmp/epistemos-r12b-cargo-clippy-20260501.log`
- Result: failed on pre-existing unrelated warnings in `skill_engine`, `vault_analyzer`, and the existing `ssm_save_state` argument count; no `fsrs_decay` hits were present.

## Guardrails

- `git diff --check` on touched tracked R12b files is clean.
- Touched-file trailing whitespace audit is clean.
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` edits were made by this slice.
- No Swift app bootstrap, FSRS UI, project file, entitlement, generated binding, branch, stash, staging, or commit edits were made by this slice.

## Risks

- Swift call sites are not yet wired to this bridge; that is the next R12 follow-up.
- Generated Swift bindings were not checked in by design.
- Clippy cannot currently be used as a zero-warning gate for the crate without addressing unrelated existing warnings.
