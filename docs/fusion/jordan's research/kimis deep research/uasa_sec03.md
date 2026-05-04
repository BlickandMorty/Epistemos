# 3. Geometry of Thought: Manifold Constraints and Attention

The transformer architecture, for all its empirical success, rests on a fragile numerical foundation. Deep stacks of self-attention layers interleaved with feed-forward networks are prone to rank collapse, exponential signal amplification, and gradient instability—pathologies that worsen predictably with depth and scale. The research community has responded with two conceptually distinct but mathematically related approaches: constraining the *geometry* of computation (projecting weight matrices onto well-behaved manifolds) and compressing the *state* of computation (reducing the dimensionality of key-value representations without loss of expressive power). This chapter examines both, with emphasis on which techniques are production-ready for deterministic substrates and which remain theoretical.

## 3.1 The Birkhoff Polytope as Attention Stabilizer

### 3.1.1 The Birkhoff-von Neumann Theorem and Its Relevance to Residual Networks

A doubly-stochastic matrix is a square matrix with non-negative entries whose rows and columns each sum to one. The Birkhoff-von Neumann theorem states that the set of all $n \times n$ doubly-stochastic matrices—the *Birkhoff polytope* $\mathcal{B}_n$—is the convex hull of the $n!$ permutation matrices. Every doubly-stochastic matrix can therefore be written as a weighted average of permutation matrices, each of which merely rearranges vector components without mixing them. This convex structure is not merely elegant; it is operationally useful because $\mathcal{B}_n$ is closed under matrix multiplication: the product of doubly-stochastic matrices remains doubly-stochastic, and therefore the spectral norm of any such product is bounded above by unity [^7^].

The closure property is the critical guarantee. In a deep residual network, the composite mapping across $L$ layers is the product of individual layer mappings. If each layer's residual mixing matrix $H_l^{\text{res}}$ lies on $\mathcal{B}_n$, the product $\prod_{l=1}^{L} H_l^{\text{res}}$ also lies on $\mathcal{B}_n$, regardless of depth. The signal amplification through the residual stream is therefore bounded *by construction*, independent of layer count. This stands in sharp contrast to unconstrained residual networks, where successive matrix multiplication can amplify (or attenuate) signals exponentially.

The standard approach to obtaining doubly-stochastic matrices is the Sinkhorn-Knopp algorithm. Given any positive matrix $K^0 \in \mathbb{R}^{n \times n}$, the algorithm alternates row-wise and column-wise normalization:

$$K^{l+1} = \mathcal{N}_R(K^l) \text{ if } l \text{ is even}, \quad K^{l+1} = \mathcal{N}_C(K^l) \text{ if } l \text{ is odd}$$

where $\mathcal{N}_R$ and $\mathcal{N}_C$ denote row and column normalization operators. The iteration converges to a doubly-stochastic matrix $K^\infty = \text{Sinkhorn}(C)$ [^5^]. In practice, a finite number of iterations (typically 20) yields approximate doubly-stochasticity sufficient for neural network training. The Sinkhorn operator is differentiable, making it compatible with gradient-based optimization via automatic differentiation through the normalization steps.

At low temperature, Sinkhorn-projected matrices exhibit a quantization behavior that is analytically tractable. As $\tau \rightarrow 0$, the projection $\mathbf{P}(\tau)$ converges to a permutation matrix $\mathbf{P}^*$ with rate controlled by the spectral gap:

$$\|\mathbf{P}(\tau) - \mathbf{P}^*\|_F = O(e^{-\Delta^*/\tau})$$

where $\Delta^*$ is the gap between optimal and second-best assignment costs [^6^]. This property becomes relevant when Sinkhorn is applied to routing matrices in Mixture-of-Experts architectures, where the limiting permutation matrix corresponds to a hard assignment of tokens to experts.

### 3.1.2 DeepSeek mHC: From 3000× Amplification to Bounded Gain

DeepSeek's Manifold-Constrained Hyper-Connections (mHC) provide the first large-scale empirical validation of Birkhoff polytope projection as a training stabilizer [^1^]. The unconstrained Hyper-Connection (HC) architecture expands the residual stream from $C$-dimensional to $n \times C$-dimensional, where $n$ is a small integer (typically 4), and learns mixing matrices $H_l^{\text{res}}$, $H_l^{\text{pre}}$, $H_l^{\text{post}}$ that route information between parallel residual streams. Without constraints, the composite mapping across layers—$\prod_{i=1}^{L-l} H_{L-i}^{\text{res}}$—exhibits catastrophic amplification.

