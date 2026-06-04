---
state: candidate-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md
status: F-ColdStream-NoHiddenAuthority passed metadata-only; no live cold transport promotion without platform-gated benchmarks
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
| `F-ColdStream-vs-Mmap` | ColdStream beats mmap-fault baseline on p95/p99 stall and read amplification for selected page-run fixtures. | Benchmark table with mmap, naive pread, and ColdStream. |
| `F-SlabArena-CopyCount` | CPU slab path preallocates buffers and reports actual copies with no per-token allocation spikes. | Allocation/copy-count trace. |
| `F-MetalIO-FeatureGate` | Metal I/O path is used only when platform support exists and falls back to CPU slabs with visible caveat. | Feature-gated dry-run and fallback fixture. |
| `F-CodecStage-Latency` | Decompression/conversion latency and copies are measured separately from file read time. | Codec fixture with checksum validation. |
| `F-TransportCancellation` | Route changes cancel obsolete in-flight reads and prevent stale slabs from entering execution. | Cancellation fixture with stale-run rejection. |
| `F-CachePolicy-Pollution` | Streaming/cache policy choice is measured against repeated hot-route performance. | Cache-pollution benchmark. |
| `F-ColdPanicFallback` | Missed transport deadlines degrade visibly rather than blocking token-time execution silently. | Fallback fixture linked to AnswerPacket caveat. |
| `F-TransportTrace-AnswerPacket` | User-visible answers that depend on cold transport link to bytes, stalls, copies, fallback, and caveats. | AnswerPacket fixture plus UI summary. |
| `F-SSD-WearBudget` | Repeated transport plans report read/write volume and reject routes over wear or energy budgets. | Wear-budget simulation. |
| `F-ColdStream-NoHiddenAuthority` | Transport cannot wake bytes or change route policy without SemanticWorkingSetPlan, ResidencyPageTable, SCOPE-Rex/SovereignGate admission, rollback, RunEventLog, and AnswerPacket proof. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/coldstream_no_hidden_authority/result.json`; no live bytes moved. |
| `F-ProviderRoute-CopySourceGuard` | Provider/KV/70B/practical-MLX route copy cannot source-launder, imply product promotion, call providers, create prompt manifests, mutate route policy, or hide L2/L3 status after large-model deferral. | PASS on 2026-06-04 as metadata-only primary witness at `artifacts/falsifiers/provider_route_copy_source_guard/result.json`; no live bytes moved. |

Current cursor after the 2026-06-04 `F-ProviderRoute-CopySourceGuard` metadata-only witness: `transport_trace_answer_packet`.

`F-ColdStream-NoHiddenAuthority` advances L1 only. `F-ColdStream-vs-Mmap`,
`F-SlabArena-CopyCount`, `F-MetalIO-FeatureGate`,
`F-CachePolicy-Pollution`, `F-ColdPanicFallback`,
`F-TransportTrace-AnswerPacket`, and `F-SSD-WearBudget` remain separate
platform/runtime gates before ColdStream can replace mmap or pread on a hot
path.

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
