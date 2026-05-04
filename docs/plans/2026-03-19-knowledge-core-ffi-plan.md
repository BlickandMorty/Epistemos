# Knowledge Core Zero-Copy FFI Plan

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Goal

Add a parallel Rust "knowledge core" beside the current BTK path, then replace BTK only after the new path proves three things:

1. It never blocks the render loop.
2. It emits diffs instead of snapshots in steady state.
3. Swift reads archived payloads in-place from shared memory without `Data` copies.

## Why this must be parallel first

The current app already has a stable graph engine, a BTK op log, a Swift wrapper, and a render loop tied to `CVDisplayLink`. Replacing that in one jump is reckless. The safe migration is:

1. Build the new runtime in `graph-engine/src/knowledge_core/`.
2. Expose a separate FFI surface.
3. Run it beside BTK for shadow validation.
4. Flip Swift consumers one path at a time.
5. Remove BTK only after parity tests pass.

## Non-Negotiable Invariants

### FFI and memory

- Rust is the only writer of `head`.
- Swift is the only writer of `tail`.
- `head` and `tail` stay on separate 128-byte cache lines.
- Archived payload bytes live entirely inside one ring slot.
- Swift never copies payload bytes into `Data` in the hot path.
- Swift never mutates payload bytes.
- Ring slots are fixed-size. Oversized payloads are a producer error, not an implicit realloc.

### Query runtime

- Transactions are append-only at the log boundary.
- Watchers are evaluated only when changed relation patterns intersect the subscription dependencies.
- UI-facing diffs are row deltas, not full query result rebuilds, except for initial subscription bootstrap and explicit snapshot requests.

### Swift UI

- Background tasks can poll the ring.
- Only the coalesced diff application touches `@Observable` models.
- Main-thread application is throttled to the active display cadence.
- The graph render loop and the query diff loop stay independent.

## Runtime Layout

```text
Swift UI
  -> background subscription pump
  -> mapped ring buffer pointer
  -> archived diff view
  -> frame-throttled model apply

Rust knowledge core
  -> parser normalizer
  -> Loro movable tree
  -> materialized fact tables
  -> Cozo query execution
  -> watcher diff engine
  -> rkyv archive
  -> SPSC shared-memory ring
```

## Rust Modules Added

- `graph-engine/src/knowledge_core/ring.rs`
  128-byte-padded SPSC shared-memory slot ring.
- `graph-engine/src/knowledge_core/archived.rs`
  rkyv-archived diff protocol types.
- `graph-engine/src/knowledge_core/store.rs`
  Cozo-backed query wrapper, subscription registry, delta emission.
- `graph-engine/src/knowledge_core/crdt.rs`
  Loro movable-tree façade with fractional order keys.
- `graph-engine/src/knowledge_core/parser.rs`
  Markdown/Org normalization into common facts.
- `graph-engine/src/knowledge_core/mod.rs`
  orchestration and FFI-facing `KnowledgeCore`.

## Deep Deliberation: latency-critical decisions

### 1. Slot ring over byte ring for phase 1

The user goal is zero-copy FFI, not "zero copies anywhere in the universe." The expensive copy today is Rust heap -> Swift heap. The slot ring removes that copy immediately.

Why slot ring first:

- simpler correctness proof
- no wrap marker protocol
- deterministic per-message bounds
- straightforward Swift pointer math
- easy backpressure accounting with `head - tail`

Why not byte ring first:

- harder wrap logic
- harder consumer parsing
- more failure modes under partial frame writes

When to upgrade to byte ring:

- only after profiling shows slot waste is material
- only if watcher diffs regularly exceed slot size

### 2. Cozo as query engine, not yet as the only fact owner

The safe design is:

- authoritative mutation path: Rust materialized fact tables + transaction log
- query execution path: Cozo
- watcher invalidation path: explicit dependency patterns

This avoids betting the whole runtime on dynamic Cozo query introspection before we have parity tests.

Production target after parity:

- persist facts directly in Cozo-backed storage
- keep the explicit dependency extraction layer
- keep the transaction log even after storage migration

### 3. Loro owns hierarchy, not whole block state

Hierarchy and move semantics are the hard CRDT problem. Loro is good at that. Property bags, links, and task metadata do not need to be shoved wholesale into the tree container to get the benefits.

Recommended long-term split:

- Loro tree: parent/child ordering and replicated move semantics
- fact tables: block text, task state, properties, links
- transaction translator: tree diff -> fact diff

This keeps the CRDT scope narrow and the query scope fast.

### 4. Swift should not deserialize on the main actor

The hot path must be:

1. load `head`
2. scan slots until `tail == head`
3. create archived views from raw pointers
4. append view-backed work items to a background queue
5. coalesce to one UI apply per frame

The main thread should receive already-grouped domain changes, not raw slot traffic.

### 5. Coalescing policy

Use these rules:

- outline diffs: keep only the newest diff per page in a frame window
- task diffs: merge all additions/updates/removals in the frame window
- property diffs: merge by `(page_id, block_id, key)`
- link diffs: merge by `(page_id, block_id, target_id, ref_type)`

Never queue multiple redundant UI applies for the same page in one frame.

## Swift Shared-Memory Consumer Stubs

These are the intended app-side shapes. They are not wired into the current Xcode target yet because the safe path is shadow-mode validation first.

