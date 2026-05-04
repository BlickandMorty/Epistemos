# Ternary Tensor Operations — The Native Computational Primitive

## 1. Executive Summary

Recent work across the algorithm–architecture–systems stack has established that ternary `{-1, 0, +1}` is not merely an aggressive quantization target, but a **fundamentally different computational primitive**: one that replaces multiply-accumulate (MAC) with conditional add/subtract/no-op. On bandwidth-constrained edge CPUs, this shifts the bottleneck from memory to compute, unlocking up to `8×` effective bandwidth expansion and `2–4×` theoretical FLOP reduction. This document synthesizes primary-source findings from T-SAR (DATE 2026), FairyFuse (2026), ETH Zurich Sparse Ternary GEMM (2025), BitNet b1.58 (2024), Tequila (2025), and Apple M4 SME microarchitecture studies (2024) to answer ten specific research questions about implementing ternary transformers on Apple Silicon.

---

## 2. Key Findings

### 2.1 Data Layout and Packing on Apple Silicon

**Bit-packing density.** The dominant question for ternary weights is how many `{-1, 0, +1}` values to pack into a machine word.

- **FairyFuse packs 16 weights into 32 bits (2 bits/weight)** using the encoding `(1,0)=+1`, `(0,1)=-1`, `(0,0)=0`, with `(1,1)` unused. This yields **16× compression vs. FP32** and **4× vs. INT8** [^2974^].
- **ETH Zurich prototyped 5 ternary entries into one byte (1.6 bits/weight)** [^2832^]. This is denser than 2 bits/weight but requires lookup-table (LUT) decoding, which introduces memory pressure and irregular accesses.
- **T-SAR decomposes each ternary weight block into a dense binary mask** `w_D ∈ {-1,+1}` and a sparse binary mask `w_S ∈ {0,1}`. The dot product becomes `y = Σ w_D·a − Σ w_S·a`, requiring two binary LUTs of size `2^c` each (total `2^(c+1)` entries), which aligns cleanly to power-of-two SIMD register widths [^2979^].

**Apple Silicon tradeoff.** Apple M-series CPUs have 128-bit NEON vectors and (on M4) 2.3 TFLOPS FP32 SME matrix units. LUT-based packing (e.g., 5-in-8) forces memory traffic for LUT tables; direct bit-decode (e.g., 16-in-32 with BMI2-style extraction) is preferable for NEON because ARM lacks a direct `pext` equivalent, but **table-register shuffles** (`TBL`/`TBX`) on NEON can emulate masked add/sub with a small on-core LUT. T-MAC reports up to **4× throughput gain over llama.cpp on ARM CPUs (Apple M2 Ultra)** using VPSHUFB-style LUTs at 1–2 bits [^2974^], but FairyFuse argues that direct masked add/sub is superior on wide SIMD because it eliminates LUT memory pressure entirely [^2974^].

**Conclusion for Apple Silicon:** The optimal layout is a **direct 2-bit-per-weight pack (16 weights in 32 bits)** stored in row-major blocks, decoded via NEON `TBL` or scalar bit-extraction into `{+1, -1, 0}` masks, followed by masked `FMLA` (or simple add/sub on integer accumulators). For sparsity-aware kernels, the ETH Zurich **blocked interleaved TCSC** (Ternary Compressed Sparse Column) format with group size 4 is the highest-performing sparse layout on M1, achieving **5.98× speedup over naive TCSC** and **50.2% of peak FP32 performance** [^2832^].

### 2.2 Ternary Attention: Score Distributions and Implications

When both queries `Q` and keys `K` are ternary `{-1, 0, +1}`, each dot-product term `q_i · k_i` is also ternary `{-1, 0, +1}`. The attention score `S = QK^T` is therefore an integer bounded by `[-d_head, +d_head]`.

For a head dimension `d_head = 128` and per-element nonzero probability `p = 0.5` (typical under absmean quantization), the score distribution has:
- **Mean = 0** (symmetric ternary)
- **Variance per term = p² = 0.25**
- **Total variance = 128 × 0.25 = 32**
- **Standard deviation ≈ 5.66**
- **Typical dynamic range (±3σ) ≈ ±17**

This is an **extremely narrow dynamic range** compared to FP16 attention scores (which can span hundreds or thousands). The narrow range has three consequences:
1. **Low-precision softmax is viable.** The exponentiation `exp(S/√d)` can be computed with INT8 or even INT4 lookup tables because the input domain is small and discrete.
2. **Reduced KV-cache precision pressure.** If attention scores are low-entropy, the gradient signals backpropagated through attention are also low-entropy, which supports aggressive quantization of the value projection weights.
3. **Head collapse risk.** If too many `q` or `k` entries are zero (high sparsity), the effective rank of the attention map drops, potentially causing degenerate attention patterns. Tequila’s deadzone analysis shows that without reactivation, up to **>50% of weights can be trapped at zero**, severely impeding model capacity [^2980^]. This risk is especially acute in the attention `W_Q` and `W_K` matrices where sparsity directly reduces the rank of the query/key subspaces.

