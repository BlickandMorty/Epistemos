# Compression-Governed Residency: The Residency Governor as Rate-Distortion Optimizer

## Research Dimension: Formalizing Memory Residency Through Information Theory

**Date:** Research Synthesis  
**Sources:** 12+ independent web searches across arXiv, IEEE, primary neuroscience literature, and information theory foundations.  
**Output File:** `/mnt/agents/output/research/recon_dim03_compression_governance.md`

---

## 1. Key Findings

### 1.1 The Rate-Distortion Function for a Learned Capability

The rate-distortion function for model compression was formally defined by **Gao et al. (2018)** [^1^] as:

$$R(D) = \min_{P_{\hat{W}|W} : \mathbb{E}[d(W, \hat{W})] \leq D} I(W; \hat{W})$$

where:
- $W \in \mathbb{R}^m$ is the multi-dimensional random variable representing model weights
- $P_W$ is the weight distribution (randomness from training data, initialization, and algorithm)
- $d(w, \hat{w})$ is the distortion between original and compressed model

For **regressors**, distortion is the expected $\ell_2$ distance:
$$d(w, \hat{w}) \equiv \mathbb{E}_X[\|f_w(X) - f_{\hat{w}}(X)\|_2^2]$$

For **classifiers**, distortion is the expected statistical distance (KL divergence, Hellinger, total variation):
$$d(w, \hat{w}) \equiv \mathbb{E}_X[D(f_{\hat{w}}(X) \| f_w(X))]$$

**Key insight for the Residency Governor:** This function quantifies the *fundamental limit* on how much a learned capability can be compressed before performance degrades beyond acceptable distortion. For a linear model with Gaussian weights $W \sim \mathcal{N}(0, \Sigma_W)$ and diagonal data covariance, the lower bound takes a **"weighted water-filling"** form [^1^]:

$$R(D) \geq \frac{1}{2}\log\det(\Sigma_W) - \sum_{i=1}^m \frac{1}{2}\log(D_i)$$

where $D_i$ are chosen such that $\sum_{i=1}^m \lambda_{x,i} D_i = D$ (weighted by data eigenvalues).

This provides a *computable* residency criterion: a capability should only be moved to a more compressed layer if the distortion at that layer remains below $D_{\text{threshold}}$.

### 1.2 DSC's Shared Basis Bank as Dictionary Learning / Compression Codebook

**Olshausen & Field (1996)** [^2^] showed that learning a sparse code for natural images yields basis functions (atoms) that resemble simple-cell receptive fields. Their objective:

$$E = -\sum_{x,y}\left[I(x,y) - \sum_i a_i \phi_i(x,y)\right]^2 - \lambda \sum_i S\left(\frac{a_i}{\sigma}\right)$$

The first term measures reconstruction fidelity (inverse distortion); the second penalizes non-sparse activations.

**Connection to DSC:** The shared basis bank in Dynamic Subspace Composition IS a dictionary learning system:
- **Dictionary = Basis Bank:** A set of shared atoms $\Phi = [\phi_1, \phi_2, ..., \phi_K]$ spanning the representational space
- **Sparse Codes = Subspace Activations:** Each capability is represented by a sparse vector of coefficients $a_i$ over the shared basis
- **Compression Codebook:** The basis bank serves as a shared codebook where each capability is encoded by its sparse index set rather than full parameters

This is structurally identical to k-means weight sharing in deep compression (Han et al., 2015) [^3^], where cluster centroids form a codebook and individual weights are replaced by indices. The rate (storage cost) becomes $\log_2(K)$ bits per weight instead of 32 bits.

**Formal mapping:**
| Dictionary Learning | DSC Shared Basis | Compression Interpretation |
|---|---|---|
| Atoms $\phi_i$ | Basis vectors $b_i$ | Codebook entries |
| Sparse coefficients $a_i$ | Activation pattern $\alpha$ | Codeword indices |
| Reconstruction error | Capability fidelity | Distortion $D$ |
| Sparsity penalty $\lambda$ | Capacity constraint | Rate $R$ |

