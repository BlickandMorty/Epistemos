# R16 ETL Apalis Queue PR2 Deliberation - 2026-05-01

## Verdict

Approved for a narrow Rust-only PR2 slice after source verification.

This gate does not approve Swift AFM sidecar generation, Shadow FFI exports,
Background Indexing UI, security-scoped bookmark enforcement, battery/thermal
pause wiring, or any protected graph/editor path. Those remain PR3+ work.

## Scope

Add a persisted SQLite-backed ETL job queue in `agent_core/src/etl/` using
Apalis workers. The implementation may define typed ingest jobs, enqueue jobs,
open an on-disk or in-memory queue, and run a worker until its caller stops it.

## Authority Evidence

- `docs/MASTER_BUILD_PLAN.md` lists R16 as foundation-only: walker + hash
  modules shipped; queue/job runners remain for PR2.
- `docs/RESEARCH_DOSSIER_TIER_3_4.md` says R16 belongs in
  `agent_core/src/etl/`, not a new crate, and that PR2 is the Apalis queue.
- `docs/plan/03_EXECUTION_MAP.md` marks the full R16 item high risk and
  requires later UI telemetry plus MAS bookmark scope; this PR2 is not claiming
  the full item done.
- Current code has `agent_core/src/etl/{mod,walker,hash}.rs` and
  `agent_core/src/lib.rs` already exposes `pub mod etl;`.

## Current API Evidence

- `cargo info apalis@1.0.0-rc.7` confirms `apalis` exists at the exact pinned
  RC and exposes the worker/monitor crate used by the dossier.
- `cargo info apalis-sqlite@1.0.0-rc.7` confirms the SQLite backend crate is
  `apalis-sqlite`, with default `tokio-comp`, `migrate`, `json`, and `chrono`
  features.
- docs.rs for `apalis-sqlite` 1.0.0-rc.7 shows `SqlitePool::connect`,
  `SqliteStorage::setup`, `SqliteStorage::new`, `SqliteStorage::new_in_queue`,
  `push_stream`, and `WorkerBuilder::new(...).backend(...).build(...).run()`.
- The older `apalis-sql = { version = "0.7.3", features = ["sqlite"] }`
  reference in the dossier/execution map is stale for `apalis = 1.0.0-rc.7`.

## Allowed Files

- `agent_core/Cargo.toml`
- `agent_core/Cargo.lock`
- `agent_core/src/etl/mod.rs`
- `agent_core/src/etl/jobs.rs`
- `agent_core/src/etl/queue.rs`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_027_2026_05_01.md`

## Forbidden Files And Subsystems

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `Epistemos/Engine/ShadowVaultBootstrapper.swift`
- `Epistemos/Engine/RustEtlFFIClient.swift`
- `Epistemos/Engine/AFMSidecarGenerator.swift`
- `epistemos-shadow/src/lib.rs`
- Xcode project files, generated `.rlib`, DerivedData, `.xcresult`
- No staging, committing, stashing, raw worktree merge, or generated binding work

## Implementation Plan

1. Add exact dependency pins:
   `apalis = "=1.0.0-rc.7"` and `apalis-sqlite = "=1.0.0-rc.7"`.
2. Add `jobs.rs` with typed, serde-serializable ETL jobs for markdown, PDF,
   and plain text inputs only.
3. Add `queue.rs` with `EtlQueue::open_at`, `EtlQueue::open_database_url`,
   `enqueue_job`, `enqueue_jobs`, and `run_worker`.
4. Register modules/re-exports from `etl/mod.rs`.
5. Prove enqueue + worker drain and on-disk reopen persistence with focused
   Rust tests.

## Acceptance

- The queue uses `apalis_sqlite::SqliteStorage` and `apalis::prelude::WorkerBuilder`.
- Tests enqueue typed jobs and drain them through an actual Apalis worker.
- Tests prove queued jobs survive closing/reopening the SQLite database before
  the worker drains them.
- Source-code sidecar generation remains excluded by reusing the existing
  walker classification boundary.
- No Swift, FFI, UI, protected graph/editor, or `graph-engine` files are touched.

## Commands

- `cargo test --manifest-path agent_core/Cargo.toml etl --lib`
- `cargo fmt --manifest-path agent_core/Cargo.toml --check`
- `git diff --check -- agent_core/Cargo.toml agent_core/src/etl docs/fusion`
- `git diff -- Epistemos/Views/Notes/ProseEditor*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine/`

## Stop Triggers

- Apalis 1.0.0-rc.7 APIs do not compile with Rust 1.94.0.
- Queue persistence requires Swift/FFI/UI changes.
- Worker drain cannot be proven without sleeps longer than a short timeout.
- Any protected path is touched by this slice.
- Cargo dependency resolution pulls in an incompatible Apalis/sqlx stack.

## WRV

WRV is not claimed for the full R16 product item. This is infrastructure inside
the existing multi-PR R16 sequence. User-visible Background Indexing status,
AFM sidecar badges, battery/thermal pause copy, and MAS bookmark enforcement
are explicitly deferred to later gates.