In a 27B-parameter model with unconstrained HC, the composite mapping gain magnitude peaks at approximately 3000×, causing numerical divergence during training [^1^]. The mHC modification projects $H_l^{\text{res}}$ onto the Birkhoff polytope via Sinkhorn-Knopp (20 iterations, $t_{\max} = 20$), while $H_l^{\text{pre}}$ and $H_l^{\text{post}}$ are constrained to non-negative values via sigmoid activation. The resulting maximum gain magnitude is bounded to approximately 1.6×—a reduction of three orders of magnitude.

The mHC layer update is:

$$x_{l+1} = H_l^{\text{res}} x_l + H_l^{\text{post},T} \, \mathcal{F}(H_l^{\text{pre}} x_l, W_l)$$

with constraints:
$$H_l^{\text{pre}} = \sigma(\tilde{H}_l^{\text{pre}}), \quad H_l^{\text{post}} = 2\sigma(\tilde{H}_l^{\text{post}}), \quad H_l^{\text{res}} = \text{Sinkhorn-Knopp}(\tilde{H}_l^{\text{res}})$$

Here $\mathcal{F}$ denotes the feed-forward or attention sublayer, $\sigma$ is the sigmoid function ensuring non-negativity, and the Sinkhorn-Knopp operator enforces doubly-stochasticity on the residual mixing matrix. The non-negativity constraints on pre- and post-mappings prevent signal cancellation from mixed positive-negative coefficients, a pathology observed in early HC experiments.

Empirically, mHC achieves +2.1% on Big-Bench Hard (BBH) and +2.3% on DROP versus the unconstrained HC baseline at 27B scale, with the performance gap widening as model size increases [^1^]. The single-layer mapping gain in mHC deviates slightly from the ideal 1.0 due to finite Sinkhorn iterations, and the composite backward gradient gain reaches a maximum of approximately 1.6—still far below the ~3000 observed in unconstrained HC.

### 3.1.3 Engineering the 6.7% Overhead

The raw Sinkhorn-Knopp projection adds substantial memory and compute overhead. Without optimization, the HC design incurs approximately $n$-fold memory access overhead, with I/O costs scaling as $(5n+1)C + n^2 + 2n$ reads and $(3n+1)C + n^2 + 2n$ writes per token [^1^]. DeepSeek mitigates this through three engineering strategies that together reduce the marginal training overhead to 6.7%.

| Optimization | Mechanism | Latency Impact | Source |
|:---|:---|:---|:---|
| Kernel fusion (TileLang) | Fuses RMSNorm, matrix multiplications, sigmoid, and Sinkhorn iterations into unified compute kernels; reduces reads from $(3n+1)C$ to $(n+1)C$ and writes from $3nC$ to $nC$ | 40% latency reduction on post/residual merge kernel | Xie et al. [^1^] |
| FP8 mixed precision | Core GEMMs in E4M3 FP8; coefficients in float32; activations in bfloat16; tile-wise $1\times128$ quantization for activations | Full FP32 accumulation via CUDA Core promotion every 128 elements | DeepSeek-V3 [^4^] |
| DualPipe communication overlap | Bidirectional pipeline scheduling overlaps forward/backward computation with all-to-all communication; mHC kernels execute on dedicated high-priority stream | 50% hidden latency for pipeline bubbles | DeepSeek-V3 [^4^] |

The kernel fusion strategy is the dominant contributor. By fusing the application of $H_l^{\text{post}}$ and $H_l^{\text{res}}$ with residual merging into a single kernel, the number of elements read is reduced from $(3n+1)C$ to $(n+1)C$, and elements written from $3nC$ to $nC$ [^1^]. This is a memory-wall optimization: the Sinkhorn iterations themselves are compute-light (alternating row/column normalizations on small $n \times n$ matrices) but would trigger multiple round-trips through memory if implemented as separate operations.

