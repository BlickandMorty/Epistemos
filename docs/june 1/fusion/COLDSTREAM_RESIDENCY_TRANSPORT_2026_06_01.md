---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: user request to invent a better-than-mmap architecture for UAS/AppColdStore hot paths when SSD/page faults become the bottleneck
status: speculative architecture doctrine; F-ColdStream-vs-Mmap, F-SlabArena-CopyCount, F-MetalIO-FeatureGate, F-CodecStage-Latency, F-TransportCancellation, and F-CachePolicy-Pollution passed metadata-only witnesses; no product promotion without panic fallback, live p99 stall proof, rollback, and platform benchmarks
---

# ColdStream Residency Transport - 2026-06-01

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

2026-06-05 status note: `F-ColdStream-NoHiddenAuthority`,
`F-TransportTrace-AnswerPacket`, `F-SSD-WearBudget`,
`F-ColdStream-vs-Mmap`, `F-SlabArena-CopyCount`, and
`F-MetalIO-FeatureGate` now pass as metadata-only primary witnesses.
`F-CodecStage-Latency` also passes as a metadata-only witness at
`artifacts/falsifiers/codec_stage_latency/result.json`: it proves file-read
traces, codec latency traces, checksums, copy counts, rollback, RunEventLog,
AnswerPacket, admission, cancellation, and visible caveats stay separate before
live codec or transport work can promote. `F-TransportCancellation` passes at
`artifacts/falsifiers/transport_cancellation/result.json`: it proves route
epochs, cancellation tokens, obsolete-read rejection, stale-slab rejection,
rollback, RunEventLog, AnswerPacket, admission, compatibility fence, and visible
caveats stay explicit before live transport work can promote.
`F-CachePolicy-Pollution` passes at
`artifacts/falsifiers/cache_policy_pollution/result.json`: it proves streaming
no-cache, hot-reuse, and metadata-only cache lanes, repeated hot-route probes,
regression and pollution budgets, rollback, RunEventLog, AnswerPacket,
admission, compatibility fence, and visible caveats stay explicit before live
transport work can promote. These do not
prove live ColdStream transport, live mmap replacement, live pread/Dispatch
I/O/Metal I/O performance, SSD stress safety, or user-facing
runtime performance.
Current L1 cursor: `cold_panic_fallback`; L2 and L3 remain unpromoted.

## Thesis

`mmap` is useful for addressability. It is not a sufficient scheduler for
token-critical cognition.

The invented Epistemos replacement is:

> **ColdStream Residency Transport: an app-owned page-run conveyor that moves
> predicted cold bytes into leased CPU/Metal/MLX-ready slabs before the decode,
> proof, search, or render path needs them.**

This does not deny UAS. It makes UAS more physical. UAS still names every
object. AppColdStore still owns layout. But token-critical cold bytes should
not arrive through surprise VM faults. They should arrive through planned,
budgeted, cancelable transport jobs whose copy count, read amplification,
decompression, cache policy, and destination are visible.

```text
SemanticWorkingSetPlan
  -> ResidencyPageTable
  -> TransportRunManifest
  -> PageRunScheduler
  -> DispatchIO / pread / Metal IO lane
  -> CodecStage
  -> SlabLease / MetalBufferLease
  -> RuntimeRouter / ActiveAssembly
  -> TransportTrace
  -> RunEventLog + AnswerPacket
```

## Why mmap is not enough

`mmap` maps a file into virtual memory and lets the kernel fault pages in. That
is excellent for simple addressability and many random-read workloads. It is
dangerous as the main control plane for Epistemos because:

- page faults happen at the wrong abstraction level: the kernel sees pages, not
  task phases, verifier deadlines, KV compatibility, or route uncertainty;
- fault timing is hard to align with token deadlines;
- read amplification and eviction behavior are opaque;
- decompression and format conversion still have to happen somewhere;
- cancellation and priority are not route-aware;
- a route can look zero-copy while merely hiding stalls in VM behavior.

ColdStream replaces surprise with contracts. It treats cold bytes as scheduled
shipments, not as accidental faults.

Companion doctrine: `docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md`
defines the broader hot-path rule. ColdStream answers how cold bytes move;
the atlas answers which copies are compute/transport/proof hazards, which
copies are intentional product/editor/visual state, and how copy-causal
geometry, shared rings, packet streams, and Lean/Rust proof harnesses should
be used before claiming a path is zero-copy or better than mmap.