**Formal distribution:** If `q_i, k_i` are i.i.d. ternary with `P(+1)=P(-1)=p/2`, the score `S` follows an **Irwin–Hall-like distribution** over integers, well-approximated by `N(0, d_head·p²)` for large `d_head`.

### 2.3 Ternary Convolution / Linear Layers via Metal Performance Shaders

Metal Performance Shaders (MPS) provides high-level matrix multiplication (`MPSMatrixMultiplication`) and convolution (`MPSCNNConvolution`) kernels, but **does not natively support ternary or sub-8-bit weights** [^2015^]. MPS operations are black-box and target FP16/FP32 precision.

However, **custom Metal compute shaders can implement ternary GEMM/GEMV**:
- Metal Shading Language (MSL) supports bitwise operations, `select()` for masked operations, and threadgroup memory for on-chip LUTs.
- A custom compute shader can load a tile of FP16/BF16 activations into threadgroup memory, stream ternary weights from device memory (2-bit packed), decode them via bit-shift masks, and accumulate with `fma()` or simple `+`/`-`.
- The Draw Things project has already shipped **Metal Quantized Attention** with online INT8 quantization and INT8 matrix multiplication fused in custom MSL shaders, achieving **1.61–1.87× speedup over FP16** on Apple M5 Max [^3000^]. This proves the toolchain supports low-bit custom kernels.
- A FlashAttention-2 implementation in Metal for Apple Silicon (M1–M3) achieves **2–4× speedup over MLX** and **14–82× over PyTorch CPU** using custom tiled shaders with `float4` SIMD and 32×32 tiles [^3003^].

**Required kernels for ternary inference on Metal:**
1. **Ternary decode kernel:** Unpack 2-bit weights into `{-1, 0, +1}` masks (using bit shifts or threadgroup LUT).
2. **Masked GEMV/GEMM kernel:** For each 16-wide weight chunk, produce two masks (`pos_mask`, `neg_mask`) and issue `simd_shuffle` or `select`-based accumulation.
3. **Fused dequantization kernel:** Multiply the integer accumulator by `w_scale * x_scale / Q_b` (per BitNet scaling) in FP16/BF32.
4. **Attention kernel:** Fused ternary Q/K decode + narrow-range softmax (as described in §2.2).

**Verdict:** Ternary convolution cannot be done with stock MPS. It requires **custom MSL compute shaders**, but the toolchain (MSL, Metal command buffers, shared memory) is fully capable.

### 2.4 Theoretical FLOP Reduction

For a standard FP16 dense GEMM, each output element requires `K` multiply-accumulate operations (2 FLOPs per MAC: 1 multiply + 1 add).

For ternary GEMM with weight sparsity `s` (fraction of non-zero weights):
- **Zero weights:** no-op (0 FLOPs).
- **Non-zero weights:** add or subtract (1 FLOP).
- **Effective FLOPs per element:** `s × 1`.

| Weight sparsity | FP16 FLOPs | Ternary FLOPs | Reduction |
|-----------------|------------|---------------|-----------|
| 0% (dense)      | 2          | 1             | **2.00×** |
| 25%             | 2          | 0.75          | **2.67×** |
| 50% (typical)   | 2          | 0.5           | **4.00×** |
| 75%             | 2          | 0.25          | **8.00×** |

BitNet b1.58 absmean quantization with `Δ = γ/2` tends to push **~50% of weights to zero** under a Laplacian weight prior, making **4× FLOP reduction** a realistic central estimate [^2307^][^2980^].

**Important caveat:** On modern SIMD units, the instruction count reduction does not always translate to wall-clock speedup because:
- FP16 FMA instructions are heavily pipelined and can sustain 1 instruction per cycle.
- Masked add/sub on ternary weights may have lower throughput if the mask generation (bit decode) is on the critical path.
- T-SAR’s microarchitecture analysis shows that the ternary-to-binary decomposition allows reuse of existing SIMD ALU adder trees with only **3.2% power and 1.4% area overhead** [^2979^], suggesting that the FLOP reduction is indeed harvestable with minimal hardware change.

### 2.5 Sparsity × MLA: Multiplicative KV-Cache Reduction

Multi-Head Latent Attention (MLA) compresses the KV cache by storing a low-rank latent vector `c_t ∈ R^{d_c}` instead of full keys and values [^1203^]. For a standard MHA model, KV cache size per token is `2 × L × h × d_h` bytes (FP16). MLA reduces this to `L × d_c` bytes, where `d_c << 2 × h × d_h` (e.g., DeepSeek-V2 uses `d_c = 512` vs. `h × d_h = 64 × 128 = 8192`, an **~16× reduction**).

