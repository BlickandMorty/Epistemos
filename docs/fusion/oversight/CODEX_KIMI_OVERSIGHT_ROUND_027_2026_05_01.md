# Codex Kimi Oversight Round 027 - 2026-05-01

## Slice

R16 ETL crawler PR2: Rust-only Apalis SQLite queue and worker foundation.

## Verdict

Proceed within this slice. The implementation adds typed ETL ingest jobs, a
SQLite-backed Apalis queue, enqueue helpers, and a worker runner with focused
and full `agent_core` tests passing.

This does not claim full R16 completion or WRV. Swift AFM sidecar generation,
Shadow FFI exports, Background Indexing UI, battery/thermal pause UI, xattr
marking, and MAS bookmark enforcement remain deferred.

## Files Touched By This Slice

- `agent_core/Cargo.toml`
- `agent_core/Cargo.lock`
- `agent_core/src/etl/mod.rs`
- `agent_core/src/etl/jobs.rs`
- `agent_core/src/etl/queue.rs`
- `docs/fusion/deliberation/r16_etl_apalis_queue_pr2_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_027_2026_05_01.md`

Existing dirty files not owned by this slice:
- `agent_core/src/etl/hash.rs`
- `agent_core/src/etl/walker.rs`
- pre-existing `agent_core/Cargo.toml` tokio/profile edits
- pre-existing protected `graph-engine/**` diffs

## Dependency Decision

The dossier/execution-map text naming `apalis-sql = 0.7.3` is stale for the
current pinned Apalis RC. The implemented dependency pair is:

```toml
apalis = "=1.0.0-rc.7"
apalis-sqlite = "=1.0.0-rc.7"
```

Evidence:
- `cargo info apalis@1.0.0-rc.7`
- `cargo info apalis-sqlite@1.0.0-rc.7`
- docs.rs `apalis-sqlite` 1.0.0-rc.7 examples showing `SqliteStorage::setup`,
  `SqliteStorage::new_in_queue`, `push_stream`, and `WorkerBuilder`.

Cargo tree checks:
- `/tmp/epistemos-r16-pr2-cargo-tree-apalis-sqlite-20260501.log`
- `/tmp/epistemos-r16-pr2-cargo-tree-apalis-sql-20260501.log`
- `/tmp/epistemos-r16-pr2-cargo-tree-sqlx-postgres-20260501.log`
- `/tmp/epistemos-r16-pr2-cargo-tree-sqlx-mysql-20260501.log`

`apalis-sql` is transitive through `apalis-sqlite`; `sqlx-postgres` and
`sqlx-mysql` have no active dependency path in `agent_core`.

## Kimi Oversight

Kimi was used read-only only. It did not edit files, run repo tools, stage, or
commit.

Logs:
- Initial advisory attempts hit step limits without useful final output:
  `/tmp/epistemos-r16-pr2-kimi-advisory-20260501.log`
- CLI smoke test:
  `/tmp/epistemos-r16-pr2-kimi-smoke-20260501.log`
- Diff review:
  `/tmp/epistemos-r16-pr2-kimi-diff-review-20260501.log`

Kimi findings adjudication:
- Missing `jobs.rs` / `queue.rs`: false positive caused by giving Kimi plain
  `git diff`, which omitted untracked new files. Codex verified the files exist
  and compile.
- Test gap: stale/false after implementation. Focused ETL tests and full
  `agent_core` tests pass.
- PGO/tokio/profile drift: real existing dirty-diff concern, but not introduced
  by this PR2 code slice. Tracked as pre-existing `agent_core/Cargo.toml` state.
- Dependency bloat: partially valid to monitor. Cargo tree shows active SQLite
  path only for this slice; no active `sqlx-postgres` or `sqlx-mysql` path.
- Format-only `hash.rs` / `walker.rs`: pre-existing dirty formatting, not new
  queue behavior.

## Red/Green Evidence

Initial compile red:
- Log: `/tmp/epistemos-r16-pr2-etl-cargo-test-20260501.log`
- Result: compile failed on a test helper lifetime (`E0597`) after the first
  queue implementation.
- Fix: drop the mutex guard before returning the drained jobs vector.

Behavioral red:
- Log: `/tmp/epistemos-r16-pr2-etl-cargo-test-final-20260501.log`
- Result: queue worker test assumed insertion order, but Apalis does not
  guarantee FIFO order for this assertion.
- Fix: compare drained jobs by stable fingerprint/path ordering.

Focused green:

```bash
cargo test --manifest-path agent_core/Cargo.toml etl --lib
```

- Log: `/tmp/epistemos-r16-pr2-etl-cargo-test-final2-20260501.log`
- Result: `13` ETL tests passed, `0` failed.

Full `agent_core` green:

```bash
cargo test --manifest-path agent_core/Cargo.toml
```

- Log: `/tmp/epistemos-r16-pr2-agent-core-cargo-test-20260501.log`
- Result: `780` lib tests, `7` bin tests, `6` integration tests, and doc-tests
  passed; `0` failures.

## Hygiene Audits

- `cargo fmt --manifest-path agent_core/Cargo.toml --check`
  - Log: `/tmp/epistemos-r16-pr2-cargo-fmt-check-final-20260501.log`
  - Result: clean.
- `git diff --check -- agent_core/Cargo.toml agent_core/Cargo.lock agent_core/src/etl docs/fusion`
  - Log: `/tmp/epistemos-r16-pr2-diff-check-final-20260501.log`
  - Result: clean.
- New-source anti-pattern scan:
  - Log: `/tmp/epistemos-r16-pr2-source-antipattern-final-20260501.log`
  - Result: no `try!`, `unwrap(`, `expect(`, `repeatForever`, or production
    `print(` in the new R16 source files.
- New-file trailing whitespace scan:
  - Log: `/tmp/epistemos-r16-pr2-trailing-whitespace-final-20260501.log`
  - Result: clean.
- Protected diff name-only audit:
  - Log: `/tmp/epistemos-r16-pr2-protected-diff-name-only-20260501.log`
  - Result: only pre-existing `graph-engine/**` dirty files are listed; this
    slice touched no protected editor, graph view/controller, or graph-engine
    files.

## Remaining Risks

- Full R16 WRV remains unavailable until Swift UI/telemetry and AFM sidecar
  paths are deliberately gated and implemented.
- The repo still has substantial pre-existing dirty work, including
  `graph-engine/**`; this slice does not normalize or revert it.
- Apalis remains an RC dependency. Exact pinning and focused tests reduce but do
  not eliminate RC churn risk.

## Next Gate

R16 PR3 must deliberate separately before touching Swift, FFI, AFM sidecar
generation, Background Indexing UI, xattr marking, or MAS bookmark enforcement.
