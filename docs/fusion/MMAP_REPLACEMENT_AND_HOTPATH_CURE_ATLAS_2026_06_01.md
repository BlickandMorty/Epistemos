---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: user request for deep mmap replacement research, hot-path/copy cures, Lean/Rust rigor, and lattice/geometric execution alignment
status: speculative architecture doctrine; no product promotion without local benchmarks, copy/allocation counters, p95/p99 stall traces, rollback, and intentional-copy waivers
---

# Mmap Replacement and Hot-Path Cure Atlas - 2026-06-01

## Thesis

`mmap` should remain an addressability primitive. It should not be the hidden
execution scheduler for token-critical, graph-critical, or verifier-critical
work.

The Epistemos upgrade is:

> **Copy-Causal Geometry:** treat every hot path as a typed graph of byte
> movement, ownership, state transition, and proof obligations; then lay out,
> schedule, and verify the path so important compute moves through contiguous
> page runs, preallocated slabs, shared Metal/Rust rings, or binary witness
> records instead of surprise page faults, JSON blobs, per-frame rebuilds, or
> unmeasured copies.

This is not a blanket "zero copy everywhere" rule. Some copies are product
copies: two graph surfaces, multiple note editor surfaces, undo-safe text
storage, visual skins, snapshots, previews, and user-visible artifacts may need
separate materialized forms. The doctrine applies to backend, compute,
transport, model/KV, proof, trace, search, and artifact hot paths where a copy
or allocation can stall reasoning, hide false residency, or distort proof.

Companion Residency PatternBoost source:
`docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` defines how
page-run geometry, copy budgets, and ColdStream traces become offline assembly
tournament features. Copy-Causal Geometry proves a candidate route is honest;
Residency PatternBoost learns which honest route layouts repeatedly win before
live execution tries to use them.

## Primary-source grounding

| Source | Grounded fact | Epistemos implication |
|---|---|---|
| Apple `mmap(2)` | Maps pages from a file/device into virtual memory; callers specify `MAP_PRIVATE` or `MAP_SHARED`; offset must be page-aligned. | Keep `mmap` for typed addressable views and baselines, not as proof that bytes are resident or token-safe. |
| Apple file mapping guidance | Large sequential reads are often better handled by disabling caching and reading into a small buffer; very large or network/removable maps have caveats. | A 70B/KV cold route should prefer explicit page-run transport when the access pattern is predictable or deadline-bound. |
| Apple file-system performance guidance | Large numbers of small I/O operations, one-shot cached reads, and mis-sized buffers can dominate latency; uncached reads should use aligned buffers when possible. | The replacement question is workload-specific: coalesce, align, measure, and compare mmap against pread/Dispatch I/O/slab candidates. |
| Apple `fcntl(2)` | macOS exposes `F_RDADVISE`, read-ahead, and `F_NOCACHE` controls. | Cold routes need explicit cache-policy experiments instead of letting model pages silently pollute system cache. |
| Apple Dispatch I/O | Provides stream or random-access file I/O channels. | CPU-side page-run transport can be scheduled, throttled, canceled, and traced. |
| Apple Metal resource loading / `MTLIOCommandQueue` | Metal has resource-loading and I/O command queue surfaces, feature-dependent. | Pro-gated direct resource residency can be tested, but must feature-gate and fall back to CPU slabs. |
| Apple 2026 Metal feature tables | Residency sets, sparse buffers/textures, tensors, and performance counter heaps are feature-family gated. | Metal tricks are not universal product assumptions; route cards must record platform support. |
| Rust `memmap2` | `Mmap`/`MmapMut` dereference to slices; `MmapOptions` supports configured mappings such as offsets and prefault/read-ahead on platforms that support it. | Useful for fixtures, metadata, and read-only byte slices, but unsafe mapping creation and platform behavior require fences. |
| Rust `zerocopy` / `bytemuck` | Derivable traits/marker traits and `Pod`/`Zeroable`-style casting make byte-layout claims explicit. | Hot FFI records should be `repr(C)`/layout-checked and machine-testable instead of ad hoc JSON where speed matters. |
| Rust `bytes` | `Buf`/`BufMut` abstract byte buffers and can avoid unnecessary contiguous assumptions. | Streaming and packet paths can carry slices/chunks without rebuilding large `String`/`Vec` values. |
| Lean / Verus / Kani / Aeneas | Lean proves math; Verus statically verifies Rust specs; Kani model-checks Rust proof harnesses; Aeneas translates safe Rust into proof assistants including Lean. | Epistemos should prove route state machines and unsafe-boundary invariants, while benchmarking performance claims separately. |
| Sparse Transformer / SpAtten / Hilbert SpMV | Structured sparsity and locality-preserving order can reduce compute or memory movement when the task structure cooperates. | Geometry can guide layout and schedule, but every gain needs local ablation against dense/scatter baselines. |

