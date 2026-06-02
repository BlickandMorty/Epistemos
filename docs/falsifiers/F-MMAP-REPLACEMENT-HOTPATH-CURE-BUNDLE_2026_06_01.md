---
state: candidate-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md
status: backlog gates; no mmap replacement, zero-copy, or copy-causal geometry promotion without measured local artifacts
---

# Falsifier Bundle - Mmap Replacement and Hot-Path Cure Atlas

## Purpose

This bundle keeps hot-path ambition falsifiable. It prevents two equal and
opposite mistakes:

1. claiming mmap or SSD addressability is RAM-speed execution; and
2. deleting useful product copies that exist for UI surfaces, undo, snapshots,
   visual variants, or user-visible artifacts.

## Candidate falsifiers

| Falsifier | Must prove | Minimum artifact |
|---|---|---|
| `F-HotPathCopyScope-IntentionalCopyWaiver` | Every copy in a touched path is classified as compute-hot, transport-hot, trace-hot, artifact-cold, surface-intentional, undo/correctness-intentional, or diagnostic-intentional. | Static/source-card report plus waiver negatives. |
| `F-HotPathCensus-Coverage` | Every promoted hot-path cure starts from a census of file I/O, mmap, SHM, cache blob, JSON, string, actor, FFI, Metal/GPU, and UI-surface movement. | Route census artifact with owner, line/file evidence, measured status, and unknowns. |
| `F-MmapKeepVsReplace` | mmap is kept only where it beats or matches explicit read/slab alternatives under the right workload and caveats. | Benchmark with mmap, `pread`, Dispatch I/O, ColdStream slab, p95/p99, faults, resident estimate, and copies. |
| `F-MmapHazardFence-Truncation` | A mapped route cannot be promoted unless page alignment, file size, mutation/truncation risk, device locality, mapped/touched/resident/fault/copied bytes, and cache policy are separated. | Mmap hazard card plus negative fixture for truncation or stale range access. |
| `F-ReadPlanMatrix-Coalescing` | Explicit read plans coalesce or justify scatter and beat the right mmap/read baseline before replacing it. | Same-fixture matrix for mmap, `pread`, Dispatch I/O, slab, Metal lease when available, and SHM handoff when relevant. |
| `F-ColdStream-vs-Mmap-HotPath` | Explicit transport beats mmap-fault baseline for token-critical selected page runs. | Fixture derived from `SemanticWorkingSetPlan`/`ResidencyPageTable`. |
| `F-PageRunGeometry-Locality` | Block/Morton/Hilbert/coactivation ordering reduces scatter, read amplification, or p99 stall versus submitted order. | PageGather benchmark with dense-restore and packetized variants. |
| `F-GeometryAlignedPageTable-Affinity` | Semantic, page, cache-line, GPU, and proof adjacency improve locality without breaking logical order or ownership. | Layout ablation with logical-order restore proof and locality counters. |
| `F-CopyBudgetVector-Enforced` | Copy bytes, allocation bytes, actor hops, materializations, and waiver classes are budgeted per route and fail closed when exceeded. | Budget vector artifact plus over-budget negative case. |
| `F-UnsafeBoundaryProofCard` | Swift/Rust/Metal byte records have explicit `repr(C)`/ABI/stride/lifetime/aliasing proof before hot use. | ABI test, layout hash, and unsafe-boundary proof card. |
| `F-ShmMaterializationWaiver` | POSIX SHM or mmap readback materializes bytes only at an explicit boundary with owner, budget, and reason. | SHM fixture that counts producer write bytes, mapped bytes, consumer materialized bytes, and lifetime cleanup. |
| `F-GraphNodeStateRing-NoLegacyPositionFerry` | Full `GraphNodeState` shared ring eliminates redundant position ferry or proves current position-only path is better. | Swift/Rust/Metal benchmark plus ABI check. |
| `F-GpuNBody-NoPositionCopyRegression` | Any new GPU N-body position path reduces copy/allocation pressure without regressing frame p99. | Renderer benchmark at small/medium/large graph sizes. |
| `F-EditorIncrementalParse-NoFullDocReparse` | Long-note edits avoid full-document parse/restyle unless correctness requires it. | 10k-line and 100KB paste fixtures with undo and visual parity. |
| `F-StreamingChunkBuffer-CopyBound` | Streaming text buffers cap copy bytes and allocation spikes on long responses. | Token stream fixture comparing current String buffer and chunk/rope candidate. |
| `F-StreamFrameArena-CopyBound` | Long token streams and route traces can use chunk/rope/packet arenas without regressing final surface correctness. | Stream-frame arena benchmark plus final rendered transcript parity. |
| `F-VaultRecallHotTrace-NoJSON` | Active routing does not depend on JSON decode in a token/per-frame hot path. | Binary/counter summary fixture plus cold JSON witness parity. |
| `F-ProtocolEdgeJsonWaiver` | JSON remains allowed at provider/tool/UI/artifact boundaries but cannot become internal active-route authority without measured safety. | Text audit plus hot-path trace proving no per-token/per-frame JSON dependency. |
| `F-EventRingActivation-NoPerEventAlloc` | EventDrain/RustEventRing production activation drains cursor/edit/token events without per-event allocation. | Ring stress test with allocation counter. |
| `F-SQLiteMmapBudget` | SQLite mmap budgets are derivative-index choices with measured resident/cold-query impact. | Search/Paperclip resident and p99 query benchmark. |
| `F-UIIdleTick-Gate` | Timers/animations do not tick unbounded while invisible, occluded, disabled, or idle. | Idle counter trace for graph overlay, AI partner, and live-note executor. |
| `F-SpatialDirtyWindow` | Graph/editor dirty-window updates refine to the same visible/search/spatial result as a full rebuild for the affected region. | Dirty-window fixture with full-rebuild parity and p99 comparison. |
| `F-ProofHarness-RustLean-StateMachine` | At least one route/slab/event state machine has machine-checked or model-checked invariants. | Lean/Verus/Kani/Aeneas proof or bounded harness linked to code. |
| `F-CopyCausalGeometry-Ablation` | The geometric layout/schedule change itself caused the improvement. | A/B ablation: submitted order vs geometric order, same source bytes and route. |
| `F-NoHiddenZeroCopyOverreach` | Docs and AnswerPackets do not imply UI/editor/product copies are forbidden or that mmap equals residency. | Text audit plus route-card caveat check. |

## Promotion rule

A hot-path cure can enter the product only when:

1. the baseline is measured;
2. the candidate beats the baseline on the target fixture or preserves a
   necessary intentional copy;
3. copy and allocation counters are present;
4. p95/p99 latency and stall sources are visible;
5. mmap mapped/touched/resident/fault/copied bytes are separated;
6. feature gates and fallback exist;
7. rollback is visible; and
8. AnswerPacket or RunEventLog exposes caveats when output depends on the path.

## Companion gates

- Residency PatternBoost bundle:
  `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- ColdStream residency transport bundle:
  `docs/falsifiers/F-COLDSTREAM-RESIDENCY-TRANSPORT-BUNDLE_2026_06_01.md`
- Semantic working-set compiler bundle:
  `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`
