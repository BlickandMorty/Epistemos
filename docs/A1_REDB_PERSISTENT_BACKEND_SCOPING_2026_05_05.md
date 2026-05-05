---
state: candidate
candidate_promoted_on: 2026-05-05
audit_item: A1 (canonical-upgrade-audit 2026-05-05)
unblocks: V2.1 Phase 8.H (DAG authority flip — durability prerequisite)
deliberation_brief_template: docs/fusion/BUILDER_EXECUTION_PROMPT_2026_04_30.md §"Deliberation Brief Required"
---

# A1 — redb-backed `DagStore` — scoping brief

> **State: candidate.** Per the canon promotion protocol, this is a
> deliberation brief — it scopes the implementation, identifies the
> dependencies, lists the test surface, and queues the actual coding
> for explicit sign-off. **Do not implement from this brief without
> approval.**
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

**`redb` 2.x** is the recommended embedded KV store:

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

Three redb tables, all keyed by 32-byte BLAKE3 hashes:

```rust
// Table layout (all keys are [u8; 32], values are bincode-encoded)
const NODES: TableDefinition<&[u8], &[u8]> = TableDefinition::new("nodes");
const EDGES: TableDefinition<&[u8], &[u8]> = TableDefinition::new("edges");
const CAPABILITIES: TableDefinition<&[u8], ()> = TableDefinition::new("capabilities");

// Two more tables for the directional indices, mirroring InMemory:
const FROM_INDEX: MultimapTableDefinition<&[u8], &[u8]> =
    MultimapTableDefinition::new("from_index");
const TO_INDEX: MultimapTableDefinition<&[u8], &[u8]> =
    MultimapTableDefinition::new("to_index");
```

**Why bincode over canonical JSON for the value encoding:** the
canonical-JSON form lives in the snapshot/replay path (where
byte-identical sort matters for content addressing). The on-disk
form just needs to be round-trippable; bincode is 3-5x smaller and
~10x faster to encode/decode. The snapshot method re-serializes
to canonical JSON when called.

**Why `MultimapTableDefinition` for the indices:** redb's multimap
supports many-values-per-key natively, ordered by value bytes. That
matches the `Vec<EdgeId>` shape of `from_index` / `to_index` without
needing manual list management.

## Implementation plan (5 slices)

### Slice 1: Cargo dep + skeleton

```toml
# agent_core/Cargo.toml
redb = "2.2"  # latest stable as of 2026-05
bincode = "1.3"
```

New module: `agent_core/src/cognitive_dag/redb_store.rs` with empty
`RedbDagStore { db: redb::Database }` struct and `impl DagStore` stub
that returns `unimplemented!()` for every method. Compiles + lib tests
green; no behavior change.

### Slice 2: put_node + get_node (the simplest pair)

Implement node insert + lookup against the `NODES` table. Test
parity against `InMemoryDagStore`: insert N nodes into both, read
all N back, assert byte-identical Node values returned.

Add a "round-trip across instances" test: open store at /tmp path,
insert nodes, drop store, reopen at same path, read nodes back. This
is the durability proof that InMemory cannot give.

### Slice 3: put_edge + edges_from + edges_to + capability registry

Implement edge insert with CD-005 capability-bound verification
(reuse the `verify_edge_against_registered_caps` logic from
`InMemoryDagStore` — extract to a shared helper). Implement the
directional traversal methods against the multimap indices.

Test: every existing `cognitive_dag::storage::tests::*` test runs
against both backends via a parameterized test macro:
```rust
fn run_backend_tests<S: DagStore>(make: impl Fn() -> S) { /* ... */ }
#[test] fn in_memory() { run_backend_tests(InMemoryDagStore::new); }
#[test] fn redb() { run_backend_tests(|| RedbDagStore::open(tempfile())); }
```

### Slice 4: merkle_root + snapshot

Both must produce byte-identical output to `InMemoryDagStore` for
identical content (this is the canonical content-addressing
contract). The trick: redb's iteration order matches BTreeMap's
(both sort by key bytes), so a straightforward iterate-and-hash
should give the same result. Verify with a fixture test that inserts
the same content into both backends and asserts merkle_root +
snapshot bytes equality.

### Slice 5: dispatch wiring + opt-in flag

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

Total: ~19 new tests on top of the existing 132 cognitive_dag tests.

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

## Why this is `state: candidate`

The implementation is well-scoped but multi-hour. Per the canon
promotion protocol, it gets one explicit sign-off cycle before code
lands. The user's question for the next deliberation: **does the redb
backend land as a single unified slice, or as the 5 slices above
with a verification beat between each?** Either approach is
canonical; the 5-slice approach is safer for review.

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
backends; today only one exists. This brief scopes the second one.
With the 5-slice plan + ~19 new tests, the redb backend is a
1-2-day implementation pass that unblocks V2.1 Phase 8.H. Held for
sign-off.