Source links:

- Apple `mmap(2)`: `https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/mmap.2.html`
- Apple file mapping guidance: `https://developer.apple.com/library/archive/documentation/Performance/Conceptual/FileSystem/Articles/MappingFiles.html`
- Apple file-system performance guidance: `https://developer.apple.com/library/archive/documentation/Performance/Conceptual/FileSystem/Articles/FilePerformance.html`
- Apple `fcntl(2)`: `https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fcntl.2.html`
- Apple Dispatch I/O: `https://developer.apple.com/documentation/dispatch/dispatch-i-o`
- Apple Metal resource loading: `https://developer.apple.com/documentation/metal/resource-loading`
- Apple `MTLIOCommandQueue`: `https://developer.apple.com/documentation/metal/mtliocommandqueue`
- Apple Metal feature tables: `https://developer.apple.com/metal/capabilities/`
- Rust `memmap2`: `https://docs.rs/memmap2/latest/memmap2/`
- Rust `zerocopy`: `https://docs.rs/zerocopy/latest/zerocopy/`
- Rust `bytemuck`: `https://docs.rs/bytemuck/latest/bytemuck/`
- Rust `bytes`: `https://docs.rs/bytes/latest/bytes/buf/`
- Lean 4: `https://lean4.dev/`
- Verus: `https://verus-lang.github.io/verus/guide/`
- Kani: `https://model-checking.github.io/kani/`
- Aeneas: `https://aeneasverif.github.io/`
- LeanDojo: `https://arxiv.org/abs/2306.15626`
- OpenAI Sparse Transformer: `https://openai.com/index/sparse-transformer/`
- OpenAI sparse attention kernels: `https://github.com/openai/sparse_attention`
- SpAtten: `https://huggingface.co/papers/2012.09852`
- Hilbert SpMV locality: `https://dspace.library.uu.nl/handle/1874/272362`

## L19-Candidate: Copy-Causal Geometry Law

A hot path becomes substrate-grade only when its copies, allocations, faults,
actor hops, layout transforms, and proof obligations are explicit enough to be
reordered, bounded, measured, or waived.

```text
HotPathCost(path) =
  p99_latency
  + page_fault_stall
  + read_amplification
  + copy_bytes
  + allocation_bytes
  + actor_hop_cost
  + format_conversion_cost
  + proof_cost
  + rollback_cost
  - locality_gain
  - reuse_gain
  - verifier_confidence_gain
```

Promotion condition:

- the path names its owner, caller, destination, residency tier, and rollback;
- copies are classified as `compute-hot`, `transport-hot`, `trace-hot`,
  `artifact-cold`, `surface-intentional`, or `undo/correctness-intentional`;
- `mmap` claims distinguish mapped, touched, resident-estimated, faulted, and
  copied bytes;
- page runs are coalesced or justified as scatter;
- layout is tested against the current baseline, not assumed from theory;
- JSON/string paths are cold-witness only unless their p99 is measured safe;
- shared rings and binary records have ABI/layout tests;
- Lean/Verus/Kani/Aeneas proofs target invariants, not performance claims;
- AnswerPacket surfaces caveats when the route affects output.

## Replacement hierarchy

