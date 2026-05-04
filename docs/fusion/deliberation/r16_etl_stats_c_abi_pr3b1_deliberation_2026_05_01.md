# R16 ETL Stats C ABI PR3B.1 Deliberation - 2026-05-01

## Verdict

Approved for a narrow Rust-only C ABI bridge after PR3B.0.

This gate exposes the new ETL queue stats snapshot through a raw C ABI function
from `agent_core`, matching the existing hand-written FFI pattern used by rope
handles. It does not approve Swift UI wiring, generated UniFFI binding changes,
AFM sidecar generation, or ShadowVaultBootstrapper ETL dispatch.

## Scope

- Add a raw C ABI stats endpoint that returns a JSON snapshot for an existing
  ETL queue database path.
- Add a matching Rust-owned string-free function.
- Keep missing queue databases honest: report `available = false` and do not
  create a database solely for diagnostics.
- Cover null path, missing path, and pending-job JSON snapshots with Rust tests.

## Allowed Files

- `agent_core/src/etl/ffi.rs`
- `agent_core/src/etl/mod.rs`
- `agent_core/src/etl/queue.rs`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_031_2026_05_01.md`

## Forbidden Files

- `Epistemos/**`
- `epistemos-shadow/**`
- `graph-engine/**`
- Generated UniFFI bindings
- Xcode project files, entitlements, generated `.rlib`, DerivedData,
  `.xcresult`, staging, commits, stash operations

## Acceptance

- `etl_queue_stats_json(null)` returns a valid unavailable JSON snapshot.
- Missing database paths return unavailable JSON and do not create files.
- Existing queue databases return live counts from `EtlQueue::stats()`.
- Every unsafe block has a `SAFETY:` comment.
- `cargo test --manifest-path agent_core/Cargo.toml etl --lib` passes.
- `cargo fmt --manifest-path agent_core/Cargo.toml --check` passes.

## Commands

- `cargo test --manifest-path agent_core/Cargo.toml etl --lib`
- `cargo fmt --manifest-path agent_core/Cargo.toml --check`
- `git diff --check -- agent_core/src/etl/ffi.rs agent_core/src/etl/mod.rs agent_core/src/etl/queue.rs docs/fusion`