Ternary quantization of the KV-projections `W_K`, `W_V` (or the compressed latent projections) introduces two layers of savings:
1. **MLA structural compression:** Reduces the number of elements stored per token.
2. **Ternary element-wise compression:** Reduces bytes per stored element from 2 (FP16) to 0.25 (2-bit ternary).

**Combined effect:** If MLA alone gives `16×` and ternary packing gives `8×`, the total KV-cache footprint is theoretically reduced by **`128×`** for the cacheable projections. However, the cached latent `c_t` must be dequantized to FP16/BF16 at attention time to preserve accuracy, so the **multiplicative** benefit is realized only in memory capacity/bandwidth, not necessarily in compute. In practice, the achievable combined reduction is **~10–20×** because:
- The `W_K` and `W_V` up-projection matrices must still be held in ternary form (small, static).
- The latent `c_t` is cached at higher precision (INT8 or FP16) to avoid error accumulation over long contexts.
- The down-projection `W_{DKV}` is ternary, so its memory is negligible.

**Conclusion:** The interaction is **multiplicative in memory footprint** but **additive in wall-clock time** (the dominant cost is still the attention score computation, which benefits from MLA’s smaller KV but not from ternary weight packing unless Q/K are also ternary).

### 2.6 Optimal Block Size for Ternary GEMM on Apple M4 NEON/SME

Apple M4 is the first chip to ship ARM’s Scalable Matrix Extension (SME) [^2976^]. SME provides **2.3 FP32 TFLOPS** on a single performance core via outer-product instructions (`FMOPA`), but this is **FP32-centric**: FP16 and INT8 throughput through SME is comparatively low (only ~2× speedup over NEON for INT8) [^2976^].

For ternary GEMM, we cannot use SME `FMOPA` directly because it performs `C += outer(A, B)` with FP32 multiply. Instead, ternary GEMM on Apple M4 should target **NEON** with the following block parameters:
- **Vector width:** 128-bit NEON processes **4 FP32** or **8 FP16** or **16 INT8** lanes. For ternary bit-packed weights (2 bits), a 128-bit load brings **64 weights**. Decoding 64 weights into add/sub masks requires ~10–12 NEON instructions (shifts, masks, compares).
- **Activation tile:** The ETH Zurich study found that **loop unrolling factor 12** and **blocked interleaved TCSC with group size 4** maximized ILP on Apple M1 [^2832^]. Extrapolating to M4’s wider decode and higher frequency, an **activation tile of 16–32 FP32 elements** (4–8 NEON vectors) with **12–16 unroll depth** is the optimal starting point.
- **Output tile:** For GEMV (decode-dominant), output-stationary tiling with `m = 16` outputs per thread (matching T-SAR’s TGEMV configuration) amortizes LUT/decode cost across multiple accumulators [^2979^].
- **SME workaround:** Although SME lacks native ternary support, one can load FP32 activations into SME vectors and use predicate masking to skip multiply operations where weights are zero. However, the overhead of predication and the FP32-only nature of SME make this **uncompetitive with a well-tuned NEON kernel** for ternary workloads.

**Recommended block size for Apple M4 NEON ternary GEMM:**
```
Activation tile:  16 FP32 (64 bytes, 1 cache line)
Weight chunk:     64 ternary weights (16 bytes, 128-bit vector)
Unroll factor:    12–16 (amortizing decode overhead)
Output tile:      16 channels (OP dataflow) or 1 channel (AP dataflow)
```

### 2.7 T-SAR Decomposition in Metal

T-SAR’s ternary-to-binary decomposition expresses the ternary dot product as the **difference of two binary dot products** [^2979^]:

```
w ∈ {-1, 0, +1}
w_D = {-1, +1}  (dense: replace 0 with +1)
w_S = {0, 1}    (sparse: 1 where original w was 0)
y = Σ w_i·a_i = Σ w_D,i·a_i − Σ w_S,i·a_i
```

This maps naturally to Metal:
1. **Offline:** Pack `w_D` as 1-bit signs and `w_S` as 1-bit zero-masks. Each original ternary weight consumes **2 bits** (same as FairyFuse), but the semantic split enables binary-LUT GEMM.
2. **Online (threadgroup LUT):** Precompute a small LUT of size `2^c` for the activation block (e.g., `c=2` gives 4 entries). Two LUTs (`D_LUT` and `S_LUT`) are generated in threadgroup/shared memory per tile.
3. **GEMM:** Use Metal SIMD-group reductions or `simd_shuffle` to accumulate the two binary products, then subtract.

The LUT generation step (`TLUT_c×s` in T-SAR) is a **register-resident table fill** that avoids DRAM traffic entirely. In MSL, this can be done with a small `constexpr` array or threadgroup broadcast. The subtraction to recover the ternary result is a single `simd_sub` per output tile.

**Feasibility:** **Yes**, the T-SAR decomposition can be implemented in Metal. It is particularly attractive because it replaces the irregular control flow of per-weight `if (w==+1) acc+=a; else if (w==-1) acc-=a;` with **uniform LUT lookups + a final subtraction**, which maps well to GPU SIMT execution.

