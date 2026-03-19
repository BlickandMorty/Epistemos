# Knowledge Core Implementation Plan

## Reality Check

This is not a greenfield architecture exercise.

Epistemos already has:

- a live Rust graph/render engine
- a live BTK note mutation/query path
- a live SwiftData + GraphStore + QueryRuntime path
- a staged `knowledge_core` path with:
  - shared-memory SPSC ring
  - rkyv diff envelopes
  - Cozo wrapper
  - Loro wrapper
  - parser scaffold
  - Swift shadow bridge

The correct plan is therefore:

1. harden the staged path
2. prove latency and correctness in shadow mode
3. cut over one surface at a time
4. keep rollback cheap until parity is proven

No serious plan should promise "100% perfect." The best defensible target is:

- explicit invariants
- measurable latency budgets
- exhaustive failure modes
- staged rollout gates
- immediate rollback paths

## Executive Goal

Replace the live BTK-driven note/query runtime with a Rust-first `knowledge_core`
only after the new path proves all of these:

1. It beats the live path on steady-state latency.
2. It does not regress correctness under adversarial mutations.
3. It does not require Swift heap copies in the transport hot path.
4. It can be disabled instantly without data loss.

## Non-Negotiable Invariants

### FFI

- Rust is the only writer of `head`.
- Swift is the only writer of `tail`.
- `head` and `tail` remain isolated on separate 128-byte cache lines.
- Every published slot is fully written before `head.store(..., Release)`.
- Swift reads `head` with `Acquire` before reading slot bytes.
- Oversized payloads never trigger implicit realloc or wrap tricks.
- Backpressure policy is explicit and observable.

### Storage and queries

- Every mutation produces a typed transaction-log entry.
- Watchers execute only when changed dependency patterns intersect.
- Initial subscription bootstrap may snapshot.
- Steady-state updates must be row deltas, not full result rebuilds.

### CRDT and ordering

- Loro owns hierarchy and move semantics.
- Fractional ordering is deterministic under concurrent inserts.
- Cycle-causing moves are rejected or deterministically resolved.
- Snapshots are versioned and replayable.

### Swift UI

- Background workers may drain ring frames.
- MainActor receives only coalesced domain diffs.
- At most one UI apply batch per frame per subscription family.
- No raw payload bytes are copied into `Data` on the staged path.

## Latency Budget

The phrase "no latency" is not real. The budget is.

Target steady-state budget for one visible subscription update:

- Rust transact + watcher invalidation: `<= 2.0 ms`
- Cozo delta query + diff build: `<= 2.0 ms`
- rkyv archive into ring slot: `<= 0.25 ms`
- Swift drain + decode summary + queue work: `<= 0.50 ms`
- MainActor apply batch: `<= 2.0 ms`
- Total backend-to-view-model budget: `<= 6.75 ms`

Hard ceiling for 60 Hz UI:

- `<= 16.6 ms` end-to-end worst acceptable frame

Stretch target for 120 Hz UI:

- `<= 8.3 ms` for visible deltas

If a path cannot be measured against these budgets, it is not ready.

## Architectural Decisions

### 1. Keep the migration parallel until the final cutover

This is mandatory. The live BTK path remains authoritative until the new path
passes parity and latency gates.

### 2. Keep the ring slot-based for now

The current slot ring is the right phase-1 choice.

Reasons:

- simpler correctness proof
- easier Swift slot math
- bounded payload rules
- clear backpressure semantics

Do not replace it with a byte ring unless profiling proves slot waste is the
dominant bottleneck.

### 3. Do not make Swift directly walk arbitrary archived graphs first

The architecture brief says "deserialize archived structs without copying."
That is a useful target, but the staged bridge should not jump straight to raw
Swift pointer-chasing for full row payloads.

Safer progression:

1. zero-copy transport
2. one-pass Rust validation
3. batched field exposure
4. only then consider direct Swift archive traversal for proven-hot shapes

Direct Swift traversal is phase-late optimization, not phase-1 architecture.

### 4. Loro should own hierarchy only

Use Loro for:

- parent/child structure
- move semantics
- sibling order keys
- snapshots/history

Keep block text, properties, tasks, links, and refs in fact tables.

### 5. Cozo should become the query engine before it becomes the only store

Short term:

