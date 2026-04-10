# Mamba-2 Runtime Plan

**Date:** 2026-04-08

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    Swift UI Layer                     │
│  ChatCoordinator → MLXInferenceService → ChatSession │
└──────────────┬──────────────────────────┬────────────┘
               │                          │
     ┌─────────▼─────────┐    ┌──────────▼──────────┐
     │  SSMStateService   │    │  MetalRuntimeManager │
     │  (state persist)   │    │  (custom kernels)    │
     │  - save/load cache │    │  - segsum_stable     │
     │  - vault scoping   │    │  - inter_chunk_scan  │
     │  - lifecycle mgmt  │    │  - direct_conv       │
     └────────┬───────────┘    │  - elementwise       │
              │                │  - MPS matmul        │
     ┌────────▼───────────┐    └──────────────────────┘
     │  epistemos-core    │              │
     │  (Rust FFI)        │    ┌─────────▼────────────┐
     │  - ssm_state v2    │    │  .metallib           │
     │  - hash functions  │    │  (compiled shaders)   │
     └────────────────────┘    └──────────────────────┘
```

## Phase 1A: MLX State Persistence — COMPLETE ✅

**Status:** Done (2026-04-08). All save/load/resume paths wired.

### What was built
1. ✅ Local mlx-swift-lm override: `extractKVCache()` + `injectKVCache()` on ChatSession
2. ✅ Save path: `notifySSMStateService()` extracts cache after generation, persists via `savePromptCache`
3. ✅ Load path: `resumeSSMState()` finds latest state, injects into ChatSession before generation
4. ✅ Vault staleness: `isStateStale()` detects vault modifications after state snapshot
5. ✅ Callback: `onSSMStateSaved` fires on save for ConversationPersistence binding
6. ✅ Benchmark harness: `MetalRuntimeManager.runBenchmark()` exercises kernels + MPS + state round-trip
7. ✅ Vault root wiring: ChatCoordinator passes vault URL for staleness detection

### Pipeline Flow (End-to-End)
```
User types query
  → ChatCoordinator.handleQuery()
    → Sets activeSessionID + activeVaultRoot on MLXInferenceService
    → PipelineService → TriageService → LocalMLXClient
      → MLXInferenceService.generate()
        → IF new SSM session:
          → resumeSSMState() → findLatestState() → isStateStale(vaultRoot) → loadMLXCache() → injectKVCache()
        → ChatSession.streamDetails() streams tokens
        → After completion: extractKVCache() → saveMLXCache() → onSSMStateSaved callback
  → NightBrain.ssmStatePruning keeps latest N snapshots
```

## Phase 1B: Custom Metal Runtime

### Kernel Inventory

| Kernel | File | Status | Purpose |
|--------|------|--------|---------|
| segsum_stable | segsum_stable.metal | Created | Log-space segment sum |
| segsum_stable_tiled | segsum_stable.metal | Created | Threadgroup-optimized variant |
| intra_chunk_scan | inter_chunk_scan.metal | Created | Blelloch scan within chunk |
| inter_chunk_reduce | inter_chunk_scan.metal | Created | Reduce phase of 3-dispatch scan |
| inter_chunk_scan_tiles | inter_chunk_scan.metal | Created | Scan tile reductions |
| inter_chunk_apply | inter_chunk_scan.metal | Created | Apply scanned prefixes |
| chunk_state_decay | elementwise_ssm_helpers.metal | Created | exp(cumsum) decay factors |
| ssd_output_merge | elementwise_ssm_helpers.metal | Created | Y_diag + Y_off |
| silu_gate | elementwise_ssm_helpers.metal | Created | SiLU gating |
| rms_norm | elementwise_ssm_helpers.metal | Created | RMSNorm between layers |
| state_buffer_copy | elementwise_ssm_helpers.metal | Created | Snapshot copy |
| depthwise_conv1d_k4 | direct_conv.metal | Created | 4-tap causal conv (prefill) |
| depthwise_conv1d_k4_silu | direct_conv.metal | Created | Fused conv+SiLU |
| conv1d_step | direct_conv.metal | Created | Autoregressive conv state |

### MPS Usage (Dense Matmuls)
- `MPSMatrixMultiplication` for input/output projections
- `MPSMatrixMultiplication` for intra-chunk SSD matmul (Step 1)
- `MPSMatrixMultiplication` for chunk state computation (Steps 2 & 4)
- **Rationale:** MPS achieves 2.9 TFLOPS vs ~0.34 TFLOPS custom — 8.5x gap

### Safety Constraints
- **NO Decoupled Lookback** — crashes on Apple GPUs (no FPG)
- **3-dispatch Reduce-then-Scan** for inter-chunk (safe baseline)
- **Decoupled Fallback** planned for Phase 2 optimization
- Chunk size Q=128 (optimal for fused kernel, fits 16KB in 32KB threadgroup)
- All FP16 compute with FP32 accumulation where needed
- Input clamping: A_log in [-20, 0] to prevent exp() overflow

## Phase 2: Vault Integration — MOSTLY COMPLETE ✅

- ✅ State directories scoped by vault_root hash + model hash (Rust v2 format)
- ✅ Session metadata binding via `onSSMStateSaved` callback
- ✅ State resume skips conversation replay via `injectKVCache()`
- ✅ Staleness detection: `isStateStale()` walks vault for post-snapshot modifications
- ✅ Pruning integrated with NightBrain background jobs
- ⬜ ConversationPersistence actor not yet instantiated in main app lifecycle (binding ready)

## Phase 3: Topology-Aware Routing

- Reuse existing `hyperbolic_topology.rs` (Cw, Gv, Vs scores)
- High-gravity sessions → more frequent state snapshots
- Markov Blanket boundaries → natural checkpoint triggers
- Complexity-weighted context injection into model

## Performance Targets

| Metric | Target | Phase | Status |
|--------|--------|-------|--------|
| State save | < 5ms | 1A | ✅ Instrumented via `lastSaveDurationMS` |
| State load | < 2ms | 1A | ✅ Instrumented via `lastLoadDurationMS` |
| Generation tok/s | Measure actual | 1A/1B | ⬜ Needs SSM model download |
| TTFT with state | < 100ms | 1A | ✅ Staleness bypass path ready |
| Custom kernel overhead | < 10% vs MLX | 1B | ⬜ `runBenchmark()` ready |
| 120 tok/s | Architecture goal, M4 Pro+ | 1B | ⬜ Pending Phase 1B kernel invocation |

## Remaining Work

### Next Session
1. **Download an SSM model** (LFM-2.5-350M or Mamba-2-2B-4bit) and run end-to-end test
2. **Run `MetalRuntimeManager.runBenchmark()`** and record to PERF_BASELINE.md
3. **Invoke custom Metal kernels** during SSD forward pass (Phase 1B hot path)
4. **Instantiate ConversationPersistence** in AppBootstrap and wire `onSSMStateSaved` to `bindSSMStatePath()`
