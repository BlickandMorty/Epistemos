---
state: canon
candidate_promoted_on: 2026-05-05
canon_promoted_on: 2026-05-05
audit_item: A1 (canonical-upgrade-audit 2026-05-05)
unblocks: V2.1 Phase 8.H (DAG authority flip — durability prerequisite)
deliberation_brief_template: docs/fusion/BUILDER_EXECUTION_PROMPT_2026_04_30.md §"Deliberation Brief Required"
implementation_status: slices 1-4 landed by Codex continuation; slice 5 dispatch authority wiring remains off by default
---

# A1 — redb-backed `DagStore` — scoping + implementation record

> **State: canon-partial.** The original deliberation brief has now
> been executed through implementation slices 1-4 by Codex continuation:
> dependency, durable store, node/edge APIs, CD-005 capability checks,
> directional indices, snapshot, and Merkle parity. Slice 5 remains
> intentionally incomplete: dispatch does **not** use redb by default,
> and `cognitive_dag_store()` still returns the in-memory reference
> store until Phase 8.H authority verification explicitly flips it.
>
> **Why this matters:** today the only `DagStore` impl is
> `InMemoryDagStore`. A reboot loses the entire Cognitive DAG. V2.1
> Phase 8.H ("DAG authority flip — drop the legacy stores, the DAG
> is the source of truth") cannot proceed without a durable backend
> that survives process restarts. A1 is the unblock.

## What's already canonical (the substrate this builds on)

The `DagStore` trait at `agent_core/src/cognitive_dag/storage.rs:42-88`
has 9 methods:

| Method | Purpose |
|---|---|
| `put_node(node) -> Result<NodeId>` | Insert; idempotent on content-addressed id |
| `get_node(id) -> Result<Option<Node>>` | Lookup by id |
| `put_edge(edge) -> Result<EdgeId>` | Insert; capability-bound verification (CD-005) |
| `edges_from(node, kind?) -> Result<Vec<Edge>>` | Outbound traversal |
| `edges_to(node, kind?) -> Result<Vec<Edge>>` | Inbound traversal |
| `merkle_root() -> Result<Hash>` | Domain-separated BLAKE3 over canonical content |
| `snapshot() -> Result<DagSnapshot>` | Full export (used by Phase 8.F replay) |
| `register_capability(cap)` | CD-005 cap registration (default: no-op) |
| `registered_capabilities() -> Vec<Hash>` | Diagnostic readback |

`InMemoryDagStore` provides the reference implementation against
RwLock-protected BTreeMaps: nodes / edges / from_index / to_index /
capabilities. Iteration order is deterministic (BTreeMap sorts by
key); the snapshot output is byte-identical for stores with
identical content.

## Crate selection

**`redb` 4.1.0** is the recommended embedded KV store:

- Pure-Rust (no C dep, easier MAS sandbox compatibility than rocksdb)
- ACID semantics with MVCC + serializable isolation
- Zero-copy reads (memmap-backed; aligns with the 2026-05-05 mmap
  audit doctrine)
- BLAKE3-keyed table inserts are O(log n) with no hashing overhead
  beyond what the cognitive DAG already does
- Single-file database (mirrors SQLite's portability story; works
  inside a vault directory under security-scoped bookmark)
- Active maintenance (cberner/redb), used in production by other
  Rust projects

**Alternatives considered + ruled out:**

- `sled` — abandoned single-maintainer; corruption issues reported.
- `rocksdb` — C++ dep, MAS-build complexity, 4-5 MB binary cost.
- `lmdb` — C dep, mmap-only (read-only mmap is fine but write path
  is awkward), works but less Rust-native than redb.
- Roll-our-own with `memmap2` — every previous "we'll just write a
  small KV store" attempt becomes a maintenance liability.

## Schema design

Three redb tables, all keyed by fixed 32-byte BLAKE3 hashes:

```rust
// Table layout (all keys are &[u8; 32]; node/edge values are JSON bytes)
const NODES: TableDefinition<&[u8; 32], &[u8]> =
    TableDefinition::new("cognitive_dag_nodes_v1");
const EDGES: TableDefinition<&[u8; 32], &[u8]> =
    TableDefinition::new("cognitive_dag_edges_v1");
const CAPABILITIES: TableDefinition<&[u8; 32], ()> =
    TableDefinition::new("cognitive_dag_capabilities_v1");

// Two more tables for the directional indices, mirroring InMemory:
const FROM_INDEX: MultimapTableDefinition<&[u8; 32], &[u8; 32]> =
    MultimapTableDefinition::new("cognitive_dag_from_index_v1");
const TO_INDEX: MultimapTableDefinition<&[u8; 32], &[u8; 32]> =
    MultimapTableDefinition::new("cognitive_dag_to_index_v1");
```

**Why JSON bytes over bincode for the value encoding:** the original
brief recommended bincode, but the implementation falsified that
assumption. `Node` / `Edge` currently use serde shapes that require
`deserialize_any`, which bincode 1.x does not support. The redb
backend therefore stores `serde_json::to_vec` bytes for nodes and
edges. This is larger than bincode but correct, replay-friendly, and
compatible with the canonical JSON path already used by snapshots.

**Why `MultimapTableDefinition` for the indices:** redb's multimap
supports many-values-per-key natively, ordered by value bytes. That
matches the `Vec<EdgeId>` shape of `from_index` / `to_index` without
needing manual list management.

## Implementation plan (5 slices)

### Slice 1: Cargo dep + skeleton — LANDED

```toml
# agent_core/Cargo.toml
redb = { version = "4.1.0", optional = true }
```

New module: `agent_core/src/cognitive_dag/redb_store.rs` with
`RedbDagStore { db: redb::Database, path: PathBuf }`. Feature:
`cognitive-dag-redb = ["redb"]`. Default OFF.

### Slice 2: put_node + get_node — LANDED

Implement node insert + lookup against the `NODES` table. Test
parity against `InMemoryDagStore`: insert N nodes into both, read
all N back, assert byte-identical Node values returned.

Add a "round-trip across instances" test: open store at /tmp path,
insert nodes, drop store, reopen at same path, read nodes back. This
is the durability proof that InMemory cannot give.

### Slice 3: put_edge + edges_from + edges_to + capability registry — LANDED

Implemented edge insert with CD-005 capability-bound verification.
The redb backend mirrors the `InMemoryDagStore` rule directly:
empty capability registry accepts non-zero signatures for legacy
fixture compatibility; once a capability is registered, every edge
must verify against the registered set.

Test: every existing `cognitive_dag::storage::tests::*` test runs
against both backends via a parameterized test macro:
```rust
fn run_backend_tests<S: DagStore>(make: impl Fn() -> S) { /* ... */ }
#[test] fn in_memory() { run_backend_tests(InMemoryDagStore::new); }
#[test] fn redb() { run_backend_tests(|| RedbDagStore::open(tempfile())); }
```

### Slice 4: merkle_root + snapshot — LANDED

Both must produce byte-identical output to `InMemoryDagStore` for
identical content (this is the canonical content-addressing
contract). The trick: redb's iteration order matches BTreeMap's
(both sort by key bytes), so a straightforward iterate-and-hash
should give the same result. Verify with a fixture test that inserts
the same content into both backends and asserts merkle_root +
snapshot bytes equality.

### Slice 5: dispatch wiring + opt-in flag — PENDING

The fifth slice is the carefully-staged authority handoff:

1. Add a feature flag `cognitive-dag-redb` that, when enabled,
   makes `cognitive_dag_store()` return a `RedbDagStore` opened at
   `<vault>/.epistemos/cognitive_dag.redb` instead of an
   `InMemoryDagStore`. Default OFF — the InMemory remains
   authoritative until Codex verifies the redb path end-to-end.
2. Add a doctrine §10 verification gate ("two consecutive weeks of
   CI green with `cognitive-dag-redb` enabled and mirrors writing
   to the redb store on every legacy write").
3. After verification, flip the default. InMemory stays available
   for tests and ephemeral runtime profiles (e.g. private-mode
   sessions) — opt-out via `--no-default-features`.

## Test surface

| Layer | Test count est. | Notes |
|---|---|---|
| Per-method parity (InMemory vs redb) | 8 (one per non-default trait method) | Ensures redb behavior matches the reference. |
| CD-005 capability binding under redb | 4 | Mirror the existing InMemoryDagStore CD-005 tests. |
| Durability across process boundary | 3 | Insert / drop / reopen / read for nodes, edges, capabilities. |
| Concurrent access | 2 | Two reader threads + one writer thread; assert no corruption. redb's MVCC handles this; the test pins the contract. |
| Snapshot byte-identity (InMemory vs redb) | 1 | Same content → same canonical-JSON snapshot bytes. |
| Merkle root parity | 1 | Same content → same merkle root. |

Implemented now: 8 redb-specific tests plus the full cognitive DAG
suite under `--features mas-build,cognitive-dag-redb`.

Verified by Codex continuation:

```bash
cargo test --manifest-path agent_core/Cargo.toml \
  --no-default-features --features mas-build,cognitive-dag-redb \
  cognitive_dag::redb_store --lib

cargo test --manifest-path agent_core/Cargo.toml \
  --no-default-features --features mas-build,cognitive-dag-redb \
  --lib cognitive_dag --target aarch64-apple-darwin

cargo clippy --manifest-path agent_core/Cargo.toml \
  --no-default-features --features mas-build,cognitive-dag-redb \
  --target aarch64-apple-darwin -- -D warnings

cargo clippy --manifest-path agent_core/Cargo.toml \
  --target aarch64-apple-darwin -- -D warnings
```

Results: redb focused 8/8 pass; feature-enabled cognitive DAG 144/144
pass; default cognitive DAG 136/136 pass; default and redb-feature
clippy pass with `-D warnings`.

## Migration / rollback

There's no migration FROM data — `InMemoryDagStore` is
process-ephemeral; the redb store starts empty on first open.
Rollback is the feature flag (`cognitive-dag-redb` off → InMemory
returns).

The `.epistemos/cognitive_dag.redb` file path is canonical; if a
future schema change is needed, the `DagSnapshot::SCHEMA_VERSION`
const in `storage.rs:106` is the version pin. A schema bump means:
1. Old store gets re-opened in read-only mode
2. `snapshot()` exports to the new schema
3. New store is opened, snapshot is re-imported via put_node + put_edge
4. Old file is renamed to `.bak`

This is reversible, auditable, and matches the GRDB migration pattern
already used in Swift.

## Doctrine alignment

- **§2.2 invariant #1 (zero-copy):** redb is mmap-backed; reads are
  zero-copy via the OS page cache. Aligns with the 2026-05-05 mmap
  audit (`docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md`).
- **§2.2 invariant #2 (single-binary in-process):** redb is a Rust
  library, not a subprocess. Compiles into the agent_core dylib. No
  sidecar.
- **§2.2 invariant #3 (Markov blanket via Rust ownership):** the
  `DagStore` trait is the existing capsule; redb is just a new impl
  behind it. Swift sees only the existing FFI surface
  (`cognitive_dag_stats_json`).
- **§2.2 invariant #4 (tiered determinism):** redb's MVCC gives
  serializable isolation; the merkle root + snapshot byte-identity
  tests pin reproducibility.
- **CD-005 (capability-bound put_edge):** the redb impl reuses the
  same verification logic the InMemory impl uses today.
- **A2 + A2-followup (per-mirror caveat caps):** unaffected. The
  per-mirror caps are registered the same way regardless of backend.

## Effort estimate

- Slice 1: 30 min (deps + skeleton)
- Slice 2: 1-2 hours (put_node/get_node + parity tests + durability test)
- Slice 3: 2-3 hours (put_edge with CD-005 + edges_from/edges_to + parameterized tests)
- Slice 4: 1-2 hours (merkle_root + snapshot byte-identity)
- Slice 5: 1-2 hours (feature flag wiring + opt-in path + first-open behavior)

Total: 5-9 hours for a tight implementation pass. Add 2-3 hours for
documentation + Codex review cycles.

## Why this is not yet the authority backend

The durable backend exists, but the authority flip is not done. The
remaining deliberation is slice 5: when `cognitive-dag-redb` is
enabled, should dispatch open `<vault>/.epistemos/cognitive_dag.redb`
and mirror every legacy write into redb, or should redb remain a
manual parity/replay backend for one more verification cycle?

Canonical default today: **OFF**. `InMemoryDagStore` remains the live
`cognitive_dag_store()` backend until CD-004 and doctrine §10 say
otherwise.

## Cross-refs

- `agent_core/src/cognitive_dag/storage.rs` (the trait + InMemoryDagStore)
- `agent_core/src/cognitive_dag/dispatch.rs` (where `cognitive_dag_store()` lives)
- `docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md` (mmap doctrine — redb is mmap-backed)
- `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md` (CD-006 — coverage state survives backend swap)
- `docs/CANONICAL_UPGRADE_AUDIT_2026_05_05.md` A1 (the audit ask)
- `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` (this session's master ledger)
- V2.1 Phase 8.H authority flip — blocked on this slice

## Bottom line

The `DagStore` trait was designed (correctly) to support multiple
backends; now the second backend exists and is verified for durable
node/edge/capability storage plus Merkle/snapshot parity. What remains
is not implementation basics; it is authority wiring and the Phase
8.H decision to let redb become the live mirrored store.
