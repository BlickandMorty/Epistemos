# Codex/Kimi Oversight Round 057 - R15 sqlite-vec KNN Fixture Baseline PR4

## Scope

R15 sqlite-vec KNN fixture baseline only.

## Approved Files

- `epistemos-core/tests/sqlite_vec_knn_baseline.rs`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json`
- `docs/fusion/deliberation/r15_sqlite_vec_knn_fixture_baseline_pr4_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_057_2026_05_01.md`

## Red Evidence

Command:

```bash
cargo test --manifest-path epistemos-core/Cargo.toml --test sqlite_vec_knn_baseline -- --ignored --nocapture
```

Result:

- Failed with no `sqlite_vec_knn_baseline` integration target.
- Log: `/tmp/epistemos-r15-sqlite-vec-knn-pr4-red-cargo-20260501.log`

## Green Evidence

Focused ignored run:

```bash
EPISTEMOS_BENCHMARK_RESULTS_DIR=/Users/jojo/Downloads/Epistemos/benchmarks/results \
  cargo test --manifest-path epistemos-core/Cargo.toml \
  --test sqlite_vec_knn_baseline -- --ignored --nocapture
```

Result:

- `1` test passed, `0` failed.
- Log: `/tmp/epistemos-r15-sqlite-vec-knn-pr4-green-cargo-20260501.log`
- Report:
  `benchmarks/results/2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json`
- Fixture metrics:
  p50 `0.012303229499999999`, p95 `0.01238895875`, p99
  `0.012405858950000001` seconds.

Default target run:

```bash
cargo test --manifest-path epistemos-core/Cargo.toml --test sqlite_vec_knn_baseline
```

Result:

- `5` lightweight source-loaded `vector_graph` checks passed.
- The 100k KNN baseline was ignored by default.
- Log: `/tmp/epistemos-r15-sqlite-vec-knn-pr4-default-cargo-20260501.log`

## Guardrails

- This is a real sqlite-vec `vec0` fixture, not a sleep placeholder.
- The test is ignored/manual by default because it inserts 100k vectors.
- It uses R13's direct per-connection sqlite-vec loading path.
- It does not touch Swift production storage, Graph UI, editor internals,
  `graph-engine`, generated bindings, or Xcode project files.

## Kimi Read-Only Advisory

Log: `/tmp/epistemos-r15-sqlite-vec-knn-kimi-advisory-20260501.log`

Verdict:

- No architecture drift.
- No false production claims.
- sqlite-vec query shape is valid.
- JSON report is compatible with the R15 recorder schema.
- Protected-path risk is zero.
- Safe to commit as a test-only baseline.

## Current Verdict

Close PR4 after exact-file staging. This closes the R15 sqlite-vec 100k x 32d
fixture baseline only; it does not claim production GRDB KNN wiring or 768d
embedding latency.