```swift
import Foundation
import Observation

struct KnowledgeCoreRingLayout {
    let headOffset: Int
    let tailOffset: Int
    let slotsOffset: Int
    let slotStride: Int
    let slotPayloadOffset: Int
    let slotCount: Int
    let slotPayloadBytes: Int
}

struct KnowledgeCoreMappedRing {
    let base: UnsafeMutableRawPointer
    let length: Int
    let layout: KnowledgeCoreRingLayout

    func slotPointer(sequence: UInt64) -> UnsafeRawPointer {
        let slotIndex = Int(sequence % UInt64(layout.slotCount))
        return UnsafeRawPointer(
            base.advanced(by: layout.slotsOffset + (slotIndex * layout.slotStride))
        )
    }

    func payloadPointer(sequence: UInt64) -> UnsafeRawPointer {
        slotPointer(sequence: sequence).advanced(by: layout.slotPayloadOffset)
    }
}

@MainActor
@Observable
final class KnowledgeCoreViewModel {
    var outlineRowsByPage: [String: [String: ArchivedOutlineRowView]] = [:]
    var taskRowsByPage: [String: [String: ArchivedTaskRowView]] = [:]
    var propertyRowsByPage: [String: [String: ArchivedPropertyRowView]] = [:]
}
```

```swift
import Foundation

final class KnowledgeCorePump {
    private let core: OpaquePointer
    private let ring: KnowledgeCoreMappedRing
    private let model: KnowledgeCoreViewModel
    private var task: Task<Void, Never>?

    init(core: OpaquePointer, ring: KnowledgeCoreMappedRing, model: KnowledgeCoreViewModel) {
        self.core = core
        self.ring = ring
        self.model = model
    }

    func start() {
        task = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            var pending: [ArchivedEnvelopeView] = []

            while !Task.isCancelled {
                let head = graph_engine_kc_ring_head(self.core)
                var tail = graph_engine_kc_ring_tail(self.core)

                while tail < head {
                    let slot = self.ring.slotPointer(sequence: tail)
                    let header = slot.assumingMemoryBound(to: KnowledgeCoreSlotHeader.self).pointee
                    let payload = self.ring.payloadPointer(sequence: tail)
                    pending.append(
                        ArchivedEnvelopeView(
                            base: payload,
                            length: Int(header.len),
                            version: header.version,
                            kind: header.kind
                        )
                    )
                    tail += 1
                }

                if !pending.isEmpty {
                    graph_engine_kc_ring_set_tail(self.core, tail)
                    let frame = pending
                    pending.removeAll(keepingCapacity: true)

                    try? await Task.sleep(for: .milliseconds(16))
                    await MainActor.run {
                        self.apply(frame)
                    }
                } else {
                    try? await Task.sleep(for: .milliseconds(2))
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func apply(_ frame: [ArchivedEnvelopeView]) {
        // Map archived rows into the Observable model without allocating intermediate Data.
    }
}
```

## Integration Sequence

### Phase 0: scaffolding

- keep BTK intact
- add `knowledge_core` Rust module
- add separate FFI entry points
- expose ring region + layout + subscription APIs

Gate:

- `cargo test` passes
- no BTK regressions

### Phase 1: shadow mode

- create `KnowledgeCoreBridge` on the Swift side
- register the same outline/task subscriptions in BTK and knowledge core
- compare diff parity in debug builds
- log mismatches by page and tx id

Gate:

- 0 row parity mismatches across edit stress tests
- no main-thread regressions

### Phase 2: editor path

- route note edits through the new parser + CRDT façade
- keep BTK as fallback behind a feature flag
- measure:
  - ring occupancy
  - mean diff bytes
  - P95 subscription latency

Gate:

- P95 Rust mutation -> Swift model apply under 8 ms
- no ring overruns in stress runs

### Phase 3: query path

- move task/property/link query subscriptions to the new store
- keep graph physics/rendering separate
- only then remove BTK query polling

Gate:

- query parity
- no frame drops during mass edits

### Phase 4: persistence and time travel

- switch Cozo storage from pure in-memory rebuilds to persisted backend
- persist Loro snapshots or updates per page
- add timeline checkout UI

Gate:

- snapshot restore parity
- bounded storage growth under long editing sessions

## Build Pipeline

### Rust

Add dependencies:

- `loro`
- `orgize`
- `libc`

Already present and reused:

- `cozo`
- `rkyv`
- `memchr`

### Xcode

No new build phase is required. The existing `build-rust.sh` path remains valid because the new module is inside the same `graph-engine` crate.

Required updates:

1. add new Rust source files to `graph-engine-build-inputs.xcfilelist`
2. extend `graph-engine-bridge/graph_engine.h`
3. keep `Epistemos-Bridging-Header.h` unchanged because it already imports the bridge header

### CI

Minimum CI expansion:

1. `cd graph-engine && cargo test`
2. `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
3. a new stress target that simulates 10k ring writes while Swift drains at 60 Hz

## Failure Modes and Mitigations

### Ring full

Mitigation:

- return explicit producer error
- count drops
- coalesce newest diff for same subscription before retry

Do not:

- block the producer
- realloc the mapped region

### Oversized archived payload

Mitigation:

- treat as programmer error in debug
- in release, fall back to chunking or a snapshot side-channel

### Query storm

Mitigation:

- dependency-pattern prefilter
- per-subscription coalescing
- one main-thread apply per frame

### CRDT/order drift

Mitigation:

- hierarchy authoritative in Loro
- order key authoritative in fractional index projection
- parity test against restored snapshots

## Recommended next implementation pass

1. wire Swift shadow-mode consumers into a debug-only bridge
2. add raw archived row views on the Swift side so there is no `String(decoding:)` in the hot path unless a view actually reads that field
3. replace the current polling `BTKSubscriptionState` path with display-rate-throttled ring consumption after parity holds
