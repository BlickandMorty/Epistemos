# R16 ETL Queue Stats PR3B.0 Deliberation - 2026-05-01

## Verdict

Approved for a narrow Rust-only PR3B.0 build slice.

This gate adds live ETL queue counters to the existing `agent_core` Apalis
SQLite queue foundation. It does not wire Swift UI, does not add a C/UniFFI
bridge, and does not claim full R16 PR3 completion.

## Scope

- Add an `EtlQueueStats` snapshot type for the existing
  `agent_core::etl::EtlQueue`.
- Add `EtlQueue::stats()` that reads Apalis SQLite metrics for
  `ETL_QUEUE_NAME`.
- Cover empty, pending, and drained queue states with Rust tests.

## Allowed Files

- `agent_core/src/etl/queue.rs`
- `agent_core/src/etl/mod.rs`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_030_2026_05_01.md`

## Forbidden Files

- `Epistemos/**`
- `epistemos-shadow/**`
- `graph-engine/**`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- Xcode project files, entitlements, generated bindings, generated `.rlib`,
  DerivedData, `.xcresult`, staging, commits, stash operations

## Kimi Instructions

Kimi may edit only the two allowed Rust files. If it needs any other file, it
must stop and report why. It must not run staging, commit, stash, branch, or
generated-binding commands.

## Acceptance

- `EtlQueue::stats()` returns deterministic zero counts for a new queue.
- Enqueued jobs appear as pending/active counters.
- Drained jobs appear as done/completed counters.
- The ETL focused cargo test passes.
- No protected or Swift files are edited by this slice.

## Commands

- `cargo test --manifest-path agent_core/Cargo.toml etl --lib`
- `cargo fmt --manifest-path agent_core/Cargo.toml --check`
- `git diff --check -- agent_core/src/etl/queue.rs agent_core/src/etl/mod.rs docs/fusion`