| Tier | Use when | Primitive |
|---|---|---|
| Keep mmap | Small read-only metadata, hashes, search-index byte reads, fixtures, and fallback baselines. | `MmapResidencyFence`, `memmap2::Mmap`, Swift `.mappedIfSafe`. |
| Fence mmap | The path might overclaim residency. | mapped/touched/resident-estimated/faulted/copied metrics. |
| Replace with CPU slabs | Predictable cold byte ranges must be ready before compute. | `TransportRunManifest`, `PageRunScheduler`, `SlabArena`, `Dispatch I/O`/`pread`. |
| Replace with Metal leases | Destination is GPU/Metal-visible and platform supports it. | `MetalBufferLease`, `MTLIOCommandQueue`, residency-set feature gate. |
| Replace with shared rings | Rust/Swift/Metal exchange per-frame or per-event state. | `GraphNodeState` ring, `GraphEvent` ring, `repr(C)` records. |
| Replace with packet streams | Dense restore is the bottleneck. | PageGather packets, logical-position/value streams, late materialization. |
| Replace with binary witnesses | JSON decode lands in a hot loop. | `zerocopy`, `bytemuck`, fixed ABI records, bounded summaries. |
| Keep intentional copy | Surface identity, undo safety, visual variants, snapshots, user artifacts. | `IntentionalCopyWaiver` with owner and scope. |

## Second-pass lock: Geometry-Aligned Execution

The deeper mmap replacement is not "delete mmap." It is a route discipline:
semantic adjacency, page adjacency, cache-line adjacency, GPU/Metal adjacency,
and proof adjacency must line up before a path can be considered hot-path
substrate.

`mmap` is kept when it is the simplest stable byte view: read-only metadata,
hash fixtures, derivative search indexes, small random byte ranges, and
fallback/baseline comparisons.

`mmap` is fenced when the path could overclaim: page alignment, file mutation,
file truncation, network/removable volume, mapped-vs-touched-vs-resident bytes,
faults, copied bytes, and cache pollution must be visible.

`mmap` is replaced when the route already knows byte ranges, deadline, codec,
destination, cancellation group, and fallback. Those paths should move through
`ReadPlanMatrix`, `TransportRunManifest`, `PageRunScheduler`, `SlabArena`,
`MetalBufferLease`, `StreamFrameArena`, or a shared Rust/Swift/Metal ring.

Second-pass objective:

```text
CureScore(path) =
  avoided_fault_stall
  + avoided_copy_bytes
  + avoided_allocations
  + locality_gain
  + verifier_confidence_gain
  - scheduler_overhead
  - extra_copy_bytes
  - false_sharing
  - complexity_cost
```

If `CureScore` is not measured or falsifiable, the cure is not promoted.

### Second-pass primitives

| Primitive | Role | Promotion gate |
|---|---|---|
| `HotPathCensus` | Static and runtime inventory of file, memory, actor, JSON, string, FFI, and GPU state movement for a route. | `F-HotPathCensus-Coverage` |
| `MmapHazardFence` | Records alignment, file size, device locality, truncation/mutation risk, mapped/touched/resident/fault/copied bytes, and cache policy. | `F-MmapHazardFence-Truncation` |
| `ReadPlanMatrix` | Compares mmap, `pread`, Dispatch I/O, slab, Metal lease, and SHM handoff under one fixture. | `F-ReadPlanMatrix-Coalescing` |
| `GeometryAlignedPageTable` | Reorders cold page/KV/weight/evidence units by block, Morton/Hilbert, coactivation, or proof-neighbor geometry. | `F-GeometryAlignedPageTable-Affinity` |
| `CopyBudgetVector` | Per-route budget for copy bytes, allocation bytes, actor hops, materializations, and waiver classes. | `F-CopyBudgetVector-Enforced` |
| `UnsafeBoundaryProofCard` | `repr(C)`/ABI/stride/aliasing/lifetime proof card for Swift/Rust/Metal byte records. | `F-UnsafeBoundaryProofCard` |
| `ShmMaterializationWaiver` | Classifies a POSIX shared-memory readback `Vec` or `Data` copy as boundary materialization, not hidden hot-path zero-copy. | `F-ShmMaterializationWaiver` |
| `StreamFrameArena` | Chunk/rope/packet arena for long token streams and route traces so repeated string growth does not become route control. | `F-StreamFrameArena-CopyBound` |
| `SpatialDirtyWindow` | Graph/editor geometry window that updates render/search/spatial state by dirty region, not full-state rebuild by default. | `F-SpatialDirtyWindow` |
| `ProtocolEdgeJsonWaiver` | Allows JSON at provider/tool/UI boundaries while banning JSON as the internal per-token/per-frame authority path. | `F-ProtocolEdgeJsonWaiver` |

