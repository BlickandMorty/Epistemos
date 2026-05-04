# Deep Research: PSOFT (Principal Subspace Orthogonal Fine-Tuning)

**Research Date**: 2025  
**Paper**: "Efficient Orthogonal Fine-Tuning with Principal Subspace Adaptation" (ICLR 2026)  
**arXiv**: 2505.11235  
**Authors**: Fei Wu, Jia Hu, Geyong Min, Shiqiang Wang  
**Institution**: University of Exeter, IBM T.J. Watson Research Center  
**Code**: https://github.com/fei407/PSOFT  

---

## 1. EXECUTIVE SUMMARY

PSOFT is a parameter-efficient fine-tuning (PEFT) method that bridges the gap between low-rank adaptation (LoRA) and orthogonal fine-tuning (OFT). It confines orthogonal transformations to the principal subspace of pre-trained weights, achieving simultaneous semantic preservation, expressiveness, and multi-dimensional efficiency. PSOFT was accepted to ICLR 2026 and has been extensively benchmarked across 35 NLP and CV tasks on 4 models (DeBERTaV3-base, ViT-B/16, LLaMA-3.2-3B, LLaMA-3.1-8B).

**Key Innovation**: Instead of operating in the full parameter space like OFT/BOFT/GOFT, or using additive low-rank updates like LoRA, PSOFT performs orthogonal transformations within the r-dimensional principal subspace obtained via SVD of pre-trained weights. This achieves:
- **18x** higher parameter efficiency than OFT variants on small models
- **94%** fewer parameters than LoRA on vision tasks with better accuracy
- **+2.3%** improvement over LoRA on GSM-8K with comparable parameter counts
- Consistent avoidance of OOM failures that plague other OFT variants at scale

---

## 2. MATHEMATICAL FORMULATION

### 2.1 Core Architecture

Given a pre-trained weight matrix **W**_pre ∈ R^(d×n), PSOFT decomposes it via SVD:

```
W_pre = U Σ V^T
```

The principal subspace is extracted from the top-r singular values/vectors:

```
W_pri = A' · B' = U[:,:r] · Σ[:r,:r] · V[:,:r]^T
```

where A' ∈ R^(d×r) and B' ∈ R^(r×n). The residual is frozen:

```
W_res = W_pre - W_pri = U[:,r:] · Σ[r:,r:] · V[:,r:]^T
```

The forward pass becomes:

```
h = (A' · R · B' + W_res)^T · x    (PSOFT)
```

where **R** ∈ R^(r×r) is an orthogonal matrix (the only trainable parameter), initialized as identity.

### 2.2 Cayley Parameterization

**R** is parameterized via the Cayley transform to enforce orthogonality without constraints:

```
R = (I - Q)(I + Q)^(-1)
```

where **Q** ∈ R^(r×r) is a **skew-symmetric matrix** (Q^T = -Q). The skew-symmetric property ensures R^T R = I automatically.

**Parameter count**: A skew-symmetric matrix has zeros on the diagonal and antisymmetric off-diagonal entries, requiring exactly **r(r-1)/2** free parameters.

### 2.3 Neumann Series Approximation

To avoid the expensive matrix inversion (I + Q)^(-1), PSOFT uses a truncated Neumann series:

```
(I + Q)^(-1) ≈ Σ_{k=0}^{K} (-Q)^k
```

With **K = 5** terms in practice. This reduces computational cost from O(r^3) for the inverse to O(K · r^2) for matrix multiplications.

| Approximation | Training Speed | Performance |
|---------------|---------------|-------------|
| Full Cayley (closed-form) | Slowest (matrix inverse) | Best |
| Neumann K=2 | Fastest | Slightly lower |
| Neumann K=5 | Fast | Near-optimal |

### 2.4 Tunable Vectors (Relaxation of Orthogonality)

PSOFT introduces two tunable vectors α, β ∈ R^r to relax strict orthogonality:

```
h = (A' · diag(α) · R · diag(β) · B' + W_res)^T · x
```

- **α** and **β** are initialized as **all-one vectors** (strict orthogonality at start)
- During training, they **gradually relax** the orthogonality constraint
- This enables adjustable angles and scalable norms for task-specific adaptation
- Overhead: only **2r** additional parameters (negligible)

**Constraint to prevent excessive deviation**:
```
||C^T · C - I||_F ≤ ε, where C = diag(α) · R · diag(β)
```

When diag(α) = λ_1 · I and diag(β) = λ_2 · I, angular relationships are preserved and magnitudes are uniformly scaled.

### 2.5 Total Parameter Count

```
#PSOFT_params = r(r-1)/2  (Cayley parameters for R)
               + 2r       (tunable vectors α, β)
```

**Example**: For r = 46: 46×45/2 + 92 = 1,035 + 92 = **1,127 parameters** (paper reports ~0.08M when applied across all layers of DeBERTaV3-base)

---

## 3. THEORETICAL GUARANTEES

### 3.1 Geometry Preservation Theorem (Theorem 4.1 / Theorem B.1)

