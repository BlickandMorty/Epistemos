# Cozo Audit

## Verdict

`PARTIAL`

Cozo is embedded and used in both the staged knowledge-core store and the live BTK query kernel. It is not the authoritative transactional knowledge core in the current runtime.

## What is real

- `cozo` is a real dependency in [Cargo.toml](/Users/jojo/Epistemos/graph-engine/Cargo.toml).
- The staged store uses Cozo in:
  - [store.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/store.rs)
- The live BTK query kernel also uses Cozo in:
  - [query_kernel.rs](/Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs)

## What is not real

- Cozo is not the source of truth.
- There is no persisted Cozo backend.
- There is no MVCC-backed app read/write lifecycle wired through Cozo.
- There is no vector or graph-algorithm feature usage in the staged runtime.

## Transaction model

Staged knowledge-core:

- source of truth is still Rust `BTreeMap`s in `DatalogStore`
- “transactions” are Rust methods like:
  - `replace_page`
  - `upsert_block`
  - `move_block`
  - `delete_block`
- `tx_id` is incremented manually
- Cozo now stays resident inside `DatalogStore`
- page/block/task/property/link mutations are mirrored incrementally into the resident Cozo relations
- full query execution still uses Cozo, but it no longer recreates a fresh DB or re-imports all rows on each refresh

Live BTK:

- source of truth is `BlockTree` + `OpLog`
- Cozo is still only used as a query helper over re-materialized rows
- outline/property watcher refresh is now incremental and skips full Cozo reruns for those matched updates
- linked-reference subscriptions still rerun full Cozo queries

## Schema coverage

Implemented relations:

- blocks
- tasks
- properties
- links

Missing or incomplete compared with the brief:

- pages as first-class relation
- tags as first-class relation
- refs/backlinks beyond generic links
- stable ordering metadata beyond `order_key` on block rows
- persistent snapshot/version storage in Cozo

## Hot-path findings

1. Staged knowledge-core no longer rebuilds Cozo per query:
   - one resident in-memory `DbInstance`
   - staged mutations mirror into Cozo relations with `import_relations(...)`
   - watcher refresh no longer pays relation creation/import cost on matched updates

2. Live BTK linked-reference queries still rebuild a fresh in-memory Cozo DB:
   - full row materialization
   - fresh in-memory Cozo DB
   - query

3. Live BTK outline/property initial subscribe and snapshot paths still rebuild Cozo:
   - initial subscription snapshots still materialize into fresh Cozo relations
   - historical snapshots still execute full queries over replayed pages

4. String-heavy row materialization is pervasive:
   - cloned `String` values for page ids, block ids, content, property keys, values

5. Query scripts are rebuilt dynamically in some cases:
   - property and link filters concatenate strings in staged store

## Error propagation

- `StoreError` exists inside Rust.
- `graph_engine_kc_*` FFI mutators collapse all failures to `0`.
- Swift cannot differentiate query/store failure from backpressure or parse failure.

## Conclusion

Cozo is now materially more honest in the staged path: one resident DB, relation-level incremental mirroring, and no per-refresh database rebuild. It is still not the authoritative persisted transactional core from the brief, and the live BTK path still relies on partial Cozo helper usage rather than a full Cozo-owned runtime.
