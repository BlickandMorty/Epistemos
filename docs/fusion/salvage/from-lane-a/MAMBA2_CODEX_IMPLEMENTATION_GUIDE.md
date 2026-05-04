# Mamba-2 Vault Runtime — Complete Implementation Guide for Codex

**Date:** 2026-04-08
**Purpose:** Ground-truth implementation guide derived from 5 research documents + codebase audit. Codex must verify all existing code against this spec and implement remaining work.

---

## RESEARCH SOURCE DOCUMENTS (Ground Truth)

These 5 documents define what "correct" means. All implementation decisions must trace back to them:

1. **Custom Metal Mamba 2 Implementation for Epistemos Technical Specification.md** — SSD algorithm pseudocode, MPS vs custom shader decision matrix, memory layout, FFI architecture, validation strategy
2. **Custom Metal Mamba-2 Implementation Technical Specification for Epistemos.md** — Bandwidth analysis, state size verification, rkyv serialization, ANE hybrid assessment, metal-rs path, Zamba2 prototype scope
3. **Metal Mamba 2 Deep Dive into Blelloch Scan, FFT Strategy, and Tile Sizing.md** — Decoupled Fallback algorithm (Apple-safe scan), FFT vs vDSP analysis, tile sizing against 32KB threadgroup limit, chunk size Q=128 proof
4. **Metal Mamba 2 Implementation Research.txt** — Extended academic foundations, hardware tables, benchmark comparisons, FlatBuffers vs rkyv decision
5. **Metal Mamba 2 Research Prompt.txt** — The original prompt defining the research questions

---

## PART 1: WHAT THE RESEARCH SAYS (THE SPEC)

### 1.1 The SSD Algorithm (4-Step Block Decomposition)

Mamba-2's State Space Duality decomposes the semiseparable SSM matrix into 4 steps:

| Step | Operation | Parallelism | Kernel Type |
|------|-----------|-------------|-------------|
| **Step 1** — Intra-chunk output (Y_diag) | Quadratic matmul within each chunk | Fully parallel | **MPS** (MPSMatrixMultiplication) |
| **Step 2** — Chunk-end states | Matmul to compute final state per chunk | Fully parallel | **MPS** |
| **Step 3** — Inter-chunk state passing | Sequential prefix scan across chunks | Sequential (but only T/Q elements) | **Custom Metal** (Reduce-then-Scan) |
| **Step 4** — Output from prior states | Matmul updating from previous chunk state | Fully parallel | **MPS** |

**Final output:** `Y = Y_diag + Y_off`

**Critical fact:** With Q=128 and L=1M tokens, Step 3 scans only 7,812 elements (0.78% of sequence). Steps 1, 2, 4 are pure matmuls.

### 1.2 Non-Negotiable Hardware Constraints

From research doc 3 (Deep Dive):

