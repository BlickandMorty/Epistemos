# CRDT Audit

## Verdict

`PARTIAL`

Loro is really present in staged knowledge-core. It is not the live outline runtime.

## What was verified

- staged wrapper exists in [crdt.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/crdt.rs)
- insert/move/delete call into `LoroTree`
- snapshots export and restore
- cycle-causing move is rejected in tests
- subtree deletion now prunes descendant metadata in tests

## Fix landed during audit

Snapshot restore previously returned a structurally restored Loro doc with empty side maps, which made subsequent block-id-based operations unreliable.

Fix:

- persist `block_id` and `order_key` into Loro node metadata
- rebuild `node_ids`, `parents`, and `order_keys` from the tree after restore and delete

Tests added:

- `restored_snapshot_retains_block_identity_and_allows_moves`
- `deleting_parent_prunes_descendant_metadata`
- `cycle_causing_move_is_rejected`

## Remaining gaps

- no remote update import/export API in the wrapper
- no explicit frontier/checkout time-travel API exposure
- no multi-peer convergence tests on the staged wrapper
- no metadata growth management or GC policy exposed

## Conclusion

The staged wrapper is now materially safer, but it is still a wrapper around Loro primitives, not a fully audited replicated outline runtime.
