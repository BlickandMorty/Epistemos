# TurboQuant (PolarQuant + QJL) — Technical Deep Dive for Implementation

## Executive Summary

TurboQuant is a two-stage, data-oblivious vector quantization framework developed by Google Research (Amir Zandieh, Vahab Mirrokni et al.), to be presented at ICLR 2026. It combines two sub-algorithms — **PolarQuant** (AISTATS 2026) and **QJL** (AAAI 2025) — to achieve near-Shannon-optimal compression of high-dimensional embedding vectors with *zero training time* and *zero indexing overhead*. The key verified numbers are: 3.5 bits per channel for quality-neutral compression (6×+ memory reduction vs FP16), 8× faster attention on NVIDIA H100 GPUs at 4-bit, and recall on the GloVe ANN benchmark that outperforms classic Product Quantization (PQ) at essentially zero indexing cost.[^1][^2][^3][^4][^5]

**What TurboQuant is NOT**: It is not a standalone vector database. It is a *compression primitive* — a way to encode embedding vectors into 3–4 bits before storing them. You still need a search structure (flat scan or approximate search) on top. The "zero training" claim is true: unlike PQ, there is no k-means codebook training step, which is the core advantage for your use case.[^2][^6]

***

## Part 1: The Three Algorithms

### 1.1 QJL — The 1-Bit Inner Product Estimator

**Paper**: arXiv:2406.03482 | AAAI 2025[^7]
**Code**: https://github.com/amirzandieh/QJL (Apache-2.0, Python + CUDA)[^8]

QJL is the foundational primitive. Given a vector \(\mathbf{x} \in \mathbb{R}^d\), it quantizes it to a single sign bit per coordinate:[^9][^7]

**Quantization:**
\[
Q_{\text{qjl}}(\mathbf{x}) = \text{sign}(\mathbf{S} \cdot \mathbf{x}) \in \{-1, +1\}^d
\]

where \(\mathbf{S} \in \mathbb{R}^{d \times d}\) is a fixed random matrix with i.i.d. \(\mathcal{N}(0,1)\) entries (generated once with a fixed seed and reused).

**Dequantization (for inner product estimation):**
\[
Q_{\text{qjl}}^{-1}(\mathbf{z}) = \frac{\sqrt{\pi/2}}{d} \cdot \mathbf{S}^\top \cdot \mathbf{z}
\]

**The critical guarantee** is that the inner product estimator is *unbiased*:[^7]
\[
\mathbb{E}\left[\langle \mathbf{y},\, Q_{\text{qjl}}^{-1}(Q_{\text{qjl}}(\mathbf{x})) \rangle\right] = \langle \mathbf{y}, \mathbf{x} \rangle
\]

This is achieved via an *asymmetric estimator*: the stored key is 1-bit, but the query remains full-precision. The variance is bounded by \(\frac{\pi}{2d} \|\mathbf{y}\|_2^2\)[^3]. In practice this means QJL alone (used as a 1-bit key cache) achieves over 5× memory reduction with no accuracy loss on LLM benchmarks[^7].

**Memory overhead**: Zero. QJL requires no normalization constants (zero-points, scales) because the JL transform itself acts as the preconditioner, making the coordinate distribution predictable.[^9][^7]

***

### 1.2 PolarQuant — The Multi-Level Polar Angle Encoder

**Paper**: arXiv:2502.02617 | AISTATS 2026[^10][^11]
**Authors**: Insu Han (KAIST), Praneeth Kacham, Vahab Mirrokni, Amir Zandieh (Google Research)[^12]

PolarQuant is a more sophisticated quantizer designed for KV cache compression that achieves better MSE-accuracy than QJL at similar bit widths. The core insight is to convert vectors to polar coordinates *after* a random rotation, which makes the angle distribution analytically tractable.[^10][^11][^12]

#### Step 1 — Random Preconditioning

Apply a shared random *rotation matrix* \(\mathbf{S}\) (orthogonal, satisfying \(\mathbf{S}^\top \mathbf{S} = \mathbf{I}\)) to the input vector. This is different from a generic random projection — it preserves norms and inner products exactly:[^11]

```
x_rotated = S @ x
```

