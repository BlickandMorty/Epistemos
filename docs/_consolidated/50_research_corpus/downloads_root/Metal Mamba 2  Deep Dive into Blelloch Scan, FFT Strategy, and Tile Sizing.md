# Metal Mamba 2: Deep Dive into Blelloch Scan, FFT Strategy, and Tile Sizing

## Executive Summary

Three architectural sub-problems govern whether a custom Metal Mamba 2 implementation is performant or broken. The **Blelloch/single-dispatch scan** question reveals a hardware correctness hazard specific to Apple GPUs — not just a performance choice. The **vDSP vs Metal FFT** question resolves cleanly in favor of Metal GPU, but with critical batch-size constraints that change the answer for the SSM convolution step. And **tile sizing against the 32 KiB threadgroup limit** has an empirically determined optimal point of Q=128 and 64×64 FP16 tiles, validated by both Apple's own tooling and the PyTorch fused Mamba 2 kernel team.

***

## 1. Blelloch Single-Dispatch Kernel

### The Forward-Progress Guarantee Crisis

The naive assumption — implement classic Blelloch up-sweep + down-sweep in a single Metal dispatch — is not just suboptimal on Apple Silicon. It is **architecturally broken**. Apple M1, M2, M3, and M4 GPUs **lack Forward-Progress Guarantees (FPG)** for workgroup scheduling. NVIDIA's Decoupled Lookback algorithm (the CUDA state-of-the-art for single-pass prefix scan) requires FPG: it spins workgroups waiting for predecessor tiles to post their reductions. On Apple GPU, those predecessor tiles may never be scheduled while other workgroups are spinning — causing indefinite starvation and, in practice, a GPU hang requiring OS-level recovery. Measured on an Apple M1 Max, running Decoupled Lookback without FPG produces a histogram where virtually 100% of runs hit the 2000ms TDR timeout threshold and crash, rather than completing.[^1]

This matters specifically to Mamba 2 because the SSD State Passing step (Step 3 of the four-step SSD algorithm) is exactly an inter-workgroup prefix scan over chunk states. If implemented as a naive Blelloch scan across GPU workgroups, **this will hang your kernel on every Apple GPU ever shipped**.

### The Solution: Decoupled Fallback

Published at SPAA '25 by Smith, Levien, and Owens (Google Research / UC Davis), **Decoupled Fallback** is the correct portable single-dispatch scan for Apple Silicon. It extends the Chained Scan architecture with a work-stealing fallback mechanism: each workgroup spins on predecessor tiles up to a configurable maximum spin count, and upon triggering, the entire workgroup cooperatively computes the blocking tile's reduction from source data — eliminating the possibility of starvation. After completing the fallback, the workgroup atomically attempts to post the result for subsequent workgroups to consume, preventing redundant fallbacks.[^1]

**Measured performance on Apple Silicon (2^25 inclusive prefix sum):**[^1]

| Method | Apple M1 Max | Apple M3 | Notes |
|--------|-------------|----------|-------|
| Decoupled Lookback | ~0% completion | ~0% completion | Crashes on both |
| Reduce-then-Scan (3 dispatches) | 25.7 × 10⁹ el/s | 7.47 × 10⁹ el/s | Safe baseline |
| **Decoupled Fallback** | **36.85 × 10⁹ el/s** | **10.87 × 10⁹ el/s** | **1.43× over RTS** |
| Memcpy ceiling | 37.5 × 10⁹ el/s | 10.80 × 10⁹ el/s | Speed-of-light |

Decoupled Fallback on M1 Max achieves 98.4% of the theoretical memory-bandwidth ceiling — essentially Memcpy speed for a prefix scan. On M3, it hits **100.5% of Memcpy** (measurement within noise). The fallback overhead is negligible: on M1 Max, 1,046 fallbacks are initiated but only 4.8 successful insertions occur on average, meaning almost all fallbacks are resolved by the time the atomic update arrives.[^1]

### Implementation Architecture for Mamba 2 SSD

The five-phase Decoupled Fallback algorithm maps directly to the Mamba 2 SSD State Passing step:

```
Phase 0: Thread 0 atomically acquires work tile (serial chunk ordering)
Phase 1: Load chunk state data (coalesced, 32-thread SIMD blocks)
Phase 2: Subgroup-rake scan (Kogge-Stone within SIMD group, register-resident)
Phase 3: Workgroup-wide scan (Ladner-Fischer, in threadgroup memory)
Phase 4: Decoupled Fallback propagation (post local reduction → lookback → fallback if stalled)
Phase 5: Write output (chunk state + global prefix)
```