### 2.8 Activation Precision Requirements

Even when weights are ternary, activations must maintain higher precision to prevent error accumulation across deep Transformer stacks.

| Component | BitNet b1.58 | FairyFuse | T-SAR | Practical Apple Silicon |
|-----------|--------------|-----------|-------|------------------------|
| **Weights** | 1.58-bit ternary | 2-bit ternary | 2-bit ternary | 2-bit ternary |
| **Activations** | 8-bit INT (absmax per-token) | FP32 (decode) | INT8 | **FP16/BF16** or **INT8** |
| **Accumulation** | INT32 → FP32 dequant | FP32 | INT16/INT32 | **FP32** |
| **Dequantization** | Per-channel `γ·β` | Per-channel scalar | Per-block scale | Per-channel / per-token |

- **BitNet b1.58** quantizes activations to **8-bit integers** using `absmax` per-token scaling: `x_q = clamp(round(x · Q_b / γ_x), -Q_b, Q_b-1)` [^2307^][^2985^].
- **FairyFuse** keeps activations in **FP32** during the masked add/sub accumulation and applies per-channel FP32 scales only at the end of the GEMV [^2974^]. This is simple but memory-bandwidth-heavy for activation tiles.
- **T-SAR** uses **INT8 activations** and generates **INT16 LUTs** inside SIMD registers, keeping accumulation in INT16/INT32 [^2979^].

**Recommendation for Apple Silicon:** Use **FP16 or BF16 activations** with **FP32 accumulators**. The Apple GPU and NEON both have native FP16/BF16 support, and FP32 accumulation is standard in Metal. INT8 activations are viable (the Neural Engine supports INT8 natively), but mixed-precision INT8×ternary kernels do not yet exist in public libraries. A practical first build is:
1. Activations: FP16 (per-token RMSNorm, no quantization).
2. Weights: 2-bit ternary, decoded to `{-1, 0, +1}` masks.
3. GEMM: FP16 activation × ternary mask → FP32 accumulator.
4. Output: Cast back to FP16/BF16 for the next layer.

This matches the **W2A16** (2-bit weights, 16-bit activations) pattern used in llama.cpp Q2_K and avoids the accuracy degradation of aggressive activation quantization.

### 2.9 BitNet b1.58 AbsMean Scaling and the Information Bottleneck

BitNet b1.58 quantizes weights with **absmean scaling**:

```
γ = (1/nm) Σ |W_ij|
w_q = clamp(round(W / γ), -1, +1)
```

With `Δ = γ/2`, the deadzone `|W| < γ/2` collapses to zero. Under a Laplacian or Gaussian weight prior, this deadzone captures **a large fraction of weights** (empirically >50% in later layers) [^2980^]. From an information-theoretic perspective:

- **Entropy of ternary weights:** `H ≤ 1.58 bits` (the naming origin). If `P(0) ≈ 0.5`, `P(+1) ≈ P(-1) ≈ 0.25`, then `H ≈ 1.5 bits`, close to the limit.
- **Information bottleneck:** The deadzone acts as a **hard thresholding operator**, zeroing out small weights that may carry fine-grained gradient signal. Tequila identifies this as **deadzone trapping**: weights oscillate around `±Δ`, receiving noisy, uninformative STE gradients, and become permanently inactive [^2980^]. This reduces effective model capacity by up to **50%**.
- **Scaling factor γ as a bandwidth control:** `γ` sets the quantization step size. A smaller `γ` reduces the deadzone, preserving more weights as non-zero, but increases clamping error for large weights. A larger `γ` sparsifies more aggressively, saving memory but bottlenecking information.

Tequila’s solution is to **repurpose dead weights as dynamic biases**:

```
Y = X · W_q · γ + Σ_{i∈D} λ·w_i
```

The bias term `Σ λ·w_i` is precomputed offline (nearly zero inference overhead) and provides a **residual channel for information** that bypasses the ternary bottleneck. This restores model capacity and yields gradients `∂L/∂w_i = x_i·∂L/∂Y + λ·∂L/∂Y` that are non-zero even inside the deadzone [^2980^].

**Practical implication:** If you are building a ternary kernel stack on Apple Silicon, you should **either** (a) use Tequila-style dynamic bias compensation during training, or (b) keep the final projection layer and attention out-projection in higher precision (FP16) to avoid the information bottleneck.

### 2.10 End-to-End Speedup for Qwen3-8B on Apple M4 Max

**Bandwidth-bound decode phase:**
- Qwen3-8B FP16/BF16 model size: **16 GB** (8B params × 2 bytes).
- Ternary model size: **2 GB** (8B params × 0.25 bytes).
- Apple M4 Max memory bandwidth: **410–546 GB/s** [^3005^][^3009^].
- Theoretical decode throughput (weight-bound) with 70% bandwidth efficiency:
  - FP16: `546 GB/s / 16 GB ≈ 34 tok/s` → `×0.7 = ~24 tok/s`.
  - Ternary: `546 GB/s / 2 GB ≈ 273 tok/s` → `×0.7 = ~191 tok/s`.
  - **Theoretical speedup: 8×** (purely from weight memory reduction).

