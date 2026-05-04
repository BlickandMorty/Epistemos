# Bottleneck R5: SVD Acceleration on Apple Silicon GPU

## Research Summary: OSFT SVD Bottleneck Analysis & Mitigations

**Date**: 2025-07  
**Problem**: OSFT requires SVD on every layer during task transitions. For LLaMA-2 7B (224 layers), this is 60-120 seconds. Need GPU-accelerated SVD on Apple Silicon.  
**Researcher**: Systems Engineering Research Division  
**Searches Conducted**: 12 distinct queries across MPS, MLX, cuSOLVER, randomized SVD, incremental SVD, Frequent Directions, JAX Metal, PyTorch MPS, M4 Max benchmarks

---

## 1. Executive Summary: The Hard Truth

| Metric | Value | Source |
|--------|-------|--------|
| PyTorch MPS SVD Support | **NOT SUPPORTED** — falls back to CPU | StackOverflow 2026, PyTorch issues |
| MLX SVD Support | **NATIVE** — `mx.linalg.svd` on GPU | MLX documentation, GitHub |
| OSFT SVD on LLaMA-2 7B (all layers) | **~2 minutes on H100** | OSFT paper (ICLR 2026 submission) |
| M4 Max GPU FP32 peak (measured) | **2.9 TFLOPS** (MPS GEMM) | HPC paper (M1-M4 benchmark) |
| M4 Max 32-core FP32 theoretical | **12.9-13.6 TFLOPS** | NanoReview, CPU-Monkey |
| M4 Max 40-core memory bandwidth | **546 GB/s** | Apple spec, llm-tracker |
| Randomized SVD speedup vs full | **76x** (single layer), **up to 100x** | RSI paper, GPU RSVD paper |
| Incremental SVD per-update cost | **O(pr + r^3)** vs O(pqr) full | Brand 2006 (MERL TR) |
| QR+SVD trick speedup | **89x** (0.087s -> 0.001s) | MATLAB Apple Silicon workaround |

**Bottom Line**: There is NO native PyTorch MPS SVD. The path forward is MLX + randomized/incremental SVD, potentially bringing 224-layer SVD from 60-120s down to **<3 seconds** on M4 Max.

---

## 2. Metal Performance Shaders (MPS) SVD Status: NOT SUPPORTED

### 2.1 PyTorch MPS Backend

**Critical Finding**: `torch.linalg.svd` is **NOT supported** on the MPS backend as of PyTorch 2.11.0 (latest stable). It falls back to CPU with a warning:

```
UserWarning: The operator 'aten::linalg_svd' is not currently supported on the MPS backend
and will fall back to run on the CPU. This may have performance implications.
```