The FP8 strategy adopts E4M3 format (4-bit exponent, 3-bit mantissa) across all tensors, with fine-grained tile-wise and block-wise quantization to manage activation outliers. Relative loss error versus BF16 baseline remains below 0.25% [^4^]. For deterministic substrates, fixed iteration counts ($t_{\max} = 20$) and quantized arithmetic with defined rounding modes are essential: convergence-based stopping criteria would introduce run-to-run variance, and floating-point non-associativity across different execution orders must be controlled.

DualPipe extends the overlap principle to pipeline parallelism by feeding micro-batches from both ends of the pipeline simultaneously. For mHC specifically, the post/residual kernels for MLP layers execute on a dedicated high-priority compute stream to prevent blocking the main training pipeline [^1^]. Activation recomputation decouples memory management from pipeline communication: the initial activation of each stage is cached locally, and intermediate activations are recomputed during backward passes rather than stored.

## 3.2 Manifold-Constrained Attention in Practice

### 3.2.1 Sinkhorn on Pre-Trained Models: What Works and What Does Not

A natural question is whether Sinkhorn projection can be applied to pre-trained models without retraining. The answer is bifurcated: it works for attention normalization, but not for mHC-style residual stream constraints.

For attention matrices, empirical evidence supports retrofitting. Sander et al. demonstrated that in trained standard Transformers, attention matrices naturally approach doubly-stochasticity: column sums converge to approximately 1 as training progresses across ViT, fairseq Transformer, and Point Cloud Transformer architectures [^5^]. This implies that trained models have already discovered attention patterns close to the Birkhoff polytope; applying Sinkhorn post-hoc therefore does not drastically alter the attention distribution. Direct replacement of Softmax with Sinkhorn at inference has been validated in the Sinkformer architecture, which preserves or slightly improves rank properties [^5^].

However, for mHC-style residual mappings, post-hoc projection is not viable. The manifold constraint shapes the optimization landscape during training; weights learn to exploit the constrained geometry. Projecting an unconstrained $H^{\text{res}}$ onto $\mathcal{B}_n$ after training would move the matrix to a nearby but functionally different point in weight space, degrading performance without retraining. The mHC paper validates this implicitly: the performance gains (+2.1% BBH, +2.3% DROP) are achieved only when Sinkhorn is applied during training [^1^]. This distinction is significant for deterministic substrates that may incorporate pre-trained foundation models: manifold constraints on residual streams require architectural integration during training, whereas attention normalization can be applied as a deterministic post-processing step at inference time.

The rank-preservation benefit of Sinkhorn over Softmax also has a subtle precondition. Lapenna et al. proved that the advantage disappears for products of *randomly generated* stochastic matrices; it emerges only when attention matrices across layers are correlated with one another, as they are in trained Transformers [^2^]. This means the benefit is not a generic property of doubly-stochastic matrices but a learned structural property of trained attention patterns. Retrofitting Sinkhorn to a pre-trained model should preserve this correlation structure and therefore maintain the rank-preservation benefit.

### 3.2.2 ManifoldFormer: Geodesic-Aware Attention on Riemannian Manifolds

While mHC constrains the *weights* to a manifold, ManifoldFormer constrains the *representations* to a manifold. It introduces a geometric Transformer that operates directly on Riemannian manifolds, computing attention weights using geodesic distances rather than Euclidean inner products [^3^]. The attention score incorporates a geometric penalty term:

$$\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{QK^T}{\sqrt{d_k}} - \lambda \, D_{\text{geo}}\right) V$$

where $D_{\text{geo}}$ represents geodesic distances on the manifold $\mathcal{M}$, and $\lambda$ is a learnable coefficient controlling the geometric penalty strength. The architecture combines geodesic-aware attention with neural ODE dynamics for temporal evolution, evaluated on EEG classification tasks where the data naturally lives on the manifold of symmetric positive-definite (SPD) matrices.

The empirical gains are additive: Riemannian VAE provides the largest individual improvement (+4.6% accuracy), the geometric Transformer adds +4.2%, and neural ODE dynamics contribute +3.5%, with combined effects exceeding the sum of individual contributions [^3^]. Cohen's Kappa improvements of 6.2–10.2% indicate that the geometric constraints improve not just raw accuracy but inter-rater agreement, suggesting more consistent and interpretable predictions.