**Realistic factors that reduce the speedup:**
1. **KV cache bandwidth:** FP16 KV cache adds ~0.59 MB/token (for 36 layers, 4096 hidden size). Even with KV cache, total bytes/token drops from ~16.6 GB to ~2.6 GB (still **~6.4×** reduction).
2. **Attention compute:** Softmax and masking remain FP16-heavy. FlashAttention-2 on Apple Silicon is already memory-efficient but not ternary-aware [^3003^].
3. **Kernel efficiency:** ETH Zurich’s best scalar ternary kernel reaches **50.2% of peak** on M1 [^2832^]; FairyFuse reaches ~65% of theoretical on Xeon [^2974^]. Assuming **50% efficiency** for a mature Apple M4 NEON ternary kernel:
   - Ternary decode: `191 × 0.5 ≈ 95 tok/s`.
   - FP16 baseline (MLX, ~70% efficiency): `34 × 0.7 ≈ 24 tok/s`.
   - **Realistic decode speedup: ~4×**.
4. **Non-linear layers:** RMSNorm, SwiGLU, and RoPE are still FP16. They constitute ~15–20% of wall-clock time in decode, diluting the linear-layer speedup.
5. **Prefill phase:** Compute-bound. Ternary reduces FLOPs by ~2–4× (depending on sparsity), but attention dominates for long contexts. T-SAR reports **5.6–24.5× GEMM latency reduction** for prefill on x86 [^2979^]; on M4 Max with SME, a conservative estimate is **2–3×** prefill speedup for short contexts (up to 2k tokens).

**End-to-end estimate for Qwen3-8B (all linear layers ternary) on Apple M4 Max (546 GB/s):**

| Phase | FP16 Baseline | Ternary Target | Realistic Speedup |
|-------|---------------|--------------|-------------------|
| **Prefill** (1k tokens) | ~40 tok/s-equivalent | ~100–120 | **2.5–3.0×** |
| **Decode** (per-token) | ~24–30 tok/s | ~80–110 | **3.0–4.5×** |
| **End-to-end** (mixed) | ~25 tok/s | ~85 tok/s | **~3.4×** |

This assumes a production-quality ternary inference stack (comparable to FairyFuse on x86 or T-MAC on ARM). In the near term, with reference-quality kernels, a **1.5–2.5×** speedup vs. FP16 is the more conservative build target.

---

## 3. Formal Definitions

### 3.1 Ternary Quantization Function

Given a full-precision weight matrix `W ∈ R^{m×n}`, the BitNet b1.58 absmean quantizer is:

```
γ = (1 / (m·n)) Σ_{i,j} |W_ij|
Ŵ = clamp(round(W / (γ + ε)), -1, +1)    // ε for numerical stability
W_q = Ŝ · γ
```

where `Ŝ ∈ {-1, 0, +1}^{m×n}` is the ternary sign matrix.

### 3.2 Ternary-to-Binary Decomposition (T-SAR)

For any ternary vector `w ∈ {-1, 0, +1}^c`:

```
w_D = {-1, +1}^c   where w_D,i = w_i if w_i ≠ 0, else +1
w_S = {0, 1}^c     where w_S,i = 1 if w_i = 0, else 0
a ∈ R^c            // activations

w · a = Σ w_D,i · a_i  −  Σ w_S,i · a_i
```

This converts one ternary dot product into **two binary dot products** and a subtraction.

### 3.3 FairyFuse Bit Packing

A 32-bit word `p` encodes 16 ternary weights using 2 bits per weight:

```
encode(+1) = (1, 0)     // bit1=1, bit0=0
encode(-1) = (0, 1)
encode( 0) = (0, 0)
```

Decode masks (BMI2 `pext` on x86; equivalent bit shifts on NEON):

```
k_pos = pext(p, 0xAAAAAAAA)   // extract even bits
k_neg = pext(p, 0x55555555)   // extract odd bits
```

Masked accumulation (AVX-512 pseudocode; NEON analog uses `vbsl` or `vadd`/`vsub` with predicates):

```
acc = mask_add(acc, k_pos, acc, X)   // X = activation tile
acc = mask_sub(acc, k_neg, acc, X)
```

### 3.4 Tequila Dynamic Bias Compensation

For deadzone weights `D = {i | |w_i| < Δ}`:

```
Y = X^T · Ŝ · α + Σ_{i∈D} λ·w_i
```

where `λ` is a learnable reactivation parameter. The bias term `B = Σ_{i∈D} λ·w_i` is precomputed offline per output channel and fused into the kernel.

### 3.5 Ternary Attention Score Distribution

For `Q, K ∈ {-1, 0, +1}^{seq×d_head}` with i.i.d. entries and per-entry nonzero probability `p`:

```
S = QK^T / sqrt(d_head)
E[S] = 0
Var[S] = (d_head · p²) / d_head = p²   // per-element before scaling
Std[S] = p · sqrt(d_head) / sqrt(d_head) = p   // wait, careful:
// Correct: score before sqrt-div is Σ_{k=1}^{d_head} q_k·k_k
// Var(Σ q_k·k_k) = d_head · Var(q_k·k_k) = d_head · p²
// After dividing by sqrt(d_head): Var(S) = p² · d_head / d_head = p²
// Actually: Var(S) = d_head · p² / d_head = p²? No.
// Let T = Σ q_k·k_k. Var(T) = d_head · p². Then S = T / sqrt(d_head).
// Var(S) = Var(T) / d_head = p².
```

So `Std(S) = p`. For `p = 0.5`, `Std(S) = 0.5`. The scaled score `S` (post `/√d`) is a **narrow-band signal** suitable for low-bit softmax tables.

---

## 4. Tensions and Counter-Arguments

### 4.1 LUT vs. Direct Masked Arithmetic

- **Pro-LUT (T-MAC, Tequila, ETH Zurich):** LUTs eliminate per-weight branching and can exploit sub-byte packing (e.g., 5 weights/byte). On ARM, `VPSHUFB`-style table lookups are efficient for 128-bit lanes. T-MAC reports **4× speedup on Apple M2 Ultra** [^2974^].
- **Pro-Direct (FairyFuse):** LUTs consume on-chip memory (L1/L2 bandwidth) and cause irregular accesses. Direct masked add/sub uses existing wide SIMD datapaths (AVX-512 or NEON) with **zero multiplication and zero LUT traffic** [^2974^].
- **Resolution:** On Apple Silicon with 128-bit NEON, the LUT footprint is small enough to fit in threadgroup/shared memory. A hybrid strategy—**LUT for small tiles (c ≤ 4) and direct masked arithmetic for large tiles**—likely offers the best of both worlds.

### 4.2 Sparsity: Gift or Curse?

- **Gift:** Zero weights reduce FLOPs and model size. A 50% sparse ternary matrix uses only 1 FLOP per effective MAC vs. 2 FLOPs for FP16.
- **Curse:** High sparsity collapses the effective rank of weight matrices. Tequila shows that naive absmean quantization traps **>50% of weights at zero**, causing >5% accuracy drop vs. full precision [^2980^]. The information bottleneck is real.
- **Resolution:** Tequila’s dynamic bias reactivation recovers accuracy within **<1% of FP16** while preserving the hardware efficiency of ternary inference. Any production ternary stack on Apple Silicon should integrate Tequila or an equivalent deadzone-recovery mechanism.

### 4.3 SME (M4) Irrelevance for Ternary

- **Observation:** Apple M4’s SME delivers **2.3 FP32 TFLOPS** but is FP32-centric; INT8 SME only achieves ~2× speedup over NEON, and there is no native ternary path [^2976^].
- **Counter:** The FP32-centric design means SME is optimized for HPC-style GEMM, not sub-byte inference. A ternary kernel should target **NEON + custom Metal shaders**, not SME.
- **Caveat:** If activations are kept in FP32 (e.g., for research/debugging), SME could be used for the final FP32 accumulation tile, but the weight decode overhead would likely negate the benefit.

### 4.4 FlashAttention and Low-Precision Attention

- **Tension:** FlashAttention-3 achieves **1.5–2.0× speedup** with FP8 on H100 by leveraging hardware-native FP8 tensor cores [^2983^]. Apple Silicon has no native FP8/ternary tensor cores.
- **Counter:** Draw Things has shipped **Metal Quantized Attention** with online INT8 quantization, achieving **1.24–1.41× speedup** over FP16 FlashAttention on M5 Max [^3000^]. This demonstrates that low-bit attention is viable via custom MSL shaders even without hardware-native support.
- **Implication:** A ternary attention kernel (Q/K in 2-bit, V in FP16/INT8) is buildable but requires a from-scratch MSL shader, not MPS.

### 4.5 Mixed-Precision Stability

- **Tension:** Industry practice keeps activations at FP16/BF16 even when weights are INT4 because activation ranges are "spiky" and input-dependent [^2990^]. Pushing activations to INT8 without QAT causes accuracy regressions on math and coding tasks.
- **Counter:** BitNet b1.58 trains from scratch with **8-bit activations** and matches FP16 perplexity at ≥3B scale [^2307^]. BitNet b1.58 2B4T uses **squared ReLU** and subln normalization to stabilize low-bit training [^2982^].
- **Practical guidance:** For on-device Apple Silicon inference of pretrained models, use **W2A16** (ternary weights, FP16 activations) with FP32 accumulators. If training from scratch, **W2A8** is viable.

---

## 5. Buildable Elements

### 5.1 Immediate Implementation (Weeks)

