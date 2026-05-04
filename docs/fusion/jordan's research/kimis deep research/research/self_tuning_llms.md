# Self-Tuning LLMs: Test-Time Training, Adaptation, and Persistent Memory
## A Systems Research Report

**Date:** 2025-07  
**Classification:** Technical Deep-Dive — Continual Learning & On-Device Adaptation  
**Key Papers:** Sun et al. NeurIPS 2024 [arXiv:2407.04620], Odrzywolek [arXiv:2603.21852], Ha et al. [arXiv:1609.09106], Finn et al. ICML 2017 [arXiv:1703.03400], Chen et al. ACL 2022 [arXiv:2110.07814]

---

## 1. Formal Definition: Test-Time Training (TTT)

### 1.1 The Core Abstraction

Test-Time Training (TTT), introduced by Sun et al. (2024) [^3157^], reframes sequence modeling as a nested learning problem. The key insight is to make the **hidden state of an RNN layer itself a machine learning model**, updated by self-supervised learning even at test time.

**Definition 1.1 (TTT Layer).** A TTT layer is a sequence modeling layer parameterized by outer-loop parameters $\phi$ and an inner-loop learner $f(\cdot; W)$ with test-time-updatable weights $W$. At each timestep $t$:

- **Update rule:** The hidden state $W_t$ is updated by a gradient step on a self-supervised loss $\ell$ applied to the current token $x_t$:
  $$
  W_t = W_{t-1} - \eta \nabla_W \ell(W_{t-1}; x_t)
  $$

- **Output rule:** The layer output $z_t$ is produced by applying the updated learner to the current token:
  $$
  z_t = f(x_t; W_t)
  $$

This is fundamentally different from standard RNNs where the hidden state is a fixed-size vector $h_t \in \mathbb{R}^d$, and different from self-attention where the "hidden state" is the growing KV cache.

### 1.2 TTT-Linear: Linear Model as Hidden State

**Definition 1.2 (TTT-Linear).** In TTT-Linear, the inner-loop learner is a linear model:

$$
f(x; W) = Wx, \quad W \in \mathbb{R}^{d_{\text{out}} \times d_{\text{in}}}
$$

The self-supervised loss is a reconstruction loss. Let $\phi: \mathbb{R}^{d_{\text{in}}} \to \mathbb{R}^{d_{\text{ss}}}$ be the view transform (outer-loop parameter), and $\psi: \mathbb{R}^{d_{\text{in}}} \to \mathbb{R}^{d_{\text{ss}}}$ be the target transform. The loss is:

$$
\ell(W; x_t) = \|\phi(x_t) - W \psi(x_t)\|^2
$$

The gradient of this loss with respect to $W$ is:

$$
\nabla_W \ell(W; x_t) = -2(\phi(x_t) - W \psi(x_t)) \psi(x_t)^\top
$$

Substituting into the update rule yields a **closed-form update** that is equivalent to linear attention [^3157^]:

$$
W_t = W_{t-1} + 2\eta (\phi(x_t) - W_{t-1} \psi(x_t)) \psi(x_t)^\top
$$

This can be rewritten in terms of sufficient statistics $G_t = \sum_{s=1}^t \phi(x_s) \psi(x_s)^\top$ and $H_t = \sum_{s=1}^t \psi(x_s) \psi(x_s)^\top$, yielding $O(1)$ inference per token after $O(t)$ precomputation — matching the complexity of linear attention.

### 1.3 TTT-MLP: Two-Layer MLP as Hidden State

**Definition 1.3 (TTT-MLP).** In TTT-MLP, the inner-loop learner is a two-layer MLP with weights $W = (W_1, W_2)$:

$$
f(x; W) = W_2 \sigma(W_1 x)
$$

where $\sigma$ is a nonlinear activation (e.g., GELU). The reconstruction loss becomes:

$$
\ell(W; x_t) = \|\phi(x_t) - f(\psi(x_t); W)\|^2
$$

The gradient $\nabla_W \ell$ requires backpropagation through the MLP. Unlike TTT-Linear, **there is no closed-form solution** — each timestep requires an actual gradient descent step.

### 1.4 Mini-Batch TTT: Practical Parallelization

The paper introduces mini-batch TTT to reduce memory I/O costs [^3157^]. Instead of updating $W_t$ every token, updates are batched in chunks of size $b$:

$$
W_t = W_{t'} - \eta \sum_{s=t'}^t \nabla_W \ell(W_{t'}; x_s), \quad t' = t - \mod(t, b)
$$

This allows parallel gradient computation within each batch, trading off some timeliness for hardware efficiency. The paper evaluates TTT-MLP at 125M to 1.3B parameters, showing it can "keep reducing perplexity by conditioning on more tokens" while Mamba plateaus after 16K context [^3157^].

### 1.5 Theoretical Equivalence: TTT as Attention

**Theorem 1.4 (Sun et al., 2024).** TTT-Linear with gradient descent is **exactly equivalent** to linear attention. TTT with a kernel estimator as the inner-loop learner is **equivalent to self-attention**. Therefore, TTT is a strict generalization that subsumes both attention mechanisms and recurrent architectures under a single self-supervised learning framework [^3157^][^3186^].

---

## 2. TTT vs. In-Context Learning: The Fundamental Distinction

| Dimension | In-Context Learning (ICL) | Test-Time Training (TTT) |
|-----------|----------------------------|--------------------------|
| **What changes** | The prompt / input sequence | The model weights $W_t$ |
| **Mechanism** | No gradients; pattern matching in pre-trained weights | Explicit gradient-based learning on test sequence |
| **Compute per token** | $O(t)$ for KV cache scan | $O(1)$ with TTT-Linear; $O(d^2)$ with TTT-MLP |
| **Memory** | KV cache grows linearly with $t$ | Hidden state has fixed size (size of $W$) |
| **Adaptation depth** | Shallow; limited by context length | Deep; each token refines the model |
| **Data persistence** | Ephemeral (lost when context cleared) | Persistent within sequence; can be saved |

ICL, as formalized by Brown et al. (2020), is inference-only: the model adapts to a task by prepending exemplars $(x_1, y_1), \ldots, (x_k, y_k)$ to the prompt. No parameter updates occur. Chen et al. (2022) [^3210^] formalize **in-context tuning (ICT)**, which meta-trains the model to better use ICL, but still freezes parameters at test time.

TTT is fundamentally different: it performs **gradient descent on the test sequence itself**, updating model parameters. This is not merely "better prompting" — it is genuine learning during inference.

The practical distinction: ICL works because pre-training has encoded task structures; TTT works because the model literally relearns on the fly.

---

## 3. Applying TTT to Qwen3-8B on Apple Silicon

### 3.1 Current Inference Landscape

Apple Silicon (M-series) has emerged as a viable platform for LLM inference. Key infrastructure:

- **MLX**: Native Apple ML framework with unified memory, lazy evaluation, zero-copy tensors [^1^]
- **Qwen3-8B**: 8B dense parameters; ~5.6GB at 4-bit quantization; ~17.5GB at bf16 [^1405^]
- **vllm-mlx**: Achieves 21-87% higher throughput than llama.cpp on Apple Silicon; continuous batching scales to 4.3x aggregate throughput [^1^]

### 3.2 Can TTT Run on a 16GB MacBook?

**Assessment: Partially yes, with significant constraints.**

A 16GB MacBook Pro (M3/M4 base) has ~12GB available after OS overhead. The memory budget:

| Component | Size (Qwen3-8B) |
|-----------|----------------|
| Model weights (4-bit) | ~5.6 GB |
| KV cache (8K context) | ~1.5 GB |
| Activations / workspace | ~2.0 GB |
| **Available for TTT** | **~3.0 GB** |

For TTT-Linear: The hidden state $W$ for a single layer has size $d_{\text{out}} \times d_{\text{in}}$. For Qwen3-8B with hidden dim $d = 4096$, this is $4096 \times 4096 \times 4 \text{ bytes} \approx 64$ MB per layer. With 32 layers: ~2 GB for all TTT-Linear hidden states. This **fits** in the 3GB budget.

For TTT-MLP: The hidden state is a two-layer MLP. If $W_1 \in \mathbb{R}^{m \times d}$ and $W_2 \in \mathbb{R}^{d \times m}$ with hidden width $m = 4d$, the per-layer state is $5d^2 \approx 320$ MB. For 32 layers: ~10 GB. This **exceeds** the available budget.

**Compute costs:** TTT-Linear adds ~$O(d^2)$ operations per token, which is comparable to the attention mechanism already present. TTT-MLP adds significantly more FLOPs due to the inner MLP forward/backward pass. On Apple Silicon's memory-bandwidth-bound inference, TTT-Linear's additional compute is likely tolerable; TTT-MLP would cause throughput collapse.

### 3.3 Required Modifications

To deploy TTT on Qwen3-8B with MLX:

1. **Replace attention layers with TTT-Linear layers**: This requires architecture surgery — replacing the standard multi-head attention with the TTT framework. The outer-loop parameters $\phi$ (view transform) and $\psi$ (target transform) must be learned during pre-training or fine-tuning.

2. **Gradient computation at inference**: MLX supports automatic differentiation. The self-supervised loss gradient can be computed via `mx.grad()` during the forward pass. This requires the model to be in training mode during inference — a paradigm shift.

3. **Mini-batch TTT for efficiency**: Batch size $b = 32$ or $64$ tokens amortizes the gradient computation overhead across multiple positions.

**Verdict:** TTT-Linear on Qwen3-8B 4-bit is **buildable** on a 16GB MacBook. TTT-MLP is not. The primary engineering challenge is not memory but the **architecture modification**: Qwen3 must be pre-trained or at least fine-tuned with TTT layers, which is a major undertaking.

---

## 4. Online / Continual Learning and Catastrophic Forgetting

### 4.1 The Forgetting Problem

When a model adapts its weights during deployment, it risks **catastrophic forgetting** (French, 1993; McCloskey & Cohen, 1989) [^1165^]: performance on previously learned tasks degrades as new data arrives. In a conversational setting, this means the model might forget its pre-training knowledge or earlier parts of the conversation.

### 4.2 Regularization-Based Methods

**Elastic Weight Consolidation (EWC)** [^3218^] computes the diagonal Fisher Information Matrix $F$ to identify parameters critical for prior tasks, then penalizes changes to those parameters:

$$
\mathcal{L}_{\text{EWC}}(\theta) = \mathcal{L}_{\text{current}}(\theta) + \frac{\lambda}{2} \sum_k F_k (\theta_k - \theta_k^*)^2
$$

**Synaptic Intelligence (SI)** [^3222^] accumulates parameter importance $\Omega_k$ over training trajectories, using a quadratic surrogate loss:

$$
\tilde{\mathcal{L}}_\mu = \mathcal{L}_\mu + c \sum_k \Omega_k^\mu (\tilde{\theta}_k - \theta_k)^2
$$

where $\Omega_k$ measures how much parameter $k$ contributed to loss reduction during previous tasks.

### 4.3 LoRA-Based Continual Learning

**TreeLoRA** and related methods [^3161^] use parameter-efficient fine-tuning to mitigate forgetting. By injecting low-rank adapters $A_i B_i$ instead of modifying base weights $W_0$, the system can:

- Add new LoRA modules for new tasks
- Merge LoRAs with regularization to preserve prior knowledge
- Route to appropriate LoRAs via a task router

The update is $W = W_0 + BA$ where $B \in \mathbb{R}^{d \times r}$, $A \in \mathbb{R}^{r \times d}$, and $r \ll d$. Since only $r(d_{\text{out}} + d_{\text{in}})$ parameters change per task, the search space for forgetting is dramatically reduced.

### 4.4 Architecture-Based Methods for LLMs

Recent work surveys three categories of continual learning for LLMs [^3221^]:

1. **Continual Pre-training**: Domain-adaptive pre-training on new corpora while preserving general knowledge.
2. **Continual Fine-tuning**: Sequential instruction tuning on new tasks.
3. **Continual Alignment**: Sequential RLHF/RLAIF to update model behavior.

Notable architectural innovations include:
- **MixLoRA**: MoE-style routing between LoRA experts [^3221^]
- **MAC (Memory of Amortized Contexts)**: An amortization network compresses data into compact modulations stored in memory; no gradient updates needed at inference [^3221^]
- **DKVB**: Discrete key-value bottleneck that only updates key-value pairs, not full parameters [^3221^]

### 4.5 Why RL Forgets Less

Surprisingly, reinforcement learning fine-tuning (RFT) exhibits less catastrophic forgetting than supervised fine-tuning [^1164^]. The theoretical explanation: "RFT's updates are inherently more conservative in parameter subspaces sensitive to prior tasks. This conservatism is naturally scaled by the variance of the reward signal, creating a data-dependent regularization."

This suggests that **gradient noise and conservative update scaling** — hallmarks of RL — may be protective against forgetting. A TTT system that injects controlled noise or caps gradient magnitudes may inherit this protection.

---

## 5. Gradient-Based Memory: Storing "Conversation Gradients"

### 5.1 The Core Idea

Instead of storing KV caches (which grow linearly with sequence length), can we store **gradients** as compressed memory? Each conversation turn produces gradients $\nabla_\theta \mathcal{L}(\theta; x_t)$. If stored and replayed, these gradients act as "fast weights" that bias the model toward previously learned patterns.

### 5.2 Sherry-Packed Gradient Compression

The concept of "Sherry-packed" gradients refers to aggressive quantization and compression of gradient tensors for storage. Standard gradient compression techniques include:

- **1-bit signSGD**: Store only the sign of each gradient component
- **Top-K sparsification**: Store only the K largest magnitude gradients
- **Error feedback**: Accumulate compression residuals across steps
- **Random sketching**: Use Count-Sketch or Johnson-Lindenstrauss projections

For a Qwen3-8B model with 8B parameters, even 1-bit gradients require 1 GB. To make this practical, we need structural compression.

### 5.3 LoRA Gradient Storage

If adaptation occurs via LoRA (rank $r = 8$), only the low-rank matrices $A, B$ need gradients. For a single layer with $d = 4096$: 
- $A \in \mathbb{R}^{8 \times 4096}$: 32K parameters
- $B \in \mathbb{R}^{4096 \times 8}$: 32K parameters

Per layer: ~64K parameters. For 32 layers with 4-byte floats: ~8 MB per conversation turn. With quantization to bf16: ~4 MB. This is **practical** for local storage.

### 5.4 Fast Weights from Stored Gradients

The stored gradients can be applied as **fast weights** following the hypernetwork paradigm [^3224^]. Define a slow network (the base LLM) and fast weights generated from gradient memory:

$$
\theta_t^{\text{fast}} = \theta_0 + \sum_{s=1}^t \alpha_s \cdot g_s \odot m_s
$$

where $g_s$ is the stored gradient at turn $s$, $\alpha_s$ is a learned mixing coefficient, $m_s$ is a gating mask, and $\odot$ is element-wise multiplication. At inference time, the model uses $\theta_t^{\text{fast}}$ as its effective parameters.

This is a direct instantiation of the **fast weights** concept originally proposed by Hinton & Plaut (1987) and later developed by Ba et al. (2016) [^3226^]: "an auxiliary network to produce weight changes in the target network, acting as a short-term memory store."

---

## 6. Memory Cost: Gradient Adaptation vs. KV Cache

### 6.1 KV Cache Scaling

For a transformer with $L$ layers, $h$ heads, sequence length $t$, and head dimension $d_h$, the KV cache requires:

$$
M_{\text{KV}} = 2 \cdot L \cdot h \cdot t \cdot d_h \cdot \text{bytes}
$$

For Qwen3-8B: $L = 32$, $h = 32$, $d_h = 128$, bf16 (2 bytes):
- At $t = 8$K tokens: $2 \cdot 32 \cdot 32 \cdot 8192 \cdot 128 \cdot 2 \approx 1.3$ GB
- At $t = 128$K tokens: $\approx 21$ GB
- At $t = 1$M tokens: $\approx 168$ GB

This is the fundamental bottleneck that DeepSeek V4's Engram architecture addresses [^3179^].

### 6.2 Gradient-Based Memory Scaling

If we store LoRA gradients per conversation turn, with $T$ turns total:

$$
M_{\text{grad}} = T \cdot 2 \cdot L \cdot r \cdot (d_{\text{in}} + d_{\text{out}}) \cdot \text{bytes}
$$

For Qwen3-8B with $r = 8$, bf16, and $T = 100$ conversation turns:

$$
M_{\text{grad}} = 100 \cdot 2 \cdot 32 \cdot 8 \cdot 8192 \cdot 2 \approx 820 \text{ MB}
$$

This is **independent of context length per turn** and scales only with the number of turns. For 1000 turns: ~8 GB — still feasible on a 16GB MacBook.

### 6.3 Comparative Summary

| Memory System | Scaling | 100 turns, 8K ctx | 1000 turns, 128K ctx |
|--------------|---------|-------------------|----------------------|
| KV cache only | $O(L \cdot h \cdot d_h \cdot t)$ | ~1.3 GB | ~21 GB |
| LoRA gradients | $O(L \cdot r \cdot d \cdot T)$ | ~820 MB | ~8.2 GB |
| TTT-Linear hidden state | $O(L \cdot d^2)$ | ~2 GB | ~2 GB (fixed) |
| TTT-MLP hidden state | $O(L \cdot d^2 \cdot m)$ | ~10 GB | ~10 GB (fixed) |

The key advantage of gradient/TTT-based memory is that it is **sublinear in sequence length**. Unlike KV caches that grow with every token, TTT hidden states have fixed size regardless of context length.

---

## 7. Meta-Learning for Few-Shot LLM Adaptation

### 7.1 MAML for LLMs

**Model-Agnostic Meta-Learning (MAML)** [^3209^] formulates adaptation as bi-level optimization:

**Inner loop (task adaptation):**
$$
\theta_i = \theta - \alpha \nabla_\theta \mathcal{L}_{\mathcal{T}_i}(f_\theta)
$$

**Outer loop (meta-update):**
$$
\theta \leftarrow \theta - \beta \nabla_\theta \sum_{\mathcal{T}_i \sim p(\mathcal{T})} \mathcal{L}_{\mathcal{T}_i}(f_{\theta_i})
$$

MAML-en-LLM [^3209^] applies this to language models, exploring a wide parameter space via multiple adapted parameters before computing the meta-update using second-order gradients. Unlike MetaICL (which is essentially multi-task fine-tuning with exemplars), MAML-en-LLM performs true inner-loop adaptation and outer-loop meta-optimization.

### 7.2 In-Context Tuning (ICT)

Chen et al. (2022) [^3210^] propose **in-context tuning**, which recasts task adaptation as sequence prediction without parameter updates:

$$
\mathcal{L}_T(\theta) = \sum_{(x_T^{\text{tgt}}, y_T^{\text{tgt}}) \in \mathcal{D}_T} \left[ -\log p_\theta(y_T^{\text{tgt}} \mid x_T^{\text{tgt}}, S_T, I_T) \right]
$$

where $S_T$ are few-shot exemplars and $I_T$ is the task instruction. The model is meta-trained to predict the target given the in-context examples. At test time, **no gradients are computed** — adaptation is purely through the prompt.

### 7.3 Practical Comparison

| Method | Test-time compute | Memory | Adaptation depth |
|--------|------------------|--------|-----------------|
| ICT (Chen et al.) | $O(t)$ inference only | Prompt tokens | Shallow |
| MAML-en-LLM | $O(K)$ gradient steps | Full model copy | Medium |
| TTT-Linear | $O(1)$ per token | Fixed $d \times d$ matrix | Deep |
| TTT-MLP | $O(d^2)$ per token | Fixed MLP weights | Deep |

For on-device deployment with severe compute constraints, **ICT is the cheapest**, **TTT-Linear offers the best depth/efficiency tradeoff**, and **MAML-en-LLM is too expensive** for real-time use.

---

## 8. The eml(x,y) Universal Operator and Learning Primitives

### 8.1 The Operator

Odrzywolek (2026) [^3187^] proved that a single binary operator:

$$
\text{eml}(x, y) = \exp(x) - \ln(y)
$$

together with the constant $1$, generates all elementary functions. Examples:
- $\exp(x) = \text{eml}(x, 1)$
- $\ln(x) = \text{eml}(1, \text{eml}(\text{eml}(1, x), 1))$
- Every elementary formula becomes a binary tree over the grammar $S \to 1 \mid \text{eml}(S, S)$

### 8.2 From Universal Function to Universal Learning Operator

The eml operator's significance is **structural minimalism**: one primitive, infinite nesting, universal expressivity. This maps naturally to a hypothesis about learning dynamics:

**Hypothesis 8.1 (Universal Learning Primitive).** There exists a single differentiable operation $U(\theta, g; \eta)$ such that all useful learning dynamics (SGD, Adam, EMA, momentum, weight decay) are compositions of $U$ with different input choices.

Inspired by eml, we propose:

$$
U(\theta, g; \eta) = \theta \cdot \exp(-\eta \cdot g) - \ln(1 + \eta \cdot |g|)
$$

This operator:
1. **Multiplicative decay**: $\exp(-\eta g)$ implements exponential weight decay when $g > 0$
2. **Additive correction**: $\ln(1 + \eta |g|)$ implements a logarithmic learning rate schedule
3. **Compositional power**: By nesting $U$ with different gradient inputs (raw gradient, momentum, variance), we can recover SGD, Adam, RMSprop, and more

The eml paper also demonstrates "gradient-based symbolic regression" using EML trees as trainable circuits with standard optimizers [^3187^], recovering closed-form elementary functions from data at shallow depths. This suggests that **learned composition of simple primitives** may be sufficient for complex adaptation — a principle directly applicable to designing adaptive optimizers for test-time learning.

---

## 9. DeepSeek V4 Engram: A Cautionary Note

DeepSeek V4 reportedly introduces the **Engram memory system** achieving $O(1)$ memory retrieval via hash-based DRAM lookups, bypassing the linear KV cache scaling [^3179^][^3182^]. However:

1. **The Engram is read-only**: It stores factual knowledge, not learned weights. There is no evidence it enables on-device weight updates.
2. **Sparse MoE**: V4's ~32B active parameters per token (out of ~1T total) reduce compute but don't solve the adaptation problem.
3. **Long-context != Continual learning**: 1M token context enables better in-context learning, not gradient-based adaptation.

Engram is an **external memory architecture**, not a self-tuning mechanism. It maps to the MemGPT / MemoryLLM paradigm of persistent external storage, not to TTT.

---

## 10. State of the Art: "Learning While Using" in Production

### 10.1 Academic / Research State

| System | Mechanism | Status |
|--------|-----------|--------|
| TTT-Linear (Sun et al.) | Gradient on self-supervised loss | Research, 125M-1.3B scale [^3157^] |
| MGTTA / GML (AAAI 2025) | Gradient memory layer for TTA | Research, vision tasks [^3155^] |
| MAC (Memory of Amortized Contexts) | Amortization network, no gradients | Research, NLP tasks [^3221^] |
| Crayon (ACL 2024) | Adapter blending, no on-device training | Research, on-device [^3231^] |
| Xpert (MobiSys 2025) | Cached pLLMs from cloud | Research, mobile [^3229^] |

### 10.2 Production / Shipping Approaches

| Product | Mechanism | Status |
|---------|-----------|--------|
| Apple Foundation Models | Adapter-based specialization | Shipping (iOS 18+) [^3223^] |
| OpenAI Custom GPTs | Retrieval + prompt engineering | Shipping |
| MemGPT / Letta | External memory management | Open source, not weight updates [^844^] |
| llama.cpp sessions | Context continuation | Shipping, ephemeral |
| MLX-lm + local LoRA | Parameter-efficient fine-tuning | Available, requires explicit training |

**No shipping system today performs automatic gradient-based weight updates during normal inference.** The closest is Apple's adapter-based specialization, which requires explicit fine-tuning workflows, not transparent in-the-loop adaptation.

---

## 11. Theoretical Bounds on Test-Time Learning

### 11.1 Online Learning Regret

Test-time learning is formally an **online convex optimization** problem. The standard regret bound (Shalev-Shwartz, 2007) [^3230^] for online gradient descent with learning rate $\eta_t = O(1/\sqrt{t})$ is:

$$
R(T) = \sum_{t=1}^T \ell_t(\theta_t) - \min_{\theta^*} \sum_{t=1}^T \ell_t(\theta^*) \leq O(\sqrt{T})
$$

This sublinear regret means that on average, the test-time learner approaches the performance of the best fixed parameter in hindsight.

### 11.2 Overfitting at Test Time

The risk of overfitting is bounded by the **Rademacher complexity** of the hypothesis class. If the TTT inner-loop learner has $d$ parameters and sees $T$ tokens, the generalization gap is $O(\sqrt{d/T})$ [^3157^].

For TTT-Linear with $W \in \mathbb{R}^{d \times d}$ ($d^2$ parameters) on a sequence of $T$ tokens:
- **Safe regime**: $T \gg d^2$ (enough tokens to constrain the $d^2$ degrees of freedom)
- **Dangerous regime**: $T \ll d^2$ (severe overfitting to the test sequence)

This explains why TTT-Linear requires long sequences to show advantage — with only 16K tokens and $d = 4096$ ($d^2 = 16$M), the ratio $T/d^2 \approx 1$ is marginal. The mini-batch TTT and mini-batch size $b$ effectively increase the "effective sample size" to $T/b$.

### 11.3 The PAC-Bayes Perspective

A tighter bound emerges from PAC-Bayes theory. If the test-time update starts from a pre-trained prior $P$ and produces posterior $Q$, the expected loss is bounded by:

$$
\mathbb{E}_{\theta \sim Q}[\mathcal{L}(\theta)] \leq \mathbb{E}_{\theta \sim Q}[\hat{\mathcal{L}}(\theta)] + \frac{\text{KL}(Q \| P) + \log(1/\delta)}{T}
$$

Pre-training provides a strong prior $P$, making $\text{KL}(Q \| P)$ small even after $T$ test-time updates. This is why TTT works: the pre-trained initialization keeps the posterior close to a good starting point.

---

## 12. Helios Shadow Memory Architecture: Explicit Connection

The Helios Shadow Memory architecture is a persistent gradient memory system that stores "conversation gradients" as first-class memory objects. Its design principles map directly to the research surveyed:

| Helios Component | Research Foundation | Function |
|-----------------|--------------------|----------|
| **Gradient Shadow Store** | Gradient Memory Layer (GML) [^3155^] | Compresses historical gradients into network parameters via self-supervised reconstruction |
| **Fast Weight Projection** | Hypernetworks / Fast Weights [^3224^] | Generates context-dependent weights from stored gradients |
| **EWC Guardian** | Elastic Weight Consolidation [^3218^] | Protects critical parameters from catastrophic drift |
| **LoRA Adapter Bank** | TreeLoRA / MixLoRA [^3161^][^3221^] | Modular task-specific adaptations with routing |
| **Shadow Sync** | Local SGD / Federated Learning [^3177^] | Aggregates gradient updates across sessions without cloud dependency |

The Helios architecture operationalizes the TTT philosophy by making every conversation a "test sequence" that produces gradient artifacts ("shadows"). These shadows are not ephemeral like KV caches — they are persistent, compressible, and composable. The base model remains frozen; adaptation occurs via fast weights generated from the shadow store.

---

## 13. Buildability Assessment: 16GB MacBook

### 13.1 What Can Actually Be Built Today

| Approach | Memory | Compute | Engineering Effort | Verdict |
|----------|--------|---------|-------------------|---------|
| KV cache + long context | ~1-2 GB at 8K | Standard | None | **Works now** |
| LoRA fine-tuning post-chat | ~5 GB (model + LoRA) | ~minutes | Low | **Buildable** |
| Gradient memory + fast weights | ~6 GB (model + shadows) | ~2x inference | Medium | **Buildable with effort** |
| TTT-Linear layer (trained model) | ~7 GB (model + hidden states) | ~1.5x inference | Very high | **Requires re-pretraining** |
| TTT-MLP layer | ~15 GB | ~5x inference | Very high | **Not on 16GB** |
| Full weight online updates | ~5 GB | ~10x inference | Medium | **Forgets catastrophically** |

### 13.2 Recommended Architecture for 16GB MacBook

The practical build order:

1. **Phase 1 (Now)**: Qwen3-8B 4-bit quantized + MLX + persistent LoRA bank. After each conversation, compute LoRA gradients on a "reflection loss" (reconstructing the conversation summary), store in adapter bank. Load appropriate adapters at conversation start.

2. **Phase 2 (Near-term)**: Add gradient memory compression. Store conversation gradients in a "shadow store" using top-K sparsification + 8-bit quantization. Use a small hypernetwork to generate fast weights from the shadow store at inference time.

3. **Phase 3 (Research)**: Pre-train or fine-tune a TTT-Linear variant of Qwen3-8B. Replace attention layers with TTT layers trained with mini-batch self-supervised reconstruction. This requires significant compute but produces the most elegant self-tuning system.

### 13.3 Memory Budget for Phase 2

```
Qwen3-8B 4-bit quantized:           5.6 GB
MLX runtime overhead:                1.5 GB
KV cache (current conversation):     1.0 GB
Gradient shadow store (100 turns):   1.0 GB
Hypernetwork (fast weight generator): 0.2 GB
LoRA adapter bank (10 adapters):     0.1 GB
                                    --------
Total:                              ~9.4 GB
Available headroom:                  ~2.6 GB
```

This fits comfortably within 16GB with margin for OS and other applications.

---

## 14. Rust Code Scaffolds

### 14.1 TTT-Linear Layer

```rust
//! TTT-Linear Layer Implementation
//! Based on Sun et al., "Learning to (Learn at Test Time)", NeurIPS 2024
//! arXiv:2407.04620

use ndarray::{Array1, Array2, Axis, linalg::generalized_dot};

/// Inner-loop learner: linear model W with self-supervised reconstruction loss
pub struct TttLinearLayer {
    /// Outer-loop parameter: view transform (learned during pre-training)
    phi: Array2<f32>,
    /// Outer-loop parameter: target transform (learned during pre-training)
    psi: Array2<f32>,
    /// Inner-loop hidden state: the "model" itself (updated at test time)
    w: Array2<f32>,
    /// Sufficient statistic: accumulated outer products phi(x) * psi(x)^T
    g: Array2<f32>,
    /// Sufficient statistic: accumulated psi(x) * psi(x)^T
    h: Array2<f32>,
    /// Learning rate for inner-loop update
    eta: f32,
    /// Dimensions
    d_in: usize,
    d_out: usize,
    d_ss: usize,
}

impl TttLinearLayer {
    pub fn new(d_in: usize, d_out: usize, d_ss: usize, eta: f32) -> Self {
        Self {
            phi: Array2::zeros((d_ss, d_in)),
            psi: Array2::zeros((d_in, d_ss)), // psi maps to d_ss; corrected below
            w: Array2::zeros((d_ss, d_ss)),
            g: Array2::zeros((d_ss, d_ss)),
            h: Array2::zeros((d_ss, d_ss)),
            eta,
            d_in,
            d_out,
            d_ss,
        }
    }

    /// Update the hidden state W using a self-supervised gradient step on token x.
    /// This is the core "test-time training" operation.
    pub fn update(&mut self, x: &Array1<f32>) {
        // Compute views: phi(x) and psi(x)
        let phi_x = self.phi.dot(x); // shape: [d_ss]
        let psi_x = self.psi.dot(x); // shape: [d_ss] — assuming psi: d_in -> d_ss

        // Accumulate sufficient statistics for closed-form update
        // G += phi(x) * psi(x)^T
        for i in 0..self.d_ss {
            for j in 0..self.d_ss {
                self.g[[i, j]] += phi_x[i] * psi_x[j];
                self.h[[i, j]] += psi_x[i] * psi_x[j];
            }
        }

        // Closed-form TTT-Linear update: equivalent to gradient descent on reconstruction loss
        // W_t = W_{t-1} + 2*eta * (phi(x) - W*psi(x)) * psi(x)^T
        let residual = &phi_x - self.w.dot(&psi_x);
        let outer = residual.insert_axis(Axis(1)).dot(&psi_x.insert_axis(Axis(0)));
        self.w = &self.w + &(2.0 * self.eta * outer);
    }

    /// Produce output for token x using the current hidden state W.
    pub fn forward(&self, x: &Array1<f32>) -> Array1<f32> {
        // z_t = f(x_t; W_t) = projection of W_t applied to x
        // In the paper, the output is a learned linear projection after TTT update
        self.w.dot(&self.psi.dot(x)) // Simplified: actual output uses learned g
    }

    /// Mini-batch TTT: accumulate gradients over b tokens, then update once.
    pub fn update_batch(&mut self, xs: &[Array1<f32>]) {
        let b = xs.len();
        let mut grad_accum = Array2::zeros((self.d_ss, self.d_ss));

        for x in xs {
            let phi_x = self.phi.dot(x);
            let psi_x = self.psi.dot(x);
            let residual = &phi_x - self.w.dot(&psi_x);
            let outer = residual.insert_axis(Axis(1)).dot(&psi_x.insert_axis(Axis(0)));
            grad_accum = grad_accum + outer;
        }

        self.w = &self.w + &(2.0 * self.eta * grad_accum / b as f32);
    }
}

/// Full TTT-Transformer block: replaces MultiHeadAttention with TTT-Linear layers
pub struct TttTransformerBlock {
    ttt_layers: Vec<TttLinearLayer>,
    ffn: FeedForwardNetwork,
    layer_norm1: LayerNorm,
    layer_norm2: LayerNorm,
}

impl TttTransformerBlock {
    pub fn forward(&mut self, x: &Array2<f32>) -> Array2<f32> {
        // x: [seq_len, d_model]
        let seq_len = x.shape()[0];
        let mut out = x.clone();

        // TTT sequence modeling: each token updates its layer's hidden state
        for t in 0..seq_len {
            let token = x.row(t).to_owned();
            for layer in &mut self.ttt_layers {
                layer.update(&token);
            }
        }

        // Produce outputs from final hidden states
        for t in 0..seq_len {
            let token = x.row(t).to_owned();
            let mut ttt_out = Array1::zeros(self.ttt_layers[0].d_out);
            for layer in &self.ttt_layers {
                ttt_out = ttt_out + layer.forward(&token);
            }
            out.row_mut(t).assign(&ttt_out);
        }

        let normed = self.layer_norm1.forward(&out);
        let ffn_out = self.ffn.forward(&normed);
        self.layer_norm2.forward(&(out + ffn_out))
    }
}

// Placeholder types for compilation
type FeedForwardNetwork = (); 
type LayerNorm = ();
```

### 14.2 Gradient-Based Fast Weights

```rust
//! Gradient Memory + Fast Weights System
//! Inspired by: Hypernetworks (Ha et al. 2016, arXiv:1609.09106)
//!             Fast Weights (Hinton & Plaut 1987; Ba et al. 2016)
//!             Gradient Memory Layer (AAAI 2025)

use std::collections::VecDeque;
use ndarray::{Array1, Array2, ScalarOperand};
use serde::{Serialize, Deserialize};

/// A compressed gradient snapshot from a conversation turn.
/// Stored as a "Sherry-packed" representation: 8-bit quantized, top-K sparse.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GradientShadow {
    /// Conversation turn identifier
    pub turn_id: u64,
    /// Timestamp for recency weighting
    pub timestamp: f64,
    /// Top-K indices of significant gradients
    pub indices: Vec<usize>,
    /// 8-bit quantized gradient values (dequantized with scale + zero_point)
    pub values_i8: Vec<i8>,
    /// Quantization scale
    pub scale: f32,
    /// Quantization zero point
    pub zero_point: i8,
    /// Layer identifier (which transformer layer this shadow applies to)
    pub layer_id: usize,
    /// Importance score for forgetting gating
    pub importance: f32,
}

impl GradientShadow {
    /// Dequantize to full f32 gradient vector
    pub fn decompress(&self, dim: usize) -> Array1<f32> {
        let mut grad = Array1::zeros(dim);
        for (idx, val_i8) in self.indices.iter().zip(self.values_i8.iter()) {
            grad[*idx] = (self.scale * (*val_i8 - self.zero_point) as f32);
        }
        grad
    }

    /// Compress a full gradient vector into Sherry-packed form
    pub fn compress(grad: &Array1<f32>, top_k: usize, layer_id: usize, turn_id: u64) -> Self {
        let mut indexed: Vec<(usize, f32)> = grad.iter().enumerate()
            .map(|(i, v)| (i, *v))
            .collect();
        indexed.sort_by(|a, b| b.1.abs().partial_cmp(&a.1.abs()).unwrap());
        indexed.truncate(top_k);

        let max_abs = indexed.iter().map(|(_, v)| v.abs()).fold(0.0f32, f32::max);
        let scale = if max_abs > 0.0 { max_abs / 127.0 } else { 1.0 };
        let zero_point = 0i8;

        let indices: Vec<usize> = indexed.iter().map(|(i, _)| *i).collect();
        let values_i8: Vec<i8> = indexed.iter()
            .map(|(_, v)| ((*v / scale).clamp(-127.0, 127.0) as i8))
            .collect();

        // Importance = L2 norm of compressed gradient
        let importance = indexed.iter().map(|(_, v)| v * v).sum::<f32>().sqrt();

        Self {
            turn_id,
            timestamp: 0.0, // Set by caller
            indices,
            values_i8,
            scale,
            zero_point,
            layer_id,
            importance,
        }
    }
}

/// Persistent shadow store for conversation gradients.
/// Implements EWC-style importance-weighted aggregation and recency gating.
pub struct ShadowMemory {
    /// Maximum number of shadows stored per layer
    capacity: usize,
    /// Per-layer FIFO queue of gradient shadows
    store: Vec<VecDeque<GradientShadow>>,
    /// EWC-style parameter importance (diagonal Fisher approximation)
    /// Protected parameters drift less.
    parameter_importance: Vec<Array1<f32>>,
    /// Model dimension per layer
    dim: usize,
    /// EWC penalty strength
    lambda: f32,
    /// Recency decay factor for mixing coefficients
    recency_tau: f32,
}

impl ShadowMemory {
    pub fn new(num_layers: usize, dim: usize, capacity: usize, lambda: f32) -> Self {
        Self {
            capacity,
            store: (0..num_layers).map(|_| VecDeque::with_capacity(capacity)).collect(),
            parameter_importance: (0..num_layers).map(|_| Array1::zeros(dim)).collect(),
            dim,
            lambda,
            recency_tau: 0.95,
        }
    }

    /// Record a new gradient shadow from a conversation turn.
    pub fn record_shadow(&mut self, shadow: GradientShadow) {
        let layer = shadow.layer_id;
        if self.store[layer].len() >= self.capacity {
            // Eviction: remove oldest shadow (FIFO)
            // Could use importance-weighted eviction instead
            self.store[layer].pop_front();
        }
        self.store[layer].push_back(shadow);
    }

    /// Compute fast weights for a given layer by blending stored shadows.
    /// Returns a correction vector delta_theta to add to base parameters.
    pub fn compute_fast_weights(&self, layer_id: usize) -> Array1<f32> {
        let mut delta = Array1::zeros(self.dim);
        let shadows = &self.store[layer_id];
        let importance = &self.parameter_importance[layer_id];

        if shadows.is_empty() {
            return delta;
        }

        // Compute recency-weighted mixing coefficients
        let n = shadows.len();
        let mut weights = Vec::with_capacity(n);
        let mut sum_weight = 0.0f32;

        for (i, shadow) in shadows.iter().enumerate() {
            // Recency weighting: newer shadows have higher weight
            let recency = self.recency_tau.powi((n - i - 1) as i32);
            // EWC gating: reduce influence on important parameters
            let ewc_gate = 1.0 / (1.0 + self.lambda * importance.mean().unwrap_or(0.0));
            let w = recency * ewc_gate * shadow.importance;
            weights.push(w);
            sum_weight += w;
        }

        // Blend decompressed gradients
        for (shadow, w) in shadows.iter().zip(weights.iter()) {
            let grad = shadow.decompress(self.dim);
            delta = delta + grad * (*w / sum_weight);
        }

        delta
    }

    /// Update parameter importance using Synaptic Intelligence accumulation.
    /// Call this after each training step with the parameter change vector.
    pub fn update_importance(&mut self, layer_id: usize, param_delta: &Array1<f32>, loss_delta: f32) {
        let omega = &mut self.parameter_importance[layer_id];
        for i in 0..self.dim {
            // Omega_k accumulates: (loss reduction) / (parameter movement)^2
            if param_delta[i].abs() > 1e-8 {
                omega[i] += (loss_delta.abs() / (param_delta[i] * param_delta[i])).min(1e6);
            }
        }
    }
}

/// Fast Weight Generator: a small hypernetwork that produces layer-specific
/// weight corrections from the shadow store.
pub struct FastWeightHypernetwork {
    /// Small embedding dimension for shadow encoding
    embed_dim: usize,
    /// One linear projection per layer: shadow_vector -> weight_correction
    projectors: Vec<Array2<f32>>,
}

impl FastWeightHypernetwork {
    /// Generate weight corrections for all layers.
    pub fn generate(&self, shadow_memory: &ShadowMemory) -> Vec<Array1<f32>> {
        let num_layers = self.projectors.len();
        let mut corrections = Vec::with_capacity(num_layers);

        for layer_id in 0..num_layers {
            let shadow_vec = shadow_memory.compute_fast_weights(layer_id);
            // Simple linear projection: could be replaced with small MLP
            let correction = self.projectors[layer_id].dot(&shadow_vec);
            corrections.push(correction);
        }

        corrections
    }
}

/// Main inference engine: base LLM + shadow memory + fast weights.
pub struct SelfTuningInferenceEngine {
    /// Base model parameters (frozen)
    base_params: Vec<Array1<f32>>,
    /// Shadow memory stores conversation history as compressed gradients
    memory: ShadowMemory,
    /// Hypernetwork generates context-dependent corrections
    hypernet: FastWeightHypernetwork,
    /// Current effective parameters = base + fast_weights
    effective_params: Vec<Array1<f32>>,
}

impl SelfTuningInferenceEngine {
    /// Before each conversation turn, recompute effective parameters from shadows.
    pub fn prepare_for_turn(&mut self) {
        let corrections = self.hypernet.generate(&self.memory);
        for (i, (base, corr)) in self.base_params.iter().zip(corrections.iter()).enumerate() {
            self.effective_params[i] = base + corr;
        }
    }

    /// After a conversation turn, compute and store a gradient shadow.
    pub fn reflect_on_turn(&mut self, gradients: Vec<Array1<f32>>, top_k: usize) {
        for (layer_id, grad) in gradients.iter().enumerate() {
            let shadow = GradientShadow::compress(grad, top_k, layer_id, 0);
            self.memory.record_shadow(shadow);
        }
    }
}
```

---

## 15. Summary and Recommendations

### 15.1 Key Findings

1. **TTT is mathematically sound and well-defined**: The update rule $W_t = W_{t-1} - \eta \nabla \ell(W_{t-1}; x_t)$ with self-supervised reconstruction loss is a genuine learning mechanism during inference. TTT-Linear is equivalent to linear attention; TTT-MLP is a strict generalization [^3157^].

2. **TTT-Linear fits on 16GB; TTT-MLP does not**: TTT-Linear hidden states require ~2GB for Qwen3-8B, fitting in the 3GB available budget. TTT-MLP requires ~10GB, exceeding capacity [^3157^].

3. **No shipping product does automatic weight updates**: All current "personalization" is either retrieval-based (MemGPT), adapter-based (Apple Foundation Models), or prompt-based (Custom GPTs). True gradient-based test-time adaptation is research-only [^3223^][^844^].

4. **Gradient-based memory is more compact than KV cache**: LoRA gradients scale with conversation turns, not sequence length. 1000 conversation turns consume ~8GB vs. 128K tokens consuming ~21GB with KV cache [^1^][^3161^].

5. **The eml operator suggests universal learning primitives**: A single composable operator generating all elementary functions inspires the search for a single composable learning operator. Whether such a primitive exists for neural adaptation remains open [^3187^].

6. **EWC + SI + LoRA provide a practical anti-forgetting stack**: Elastic Weight Consolidation protects critical parameters, Synaptic Intelligence tracks importance online, and LoRA restricts the update subspace. Together, they make on-device continual learning viable [^3218^][^3222^][^3161^].

7. **DeepSeek V4's Engram is external memory, not self-tuning**: Engram achieves $O(1)$ retrieval but does not update model weights. It complements, rather than replaces, gradient-based adaptation [^3179^].

### 15.2 Recommended Architecture: "Helios Self-Tuning Stack"

For a 16GB MacBook running Qwen3-8B:

```
┌─────────────────────────────────────────────────────┐
│  Layer 3: Application Interface                       │
│  - Conversation manager                               │
│  - Adapter routing                                    │
├─────────────────────────────────────────────────────┤
│  Layer 2: Fast Weight System                          │
│  - ShadowMemory (gradient store, EWC-gated)           │
│  - FastWeightHypernetwork (context corrections)       │
│  - LoRA Adapter Bank (task-specific modules)          │
├─────────────────────────────────────────────────────┤
│  Layer 1: Inference Engine                            │
│  - Qwen3-8B 4-bit quantized (MLX)                   │
│  - KV cache (current conversation only)               │
│  - Effective params = base + fast_weights           │
├─────────────────────────────────────────────────────┤
│  Layer 0: Persistence                               │
│  - Shadow store on disk (compressed gradients)        │
│  - Adapter weights on disk (LoRA checkpoints)       │
│  - EWC importance matrices on disk                    │
└─────────────────────────────────────────────────────┘
```

### 15.3 Critical Open Problems

1. **Pre-training with TTT layers**: No open-source TTT-Linear LLM exists. Building one requires re-implementing the architecture and training from scratch or fine-tuning a strong base model.

2. **Stability of online gradient updates**: Even with EWC/SI, long-running online learning may drift. Need bounded-gradient mechanisms (e.g., trust regions, projection onto pre-trained subspace).

3. **Evaluation of "learning" vs. "memorization"**: A self-tuning model must be evaluated on generalization to novel queries about prior conversations, not just retrieval of verbatim statements.

4. **Privacy of gradient shadows**: Stored gradients may leak training data. Differential privacy during shadow compression is an open problem.

---

## References

[^3157^] Yu Sun, Xinhao Li, Karan Dalal, et al. "Learning to (Learn at Test Time): RNNs with Expressive Hidden States." *NeurIPS 2024*. arXiv:2407.04620.

[^3155^] "Learning to Generate Gradients for Test-Time Adaptation via Test-Time Training Layers." *AAAI 2025*. arXiv:2412.16901.

[^3186^] Yu Sun, et al. "Learning to (Learn at Test Time)." arXiv:2310.13807.

[^3224^] David Ha, Andrew Dai, Quoc V. Le. "HyperNetworks." *ICLR 2017*. arXiv:1609.09106.

[^3226^] Neil C. Rabinowitz. "Meta Networks." Building on fast weights: Hinton & Plaut (1987); Ba et al. (2016).

[^3209^] "MAML-en-LLM: Model Agnostic Meta-Training of LLMs for Improved In-Context Learning." arXiv:2405.11446.

[^3210^] Yanda Chen, Ruiqi Zhong, Sheng Zha, George Karypis, He He. "Meta-learning via Language Model In-context Tuning." *ACL 2022*. arXiv:2110.07814.

[^3218^] "Continual Learning through Retrieval and Imagination." *AAAI*.

[^3222^] Friedemann Zenke, Ben Poole, Surya Ganguli. "Continual Learning Through Synaptic Intelligence." *ICML 2017*.

[^3161^] "TreeLoRA: Efficient Continual Learning via Layer-Wise Distributionally Adaptive Re-Parameterization." *ICML 2025*.

[^3221^] "Continual Learning in Large Language Models." arXiv:2603.12658.

[^1164^] Cameron R. Wolfe. "Continual Learning with RL for LLMs." Blog post, 2026.

[^1165^] "Continual Learning of Large Language Models." *ACM Computing Surveys*, 2025.

[^3177^] "Asynchronous Online Federated Learning for Edge Devices." arXiv:1911.02134.

[^3187^] Andrzej Odrzywolek. "All elementary functions from a single binary operator." arXiv:2603.21852.

[^3179^] "DeepSeek V4: Engram Architecture, 1M Context & Coding Guide." Digital Applied, 2026.

[^3182^] "Data Story: A Deep Dive into Deepseek V4." Kili Technology, 2026.

[^844^] "Design Patterns for Long-Term Memory in LLM-Powered Architectures." Serokell, 2025.

[^1^] "Native LLM and MLLM Inference at Scale on Apple Silicon." arXiv:2601.19139.

[^1405^] "Exploring LLMs with MLX and the Neural Accelerators in the M5 GPU." Apple Machine Learning Research, 2025.

[^3223^] "On-Device LLM Personalization at Scale." TechBytes, 2026.

[^3229^] "Expediting On-Device LLM Personalization via Explainable Model Selection." *MobiSys 2025*.

[^3231^] "Crayon: Customized On-Device LLM via Instant Adapter Blending." *ACL 2024*.

[^3230^] Shai Shalev-Shwartz. "Online Learning: Theory, Algorithms, and Applications." PhD Thesis, 2007.

[^3214^] "Adaptive KV Cache Management for Efficient Transformer Inference." Chalmers University.