For deterministic substrates, the ManifoldFormer approach is viable when the input data has known manifold structure (EEG signals, graph embeddings, physical states). For generic text, however, the latent representation manifold is unknown and must be estimated, adding both computational cost and estimation variance. The Equivariant Geodesic Network (EGN) extends this framework with fully end-to-end SPD-preserving architectures combining equivariant bilinear transforms, manifold-aware activations, and geodesic attention with affine-invariant Riemannian metrics [^9^]. RiemannInfer provides a complementary perspective, reformulating Transformer inference as navigation on Riemannian manifolds constructed from attention distribution features, with reasoning path planning minimizing inference work by measuring geodesics and curvature [^8^].

A separate but related direction is hyperbolic attention, which reformulates attention scores using hyperbolic distance $d_H$ rather than Euclidean distance: $\alpha_{ij} = \text{softmax}(-\beta \cdot d_H(q_i, k_j)^2)$. Points near the center of the Poincaré ball capture high-level hierarchical information, while points near the boundary encode fine-grained details, enabling natural multi-resolution processing [^24^]. Hyperbolic transformers operate approximately 1.3× slower than Euclidean counterparts and exhibit numerical instabilities during repeated transformations, limiting their practical deployment despite theoretical appeal for hierarchical text [^25^].

### 3.2.3 BRL-Attention: Linear Complexity via Low-Rank Bottleneck Regularization

Bottleneck Regularized Linear Attention (BRL-Attention) addresses a different pathology: the geometric bottleneck of linear attention mechanisms. Standard linear attention approximates Softmax attention via kernel feature maps, achieving $O(n)$ complexity in sequence length but suffering from limited expressiveness and over-squashing in deep networks. BRL-Attention unites pattern-based and kernel-based techniques, extending local attention with compressed global tokens to achieve linear complexity while matching full Softmax attention expressiveness [^17^].

The key insight is that low-rank bottleneck regularization on the attention feature maps mitigates the geometric bottleneck—an information-theoretic limit on how much global context can flow through linear attention—while preserving the computational advantages. This is conceptually aligned with both the manifold constraint philosophy (restricting the solution space to well-conditioned subspaces) and the MLA approach (compressing KV representations via low-rank projection). BRL-Attention is applicable to both encoder-only and autoregressive decoder architectures, with open-source implementations available [^17^].

## 3.3 Multi-Head Latent Attention (MLA)

### 3.3.1 Low-Rank KV Compression and the Decoupled RoPE Strategy

Multi-Head Latent Attention (MLA), introduced in DeepSeek-V2, attacks the inference memory bottleneck from a different geometric angle: instead of constraining the mixing matrices, it compresses the key-value cache via low-rank projection. The KV cache in standard Multi-Head Attention (MHA) stores separate key and value vectors for each head, with memory scaling as $O(2 \cdot d_h \cdot n_h \cdot L)$ for hidden dimension $d_h$, head count $n_h$, and context length $L$. MLA compresses keys and values into a shared latent vector $c_t^{\text{KV}}$ via down-projection, reducing the KV cache to $O((d_c + d_h^R) \cdot L)$ [^1^].

For DeepSeek-V2, the compression dimension $d_c$ is set to $4d_h$ and the RoPE (Rotary Position Embedding) dimension $d_h^R$ to $d_h/2$. Under this configuration, the KV cache per token is equivalent to Grouped-Query Attention (GQA) with only 2.25 groups, yet performance exceeds MHA [^1^]. The 90%+ compression rate is achieved without sacrificing the model's ability to attend to distant context, enabling 128K+ context windows on memory-constrained hardware.

The decoupled RoPE strategy is critical to this efficiency. Standard RoPE intertwines positional information with semantic content, preventing the weight absorption trick that eliminates per-token up-projection overhead during decoding. MLA separates positional information into a small vector $k_t^R$ that is cached separately, while the bulk of key/value information lives in the compressed latent $c_t^{\text{KV}}$. The weight absorption trick then pre-computes composite matrices $(W^{\text{UQ}^T} W^{\text{UK}})$ and absorbs $W^{\text{UV}}$ into $W^O$, so the decode phase avoids per-token up-projections entirely [^2^].

### 3.3.2 TransMLA: Retrofitting Pre-Trained Models

