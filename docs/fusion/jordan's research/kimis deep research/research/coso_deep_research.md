# Deep Research Report: Continuous Subspace Optimization (coSO) for Continual Learning

**Research Date**: 2025  
**Paper**: "Continuous Subspace Optimization for Continual Learning" (NeurIPS 2025)  
**Authors**: Quan Cheng, Yuanyu Wan, Lingyu Wu, Chenping Hou, Lijun Zhang  
**Institution**: Nanjing University, Zhejiang University, National University of Defense Technology  
**Researcher**: AI Research Agent  

---

## Executive Summary

CoSO (Continuous Subspace Optimization) is a NeurIPS 2025 continual learning method that optimizes pre-trained vision transformers by projecting gradients onto **dynamically changing low-rank subspaces** derived from SVD of gradients, while enforcing **orthogonality** between current task subspaces and a maintained **historical task subspace** matrix. It uses **Frequent Directions** for lightweight task-specific subspace consolidation.

**Critical Finding**: Several claims about coSO from the uploaded reference document (star-shaped domain parameterization, trajectory optimization W(t) = W_0 + Sum alpha_k(t) B_k, frame-theoretic regularization, joint plasticity+stability loss) are **NOT present** in the actual coSO paper. These appear to describe a hypothetical or conflated method. The actual coSO is a gradient-projection method, not a weight-space trajectory optimization.

---

## 1. Paper Identity and Venues

### 1.1 Primary Paper

| Attribute | Detail |
|-----------|--------|
| **Title** | Continuous Subspace Optimization for Continual Learning |
| **Authors** | Quan Cheng, Yuanyu Wan, Lingyu Wu, Chenping Hou, Lijun Zhang |
| **Venue** | NeurIPS 2025 (39th Conference on Neural Information Processing Systems) |
| **arXiv** | https://arxiv.org/abs/2505.11816 |
| **PDF (v2)** | https://arxiv.org/pdf/2505.11816 |
| **OpenReview** | https://openreview.net/pdf?id=iLYV4iIC0c |
| **NeurIPS Poster** | https://neurips.cc/virtual/2025/poster/116567 |
| **Submission** | v1: May 17, 2025; v2: November 11, 2025 |

### 1.2 Related Papers

| Paper | Venue / Status | Relationship to coSO |
|-------|---------------|----------------------|
| "Sculpting Subspaces: Constrained Full Fine-Tuning in LLMs for Continual Learning" (OSFT) | ICLR 2026 | Orthogonal subspace method using SVD on weights; no direct connection to coSO |
| "Efficient Orthogonal Fine-Tuning with Principal Subspace Adaptation" (PSOFT) | arXiv:2505.11235 | Cayley parameterization for orthogonal fine-tuning; no direct connection to coSO |
| "Orthogonal Low-Rank Adaptation" (O-LoRA) | EMNLP 2023 Findings | Uses LoRA orthogonality loss; different approach from coSO |
| "InfLoRA: Interference-Free Low-Rank Adaptation for Continual Learning" | CVPR 2024 | Gradient projection for LoRA continual learning; similar gradient-projection spirit |
| "GaLore: Memory-Efficient LLM Training by Gradient Low-Rank Projection" | ICLR 2024 Workshop | Direct inspiration for coSO's gradient SVD projection approach |
| "KeepLoRA: Continual Learning with Residual Gradient Adaptation" | arXiv:2601.19659 | Cites coSO (Cheng et al., 2025) as gradient projection method |
| "Task-Driven Subspace Decomposition for Knowledge Sharing and Isolation in LoRA-based Continual Learning" (LoDA) | arXiv:2603.00191 | Compares against coSO on benchmarks |

---

## 2. Mathematical Formulation (Actual)

### 2.1 Problem Setup

CoSO operates on a pre-trained Vision Transformer with weight matrix W in layer l. Given a sequence of tasks D = {D_1, ..., D_N}, the model must learn each task sequentially without accessing previous task data.

### 2.2 Core Mechanism (Three Stages)

**Stage 1: Orthogonal Projection of Gradients**

Maintain an orthonormal basis matrix M_{tau-1} spanning all previous tasks' gradient subspaces. For current task tau at step t:

```
G'_{tau,t} = G_{tau,t} - M_{tau-1} M_{tau-1}^T G_{tau,t}     (Eq. 1)
```