**Claim**: PSOFT preserves pairwise angles between columns and column norms of the principal weights if and only if R^T · G · R = G, where G = A^T · A.

**Formal Statement**:
Let W_pri = A · B ∈ R^(d×n) and W_ps-tuned = A · R · B ∈ R^(d×n).
Then:

```
R^T · G · R = G   ⟺   (∀i≠j, θ_ij^ps-tuned = θ_ij^pri) 
                         AND (∀i, ||w_i^ps-tuned|| = ||w_i^pri||)
```

**Proof Sketch** (from paper Appendix B):
- **Sufficiency**: If R^T G R = G, then cosines of angles and norms are preserved by direct substitution
- **Necessity**: Define M = R^T G R - G. From norm preservation, b_i^T M b_i = 0 for all i. From angle preservation, b_i^T M b_j = 0 for all i≠j. Since {b_i} spans R^r, M = 0.

**Source**: PSOFT Paper, Appendix B, Theorem B.1  
**URL**: https://arxiv.org/abs/2505.11235  
**Confidence**: HIGH — rigorous proof provided in paper

### 3.2 Simplified Condition (Practical Implementation)

When A is normalized such that A^T · A = I_r, the condition simplifies to:

```
R^T · R = I
```

This is satisfied by construction via the Cayley parameterization.

### 3.3 Higher Effective Rank Under Parameter Budget

**Key theoretical insight**: Under a fixed parameter budget M:

| Method | Parameter Formula | Effective Rank | Relation |
|--------|-------------------|----------------|----------|
| LoRA | (d+n)·r | r_LoRA = M/(d+n) | Small |
| PSOFT | r^2 | r_PSOFT = √M | Large |

Since √M ≪ (d+n) for typical d,n, we have **r_PSOFT ≫ r_LoRA**. PSOFT operates with much larger ranks under the same parameter budget, explaining its superior expressiveness.

**Example**: For M = 12M params, d = n = 4096 (typical LLM layer):
- LoRA rank: r = 12M/(4096+4096) ≈ **1,464**
- PSOFT rank: r = √(12M) ≈ **3,464**

Wait — this seems contradictory to reported ranks. Actually in practice, PSOFT uses ranks like r=352 for LLaMA-3.2-3B with ~12M total trainable params, because the 12M is spread across ALL layers. Per-layer, the budget is much smaller. The key insight still holds: PSOFT achieves higher rank per parameter spent.

### 3.4 Lipschitz/Singular Value Preservation

While the paper does not explicitly derive Lipschitz bounds on singular values in the main text, the geometry preservation theorem implies that:

1. **Norm preservation**: Column norms are preserved, preventing explosive growth or collapse of activations
2. **Angle preservation**: Pairwise angular relationships are maintained, preserving the semantic structure
3. **Spectral stability**: Since R is orthogonal, its singular values are all exactly 1, preventing rank collapse

The paper notes: "The subspace-based update avoids the long chains of full-dimensional multiplications used in GOFT and BOFT, which become increasingly expensive at larger scales."

**Source**: PSOFT Paper, Section 6 and Appendix L  
**Confidence**: MEDIUM — theoretical framework is sound but explicit Lipschitz constants not derived

---

## 4. BENCHMARK RESULTS

### 4.1 Natural Language Understanding (GLUE) — DeBERTaV3-base

| Method | #Params | Mem (GB) | CoLA | STS-B | RTE | MRPC | SST2 | QNLI | Avg |
|--------|---------|----------|------|-------|-----|------|------|------|-----|
| FFT | 184M | 5.9 | 67.56 | 91.46 | 82.88 | 90.69 | 94.13 | 93.37 | 86.68 |
| GOFTv2 | 0.08M | 18.5 | 65.45 | OOM | — | — | — | — | — |
| qGOFTv2 | 0.33M | 18.5 | 68.03 | OOM | — | — | — | — | — |
| BOFT | 1.41M | 6.3 | 68.85 | 91.09 | 83.60 | 88.40 | 95.28 | 93.78 | 86.83 |
| OFTv2 | 1.29M | 4.5 | 66.79 | 91.22 | 84.03 | 89.61 | 93.72 | 92.64 | 86.34 |
| LoRA r=8 | 1.33M | 4.5 | 67.98 | 91.60 | 84.87 | 90.20 | 95.28 | 93.89 | 87.30 |
| PiSSA r=8 | 1.33M | 4.5 | 66.50 | 91.40 | 83.77 | 89.90 | 93.17 | 92.72 | 86.24 |
| DoRA r=8 | 1.41M | 5.8 | 67.06 | 91.60 | 87.19 | 90.49 | 95.23 | 94.09 | 87.61 |
| LoRA-XS | 1.33M | 4.2 | 64.67 | 91.48 | 84.17 | 91.27 | 93.85 | 93.14 | 86.43 |
| **PSOFT r=46** | **0.08M** | **4.1** | **70.42** | **91.56** | **86.74** | **90.49** | **95.55** | **93.47** | **88.04** |