### 1.3 The Information Bottleneck of the 7-Layer Memory Hierarchy

**Tishby & Zaslavsky (2015)** [^4^] formulated deep learning as an information bottleneck problem. The IB Lagrangian:

$$\mathcal{L}[p(\hat{x}|x)] = I(X; \hat{X}) - \beta I(\hat{X}; Y)$$

where:
- $I(X; \hat{X})$ = rate (complexity of representation)
- $I(\hat{X}; Y)$ = preserved relevant information
- $\beta$ = tradeoff parameter between compression and prediction

**The 7-layer hierarchy as a cascade of IB problems:**
Each layer $L_i$ in the SCOPE-Rex hierarchy (L0 Context → L7 Quarantine) can be characterized by a pair $(I(X; T_i), I(T_i; Y))$ on the **information plane** [^5^]:

| Layer | IB Characteristic | Biological Analog |
|---|---|---|
| L0 (Context) | High $I(X;T)$, High $I(T;Y)$ | Hippocampal rapid learning |
| L1-L3 (Working) | Decreasing $I(X;T)$, stable $I(T;Y)$ | MTL cortical consolidation |
| L4-L5 (Associative) | Low $I(X;T)$, high $I(T;Y)$ | Neocortical semantic |
| L6-L7 (Deep/Quarantine) | Minimal $I(X;T)$, compressed $I(T;Y)$ | Remote memory / schema |

The **data processing inequality** ensures $I(X; T_1) \geq I(X; T_2) \geq ... \geq I(X; T_7)$, forming a natural compression cascade. Each transition $L_i \to L_{i+1}$ corresponds to moving to a point further along the IB curve—accepting less rate for preserved relevance.

### 1.4 Erosion as KL Divergence: D(P_current || P_original)

Memory erosion—"overused edges lose precision"—can be formalized as **distributional drift** between the current and original claim distributions.

For a capability initially represented by distribution $P_{\text{original}}$ over some representational space (e.g., weight distribution, activation patterns, or claim posteriors), after $t$ uses the distribution becomes $P_{\text{current}}^{(t)}$. The erosion is:

$$\text{Erosion}_t = D_{KL}(P_{\text{current}}^{(t)} \| P_{\text{original}})$$

This measures the **information lost** (in nats) due to drift. When $\text{Erosion}_t > \epsilon_{\text{max}}$ (a threshold), the capability must either:
1. Be **refreshed** from a less-eroded copy (if available at a higher layer)
2. Be **marked for re-learning** (if distortion exceeds acceptable $D$)
3. Be **quarantined** (if safety-critical and erosion introduces catastrophic risk)

**Connection to catastrophic forgetting:** Kaushik et al. (2021) [^6^] formalize the "Optimal Overlap Hypothesis"—that forgetting is minimized by learning optimal representational overlap. Erosion is the complement: when overlap becomes suboptimal, KL divergence increases. The EWC (Elastic Weight Consolidation) approach [^7^] uses Fisher information to penalize changes to important weights, which is equivalent to constraining $D_{KL}$ divergence.

### 1.5 Optimal Compression Schedule: When to Move L0→L1→L2→...

The optimal compression schedule follows a **continuous-time Markov decision process** where the state is the current layer $L_i$ and the decision is whether to compress further or maintain.

**Decision variables:**
- $u(t)$ = usage frequency (how often capability is accessed)
- $D_{\text{tolerance}}$ = acceptable distortion for this capability
- $R_i$ = storage cost at layer $i$
- $\delta_i$ = access latency at layer $i$

**Optimal policy (inspired by curriculum learning + rate-distortion):**

$$\pi^*(L_i \to L_{i+1}) = \mathbb{1}\left[ u(t) < u_{\text{threshold}}(i) \land R(L_i) > R_{\text{target}}(D_{\text{tolerance}}) \right]$$

where $R_{\text{target}}(D)$ is the rate-distortion function. The threshold $u_{\text{threshold}}(i)$ decreases with $i$ (deeper layers accept lower usage).

