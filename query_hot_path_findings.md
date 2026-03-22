# Query Hot Path Findings

## Severity-ordered findings

1. Fresh Cozo DB per query is removed from staged knowledge-core watcher refresh.
   Evidence: [store.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/store.rs)
   Impact: matched staged subscriptions now avoid relation creation/import and refresh only touched rows.

2. Fresh Cozo DB per query still exists in live BTK linked-reference subscriptions.
   Evidence: [query_kernel.rs](/Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs)
   Impact: reactive diff generation still pays full query rebuild cost for graph traversals.

3. Live query UI bypasses typed Rust diffs entirely.
   Evidence: [ReactiveQuery.swift](/Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift), [QueryRuntime.swift](/Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift)
   Impact: coarse invalidation + full Swift re-execution.

4. Staged Swift consumer still materializes owned Swift rows and strings.
   Evidence: [KnowledgeCoreBridge.swift](/Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift), [lib.rs](/Users/jojo/Epistemos/graph-engine/src/lib.rs)
   Impact: transport got cheaper, but UI-safe snapshots still allocate with result size.

5. String cloning still dominates row materialization.
   Evidence: both [store.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/store.rs) and [query_kernel.rs](/Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs)
   Impact: hot-path allocation churn scales with result size.

## Bottom line

The staged watcher path now has real incremental refresh, and the live BTK property/outline watcher path has a smaller but real incremental win. The remaining hot-path tax is in the live Swift invalidation model, linked-reference full reruns, and unavoidable row/string materialization at the Rust-to-Swift boundary.
