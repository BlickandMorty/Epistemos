# Query Hot Path Findings

## Severity-ordered findings

1. Fresh Cozo DB per query in staged knowledge-core.
   Evidence: [store.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/store.rs)
   Impact: full relation import and query setup on every watcher refresh.

2. Fresh Cozo DB per query in live BTK subscriptions.
   Evidence: [query_kernel.rs](/Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs)
   Impact: reactive diff generation still pays full query rebuild cost.

3. Live query UI bypasses typed Rust diffs entirely.
   Evidence: [ReactiveQuery.swift](/Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift), [QueryRuntime.swift](/Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift)
   Impact: coarse invalidation + full Swift re-execution.

4. Staged Swift consumer re-validates the archive on every helper call.
   Evidence: [KnowledgeCoreBridge.swift](/Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift), [lib.rs](/Users/jojo/Epistemos/graph-engine/src/lib.rs)
   Impact: per-row FFI and validation overhead on large diffs.

5. String cloning dominates row materialization.
   Evidence: both `store.rs` and `query_kernel.rs`
   Impact: hot-path allocation churn scales with result size.

## Bottom line

The staged watcher path is better-filtered than the live UI path, but neither path currently qualifies as a truly incremental low-allocation query core.