- authoritative mutation state in Rust materialized structures + tx log
- Cozo for query execution
- explicit dependency extraction for watchers

Long term:

- persistent Cozo-backed store
- tx log retained for watcher invalidation and replay

## Zero-Copy Truth Table

### Acceptable in phase 1

- Rust archives directly into mapped ring slot
- Swift reads slot bytes in place
- Swift uses typed metadata accessors
- Swift materializes UI-owned values only at the final apply boundary

### Not acceptable

- `Vec<u8>` temp archive on producer hot path
- `Data` wrapping the ring payload
- JSON or `[String: Any]` bridges
- per-field FFI chatter for metadata
- whole-result rebuilds on unrelated datoms

### Required next optimization

The current staged gap is row decoding.

Current state:

- summary path improved
- full row payload path still re-validates per row

Next fix:

- add batched section/row accessors or a section view accessor
- validate once per payload section, not once per row

## Target Runtime Layout

```text
SwiftUI Views
  -> @Observable query models
  -> frame-coalesced apply
  -> KnowledgeCore shadow/live runtime
  -> mapped shared-memory ring

Rust knowledge_core
  -> mutation API
  -> tx log
  -> Loro hierarchy
  -> materialized fact tables
  -> Cozo query engine
  -> watcher invalidation
  -> diff archive
  -> SPSC ring publish
```

## Phase Plan

### Phase 0: Lock the baseline

Deliverables:

- commit current staged state
- store baseline commands/results in benchmark docs
- keep `knowledge-core` feature-flagged

Required commands:

- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml knowledge_core -- --nocapture`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`

Gate:

- no new runtime work before a clean checkpoint exists

### Phase 1: Finish the transport contract

Objectives:

- preserve zero-copy transport
- reduce FFI overhead
- make backpressure explicit

Implementation:

1. Keep existing layout assertions and ring tests.
2. Add a row-batch accessor for one payload section.
3. Add an explicit backpressure policy enum:
   - `fail`
   - `coalesce_latest`
   - `drop_nonvisible`
4. Add per-core counters:
   - published frames
   - dropped frames
   - coalesced frames
   - ring-full failures
5. Expose read-only stats over FFI.

Latency objective:

- metadata decode path stays under `6 us`
- row batch projection is at least `3x` faster than per-row FFI

Rollback:

- keep current row accessor API and layer the batch API additively

### Phase 2: Canonical parser

Objectives:

- stop pretending line parsing is event normalization
- build one canonical AST/fact stream

Implementation:

1. Define canonical parser output types:
   - block
   - task
   - property
   - inline link
   - tag
   - ref
2. Use `pulldown-cmark` events for Markdown.
3. Use `orgize` events for Org.
4. Normalize both into the same fact emitter.
5. Use `memchr`-style byte scanning only in lexical helper hot paths.

Requirements:

- zero regex in hot parsing loops
- reserve capacities for token vectors
- parser benchmarks on large fixtures

Gate:

- parser output parity against existing live note cases

### Phase 3: CRDT/hierarchy correctness

Objectives:

- make Loro the staged hierarchy owner
- keep BTK live until parity is proven

Implementation:

1. Define staged hierarchy API:
   - `insert_block`
   - `move_block`
   - `delete_block`
   - `snapshot`
   - `checkout`
2. Keep fractional ordering separate and typed.
3. Add adversarial tests:
   - repeated midpoint inserts
   - equal-position multi-peer inserts
   - cycle attempts
   - reorder storms
   - deep snapshot/restore

Gate:

- ordering must remain deterministic across peers
- cycle-causing moves must never corrupt the tree

### Phase 4: Persistent Cozo-backed fact core

Objectives:

- stop rebuilding an in-memory Cozo instance per query
- make query latency meaningful

Implementation:

1. Replace ephemeral `DbInstance::new("mem", "", "")` per query.
2. Introduce one long-lived database handle per `KnowledgeCore`.
3. Choose one storage backend intentionally:
   - SQLite first for local-first simplicity
   - RocksDB only if measured write/read patterns justify it
4. Define explicit schema:
   - `block`
   - `task`
   - `property`
   - `link`
   - `tag`
   - `ref`
   - `block_order`
   - `page`
5. Use stable numeric ids internally where possible.
6. Keep strings at the boundary, not as hot-path join keys where avoidable.