After rotation, the vector effectively behaves as if drawn from a multivariate Gaussian distribution \(\mathcal{N}(0, \|\mathbf{x}\|_2 \cdot \mathbf{I}_d)\)[^11]. **This is the key**: the distribution of the resulting polar angles is now *known analytically*, so an optimal codebook can be derived without data-dependent k-means.

#### Step 2 — Recursive Polar Transformation

This is *not* a simple 2D polar conversion. PolarQuant applies a recursive, multi-level algorithm:[^11]

- **Level 1**: Group coordinates into pairs \((x_{2j-1}, x_{2j})\). Convert each pair to polar form:
\[
\psi^{(1)}_j = \text{atan2}(x_{2j},\, x_{2j-1}) \in [0, 2\pi)
\]
This yields \(d/2\) angles and \(d/2\) radii.

- **Level \(\ell \geq 2\)**: Take the \(d/2^{\ell-1}\) radii from the previous level. Group them into pairs, compute:
\[
\psi^{(\ell)}_j = \arctan\!\left(\frac{\|\mathbf{x}_{\text{right}}\|_2}{\|\mathbf{x}_{\text{left}}\|_2}\right) \in [0, \pi/2]
\]

- **Recurse** \(\log_2 d\) times until a single final radius \(r = \|\mathbf{x}\|_2\) remains.

The final output is: **1 radius** (stored in FP16/FP32) + **(d-1) angles** at various levels.[^11]

#### Step 3 — Quantize the Angles

After rotation, the angle distribution at each level \(\ell\) is analytically known:[^11]
\[
f_{\ell}(\psi) = \frac{\Gamma(2^{\ell-1})}{2^{2^{\ell-1}-2} \cdot \Gamma(2^{\ell-2})^2} \cdot \sin^{2^{\ell-1}-1}(2\psi)
\]

Because these angles are **independent** (separable joint pdf), each can be quantized independently with an optimal 1D codebook — no joint optimization needed. The codebooks are precomputed offline from this analytical distribution.[^11]

**Practical bit allocation** (for d=128, L=4 levels):[^11]
- Level 1 angles: **4 bits** (range [0, 2π), wider distribution)
- Levels 2-4 angles: **2 bits** each (range [0, π/2], highly concentrated around π/4)
- Final radius: stored in FP16

Memory per 16 coordinates: `16 (radius FP16) + 32 + 8 + 4 + 2 = 62 bits` → **3.875 bits/coordinate** → 4.2× compression.[^11]

#### Benchmark Results (PolarQuant vs Baselines)

| Method | LongBench Avg | NIAH | Compression |
|--------|--------------|------|-------------|
| Exact (FP16) | 48.63 | 100% | 1× |
| KIVI | 46.70 | — | ~4× |
| **PolarQuant** | 48.11 | 99%+ | 4.2× |
| **PolarQuant-R (online)** | 48.37 | 99%+ | 4.2× |

[^11]

***

### 1.3 TurboQuant — The Two-Stage Optimal Quantizer

**Paper**: arXiv:2504.19874 | ICLR 2026[^2][^3]

TurboQuant is the synthesis. It uses random rotation to induce a Beta distribution on coordinates (rather than polar coordinates), then applies an optimal scalar quantizer, and finally applies QJL on the residual to produce an *unbiased* inner product estimator.[^3]

#### The Beta Distribution Insight

After applying a random rotation matrix \(\mathbf{\Pi}\) (generated via QR decomposition), each coordinate of the rotated vector is uniformly distributed on the unit hypersphere, following a **Beta distribution**:[^3]

\[
f_X(x) = \frac{\Gamma(d/2)}{\sqrt{\pi} \cdot \Gamma((d-1)/2)} \cdot (1-x^2)^{(d-3)/2}, \quad x \in [-1, 1]
\]

In high dimensions (\(d \gg 1\)), this converges to \(\mathcal{N}(0, 1/d)\). More importantly, distinct coordinates become **nearly independent**, which means you can quantize each coordinate independently using an optimal 1D quantizer and still achieve near-optimal total distortion.[^3]

#### Stage 1 — MSE-Optimal Quantizer (TurboQuant_mse)