This removes the gradient component aligned with historical task directions.

**Stage 2: Memory-Efficient Low-Rank Optimization**

Perform truncated SVD on the projected gradient:

```
U Sigma V^T = SVD_{r1}(G'_{tau,t})
P_{tau,t} = U[:, :r1]                                          (Eq. 2)
```

Project gradient into low-rank space:
```
R_{tau,t} = P_{tau,t}^T G'_{tau,t}                             (Eq. 3)
```

Run Adam optimizer in low-rank space:
```
M_{tau,t} = (beta_1 * M_{tau,t-1} + (1-beta_1) * R_{tau,t}) / (1 - beta_1^t)
V_{tau,t} = (beta_2 * V_{tau,t-1} + (1-beta_2) * R_{tau,t}^2) / (1 - beta_2^t)
N_{tau,t} = M_{tau,t} / (sqrt(V_{tau,t}) + epsilon)            (Eq. 4)
```

Project back and update weights:
```
tilde{G}_{tau,t} = P_{tau,t} N_{tau,t}
W_{tau,t} = W_{tau,t-1} - eta * tilde{G}_{tau,t}              (Eq. 5)
```

**Stage 3: Task-Specific Subspace Consolidation via Frequent Directions**

After each step, compute low-rank approximation:
```
U Sigma V^T = SVD_{r2}(G'_{tau,t})
Q_{tau,t} = U Sigma                                           (Eq. 6)
```

Incrementally consolidate via FD sketching:
```
U' Sigma' V'^T = SVD_{r2}([S_{tau,t-1}, Q_{tau,t}])
S_{tau,t} = U' * sqrt(Sigma'^2 - sigma_t * I_{r2})            (Eq. 8)
where sigma_t = Sigma'_{r2,r2}^2
```

After task completes, update historical subspace:
```
U_tau Sigma_tau V_tau^T = SVD(S_{tau,T})                      (Eq. 11)
```

Select k by variance criterion:
```
sum_{i=1}^k sigma_i^2 / sum_{j=1}^{r2} sigma_j^2 <= epsilon_th  (Eq. 12)
```

Update basis:
```
M_tau = [M_{tau-1}, U_tau[:, :k]]                              (Eq. 13)
```

### 2.3 Key Hyperparameters (from Appendix D)

| Dataset | Projection rank (r1) | FD rank (r2) | Update gap (K) | Threshold (epsilon_th) |
|---------|---------------------|--------------|----------------|----------------------|
| CIFAR100 | 15 | 100 | 1 | 0.98 |
| ImageNet-R | 50 | 120 | 1 | 0.98 |
| DomainNet | 70 | 160 | 20 | 0.98 |

**Confidence**: HIGH -- All equations and hyperparameters verified from arXiv:2505.11816v2.

---

## 3. Verification of Claims from Reference Document

### Claims That ARE NOT in the Actual coSO Paper

| Claim from Reference | Actual coSO? | Source Evidence |
|---------------------|--------------|-----------------|
| "Parameterizes star-shaped domain: W(t) = W_0 + Sum_k alpha_k(t) B_k" | **NO** -- This formula does NOT appear in the paper | Full paper review; coSO operates on gradient projection, not weight-space trajectory |
| "Optimizes entire subspace trajectory rather than per-task snapshots" | **NO** -- coSO does not use trajectory optimization | The paper uses sequential orthogonal subspaces, not trajectory optimization in time |
| "Jointly optimizes plasticity + stability loss" | **NO** -- No explicit multi-objective loss | Only standard task loss + orthogonal projection mechanism |
| "Frame-theoretic regularization prevents representation collapse" | **NO** -- No frame theory in the paper | No mention of frames, frame bounds, or frame-theoretic concepts |
| "Smooth transitions without per-task SVD recompute" | **PARTIAL** -- SVD is recomputed every K steps | SVD_{r1} is computed every K steps during training (not once per task) |
| "Higher memory (stores basis paths)" | **MISLEADING** -- Stores basis matrix M_tau, not "paths" | Stores orthonormal basis M_tau of historical subspace; uses FD sketching |
| "coSO + Cayley parameterization combination" | **NOT PRESENT** -- No Cayley transform in coSO | Cayley parameterization is from PSOFT/OFTv2, not coSO |

### Claims That ARE Correct