1. **NEON Ternary GEMV Kernel (CPU)**
   - Pack weights: 16 weights → `uint32_t` (2 bits/weight).
   - Decode: Use NEON `vshr_n_u32` + `vand_u32` to extract even/odd bits into two `uint16x4_t` masks.
   - Accumulate: Use `vbsl_f32` (bitwise select) to drive `vadd_f32`/`vsub_f32` on FP32 activation tiles.
   - Target: Apple M4 performance core, single-threaded decode for 7–8B models.

2. **Metal Compute Shader for Ternary GEMM (GPU)**
   - Custom MSL kernel: load 128-bit weight vectors (64 ternary values), decode to `+1/-1/0` masks with bit shifts.
   - Load FP16 activation tile into threadgroup memory.
   - Accumulate with `fma()` or `+`/`-` into FP32 local registers.
   - Fuse per-channel scale multiplication at tile boundary.
   - Integrate into MLX or llama.cpp Metal backend.

3. **Tequila Bias Fuser**
   - Offline pass: compute `B = Σ_{i∈D} λ·w_i` per output channel.
   - Fuse `B` into the existing bias vector of each `nn.Linear`.
   - Zero runtime overhead; accuracy recovery <1% vs. FP16 [^2980^].

### 5.2 Medium-Term (Months)

4. **Blocked Interleaved TCSC Sparse Kernel**
   - Port ETH Zurich’s scalar/vectorized sparse ternary GEMM to Apple M4 NEON with SVE-style predication (if available in future chips) or emulate with `vld1q_u8` gathers.
   - Optimize group size and block size via auto-tuning (grid search over {4,8,12,16} unroll factors).

5. **Ternary FlashAttention Shader**
   - Implement Q/K ternary packing in MSL.
   - Compute attention scores in INT8 or INT16 (range ±17 for d=128, p=0.5).
   - Online softmax with small LUT (`exp(x)` for x ∈ [-20, +20] in INT8 steps).
   - Benchmark vs. MLX FlashAttention and Draw Things Metal Attention.

6. **MLA + Ternary KV Cache Stack**
   - Compress KV projections to ternary down-projectors (`W_DKV`).
   - Cache latent `c_t` in INT8 or FP16.
   - Implement low-rank decompression (`W_UK`, `W_UV`) with ternary weights in Metal.

### 5.3 Research-Grade (Open Questions)

7. **SME-Aware Ternary Microkernel**
   - Even though SME is FP32-centric, explore using `FMOPA` with **binary-valued FP32 activations** (e.g., `+1.0` / `-1.0`) to emulate ternary multiply via `C += outer(A_binary, B_binary)` and then subtract the zero-mask contribution. This is the Metal equivalent of T-SAR’s decomposition.
   - Measure whether the SME bandwidth (2.3 TFLOPS) can be exploited despite the emulation overhead.

8. **Adaptive Block Size Scheduler**
   - T-SAR’s software layer adaptively selects AP vs. OP dataflow per layer [^2979^]. Build an Apple Silicon equivalent that profiles each linear layer at runtime (dense vs. sparse, activation reuse vs. output channels) and dispatches to the optimal microkernel.

---

## 6. Theoretical Foundations

### 6.1 Proven

- **Ternary packing reduces memory traffic by 8× vs. FP16** (16× vs. FP32). This is arithmetic, not conjecture.
- **FairyFuse achieves zero FP-multiplication inner loops** on x86 AVX-512, verified by assembly inspection [^2974^].
- **T-SAR’s ternary-to-binary decomposition is exact:** `Σ w·a = Σ w_D·a − Σ w_S·a` with no approximation error [^2979^].
- **Tequila’s dynamic bias restores deadzone-trapped weights to within <1% accuracy of FP16** on LLaMA 3.2 and Qwen3, proven by 10B-token QAT experiments [^2980^].
- **Apple M4 SME achieves >2.3 FP32 TFLOPS** and outperforms Accelerate BLAS in almost all tested small-GEMM configurations [^2976^].
- **ETH Zurich Sparse Ternary GEMM reaches 50.2% of theoretical peak** on Apple M1 with blocked interleaved TCSC [^2832^].
- **FlashAttention-3 FP8 achieves 2.6× lower numerical error than baseline FP8 attention** via block quantization and incoherent processing [^2983^].

### 6.2 Conjectured / Engineering-Open

- **Optimal NEON ternary block size for M4:** The {12-unroll, 16-tile} recommendation is extrapolated from M1 scalar data and SME microbenchmarks. No published study has validated this exact configuration.
- **End-to-end 3–4× speedup for Qwen3-8B on M4 Max:** This assumes a kernel efficiency of ~50% and pure memory-bound decode. Actual numbers will depend on the maturity of the ternary kernel, the fraction of time spent in non-linear layers, and KV-cache quantization strategy.
- **Ternary attention rank collapse:** The statistical argument (§2.2) is first-principles; no published work has empirically measured the effective rank of ternary attention maps in a production LLM.
- **SME emulation of ternary ops:** The idea to use `FMOPA` with binary FP32 vectors is theoretically sound but untested on real M4 silicon. It may fail due to predicate-setup overhead.