** TRACE-CNN curriculum learning approach** [^8^] provides empirical validation: curriculum learning (progressive training from easy to hard) integrated with model compression "significantly mitigates the problem of accuracy loss." Applied to residency: capabilities should be compressed progressively, with verification that harder (more complex) variants still function correctly after each compression step.

### 1.6 Anchors as Compression Landmarks

The Resonance Model's "anchors" are **reference points that survive aggressive compression**—they are structurally equivalent to "compression landmarks" or "fiducial points" in manifold learning.

Formally, an anchor is a representation $T_{\text{anchor}}$ such that:
$$I(T_{\text{anchor}}; Y) \approx I(X; Y)$$
while $I(X; T_{\text{anchor}}) \ll I(X; X)$

In other words, anchors are **maximally compressed sufficient statistics** for the task-relevant information. They survive across layers because they capture the essential structure that remains invariant under the Markov cascade.

This is directly related to **Goldfeld et al. (2019)** [^9^] finding that "compression is driven by progressive geometric clustering of the representations of samples from the same class." Anchors are the cluster centroids that persist even as individual sample representations are compressed.

### 1.7 Kolmogorov Complexity for Residency Decisions

The Kolmogorov complexity $K(x)$ of an object is the length of the shortest program that generates it on a universal Turing machine [^10^]. For a schema/capability $S$:

$$K(S) = \min_{p: U(p) = S} |p|$$

**Decision criterion:** A capability with lower Kolmogorov complexity can reside at a deeper (more compressed) layer because it has more inherent structure—more "compressible" regularity.

**Practical approximation:** Since $K(S)$ is uncomputable, we use:
1. **Compression-based proxy:** $K(S) \approx |\text{gzip}(S)|$ or $|\text{zlib}(\text{serialize}(S))|$
2. **Neural description length:** $K(f_w) \approx \text{MDL}(w) = L(w) + L(D|w)$
3. **Structure function:** The capability's regularity profile over scale

Recent work by Romera-Paredes et al. [^11^] shows that Kolmogorov complexity can be applied to programs and grammars with strong generalization. The key insight: capabilities that are "more like programs" (algorithmic, compositional) have lower Kolmogorov complexity and can survive deeper compression.

### 1.8 Minimal Description Length of Each Residency Level

The MDL principle [^12^] states that the best model minimizes:
$$L_{\text{total}} = L(\text{model}) + L(\text{data} | \text{model})$$

**For each residency level:**

| Level | Description Length Component | Approximate Form |
|---|---|---|
| L0 (Context) | $L_0 = L(\text{full weights}) + L(\text{raw activations})$ | $\sum_i 32 \cdot |W_i| + \text{activation trace}$ |
| L1-L3 (Working) | $L_{1-3} = L(\text{sparse code}) + L(\text{residual})$ | $K \cdot \log_2 N + \|\text{residual}\|_0$ |
| L4-L5 (Assoc) | $L_{4-5} = L(\text{basis indices}) + L(\text{codebook})$ | $n \cdot \log_2 K + K \cdot d$ |
| L6 (Deep) | $L_6 = L(\text{schema}) + L(\text{exceptions})$ | $|p_{\text{schema}}| + \sum_j |e_j|$ |
| L7 (Quarantine) | $L_7 = L(\text{compressed}) + L(\text{audit log})$ | $R(D_{\text{max}}) + \text{trace bits}$ |

**Key insight from Grunwald (2019)** [^13^]: MDL is a "powerful extension of both penalized likelihood and Bayesian approaches, in which penalization functions and prior distributions are replaced by more general luckiness functions." The residency governor's decision rule becomes:

$$L^*(S) = \arg\min_{i \in \{0,...,7\}} \left[ L_i(S) + \lambda_i \cdot \text{Risk}_i(S) \right]$$

where $\text{Risk}_i(S)$ captures safety/reversibility concerns at level $i$.

---

## 2. Formal Definitions