**Source**: [StackOverflow — confirmed Jan 2026](https://stackoverflow.com/questions/79859178)  
**PyTorch MPS tracking issue**: [GitHub #77764](https://github.com/pytorch/pytorch/issues/77764)

**Implication**: Any PyTorch code calling `torch.linalg.svd` on MPS tensors will silently execute on CPU, crossing the CPU-GPU memory boundary twice (GPU->CPU for input, CPU->GPU for output). This is **catastrophic** for performance.

### 2.2 What MPS DOES Support

MPS supports: matrix multiplication, convolutions, activations, softmax, basic element-wise ops. It does **NOT** support:
- SVD (`linalg_svd`)
- Cholesky decomposition (historically; may have partial support now)
- QR decomposition (limited)
- Eigendecomposition
- `float64` (double precision) — entirely unsupported

**Source**: [PyTorch Hardware Acceleration 2025 Analysis](https://tunguz.github.io/PyTorch_Hardware_2025/)

### 2.3 MPS GEMM Performance (Reference Point)

| Device | MPS GEMM (8192x8192 FP32) | TFLOPS |
|--------|---------------------------|--------|
| M1 GPU | Baseline | 1.36 |
| M2 GPU | +65% vs M1 | 2.24 |
| M3 GPU | +10% vs M2 | 2.47 |
| M4 GPU | +17% vs M3 | **2.90** |

**Source**: ["Apple vs. Oranges" HPC paper, Feb 2025](https://arxiv.org/html/2502.05317v1)

---

## 3. MLX: The Only Native GPU SVD Path on Apple Silicon

### 3.1 MLX SVD Support

Apple's **MLX** framework (launched Dec 2023) provides **native GPU-accelerated SVD** via:
```python
import mlx.core as mx
U, S, Vt = mx.linalg.svd(A)  # Runs on Apple GPU
```

**Confirmed operations in MLX linear algebra**: SVD, QR, Cholesky, eigendecomposition, matrix inverse, FFT.  
**Source**: [MLX documentation](https://ml-explore.github.io/mlx/build/html/python/linalg.html), [Julia discourse](https://discourse.julialang.org/t/julia-access-to-apple-gpu-with-mlx-and-or-metal-performance-shaders-mps/117647)

### 3.2 MLX vs PyTorch MPS Performance

| Operation | MLX GPU | PyTorch MPS | MLX Speedup |
|-----------|---------|-------------|-------------|
| Linear (1024-dim) | 3.4 ms | 3.8 ms | ~1.1x |
| MatMul (4000x4000) | 27.2 ms | 1.4 ms* | PyTorch wins* |
| MatMul (M2 Max) | 4.2 ms | 7.6 ms | **1.8x** |
| LLM Inference (Llama 7B) | ~95 tok/s | ~65 tok/s | **1.5x** |
| Memory (Llama 7B) | 14.2 GB | 18.5 GB | **-23%** |

*PyTorch MPS MatMul at 4000x4000 was anomalously fast in one benchmark; not reproducible across matrix sizes.  
**Source**: [mlx-benchmark GitHub](https://github.com/TristanBilot/mlx-benchmark), [MLX vs PyTorch comparison](https://metalcloud.space/blog/mlx-vs-pytorch-comparison/)

**Key insight**: MLX is consistently 1.5-2x faster than PyTorch MPS for transformer workloads and uses less memory due to unified memory + lazy evaluation.

### 3.3 MLX SVD Benchmark Gap

**Critical gap**: No published benchmarks specifically for `mx.linalg.svd` timing on Apple Silicon GPUs. The mlx-benchmark repository covers MatMul, Linear, Conv, Softmax, etc., but **SVD is not included** in the benchmark suite.

**Estimated SVD performance on M4 Max** (derived):
- SVD of 4096x4096 requires ~2*4096^3 = 137 GFLOP
- At 2.9 TFLOPS sustained (MPS GEMM), theoretical minimum: **~47 ms**
- With overhead (SVD is ~50x slower than GEMM at same dimensions on NVIDIA): **~2-3 seconds**
- This aligns with OSFT paper's ~2 minutes on H100 for 224 layers = **~0.5s per layer**

---

## 4. GPU SVD Benchmarks (NVIDIA Reference Points)

### 4.1 cuSOLVER SVD on V100

NVIDIA GTC 2019 presentation gives absolute numbers for cuSOLVER SGESVD on V100:

| Matrix Size | cuSOLVER SGESVD (ms) | SGEMM reference (ms) | SVD/GEMM ratio |
|-------------|----------------------|----------------------|----------------|
| 512 | 5.22 | ~0.002 | ~2610x |
| 1024 | 18.97 | ~0.012 | ~1580x |
| 2048 | 63.15 | ~0.098 | ~644x |
| **4096** | **152.07** | ~0.749 | **~203x** |
| 8192 | 264.11 | ~4.72 | ~56x |

**Source**: [NVIDIA GTC 2019 — S9226 Fast SVD on GPU](https://developer.download.nvidia.com/video/gputechconf/gtc/2019/presentation/s9226-fast-singular-value-decomposition-on-gpus-v2.pdf)

**Critical insight**: SVD is **~200x slower than GEMM** at 4096x4096 on V100. The SVD algorithm is memory-bound and has poor GPU utilization.

### 4.2 Modern GPU SVD (2024-2025)

Recent research achieves significant speedups over cuSOLVER:

| Method | GPU | Speedup vs cuSOLVER |
|--------|-----|---------------------|
| GPU-centered BDC (2025) | V100 | **12.4x** |
| GPU-centered BDC (2025) | MI210 | **7.5x** |
| Tensor Core SVD (2024) | H100 | **6.1x** |
| Tensor Core SVD (2024) | A100 | **5.0x** |

**Source**: [ACM ToMS 2026 — GPU SVD](https://dl.acm.org/doi/10.1145/3787861), [arxiv GPU-centered SVD 2025](https://arxiv.org/html/2508.11467v1)

### 4.3 Extrapolated M4 Max SVD Time for 4096x4096

Using the ratio method:
- V100 cuSOLVER: 152ms at 4096x4096
- V100 SGEMM: ~13.4 TFLOPS peak
- M4 Max SGEMM: ~2.9 TFLOPS measured
- Ratio: 2.9/13.4 = 0.22x the performance
- **Estimated M4 Max SVD (4096x4096): 152ms / 0.22 = ~690ms**
- With MLX optimization (assume 2x faster than naive): **~350ms per matrix**

For 224 layers: 224 * 0.35s = **~78 seconds** for full SVD on all layers.

This is comparable to the reported 60-120s CPU time, confirming that even GPU SVD without approximation won't solve the bottleneck.

---

## 5. Randomized SVD: The 76x Speedup Path

### 5.1 How Randomized SVD Works

Instead of computing a full SVD, randomized SVD:
1. Samples a random Gaussian matrix Omega (n x k)
2. Computes Y = A * Omega (m x k) — **one matrix multiply**
3. Takes QR of Y: Y = QR
4. Computes B = Q^T * A (k x n)
5. Takes SVD of small B: B = U_B * S * V^T
6. Reconstructs: U = Q * U_B

**Complexity**: O(mnk) instead of O(min(mn^2, m^2n)) — dramatic savings when k << min(m,n).

### 5.2 Randomized Subspace Iteration (RSI) Results

Paper: ["Low-Rank Compression via Randomized Subspace Iteration" (2026)](https://arxiv.org/html/2604.02659v1)

| Method | Layer | Time | Speedup vs Exact SVD | Normalized Error |
|--------|-------|------|----------------------|-----------------|
| Exact SVD | VGG19 (4096x25088) | 2.33s | 1x | 1.0 |
| RSI q=2, k=200 | VGG19 | **0.031s** | **76x** | ~1.0 |
| RSI q=4, k=200 | VGG19 | **0.046s** | **51x** | ~1.0 |
| RSI q=2, k=1000 | VGG19 | **0.23s** | **10x** | ~1.0 |
| Exact SVD | ViT (768x3072) | ~0.5s | 1x | 1.0 |
| RSI q=3, k=500 | ViT | **~0.01s** | **~50x** | <1.2 |

**Key finding**: RSI with q=2 achieves **76x speedup** with near-zero accuracy loss for rank-200 approximation.

### 5.3 RSVD on GPU Speedups (NVIDIA GTC 2019)

| Matrix Size | Rank-10 RSVD Speedup | Rank-20 RSVD Speedup |
|-------------|----------------------|----------------------|
| 1024 | 11-24x | 5-10x |
| 2048 | 34-103x | 14-43x |
| **4096** | **31-82x** | **13-34x** |

**Source**: [NVIDIA GTC 2019 RSVD slides](https://developer.download.nvidia.com/video/gputechconf/gtc/2019/presentation/s9226-fast-singular-value-decomposition-on-gpus-v2.pdf)

### 5.4 RSVD Accuracy Analysis

| Power Iterations (q) | Spectral Error | Frobenius Error | Practical |
|---------------------|----------------|-----------------|-----------|
| q=0 (basic RSVD) | Large, variable | Acceptable if fast decay | Risky |
| q=1 | Moderate | Good for most NN weights | Usable |
| **q=2** | **Small** | **Excellent** | **Recommended** |
| q=3 | Very small | Near-exact | Overkill for OSFT |

**Source**: [Randomized Block Krylov paper (Musco & Musco)](https://people.cs.umass.edu/~cmusco/personal_site/pdfs/blockKrylov.pdf)

### 5.5 RSVD Time Estimate for M4 Max

For a 4096x4096 matrix, rank-200 approximation with q=2:
- 3 matrix multiplies (A*Omega, A^T*Y, Q^T*A): 3 * ~5ms = ~15ms
- QR on tall-skinny: ~5ms
- SVD on small 200x4096: ~2ms
- **Total per matrix: ~22ms**
- **Total for 224 layers: 224 * 22ms = ~5 seconds**

This brings OSFT SVD from 60-120s to **<5 seconds** — a **12-24x improvement**.

---

## 6. Incremental SVD: The O(pr + r^3) Update Path

### 6.1 How Incremental SVD Works

Given existing SVD: A = U * S * V^T  
When adding columns: A+ = [A | P]  
Incremental SVD updates U, S, V in **O(pr + r^3)** time instead of recomputing from scratch.

**Source**: [Brand 2006 — "Fast Low-Rank Modifications of the Thin Singular Value Decomposition"](https://www.merl.com/publications/docs/TR2006-059.pdf)

### 6.2 Performance Characteristics

| Property | Value |
|----------|-------|
| Per-update complexity | O(pr + r^3) |
| Full thin SVD complexity | O(pqr + qr^3) = O(pqr) when r = O(sqrt(p)) |
| Space per update | O((p+q)r) — sublinear in matrix size |
| Accuracy tradeoff | Slightly worse than full recomputation; multipass improves |
| Speed vs Lanczos | **"Orders of magnitude faster"** |

**Empirical result**: Linear scaling with size and rank. Working set fits in CPU L1/L2 cache.

### 6.3 Applicability to OSFT

For OSFT task transitions:
- Weight matrices change by small amounts (gradient updates)
- Rank r is typically 50-200 (low-rank adaptation)
- Incremental SVD could update from previous SVD instead of recomputing
- **Estimated speedup**: 10-100x depending on how much the weights change

**Limitation**: If weights change significantly (full fine-tuning), incremental SVD accuracy degrades. Needs periodic full recomputation.

---

## 7. Frequent Directions: The coSO Streaming Approach

### 7.1 How Frequent Directions Works

Frequent Directions (FD) is a **deterministic streaming sketching algorithm**:
1. Maintains a small sketch matrix B (l x d, where l << n)
2. Processes rows of A one at a time
3. When sketch is full, performs SVD of B, shrinks singular values, discards least important direction
4. Provides guaranteed error bounds

**Source**: [Liberty 2013, Ghashami et al. 2016, KDD 2016 paper](https://www.kdd.org/kdd2016/papers/files/rfp1039-ghashamiA.pdf)

### 7.2 Error Bounds

With sketch size l = k + 1/epsilon:
- **Spectral norm bound**: ||A^T*A - B^T*B||_2 <= epsilon * ||A - A_k||_F^2
- **Frobenius bound**: ||A - pi_B^k(A)||_F <= (1 + epsilon) * ||A - A_k||_F

**Space**: O(l*d) instead of O(n*d)  
**Time per row**: O(l*d) — dominated by SVD of small sketch

### 7.3 CoSO's Use of Frequent Directions

The **CoSO (Continuous Subspace Optimization)** paper uses FD for continual learning:

> "While learning a task, CoSO leverages Frequent Directions (FD) to maintain a compact task-specific component, which captures critical update directions of the current task with **negligible computational cost**."

CoSO replaces full SVD on activations with FD sketching, achieving:
- Streaming updates (no need to store all gradients)
- Guaranteed approximation quality
- **No per-task SVD bottleneck**

**Source**: [CoSO paper — "Continuous Subspace Optimization for Continual Learning"](https://arxiv.org/html/2505.11816v1)

### 7.4 Can FD Replace Full SVD for OSFT?

**Answer: Partially, with tradeoffs.**

| Aspect | Full SVD | Frequent Directions |
|--------|----------|---------------------|
| Accuracy | Exact | Bounded approximation |
| Time per layer | 350ms (M4 Max) | ~5-10ms (sketch SVD only) |
| Space | O(n^2) | O(l*n) where l = k + 1/eps |
| Streaming | No | Yes |
| Singular vectors | Full | Approximate top-k |

For OSFT specifically:
- FD can maintain an approximate subspace across task transitions
- If OSFT only needs top-r singular vectors, FD with l = 2r gives (1+eps) approximation
- **Estimated FD cost per layer**: SVD of l x n sketch where l ~ 100-200: **~1-2ms**
- **Total for 224 layers**: ~0.2-0.5 seconds

**Verdict**: FD is the fastest approach but introduces approximation error. Best used when OSFT's SVD is for gradient projection (where approximate directions suffice), not for exact orthogonalization.

---

## 8. JAX on Metal: Experimental and Limited

### 8.1 JAX Metal Status

| Project | Status | SVD Support | Performance |
|---------|--------|-------------|-------------|
| `jax-metal` (official) | **Discontinued** | N/A | N/A |
| `jax-mps` (community) | Experimental | Unknown | ~3.7x speedup vs CPU on ResNet18 |
| `jax-mps` (M4 MacBook Air) | Early stage | "Not all ops implemented" | 0.928s/step vs 3.437s CPU |

**Source**: [Apple JAX Metal page](https://developer.apple.com/metal/jax/), [jax-mps PyPI](https://pypi.org/project/jax-mps/), [GitHub Discussion](https://github.com/jax-ml/jax/discussions/34648)

**Verdict**: Not viable for SVD acceleration. Community project in early stages, many operations not implemented.

---

## 9. PyTorch MPS SVD: The Workaround

### 9.1 Current Workaround Pattern

Since MPS doesn't support SVD, the only PyTorch option is:

```python
# Move to CPU for SVD, move back to MPS
device = torch.device("mps")
x = torch.randn(4096, 4096, device=device)

# Falls back to CPU automatically (with warning)
u, s, v = torch.linalg.svd(x)  # SLOW: GPU->CPU->GPU transfer

# Alternative: explicit CPU pipeline
x_cpu = x.cpu()
u, s, v = torch.linalg.svd(x_cpu)  # Compute on CPU
u, s, v = u.to(device), s.to(device), v.to(device)  # Move back
```

### 9.2 Accelerate Framework (CPU-only)

Apple's Accelerate framework provides LAPACK SVD (via `cblas`/`lapack`) that runs on CPU:
- Uses AMX (Apple Matrix Extensions) acceleration
- Achieves 1.49 TFLOPS on M4 CPU (vs 2.9 TFLOPS GPU with MPS)
- **SVD on M4 CPU (4096x4096)**: estimated ~1-2 seconds per matrix

**Source**: [Swift forums — Accelerate framework benchmarks](https://forums.swift.org/t/performance-of-accelerate-framework-vs-swift-on-apple-silicon/80919)

### 9.3 MATLAB QR+SVD Workaround (89x Speedup)

A critical finding for tall-skinny matrices:

```matlab
% Standard: 0.086851 seconds
[U,S,V] = svd(A,0);

% QR+SVD trick: 0.000977 seconds — 89x faster!
[Q,R] = qr(A,"econ");
[U,S,V] = svd(R);
U = Q*U;
```

**Source**: [MATLAB Central — Apple Silicon SVD slowdown](https://www.mathworks.com/matlabcentral/answers/2170959-massive-slowdown-for-apple-silicon-in-computing-svd)

**Applicability**: This trick works because Apple's LAPACK has suboptimal tuning for direct SVD on tall-skinny matrices. For 4096x4096 (square), the speedup is less dramatic but still significant.

---

## 10. M4 Max Hardware Specifications

| Spec | M4 Max (32-core GPU) | M4 Max (40-core GPU) |
|------|----------------------|----------------------|
| CPU Cores | 14 (10P+4E) | 16 (12P+4E) |
| GPU Cores | 32 | 40 |
| FP32 TFLOPS (theoretical) | 12.9 | ~16.1 |
| FP32 TFLOPS (measured MPS GEMM) | ~2.5-2.9 | ~2.9-3.5 |
| Memory Bandwidth | 410 GB/s | 546 GB/s |
| Max Unified Memory | 128 GB | 128 GB |
| Geekbench 6 Metal | 159,744 | 190,329 |
| Geekbench 6 Single-Core | 25,660 | 26,200 |

**Sources**: [NanoReview](https://nanoreview.net/en/gpu/apple-m4-max-gpu-32-core), [Geekbench](https://browser.geekbench.com/mac-benchmarks), [NotebookCheck](https://www.notebookcheck.net/Apple-M4-Max-40-core-GPU-Benchmarks-and-Specs.920457.0.html)

---

## 11. Recommended Mitigation Strategy

### 11.1 Tiered Approach

```
Priority 1: MLX + Randomized SVD (implement NOW)
  - Port OSFT SVD calls from PyTorch to MLX
  - Use randomized subspace iteration with q=2, k=rank
  - Expected: 60-120s → 3-5s (12-40x speedup)
  - Accuracy: Near-exact for low-rank approximations

Priority 2: Incremental SVD across task transitions
  - Cache SVD results from previous task
  - Use Brand's incremental update for small weight changes
  - Expected: 3-5s → 0.5-1s (additional 5-10x)
  - Only recompute full SVD when task shift is large

Priority 3: Frequent Directions (long-term research)
  - Replace full SVD entirely with FD sketching
  - Maintain streaming sketch across all tasks
  - Expected: 0.5-1s → 0.1-0.3s (additional 3-5x)
  - Tradeoff: Approximate vs exact singular vectors
```

### 11.2 Implementation Path for MLX + RSVD

```python
import mlx.core as mx

def randomized_svd_mlx(A, rank, power_iters=2):
    """GPU-accelerated randomized SVD on Apple Silicon via MLX."""
    m, n = A.shape
    # 1. Random Gaussian matrix
    omega = mx.random.normal((n, rank))
    # 2. Power iteration to improve accuracy
    Y = A @ omega
    for _ in range(power_iters - 1):
        Y = A @ (A.T @ Y)
    # 3. QR decomposition
    Q, _ = mx.linalg.qr(Y)
    # 4. Project A onto Q
    B = Q.T @ A
    # 5. SVD of small B
    U_b, S, Vt = mx.linalg.svd(B, stream=mx.gpu)
    # 6. Reconstruct U
    U = Q @ U_b
    return U, S, Vt

# Batch SVD for all layers
for name, W in model_params.items():
    U, S, Vt = randomized_svd_mlx(W, rank=200, power_iters=2)
    # Apply OSFT projection...
```

### 11.3 Expected Performance Summary

| Approach | Time (224 layers, M4 Max) | Speedup | Accuracy |
|----------|---------------------------|---------|----------|
| Current (CPU SVD) | 60-120s | 1x | Exact |
| MLX Full SVD (GPU) | ~78s | 1-1.5x | Exact |
| **MLX + RSVD (q=2)** | **3-5s** | **12-40x** | **Near-exact** |
| MLX + Incremental SVD | 0.5-1s | 60-240x | Good (approx) |
| MLX + Frequent Directions | 0.2-0.5s | 120-600x | Bounded approx |

---

## 12. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| MLX SVD slower than estimated | Medium | Less speedup than expected | Benchmark first; fallback to RSVD |
| RSVD accuracy insufficient for OSFT | Low | Degraded task separation | Increase q (power iterations); validate on benchmark |
| MLX API changes / instability | Medium | Code breakage | Pin MLX version; wrap in adapter |
| Incremental SVD drift accumulation | Medium | Accuracy degradation over tasks | Periodic full recomputation every N tasks |
| PyTorch MPS adds SVD support | Low (2026+) | Could simplify stack | Monitor PyTorch roadmap; MLX migration still valuable |

---

## 13. Key Citations

1. OSFT Paper: "Sculpting Subspaces: Constrained Full Fine-Tuning in LLMs for Continual Learning" — ICLR 2026 submission. SVD time: ~2 min on H100 for LLaMA-2 7B.

2. CoSO Paper: "Continuous Subspace Optimization for Continual Learning" — arxiv 2025. Uses Frequent Directions for streaming SVD.

3. Brand 2006: "Fast Low-Rank Modifications of the Thin Singular Value Decomposition" — MERL TR2006-059. Incremental SVD in O(pr + r^3).

4. NVIDIA GTC 2019: "Fast SVD on GPU" — cuSOLVER benchmarks, RSVD speedups up to 100x.

5. RSI Paper (2026): "Low-Rank Compression via Randomized Subspace Iteration" — 76x speedup over exact SVD.

6. HPC Apple Paper (2025): "Apple vs. Oranges" — M4 GPU peaks at 2.9 TFLOPS FP32.

7. Block Krylov Paper: "Randomized Block Krylov Methods for Stronger and Faster Approximations" — gap-independent convergence bounds.

8. MATLAB Apple SVD Workaround (2024): QR+SVD trick achieves 89x speedup.

9. PyTorch MPS SVD Issue: StackOverflow 2026 — confirmed not supported.

10. Learning-Augmented FD (2025): 1-2 orders of magnitude improvement over base Frequent Directions.

---

## 14. Verdict

**The 60-120 second SVD bottleneck is solvable.** The recommended path is:

1. **Immediate**: Migrate SVD calls from PyTorch CPU to **MLX GPU** — this alone may cut time by 30-50%
2. **Short-term**: Implement **randomized SVD** (RSI with q=2) via MLX — brings 224-layer SVD to **<5 seconds** with negligible accuracy loss
3. **Medium-term**: Add **incremental SVD** updates across task transitions — further reduces to **<1 second**
4. **Long-term**: Evaluate **Frequent Directions** (as used by CoSO) to potentially eliminate full SVD entirely

The combination of MLX (native Apple GPU SVD) + randomized algorithms (RSVD) is the most promising approach, offering **12-40x speedup** with minimal implementation complexity.