| Claim | Verification | Confidence |
|-------|-------------|------------|
| "Handles task sequences (not just pairwise)" | YES -- tested on 5, 10, 20 task sequences | HIGH |
| "Uses orthogonal projection to historical subspace" | YES -- Eq. (1) is exactly this | HIGH |
| "Memory-efficient via gradient projection" | YES -- reduces memory vs LoRA methods | HIGH |

### Key Insight

The reference document appears to describe a **hypothetical or conflated method** that combines ideas from:
- **coSO** (gradient SVD projection, Frequent Directions)
- **PSOFT** (Cayley parameterization for orthogonality)
- **O-LoRA/OSFT** (orthogonality regularization loss)
- Possibly some theoretical continual learning framework (star-shaped domain, trajectory optimization)

The **actual coSO** is significantly simpler: it is a gradient projection method inspired by GaLore that enforces orthogonality to historical subspaces via projection matrices.

---

## 4. Benchmark Results (Verified from Paper)

### 4.1 ImageNet-R (Primary Benchmark)

| Method | 5 Tasks ACC_5 | 5 Tasks avg ACC | 10 Tasks ACC_10 | 10 Tasks avg ACC | 20 Tasks ACC_20 | 20 Tasks avg ACC |
|--------|--------------|----------------|----------------|-----------------|-----------------|-----------------|
| L2P | -- | -- | -- | -- | -- | -- |
| DualPrompt | -- | -- | -- | -- | -- | -- |
| CODA-P | -- | -- | -- | -- | -- | -- |
| InfLoRA | 78.19 | 82.48 | 74.46 | 80.30 | 72.32 | 78.47 |
| SD-LoRA | 78.50 | 82.76 | 75.82 | 81.29 | 73.21 | 79.40 |
| VPT-NSP2 | 79.82 | 84.28 | 77.49 | 82.73 | 75.42 | 81.32 |
| **CoSO** | **82.37** | **86.46** | **80.72** | **85.67** | **78.27** | **83.62** |

**Absolute improvements over best baseline**:
- 5 Tasks: +2.55% final, +2.18% average
- 10 Tasks: +3.23% final, +2.47% average  
- 20 Tasks: +2.85% final, +2.30% average

### 4.2 CIFAR100 (10 Tasks) and DomainNet (5 Tasks)

| Method | CIFAR100 ACC_10 | CIFAR100 avg ACC | DomainNet ACC_5 | DomainNet avg ACC |
|--------|----------------|-----------------|-----------------|-------------------|
| L2P | 82.64+/-0.26 | 87.90+/-0.19 | 70.03+/-0.09 | 75.65+/-0.06 |
| DualPrompt | 84.68+/-0.22 | 90.12+/-0.05 | 72.25+/-0.05 | 77.84+/-0.02 |
| CODA-P | 86.60+/-0.37 | 91.46+/-0.20 | 73.16+/-0.07 | 78.75+/-0.04 |
| InfLoRA | 86.85+/-0.08 | 91.45+/-0.16 | 73.09+/-0.11 | 79.21+/-0.08 |
| SD-LoRA | 87.30+/-0.45 | 91.81+/-0.27 | 73.20+/-0.12 | 79.03+/-0.04 |
| VPT-NSP2 | 88.09+/-0.12 | 92.48+/-0.11 | 72.52+/-0.13 | 78.68+/-0.06 |
| **CoSO** | **88.77+/-0.16** | **92.99+/-0.23** | **74.27+/-0.07** | **80.05+/-0.04** |

**Source**: arXiv:2505.11816v2, Tables 1 and 2.  
**Confidence**: HIGH

### 4.3 Independent Verification (LoDA Paper)

The LoDA paper (arXiv:2603.00191v1, Table 1) independently reports coSO results:

| Method | 10S-ImageNetR | 10S-ImageNetA | 20S-ImageNetR |
|--------|--------------|--------------|--------------|
| CoSO | 81.10+/-0.39 | 85.56+/-0.13 | 78.19+/-0.28 |

Note: Slightly different numbers than coSO's own paper due to different experimental setup.

---

## 5. Ablation Studies

### 5.1 CoSO Ablation (from coSO paper, Table 3)