## Keep, fence, or replace decision matrix

| Question | Keep mmap | Fence mmap | Replace mmap |
|---|---|---|---|
| Access pattern | Random, read-only, small/medium, repeated. | Mixed or unknown. | Predictable range set, sequential run, deadline-bound route. |
| Destination | CPU reads bytes directly. | CPU reads bytes but may mutate, truncate, or cross device risk. | GPU buffer, Rust ring, stream arena, slab, codec, or verifier packet. |
| Proof state | Layout is already simple and measured. | Mapping may hide faults, resident claims, or copies. | Route needs explicit cancellation, fallback, checksum, lease, and copy counter. |
| Failure cost | Slow fallback is acceptable. | SIGBUS/truncation/cache pollution would be harmful. | Page fault or materialization can stall reasoning or render frame. |
| Product semantics | View/baseline/fixture/index. | Ambiguous hot/cold route. | Compute-hot, transport-hot, trace-hot, or proof-hot path. |

## Local hot-path atlas

| Path | Current evidence | Cure direction |
|---|---|---|
| UAS/ColdStore mmap fixture | `agent_core/src/bin/falsify_uas_acs_mmap_residency.rs` proves one 16 MiB mmap-backed UAS/ResidencyLease/AcsAnchor slice, not live inference. | Keep as baseline; add `F-MmapKeepVsReplace` and `F-ColdStream-vs-Mmap-HotPath` before replacement claims. |
| AppColdStore route cards | `agent_core/src/uas/app_cold_store.rs` is metadata/dry-run route-card planning, not page transport. | Feed `TransportRunManifest` and `SlabArena` only after byte-range/codec/checksum/cancellation proof. |
| PageGather / KV page selection | `agent_core/src/helios/page_gather.rs` says full Fisher-Yates random scatter is a failure stressor; block-sorted scheduling and packetized output are the promising lane. | Add `GeometricPageRunPlanner`: block, Morton/Hilbert/coactivation order; prove packet path beats dense restore. |
| POSIX SHM data plane | `agent_core/src/shared_memory.rs` writes payloads through POSIX shared memory, then `read_payload` materializes `Vec<u8>` from the mapped segment. | Keep SHM as an interprocess data plane; add `ShmMaterializationWaiver` and byte counters for consumer copies. |
| Agent arena mmap | `agent_core/src/arena/mod.rs` uses a page-aligned mmap-backed request arena and copies slot payloads into `Vec<u8>` on read. | Treat as bounded control/IPC arena; prove slot layout and classify read materialization before calling it zero-copy. |
| Graph physics/render state | `graph-engine/src/engine.rs` has a full 64-byte `GraphNodeState` ring writer, while Swift currently binds production position-only shared buffers in `MetalGraphView.swift`. | Promote the NodeState ring to the main Swift path and retire legacy position ferry where measured safe. |
| Graph `sync_all_positions()` | Copies simulation arrays into graph nodes and ECS world, then rebuilds spatial grid when positions changed. | Split visual-state, spatial-state, and graph-model sync; use dirty geometry windows and shared state for render-only paths. |
| Shared position feature path | `graph-engine/src/engine.rs::write_positions_to_shared` currently collects `xs` and `ys` vectors before writing when `shared-position-buffers` is active. | Before promotion, direct-write into bound SoA/interleaved buffer or prove the collect is cold/feature-only. |
| Swift shared graph buffers | `MetalGraphView.swift` allocates three `.storageModeShared` position buffers and semaphores, with legacy ferry retained for A/B fallback. | Good direction; next proof is ABI/stride/semaphore correctness and whether full `GraphNodeState` beats position-only. |
| GPU N-body | `renderer.dispatch_gpu_nbody` copies position scratch into a Metal buffer and copies prior forces into a Vec. | Use persistent shared/managed buffers or direct world SoA upload; gate against CPU Barnes-Hut and current O(N2) thresholds. |
| Graph commit arrays | `MetalGraphView.swift` builds `payload.xs`/`payload.ys` during graph commit. | Classify as cold/warm graph load, not per-frame; keep unless commit p99 says otherwise. |
| Note editor parse | `ProseTextView2.reparseAndInvalidate()` reparses full `string`; debounce exists but defaults to zero. | Keep UI correctness copies; add incremental line/paragraph parse forest and long-doc debounce gates before changing UX. |
| Streaming text | `DisplayPacedTextBuffer` coalesces display updates but uses `pendingText += text`. | For long streams, use chunked buffers/rope segments and bounded flush copies; keep final surface copy. |
| Vault recall trace | `VaultRecallBridge.trace` decodes JSON into Swift trace; this is fine for breadcrumbs, not per-token hot control. | Hot path emits fixed counters/binary summary; JSON remains cold witness for UI/AnswerPacket. |
| Provider/tool JSON | `agent_core` providers, tools, Eidos witnesses, and admission records legitimately use `serde_json` at protocol and artifact edges. | Add `ProtocolEdgeJsonWaiver`: boundary JSON is allowed, internal active routing needs binary/fixed counters if measured hot. |
| EventDrain / RustEventRing | `GraphEvent` is a 64-byte `repr(C)`-mirrored event and drain buffer is reused, but no production caller owns it yet. | Activate for cursor/edit/token events only with no per-event allocation falsifier. |
| SQLite/search mmap | `SearchIndexService` and `PaperclipStateStore` set bounded `PRAGMA mmap_size = 268435456`; search index is derivative and rebuildable. | Keep budgeted mmap; measure resident impact and cold-query p99 before reducing or replacing. |
| Tool embedding cache blobs | `agent_core/src/cache/mod.rs` serializes `f32` embeddings into blobs and rehydrates them into `Vec<f32>`. | Warm cache materialization is acceptable; add `CacheBlobBorrowView` only if recall routes prove it hot. |
| SDF label atlas | `SDFLabelAtlas` decodes JSON/pixels and copies rows during atlas construction. | Cold initialization copy; keep unless label rebuilds enter frame p99. |
| Semantic clustering slices | `SemanticClusterService` uses array snapshots and slices during background clustering. | Batch-warm path; profile before replacing with borrowed/vDSP no-slice-copy variants. |
| Timers/animations | Graph render has occlusion/visibility gates; pinned panel and AI partner timers are explicit. | Only hot-path issue if they tick while invisible/idle; prove with idle tick counters before edits. |

