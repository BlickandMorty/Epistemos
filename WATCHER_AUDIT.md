# Watcher Audit

## Verdict

`PARTIAL`

Dependency filtering exists. True delta-query execution does not.

## Staged knowledge-core

Evidence:

- [store.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/store.rs)

What works:

- `ChangedPatterns` tracks pages, relations, property keys, block ids.
- `SubscriptionSpec::matches(...)` filters irrelevant commits.
- `diff_rows(...)` emits typed row-level `added/updated/removed` envelopes.

What does not match the brief:

- on a matching commit, the store reruns the full query for that subscription
- it does not run a true delta query over just the changed datoms

## Live BTK

Evidence:

- [query_kernel.rs](/Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs)

What works:

- `ChangedFacts` + `QueryDependencies` avoid some irrelevant reruns
- row-level diffs are generated

What does not match the brief:

- matching subscriptions rerun full queries over re-materialized pages
- diffs are archived into `Vec<u8>` payloads

## Live Swift query UI

Evidence:

- [ReactiveQuery.swift](/Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift)
- [GraphStore.swift](/Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift)

Status:

- live UI is still driven by notification invalidation
- it is not driven by typed watcher diffs

## Conclusion

The current repo has watcher filtering, not incremental view maintenance. The distinction matters: irrelevant transactions can be skipped, but relevant transactions still pay full query rerun cost.
