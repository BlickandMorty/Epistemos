# Top Latency Wins

## 1. Live Reactive Query Lag Collapsed

Files:
- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Engine/ReactiveQuery.swift`

Change:
- removed the extra `GraphStore` debounce
- reduced `ReactiveQuery` debounce from `100ms` to `35ms`

Why it matters:
- this directly affects the live query/search UI
- the old path forced a roughly `150ms` minimum wait after graph mutation
- the new path reduces that floor to roughly `35ms`

Verdict:
- highest-ROI live-path win in this pass

## 2. Staged Knowledge-Core Watcher Incremental Refresh

Files:
- `graph-engine/src/knowledge_core/store.rs`

Measured result:
- `167.49x` faster than full rerun in the benchmark harness

Why it matters:
- proves that dependency-aware invalidation is the right deep systems lever
- stronger than transport-only optimization

Verdict:
- profound architecture, but still staged

## 3. Staged Summary Accessor Batching

Files:
- `graph-engine/src/lib.rs`

Measured result:
- `6.04x` faster summary decode

Why it matters:
- validates batched accessors before bigger transport changes

Verdict:
- medium-complexity, high-ROI bridge improvement

## 4. Staged Batched Row Accessor

Files:
- `graph-engine/src/lib.rs`

Measured result:
- `3.18x` faster than scalar row access

Why it matters:
- reduces row-by-row ABI round-trips

Verdict:
- useful bridge tuning

## 5. GraphBuilder Bulk Body Reads Moved to Mapped Path

Files:
- `Epistemos/Graph/GraphBuilder.swift`

Change:
- full page scans for block references now use `loadBody(mapped: true)`

Why it matters:
- bulk structural rebuilds no longer force the plain `loadBody()` path

Verdict:
- low-risk bulk-read improvement

## 6. Daily Brief Context Now Loads Each Note Body Once

Files:
- `Epistemos/State/DailyBriefState.swift`

Change:
- recent note selection now uses mapped reads
- each included note body is loaded once and reused for snippet generation

Why it matters:
- this is a user-visible context-building path
- it cuts duplicate body hydration in a hot landing/palette feature

Verdict:
- low-risk live-path improvement

## 7. Backlinks Scan Now Uses Mapped Reads

Files:
- `Epistemos/Views/Notes/NoteBacklinksPanel.swift`

Change:
- vault-wide backlink scanning now uses `loadBody(mapped: true)`

Why it matters:
- whole-vault body scans should not use the more expensive default read path

Verdict:
- simple bulk-read win

## 8. BTK Property Watcher Incremental Refresh

Files:
- `graph-engine/src/block_kernel/query_kernel.rs`

Measured result:
- `1.24x` faster than full rerun

Why it matters:
- confirms the live path benefits from scoped refresh too
- also shows there is still surrounding overhead to remove

Verdict:
- real but modest

## 9. Query Invalidations Are Now Single-Window, Not Stacked

Files:
- `Epistemos/Engine/ReactiveQuery.swift`

Why it matters:
- coalescing still exists, but it no longer stacks a second coalescing layer on top of upstream changes

Verdict:
- simple fix, strong UX payoff

## 10. FFI Scope Was Narrowed To What Is Actually Hot

Files:
- `FFI_OPPORTUNITY_MATRIX.md`
- `WHOLE_APP_PERF_MAP.md`

Why it matters:
- prevents wasted time on cold FFI boundaries
- keeps search, note IO, and query invalidation at the top of the queue

Verdict:
- judgment win, not a code-speed win

## Biggest Remaining Gaps

1. Swift-side BTK payload materialization is still allocation-heavy
2. `ReactiveQuery` still uses broad notification invalidation
3. repeated note body hydration still exists in many non-editor surfaces
4. the staged parser is still too slow to justify migration pressure
5. targeted Swift tests still cannot run until unrelated Swift 6 test debt is fixed