### 2.1 Rate-Distortion for a Learned Capability

```
Definition: Capability Rate-Distortion Function

Let C be a learned capability represented by:
  - Weight distribution W_C ~ P_W over parameter space
  - Activation mapping f_W: X -> Y
  - Usage distribution U_C over input space

The rate-distortion function for C is:

  R_C(D) = min_{P_{\hat{W}|W}} I(W; \hat{W})
           subject to:
           E_{W,\hat{W}}[d(W, \hat{W})] <= D
           P_{\hat{W}|W} forms a valid Markov kernel

where the distortion d(W, \hat{W}) depends on capability type:
  - Classification: d = E_X[KL(f_\hat{W}(X) || f_W(X))]
  - Regression:     d = E_X[||f_\hat{W}(X) - f_W(X)||^2]
  - Generative:     d = E_X[JS(p_W || p_\hat{W})]
```

### 2.2 DSC Basis Bank as Codebook

```
Definition: Shared Basis Codebook

Let B = {b_1, b_2, ..., b_K} be the shared basis bank with b_i in R^d.
A capability C is encoded by:

  C = sum_{i in I_C} alpha_i * b_i + epsilon_C

where:
  - I_C subset of {1,...,K} is the support (sparse indices)
  - alpha in R^{|I_C|} are coefficients
  - epsilon_C is the reconstruction residual

The compressed description length is:
  L(C) = |I_C| * log_2(K)     // index coding
       + |I_C| * bits(alpha)   // coefficient precision
       + L(epsilon_C)          // residual (optional, for lossless)

Rate = L(C) / L(C_0) where L(C_0) is uncompressed length.
```

### 2.3 Information Bottleneck of the Hierarchy

```
Definition: Hierarchical Information Bottleneck

For the 7-layer hierarchy, define the Markov chain:
  X -> T_0 -> T_1 -> ... -> T_7 -> Y

where T_i is the representation at layer L_i.

Each transition satisfies the Data Processing Inequality:
  I(X; T_0) >= I(X; T_1) >= ... >= I(X; T_7)
  I(T_0; Y) <= I(T_1; Y) <= ... <= I(T_7; Y)  [initially]

The IB Lagrangian at layer i:
  L_i = I(X; T_i) - beta_i * I(T_i; Y)

Layer assignment rule:
  Assign capability C to layer i* where:
  i* = argmin_i [L_i(C) + gamma * Safety_i(C)]
  subject to: I(T_i; Y_C) >= I_min(C)
```

### 2.4 Erosion as KL Drift

```
Definition: Erosion-Distortion

Let P_C^{(0)} be the original claim distribution for capability C.
Let P_C^{(t)} be the distribution after t accesses/updates.

Erosion: E_C(t) = D_KL(P_C^{(t)} || P_C^{(0)})

Safety condition: E_C(t) < E_max(C) for continued residency at current level.

If E_C(t) >= E_max(C), trigger one of:
  1. Refresh: Reload P_C^{(0)} from higher-fidelity layer
  2. Reconsolidate: Compress to deeper layer with E_C(t) = 0 (new baseline)
  3. Quarantine: Isolate C for safety review if distortion affects output
```

### 2.5 Optimal Compression Schedule

```
Definition: Compression MDP

State: s = (L_i, u, E, D)  // current layer, usage, erosion, distortion
Action: a in {MAINTAIN, COMPRESS, EXPAND, QUARANTINE}
Reward: R(s,a) = -[StorageCost(a) + AccessCost(a) + Risk(s,a)]
Transition: P(s'|s,a) based on capability dynamics

Optimal policy: pi*(s) = argmax_a E[sum gamma^t R(s_t, a_t)]

Greedy compression rule:
  COMPRESS if:
    u(t) < u_threshold(i) AND
    D_current < D_tolerated(i+1) AND
    E(t) < E_max(i+1)
```

---

## 3. Tensions and Counter-Arguments

### 3.1 The Information Bottleneck Controversy