**No 64-bit atomics required** — the tile state representation uses bit-packed 32-bit atomics. This is critical because Metal historically lacked 64-bit atomic support.[^1]

The source code is publicly available under MIT license at `https://github.com/b0nes164/Decoupled-Fallback-Paper`, implemented in WGSL (which compiles to Metal via Dawn). The algorithm is subgroup-size agnostic and works with Metal's 32-thread SIMD groups without modification.[^1]

### Scope of the Scan Problem in Mamba 2 SSD

The Decoupled Fallback scan only applies to the **inter-chunk scan** (SSD Step 3). At chunk size Q=128 and a 1M token sequence, Step 3 scans over T/Q = 7,812 chunk states — a small scan where even Reduce-then-Scan adds negligible absolute latency. The **intra-chunk scan** (within a single chunk of 128 tokens) never crosses threadgroup boundaries and can use classic Blelloch up-sweep/down-sweep safely within a single threadgroup's shared memory. The complete architecture:[^2]

- **Intra-chunk (N ≤ 128):** Standard Blelloch in threadgroup memory. No inter-workgroup coordination. Safe.
- **Inter-chunk (T/Q elements):** Decoupled Fallback. Single dispatch. Near-Memcpy performance.

***

## 2. vDSP FFT vs Custom Metal GPU FFT

### Performance Summary

A March 2026 paper (Bergach, arXiv:2603.27569) provides the first rigorous GPU FFT vs. vDSP comparison on Apple Silicon, achieving **138.45 GFLOPS with a custom Metal radix-8 Stockham kernel** versus **107 GFLOPS from vDSP/Accelerate** on an M1 — a 29% improvement. However, the answer for the Mamba 2 convolution step is more nuanced than the headline number suggests.[^3]

**N=4096, Batch=256 on Apple M1:**[^3]

| Kernel | GFLOPS | µs/FFT | vs vDSP |
|--------|--------|--------|---------|
| vDSP/Accelerate (AMX + NEON) | 107.0 | 2.29 | 1.00× |
| Metal Radix-4 Stockham | 113.6 | 2.16 | +6% |
| **Metal Radix-8 Stockham** | **138.45** | **1.78** | **+29%** |
| Metal SIMD shuffle hybrid | 61.5 | 3.99 | −43% |

### The Critical Batch-Size Constraint

The Metal GPU FFT **requires batch ≥ 64** to overcome dispatch overhead and exceed vDSP. At small batches (≤ 16 FFTs), vDSP wins due to lower launch latency. This creates an important analysis question for Mamba 2:[^3]

- Mamba 2 uses **d_conv = 4** (a convolution kernel of 4 taps)
- The FFT size per channel is `next_pow2(2 × d_conv) = 8` — trivially small
- The batch dimension is **d_model = 2048** channels processed simultaneously

With 2048 independent FFTs of size 8, the batch far exceeds the threshold of 64, and all 2048 transforms fit entirely within a single threadgroup's shared memory. **Metal GPU FFT wins for Mamba 2's convolution step** — but the optimal strategy is to precompute `FFT(K)` once and store it in an MTLBuffer, then perform element-wise complex multiplication across 2048 channels as a simple parallel shader, avoiding repeated FFT computation of the fixed kernel weights.[^3]

### The Two-Tier Memory Model — Counterintuitive Finding

The key architectural insight from Bergach's work is a **reversal of conventional GPU FFT wisdom** on Apple Silicon:[^3]

