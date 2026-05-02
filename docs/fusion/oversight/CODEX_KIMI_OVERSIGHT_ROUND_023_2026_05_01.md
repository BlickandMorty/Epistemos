# Codex / Kimi Oversight Round 023 - R13 sqlite-vec + petgraph Foundation

Date: 2026-05-01

## Scope

R13 foundation slice for `epistemos-core`:
- Add `sqlite-vec`, `rusqlite`, and `petgraph` dependencies.
- Add a validated vec0 schema helper.
- Add sqlite-vec registration/loading foundation.
- Add a `StableDiGraph` projection primitive.
- Expose only safe UniFFI-compatible helper functions for later Swift wiring.

## Kimi Use

Kimi was used read-only for a narrow sqlite-vec advisory after local tests showed that process-level auto-extension registration did not make `vec_version()` available on a fresh connection.

Kimi order constraints:
- Read-only advisory.
- No file edits.
- No writes.
- No staging.
- No commits.

Kimi log:
`/tmp/epistemos-r13-kimi-sqlite-vec-advisory-20260501.log`

Kimi recommendation:
- Use direct per-connection sqlite-vec initialization for Rust-owned `rusqlite::Connection`s.
- Do not claim global auto-extension works when it is not locally proven.
- Keep the unsafe initialization tightly documented and tested.

Codex disposition:
- Accepted the direct-loader recommendation.
- Rejected any unverified global auto-extension success claim.
- Kept Swift/GRDB handle wiring out of scope for a later deliberated slice.

## Codex Verification

Focused R13 test:

```bash
cd epistemos-core && cargo test vector_graph --lib
```

- Log: `/tmp/epistemos-r13-vector-graph-foundation-green-20260501.log`
- Result: `5` passed, `0` failed.

Full Rust lib test:

```bash
cd epistemos-core && cargo test --lib
```

- Log: `/tmp/epistemos-r13-epistemos-core-lib-test-20260501.log`
- Result: `378` passed, `0` failed.

Format:

```bash
cd epistemos-core && cargo fmt -- --check
```

- Log: `/tmp/epistemos-r13-cargo-fmt-check-20260501.log`
- Result: clean.

Clippy:

```bash
cd epistemos-core && cargo clippy --lib -- -D warnings
```

- Log: `/tmp/epistemos-r13-cargo-clippy-20260501.log`
- Result: blocked by pre-existing unrelated lint backlog.
- New R13 file check: no `vector_graph` findings after replacing the unannotated transmute with a typed helper.

## sqlite-vec Evidence

Local upstream crate check:

```bash
cargo test test_rusqlite_auto_extension --manifest-path ~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/sqlite-vec-0.1.9/Cargo.toml
```

- Log: `/tmp/sqlite-vec-crate-rusqlite-auto-extension-20260501.log`
- Result: failed with `no such function: vec_version`.

R13 consequence:
- `register_sqlite_vec_auto_extension()` remains best-effort and guarded.
- `load_sqlite_vec_connection(&rusqlite::Connection)` is the verified Rust-owned connection path.
- Later Swift/GRDB wiring must deliberate handle-level loading explicitly; it must not assume the global auto-extension path is reliable.

## Files Changed

R13 files:
- `epistemos-core/Cargo.toml`
- `epistemos-core/Cargo.lock`
- `epistemos-core/src/lib.rs`
- `epistemos-core/src/uniffi_exports.rs`
- `epistemos-core/src/vector_graph.rs`
- `epistemos-core/uniffi/epistemos_core.udl`
- `docs/fusion/deliberation/r13_sqlite_vec_petgraph_foundation_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_023_2026_05_01.md`

## Guardrails

- No generated UniFFI bindings checked in.
- No Swift/GRDB runtime wiring changed.
- No protected note editor files changed.
- No protected graph renderer/controller files changed.
- No `graph-engine/**` edits were made by this slice.
- Protected diff audit still shows pre-existing graph-engine dirty files from outside R13.
- No staging, commits, branch changes, stash operations, project-file edits, or entitlement edits.