```
Algorithm Quant_mse(x, b_bits):
  1. Pi = QR(randn(d, d))         # fixed-seed rotation matrix
  2. y  = Pi @ x                  # rotate to induce Beta distribution
  3. for j in 1..d:
       idx[j] = argmin_k |y[j] - c_k|  # nearest centroid (precomputed codebook)
  4. return idx

Algorithm DeQuant_mse(idx, Pi, centroids):
  1. y_hat = centroids[idx]        # look up reconstructed coordinates
  2. x_hat = Pi.T @ y_hat          # rotate back
  3. return x_hat
```

The codebook centroids \(\{c_k\}\) are precomputed once by solving a 1D k-means problem for the Beta distribution. For moderately high dimensions (large \(d\)):[^3]
- **1-bit**: centroids \(\approx \{\pm\sqrt{2/\pi d}\}\)  
- **2-bit**: centroids \(\approx \{\pm 0.453/\sqrt{d},\, \pm 1.51/\sqrt{d}\}\)

The MSE distortion bound is:[^3]
\[
D_{\text{mse}} \leq \frac{\sqrt{3}\pi}{2} \cdot \frac{1}{4^b}
\quad \left(\approx 2.7 \times \text{ Shannon lower bound}\right)
\]

Specific values: b=1 → 0.36, b=2 → 0.117, b=3 → **0.03**, b=4 → 0.009.[^3]

#### Stage 2 — Residual QJL for Unbiased Inner Products (TurboQuant_prod)

MSE-optimal quantizers are *biased* for inner product estimation (the bias is \(2/\pi\) at 1-bit). TurboQuant_prod fixes this with a two-stage approach:[^3]

```
Algorithm Quant_prod(x, b_bits):
  1. idx  = Quant_mse(x, b_bits - 1)           # Stage 1: (b-1)-bit MSE quant
  2. r    = x - DeQuant_mse(idx, Pi, centroids) # residual vector
  3. gamma = ||r||_2                            # residual L2 norm (store as FP16 scalar)
  4. qjl  = sign(S @ (r / gamma))              # Stage 2: 1-bit QJL on residual
  5. return (idx, qjl, gamma)

Algorithm DeQuant_prod(idx, qjl, gamma, Pi, S, centroids):
  1. x_mse = DeQuant_mse(idx, Pi, centroids)
  2. r_hat  = gamma * (sqrt(pi/2) / d) * (S.T @ qjl)
  3. return x_mse + r_hat
```

This produces an **unbiased** inner product estimator:[^3]
\[
\mathbb{E}\left[\langle \mathbf{y},\, \tilde{\mathbf{x}} \rangle\right] = \langle \mathbf{y}, \mathbf{x} \rangle
\]

with inner-product distortion bound:
\[
D_{\text{prod}} \leq \frac{\sqrt{3}\pi^2 \|\mathbf{y}\|_2^2}{d} \cdot \frac{1}{4^b}
\]

At **b=3.5 bits** (the "Goldilocks zone"), quality neutrality is achieved empirically on all tested benchmarks.[^13][^2]

***

## Part 2: Verified Performance Numbers

### KV Cache Benchmarks

| Metric | TurboQuant 3.5-bit | TurboQuant 2.5-bit | Full FP16 |
|--------|-------------------|-------------------|-----------|
| LongBench | 50.06 | 49.44 | 50.06 |
| Needle-in-Haystack | 100% | 99.8% | 100% |
| ZeroSCROLLS | best | near-best | baseline |
| Memory compression | 6×+ | 8×+ | 1× |
| Attention speed (H100) | 8× | 8× | 1× |

[^4][^5][^1]

### Nearest Neighbor Search (GloVe d=200)

On approximate nearest-neighbor (ANN) benchmarks, TurboQuant achieves the **best 1@k recall** while having indexing time ≈ 0, compared to:[^5][^1]
- **Product Quantization (PQ)**: Lower recall, requires k-means training (~240s indexing)
- **RaBitQ** (grid-based online method): Lower recall, ~2268s indexing

The indexing time difference is extreme — approximately **180,000× faster** than PQ for the same dataset, because TurboQuant requires no codebook training.[^3]

***

## Part 3: Implementation Guide for Your Stack

### Critical Distinction: What Exists vs What Needs to Be Built

