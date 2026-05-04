# 2026-03-19-abi-decision-memo


> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).


## CURRENT ABI / MATERIALIZATION MAP

- Live BTK bytes originate in Rust as archived `SubscriptionPayload` buffers returned by `graph_engine_btk_take_subscription_update` and `graph_engine_btk_snapshot_subscription`.
- Those bytes cross the ABI as `GraphEngineByteBuffer` in [`/Users/jojo/Epistemos/graph-engine/src/lib.rs`](/Users/jojo/Epistemos/graph-engine/src/lib.rs) and are consumed in [`/Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift`](/Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift).
- Live Swift allocations currently occur in three places:
  - `Data(bytesNoCopy:)` wrapper allocation for the Rust-owned buffer
  - per-row FFI calls through `graph_engine_btk_payload_row`
  - eager `String(decoding:)` for every string field in every returned row
- Live strings materialize in `GraphEngine.decode(slice:)`.
- Live arrays materialize in `decodeBTKRows`, then again into `rowMap.values.sorted`.
- Staged knowledge-core bytes originate in Rust as archived `QueryDiffEnvelope` frames written directly into the shared-memory ring by `SharedRingBuffer::write_archived_frame`.
- Staged bytes cross the ABI as a mapped ring slot plus getter APIs in [`/Users/jojo/Epistemos/graph-engine/src/lib.rs`](/Users/jojo/Epistemos/graph-engine/src/lib.rs) and are consumed in [`/Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift`](/Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift).
- Staged Swift allocations currently occur in:
  - `KnowledgeCoreRowSnapshot` array creation for each added/updated/removed section
  - eager `String(decoding:)` for every string field in every row
  - summary array replacement in `KnowledgeCoreShadowRuntime`
- Hot surfaces:
  - live BTK outline/property/link subscriptions in `GraphEngine.swift`
  - staged knowledge-core decode/apply in `KnowledgeCoreBridge.swift`
- Cold surfaces:
  - ring metadata layout helpers
  - one-shot knowledge-core mutation APIs
  - graph control/render command FFI

## DOMINANT COST RANKING

1. Live BTK per-row Swift string materialization and per-row FFI call overhead in `GraphEngine.decodeBTKRows`.
2. Staged knowledge-core eager row snapshot + string materialization in `KnowledgeCoreBridge.decodeRows` / `decodeRowSnapshot`.
3. Live BTK `Data(bytesNoCopy:)` ownership wrapper around Rust buffers in `GraphEngine.takeBTKBuffer`.
4. Identity-string churn in live BTK row application (`BTKSubscriptionRow.identity`, `rowMap`, full resort).
5. Staged shadow runtime measuring counters instead of a real apply/projection path.

## ABI DESIGN OPTIONS RANKED FOR THIS CODEBASE

### 1. Current C ABI + better batched typed accessors + bounded-lifetime payload readers + projection/string caches
- Attacks:
  - live BTK per-row FFI overhead
  - repeated UTF-8 decode/allocation on hot rows
  - `Data(bytesNoCopy:)` ownership ambiguity
- Integration risk: low
- Ownership model:
  - Rust still owns BTK buffers and frees them explicitly
  - Swift uses a short-lived payload lease wrapper
  - staged ring slots remain borrowed only inside drain/apply scope
- Swift ergonomics: good
- Debugger cost: low
- Migration cost: low
- Justified here: yes

### 2. Borrowed UTF-8 spans + Swift projection cache over current payloads
- Attacks:
  - repeated string decode/allocation
  - object replacement churn
- Integration risk: medium
- Ownership model:
  - safe only with strict lexical-scope wrappers
  - no proof in this repo that `UTF8Span` / `~Escapable` is ready for production use here
- Swift ergonomics: mixed
- Debugger cost: medium
- Migration cost: medium
- Justified here: partially, but only with conservative wrappers and not as the first step

### 3. Versioned typed diff ABI with row-wise flat payload sections
- Attacks:
  - staged string decode churn
  - getter overhead
  - future projection cache reuse
- Integration risk: medium-high
- Ownership model:
  - strong if payload header + offsets + release boundaries are correct
- Swift ergonomics: decent
- Debugger cost: medium
- Migration cost: medium-high
- Justified here: not yet; current archived row-wise diffs plus additive accessors are still good enough for this stage

### 4. Explicit snapshot/apply contract with stable row IDs and changed-field masks
- Attacks:
  - avoid replacing long-lived Swift state
  - reduce unchanged field churn
- Integration risk: medium
- Ownership model: strong
- Swift ergonomics: good
- Debugger cost: medium
- Migration cost: medium
- Justified here: yes, but on top of option 1, not instead of it

### 5. Versioned typed diff ABI with columnar sections
- Attacks:
  - analytical scan throughput
- Integration risk: high
- Ownership model: fine
- Swift ergonomics: poor for the current row-driven UI
- Debugger cost: high
- Migration cost: high
- Justified here: no

### 6. String intern table / symbol IDs as a new transport-wide protocol
- Attacks:
  - repeated string bytes across rows
- Integration risk: medium-high
- Ownership model: fine
- Swift ergonomics: acceptable
- Debugger cost: medium
- Migration cost: medium-high
- Justified here: only if the simpler cache path fails; not first

### 7. Hybrid new payload protocol replacing archived staged transport now
- Attacks:
  - staged decode cost
  - future UI apply cost
- Integration risk: high
- Ownership model: can be strong, but this is more than the repo needs right now
- Swift ergonomics: acceptable
- Debugger cost: medium
- Migration cost: high
- Justified here: no

## SINGLE RECOMMENDED DESIGN

- Winner:
  - additive batched row accessors where missing
  - bounded-lifetime Swift payload leases instead of `Data(bytesNoCopy:)`
  - shared Swift UTF-8 string cache
  - stable struct row keys / projection-style apply

- Why it wins here:
  - it directly attacks the live production hot path first
  - it reuses the current row-wise diff shape that already matches the UI
  - it keeps staged knowledge-core parallel
  - it avoids building a second payload protocol before the current one is exhausted
  - it preserves rollback: old getters and old decode paths can remain available

- What it does not solve:
  - it does not remove all Swift string ownership costs
  - it does not make knowledge-core production-ready
  - it does not eliminate full row sorting in the live BTK consumer
  - it does not create a general long-lived borrowed-string model in Swift

- Deferred:
  - any new flat staged payload protocol
  - any transport-wide intern table format
  - any knowledge-core promotion
  - any Rust-owned long-lived string views in Swift

## IMPLEMENTATION PLAN

1. Add failing tests for:
  - live BTK batch row decoding parity
  - safe payload ownership without `Data(bytesNoCopy:)`
  - staged apply path reusing cached strings/projections on repeat updates
2. Add additive live BTK batch row accessor(s) in Rust + header.
3. Replace live BTK `Data(bytesNoCopy:)` with an owned payload lease in Swift.
4. Add a reusable Swift UTF-8 string cache and stable row-key structs.
5. Move staged shadow apply onto a real projection cache path while keeping `drainPayloads()` intact for compatibility.
6. Add targeted telemetry and microbench coverage.
7. Validate before/after numbers.
8. Keep rollback trivial by preserving legacy staged/live entry points.

## ROLLBACK PLAN

- Keep existing scalar row getters.
- Keep staged `drainPayloads()` snapshot API.
- Gate new projection/apply path behind internal call-site selection only.
- Revert new batch accessor usage in Swift without touching Rust store/query logic.