**Saxe et al. (2018)** [^14^] published a direct refutation of Tishby's claims, showing that:
1. The "compression phase" is **not universal**—it depends on activation function. Double-sided saturating nonlinearities (tanh) show compression; single-sided (ReLU) and linear do not.
2. There is **no causal connection** between compression and generalization: networks that do not compress still generalize well.
3. Compression does **not** arise from SGD stochasticity—full-batch gradient descent shows the same pattern.

**Goldfeld et al. (2019)** [^9^] further clarified that observed "compression" in binning-based MI estimates was actually tracking **geometric clustering** of same-class representations, not true information-theoretic compression.

**Implication for Residency Governor:** The IB framework is a useful *design principle* and *organizing metaphor* for the hierarchy, but we should not assume that each layer transition must achieve "true" information-theoretic compression. The clustering/geometric compression perspective is equally valid—what matters is that representations become more abstract and structured, whether measured by MI reduction or by increased geometric clustering.

### 3.2 Rate-Distortion Achievability vs. Tractability

Gao et al. prove achievability for linear models, but note: "Although this achievable compression scheme is intractable in practice, this analysis motivates a novel model compression framework" [^1^].

**Tension:** The theoretically optimal compression scheme (water-filling over eigenvalue-weighted dimensions) requires knowing the full weight distribution and data covariance—exactly what we don't have in a dynamic system. Practical residency decisions must use **greedy approximations** (pruning heuristics, quantization thresholds) rather than optimal RD solutions.

### 3.3 MDL vs. Practical Compressibility

Kolmogorov complexity is **uncomputable** [^10^]. Even approximations via standard compressors (gzip, bz2) are only coarse upper bounds. For neural networks, the gap between MDL theory and practical description length objectives remains a "conceptual gap" [^11^].

**Tension:** A residency governor based on Kolmogorov complexity would be non-computable. We must use proxy measures:
- Weight entropy $H(W)$ (approximates compressibility)
- Fisher information $F(W)$ (approximates sensitivity)
- Spectral norms of layer Jacobians

### 3.4 CLS Theory: Hippocampus ≠ Lossless

The Complementary Learning Systems theory [^15^] does not claim the hippocampus is "lossless." Rather:
- Hippocampus stores **pattern-separated** representations (distinct for each episode)
- Neocortex stores **overlapping** representations (shared structure across episodes)
- The hippocampus is fast-learning but **not infinite capacity**
- Consolidation is **interleaved replay**, not direct copy

**Tension:** Mapping L0 to "lossless" hippocampus and L6-L7 to "compressed" cortex oversimplifies. The hippocampus achieves rapid learning precisely BECAUSE it uses non-overlapping (high-rate) representations. The compression happens during replay-driven interleaved learning into cortex. The residency governor should model this as a **two-stage process**: rapid high-rate storage (L0) → interleaved consolidation → gradual rate reduction (L1-L7).

### 3.5 Catastrophic Forgetting as Information Loss

Forgetting is not simply "information loss"—it's **representation interference**. Kaushik et al. [^6^] show that over-generalization (learning a superset function) can cause "catastrophic remembering"—the opposite problem where a network becomes too familiar and loses discrimination.

**Tension:** The residency governor must balance:
- **Forgetting risk:** Too much compression → interference with existing knowledge
- **Remembering risk:** Too little compression → overfitting to specifics, losing generalization
- **Optimal overlap:** Representational overlap should be reduced for unrelated tasks, increased for similar tasks

---

## 4. Buildable Elements

### 4.1 Immediately Implementable

1. **Capability Rate-Distortion Tracker**
   - Monitor $D_{\text{current}} = \mathbb{E}[\|f_{\text{compressed}} - f_{\text{original}}\|^2]$ for each capability
   - Trigger compression when $D_{\text{current}} < D_{\text{threshold}}(L_{i+1})$

2. **Basis Bank Sparsity Monitor**
   - Track $L_0(C) = |I_C| \cdot \log_2 K$ for each capability
   - When $|I_C|$ drops below threshold, capability can move deeper

