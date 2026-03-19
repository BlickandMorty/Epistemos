# Cozo Audit

## Verdict

`PARTIAL`, leaning `FAIL` for the design brief.

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
- Cozo is only used during query execution

Live BTK:

- source of truth is `BlockTree` + `OpLog`
- Cozo is only used as a query helper over re-materialized rows

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

1. Every staged query rebuilds a fresh in-memory Cozo DB:
   - `DbInstance::new("mem", "", "")`
   - relation creation script
   - full row import
   - query script execution

2. Every live BTK reactive query does the same pattern:
   - full row materialization
   - fresh in-memory Cozo DB
   - query

3. String-heavy row materialization is pervasive:
   - cloned `String` values for page ids, block ids, content, property keys, values

4. Query scripts are rebuilt dynamically in some cases:
   - property and link filters concatenate strings in staged store

## Error propagation

- `StoreError` exists inside Rust.
- `graph_engine_kc_*` FFI mutators collapse all failures to `0`.
- Swift cannot differentiate query/store failure from backpressure or parse failure.

## Conclusion

Cozo is present, but it is being used as an embedded query engine over separately materialized in-memory facts. That is a legitimate staging technique. It is not the architecture described in the brief.