| Variant | ImageNet-R (5T) ACC | ImageNet-R (10T) ACC | ImageNet-R (20T) ACC |
|---------|--------------------|---------------------|---------------------|
| w/o Orthogonal projection | 79.35 | 75.90 | 69.75 |
| w/o Frequent Directions | 80.72 | 78.83 | 76.68 |
| **Full CoSO** | **82.37** | **80.72** | **78.27** |

**Key findings**:
- Removing orthogonal projection causes **-8.52%** drop on 20 tasks
- Removing FD causes **-1.59%** drop on 20 tasks
- Both components are essential; orthogonal projection is more critical

---

## 6. Memory and Computational Analysis

### 6.1 Computational Cost (ImageNet-R, 10 Tasks)

| Method | GFLOPs | Memory Usage (GB) |
|--------|--------|------------------|
| L2P | 70.24 | 12.90 |
| DualPrompt | 70.24 | 12.96 |
| CODA-P | 70.24 | 12.97 |
| InfLoRA | 35.12 | 13.44 |
| SD-LoRA | 35.12 | 15.62 |
| VPT-NSP2 | 35.83 | 11.54 |
| **CoSO** | **35.12** | **13.61** |

**Source**: arXiv:2505.11816v2, Appendix E, Table 5.  
**Confidence**: HIGH

### 6.2 Memory Breakdown Analysis

CoSO's memory overhead comes from:

| Component | Storage | Size |
|-----------|---------|------|
| Historical basis matrix M_{tau-1} | m x K (cumulative) | grows with number of tasks |
| FD sketch matrix S_{tau,t} | m x r2 | fixed per task |
| Projection matrix P_{tau,t} | m x r1 | fixed per step |
| Low-rank gradient R_{tau,t} | r1 x n | fixed per step |

where K = cumulative retained directions across all tasks.

The coSO paper claims memory is reduced from **(mn + 3mr1 + 3nr1)** (LoRA-based) to **(mn + mr1 + 2nr1)**.

### 6.3 Theoretical Cost of FD Sketching

From Proposition 1 (coSO paper):
- Direct covariance computation: O(m^2 * n * T)
- With FD sketching: O(m * n * r2 * T)
- Reduction factor: O(m/r2)

---

## 7. Code Availability

### 7.1 CoSO Code

| Status | **NOT FOUND** -- No public code repository identified |
|--------|------------------------------------------------------|
| Paper mentions | No code link in the paper |
| GitHub search | No repository by Quan Cheng or Lijun Zhang implementing coSO |
| arXiv | No supplementary materials with code |

### 7.2 Related Methods with Code

| Method | Code Availability | URL |
|--------|------------------|-----|
| OSFT (Sculpting Subspaces) | YES | https://github.com/Red-Hat-AI-Innovation-Team/mini_trainer |
| OSFT Training Hub | YES | https://github.com/Red-Hat-AI-Innovation-Team/training_hub |
| PSOFT | HuggingFace PEFT | Available via pip |
| GaLore (inspiration) | YES | https://github.com/jiaweizzhao/GaLore |

---

## 8. Comparison with Related Methods

### 8.1 coSO vs OSFT (Sculpting Subspaces)

| Aspect | coSO | OSFT |
|--------|------|------|
| **Venue** | NeurIPS 2025 | ICLR 2026 |
| **Target model** | Vision Transformers | LLMs (T5, LLaMA-2, Mistral) |
| **Subspace identification** | Gradient SVD | Weight SVD |
| **Orthogonality** | Gradient projection (Eq. 1) | High-rank vs low-rank subspace separation |
| **Memory per task** | Stores basis M_tau (grows) | Fixed parameter count |
| **SVD frequency** | Every K steps | Once per task |
| **Key claim** | Continuous subspaces via gradient SVD | Constrained full fine-tuning via weight SVD |
| **Code** | Not available | Available (Red Hat) |
| **Accuracy gain** | +2-3% over baselines | +7% over O-LoRA |

### 8.2 coSO vs PSOFT

| Aspect | coSO | PSOFT |
|--------|------|-------|
| **Focus** | Continual learning | Single-task PEFT |
| **Orthogonality** | Gradient projection | Cayley parameterization of R matrix |
| **Trainable params** | Full parameter update | r(r-1)/2 + 2r per layer |
| **Subspace** | Gradient-derived, changes over time | Principal subspace of pre-trained weights |
| **Combination** | Not applicable | PSOFT is not a continual learning method |