3. **Usage-Based Compression Scheduler**
   - Maintain moving average $u(t)$ for each capability
   - If $u(t) < u_{\text{threshold}}$ for $t > t_{\text{window}}$, schedule compression

4. **KL-Drift Erosion Detector**
   - Sample claim distribution periodically
   - Compute $D_{KL}(P_{\text{current}} || P_{\text{original}})$ using histogram approximation
   - Flag for refresh when $D_{KL} > \epsilon$

5. **Anchor Persistence Validator**
   - Identify anchors by high $I(T_{\text{anchor}}; Y)$ / low $I(X; T_{\text{anchor}})$ ratio
   - Verify anchors survive compression by checking consistency across layers

### 4.2 Medium-Term Implementable

1. **Hierarchical IB Optimizer**
   - Solve multi-layer IB Lagrangian numerically
   - Use variational approximation for mutual information estimation

2. **Fisher-Information Weighted Compression**
   - Compute diagonal Fisher $F_{ii}$ for each parameter
   - Compress low-Fisher parameters more aggressively (EWC-inspired)

3. **Replay-Based Consolidation Pipeline**
   - Implement CLS-style interleaved replay from L0 to deeper layers
   - Use generative replay or stored exemplars

---

## 5. Theoretical Foundations

### 5.1 Proven Results

| Result | Source | Status |
|---|---|---|
| Rate-distortion lower bound for linear models | Gao et al. (2018) [^1^] | **Proven** |
| RD achievability via weighted water-filling | Gao et al. (2018) [^1^] | **Proven** |
| Optimal compression for 1-hidden-layer ReLU | Gao et al. (2018) [^1^] | **Proven** |
| IB generalization bounds for DNNs | Tishby & Zaslavsky (2015) [^4^] | **Proven** |
| DPI chain in layered networks | Tishby (2015) [^4^] | **Proven** |
| SGD converges to Gibbs distribution | Tishby (2017) | **Proven** |
| MDL protects against overfitting | Grunwald (2019) [^13^] | **Proven** |
| CLS theory explains consolidation | McClelland et al. (1995) [^15^] | **Neuroscientifically validated** |

### 5.2 Conjectured / Disputed

| Claim | Source | Status |
|---|---|---|
| DNN training has universal "compression phase" | Tishby et al. | **Disputed** by Saxe et al. [^14^] |
| Compression causes generalization | Tishby et al. | **Disputed** — no causal link proven [^14^] |
| ReLU networks compress | Tishby et al. | **Disputed** — Saxe shows they do not [^14^] |
| Binning-based MI measures true compression | Shwartz-Ziv & Tishby | **Disputed** — measures clustering instead [^9^] |
| Kolmogorov complexity guides NN compression | Various | **Conjectured** — uncomputable in practice |
| 7-layer hierarchy is optimal for cognition | SCOPE-Rex | **Conjectured** — no proof of optimality |

---

## 6. References

1. **Gao, W., Liu, Y.-H., Wang, C., & Oh, S.** (2018). *Rate Distortion For Model Compression: From Theory To Practice*. arXiv:1810.06401. https://arxiv.org/abs/1810.06401

2. **Olshausen, B. A., & Field, D. J.** (1996). Emergence of simple-cell receptive field properties by learning a sparse code for natural images. *Nature*, 381(6583), 607-609. https://www.cs.cmu.edu/~efros/courses/LBMV07/Papers/olshausen-nature-96.pdf

3. **Han, S., Mao, H., & Dally, W.** (2015). Deep compression: Compressing deep neural networks with pruning, trained quantization and Huffman coding. *ICLR*. (Referenced in [^3^])

4. **Tishby, N., & Zaslavsky, N.** (2015). *Deep Learning and the Information Bottleneck Principle*. arXiv:1503.02406. https://arxiv.org/abs/1503.02406

5. **Shwartz-Ziv, R., & Tishby, N.** (2017). Opening the Black Box of Deep Neural Networks via Information Theory. arXiv:1703.00810. (Referenced in [^5^])

