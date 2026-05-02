# R15 sqlite-vec KNN Fixture Baseline PR4 Deliberation - 2026-05-01

## Scope

Add a test-only, ignored-by-default Rust integration baseline for sqlite-vec KNN
at 100k deterministic fixture vectors.

This follows:

- R13 sqlite-vec + petgraph foundation, which added `sqlite-vec = "=0.1.9"`,
  `rusqlite = "0.32"`, direct per-connection sqlite-vec loading, and validated
  `vec0` schema rendering in `epistemos-core`.
- R15 PR1, which added the JSON benchmark report schema.
- R15 PR2/PR3, which added deterministic fixture baselines without touching
  production graph/editor surfaces.

## Evidence

- `docs/RESEARCH_DOSSIER_TIER_3_4.md` R15 names sqlite-vec KNN at 100k vectors
  as a required specialized benchmark.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` still lists
  sqlite-vec 100k KNN as a remaining R15 specialized baseline.
- `epistemos-core/src/vector_graph.rs` exposes
  `load_sqlite_vec_connection(&Connection)` and
  `note_embeddings_schema(table_name, dimensions)`.
- Local sqlite-vec 0.1.9 source requires KNN queries to use
  `embedding MATCH ?`, either `k = ?` or `LIMIT`, and
  `ORDER BY distance`.

## Decision

Add `epistemos-core/tests/sqlite_vec_knn_baseline.rs` instead of wiring the
Swift disabled benchmark through GRDB in this slice.

Reasons:

- It verifies the real sqlite-vec extension path now available in
  `epistemos-core`.
- It avoids production Swift storage wiring and migration risk.
- It avoids modifying protected graph/editor hot paths.
- It produces a JSON report compatible with the R15 benchmark recorder schema.

## Non-Goals

- Do not claim production KNN is wired into user-facing search.
- Do not touch Swift GRDB storage, app runtime, generated UniFFI bindings, or
  `.xcodeproj`.
- Do not convert the disabled Swift `SQLiteVecKNNBenchTests` placeholder into a
  production benchmark yet.
- Do not optimize sqlite-vec, graph-engine, or vector dimensions beyond this
  deterministic fixture gate.

## Allowed Files

- `epistemos-core/tests/sqlite_vec_knn_baseline.rs`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json`
- `docs/fusion/deliberation/r15_sqlite_vec_knn_fixture_baseline_pr4_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_057_2026_05_01.md`

## Protected Files

- No `Epistemos/Views/Notes/ProseEditor*.swift`
- No `Epistemos/Views/Notes/ProseTextView2.swift`
- No `Epistemos/Views/Graph/**`
- No `graph-engine/**`
- No `epistemos-shadow/**`
- No generated bindings or Xcode project edits

## Red Test

Before implementation:

```bash
cargo test --manifest-path epistemos-core/Cargo.toml --test sqlite_vec_knn_baseline -- --ignored --nocapture
```

Result: failed because Cargo had no `sqlite_vec_knn_baseline` integration test
target.

Log: `/tmp/epistemos-r15-sqlite-vec-knn-pr4-red-cargo-20260501.log`

## Green Test

After implementation:

```bash
EPISTEMOS_BENCHMARK_RESULTS_DIR=/Users/jojo/Downloads/Epistemos/benchmarks/results \
  cargo test --manifest-path epistemos-core/Cargo.toml \
  --test sqlite_vec_knn_baseline -- --ignored --nocapture
```

Expected:

- The ignored manual baseline runs only when explicitly selected.
- 100k deterministic 32-dimensional vectors are inserted into a real `vec0`
  table.
- 16 KNN queries return `k = 10` sorted distance rows.
- The JSON report includes finite p50/p95/p99 values and fixture metadata.

Actual:

- Focused ignored run passed with `1` test, `0` failed.
- Default target run passed with `5` lightweight source-loaded
  `vector_graph` checks and the 100k KNN baseline ignored.
- Report:
  `benchmarks/results/2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json`
- Measured fixture values:
  p50 `0.012303229499999999`, p95 `0.01238895875`, p99
  `0.012405858950000001` seconds.
- Logs:
  `/tmp/epistemos-r15-sqlite-vec-knn-pr4-green-cargo-20260501.log`
  and `/tmp/epistemos-r15-sqlite-vec-knn-pr4-default-cargo-20260501.log`

## Implementation Note

`epistemos-core` is currently configured as an FFI crate with `cdylib` and
`staticlib` crate types. To avoid changing production Cargo outputs for this
test-only baseline, the integration test source-loads
`epistemos-core/src/vector_graph.rs` and uses its direct connection loader.

## Rollback

Remove the integration test, generated JSON report, and this deliberation note.
No production code or schema migration should need rollback.

## Stop Triggers

- sqlite-vec cannot insert or query the real fixture.
- Query requires a production storage workaround.
- Any protected path changes.
- The baseline needs non-deterministic network/model dependencies.