Companion Residency PatternBoost source:
`docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` defines how
successful and failed `TransportTrace`s become offline assembly tournament
features. A page-run plan that repeatedly wins can become an elite assembly
motif only after held-out p95/p99, copy-count, cold-miss, rollback, and
AnswerPacket proof.

## Apple grounding

| Apple/system surface | Useful lesson | Epistemos use |
|---|---|---|
| `mmap(2)` | File-backed virtual memory exists and remains useful for addressable views. | Keep `mmap` for metadata, low-risk read-only slices, and fallback baselines. |
| `fcntl(F_NOCACHE)` and Apple file-performance guidance | macOS exposes knobs for caching behavior when streaming file data. | Streaming cold model pages should declare whether they should pollute system cache. |
| Dispatch I/O | Random-access and stream file I/O can be scheduled asynchronously with low/high water behavior. | CPU-side page-run lanes can use explicit backpressure and cancellation instead of synchronous page faults. |
| Metal resource loading / `MTLIOCommandQueue` | Metal can run dedicated I/O command queues with priorities, cancellation, shared events, scratch buffers, and loading into GPU resources/memory. | Pro-gated path for direct file-to-Metal-buffer residency when hardware and API availability permit. |
| Metal residency sets / command queues | Metal exposes explicit resource residency concepts for command execution. | GPU-visible resources should enter a lease/residency set before execution, not be assumed hot. |

## Source links

- Apple `mmap(2)` man page:
  `https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/mmap.2.html`
- Apple `fcntl(2)` man page:
  `https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fcntl.2.html`
- Apple file-system performance tips:
  `https://developer.apple.com/library/archive/documentation/Performance/Conceptual/FileSystem/Articles/FilePerformance.html`
- Apple Dispatch I/O:
  `https://developer.apple.com/documentation/dispatch/dispatch-i-o`
- Apple Metal resource loading:
  `https://developer.apple.com/documentation/metal/resource-loading`
- Apple `MTLDevice.supportsFamily(_:)`:
  `https://developer.apple.com/documentation/metal/mtldevice/supportsfamily(_:)`
- Apple Metal feature set tables:
  `https://developer.apple.com/metal/capabilities/`

## L18-Candidate: Explicit Residency Transport Law

A cold substrate route becomes token-safe only when its predicted cold bytes
move through explicit, measured, cancelable transport into leased execution
buffers before they can block the hot path.

```text
TransportUtility(run | mission) =
  avoided_page_fault_stall
  + saved_read_amplification
  + destination_readiness_delta
  + cancellation_value
  + cache_pollution_reduction
  - scheduling_overhead
  - extra_copy_cost
  - decompression_cost
  - SSD_wear_cost
  - implementation_complexity
```

Promotion condition:

- the route declares every byte range, codec, checksum, destination, priority,
  and lease;
- mmap, pread/Dispatch I/O, and Metal I/O baselines are compared where
  available;
- p95/p99 stall time beats mmap-fault and naive pread baselines;
- read amplification and copy count are measured;
- cancellation prevents useless reads after route changes;
- cache pollution and SSD wear are budgeted;
- token-critical execution never depends on an unplanned page fault; and
- AnswerPacket exposes transport caveats when cold bytes shape output.

## Primitive set

### `TransportRunManifest`

The concrete byte-moving plan derived from the page table.

```text
TransportRunManifest {
  route_id
  page_runs
  priority_lanes
  destination_lanes
  codec_plan
  checksum_plan
  cancellation_group
  fallback_mmap_allowed
}
```

### `PageRun`

Contiguous or coalesced file range.

```text
PageRun {
  file_id
  offset
  length
  semantic_units
  codec
  checksum
  reuse_horizon
  cache_policy
  destination
}
```

### `PageRunScheduler`

Groups adjacent runs, assigns priority, and avoids per-token I/O.

```text
PageRunScheduler {
  pending_runs
  coalesced_runs
  urgent_lane
  prefetch_lane
  background_lane
  max_inflight_bytes
  cancellation_policy
}
```

### `SlabArena`

Preallocated app-owned memory for decoded page bundles.

2026-06-04 L1 status: `F-SlabArena-CopyCount` passes metadata-only at
`artifacts/falsifiers/slab_arena_copy_count/result.json`. It binds slab plans,
leases, copy events, allocation samples, rollback, RunEventLog, AnswerPacket,
admission, cancellation, purge policy, and fallback while loading zero
runtime/model bytes. This is a planning witness only; live allocation telemetry
and Metal I/O remain downstream gates.

