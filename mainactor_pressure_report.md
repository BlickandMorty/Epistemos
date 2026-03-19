# MainActor Pressure Report

## Live path

- `GraphStore` posts a debounced notification after 50 ms
- `ReactiveQuery` adds another 100 ms debounce
- reevaluation and result emission occur on `@MainActor`

Implication:

- low-frequency protection exists
- fine-grained low-latency updates do not

## Staged shadow path

- polling loop sleeps for 16 ms by default
- at most one `applyBatch(...)` call happens per poll iteration

Implication:

- staged path is frame-batched in shape
- real view invalidation cost is still unknown because only counters are updated

## Remaining risk

- if full payload decoding is moved onto the main actor later, this path will regress immediately

## Recommendation

Keep heavy decode/materialization off-main and only deliver already-coalesced diffs to UI-facing state.