6. **Kaushik, P., et al.** (2021). *Understanding Catastrophic Forgetting and Remembering in Continual Learning*. Johns Hopkins University. https://www.cs.jhu.edu/~alanlab/Pubs21/kaushik2021understanding.pdf

7. **Kirkpatrick, J., et al.** (2017). Overcoming catastrophic forgetting in neural networks. *PNAS*, 114(13), 3521-3526. (Referenced in [^7^])

8. **TRACE-CNN authors** (2024). *Enhancing accuracy of compressed CNNs through transfer teacher and reinforcement guided training curriculum*. Knowledge-Based Systems. https://www.sciencedirect.com/science/article/abs/pii/S0950705124013534

9. **Goldfeld, Z., et al.** (2019). *Estimating Information Flow in Deep Neural Networks*. ICML 2019. http://proceedings.mlr.press/v97/goldfeld19a/goldfeld19a.pdf

10. **Li, M., & Vitanyi, P.** (2008). *An Introduction to Kolmogorov Complexity and Its Applications* (3rd ed.). Springer. (Referenced in [^10^])

11. **Romera-Paredes, B., et al.** (2024). Bridging Kolmogorov Complexity and Deep Learning. arXiv:2509.22445. https://arxiv.org/pdf/2509.22445

12. **Rissanen, J.** (1978; 1989; 2007). *MDL Principle*. Multiple works. (Referenced in [^12^])

13. **Grunwald, P.** (2019). *Minimum Description Length Revisited*. arXiv:1908.08484. https://arxiv.org/abs/1908.08484

14. **Saxe, A. M., et al.** (2018). *On the Information Bottleneck Theory of Deep Learning*. ICLR 2018. https://openreview.net/forum?id=ry_WPG-A-

15. **McClelland, J. L., McNaughton, B. L., & O'Reilly, R. C.** (1995). Why there are complementary learning systems in the hippocampus and neocortex. *Psychological Review*, 102(3), 419-457. https://pubmed.ncbi.nlm.nih.gov/7624455/

16. **Roos, T.** (2019). Minimum Description Length Revisited. arXiv:1908.08484. https://arxiv.org/abs/1908.08484

17. **Brady, T. F., et al.** (2009). Using statistical regularities to form more efficient memory representations. *Journal of Experimental Psychology*. https://konklab.fas.harvard.edu/Papers/Brady_2009_JEPG.pdf

18. **Agustsson, E., & Theis, L.** (2020). *Universally Quantized Neural Compression*. NeurIPS 2020. https://proceedings.neurips.cc/paper_files/paper/2020/file/92049debbe566ca5782a3045cf300a3c-Paper.pdf

19. **Shi, Y., et al.** (2023). *Lossy and Lossless (L2) Post-training Model Size Compression*. ICCV 2023. https://openaccess.thecvf.com/content/ICCV2023/papers/Shi_Lossy_and_Lossless_L2_Post-training_Model_Size_Compression_ICCV_2023_paper.pdf

20. **Choi, Y., et al.** (2018). *Universal Deep Neural Network Compression*. arXiv:1802.02271. https://arxiv.org/abs/1802.02271

21. **McClelland, J. L.** (2013). Incorporating rapid neocortical learning into complementary learning systems theory. *J. Exp. Psychol. Gen.*, 142(4), 1190-1210. https://pubmed.ncbi.nlm.nih.gov/23978185/

22. **Schapiro, A. C., et al.** (2017). Complementary learning systems within the hippocampus. *Phil. Trans. R. Soc. B*, 372(1711). https://royalsocietypublishing.org/rstb/article/375/1799/20190637/23829/

---

## 7. Synthesis: The Residency Governor as Rate-Distortion Optimizer

### 7.1 Unified Formalization

The Residency Governor can be unified as a **multi-objective rate-distortion optimizer**:

$$\min_{\pi} \sum_{C \in \text{Capabilities}} \left[ R_{\pi(C)}(D_C) + \lambda_1 \cdot \text{Latency}_{\pi(C)} + \lambda_2 \cdot \text{Risk}_{\pi(C)} + \lambda_3 \cdot E_C(t) \right]$$

where:
- $\pi(C)$ is the residency assignment for capability $C$
- $R_{\pi(C)}(D_C)$ is the rate-distortion cost at the assigned layer
- $\text{Latency}_{\pi(C)}$ is the access cost
- $\text{Risk}_{\pi(C)}$ is the safety/reversibility penalty
- $E_C(t)$ is the erosion (KL-drift) penalty

### 7.2 The Compression Cascade as Markov Chain

The 7-layer hierarchy forms a **Markov cascade of sufficient statistics**:

$$X \xrightarrow{\text{L0}} T_0 \xrightarrow{\text{L1}} T_1 \xrightarrow{\text{L2}} T_2 \xrightarrow{\text{L3}} T_3 \xrightarrow{\text{L4}} T_4 \xrightarrow{\text{L5}} T_5 \xrightarrow{\text{L6}} T_6 \xrightarrow{\text{L7}} T_7 \to Y$$

Each arrow is a lossy channel. The Data Processing Inequality guarantees:
- $I(X; T_0) \geq I(X; T_1) \geq ... \geq I(X; T_7)$ (monotonic compression)
- The relevant information $I(T_i; Y)$ is preserved as long as $I(T_i; Y) \geq I_{\min}$

### 7.3 DSC as Dictionary Coding

The DSC shared basis bank is a **learned codebook**:
- **Encoder:** Sparse coding finds indices $I_C$ and coefficients $\alpha$
- **Decoder:** Reconstruct capability as $\sum_i \alpha_i b_i$
- **Rate:** $\log_2(K)$ bits per active basis element
- **Distortion:** Reconstruction error $\|\epsilon_C\|^2$

This is the neural analog of JPEG's DCT codebook or MP3's MDCT codebook—learned rather than designed.

### 7.4 Operational Decision Framework

```
FOR each capability C:
  COMPUTE:
    D_current = distortion at current layer
    R_current = description length at current layer
    u_C = moving average usage frequency
    E_C = KL-drift from original
    K_C = proxy Kolmogorov complexity

  DECIDE:
    IF E_C > E_max AND u_C > u_critical:
      -> REFRESH from higher fidelity layer
    ELSE IF u_C < u_threshold(i) AND D_current < D_threshold(i+1):
      -> COMPRESS to layer i+1
    ELSE IF Risk(C) > Risk_threshold AND Reversibility(C) = LOW:
      -> QUARANTINE to L7
    ELSE:
      -> MAINTAIN at current layer

  AFTER TRANSITION:
    VERIFY: I(T_new; Y_C) >= I_min(C)
    UPDATE: P_original = P_current (new baseline for erosion)
```

### 7.5 Open Questions

1. **How to estimate mutual information in continuous representations?** Binning-based estimates are artifact-prone [^14^]; kernel density methods are expensive. Variational bounds (Donsker-Varadhan) may be the practical solution.

2. **What is the optimal number of layers?** The 7-layer hierarchy is inspired by biological memory systems, but there is no proof of optimality. Information-theoretic analysis suggests the number should relate to the "bifurcation points" of the IB curve [^4^].

3. **How to handle task-relevant vs. task-irrelevant compression?** Saxe et al. show that networks compress task-irrelevant information while boosting task-relevant information [^14^]. The residency governor needs similar discrimination: not all information in a capability is equally important.

4. **Can we prove the residency governor converges?** A MDP formulation allows convergence analysis, but the state space is enormous. Mean-field or approximate analysis may yield guarantees.

5. **What is the role of ternary tensors?** The original mission mentions "ternary tensors." This suggests a three-valued logic (positive / negative / absent) for basis activations. Ternary quantization (2 bits vs. 32 bits) achieves ~16x compression and may be the natural substrate for a compressed residency system.

---

*End of Research Synthesis*