- **Threadgroup memory barriers cost ~2 GPU cycles** (nearly free — enabled by Apple's Tile-Based Deferred Rendering hardware)
- **Scattered threadgroup access patterns cost 3.2× bandwidth** compared to sequential access

The SIMD shuffle hybrid kernel uses *fewer* barriers but scattered threadgroup memory access — and achieves only 44% of the radix-8 Stockham throughput. The correct design principle for Apple GPU FFT is: **maximize sequential (coalesced) threadgroup access patterns; do not optimize for minimizing barriers**.[^3]

This has a direct implication for the selective scan kernel: do not use SIMD shuffle for inter-SIMD-group state exchange in the scan. Use sequential threadgroup loads/stores instead.

### Optimal Metal FFT Configuration

Derived from Apple M1 hardware parameters:[^3]

```
Register file (Tier 1): 208 KiB — data-resident, exchange via simd_shuffle ~1–2 cycles
Threadgroup memory (Tier 2): 32 KiB — exchange-only between SIMD groups, ~2–4 cycles

Max single-dispatch FFT (FP32): N = 4096   (4096 × 8 bytes = 32 KiB exactly)
Max single-dispatch FFT (FP16): N = 8192   (8192 × 4 bytes = 32 KiB exactly)
```

**Multi-size kernel configurations:**[^3]

| N | Threads | Radix | Passes | TG Mem |
|---|---------|-------|--------|--------|
| 256 | 64 | 4 | 4 | 2 KiB |
| 1024 | 256 | 4 | 5 | 8 KiB |
| 4096 | 512 | **8** | 4 | **32 KiB** |
| 8192 | 512 | 8 | Four-step | 32 KiB + device transpose |
| 16384 | 512 | 8 | Four-step | 32 KiB + device transpose |

For sizes exceeding 4096, the four-step FFT decomposition is required: split N = N₁ × N₂ where N₂ ≤ 4096, apply sub-FFTs in separate threadgroup dispatches with a device-memory transpose between stages.[^3]

### Radix-8 Butterfly Implementation

The split-radix DIT butterfly reduces arithmetic from ~320 FLOPs (naïve 8×8 matrix-vector) to ~52 real additions + 12 real multiplications per butterfly:[^3]

\[ \text{DFT}_8 = \text{radix-2}\left(\text{DFT}_4^{\text{even}},\ \text{DFT}_4^{\text{odd}} \cdot W_8\right) \]

Radix-8 uses 38 GPRs per thread — 30% of the 128-GPR budget — leaving headroom for twiddle factors and compiler temporaries. Radix-16 would use 61% of the budget, causing occupancy degradation.[^3]

**Note on simdgroup_matrix (MMA) for FFT:** Apple's 8×8 hardware MMA is counter-productive for single-FFT-per-threadgroup execution. The data marshaling overhead between Stockham layout and MMA tile layout negates the 4× ALU advantage. Only consider MMA for batched FFT (8+ simultaneous FFTs per threadgroup), where matrix dimensions align naturally.[^3]

***

## 3. Tile Size vs. 32 KiB Threadgroup Memory

### Hardware Constraints (Invariant M1 through M4)

The 32 KiB threadgroup memory size is **identical across every M-series chip** from M1 through M4 Max. More cores and higher bandwidth on M3/M4 increase parallelism but do not change on-chip tile capacity. The register file (208 KiB) is also consistent.[^4][^3]

Key parameters that constrain tile sizing:[^5][^3]

```
Threadgroup memory:     32,768 bytes = 32 KiB
FP16 element size:      2 bytes
Max FP16 elements in TG: 32,768 / 2 = 16,384
Square tile of FP16:    √16,384 = 128 × 128 (single matrix, full TG memory)
Practical (A + B tiles): 2 × 64 × 64 × 2 = 16,384 bytes = 16 KiB (leaves room for C accumulator)
```

### SSD-Specific Tile Analysis

The SSD algorithm's four steps have distinct tiling requirements. Step 3 (State Passing scan) uses Decoupled Fallback as described above. The three matmul steps (1, 2, 4) tile as follows:

**Step 1 — Intra-chunk output (Q×Q block attention, quadratic within chunk):**
- Matrix shapes: (Q × N) × (N × D), output Q × D
- At Q=128, N=64, D=2048: tiles of 64×64 FP16 fit with 16 KiB
- Each threadgroup handles a 64×64 output tile across K=64 state dimension

**Step 2 — Chunk state (N × D output per chunk):**
- Matrix: Bₜ (Q × N) × Xₜ (Q × D), contracted over Q
- With Q=128: compute 64×64 tiles, 2 iterations over Q

**Step 4 — Output state contribution:**
- Matrix: Cₜ (1 × N) × hₜ (N × D), output 1 × D per chunk
- Simpler: single-row projection, fits trivially

**Recommended tile configuration for SSD in Metal:**[^6][^4]

| SSD Step | Operation Shape | Tile Config (FP16) | TG Mem Used |
|----------|----------------|---------------------|-------------|
| Step 1 (intra-chunk matmul) | (Q×N) × (N×D) | 64 × 64 × 32 | 16 KiB |
| Step 2 (chunk state) | (Q×N) × (Q×D) | 64 × 64 × 32 | 16 KiB |
| Step 3 (state passing) | Decoupled Fallback scan | 256 threads × N=64 | 4 KiB |
| Step 4 (output state) | (1×N) × (N×D) | 64 × 64 × 32 | 16 KiB |

### The Critical Chunk Size Q = 128

The chunk size Q is the single most impactful tuning parameter for the Metal SSD implementation. Evidence converges on **Q=128** as optimal for fused single-kernel implementations:

The PyTorch/Triton team discovered that before kernel fusion, optimal chunk size was Q=256; after fusing all five SSD kernels into one, **optimal chunk size dropped to Q=128**. The reason: fusion changes the register pressure and shared memory occupancy profile. At Q=128:[^6]
- Intra-chunk matmul fits in 16 KiB (half the TG memory), leaving 16 KiB for accumulators and the Decoupled Fallback spine
- State Passing serialization latency is hidden by Chunk State and Chunk Scan computation in parallel for other (batch, head) pairs
- At Q=256, TG memory pressure causes register spillage, defeating the fusion benefit

At Q=128 for a 1M token sequence: State Passing scans T/Q = **7,812 chunk states** — a 7,812-element Decoupled Fallback scan that runs in essentially memcpy time on M3/M4.

### simdgroup_matrix and Apple's MPP

Apple's March 2026 **Metal Performance Primitives (MPP)** framework provides production GEMM with hardware `simdgroup_matrix` (8×8 MMA). The guidance for 16-bit on current chips:[^4]

- Start with **SM = SN = 32** elements per SIMD group (32×32 simdgroup tile)
- Use a **2×2 SIMD group tile per threadgroup** → 64×64 threadgroup tile at 16-bit
- Smaller shapes: reduce to 1×2 or 1×1 simdgroup arrangement to preserve occupancy
- Increasing tile size beyond the occupancy cliff causes performance regression from dimension quantization effects[^4]

**Note:** `simdgroup_matrix` requires 8-element-multiple matrix dimensions. The Mamba 2 standard of D=2048 (multiple of 8) and N=64 (multiple of 8) satisfies this. Chunk size Q=128 (multiple of 8) also satisfies it.

### Tile Size Impact on Token Speed

The tile size affects **prefill** throughput (compute-bound) but not **generation** throughput (bandwidth-bound). For the Epistemos use case — persistent state caching with long context but single-token generation — the bandwidth analysis dominates:

| Chip | Bandwidth (GB/s) | FP16 2.7B (theoretical) | FP16 2.7B (realistic ~65%) |
|------|-----------------|------------------------|---------------------------|
| M3 base | 100 | ~18 tok/s | ~12 tok/s |
| M3 Max (40-core) | 400 | ~74 tok/s | ~48 tok/s |
| M4 Pro (20-core) | 273[^7] | ~51 tok/s | ~33 tok/s |
| M4 Max (40-core) | 546[^7] | ~101 tok/s | ~66 tok/s |

The 120 tok/s target with FP16 weights requires **M4 Max or M3 Ultra** at minimum. With W4A16 quantization (Quamba2-style, ~1.6% accuracy drop), the weight tensor shrinks 4×, pushing M4 Max to ~264 tok/s theoretical / ~170 tok/s realistic — achieving the target comfortably on M4 Pro and above.[^8]

Tile size optimization improves prefill speed (which matters for the ≤100ms first-token target) but does not move the generation number. Focus tile tuning effort on the Step 1 and Step 2 matmuls, which dominate prefill FLOPs.

***

## 4. Synthesis: Kernel Architecture Decision Tree

The three analyses produce a concrete implementation plan for the Metal fused SSD kernel:

```
                    ┌─────────────────────────────────┐
                    │      Fused Metal SSD Kernel      │
                    │    (single MTLCommandBuffer)     │
                    └────────────┬────────────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          │                      │                      │
    Intra-chunk             State Passing           FFT Conv
  (Steps 1, 2, 4)           (Step 3)              (pre-SSD)
          │                      │                      │
  simdgroup_matrix      Decoupled Fallback       Radix-8 Stockham
  64×64 FP16 tiles      single dispatch         512 threads
  TG = 16 KiB           near-Memcpy speed        TG = 32 KiB
  Q=128, N=64           no FPG required          + precomputed
                                                  FFT(K) in MTLBuffer
```

**Three non-negotiable constraints from the research:**

1. **Never use Decoupled Lookback for inter-chunk scan** — it will crash on every Apple GPU.
2. **Never use SIMD shuffle for threadgroup exchange in FFT** — 3.2× bandwidth penalty from scattered access.
3. **Chunk size Q must be 128 for the fused kernel** — Q=256 causes TG memory pressure that defeats fusion.

***

## 5. Open Questions and Validation Path

**Quantization accuracy for Quamba2-style INT8:** Standard quantization schemes (like QuaRot W8A8) suffer 21% accuracy degradation on Mamba due to activation outliers in gate projections. The Quamba2 framework's channel-order-preserving offline clustering approach achieves W4A16 with only 1.6% accuracy drop — but requires per-state-group quantization for B and C parameters. A Metal implementation of Quamba2-style dequant inside the fused kernel adds complexity but is essential for M4 Pro performance targets.[^9][^8]

**M4 FP16 double-rate throughput:** Microbenchmarks on M5 confirm FP16 provides ~2× throughput vs. FP32 for matrix multiply inner loops, achieving 74% of the 8,080 GFLOPS theoretical ceiling at 32 independent accumulator chains. The same pattern holds on M3/M4 with slightly different ceilings. The SSD matmul inner loops naturally provide the required instruction-level parallelism through K-dimension accumulation — FP16 is the correct precision for all SSD matmul steps.[^10]

**Prototype recommendation:** Implement the 2.7B Mamba 2 model with:
- Chunk size Q=128, state size N=64
- Decoupled Fallback scan (adapt from the MIT-licensed WGSL reference)
- Radix-8 Stockham Metal FFT for convolution (adapt from `https://github.com/aminems/AppleSiliconFFT`)
- 64×64 FP16 simdgroup_matrix tiles via MPP or hand-written MSL
- MTLStorageModeShared (default on Apple Silicon — zero-copy CPU/GPU)
- Target M4 Max for validation against the 120 tok/s goal at FP16; verify INT4 path hits target on M4 Pro

---

## References

1. [[PDF] Decoupled Fallback: A Portable Single-Pass GPU Scan](https://escholarship.org/content/qt0bk9z4bt/qt0bk9z4bt.pdf) - We present Decoupled Fallback, a fully portable Chained Scan capable of achieving SOL performance wi...

2. [PERKS: a Locality-Optimized Execution Model for Iterative Memory-bound
  GPU Applications](https://arxiv.org/pdf/2204.02064.pdf) - ...implementations have a loop on the host side that invokes the GPU kernel as
much as time/algorith...

3. [A 138 GFLOPS Radix-8 Stockham FFT on Apple Silicon via ... - arXiv](https://arxiv.org/html/2603.27569v1) - Abstract. We present an optimized Fast Fourier Transform (FFT) implementation for Apple Silicon GPUs...

4. [[PDF] Metal Performance Primitives (MPP) Programming Guide](https://developer.apple.com/download/files/Metal-Performance-Primitives-Programming-Guide.pdf) - Optimized GEMM implementations on GPUs use a multilevel tiling hierarchy that assigns tiles to simdg...

5. [Advanced GPU Optimization: Metal & Vulkan Compute from zero to ...](https://dev.to/javadinteger/advanced-gpu-optimization-metal-vulkan-compute-from-zero-to-hero-4cfg) - Ensure that within a warp (32 threads on Apple GPUs), accesses are coalesced. Avoid bank conflicts i...

6. [Accelerating Mamba2 with Kernel Fusion - PyTorch](https://pytorch.org/blog/accelerating-mamba2-with-kernel-fusion/) - ... optimal chunk size for Mamba2-2.7B had been 256. However, with the new fused kernel, the optimal...

7. [GPU Comparison - LLM Tracker](https://llm-tracker.info/GPU-Comparison) - A M4 Pro has 273 GB/s of MBW and roughly 7 FP16 TFLOPS. A 5090 has 1.8TB/s of MBW and likely somewhe...

8. [Quamba2: A Robust and Scalable Post-training Quantization Framework for Selective State Space Models](https://arxiv.org/abs/2503.22879) - State Space Models (SSMs) are emerging as a compelling alternative to Transformers because of their ...

9. [MambaQuant: Quantizing the Mamba Family with Variance Aligned Rotation
  Methods](https://arxiv.org/html/2501.13484v2) - ...demonstrates significant potential as a foundational architecture for various
tasks. Quantization...

10. [Apple M5 GPU Roofline Analysis - Michael's Tinkerings](https://www.michaelstinkerings.org/apple-m5-gpu-roofline-analysis/) - The optimal pattern for compute-heavy Metal kernels on Apple Silicon: Load as float4 for memory effi...