## Copy classes

| Class | Allowed? | Example |
|---|---|---|
| `compute-hot` | No, unless measured and bounded. | KV page decode, graph physics positions, verifier packet bridge. |
| `transport-hot` | Only inside declared codec/slab stage. | SSD page run into `SlabArena`. |
| `trace-hot` | Prefer fixed records. | Per-token/per-frame route metrics. |
| `artifact-cold` | Yes, if outside hot path. | Saved report, JSON artifact, export. |
| `surface-intentional` | Yes. | Multiple graph/editor surfaces, visual variants, previews. |
| `undo/correctness-intentional` | Yes. | TextKit storage, undo snapshots, conflict-safe editor state. |
| `diagnostic-intentional` | Yes with budget. | Debug trace, screenshot, benchmark artifact. |

Every future "zero-copy" claim must name the class. The ban is on hidden
compute/transport copies, not on UI state that earns its existence.

## Copy-causal geometry

Represent a route as a directed multigraph:

```text
Node = {semantic_unit, byte_range, owner, residency, format, proof_state}
Edge = {read, decode, copy, borrow, map, cast, schedule, verify, render, save}
Weight = {latency, bytes, faults, allocs, actor_hops, confidence_delta}
```

Then choose layout and execution order that minimize the weighted boundary
between the active set and cold substrate:

```text
LayoutObjective(active_set) =
  min over orders:
    sum(edge_crossings * movement_cost)
  + sum(scatter_penalty)
  + sum(cache_pollution)
  + sum(proof_gap)
  - sum(reuse_locality)
```

Practical forms:

- block-sorted PageGather for near-term wins;
- Morton/Hilbert/coactivation ordering for two-dimensional or graph-like
  access neighborhoods;
- proof-aware packet streams when dense logical restore is slower than
  consuming `(logical_position, value)` packets;
- coactivation tiles for weight pages, KV pages, adapters, evidence, and
  proof tools that often wake together;
- spatial dirty windows for graph and editor state so geometry changes do not
  force full-state rebuilds.

This is the "align geometry to force execution" idea in rigorous form:
geometry cannot promise perfect reasoning, but it can remove whole categories
of accidental scatter, hidden copies, and proof ambiguity.

## Lean/Rust proof targets

Formal tools should prove invariants that stay true across input sizes:

- `TransportRunManifest` completeness: every run has range, checksum, codec,
  destination, priority, cancellation group, fallback, and lease.
- `SlabLease` typestate: a slab cannot be consumed before `ready`, after
  `expired`, or after cancellation.
- `GraphNodeState` ABI: Swift/Rust sizes, alignment, stride, and version match.
- `GraphEvent` ABI: every event remains 64 bytes and unknown kinds are safe.
- PageGather schedule: logical positions are unique, in bounds, and restore or
  packet semantics preserve caller-visible order.
- Copy classification: a compute-hot route cannot pass without copy/allocation
  counters or an explicit waiver.
- Mmap fence: mapped bytes are never equivalent to resident bytes.
- Geometry-aligned page table: every physical page/KV/weight/evidence run maps
  injectively to one logical owner or one explicit shared owner set.
- Materialization waiver totality: every boundary copy in SHM, cache, JSON,
  string, or UI surface has a class, owner, budget, and reason.
- Spatial dirty window: an incremental graph/editor update is a refinement of
  the full rebuild result for the affected region.

Performance is still benchmarked. Proof prevents invalid states; it does not
prove SSD bandwidth, cache behavior, or model quality.

## Backlog work order

1. Build `IntentionalCopyWaiver` schema for docs/artifacts so zero-copy claims
   do not attack UI/editor correctness copies.
2. Extend `copy_counter` with bytes-copied adapters for Rust hot fixtures and
   mirror Swift signposts for Swift/Metal copies.
3. Add `F-MmapKeepVsReplace` comparing Swift `.mappedIfSafe`, `memmap2`,
   `pread`, Dispatch I/O, and ColdStream slabs on the same fixtures.
4. Add `HotPathCensus` for the current graph render, stream buffer, SHM,
   cache blob, SQLite mmap, and note-editor parse paths.
5. Promote `GraphNodeState` shared ring to a measured Swift path or write a
   blocker explaining why position-only remains better.
6. Add `GeometricPageRunPlanner` with block-sorted baseline first, then
   Morton/Hilbert/coactivation order if the baseline leaves p99 on the table.
7. Add `MmapHazardFence` to any new `memmap2`/Swift mapped route before it is
   used in product routing.
8. Add long-doc editor falsifier before changing default debounce or parse
   semantics.
9. Move VaultRecall hot summaries to fixed counters before using traces for
   active routing decisions.
10. Wire `EventDrain` only after a no-allocation event harness passes.
11. Add Lean/Kani/Verus/Aeneas experiments for one small route state machine,
   not the whole app.

## Canonical read rule

Read this file when a session touches mmap replacement, SSD hot paths, cold I/O,
copy-count claims, "zero-copy" wording, graph render/physics state movement,
PageGather/KV page transport, Rust/Swift/Metal FFI records, hot JSON traces,
streaming buffers, note-editor performance, or any attempt to use lattice or
geometry to make execution more reliable.