---

## 7. References

1. **T-SAR** — Oh et al., *T-SAR: A Full-Stack Co-design for CPU-Only Ternary LLM Inference via In-Place SIMD ALU Reorganization*, arXiv:2511.13676 [cs.AR], 2025. https://arxiv.org/abs/2511.13676 [^2979^]
2. **FairyFuse** — Zuo et al., *FairyFuse: Multiplication-Free LLM Inference on CPUs via Fused Ternary Kernels*, arXiv:2604.20913 [cs.LG], 2026. https://arxiv.org/abs/2604.20913 [^2974^]
3. **ETH Zurich Sparse Ternary GEMM** — *Accelerating Sparse Ternary GEMM for Quantized LLM inference on Apple Silicon*, arXiv:2510.06957 [cs.DC], 2025. https://arxiv.org/abs/2510.06957 [^2832^]
4. **BitNet b1.58 (Original)** — Ma et al., *The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits*, arXiv:2402.17764 [cs.CL], 2024. https://arxiv.org/abs/2402.17764 [^2307^]
5. **BitNet b1.58 Reloaded** — *BitNet b1.58 Reloaded: State-of-the-art Performance Also on Smaller Networks*, arXiv:2407.09527 [cs.LG], 2024. https://arxiv.org/abs/2407.09527 [^2977^]
6. **BitNet b1.58 2B4T Technical Report** — arXiv:2504.12285 [cs.CL], 2025. https://arxiv.org/abs/2504.12285 [^2982^]
7. **Tequila** — *Tequila: Trapping-free Ternary Quantization for Large Language Models*, arXiv:2509.23809 [cs.LG], 2025. https://arxiv.org/abs/2509.23809 [^2980^]
8. **Hello SME** — Remke & Breuer, *Hello SME! Generating Fast Matrix Multiplication Kernels Using the Scalable Matrix Extension*, arXiv:2409.18779 [cs.DC], 2024. https://arxiv.org/abs/2409.18779 [^2976^]
9. **Apple vs. Oranges (M-Series HPC Review)** — *Apple vs. Oranges: Evaluating the Apple Silicon M-Series SoCs for HPC Performance and Efficiency*, arXiv:2502.05317 [cs.AR], 2025. https://arxiv.org/abs/2502.05317 [^2015^]
10. **FlashAttention-3** — Dao et al., *FlashAttention-3: Fast and Accurate Attention with Asynchrony and Low-precision*, arXiv:2407.08608 [cs.LG], 2024. https://arxiv.org/abs/2407.08608 [^2983^]
11. **Metal Quantized Attention (Draw Things)** — *Metal Quantized Attention: pulling M5 Max ahead with Int8 matrix multiplication*, 2026. https://releases.drawthings.ai/p/metal-quantized-attention-pulling [^3000^]
12. **Flash Attention Metal (GitHub)** — *Flash Attention for Apple Silicon Using metal-cpp*, 2025. https://github.com/harvestingmoon/flash_attn_metal_cpp [^3003^]
13. **Mixed-Precision Quantization Survey** — *Mixed-Precision Quantization for Language Models*, arXiv:2510.16805 [cs.CL], 2025. https://arxiv.org/abs/2510.16805 [^3001^]
14. **DeepSeek MLA / MHA2MLA** — Guo et al., *Towards Economical Inference: Enabling DeepSeek's Multi-Head Latent Attention in Any Transformer-based LLMs*, arXiv:2502.14837 [cs.CL], 2025. https://arxiv.org/abs/2502.14837 [^1203^]
15. **Apple M4 Max Specifications** — Apple Support, *MacBook Pro (14-inch, M4 Pro or M4 Max, 2024)*, 2024. https://support.apple.com/en-us/121553 [^3006^]
16. **Apple M4 Family Comparison** — Ars Technica, *Apple’s M4, M4 Pro, and M4 Max compared*, 2024. https://arstechnica.com/apple/2024/10/apples-m4-m4-pro-and-m4-max-compared/ [^3009^]
17. **Qwen3 Speed Benchmark** — Qwen Documentation, *Speed Benchmark*, 2025. https://qwen.readthedocs.io/en/latest/getting_started/speed_benchmark.html [^2996^]
18. **BitNet b1.58 Blog Analysis (AbsMean Code)** — Youngju.dev, *BitNet Paper Analysis*, 2026. https://www.youngju.dev/blog/ai-papers/2026-03-06-ai-papers-bitnet-1bit-llm-ternary-weight-inference.en [^2985^]
19. **Precision-to-Quantization Guide (DeepInfra)** — *From Precision to Quantization: A Practical Guide to Faster, Cheaper LLMs*, 2026. https://deepinfra.com/blog/precision-to-quantization-faster-cheaper-llms [^2990^]