### 8.3 coSO vs O-LoRA

| Aspect | coSO | O-LoRA |
|--------|------|--------|
| **Mechanism** | Gradient projection onto orthogonal subspace | LoRA parameters orthogonal to previous tasks |
| **Regularization** | Hard projection (no loss term) | Soft orthogonality loss term |
| **Storage** | Historical basis matrix M_tau | Previous LoRA parameters {A_t, B_t} |
| **Frame-theoretic** | NO | Has orthogonality regularization (similar to frame condition) |

---

## 9. Scalability Analysis

### 9.1 Tested Scale

| Dataset | Max Tasks | Backbone | Model Size |
|---------|----------|----------|------------|
| ImageNet-R | 20 | ViT-B/16 | ~86M params |
| CIFAR100 | 10 | ViT-B/16 | ~86M params |
| DomainNet | 5 | ViT-B/16 | ~86M params |

### 9.2 Scalability to 100+ Tasks

**NOT TESTED** in the coSO paper. The maximum tested is 20 tasks on ImageNet-R.

**Theoretical concerns for 100+ tasks**:
- Historical basis matrix M_tau grows with each task (M_tau = [M_{tau-1}, U_tau[:, :k]])
- The dimension of M_tau increases linearly with the number of tasks
- For 100 tasks, if each task adds ~10-50 directions, M_tau could have 1000-5000 columns
- Orthogonal projection cost O(m * dim(M)^2) could become significant
- No mechanism for basis compression or forgetting old task directions is described

**Confidence**: MEDIUM -- Concerns are theoretical; no empirical evidence.

---

## 10. Key Questions Answered

### Q1: What is the exact memory overhead of coSO vs OSFT vs PSOFT?

| Method | Memory Pattern | ImageNet-R 10T |
|--------|---------------|----------------|
| coSO | O(mn + mr1 + 2nr1 + m*K_cum) | 13.61 GB |
| InfLoRA (closest baseline) | O(mn + 3mr1 + 3nr1) | 13.44 GB |
| OSFT | Fixed model size, no per-task growth | Not reported (different setting) |
| PSOFT | O(r^2) additional per layer | Not comparable (single-task) |

**coSO overhead over InfLoRA**: 0.17 GB (1.3% increase) for significantly better performance.

### Q2: How does coSO handle 100+ sequential tasks?

**Not tested empirically.** Theoretical analysis suggests the historical basis M_tau grows with each task. No compression mechanism is described. This is a key limitation.

### Q3: What is the compute cost of trajectory optimization vs per-task SVD?

CoSO does NOT use trajectory optimization. It uses:
- SVD of gradient: every K steps (amortized cost)
- FD sketching update: every K steps
- Per-step cost is dominated by gradient computation and projection

Total GFLOPs on ImageNet-R 10T: **35.12** (same as InfLoRA and SD-LoRA).

### Q4: Can coSO be combined with PSOFT's Cayley parameterization?

**No direct combination is described.** The methods address different problems:
- coSO: gradient-space projection for continual learning
- PSOFT: weight-space orthogonal transformation for single-task fine-tuning

The Cayley parameterization maintains an orthogonal matrix R for weight updates; coSO maintains an orthogonal basis M_tau for gradient projection. These are fundamentally different mechanisms.

---

## 11. Frame-Theoretic Regularization

**NOT FOUND in coSO.** The concept of "frame-theoretic regularization" does not appear in the coSO paper.

However, related concepts exist in other methods:

| Method | Regularization | Form |
|--------|---------------|------|
| O-LoRA | Orthogonality loss | sum ||A_i^T A_j||^2 |
| PSOFT | Strict orthogonality | Cayley transform R^T R = I |
| coSO | Hard projection | G' = G - M M^T G (no loss term) |

The closest frame-theoretic concept in coSO is the **Frequent Directions sketch** (Proposition 1), which bounds the approximation error of the gradient covariance matrix. This ensures the sketch S_{tau,T} S_{tau,T}^T approximates the true covariance sum_t G'_{tau,t} G'^T_{tau,t} with bounded spectral error.

---

## 12. Limitations and Failure Modes

### 12.1 From the Paper