| Component | Status | Location |
|-----------|--------|----------|
| QJL Python + CUDA | ✅ Open source | github.com/amirzandieh/QJL[^8] |
| PolarQuant PyTorch + CUDA | ✅ In paper / no standalone repo | arXiv:2502.02617[^10] |
| TurboQuant reference | ⚠️ Pseudocode only | arXiv:2504.19874[^2] |
| Official open-source | ❌ Expected Q2 2026 | llama.cpp #20969[^5] |

### Step-by-Step Implementation Blueprint

#### Step 0 — Precompute Fixed State (One-Time)

```python
import numpy as np
from scipy.optimize import minimize

d = 768  # your embedding dimension

# 1. Fixed rotation matrix (deterministic seed)
rng = np.random.default_rng(seed=42)
G = rng.standard_normal((d, d))
Pi, _ = np.linalg.qr(G)  # orthogonal rotation matrix

# 2. Random JL matrix for QJL residual
S = rng.standard_normal((d, d))

# 3. Precompute Lloyd-Max centroids for Beta distribution
# For high-dim, Beta ~ N(0, 1/d), so use Gaussian centroids
# b=2 (used for (b-1)=2 in TurboQuant_prod at b=3):
# c ≈ [-1.51/sqrt(d), -0.453/sqrt(d), +0.453/sqrt(d), +1.51/sqrt(d)]
# Compute more precisely via numerical 1D k-means on Beta samples
```

#### Step 1 — Quantize (Quant_prod)

```python
def turboquant_encode(x, Pi, S, centroids, b_total=3):
    """
    x: float32 vector, shape (d,)
    Returns: (idx: uint8 array, qjl: int8 array, gamma: float16)
    """
    # Normalize to unit sphere
    norm = np.linalg.norm(x)
    x_unit = x / norm  # store norm separately if needed

    # Stage 1: (b-1)-bit MSE quantization
    b_mse = b_total - 1  # 2 bits if b_total=3
    y = Pi @ x_unit  # rotate: coordinates now follow Beta dist
    idx = np.array([np.argmin(np.abs(y_j - centroids[b_mse])) for y_j in y], dtype=np.uint8)

    # Dequantize Stage 1 result to get residual
    y_hat = centroids[b_mse][idx]
    x_hat = Pi.T @ y_hat

    # Stage 2: QJL on residual
    r = x_unit - x_hat
    gamma = np.linalg.norm(r).astype(np.float16)
    if gamma > 1e-8:
        r_normalized = r / gamma
    else:
        r_normalized = r
    qjl = np.sign(S @ r_normalized).astype(np.int8)  # +1 or -1

    return idx, qjl, gamma, norm  # store original norm too
```

#### Step 2 — Inner Product Estimation (DeQuant_prod for Search)

```python
def turboquant_inner_product(query, idx, qjl, gamma, Pi, S, centroids, b_mse=2):
    """
    Estimate inner product <query, x> from compressed representation.
    query: float32, shape (d,)
    """
    # Reconstruct MSE part
    y_hat = centroids[b_mse][idx]
    x_hat = Pi.T @ y_hat

    # Inner product with MSE reconstruction
    ip_mse = np.dot(query, x_hat)

    # QJL residual correction
    Sq = S.T @ qjl          # shape (d,)
    ip_residual = gamma * (np.sqrt(np.pi / 2) / len(query)) * np.dot(query, Sq)

    return ip_mse + ip_residual  # unbiased estimator
```

#### Step 3 — Memory Layout for Storage

For a database of N vectors of dimension d, using 3-bit TurboQuant:
- `idx` matrix: N × d × 2 bits = **N × d / 4 bytes** (pack uint8, 4 indices per byte)
- `qjl` matrix: N × d × 1 bit = **N × d / 8 bytes** (pack as bitfield)
- `gamma` array: N × 2 bytes (FP16)
- Total: **≈ 0.44 bytes per float**, vs 2 bytes for FP16 → **~4.5× compression**

For SQLite blob storage (your use case): serialize each entry as `[idx_bytes | qjl_bits | gamma_f16]`.

#### Step 4 — Integration with Rust (UniFFI)

The core math operations to expose from Rust:

```rust
pub struct TurboQuantIndex {
    rotation_matrix: Vec<f32>,   // Pi: d×d, row-major (fixed seed)
    jl_matrix: Vec<f32>,         // S: d×d (fixed seed)
    centroids: Vec<f32>,         // Lloyd-Max centroids for each b
    dim: usize,
    records: Vec<CompressedVector>,
}

pub struct CompressedVector {
    id: String,
    idx: Vec<u8>,      // 2-bit indices, packed
    qjl: Vec<u8>,      // 1-bit signs, packed
    gamma: f16,        // residual norm
    orig_norm: f16,    // original L2 norm
}

impl TurboQuantIndex {
    pub fn ingest_note(&mut self, id: String, embedding: Vec<f32>) { ... }
    pub fn search_memory(&self, query: Vec<f32>, limit: u32) -> Vec<String> { ... }
}
```

For the rotation and matmul kernels, use the [`nalgebra`](https://crates.io/crates/nalgebra) crate or raw BLAS/LAPACK bindings. The QJL `sign(S @ r)` operation is a single matrix-vector product plus sign extraction — fully vectorizable with SIMD.

***

## Part 4: Correcting the Manifesto

Your manifesto is directionally correct but contains several inaccuracies worth knowing before implementation.

### What's Accurate

- ✅ Data-oblivious: no k-means, no training step required[^2][^3]
- ✅ Two-stage: main quantizer + 1-bit QJL residual[^1]
- ✅ Zero indexing time (vs PQ which takes minutes)[^5][^3]
- ✅ 6×+ memory reduction; 8× attention speedup[^4][^1]
- ✅ 3.5 bits per channel = quality neutral (100% accuracy)[^13][^2]
- ✅ Outperforms PQ in ANN recall on GloVe[^1][^5]

### What's Incorrect or Needs Correction

| Claim in Manifesto | Reality |
|--------------------|---------|
| "PolarQuant converts (x,y) → (r, θ)" | PolarQuant does a *recursive multi-level* decomposition producing **d-1 angles** across log₂(d) levels, not a single 2D polar conversion[^11] |
| "Forces data into Beta Distribution" | The Beta distribution arises naturally on the rotated coordinates because the random rotation maps any unit vector to the uniform distribution on the hypersphere — it's a *consequence* of the rotation, not a target[^3] |
| "8× speedup from matrix multiplications replacing distance calculations" | The speedup comes from reduced memory bandwidth (fewer bytes moved from HBM to SRAM) and hardware-native low-bit integer arithmetic on H100, not from replacing "distance with matmul"[^4] |
| "Metal Performance Shaders (MPS)" | The paper benchmarks exclusively on NVIDIA H100/A100. MPS adaptation requires writing custom Metal compute kernels — not in the paper[^1][^4] |
| "Build from scratch in Rust" | The reference implementation is Python + PyTorch + CUDA C++. QJL has an Apache-2.0 repo[^8]. A Rust port is community work, not something with published reference code |
| "Mamba-2 encoder" | TurboQuant is encoder-agnostic. Works with any dense float embedding — Mamba-2, transformer, or otherwise |

***

## Part 5: Practical Risks for a Local-First Mac App

The manifesto proposes running TurboQuant on a MacBook Pro. Some specific issues to plan for:

**MPS Kernel Gap**: The paper's 8× speedup uses NVIDIA-specific optimizations (CUDA, H100 Tensor Cores). Apple's Metal Performance Shaders support matrix multiplications but require custom kernel authoring for the rotation and QJL sign operations. The computational bottleneck shifts to the FP32 matmul for the rotation (O(d²) per vector) — for d=768, that's ~589K FLOPs per note ingested.[^4][^1]

**Rotation Matrix Size**: At d=768, the rotation matrix Π is 768×768 = 2.36M floats = ~9 MB resident in RAM. The JL matrix S is another 9 MB. Both can be generated deterministically from a seed (store only the seed), regenerated at startup, and cached.[^3]

**Flat Scan vs Index**: For millions of notes, a flat scan over compressed vectors (O(N) inner products per query) works and is fast because each inner product is cheap (packed integers + sign bits). For true ANN at scale, you'd layer TurboQuant encoding under an HNSW or IVF index structure — TurboQuant handles the *quantization* layer, not the *graph traversal* layer.

**No Official Open-Source Yet**: As of March 2026, the only released code is the QJL repo. Open-source TurboQuant is expected in Q2 2026. The pseudocode in arXiv:2504.19874 is sufficient to implement from scratch.[^8][^5]

***

## Part 6: Recommended Implementation Order

1. **Start with QJL** — it has real, working code, Apache-2.0 license, and demonstrates the core concept. Port the inner product estimator to your language of choice.[^8]

2. **Implement TurboQuant_mse** — precompute Lloyd-Max centroids for Beta distribution offline, implement random rotation + per-coordinate scalar quantization. This is ~100 lines of Rust/Python.

3. **Add residual QJL** — compose TurboQuant_mse with QJL to get TurboQuant_prod. Adds the gamma scalar and bitfield storage.

4. **Benchmark locally** — compare recall on a sample of your note embeddings against a brute-force cosine index to verify the implementation matches theoretical distortion bounds.

5. **Layer on search** — implement a simple flat-scan search using the inner product estimator, then add HNSW on top if needed for >100K notes.

---

## References

1. [TurboQuant: Redefining AI efficiency with extreme compression](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/) - We introduce a set of advanced theoretically grounded quantization algorithms that enable massive co...

2. [TurboQuant: Online Vector Quantization with Near-optimal Distortion ...](https://arxiv.org/abs/2504.19874) - We propose TurboQuant to address both mean-squared error (MSE) and inner product distortion, overcom...

3. [TurboQuant: Online Vector Quantization with Near-optimal Distortion ...](https://arxiv.org/html/2504.19874v1) - This approach operates by projecting a uniform grid onto the unit sphere and conducting a search to ...

4. [Google Research Launches TurboQuant for Faster Model Inferen](https://phemex.com/news/article/google-research-unveils-turboquant-for-efficient-model-compression-68826) - Google Research has introduced TurboQuant, a novel quantization algorithm that compresses the KV cac...

5. [TurboQuant - Extreme Compression for AI Efficiency](https://turboquant.net) - For ANN systems such as FAISS, TurboQuant improves recall while keeping indexing overhead close to z...

6. [Product Quantization: Compressing high-dimensional vectors by 97%](https://www.pinecone.io/learn/series/faiss/product-quantization/) - Lower recall rates are a major drawback of PQ. This can be counteracted somewhat by using larger nbi...

7. [[2406.03482] QJL: 1-Bit Quantized JL Transform for KV Cache ...](https://arxiv.org/abs/2406.03482) - We introduce QJL, a new quantization approach that consists of a Johnson-Lindenstrauss (JL) transfor...

8. [GitHub - amirzandieh/QJL: QJL: 1-Bit Quantized JL transform for KV ...](https://github.com/amirzandieh/QJL) - Overall, QJL offers a memory-efficient, fast, and accurate solution for KV cache quantization, addre...

9. [Quantized Johnson-Lindenstrauss transform for LLMs - LinkedIn](https://www.linkedin.com/posts/amir-zandieh-phd-323a13a9_github-amirzandiehqjl-qjl-1-bit-quantized-activity-7223408478327840769-RzQe) - Introducing Quantized Johnson-Lindenstrauss (QJL), a novel approach to compress the Key-Value (KV) c...

10. [PolarQuant: Quantizing KV Caches with Polar Transformation - arXiv](https://arxiv.org/abs/2502.02617) - This work introduces PolarQuant, a novel quantization method employing random preconditioning and po...

11. [PolarQuant: Quantizing KV Caches with Polar Transformation - arXiv](https://arxiv.org/html/2502.02617v1) - This work introduces PolarQuant, a novel quantization method employing random preconditioning and po...

12. [PolarQuant: Quantizing KV Caches with Polar Transformation](https://research.google/pubs/polarquant-quantizing-kv-caches-with-polar-transformation/) - This work introduces PolarQuant, a novel quantization method employing random preconditioning and po...

13. [[PDF] Online Vector Quantization with Near-optimal Distortion Rate - arXiv](https://arxiv.org/pdf/2504.19874.pdf) - We propose TurboQuant to address both mean-squared error (MSE) and inner product distor- tion, overc...