Gate:

- no fresh full relation import on every query
- subscription query latency must scale sublinearly with total graph size for page-local mutations

### Phase 5: Watcher engine

Objectives:

- make watcher invalidation cheap and typed

Implementation:

1. Register subscriptions with explicit dependency keys.
2. Record changed datoms per transaction.
3. Match subscriptions only when dependency keys intersect.
4. Re-run only the relevant delta query.
5. Diff against prior materialized rows.
6. Serialize typed deltas to rkyv envelope.

Required subscription families:

- outline
- tasks
- properties
- links

Gate:

- irrelevant block text changes must not fire unrelated task/property/link watchers

### Phase 6: Swift shadow runtime with real model apply

Objectives:

- graduate from counters-only shadow mode to real view-model shadow state

Implementation:

1. Keep polling/drain off the MainActor.
2. Drain summary metadata first.
3. Skip row decoding for non-visible subscriptions where summary is enough.
4. Decode row batches on a background actor.
5. Coalesce to one apply batch per frame window.
6. Update `@Observable` models on MainActor only.

Required model policy:

- dictionary/set keyed by stable ids
- merge in place when possible
- no whole-array rebuild for small diffs

Gate:

- no unbounded task spawning
- one visible apply batch per frame window

### Phase 7: Shadow parity harness

Objectives:

- compare BTK/live results against staged results before cutover

Implementation:

1. Mirror live mutations into staged `knowledge-core`.
2. For each subscription family, compare:
   - row ids
   - ordering
   - counts
   - visible text/task/property values
3. Log parity mismatches with reproducible fixtures.
4. Add golden fixtures for:
   - markdown notes
   - org notes
   - mixed task/property/link pages
   - move-heavy outlines

Gate:

- parity must pass on every golden fixture before any live cutover

### Phase 8: Incremental cutover

Cut over in this order:

1. outline shadow apply for one non-critical internal screen
2. tasks subscriptions
3. properties
4. links
5. note mutation source of truth

Never cut over hierarchy mutation and query consumption in the same step.

Required controls:

- feature flag per subscription family
- runtime rollback switch
- metrics attached to both paths during comparison

### Phase 9: Remove old path only after proof

Removal criteria:

- staged path is default for at least one release cycle
- no unresolved parity mismatches
- latency beats BTK path on representative workloads
- test suite includes ring, watcher, parser, CRDT, ABI, and Swift lifecycle coverage

Until then, BTK stays.

## Performance Worklist

### Immediate

- row-batch payload accessor
- persistent Cozo handle
- query result ids instead of string-heavy keys where possible
- summary-only path for hidden subscriptions

### Next

- section-level archived row views
- string interning or numeric id mapping for hot joins
- preallocated diff vectors
- parser byte-scan optimizations

### Late only if measured

- direct Swift archive traversal for full row payloads
- byte ring instead of slot ring
- deeper columnar storage changes

## Safety and ABI Plan

Required:

- every `unsafe` block has a `SAFETY:` justification
- FFI layout tests for every exported struct
- cbindgen header verification
- malformed payload fuzzing
- ring concurrency stress tests
- fractional index property tests
- CRDT snapshot/restore property tests

Do not claim ABI stability until the header and Rust layouts are checked in CI.

## Benchmarks Required Before Cutover

Rust:

- ring write throughput/latency
- payload summary decode
- row-batch decode
- watcher invalidation cost
- Cozo transact/query latency
- parser throughput
- CRDT reorder storm cost

Swift:

- drain loop cost per frame
- background decode cost
- MainActor apply cost
- dropped/coalesced frame counts under synthetic churn

## Go / No-Go Rule

Current decision: `NO-GO for replacement`, `GO for continued shadow hardening`.

The only responsible path is:

- keep live BTK runtime intact
- keep `knowledge-core` behind feature flags
- use the staged bridge to prove the architecture with numbers
- cut over only when parity and latency are both demonstrated

## Recommended Immediate Next Steps

1. Commit the current working tree as a checkpoint.
2. Implement the staged row-batch payload accessor.
3. Replace ephemeral Cozo-per-query with a persistent staged database handle.
4. Add shadow parity fixtures for outline/task/property pages.
5. Fix unrelated Swift test compile blockers so targeted bridge tests can run under `xcodebuild test`.

