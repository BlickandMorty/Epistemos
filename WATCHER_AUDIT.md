# Watcher Audit

## Verdict

`PARTIAL`, but materially better than the pre-fix state.

Dependency filtering exists. Incremental row refresh now exists for the simple staged subscriptions and for the live BTK outline/property subscriptions. True Cozo-side delta-query execution still does not.

## Staged knowledge-core

Evidence:

- [store.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/store.rs)

What works:

- `ChangedPatterns` tracks pages, relations, property keys, block ids.
- `SubscriptionSpec::matches(...)` filters irrelevant commits.
- `diff_rows(...)` emits typed row-level `added/updated/removed` envelopes.
- matched staged subscriptions now update only the touched row identities instead of rerunning the full staged query
- `matching_updates_refresh_outline_without_full_query_rerun` proves the staged outline watcher avoids a full rerun on matched updates
- benchmark: `knowledge_core_outline_watcher` measured `69896 ns/tx` incremental vs `6445119 ns/tx` full rerun, about `92.21x` faster

What does not match the brief:

- it still is not a true Cozo delta query over transactional datoms
- initial subscribe still materializes full result sets

## Live BTK

Evidence:

- [query_kernel.rs](/Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs)

What works:

- `ChangedFacts` + `QueryDependencies` avoid some irrelevant reruns
- row-level diffs are generated
- matched outline/property subscriptions now refresh from touched facts without rerunning full Cozo queries
- `matching_property_updates_do_not_reexecute_full_query` proves the live BTK property watcher avoids a full rerun on matched updates
- benchmark: `btk_property_watcher` measured `6828786 ns/tx` incremental vs `12790724 ns/tx` full rerun, about `1.87x` faster

What does not match the brief:

- linked-reference subscriptions still rerun full queries over re-materialized pages
- diffs are archived into `Vec<u8>` payloads

## Live Swift query UI

Evidence:

- [ReactiveQuery.swift](/Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift)
- [GraphStore.swift](/Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift)

Status:

- live UI is still driven by notification invalidation
- it is not driven by typed watcher diffs

## Conclusion

The current repo is no longer “filtering only.” It now has selective incremental watcher maintenance for the simplest subscription classes. The remaining gap is that the engine still does not run true Cozo-side delta queries, and the live Swift UI still does not consume these typed Rust watcher diffs as its primary dataflow.
