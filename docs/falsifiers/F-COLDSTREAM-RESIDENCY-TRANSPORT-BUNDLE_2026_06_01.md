---
state: candidate-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md
status: F-ColdStream-vs-Mmap, F-SlabArena-CopyCount, F-MetalIO-FeatureGate, F-CodecStage-Latency, F-TransportCancellation, F-CachePolicy-Pollution, F-ColdPanicFallback, F-ProductRouteReview, and F-SmallModelRuntimeHarnessSafetyPlan passed metadata-only witnesses; no live cold transport or runtime promotion without dry-run, live platform, and user-facing proof
---

# Falsifier Bundle - ColdStream Residency Transport

## Purpose

These gates keep a custom transport from becoming folklore. ColdStream wins
only if it beats mmap-fault and naive read baselines on the exact workload
Epistemos needs: predicted cold page runs, bounded token stalls, explicit
destinations, cancellation, measured copies, and visible fallback.

## Candidate falsifiers

| Falsifier | Must prove | Minimum artifact |
|---|---|---|
| `F-TransportRunManifest-Completeness` | Every transport run names byte ranges, codec, checksum, destination, priority, lease, fallback, and cancellation group. | Manifest fixture plus missing-field negatives. |
| `F-PageRun-Coalescing` | Coalescing reduces read amplification versus raw page order without reading too many useless bytes. | Synthetic and file-backed run benchmark. |
| `F-ColdStream-vs-Mmap` | ColdStream benchmark-plan rows beat mmap-fault and naive pread rows on p95/p99 stall and read amplification for same synthetic fixtures while staying metadata-only. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/coldstream_vs_mmap/result.json`; no live mmap, pread, ColdStream, Metal I/O, model, or SSD stress bytes moved. |
| `F-SlabArena-CopyCount` | CPU slab path preallocates buffers and reports actual copies with no per-token allocation spikes. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/slab_arena_copy_count/result.json`; no live transport, model, or runtime bytes moved. |
| `F-MetalIO-FeatureGate` | Metal I/O path is used only when platform support exists and falls back to CPU slabs with visible caveat. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/metal_io_feature_gate/result.json`; no live Metal, model, or runtime bytes moved. |
| `F-CodecStage-Latency` | Decompression/conversion latency and copies are measured separately from file read time. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/codec_stage_latency/result.json`; no live codec benchmark, transport, model, or runtime bytes moved. |
| `F-TransportCancellation` | Route changes cancel obsolete in-flight reads and prevent stale slabs from entering execution. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/transport_cancellation/result.json`; no live transport, model, or runtime bytes moved. |
| `F-CachePolicy-Pollution` | Streaming/cache policy choice is measured against repeated hot-route performance. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/cache_policy_pollution/result.json`; no live transport, model, or runtime bytes moved. |
| `F-ColdPanicFallback` | Missed transport deadlines degrade visibly rather than blocking token-time execution silently. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/cold_panic_fallback/result.json`; no live transport, model, or runtime bytes moved. |
| `F-TransportTrace-AnswerPacket` | User-visible answers that depend on cold transport link to bytes, stalls, copies, fallback, and caveats. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/transport_trace_answer_packet/result.json`; no live bytes moved. |
| `F-SSD-WearBudget` | Repeated transport plans report read/write volume and reject routes over wear, energy, cache-pollution, or write-amplification budgets. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/ssd_wear_budget/result.json`; no live bytes moved and no SSD stress run. |
| `F-ColdStream-NoHiddenAuthority` | Transport cannot wake bytes or change route policy without SemanticWorkingSetPlan, ResidencyPageTable, SCOPE-Rex/SovereignGate admission, rollback, RunEventLog, and AnswerPacket proof. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/coldstream_no_hidden_authority/result.json`; no live bytes moved. |
| `F-ProviderRoute-CopySourceGuard` | Provider/KV/70B/practical-MLX route copy cannot source-launder, imply product promotion, call providers, create prompt manifests, mutate route policy, or hide L2/L3 status after large-model deferral. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/provider_route_copy_source_guard/result.json`; no live bytes moved. |
| `F-ProductRouteReview` | Product-route review keeps KV-Direct 128K, live sparse 70B, dense 70B runtime, and live ColdStream transport red before runtime harness planning. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/product_route_review/result.json`; no live transport, model, or runtime bytes moved. |
| `F-SmallModelRuntimeHarnessSafetyPlan` | Small-model runtime harness planning is serialized, owner-gated, dry-run-first, cancellable, rollback-bound, AnswerPacket-visible, privacy-fenced, and metadata-only before any MLX probe. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/small_model_runtime_harness_safety_plan/result.json`; no live transport, model, or runtime bytes moved. |
| `F-SmallModelRuntimeHarnessDryRunWitness` | Small-model runtime harness transcript replay must stay dry-run, mutation-free, runtime-byte-free, and AnswerPacket-visible before owner-approved probing. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/small_model_runtime_harness_dry_run_witness/result.json`; no live transport, model, or runtime bytes moved. |
| `F-SmallModelRuntimeHarnessOwnerApprovedProbe` | The first small-model smoke probe must be owner-approved, dry-run-bound, local-catalog-bound, serialized, cancellable, rollback-bound, AnswerPacket-visible, privacy-fenced, and execution-deferred. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/small_model_runtime_harness_owner_approved_probe/result.json`; no live transport, model, or runtime bytes moved. |
| `F-SmallModelRuntimeHarnessAbortableRuntimeProbe` | The owner-approved small-model smoke lanes must prove pre-runtime cancellation, deadlines, rollback, RunEventLog, AnswerPacket, privacy, budget, and mutation-free abort before any logged runtime smoke. | PASS on 2026-06-05 as metadata-only primary witness at `artifacts/falsifiers/small_model_runtime_harness_abortable_runtime_probe/result.json`; no live transport, model, or runtime bytes moved. |
| `F-SmallModelRuntimeHarnessProductRouteCapabilityRecheck` | Product-route capability blockers must remain visible after retained AnswerPacket handoff before fresh runtime leases can resume. | PASS on 2026-06-05 as L1 blocker-ledger primary witness at `artifacts/falsifiers/small_model_runtime_harness_product_route_capability_recheck/result.json`; no fresh product runtime/model bytes moved. |
| `F-SmallModelRuntimeHarnessFreshProductRuntimeSafetyLease` | Fresh product runtime leases must bind owner approval, dry-run fallback, serialized execution, cancellation/deadline, rollback, RunEventLog, AnswerPacket, privacy, and MAS/Pro honesty before any fresh live probe. | PASS on 2026-06-05 as L1 metadata-only safety-lease primary witness at `artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_safety_lease/result.json`; no fresh product runtime/model bytes moved. |
| `F-SmallModelRuntimeHarnessFreshProductRuntimeLiveProbe` | Fresh product runtime sidecars must prove exactly one redacted local small-model token under the safety lease before product AnswerPacket packaging can move. | PASS on 2026-06-05 as L1-only fresh runtime sidecar witness at `artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_live_probe/result.json`; one redacted Qwen3-4B token, nonzero bounded small-model bytes, no L2/L3 promotion. |
| `F-SmallModelRuntimeHarnessFreshProductRuntimeAnswerPacketProbe` | Fresh product runtime sidecars must packetize into real AnswerPacket and RunEventLog proof without opening new model/runtime bytes or promoting product capability. | PASS on 2026-06-05 as L1-only fresh product-runtime AnswerPacket witness at `artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/result.json`; one AnswerPacket, one RunEventLog, upstream runtime/model bytes retained, packetization bytes zero, no L2/L3 promotion. |
| `F-SmallModelRuntimeHarnessFreshProductRuntimeWrvProbe` | Fresh product-runtime AnswerPacket proof must be wired, reachable, visible, and source/test verified before product capability can be rechecked. | PASS on 2026-06-05 as L1/L3-source WRV witness at `artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_wrv_probe/result.json`; 10 source refs, 29 source markers, 3 visible surfaces, 4 focused test refs, 9 test markers, 12 WRV phases, zero new model/runtime bytes, no L2 product promotion. |

Current cursor after the 2026-06-05 `F-SmallModelRuntimeHarnessFreshProductRuntimeWrvProbe`: `small_model_runtime_harness_fresh_product_runtime_capability_recheck`.

`F-ColdStream-NoHiddenAuthority`, `F-TransportTrace-AnswerPacket`, and
`F-SSD-WearBudget` advance L1 only. `F-ColdStream-vs-Mmap` also advances L1
only as a benchmark-plan witness. `F-SlabArena-CopyCount` advances L1 only as a
CPU slab preallocation/copy-count witness. `F-MetalIO-FeatureGate` advances L1
only as a platform feature-gate and fallback witness. `F-CodecStage-Latency`
advances L1 only as codec/read-trace separation evidence.
`F-TransportCancellation` advances L1 only as cancellation/stale-slab rejection
evidence. `F-CachePolicy-Pollution` advances L1 only as cache-policy and
hot-route regression evidence. `F-ColdPanicFallback` advances L1 only as
missed-deadline fallback evidence, and `F-ProductRouteReview` advances L1 only
as red-route review evidence. `F-SmallModelRuntimeHarnessSafetyPlan` advances
L1 only as small-model harness safety planning; live platform benchmarks, p99
stall proof, MLX probes, and user-facing transport remain separate before
ColdStream can replace mmap or pread on a hot path. `F-SmallModelRuntimeHarnessFreshProductRuntimeLiveProbe` advances L1 only as one fresh redacted product-path Qwen3-4B token; `F-SmallModelRuntimeHarnessFreshProductRuntimeAnswerPacketProbe` advances L1 only by wrapping that sidecar in AnswerPacket and RunEventLog proof with zero new packetization bytes; `F-SmallModelRuntimeHarnessFreshProductRuntimeWrvProbe` advances L1/L3-source proof only by binding the fresh packet evidence to exact app source/test surfaces. L2 capability and broader L3 product proof remain separate.

## Promotion rule

ColdStream can replace mmap on a hot path only when:

1. mmap is measured as a bottleneck on that fixture;
2. ColdStream beats mmap and naive read baselines;
3. copy count and allocations are bounded;
4. cancellation works;
5. fallback is visible;
6. feature gates are platform-aware;
7. SSD/cache impact is budgeted; and
8. AnswerPacket and RunEventLog expose the route.

## Companion gates

- Residency PatternBoost bundle:
  `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- Mmap replacement and hot-path cure bundle:
  `docs/falsifiers/F-MMAP-REPLACEMENT-HOTPATH-CURE-BUNDLE_2026_06_01.md`
- Semantic working-set compiler bundle:
  `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`
