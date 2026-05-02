# R13 sqlite-vec + petgraph Foundation Deliberation - 2026-05-01

## Gate

Approved for the first R13 foundation slice: add `sqlite-vec` and `petgraph` to `epistemos-core`, expose safe vec0 schema/extension helpers, and add a stable graph projection primitive.

## Classification

Core/MAS-safe.

## Scope

- Add `sqlite-vec = "0.1.9"` and `petgraph = "0.8.2"` to `epistemos-core`.
- Add only the extra SQLite Rust dependency needed to test vec0 installation from Rust.
- Provide a safe table-name/dimension validated vec0 note-embedding schema helper.
- Provide process-level sqlite-vec auto-extension registration.
- Provide a `StableDiGraph` projection over explicit node/edge inputs.
- Add Rust tests for vec0 schema, sqlite-vec registration/table creation, graph projection, and invalid edge handling.

## Allowed Write Scope

- `epistemos-core/Cargo.toml`
- `epistemos-core/Cargo.lock`
- `epistemos-core/src/lib.rs`
- `epistemos-core/src/uniffi_exports.rs`
- `epistemos-core/src/vector_graph.rs`
- `epistemos-core/uniffi/epistemos_core.udl`
- `docs/fusion/deliberation/r13_sqlite_vec_petgraph_foundation_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_023_2026_05_01.md`

## Explicit Non-Scope

- No Swift/GRDB call-site wiring.
- No generated UniFFI binding check-ins.
- No benchmark harness.
- No `graph-engine/**`, protected note editor files, protected graph renderer/controller files, project files, entitlements, branch, stash, staging, or commit edits.

## Evidence Before Edit

- R13 queue item requires `sqlite-vec = "0.1.9"` and `petgraph = "0.8.2"` in `epistemos-core`.
- The `sqlite-vec` crate exposes `sqlite3_vec_init` and its own test registers it through `sqlite3_auto_extension`.
- `petgraph` exposes `stable_graph::StableDiGraph`, which fits the requested stable projection foundation.

## Decision

Land a compile-tested Rust foundation first. Swift GRDB runtime wiring and KNN benchmarks should come later so this slice can isolate dependency/linkage risk.

## Test Plan

- Run:
  `cd epistemos-core && cargo test vector_graph --lib`
- Then run:
  `cd epistemos-core && cargo test --lib`

## Stop Triggers

- Any need to change Swift app runtime wiring.
- Any need to check in generated Swift bindings.
- Any need to touch protected graph/editor/rendering paths.

## Result

Status: approved and implemented with one important sqlite-vec nuance.

Implemented:
- Added `sqlite-vec = "=0.1.9"`, `petgraph = "=0.8.2"`, and `rusqlite = "0.32"` to `epistemos-core`.
- Added `epistemos-core/src/vector_graph.rs` with validated vec0 schema rendering, best-effort sqlite-vec auto-extension registration, direct per-`rusqlite::Connection` sqlite-vec loading, and `StableDiGraph` projection.
- Exposed UniFFI-safe R13 helpers for auto-extension registration, vec0 schema rendering, and stable graph projection.
- Added tests for schema validation, sqlite-vec direct load + `vec0` table creation, auto-extension false-positive guarding, stable node/edge projection, and dangling edge rejection.

Nuance:
- On this macOS/Rust path, `sqlite-vec` 0.1.9's own `sqlite3_auto_extension` crate test fails with `no such function: vec_version`; local proof is in `/tmp/sqlite-vec-crate-rusqlite-auto-extension-20260501.log`.
- R13 therefore does not claim global auto-extension is reliable. The helper is retained and guarded: if it ever returns success, a fresh connection must prove `vec_version()`.
- The verified usable path in this slice is direct loading into a Rust-owned `rusqlite::Connection` via the statically linked `sqlite3_vec_init` symbol. Swift/GRDB handle-level wiring remains out of scope and must not assume process-level auto-extension works.

Verification:
- `cd epistemos-core && cargo test vector_graph --lib`
  - Log: `/tmp/epistemos-r13-vector-graph-foundation-green-20260501.log`
  - Result: `5` passed, `0` failed.
- `cd epistemos-core && cargo test --lib`
  - Log: `/tmp/epistemos-r13-epistemos-core-lib-test-20260501.log`
  - Result: `378` passed, `0` failed.
- `cd epistemos-core && cargo fmt -- --check`
  - Log: `/tmp/epistemos-r13-cargo-fmt-check-20260501.log`
  - Result: clean.
- `cd epistemos-core && cargo clippy --lib -- -D warnings`
  - Log: `/tmp/epistemos-r13-cargo-clippy-20260501.log`
  - Result: blocked by pre-existing unrelated lint backlog; no `vector_graph` or `fsrs_decay` findings after the annotated sqlite-vec transmute fix.

Audit logs:
- Diff check: `/tmp/epistemos-r13-diff-check-20260501.log`
- Source anti-pattern audit: `/tmp/epistemos-r13-source-anti-pattern-audit-20260501.log`
- Unsafe safety audit: `/tmp/epistemos-r13-unsafe-safety-audit-20260501.log`
- Source line audit: `/tmp/epistemos-r13-source-audit-20260501.log`
- Protected diff audit: `/tmp/epistemos-r13-protected-diff-audit-20260501.log`
- Kimi read-only sqlite-vec advisory: `/tmp/epistemos-r13-kimi-sqlite-vec-advisory-20260501.log`

Guardrails:
- No generated UniFFI bindings checked in.
- No Swift/GRDB call-site wiring changed.
- No protected note editor files changed.
- No protected graph renderer/controller files changed.
- No `graph-engine/**` edits were made by this slice; protected diff audit still shows pre-existing graph-engine dirty files from outside this slice.