TransMLA demonstrates that the MLA architecture can be retrofitted to existing GQA-based models (LLaMA, Qwen, Gemma, Mixtral) with only 6 billion tokens of fine-tuning to recover comparable performance [^3^]. The conversion addresses RoPE incompatibility through two techniques: RoRoPE (PCA-based RoPE concentration) and FreqFold, which adapt existing position encodings to the decoupled format. Training-free conversion achieves 68.75% KV cache compression with only 1.65% performance degradation; the 93% compression version requires 6B tokens to fully recover [^3^].

The theoretical justification for migration is compelling: TransMLA proves that MLA consistently offers higher expressive power than GQA under the same KV cache overhead [^3^]. This means that for a fixed memory budget, MLA can represent a strictly larger class of attention functions than GQA. In practice, this translates to better long-context retrieval and more nuanced attention patterns.

| Mechanism | Compression Ratio | Speedup (8K context) | Retraining Required | Applicable Models |
|:---|:---|:---|:---|:---|
| MLA (native) | 90%+ | Baseline | From scratch | DeepSeek-V2/V3 |
| TransMLA (training-free) | 68.75% | 3–5× | None | LLaMA, Qwen, Gemma, Mixtral |
| TransMLA (fine-tuned) | 93% | 10.6× | 6B tokens | LLaMA, Qwen, Gemma, Mixtral |
| mHC + MLA combined | >90% KV + stable residual | Not measured | From scratch | Theoretical |

The practical implication is that local deterministic substrates can adopt MLA without abandoning the existing ecosystem of open-weight models. A 7B-parameter model converted via TransMLA achieves 10.6× speedup at 8K context length while maintaining meaningful output, and the compressed format is compatible with standard inference engines (vLLM, SGLang) [^3^]. This compatibility is essential for deterministic runtimes that depend on reproducible kernel behavior.

### 3.3.3 The Efficient Local Inference Stack: MLA + MoE + GRPO

When MLA is combined with Mixture-of-Experts (MoE) and Group Relative Policy Optimization (GRPO), the result is an inference stack optimized for both throughput and training efficiency on resource-constrained hardware. MLA reduces the KV cache memory footprint by 90%+, MoE activates only a subset of parameters per token (typically 8–32 experts out of 256), and GRPO eliminates the critic model required by PPO, reducing memory consumption by approximately 25% [^7^].

The GRPO objective samples $G$ outputs per question and optimizes using clipped policy ratios with group-relative advantages. The advantage for each sample is computed by normalizing rewards within the group—subtracting the group mean and dividing by the group standard deviation—rather than estimating a value function [^7^]. DeepSeek-R1-Zero used GRPO with purely rule-based rewards (accuracy + format) without any neural reward model, achieving AIME 2024 pass@1 improvement from 15.6% to 77.9% [^9^]. The rule-based approach is particularly suitable for deterministic substrates because reward functions are verifiable, reproducible, and free from the reward hacking that plagues learned reward models [^10^].

For local deployment on Apple Silicon with 128GB Unified Memory Architecture (UMA), a 7B model with MLA compression and INT8 quantization for inference requires approximately 7–14GB for model weights and 1–2GB for the compressed KV cache at 128K context. The policy and reference models for GRPO training (14B parameters total in 4-bit) fit within the remaining memory. The primary bottleneck is generation throughput for creating rollouts, not memory capacity [^29^].

The stack creates a virtuous cycle: MLA enables longer context for training data, GRPO efficiently distills reasoning patterns from that data without a critic model, and MoE provides parameter capacity without proportional activation cost. For deterministic substrates, the fixed iteration count of Sinkhorn in mHC (20 steps), the deterministic routing of MoE (top-$k$ expert selection), and the reproducible reward computation of GRPO (rule-based, no stochastic critic) all contribute to byte-identical training trajectories when seeded appropriately.

---

The manifold constraint framework and the compression framework are not mutually exclusive; they address different pathologies in the transformer stack. mHC stabilizes the *depth* dimension by bounding signal amplification through constrained residual mappings. MLA compresses the *width* dimension by reducing KV cache state. BRL-Attention and ManifoldFormer explore alternative geometric priors for specialized data types. For production deterministic substrates, the priority should be: (1) MLA for immediate KV cache reduction on existing models via TransMLA, (2) mHC for new training runs where the 6.7% overhead is acceptable in exchange for depth-independent stability guarantees, and (3) condition number monitoring of Q, K, V matrices as a runtime diagnostic for attention health [^4^].
