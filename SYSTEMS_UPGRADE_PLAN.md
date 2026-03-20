# Systems Upgrade Plan

## P0 — Highest ROI, Lowest Risk

### 1. Collapse the Live Query Invalidation Stack

Class:
- simpler fix

Status:
- implemented in this pass

Change:
- remove the extra `GraphStore` debounce
- keep one coalescing layer in `ReactiveQuery`
- tighten the debounce budget to a small UI-safe window

Why this wins:
- immediate user-visible latency improvement
- no architecture migration
- preserves the current query stack

### 2. Reduce Repeated Note Body Hydration in Bulk/Background Work

Class:
- simpler fix

Status:
- partially implemented in this pass

Change:
- use mapped/bulk-friendly read paths where code is already scanning many note bodies
- stop using `loadBody()` in bulk loops when a mapped or cached path already exists

Implemented so far:
- `GraphBuilder.build(context:)` block-ref scan
- `DailyBriefState.buildBriefPrompt(...)` recent note body collection
- `NoteBacklinksPopover.scanBacklinks()`

Why this wins:
- reduces string/disk churn
- low risk because the API already exists

### 3. Keep GRDB/FTS5 as the Text Search Backbone

Class:
- do nothing architecturally, only tune call sites

Change:
- do not try to replace search with graph-runtime or shared-memory transport
- push note/body search toward `SearchIndexService` first

Why this wins:
- correct tool for the job
- avoids cargo-culting the knowledge-core paper into the wrong subsystem

### 4. Trim BTK Payload Materialization Where Views Need It

Class:
- dataflow fix

Change:
- add or use batched row accessors
- avoid re-decoding whole payloads when the UI only needs summary counts or selected fields

Why this wins:
- meaningful bridge savings without forcing a full transport rewrite

## P1 — High ROI, Moderate Structural Change

### 1. Replace Broad ReactiveQuery Invalidation With Dependency Keys

Class:
- dataflow fix

Change:
- extract simple dependency keys from query plans
- only rerun reactive queries that intersect changed graph/search domains

Why this wins:
- avoids full recompute churn
- aligns the live path more closely with the staged watcher architecture

### 2. Move More Query Filtering Off the Main Actor

Class:
- dataflow fix

Change:
- keep UI state on `@MainActor`
- move pure filtering/projection work off-main where isolation allows

Why this wins:
- protects render responsiveness

### 3. Build Cached Projections for Common Note Surfaces

Class:
- storage/query fix

Change:
- sidebar, backlinks, daily brief, and note-context surfaces should use cached snippets/projections instead of repeatedly reading full bodies

Why this wins:
- body text is large and expensive to hydrate repeatedly

## P2 — Advanced Systems Upgrades Only If Benchmarks Justify Them

### 1. Promote Knowledge-Core Watchers Only After UI Parity

Class:
- systems / low-level

Change:
- keep `knowledge-core` behind flag/shadow mode until:
  - typed diff application is wired into real UI state
  - parity exists with current BTK/query behavior
  - benchmarks show end-to-end wins

Why this wins:
- avoids replacing the stable runtime with better transport but worse product behavior

### 2. Replace Newline BTK Helper Results With Typed Buffers

Class:
- systems / low-level

Change:
- only if one-shot BTK helper queries become hot enough

Why this wins:
- cheaper than jumping straight to shared memory

### 3. Incremental Structural Graph Projection

Class:
- storage/query fix

Change:
- stop using whole-body structural rebuilds as the primary refresh strategy

Why this wins:
- scales much better on large vaults

## P3 — Speculative / Optional

### 1. End-to-End Shared-Memory Diff Consumption in Swift UI

Class:
- systems / low-level

Condition:
- only if the production UI truly consumes high-frequency structured diffs
- only if batching and typed ABI accessors are not enough

### 2. Authoritative Cozo/Loro Runtime Cutover

Class:
- storage/query + systems

Condition:
- only after feature parity, persistence semantics, and migration safety are proven

### 3. Wider Use of Event-Normalized Parsing

Class:
- dataflow fix

Condition:
- only if live ingest/index/update paths bottleneck on current string/line parsing

## What To Avoid

1. Replacing GRDB/FTS5 with a custom Rust search bridge before proving a need
2. Spreading shared-memory/rkyv transport into cold or tiny FFI calls
3. Replacing the stable BTK/SwiftData path with `knowledge-core` before UI parity
4. Building a fully custom invalidation framework for query/search before a scoped dependency-key pass