| Constraint | Value | Source |
|------------|-------|--------|
| Threadgroup memory | **32KB** (invariant M1–M4) | Apple Silicon hardware |
| SIMD group size | **32 threads** | Apple GPU architecture |
| Chunk size Q | **128** (optimal for fused kernel) | PyTorch kernel fusion paper |
| Q=128 FP16 in TG | 128×128×2 = 32KB | Exactly fills threadgroup |
| Q=128 FP32 in TG | 128×128×4 = 64KB | **TOO BIG** — must tile or use FP16 |
| Forward-Progress Guarantee | **ABSENT on Apple GPUs** | Smith, Levien, Owens (SPAA '25) |

### 1.3 The Decoupled Lookback Ban

**CRITICAL:** Decoupled Lookback (the CUDA state-of-art for single-pass prefix scan) **WILL HANG on every Apple GPU ever shipped.** Apple GPUs lack Forward-Progress Guarantees. Measured: ~100% of runs hit the 2000ms TDR timeout and crash.

**Correct alternatives (ranked):**
1. **Decoupled Fallback** (SPAA '25) — single-dispatch, 98.4% of memcpy speed on M1 Max. MIT-licensed reference at `github.com/b0nes164/Decoupled-Fallback-Paper`. Uses work-stealing fallback mechanism.
2. **Reduce-then-Scan** (3-dispatch) — safe baseline, 1.43x slower than Decoupled Fallback but guaranteed safe. **This is what we implemented.**

### 1.4 MPS vs Custom Shaders

From research doc 2:
- `MPSMatrixMultiplication` achieves **2.9 TFLOPS on M4**
- Custom Metal matmul achieves **~0.34 TFLOPS** (Cutlass-style tiling)
- **8.5x gap** — MPS wins overwhelmingly for all dense matmuls

**Rule:** Use MPS for ALL matmuls (Steps 1, 2, 4 + input/output projections). Custom Metal ONLY for:
- `segsum_stable` — log-space segment sum (numerical stability)
- `inter_chunk_scan` — prefix scan (sequential, not matmul)
- `chunk_state_decay` — elementwise exp(cumsum)
- `direct_conv` — 4-tap depthwise convolution
- `silu_gate` — SiLU activation
- `rms_norm` — layer normalization
- `ssd_output_merge` — Y_diag + Y_off addition

### 1.5 Convolution Strategy

From research docs 1 and 3:
- Mamba-2 uses **d_conv=4** (4-tap depthwise convolution)
- FFT is wasteful for d_conv=4 (only 4 multiply-accumulate ops per output)
- **Direct sliding-window convolution** is correct
- FFT only makes sense for d_conv ≥ 16 (Mamba-2 doesn't use this)
- Pre-compute FFT(K) and cache in MTLBuffer IF FFT path is ever needed

**Current implementation:** `direct_conv.metal` with `depthwise_conv1d_k4`, `depthwise_conv1d_k4_silu` (fused), and `conv1d_step` (autoregressive decode).

### 1.6 Memory Architecture

From research docs 1 and 2:

**State sizes (FP16):**

| Model | Layers | H | N | D_head | SSM State | Conv State | Total |
|-------|--------|---|---|--------|-----------|------------|-------|
| Mamba-2 2.7B | 64 | 32 | 64 | 64 | ~16.8 MB | ~8.4 MB | ~25 MB |
| LFM2.5 1.2B | 48 | 32 | 64 | 64 | ~12.6 MB | ~6.3 MB | ~19 MB |
| 7B equivalent | 64 | 64 | 64 | 64 | ~32 MB | ~16 MB | ~48 MB |

**Compared to Transformer 7B KV cache at 1M context: 412 GB (impossible)**

**Buffer strategy:**
- `MTLStorageModeShared` for all state buffers (zero-copy CPU/GPU on Apple Silicon UMA)
- Ping-pong buffers for read/write hazard avoidance
- `MTLHeap` for arena allocation (eliminates per-buffer overhead)
- State save: single `memcpy` from shared buffer → disk (~2.3ms for 16MB on NVMe)

### 1.7 Serialization

Research docs recommend **rkyv** (zero-copy, 1.24ns access) or **FlatBuffers** (zero-copy, 0.46µs per item).

**What we implemented:** Dual-format approach:
1. **MLX native** (`savePromptCache`/`loadPromptCache`) — primary path, handles MambaCache natively
2. **MAMB v2 binary** (custom, epistemos-core) — for custom Rust runtime, flat binary with 60-byte header

### 1.8 Performance Targets

From research doc 1 (verified throughput ceilings):

| Chip | Bandwidth | 2.7B INT4 (~1.4GB) Theoretical | Realistic (50-65% eff) |
|------|-----------|-------------------------------|----------------------|
| M3 base | 100 GB/s | 74 tok/s | ~37-48 tok/s |
| M4 Pro | 273 GB/s | 202 tok/s | ~101-135 tok/s |
| M4 Max | 546 GB/s | 404 tok/s | ~202-270 tok/s |

**120 tok/s target:** Achievable on M4 Pro with INT4 quantization. Architecture goal, not a promise.

### 1.9 segsum Numerical Stability

From research doc 2:
- Computing L matrix via cumulative product differences causes **catastrophic cancellation and NaNs even in FP32**
- Stable implementation: compute in **log-space using only addition** (never subtraction)
- Clamp inputs to [-20, 0] to prevent exp() overflow
- Use FP32 for intermediate accumulation, output FP16

### 1.10 ANE Strategy

From research docs 1 and 2:
- ANE can run: input/output projections, LayerNorm, SiLU, softmax
- ANE CANNOT run: selective scan, segsum, custom layers, gather, dilated conv
- **Phase 4 or later** — do not make the recurrent scan depend on ANE
- ANE↔GPU transitions incur memory copy overhead — only worth it if projections dominate

---

## PART 2: WHAT HAS BEEN BUILT (Current State)

### 2.1 Phase 1A — MLX State Persistence ✅ COMPLETE

| Component | File | Status |
|-----------|------|--------|
| Feature flags | `EpistemosConfig.swift` | ✅ 3 @AppStorage flags |
| Rust SSM state v2 | `epistemos-core/src/ssm_state.rs` | ✅ 380 LOC, 5/5 tests pass |
| Rust FFI exports | `uniffi_exports.rs` + `epistemos_core.udl` | ✅ 6 functions + SSMStateError |
| SSMStateService actor | `Epistemos/Vault/SSMStateService.swift` | ✅ Save/load/list/prune + staleness detection |
| MLX-Swift local fork | `LocalPackages/mlx-swift-lm/` | ✅ extractKVCache() + injectKVCache() on ChatSession |
| MLX inference hooks | `MLXInferenceService.swift` | ✅ Persistent SSM session, save after generation, resume on load |
| AppBootstrap wiring | `AppBootstrap.swift` | ✅ SSMStateService created + wired to MLX + NightBrain |
| ChatCoordinator wiring | `ChatCoordinator.swift` | ✅ activeSessionID + vault root passing |
| Session metadata | `ConversationPersistence.swift` | ✅ ssmStatePath binding + onSSMStateSaved callback |
| NightBrain pruning | `NightBrainService.swift` | ✅ ssmStatePruning job |
| Benchmark harness | `MetalRuntimeManager.swift` | ✅ runBenchmark() with kernels + MPS + state round-trip |

**End-to-end flow:**
```
User query → ChatCoordinator sets sessionID + vaultRoot
  → MLXInferenceService.generate()
    → IF SSM model + existing state:
      → resumeSSMState() → findLatestState() → isStateStale() → loadMLXCache() → injectKVCache()
    → ChatSession.streamDetails() (tokens flow)
    → After completion: extractKVCache() → saveMLXCache() → onSSMStateSaved callback
  → NightBrain.ssmStatePruning keeps latest N snapshots
```

### 2.2 Phase 1B — Custom Metal Kernels ✅ CREATED, ⬜ NOT YET INVOKED

**4 Metal shader files, 14 kernels, 729 total lines:**

| File | Kernels | Research Compliance |
|------|---------|-------------------|
| `segsum_stable.metal` (164 LOC) | `segsum_stable`, `segsum_stable_tiled` | ✅ Log-space addition only, FP32 accumulation, [-20,0] clamping |
| `inter_chunk_scan.metal` (255 LOC) | `inter_chunk_reduce`, `inter_chunk_scan_tiles`, `inter_chunk_apply`, `intra_chunk_scan` | ✅ 3-dispatch Reduce-then-Scan (Apple-safe), NO Decoupled Lookback |
| `elementwise_ssm_helpers.metal` (154 LOC) | `chunk_state_decay`, `ssd_output_merge`, `silu_gate`, `rms_norm`, `state_buffer_copy` | ✅ FP32 intermediates, bounds guards |
| `direct_conv.metal` (156 LOC) | `depthwise_conv1d_k4`, `depthwise_conv1d_k4_silu`, `conv1d_step` | ✅ Direct 4-tap, NOT FFT, conv_state update for decode |

**MetalRuntimeManager.swift:** Pipeline state management for all 14 kernels. Compiles from default library. MPS matmul via `createMatmul()`. Ping-pong state buffers. MTLHeap for arena allocation. Benchmark harness ready.

### 2.3 Phase 2 — Vault Integration ✅ MOSTLY COMPLETE

| Component | Status |
|-----------|--------|
| Vault-scoped state directories (Rust v2 format) | ✅ `{vault}/ssm_state/{model_hash_hex}/` |
| Session metadata binding | ✅ `onSSMStateSaved` callback to ConversationPersistence |
| State resume without replay | ✅ `injectKVCache()` bypasses conversation re-processing |
| Staleness detection | ✅ `isStateStale()` walks vault for post-snapshot modifications |
| NightBrain pruning | ✅ `ssmStatePruning` job with configurable retention |
| ConversationPersistence instantiation | ⬜ Actor not yet created in AppBootstrap lifecycle |

### 2.4 What Has NOT Been Built

| Component | Research Requirement | Status |
|-----------|---------------------|--------|
| SSD forward pass using custom Metal kernels | Steps 1-4 encoded in single MTLCommandBuffer | ⬜ Not implemented |
| MPS matmul integration for Steps 1, 2, 4 | MPSMatrixMultiplication for dense ops | ⬜ `createMatmul()` exists but not wired to SSD |
| Model weight loading (safetensors/GGUF) | Rust model loader via candle-core or custom | ⬜ Not implemented |
| Tokenizer (Rust-side) | HuggingFace tokenizers crate | ⬜ Not implemented |
| Sampler (Rust-side) | greedy/top-p/top-k in pure Rust | ⬜ Not implemented |
| Decoupled Fallback scan | Single-dispatch Apple-safe scan | ⬜ Using 3-dispatch baseline |
| MTLSharedEvent for token streaming | GPU→CPU notification without busy-waiting | ⬜ Not implemented |
| Triple-buffered command submission | Overlap CPU/GPU with 3 in-flight buffers | ⬜ Not implemented |
| INT4 dequantization in shader | INT4→FP16 in input projection | ⬜ Not implemented |
| ANE hybrid offload | Core ML custom layer for projections | ⬜ Phase 4 |
| Speculative decoding | Small Mamba drafter + large verifier | ⬜ Phase 4 |
| Topology-aware state routing | Complexity/gravity/volatility from hyperbolic_topology.rs | ⬜ Phase 3 |

---

## PART 3: IMPLEMENTATION PLAN FOR CODEX

### Priority Order

```
1. End-to-end test with real SSM model (download + run + verify state save/load)
2. Run MetalRuntimeManager.runBenchmark() — record real numbers
3. Wire ConversationPersistence binding in AppBootstrap
4. Build SSD forward pass using existing kernels + MPS
5. Rust model loader + tokenizer + sampler
6. Upgrade to Decoupled Fallback scan
7. INT4 dequantization shader
8. MTLSharedEvent streaming
9. Topology-aware routing (Phase 3)
10. ANE hybrid (Phase 4)
```

### Task 1: End-to-End SSM Model Test

**Goal:** Download an SSM model, run inference, verify state saves and restores.

1. Download `mlx-community/mamba2-2.7b-4bit` or `mlx-community/LFM-2.5-350M-Instruct-4bit`
2. Enable `ssmStatePersistenceEnabled` in Settings
3. Send a message using the SSM model
4. Verify: state file appears in `~/Library/Application Support/Epistemos/ssm_cache/{model}/`
5. Verify: `lastSaveDurationMS` logged (target < 5ms)
6. Close and reopen session
7. Verify: state loads, `lastLoadDurationMS` logged (target < 2ms)
8. Verify: generation is coherent (not garbage from corrupted state)
9. Modify a vault note, re-query
10. Verify: `isStateStale()` returns true, state is refreshed

### Task 2: Run Benchmark Harness

**Goal:** Record real performance numbers in PERF_BASELINE.md.

```swift
// Call from debug menu or test
let manager = MetalRuntimeManager()!
manager.compileKernels()
let results = manager.runBenchmark()
// Write results to PERF_BASELINE.md
```

Record: kernel compile time, segsum dispatch time, silu_gate dispatch time, state_buffer_copy time, MPS matmul time, state round-trip time. Include device info.

### Task 3: Wire ConversationPersistence

**In AppBootstrap.swift:** The `ConversationPersistence` actor needs to be instantiated and the `onSSMStateSaved` callback from MLXInferenceService needs to call `persistence.bindSSMStatePath(sessionID:, statePath:)`.

### Task 4: Build SSD Forward Pass

**This is the core remaining engineering work.** Build a `Mamba2ForwardPass` struct/class that:

1. Takes model weights (MTLBuffers) and input tokens
2. Encodes all 4 SSD steps into one `MTLCommandBuffer`:
   - segsum_stable → produces L_matrix
   - MPS matmul → Step 1 intra-chunk output (Y_diag)
   - MPS matmul → Step 2 chunk-end states
   - inter_chunk_reduce + inter_chunk_scan_tiles + inter_chunk_apply → Step 3 state passing
   - MPS matmul → Step 4 output from states
   - ssd_output_merge → Y = Y_diag + Y_off
3. All within a single command buffer (no CPU sync between steps — Metal handles data hazards)
4. Returns logits buffer for sampling

**Research-mandated constraints:**
- Chunk size Q = 128
- Threadgroup size 256 (8 SIMD groups × 32)
- segsum uses FP32 accumulation, output FP16
- inter_chunk_scan uses 3-dispatch (not Decoupled Lookback)
- MPS for ALL matmuls
- Command buffer must complete in < 2 seconds (GPU watchdog)
- For 1M tokens: break into 512-token segments, each < 100ms

**Memory layout per research:**
```
Weight matrices: [D_inner, D_model] row-major, padded to 64-byte alignment
Hidden states:   [n_layers, H, N, D_head] — layers outermost for streaming
Chunk states:    [B, n_chunks, H, N] — chunk outermost for sequential access
```

**Buffer modes:**
- Model weights: `MTLStorageModeShared` (read-only after load, zero-copy)
- Hidden states: `MTLStorageModeShared` (ping-pong for read/write)
- Intermediates: `MTLHeap` sub-allocation (fast, aliasable)

### Task 5: Rust Model Loader

**Goal:** Load safetensors model weights into MTLBuffers from Rust.

```rust
// In a new file: epistemos-core/src/model_loader.rs or agent_core equivalent
pub fn load_mamba2_weights(
    model_path: &Path,
) -> Result<ModelWeights, ModelError> {
    // Parse safetensors header
    // Memory-map weight file
    // Return typed weight references
}
```

**Research says:** Use `mmap()` for weights. On Apple Silicon NVMe (7-10 GB/s), 2.7B INT4 (~1.4GB) loads in ~200ms. Model weights are read-only after loading.

### Task 6: Rust Tokenizer + Sampler

**Tokenizer:** Use HuggingFace `tokenizers` crate (already in Cargo ecosystem).

**Sampler:** Implement in pure Rust:
- Greedy: `argmax(logits)`
- Top-K: sort, take top K, softmax, sample
- Top-P (nucleus): sort by probability, accumulate until sum > p, sample
- Temperature: `logits / temperature` before softmax

### Task 7: Upgrade to Decoupled Fallback

Replace 3-dispatch Reduce-then-Scan with single-dispatch Decoupled Fallback:
- Reference: MIT-licensed WGSL at `github.com/b0nes164/Decoupled-Fallback-Paper`
- Port from WGSL to MSL (Metal Shading Language)
- No 64-bit atomics needed (bit-packed 32-bit)
- Measured: 98.4% of memcpy speed on M1 Max (36.85 × 10⁹ el/s)
- 1.43x faster than Reduce-then-Scan

### Task 8: INT4 Dequantization

**Goal:** Dequantize INT4 weights to FP16 in the input projection shader.

```metal
// Dequantize 2 INT4 values packed in one byte
kernel void dequant_int4_to_fp16(
    device const uint8_t *packed_weights [[buffer(0)]],
    device half *output [[buffer(1)]],
    device const half *scales [[buffer(2)]],  // per-group scale factors
    device const half *zeros [[buffer(3)]],   // per-group zero points
    constant uint &group_size [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
) {
    uint byte_idx = gid / 2;
    uint nibble = gid % 2;
    uint8_t packed = packed_weights[byte_idx];
    uint8_t val = nibble == 0 ? (packed & 0xF) : (packed >> 4);

    uint group = gid / group_size;
    output[gid] = (half(val) - zeros[group]) * scales[group];
}
```

### Task 9: MTLSharedEvent Token Streaming

**Goal:** GPU signals Swift when next token logits are ready (non-blocking).

```swift
let tokenReadyEvent = device.makeSharedEvent()!
let listener = MTLSharedEventListener()

tokenReadyEvent.notify(listener, atValue: UInt64(tokenCount + 1)) { event, value in
    let token = readLatestToken(from: sharedLogitsBuffer)
    let text = tokenizer.decode([token])
    onToken(text)
    // Re-register for next token
    event.notify(listener, atValue: value + 1) { ... }
}
```

This replaces `cmdBuf.waitUntilCompleted()` (blocking) with event-driven notification.

---

## PART 4: VERIFICATION REQUIREMENTS

### Numerical Correctness

From research doc 1:
- Mamba-2 FP16 shows **0.10% average divergence** from FP32 (Lyapunov-stable)
- Test tolerance: `atol=1e-3, rtol=1e-3` for individual elements
- Test sequence ladder: L = [16, 128, 1024, 16384, 131072]
- State size must remain **constant** regardless of sequence length

### segsum Validation

- Must produce **lower-triangular matrix** (upper triangle = 0)
- `L[i,j] = exp(sum(A_log[k] for k in j..i))` for i ≥ j
- Must NOT produce NaN for any input in [-20, 0]
- Diagonal elements must be `exp(A_log[i])` (single element sum)
- Compare against CPU reference implementation

### Scan Validation

- Must NOT hang (run with 5-second timeout watchdog)
- Inclusive prefix scan: result[i] = sum(input[0..i])
- Verify with known test vectors: [1,1,1,1] → [1,2,3,4]
- Verify with SSM state passing: h_c = decay_c * h_{c-1} + state_c

### Memory Safety

From research doc 1:
- Every kernel must have `if (gid >= params.n_elements) return;` bounds guard
- `MTLCommandBuffer.addCompletedHandler` must inspect `.error` property
- Fallback to CPU path if GPU resets > 2x in 60 seconds
- Command buffers must complete in < 2 seconds (watchdog)

### State Persistence

- Save snapshot → load snapshot → verify generation resumes coherently
- State file size matches expected (within 1KB of calculated size)
- Save time < 5ms, load time < 2ms
- Repeated save/load cycles don't grow file size
- Stale state detection works when vault notes are modified

---

## PART 5: RESEARCH CONSTRAINTS SUMMARY (Quick Reference)

### MUST DO
- [x] Chunk size Q = 128
- [x] MPS for all dense matmuls (Steps 1, 2, 4)
- [x] Custom Metal only for scan, segsum, elementwise, conv
- [x] segsum in log-space with FP32 accumulation
- [x] 3-dispatch Reduce-then-Scan (Apple-safe)
- [x] Direct conv for d_conv=4 (not FFT)
- [x] MTLStorageModeShared for state buffers (zero-copy UMA)
- [x] Ping-pong state buffers
- [x] Bounds guards on all Metal buffer accesses
- [x] Feature flag gating all new code
- [ ] MTLHeap arena allocation for inference buffers
- [ ] Single MTLCommandBuffer for all 4 SSD steps (no CPU sync between)
- [ ] Command buffer < 2s (GPU watchdog)
- [ ] INT4 weight support (primary target)

### MUST NOT DO
- [x] ~~Decoupled Lookback~~ — crashes Apple GPUs
- [x] ~~FFT for d_conv=4~~ — wasteful, direct conv is 4 MACs
- [ ] ~~Custom matmul kernels~~ — MPS is 8.5x faster
- [ ] ~~ANE dependency in Phase 1-2~~ — defer to Phase 4
- [ ] ~~Speculative decoding in Phase 1-2~~ — defer to Phase 4
- [ ] ~~Q=256 for fused kernel~~ — causes TG memory pressure
- [ ] ~~Blocking waitUntilCompleted in decode loop~~ — use MTLSharedEvent
- [ ] ~~Fake benchmarks~~ — measure actual hardware, record exact numbers

### SHOULD DO (if time permits)
- [ ] Decoupled Fallback single-dispatch scan (1.43x faster than Reduce-then-Scan)
- [ ] MTLHeap memory aliasing (saves ~40% peak memory for long contexts)
- [ ] Triple-buffered command submission (overlap CPU/GPU)
- [ ] `function_constant` for M3 vs M4 kernel specialization
- [ ] Pre-compile .metallib at build time (avoid JIT on first inference)
- [ ] Quamba2-style INT4 quantization (channel-order-preserving, 1.6% accuracy drop)

---

## PART 6: FILE MAP

### What Exists (DO NOT REBUILD)

```
epistemos-core/src/ssm_state.rs          — v2 binary format, 5 tests ✅
Epistemos/Vault/SSMStateService.swift    — save/load/list/prune + staleness ✅
Epistemos/Engine/MLXInferenceService.swift — persistent SSM session, hooks ✅
Epistemos/Engine/MetalRuntimeManager.swift — 14 pipelines + benchmark ✅
Epistemos/Shaders/Mamba2/segsum_stable.metal — 2 kernels ✅
Epistemos/Shaders/Mamba2/inter_chunk_scan.metal — 4 kernels ✅
Epistemos/Shaders/Mamba2/elementwise_ssm_helpers.metal — 5 kernels ✅
Epistemos/Shaders/Mamba2/direct_conv.metal — 3 kernels ✅
Epistemos/App/AppBootstrap.swift         — SSMStateService wiring ✅
Epistemos/App/ChatCoordinator.swift      — sessionID + vault root ✅
Epistemos/Vault/ConversationPersistence.swift — ssmStatePath binding ✅
Epistemos/State/NightBrainService.swift  — ssmStatePruning job ✅
Epistemos/State/EpistemosConfig.swift    — 3 feature flags ✅
LocalPackages/mlx-swift-lm/             — extractKVCache + injectKVCache ✅
```

### What Must Be Built

```
Epistemos/Engine/Mamba2ForwardPass.swift — SSD forward pass using kernels + MPS
epistemos-core/src/model_loader.rs       — safetensors weight loading
epistemos-core/src/tokenizer_bridge.rs   — HF tokenizers crate bridge
epistemos-core/src/sampler.rs            — greedy/top-p/top-k sampling
Epistemos/Shaders/Mamba2/dequant_int4.metal — INT4→FP16 dequantization
```

### What Must Be Verified

```
Every Metal kernel — numerical correctness against CPU reference
MLX state save/load — round-trip coherence
Benchmark harness — real numbers in PERF_BASELINE.md
Feature flag — OFF produces zero SSM code paths
Build — xcodebuild succeeds, cargo test passes
```