1. **Limited to vision transformers**: All experiments use ViT-B/16; no LLM experiments
2. **Maximum 20 tasks tested**: Longer sequences not validated
3. **Historical basis growth**: M_tau grows with each task; no compression mechanism
4. **Two separate SVD operations per step**: One for projection (r1), one for FD sketching (r2)

### 12.2 Additional Limitations (Researcher Analysis)

1. **No code available**: Reproducibility concerns
2. **Fixed threshold epsilon_th = 0.98**: No adaptive thresholding based on task difficulty
3. **Gradient low-rank assumption**: If gradients are not low-rank, approximation quality degrades
4. **No handling of task similarity**: Orthogonal projection is agnostic to whether tasks are related
5. **SVD computation cost**: Every K steps requires SVD on m x n matrix; for large models this is expensive

---

## 13. Source Traceability Matrix

| Finding | Source | URL | Date | Confidence |
|---------|--------|-----|------|------------|
| coSO paper title, authors, venue | arXiv v2 | https://arxiv.org/abs/2505.11816 | May 2025 | HIGH |
| Mathematical formulation Eqs. 1-13 | arXiv PDF | https://arxiv.org/pdf/2505.11816 | Nov 2025 | HIGH |
| Benchmark tables | arXiv v2 | Tables 1, 2 in paper | Nov 2025 | HIGH |
| Memory/compute analysis | Appendix E | arXiv v2 Table 5 | Nov 2025 | HIGH |
| FD sketching bound | Proposition 1 | arXiv v2 Appendix A | Nov 2025 | HIGH |
| Hyperparameters | Appendix D | arXiv v2 | Nov 2025 | HIGH |
| No star-shaped domain in coSO | Full paper review | arXiv v2 | Nov 2025 | HIGH |
| No frame-theoretic regularization | Full paper review | arXiv v2 | Nov 2025 | HIGH |
| No trajectory optimization | Full paper review | arXiv v2 | Nov 2025 | HIGH |
| No code publicly available | GitHub search + arXiv | Multiple | 2025 | HIGH |
| OSFT code available | GitHub | https://github.com/Red-Hat-AI-Innovation-Team/mini_trainer | 2025 | HIGH |
| PSOFT Cayley parameterization | arXiv:2505.11235v3 | https://arxiv.org/html/2505.11235v3 | Feb 2026 | HIGH |
| GaLore inspiration | Section 3.2 | arXiv:2505.11816 | Nov 2025 | HIGH |
| LoDA independent verification | arXiv:2603.00191 | https://arxiv.org/html/2603.00191v1 | Feb 2026 | HIGH |
| O-LoRA orthogonality loss | EMNLP 2023 | https://aclanthology.org/2023.findings-emnlp.715.pdf | 2023 | HIGH |
| OSFT/Sculpting Subspaces details | ICLR 2026 OpenReview | https://openreview.net/forum?id=vQcyqsGJDw | Oct 2025 | HIGH |

---

## 14. Conclusions

### What coSO Actually Is

CoSO is a **gradient projection method** for continual learning with vision transformers that:
1. Projects gradients orthogonal to a maintained historical task subspace
2. Performs low-rank SVD on projected gradients for memory-efficient optimization (inspired by GaLore)
3. Uses Frequent Directions to incrementally consolidate task-specific gradient information
4. Updates the historical subspace basis after each task

### What coSO Is NOT

CoSO is NOT:
- A weight-space trajectory optimization method
- A method with star-shaped domain parameterization
- A method with frame-theoretic regularization
- A method that uses Cayley parameterization
- A method tested on LLMs (only vision transformers)
- A method tested beyond 20 tasks

### Research Assessment

The uploaded reference document contains **significant inaccuracies** about coSO's methodology. The actual coSO method is simpler, more practical, and empirically validated -- but lacks several of the theoretically elegant features described in the reference (trajectory optimization, frame theory, Cayley parameterization). These features appear to be conflated from other methods in the orthogonal continual learning literature (PSOFT for Cayley, O-LoRA for orthogonality regularization, and general functional analysis for frame theory).

### Key Open Questions

1. Can coSO scale to 100+ tasks with basis compression?
2. Does coSO work for LLMs (beyond vision transformers)?
3. Can coSO be combined with weight-space orthogonal methods?
4. Where is the public code implementation?

---

*Report compiled from 10+ independent web searches across arXiv, OpenReview, NeurIPS proceedings, GitHub, and independent research papers.*