```text
SlabArena {
  slab_id
  byte_capacity
  alignment
  owner_thread_or_actor
  lease_table
  copy_count_expected
  purge_policy
}
```

### `MetalBufferLease`

GPU/Metal-ready destination contract.

```text
MetalBufferLease {
  buffer_id
  metal_resource_ref
  residency_set_ref
  byte_range
  ready_event
  expiry
  fallback_cpu_slab
}
```

### `CodecStage`

Explicit decompression/conversion stage.

```text
CodecStage {
  codec
  input_run
  output_slab
  cpu_or_metal_kernel
  expected_copy_count
  expected_latency
  checksum_after_decode
}
```

### `TransportTrace`

Observability for the page pump.

```text
TransportTrace {
  manifest_ref
  run_timings
  bytes_requested
  bytes_read
  bytes_decoded
  copies
  cache_policy
  cancellations
  p95_stall
  p99_stall
  read_amplification
}
```

### `ColdPanicFallback`

Visible fallback when the transport misses its deadline.

```text
ColdPanicFallback {
  missed_run
  deadline
  fallback_route
  quality_caveat
  user_visible_limit
  rollback
}
```

## Transport lanes

| Lane | Purpose | Candidate implementation |
|---|---|---|
| Metadata lane | Small manifests, checksums, source cards, route cards. | `mmap` or ordinary read. |
| CPU slab lane | Decoded page bundles for Rust/MLX/Swift consumers. | `pread` or Dispatch I/O into preallocated slabs. |
| Streaming lane | Large cold runs that should not pollute cache. | File descriptor with explicit cache policy, benchmarked per workload. |
| Metal lane | Direct GPU-resource residency where supported. | `MTLIOCommandQueue` / Metal resource loading, Pro-gated. |
| Rebuild lane | Regenerable warm packs and coactivation tiles. | Background jobs with cancellation and checksums. |

## Intentional-copy caveat

ColdStream is not a mandate to remove every copy in the app. Product copies
for multiple graph views, multiple note editor surfaces, undo-safe TextKit
state, visual variants, previews, snapshots, and user artifacts can remain
when they are outside compute/transport/proof hot paths. Any "zero-copy" claim
must name its `CopyClass` and either prove the copy is gone on the hot path or
attach an `IntentionalCopyWaiver` that explains why the copy belongs to UX,
correctness, diagnostics, or cold artifact generation.

## Hot-path failure map

| Likely failure | ColdStream answer |
|---|---|
| Token waits on random SSD page fault | No token-critical unit can run unless its `SlabLease` or `MetalBufferLease` is ready, or the route degrades through `ColdPanicFallback`. |
| mmap looks zero-copy but stalls | `TransportTrace` reports p99 stall, faults baseline, copy count, and read amplification. |
| Prefetch reads useless pages | Cancellation groups and trace-regret update the next `TransportRunManifest`. |
| Decompression becomes hidden copy storm | `CodecStage` reports expected and actual copy count and latency. |
| OS cache gets polluted by one-off model pages | `PageRun.cache_policy` chooses cache behavior and the falsifier compares repeated-run impact. |
| SSD wear grows silently | `TransportTrace` aggregates bytes read/written and route admission budgets wear-sensitive loops. |
| Metal path is unavailable | Feature gate falls back to CPU slabs and records the lane choice in AnswerPacket. |

## Product posture

MAS-safe:

- metadata lane;
- small CPU-slab fixtures;
- transport manifests;
- AnswerPacket caveats;
- no live model-page transport until measured.

Pro Research:

- large AppColdStore page pump;
- Metal I/O resource loading;
- codec kernels;
- KV/page transport;
- 70B-lite dry-run transport fixtures.

Never:

- claim mmap is RAM;
- hide page-fault stalls as model time;
- count mapping as residency;
- rely on token-time synchronous cold reads;
- skip copy-count measurement;
- let transport override route admission.

## Canonical read rule

Read this file when a session touches mmap, AppColdStore transport, SSD hot
paths, page faults, cold I/O, prefetch windows, Metal I/O, Dispatch I/O,
file-backed KV/model pages, page-run packing, copy-count claims, or any claim
that UAS/AppColdStore can move cold model material fast enough for reasoning.
Also read `docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md`
when the task touches "zero-copy" wording, graph/render state movement,
PageGather geometry, hot JSON traces, streaming buffers, editor performance,
Rust/Swift/Metal FFI records, or lattice/geometric execution alignment.

Also read `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` when
successful or failed transport traces are used to learn reusable page-run,
prefetch, layout, or pause/resume motifs for future resident assemblies.