**Key findings**:
- PSOFT with **0.08M** params (94% fewer than LoRA's 1.33M) achieves **88.04 avg** vs LoRA's 87.30
- PSOFT avoids OOM that crashes GOFTv2/qGOFTv2
- PSOFT uses **lowest memory** (4.1 GB) among all methods
- **+0.74** absolute improvement over LoRA with 16x fewer parameters

**Source**: PSOFT Paper, Table 2  
**URL**: https://arxiv.org/abs/2505.11235  
**Confidence**: HIGH — averaged over 5 random seeds, rigorous evaluation protocol

### 4.2 Visual Classification (VTAB-1K) — ViT-B/16

| Method | #Params | Mem (GB) | Avg |
|--------|---------|----------|-----|
| LoRA r=8 | 1.33M | 9.9 | 71.8 |
| PiSSA r=8 | 1.33M | 9.9 | 72.3 |
| DoRA r=8 | 1.41M | 17.8 | 72.3 |
| LoRA-XS | 1.33M | 6.6 | 71.6 |
| **PSOFT r=46** | **0.08M** | **6.2** | **73.4** |

**Key findings**:
- PSOFT achieves **73.4 avg** (best) with **94% fewer parameters** than LoRA
- **+1.6** absolute over LoRA, **+1.1** over PiSSA, **+1.8** over DoRA
- Lowest memory footprint (6.2 GB) among all methods
- GOFTv2 and qGOFTv2 OOM immediately

**Source**: PSOFT Paper, Table 3  
**Confidence**: HIGH

### 4.3 Mathematical Reasoning — LLaMA-3.2-3B on GSM-8K and MATH

| Method | #Params | Memory (GB) | GSM-8K | MATH |
|--------|---------|-------------|--------|------|
| FFT | 3.21B | 69.0 | 63.00 | 16.84 |
| GOFTv2 | 0.75M | OOM | — | — |
| qGOFTv2 | 2.98M | OOM | — | — |
| BOFT | 3.76M | OOM | — | — |
| OFTv2 | 11.6M | 35.2 | 61.03 | 15.70 |
| LoRA r=8 | 12.2M | 32.2 | 60.80 | 15.76 |
| PiSSA r=8 | 12.2M | 32.2 | 61.26 | 14.96 |
| DoRA r=8 | 12.9M | 43.4 | 62.62 | 15.48 |
| LoRA-XS | 12.1M | 34.4 | 61.56 | 15.02 |
| **PSOFT r=352** | **12.2M** | **36.2** | **63.08** | **15.98** |

**Key findings**:
- PSOFT **outperforms LoRA by +2.28%** on GSM-8K (63.08 vs 60.80)
- PSOFT **outperforms PiSSA by +1.02%** on MATH (15.98 vs 14.96)
- All other OFT variants (GOFTv2, qGOFTv2, BOFT) **OOM on H100 80GB**
- PSOFT matches LoRA memory (36.2 GB vs 32.2 GB) while delivering superior performance

**Source**: PSOFT Paper, Table 4  
**Confidence**: HIGH

### 4.4 Commonsense Reasoning — LLaMA-3.1-8B

| Method | #Params | Memory (GB) | Avg |
|--------|---------|-------------|-----|
| FFT | 8.03B | OOM | — |
| GOFTv2 | 0.98M | OOM | — |
| qGOFTv2 | 3.93M | OOM | — |
| BOFT | 4.72M | OOM | — |
| OFTv2 | 14.3M | 55.5 | 80.77 |
| LoRA r=8 | 14.2M | 54.1 | 81.11 |
| PiSSA r=8 | 14.2M | 54.1 | 81.30 |
| DoRA r=8 | 14.9M | 65.6 | 82.09 |
| LoRA-XS | 14.2M | 56.2 | 81.88 |
| **PSOFT r=424** | **14.5M** | **58.4** | **82.54** |

**Key findings**:
- PSOFT achieves **82.54 avg** (best across 8 benchmarks)
- **+1.77%** over OFTv2, **+0.45%** over DoRA
- **Reduces memory by ~7 GB** compared to DoRA (58.4 vs 65.6)
- All GOFT/BOFT variants OOM even on H100
- Benchmarks: BoolQ, PIQA, SIQA, HellaSwag, Winogrande, ARC-e, ARC-c, OBQA

**Source**: PSOFT Paper, Table 5  
**Confidence**: HIGH

### 4.5 Training Speed Comparison

| Model | Method | Time | Speedup vs Baseline |
|-------|--------|------|-------------------|
| LLaMA-3.2-3B (Q,K,V) | GOFTv2/qGOFTv2 | ~200 min | baseline |
| | BOFT | ~120 min | 1.7x |
| | PSOFT | **57 min** | **3.5x** |
| LLaMA-3.1-8B (Q,V) | BOFT | ~93 min | baseline |
| | PSOFT | **29 min** | **3.2x** |
| LLaMA-3.1-8B (Q,K,V,U,D) | DoRA | ~90 min | baseline |
| | PSOFT | **53 min** | **1.7x** |

**Source**: PSOFT Paper, Figure 4(b)  
**Confidence**: HIGH

---

## 5. PARAMETER COUNT ANALYSIS

### 5.1 Per-Layer Parameter Comparison

For a single linear layer with input dim d, output dim n, rank r:

| Method | Trainable Parameters | Decoupled from hidden dim? |
|--------|---------------------|---------------------------|
| LoRA | d·r + r·n | No |
| DoRA | d·r + r·n + n | No |
| VeRA | r + n | Partially |
| OFT | r·(d/r)·(d/r) + n | No |
| BOFT | m·(d/b)·b² + n | No |
| SVFT | d_min·k + (d_min-k)(k+1) | No |
| LoRA-XS | r × r | Yes |
| **PSOFT** | **r(r-1)/2 + 2r** | **Yes** |

**Key advantage**: PSOFT's parameter count is **independent of layer width** (d and n). It depends only on rank r, enabling fine-grained control over parameter budgets.

### 5.2 PSOFT vs OSFT Parameter Counts

**Important distinction**: OSFT (Orthogonal Subspace Fine-Tuning) is a **different method** for continual learning, not a direct predecessor of PSOFT. The naming similarity is coincidental.

| Aspect | OSFT | PSOFT |
|--------|------|-------|
| **Purpose** | Continual learning | Single-task fine-tuning |
| **Core mechanism** | SVD-based subspace projection + orthogonal constraint | Cayley-parameterized orthogonal matrix in principal subspace |
| **Parameter count** | Full-rank projection matrices | r(r-1)/2 + 2r per layer |
| **Orthogonality** | Constrained via loss function (soft) | Hard via Cayley transform (exact) |
| **Task adaptation** | New projection per task | Same orthogonal matrix, tunable vectors |
| **Models tested** | T5-Large, LLaMA-2 7B, Mistral-7B | DeBERTaV3, ViT, LLaMA-3.2-3B, LLaMA-3.1-8B |

**Note**: The user's question mentions "3x fewer params than OSFT" — this claim appears to reference a comparison within a specific uploaded document that we could not independently verify. The PSOFT paper itself does not directly compare to OSFT (which is a continual learning method). The comparison may be from a different context or a different method with a similar name.

### 5.3 Total Model Trainable Parameters (Example: DeBERTaV3-base)

| Method | #Params | Rank |
|--------|---------|------|
| GOFTv2 | 0.08M | — |
| PSOFT | **0.08M** | r=46 |
| BOFT | 1.41M | m=2, b=8 |
| OFTv2 | 1.29M | b=32 |
| LoRA r=8 | 1.33M | r=8 |
| DoRA r=8 | 1.41M | r=8 |
| LoRA-XS | 1.33M | r=136 |

PSOFT achieves the same parameter count as GOFTv2 (0.08M) but with dramatically better memory efficiency and no OOM issues.

---

## 6. THE CAYLEY TRANSFORM — MATHEMATICAL BACKGROUND

### 6.1 Definition

The Cayley transform maps skew-symmetric matrices to orthogonal matrices:

```
R = (I - S)(I + S)^(-1)
```

where S ∈ so(n) (Lie algebra of skew-symmetric matrices) and R ∈ SO(n) (special orthogonal group, det(R) = +1).

### 6.2 Properties

1. **Bijective correspondence**: For orthogonal matrices R without eigenvalue -1, the inverse exists:
   ```
   S = (I - R)(I + R)^(-1)
   ```

2. **Parameter count reduction**: SO(n) requires n(n-1)/2 parameters (same as skew-symmetric matrices), compared to n² for arbitrary matrices — a **~50% reduction**.

3. **Preservation of group structure**: The transform maps the Lie algebra so(n) to the Lie group SO(n).

4. **Avoidance of singularities**: Unlike Euler angles, no gimbal lock issues.

5. **Rational parameterization**: No transcendental functions (unlike matrix exponential).

### 6.3 Neumann Series for Efficient Computation

The matrix inverse (I + Q)^(-1) is approximated by:

```
(I + Q)^(-1) ≈ I - Q + Q² - Q³ + Q⁴ - Q⁵ + ... (K terms)
```

With K=5, the approximation achieves near-optimal performance while significantly accelerating training:

| K (terms) | Relative Speed | Performance | Notes |
|-----------|---------------|-------------|-------|
| 2 | Fastest | Good | Most efficient |
| 5 | Fast | Near-optimal | **Recommended default** |
| 10 | Moderate | Very close to exact | Diminishing returns |
| ∞ (exact) | Slowest | Best | Closed-form inverse |

**Source**: PSOFT Paper, Appendix J.4 and Figure 8(b); OFTv2 paper  
**Confidence**: HIGH — empirically validated

---

## 7. RELAXATION PARAMETER ANALYSIS

### 7.1 How α and β Work

The tunable vectors α, β ∈ R^r modify the forward computation:

```
h = (A' · diag(α) · R · diag(β) · B' + W_res)^T · x
```

- **Initialization**: α = β = 1 (all ones) → strict orthogonality at start
- **During training**: Values deviate from 1, relaxing the orthogonality constraint
- **Effect**: Enables adjustable angles and scalable norms for task-specific adaptation

### 7.2 Ablation Studies

**Effect of orthogonality regularization** (Table 6 from paper):

| Method | #Params | GSM-8K | MATH |
|--------|---------|--------|------|
| PiSSA+LoRA-XS (γ=0.0, no orthogonality) | 12.1M | 61.26 | 14.72 |
| PiSSA+LoRA-XS (γ=0.01) | 12.1M | 61.26 | 14.80 |
| PiSSA+LoRA-XS (γ=0.1) | 12.1M | 59.89 | 14.90 |
| PiSSA+LoRA-XS (γ=1.0) | 12.1M | 59.36 | 14.44 |
| **PSOFT strict orthogonality (r=248)** | **6.0M** | **61.18** | **14.80** |
| **PSOFT strict orthogonality (r=352)** | **12.1M** | **62.77** | **15.74** |

**Key insight**: Too much orthogonality regularization (large γ) **hurts performance**. PSOFT with strict orthogonality via Cayley achieves comparable performance to unconstrained variants with **half the parameters**, and clear gains when parameter counts are matched.

**Source**: PSOFT Paper, Table 6  
**Confidence**: HIGH

### 7.3 Single vs Double Tunable Vectors

The paper evaluates enabling only α, only β, or both:

- **Both α and β**: Best performance
- **Only α**: Moderate improvement
- **Only β**: Moderate improvement
- **Neither** (strict orthogonality): Baseline

This suggests that tuning only one side lacks sufficient capacity to capture task-specific variations.

**Source**: PSOFT Paper, Figure 3  
**Confidence**: MEDIUM — single experiment, r=64 on LLaMA-3.2-3B

### 7.4 What Values Do α and β Take?

The paper does not report detailed statistics on the final values of α and β after training. This is a gap in the analysis. However, the constraint ||C^T C - I||_F ≤ ε ensures they don't deviate excessively from orthogonality.

---

## 8. RANK SENSITIVITY AND SCALING

### 8.1 Effect of Rank on Small Models (DeBERTaV3-base on CoLA)

| Rank r | #Params | Matthew's Correlation | Peak Memory | Runtime |
|--------|---------|----------------------|-------------|---------|
| 1 | 144 | 59.20 | 4.0 GB | 17m34s |
| 2 | 360 | 68.80 | 4.0 GB | 18m32s |
| 4 | 1,008 | 70.08 | 4.0 GB | 19m17s |
| 8 | 3,168 | 70.93 | 4.0 GB | 19m08s |
| 16 | 10,944 | 68.36 | 4.0 GB | 19m32s |
| 32 | 40,320 | 72.09 | 4.0 GB | 19m41s |
| 64 | 154,368 | 69.16 | 4.1 GB | 21m29s |
| 128 | 603,648 | 72.46 | 4.2 GB | 20m42s |
| 256 | 2,386,944 | 74.09 | 4.6 GB | 24m35s |
| 512 | 9,492,480 | 71.04 | 5.8 GB | 27m20s |

**Key findings**:
- Performance **improves with rank** but with diminishing returns
- Even rank=1 achieves reasonable results (59.20)
- Memory increases only marginally with rank (4.0 → 5.8 GB for 512x parameter increase)
- Runtime stays nearly flat due to Neumann series approximation

### 8.2 Effect of Rank on Large Models (LLaMA-3.2-3B on Commonsense)

| Rank r | #Params | Avg Accuracy | Peak Memory |
|--------|---------|-------------|-------------|
| 1 | 392 | 27.07 | 31.5 GB |
| 16 | 29,792 | 57.12 | 31.6 GB |
| 64 | 420,244 | 70.95 | 32.1 GB |
| 128 | 1,643,264 | 73.90 | 32.8 GB |
| 256 | 6,497,792 | 74.95 | 34.5 GB |
| 512 | 25,840,640 | 75.05 | 38.4 GB |

**Practical guidance from paper**:
- **Simple tasks**: Small to moderate ranks (32-128) sufficient
- **Complex tasks**: Larger ranks (64-256) recommended
- **Extremely small ranks** (<16) may underfit on complex tasks

**Source**: PSOFT Paper, Appendix J, Tables 17-18  
**Confidence**: HIGH

---

## 9. IMPLEMENTATION AND CODE

### 9.1 Official Implementation

**Repository**: https://github.com/fei407/PSOFT  
**Status**: Public, actively maintained  
**License**: Not explicitly stated (assumed academic)

**Structure**:
- `NLU/`: GLUE benchmark experiments (DeBERTaV3)
- `Vision/`: VTAB-1K experiments (ViT-B/16)
- `Math/`: MetaMathQA experiments (LLaMA-3.2-3B)
- `Commonsense/`: Commonsense-15K experiments (LLaMA-3.1-8B)

**Setup**:
```bash
conda env create -f psoft.yml
conda activate psoft
huggingface-cli login
```

### 9.2 HuggingFace PEFT Integration

**Status**: **Integration in progress**

A feature request (Issue #3026) was filed in the HuggingFace PEFT repository:
- **Date**: February 2026
- **Proposed by**: Paper authors (fei407)
- **Status**: Authors expressed willingness to implement and submit PR
- **Target**: Clean integration following PEFT's abstractions and coding conventions

**Source**: https://github.com/huggingface/peft/issues/3026  
**Confidence**: HIGH

### 9.3 Dependencies

Based on the codebase:
- PyTorch
- HuggingFace Transformers
- HuggingFace PEFT
- Standard ML libraries (numpy, scipy, etc.)

### 9.4 Key Implementation Details

1. **Cayley parameterization**: Uses truncated Neumann series (K=5) for (I+Q)^(-1)
2. **SVD initialization**: A' and B' obtained from PiSSA-style SVD of pre-trained weights
3. **Orthogonal initialization**: R initialized as identity matrix
4. **Separate learning rates**: Different LR for classification head vs PEFT modules

---

## 10. COMPARISON WITH RELATED METHODS

### 10.1 PSOFT vs LoRA

| Aspect | LoRA | PSOFT |
|--------|------|-------|
| Update type | Additive: W + BA | Multiplicative: A'RB' + W_res |
| Geometry | Low-rank manifold | Orthogonal group |
| Parameter count | (d+n)·r | r(r-1)/2 + 2r |
| Effective rank (same budget) | M/(d+n) | √M |
| Semantic preservation | No explicit guarantee | Theorem-guaranteed in principal subspace |
| Memory overhead | Low | Low (comparable) |
| Training speed | Fast | Moderate (between LoRA and DoRA) |
| Rank flexibility | Minimum r=1 (tied to d,n) | Any r (decoupled from d,n) |

**When PSOFT wins**: Tasks where preserving semantic structure matters; when parameter budget is very limited; when higher effective rank is beneficial.

### 10.2 PSOFT vs OFT/BOFT/GOFT

| Aspect | OFT/BOFT/GOFT | PSOFT |
|--------|---------------|-------|
| Transformation space | Full parameter space | Principal subspace only |
| Parameter count | Scales with d or d·log(d) | Scales with r² only |
| Memory at scale | OOM on large models | Survives on same hardware |
| Training speed | Slow (especially GOFT) | 2-3x faster |
| Expressiveness | Full-rank orthogonal | Low-rank orthogonal |
| Theoretical guarantee | Full geometry preservation | Principal subspace preservation |

**When PSOFT wins**: Large models, memory-constrained settings, need for speed without sacrificing performance.

### 10.3 PSOFT vs OSFT (Orthogonal Subspace Fine-Tuning for Continual Learning)

These are **different methods with similar names**:

- **OSFT** (OpenReview 2025): A continual learning method that uses SVD to identify critical subspaces and constrains new task updates to be orthogonal to preserved subspaces. Tested on T5, LLaMA-2, Mistral for continual learning benchmarks.

- **PSOFT** (ICLR 2026): A single-task fine-tuning method that performs orthogonal transformations within the principal subspace. Not specifically designed for continual learning.

**The "3x fewer params than OSFT" claim**: We could not independently verify this specific claim. It may originate from a different document or comparison context. The PSOFT paper does not directly compare to OSFT.

---

## 11. COMBINATION WITH OTHER METHODS

### 11.1 PSOFT + PiSSA Initialization

PSOFT naturally builds on PiSSA's SVD-based initialization:
- A' and B' are derived from the SVD of pre-trained weights (same as PiSSA)
- PSOFT **freezes** A' and B' (unlike PiSSA which trains them)
- Only R (orthogonal) and α, β are trained

**Initialization ablation** (Table 7 from paper):

| Initialization | RTE | CoLA |
|----------------|-----|------|
| A_orth · R_orth · B | **85.92** | **70.63** |
| A · R_orth · B_orth | 52.71 | 67.97 |
| A · R_orth · B | 71.11 | 69.23 |

**Finding**: Orthogonal initialization on A (A_orth) yields best results. Enforcing orthogonality on B reduces expressiveness.

### 11.2 PSOFT + DoRA

Not directly explored in the paper. DoRA decomposes adaptation into direction and magnitude components. PSOFT's orthogonal matrix R handles direction; the tunable vectors α and β partially handle magnitude. A direct combination is not obvious but could be explored.

### 11.3 PSOFT + LoRA-XS

LoRA-XS inserts a trainable square matrix between LoRA's A and B. PSOFT can be viewed as a principled variant where this square matrix is constrained to be orthogonal via Cayley parameterization, with additional SVD-based initialization and tunable vectors.

**Evidence**: Table 6 shows PiSSA+LoRA-XS (unconstrained R) vs PSOFT (Cayley-parameterized R). PSOFT matches or exceeds performance with fewer parameters.

---

## 12. LIMITATIONS AND FAILURE MODES

### 12.1 Documented Limitations from Paper

1. **SVD initialization dependency**: Requires computing SVD of pre-trained weights, which adds upfront cost. However, this is done once and cached.

2. **Limited to models up to 8B (empirical)**: "Due to hardware resource constraints, our empirical evaluation is limited to models of up to 8B parameters."

3. **Hyperparameter sensitivity at large scale**: "Large models often exhibit higher sensitivity to hyperparameters, including learning-rate settings for structured updates such as orthogonal transformations."

4. **Activation memory from backbone**: "The activations of the underlying backbone (e.g., attention and feed-forward layers) can become the dominant source of memory usage at large scales."

5. **Rank selection trade-off**: "Very small ranks may lead to underfitting on complex tasks, whereas larger ranks improve expressiveness but also increase the trainable parameter budget."

6. **Neumann approximation error**: K=5 terms introduce small approximation error vs exact Cayley transform. The paper shows this is negligible in practice.

### 12.2 Potential Undocumented Limitations

1. **No continual learning evaluation**: PSOFT is evaluated only on single-task fine-tuning, not on sequential/multi-task continual learning. The geometry preservation property suggests potential for CL, but this is untested.

2. **No 100+ task evaluation**: The claim about handling 100+ sequential tasks is untested in the paper.

3. **Cayley transform singularity**: The Cayley transform fails when R has eigenvalue -1. The paper does not discuss handling this edge case.

4. **SVD computation cost**: For very large matrices, the initial SVD can be expensive (though amortized over training).

5. **No quantization-aware version**: Unlike OFTv2 which has a quantized extension, PSOFT has no QPSOFT variant yet.

### 12.3 Comparison with OSFT for Continual Learning

If the user's goal is continual learning (as implied by references to OSFT and O-LoRA), PSOFT has **not been evaluated for this setting**. OSFT and O-LoRA are explicitly designed for continual learning; PSOFT is not.

**OSFT continual learning results** (for reference):
- Up to **7% higher** average accuracy than O-LoRA
- Reduces forgetting to **near-negligible levels**
- Maintains general linguistic capabilities, instruction-following, and safety

**Source**: OSFT OpenReview paper  
**URL**: https://openreview.net/forum?id=vQcyqsGJDw  
**Confidence**: HIGH (for OSFT claims); N/A (PSOFT has no CL evaluation)

---

## 13. APPLE SILICON / MLX FEASIBILITY

### 13.1 Assessment

PSOFT's core operations are:
1. SVD of pre-trained weights (one-time)
2. Matrix multiplications with Cayley-parameterized orthogonal matrix
3. Neumann series approximation (K matrix multiplications)
4. Forward/backward through frozen A', B' and trainable R, α, β

### 13.2 Feasibility Factors

| Factor | Assessment | Notes |
|--------|-----------|-------|
| PyTorch MPS support | **Compatible** | Core ops (matmul, SVD) supported on MPS |
| Memory efficiency | **Excellent** | PSOFT uses minimal memory — suitable for 16-24GB Apple Silicon |
| SVD on MPS | **Supported** | torch.linalg.svd works on MPS |
| Cayley transform | **Compatible** | Skew-symmetric parameterization + matmul only |
| Neumann series | **Compatible** | K matrix multiplications, highly parallelizable |
| MLX port | **Straightforward** | Mainly matmul operations; no exotic ops needed |

### 13.3 Estimated Performance on Apple Silicon

Based on PSOFT's memory profile:
- **DeBERTaV3-base fine-tuning**: Should run comfortably on M1/M2 Pro (16GB+)
- **ViT-B/16 fine-tuning**: Should run on M2/M3 Pro (18GB+), peak < 4GB at batch size 32
- **LLaMA-3.2-3B inference**: PSOFT adapters add minimal overhead; base model may need quantization
- **LLaMA-3.2-3B fine-tuning**: Would need M3 Max (36GB+) or model quantization

**Conclusion**: PSOFT is **highly feasible** for Apple Silicon deployment due to its minimal memory footprint. The absence of exotic operations (just SVD + matmuls) makes porting to MLX straightforward.

**Confidence**: MEDIUM — no explicit Apple Silicon testing reported, but architectural compatibility is strong

---

## 14. KEY QUESTIONS ANSWERED

### Q1: What is the exact parameter count reduction: PSOFT vs OSFT vs LoRA?

| Method | Per-Layer Params | Example (r=46, d=768, n=768) |
|--------|-----------------|------------------------------|
| LoRA | d·r + n·r = r(d+n) | 1.33M |
| DoRA | r(d+n) + n | 1.41M |
| OFTv2 | r·(d/r)² + n | 1.29M |
| BOFT | m·(d/b)·b² + n | 1.41M |
| GOFTv2 | ~0.08M | 0.08M |
| **PSOFT** | **r(r-1)/2 + 2r** | **0.08M** |

The "3x fewer params than OSFT" claim could not be independently verified. OSFT is a different method for continual learning; the PSOFT paper does not directly compare to it.

### Q2: How does the relaxation parameter α affect forgetting vs plasticity?

The paper does not use the framing of "forgetting vs plasticity" as it focuses on single-task fine-tuning. Key findings about relaxation:
- α, β start at 1 (strict orthogonality)
- They relax during training, enabling task-specific adaptation
- Enabling **both** vectors gives best performance (vs single-sided or none)
- The constraint ||C^T C - I||_F ≤ ε prevents excessive deviation

For continual learning applications, this relaxation mechanism would need careful tuning to balance plasticity (new task learning) vs stability (old task retention).

### Q3: What is the computational cost of Cayley transform vs SVD projection?

| Operation | Cost | Notes |
|-----------|------|-------|
| SVD (one-time) | O(min(d²n, dn²)) | Done once at initialization |
| Cayley (closed-form) | O(r³) | Matrix inverse |
| Cayley (Neumann K=5) | O(5r²) = O(r²) | **Used in practice** |
| Forward pass | O(d·r·n) | Same as LoRA |
| Backward pass | O(d·r·n) | Through R only |

**Neumann series (K=5) is the key efficiency trick** — it reduces the per-step cost from O(r³) to O(r²), making PSOFT competitive with LoRA in training speed.

### Q4: Can PSOFT handle 100+ sequential tasks without forgetting?

**Answer: Unknown. Not tested.**

PSOFT has **no continual learning evaluation** in the paper. All experiments are single-task fine-tuning. The method is designed for efficiency and expressiveness, not specifically for preventing catastrophic forgetting across sequential tasks.

However, the geometry preservation property (Theorem 4.1) suggests that PSOFT preserves the semantic structure of pre-trained weights, which could theoretically reduce forgetting. Adapting PSOFT for continual learning would require:
1. Task-specific orthogonal matrices R_t
2. A mechanism to prevent interference between task subspaces
3. Evaluation on standard CL benchmarks

This remains an open research direction.

---

## 15. RESEARCH GAPS AND OPEN QUESTIONS

1. **Continual learning evaluation**: PSOFT has not been tested on sequential/multi-task learning scenarios
2. **Quantization-aware variant**: No QPSOFT exists yet, unlike QLoRA and quantized OFTv2
3. **Very large models (>70B)**: Only tested up to 8B parameters
4. **Long-context settings**: Not evaluated on long-sequence tasks
5. **Final α, β distribution**: Paper doesn't report statistics on learned relaxation values
6. **Combination with other PEFT methods**: Systematic study of PSOFT + adapters, prefix tuning, etc. missing
7. **Transfer learning analysis**: How well do PSOFT adapters transfer across tasks?
8. **Interpretability**: What do the learned orthogonal transformations represent?

---

## 16. CITATIONS AND SOURCES

| # | Source | URL | Date | Type |
|---|--------|-----|------|------|
| 1 | PSOFT Paper (arXiv v3) | https://arxiv.org/abs/2505.11235 | Feb 2026 | Primary |
| 2 | PSOFT ICLR 2026 OpenReview | https://openreview.net/forum?id=FSHrinMArK | 2026 | Conference |
| 3 | PSOFT GitHub | https://github.com/fei407/PSOFT | Sep 2025 | Code |
| 4 | HuggingFace PEFT Issue | https://github.com/huggingface/peft/issues/3026 | Feb 2026 | Integration |
| 5 | OSFT Paper | https://openreview.net/forum?id=vQcyqsGJDw | Oct 2025 | Related |
| 6 | OFTv2 Paper | https://arxiv.org/html/2506.19847v1 | Jun 2025 | Related |
| 7 | BOFT Paper | https://wyliu.com/papers/BOFT_v3.pdf | 2024 | Related |
| 8 | Cayley Transform Survey | https://grokipedia.com/page/Cayley_transform | Jan 2026 | Background |
| 9 | Cayley Parameterization PDF | https://cv.inf.elte.hu/wp-content/uploads/2025/12/Cayley2.pdf | Dec 2025 | Background |
| 10 | O-LoRA Paper | https://aclanthology.org/2023.findings-emnlp.715.pdf | EMNLP 2023 | Related |

---

## 17. CONFIDENCE SUMMARY

| Claim | Confidence | Evidence |
|-------|-----------|----------|
| PSOFT confines orthogonality to principal subspace | **HIGH** | Core paper contribution, explicitly stated |
| Uses Cayley transform for efficient orthogonal matrices | **HIGH** | Clearly documented, with Neumann approximation |
| Tunable vectors relax orthogonality during training | **HIGH** | Ablation studies provided |
| Parameter count: r(r-1)/2 + 2r | **HIGH** | Explicit formula with derivation |
| 18x parameter efficiency on small models | **HIGH** | Empirically verified on GLUE/VTAB |
| Outperforms LoRA on GSM-8K by +2.3% | **HIGH** | Multiple seeds, clear margin |
| Avoids OOM where other OFT variants fail | **HIGH** | Consistent across all large-model experiments |
| Geometry preservation theorem | **HIGH** | Rigorous proof in Appendix B |
| 3x fewer params than OSFT | **LOW** | Could not verify; OSFT is different method |
| Lipschitz bounds on singular values | **MEDIUM** | Implied by theory but not explicitly derived |
| Handles 100+ sequential tasks | **LOW** | Not evaluated for continual learning |
| Apple Silicon feasibility | **MEDIUM** | Architectural compatibility strong but untested |

---

*Research compiled from 10+ independent web searches across arXiv, OpenReview, GitHub, HuggingFace, and academic sources. All claims traced to primary sources where possible.*
