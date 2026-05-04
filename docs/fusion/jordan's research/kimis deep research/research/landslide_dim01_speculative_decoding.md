# Speculative Decoding and Lookahead Decoding for Local LLM Inference — Deep Research Report

**Research focus:** Techniques, speedup numbers, draft model selection, acceptance rates, Apple Silicon / MLX-specific implementations, and continuous batching integration.  
**Date:** Compiled from web research, arXiv papers, and framework documentation.  
**Format:** Markdown with inline citations [^N^].

---

## Table of Contents

1. [Speculative Decoding with Draft Models](#1-speculative-decoding-with-draft-models)
2. [Self-Speculative Decoding (Medusa, EAGLE, ReDrafter, LayerSkip, SWIFT, ConfLayers)](#2-self-speculative-decoding)
3. [Lookahead Decoding and Jacobi Iteration](#3-lookahead-decoding-and-jacobi-iteration)
4. [Draft Model Selection and `num_draft_tokens` Tuning](#4-draft-model-selection-and-num_draft_tokens-tuning)
5. [Acceptance Rates and When Speculative Decoding Hurts](#5-acceptance-rates-and-when-speculative-decoding-hurts)
6. [Integration with Continuous Batching](#6-integration-with-continuous-batching)
7. [Apple Silicon & MLX Specific Implementations](#7-apple-silicon--mlx-specific-implementations)
8. [Implementation Quick Reference](#8-implementation-quick-reference)

---

## 1. Speculative Decoding with Draft Models

### Core Mechanism

Speculative decoding (SD) accelerates LLM inference by using a smaller, faster **draft model** to propose k candidate tokens autoregressively, then having the larger **target model** verify all candidates in a single parallel forward pass [^2407^]. The technique is mathematically lossless — the output distribution matches the target model exactly — because rejected tokens are resampled with correction [^2407^].

The expected number of accepted tokens per round is given by:

$$
\tau = \frac{1 - \alpha^{\gamma+1}}{1 - \alpha}
$$

where $\alpha$ is the per-token acceptance rate and $\gamma$ is the number of draft tokens proposed [^2437^] [^2467^].

### Speedup Numbers

| Configuration | Speedup | Notes |
|--------------|---------|-------|
| Llama 3.1 70B + Llama 3.2 1B draft (llama.cpp) | **2-3x** | Same-family, same tokenizer [^2438^] |
| Llama 3.1 70B + 1B draft (vLLM) | **2.31x** | Production benchmark [^1421^] |
| Vicuna + GPT2-Small/GPT2-XL draft (SPRINTER) | **1.7x** | Approximate verification, 8.3x fewer FLOPs [^2408^] |
| Qwen2.5 72B + Qwen2.5 7B draft | **2-2.5x** | Same-family draft [^2438^] |
| Mixtral 8x7B + Mistral 7B draft | **1.5-2x** | MoE target with dense draft [^2438^] |
| DeepSeek Coder 33B + Qwen2.5 Coder 1.5B | **2-3x** | Cross-family but task-aligned [^2438^] |
| TensorRT-LLM + ReDrafter (H100) | **2.5-2.7x** | Apple's recurrent draft in production [^2435^] [^2442^] |

### Theoretical Speedup Formula

The expected speedup can be modeled as [^2474^]:

$$
\mathbb{E}[\text{speedup}] = \frac{1 - \alpha^{k+1}}{(1-\alpha)(kc + 1)}
$$

where $c$ is the latency ratio of draft model to target model ($c < 1$). In practice, $c \leq 0.1$ is desirable [^2474^]. The acceptance rate $\alpha$ is related to the total variation distance between draft and target distributions: $\alpha = 1 - \text{TVD}(p, q)$ [^2474^].

### When Draft Models Fail

Poor draft model selection can yield **no speedup or even slowdown**. Key failure modes:
- Draft and target use **different tokenizers** (unless UAG translation is applied) [^2492^]
- Draft model is **too large** ($c > 0.1$), making sequential drafting expensive
- Draft model is **poorly aligned** with target ($\alpha < 0.5$) [^2437^]
- **High batch sizes** where verification overhead exceeds gains [^2514^]

---

## 2. Self-Speculative Decoding

Self-speculative methods eliminate the need for a separate draft model by reusing the target model's own layers, features, or adding lightweight heads. This reduces memory overhead and avoids model synchronization issues.

### 2.1 Medusa: Multiple Decoding Heads

**Medusa** adds 3-5 lightweight single-layer feed-forward "heads" on top of the target model's last hidden state to predict tokens at positions +1, +2, +3, etc. [^2436^]. It uses a **tree-based attention mechanism** to verify multiple candidate continuations in parallel without batch expansion [^2436^] [^2448^].

| Variant | Speedup | Training Required | Notes |
|---------|---------|-------------------|-------|
| **Medusa-1** | **2.2x** | ~5 hours on one A100 | Freeze backbone, train heads only; lossless [^2436^] [^2439^] |
| **Medusa-2** | **2.3-3.6x** | Longer, joint fine-tuning | Fine-tune backbone + heads with differential learning rates [^2436^] [^2448^] |
| Dynamic Tree Attention | Additional gains | No retraining | Replace fixed tree with dynamic candidate generation [^2447^] |

**Key advantages:** No separate draft model; heads share the target model's compute and KV cache. Compatible with quantization [^2439^].

**Typical acceptance scheme:** Rejection sampling for exact distribution match; "typical acceptance" (temperature threshold) for extra speed while maintaining quality [^2439^].

### 2.2 EAGLE Family: Feature-Prediction Draft Heads

**EAGLE** (Efficient Auto-regressive Decoder) uses a lightweight draft model that predicts **feature vectors (hidden states)** instead of tokens directly, then applies the target model's LM head to obtain draft tokens [^2454^] [^2455^].

| Method | Speedup | Acceptance Rate | Key Innovation |
|--------|---------|-----------------|--------------|
| **EAGLE-1** | **2.2-3.8x** | High | Reuses top-layer features; autoregression at feature level [^2469^] |
| **EAGLE-2** | **3.05-4.26x** | Dynamic tree pruning | Context-aware dynamic draft tree based on confidence [^2454^] [^2469^] |
| **EAGLE-3** | **3.0-6.5x** | **70-80%** flat across positions | Training-time test (TTT) + multi-layer feature fusion [^2454^] [^2468^] [^2469^] |

**EAGLE-3 breakthroughs:**
1. **Training-Time Test (TTT):** Simulates the actual multi-step inference process during training — feeding draft predictions back as inputs — eliminating the train-inference distribution shift that causes acceptance rates to decay with draft length [^2468^] [^2517^].
2. **Multi-Layer Feature Fusion:** Concatenates low, middle, and upper-layer features (e.g., 3 x 4096 = 12,288 dims for Llama 3.1-8B) and compresses back through a learned FC layer, capturing richer semantic information than top-layer-only methods [^2468^].

**Production benchmark (SGLang, Llama-3.1-8B, 1x H100):**
- Baseline: 158.34 tok/s
- EAGLE-2: 244.10 tok/s (**1.54x**)
- **EAGLE-3: 373.25 tok/s (2.36x)** [^2455^]

**Production benchmark (GLM-4.7-Flash, single H100):**
- B=1: 168 tok/s vs 120 tok/s baseline (**1.39x**); acceptance 40%, avg 2.4 accepted per step with k=6 [^2422^]
- B=32: 440 tok/s system throughput vs 259 tok/s baseline (**1.70x**); per-request latency improvement 1.30x [^2422^]

The EAGLE-3 draft head for GLM-4.7-Flash is only **277 MB** — small enough to co-deploy on the same GPU [^2422^].

### 2.3 ReDrafter: Apple's Recurrent Draft Model

**ReDrafter** (Recurrent Drafter), developed by Apple, leverages an **RNN** conditioned on the LLM's hidden states as the draft model, combined with **beam search** and **dynamic tree attention** to eliminate duplicated prefixes [^2435^] [^2445^].

| Implementation | Speedup | Hardware |
|---------------|---------|----------|
| PyTorch (Vicuna, MT-Bench) | **Up to 3.5x** | NVIDIA H100 |
| TensorRT-LLM (production) | **Up to 2.5x** | NVIDIA H100 |
| **MLX (on-device)** | **Up to 2.3x** | Apple Silicon Metal GPU |

ReDrafter achieves **state-of-the-art speedup** among speculative methods because the RNN draft model harnesses local temporal dependencies, improving predictive accuracy over independent head-based methods [^2435^]. Apple and NVIDIA collaborated to integrate ReDrafter into TensorRT-LLM for production deployment [^2442^] [^2443^].

### 2.4 LayerSkip: Early Exit + Self-Speculative Decoding

**LayerSkip** (Meta) is a training-time + inference-time solution [^2495^] [^2496^]:

1. **Training:** Applies **layer dropout** (low rates for early layers, higher for later layers) plus **early exit loss** where all transformer layers share the same LM head.
2. **Inference:** Exits at early layers for drafting, then verifies/corrects with remaining layers.

**Speedups:**
- **2.16x** on summarization (CNN/DM)
- **1.82x** on coding
- **2.0x** on TOPv2 semantic parsing [^2495^] [^2496^]

**Key advantage:** Lower memory footprint than other speculative methods because draft and verification share compute and activations [^2495^].

### 2.5 SWIFT: On-the-Fly Adaptive Layer Skipping

**SWIFT** is a **plug-and-play, training-free** self-speculative method that adaptively selects which layers to skip during inference [^2464^] [^2466^].

- **Speedup: 1.3-1.6x** across LLaMA-2, CodeLLaMA, and tasks including summarization, code generation, math reasoning [^2464^]
- **Acceptance rate: 98-100%** for LLaMA-2 series in greedy decoding [^2470^] [^2472^]
- Uses Bayesian optimization + random search to find optimal skip layer sets on-the-fly [^2464^]
- No auxiliary model, no training required [^2466^]

For LLaMA-70B series, SWIFT achieves **1.4-1.5x** speedup with acceptance rates exceeding **85%** [^2464^].

### 2.6 ConfLayers: Confidence-Based Adaptive Layer Skipping

**ConfLayers** (AMD / UC Irvine) is another training-free self-speculative method using confidence-based layer skipping with adaptive window sizing [^2512^] [^2475^].

- **Speedup: up to 1.4x** over vanilla autoregressive decoding
- Outperforms SWIFT on larger models (1.37x vs 1.30x on LLaMA-2-70B CNN-DM) [^2475^]
- Prioritizes maximizing **number of accepted tokens** over just acceptance rate
- Skip ratio maintained between 40-60% via adaptive threshold [^2475^]

### 2.7 N-Gram and Cache-Based Speculation (Zero Neural Overhead)

**N-gram speculation** requires no neural network at all — it caches previously generated token sequences and proposes repeats [^2438^] [^2465^]:

- **llama.cpp ngram-simple:** Searches token history for matching n-grams; best for code refactoring and repetitive text [^2438^]
- **llama.cpp ngram-map-k:** Uses internal hash-map of n-grams with configurable hit thresholds [^2438^]
- **Cacheback:** LRU cache table maps leading tokens to follower tokens; draft generation in microseconds; state-of-the-art among training-free, no-model baselines [^2465^]

These methods excel for **structured outputs** (JSON, code, legal templates) where repetition is high [^1421^].

---

## 3. Lookahead Decoding and Jacobi Iteration

### 3.1 Jacobi Decoding Foundation

Autoregressive decoding can be reformulated as solving a non-linear system via the **fixed-point Jacobi iteration method** [^2411^] [^2494^]. Each Jacobi step updates all positions in parallel:

$$
y_i^{(j+1)} = \arg\max_y p_\theta(y \mid \mathbf{y}_{<i}^{(j)}, \mathbf{x})
$$

All $n$ maximization problems can be solved in parallel with a causal attention mask — **only one forward pass** is required per iteration [^2434^]. The iteration converges when $\mathbf{y}^{(k)} = \mathbf{y}^{(k-1)}$, which is provably identical to greedy AR decoding [^2434^].

**Limitation of pure Jacobi:** Generated tokens often appear in wrong positions, and correct tokens get replaced in subsequent iterations, preventing wall-clock speedup [^2411^].

### 3.2 Lookahead Decoding

**Lookahead Decoding** builds on Jacobi by leveraging the fact that memory-bandwidth-bound decoding leaves compute cycles unused [^2411^] [^2497^]. It uses a **lookahead branch** (generates n-grams) and a **verification branch** (verifies n-grams) in a **single step**:

- Maintains an **n-gram pool** cache of historical n-grams
- Uses a 2D window with parameters $W$ (lookahead size) and $N$ (lookback steps)
- Scales linearly with compute — reduces decoding steps relative to $\log(\text{FLOPs})$ [^2411^]

**Speedups:**
- **1.8x** on MT-Bench (multi-turn chat, LLaMA-2 7B) [^2411^] [^2494^] [^2497^]
- **Up to 2.3x** on code completion (HumanEval) [^2494^]
- **Up to 4x** with Lookahead Parallelism on 8 GPUs (ClassEval) [^2411^] [^2494^]
- FlashAttention integration adds **20%** additional speedup [^2494^]

**Key advantage:** No draft model, no training, no data stores — works with any autoregressive LLM [^2497^].

### 3.3 Consistency LLMs (CLLMs)

**CLLMs** fine-tune LLMs with **consistency distillation** so the model learns to predict the fixed point from any intermediate Jacobi state [^2441^]. This achieves **2.4-3.4x** generation speedup while preserving quality [^2441^].

### 3.4 Jacobi Forcing

**Jacobi Forcing** trains models with a noise schedule across blocks, creating a curriculum from "denoise a few tokens" to "denoise many tokens" [^2440^]. Ablations show linear progressive noise schedule achieves **0.48 iterations/token** vs 0.62 for reverse progressive [^2440^].

---

## 4. Draft Model Selection and `num_draft_tokens` Tuning

### 4.1 Draft Model Selection Best Practices

**Non-negotiable requirements:**
1. **Same tokenizer** as target model (unless using UAG cross-tokenizer translation) [^2437^] [^2438^]
2. **Same architecture family** when possible (higher acceptance) [^2437^] [^1421^]
3. **Similar training data** to maximize alignment [^2437^]

**Size ratio:**
- Draft models typically range from **1/10 to 1/50** the target size [^2437^] [^1421^]
- Smaller drafts generate faster but may have lower acceptance
- Llama 3.2-1B drafting for Llama 3.1-70B is a canonical strong pairing [^2438^] [^1421^]

**Recommended model pairs (llama.cpp documentation):** [^2438^]

| Target Model | Draft Model | Expected Speedup |
|-------------|-------------|------------------|
| Llama 3.1 70B | Llama 3.2 1B | ~2-3x |
| Llama 3.1 70B | Llama 3.2 3B | ~2-2.5x |
| Qwen2.5 72B | Qwen2.5 7B | ~2-2.5x |
| Mixtral 8x7B | Mistral 7B | ~1.5-2x |

**Fine-tuning for domain-specific drafts:**
Organizations report **20-40% acceptance rate improvements** from fine-tuning a small draft model on the target model's outputs [^1421^]. Collect target outputs on representative inputs, then fine-tune the draft to match.

### 4.2 Cross-Tokenizer Draft Models (UAG)

**Universal Assisted Generation (UAG)** enables cross-family speculative decoding when draft and target have different tokenizers [^2492^] [^2493^]:

- **Naive token translation:** String round-trip (decode draft tokens → text → encode with target tokenizer). Produces low acceptance rates, often making SD slower than baseline [^2492^].
- **Context-aware translation:** Prepends a prefix window of previously accepted tokens before re-tokenization to resolve boundary ambiguities. **Consistently outperforms naive translation** across all conditions [^2492^].
- **Token-Level Intersection (TLI):** Constrains draft to vocabulary intersection at sampling time, eliminating translation latency but restricting draft fluency when intersections are small [^2492^].

For MLX-LM, context-aware UAG has been implemented as a fork enabling cross-family pairs like Bielik 11B (Mistral tokenizer) with Qwen2.5-1.5B or Llama 3.2-1B [^2492^].

### 4.3 `num_draft_tokens` / `num_speculative_tokens` Tuning

The number of draft tokens proposed per round ($\gamma$ or $k$) is critical:

| Setting | Recommendation | Rationale |
|---------|----------------|-----------|
| **k = 2-3** | Conservative, creative/diverse outputs | Lower rejection rate for high-entropy generation [^2389^] |
| **k = 4-6** | Sweet spot for structured outputs (JSON, code, legal) | Balances parallelism with acceptance [^2389^] [^1421^] |
| **k = 7-10** | Only when acceptance rate $\alpha \geq 0.7$ | High acceptance needed to amortize draft cost [^2437^] |
| **k > 10** | Generally diminishing returns | Error compounding reduces acceptance [^2420^] |

**Theoretical relationship:**
At $\alpha \geq 0.6$ and $\gamma \geq 5$, speculative decoding achieves **2-3x speedups** [^2467^]. But increasing $\gamma$ helps only when $\tau$ (expected accepted length) is high; otherwise performance may be negatively affected [^2467^].

**Adaptive tuning:** The optimal speculation length depends on batch size, GPU architecture, and model. Larger batch sizes require **smaller speculation lengths** [^2523^]. One study found adaptive speculation achieved **1.94x** average across all batch sizes vs worse fixed-length performance [^2511^].

---

## 5. Acceptance Rates and When Speculative Decoding Hurts

### 5.1 Acceptance Rate Thresholds

| Acceptance Rate ($\alpha$) | Interpretation | Action |
|---------------------------|----------------|--------|
| $\alpha \geq 0.7$ | Excellent speedup, well-matched draft | Use aggressive k=7-10 [^2437^] |
| $\alpha = 0.5-0.7$ | Good speedup, worthwhile | Use moderate k=4-6 [^2437^] |
| $\alpha = 0.4-0.5$ | Marginal, break-even region | Use conservative k=2-3 or consider alternatives [^2437^] |
| $\alpha < 0.5$ | Poor — speculative decoding may hurt | Change draft model or disable SD [^2437^] [^1421^] |

**Concrete production threshold:** According to mlx-lm documentation, acceptance rates **above 0.65** typically yield net speedups. Below that threshold, overhead of running two models outweighs gains [^2389^].

**Domain variation:**
- Legal text: often **>0.75** [^2389^]
- Creative writing: closer to **0.55** [^2389^]
- Code generation: **0.6-0.8** depending on language and task [^1421^]

### 5.2 When Speculative Decoding Hurts

**High batch sizes / high GPU utilization:**
At batch size 1-10, speculative decoding delivers **2-3x speedup**. At batch size 32+, it often performs **worse than standard decoding** [^2514^].

- On Qwen3-8B, speedup degraded from **1.93x to 0.99x** as batch size grew from 2 to 48 [^2511^]
- EAGLE speedup degrades from **1.73x to 1.21x** as batch size scales from 1 to 128 [^2450^]
- vLLM's speculative decoding underperformed its baseline at high concurrency, leading to deprecation in v1 engine [^2450^] [^2453^]
- SGLang+EAGLE exhibits negative speedups across all batch sizes in some evaluations [^2450^] [^2453^]

**Crossover point (GPT-OSS 120B on H100):** [^2517^]
- 1-8 concurrent requests: Use SD (EAGLE-3 with k=7)
- 8-32 concurrent requests: Use SD with reduced k (3-5)
- 32+ concurrent requests: **Disable speculative decoding**, rely on continuous batching

**Other failure modes:**
- **Very short responses (<20 tokens):** Not enough generation to amortize draft overhead [^2514^]
- **High-temperature creative generation:** Random sampling tanks acceptance rates [^2514^] [^2511^]
- **Memory-constrained deployments:** Draft model weights (1-8 GB) + KV cache + verification tensors consume VRAM that could go to larger batches [^2514^]
- **Poorly matched draft model:** Generic small models underperform same-family drafters [^1421^]

**Hardware-dependent effects:**
On an H100 (very high memory bandwidth), speculative decoding may show **no speedup** for Mamba 2.8B + 130M draft, while an RTX 3090 shows 1.5x under the same configuration — higher-bandwidth GPUs leave less idle compute for SD to reclaim [^2511^].

### 5.3 Pyramid Speculative Decoding (3-Model)

**PyramidSD** addresses the low-acceptance problem when draft and target are far apart in size by inserting an intermediate **qualifier model** [^2451^] [^2452^].

- Draft (1B) → Qualifier (3B) → Target (8B)
- Uses **fuzzy acceptance criteria** with divergence thresholds $\tau_Q$ and $\tau_T$
- Achieves **up to 1.91x** over standard SD (reaching 124 tok/s on RTX 4090) [^2451^]
- Best maintained when $\tau_Q \leq \tau_T$ — qualifier filters mismatches first [^2451^]

---

## 6. Integration with Continuous Batching

### 6.1 The Core Challenge

Speculative decoding and continuous batching are **tensioned** because:
1. Both aim to saturate GPU resources — enabling one can offset the other [^2523^]
2. Speculation repurposes the prefill stage for parallel verification, breaking the prefill-decode separation that batching systems optimize [^2453^]
3. Continuous batching already induces raggedness from varying request lengths; speculation compounds this with per-sequence acceptance variance, creating **nested raggedness** [^2453^]

### 6.2 Production Framework Support

**vLLM:**
- Uses **Draft Runner** and **Target Runner** within its continuous batching architecture [^2428^]
- Scheduler modified to handle multiple token slots per forward pass
- Memory manager handles KV cache for both draft and target [^2428^]
- v0 engine used batch expansion (deprecated in v1 due to K×K memory overhead) [^2450^]
- Supports speculative model parameter: `speculative_model="meta-llama/Llama-3.2-1B-Instruct"`, `num_speculative_tokens=4` [^2424^]

**SGLang:**
- Industry-leading speculative decoding with EAGLE-2/EAGLE-3, MTP, standalone draft, and n-gram [^2455^]
- EAGLE-3 achieves **2.36x** on Llama-3.1-8B at batch size 1 [^2455^]
- `--speculative-algorithm EAGLE3` with tunable `num-steps`, `eagle-topk`, `num-draft-tokens`

**TensorRT-LLM:**
- ReDrafter integrated in-engine for minimal runtime overhead [^2442^]
- Supports tensor parallelism and continuous batching [^2435^]
- Drafting and validation logic inside a single engine [^2442^]

**AWS Neuron / Transformers-NeuronX:**
- Speculative decoding now available with vLLM for continuous batching on Neuron hardware [^2424^]
- Requires target and draft from same model family

### 6.3 Batch Speculative Decoding Research

**Batch Speculative Decoding Done Right** identifies that existing batch SD methods violate correctness by breaking synchronization invariants (position tracking, attention, KV-cache) across ragged tensors [^2453^].

- **EqSpec:** Formalizes invariants; realignment accounts for **40% of computation** [^2453^]
- **EXSpec:** Expands scheduling scope with dynamic grouping by sequence length; achieves **3x throughput** at batch size 8 over batch size 1 [^2453^]
- Beyond batch size 8, throughput degrades as grouping success rates decline [^2453^]

**Adaptive strategy:** The optimal speculation length varies across batch sizes. One study's adaptive policy achieved equal or better performance than fixed-length schemes, with **extra 9% latency reduction** for time-varying requests [^2523^].

### 6.4 When to Use Each

| Scenario | Recommendation |
|----------|---------------|
| Interactive chat, B=1-8 | **Enable speculative decoding** (EAGLE-3, ReDrafter, or same-family draft) |
| Medium concurrency, B=8-32 | **Adaptive speculation** with reduced k; monitor per-request latency |
| High throughput serving, B=32+ | **Disable SD**; rely on continuous batching + PagedAttention |
| Long-context + large batch | May re-enable SD because KV cache becomes memory bottleneck, restoring SD benefits [^2511^] |

---

## 7. Apple Silicon & MLX Specific Implementations

### 7.1 Apple Silicon Hardware Landscape

Apple Silicon's unified memory architecture eliminates CPU-GPU transfer but the **shared memory bus is the binding constraint** [^2407^]:

| Chip | Max Memory | Memory Bandwidth | ~tok/s (7B Q4) | ~tok/s (70B Q4) |
|------|-----------|-----------------|----------------|-----------------|
| M1 Pro | 32 GB | 200 GB/s | 38 | — |
| M1 Max | 64 GB | 400 GB/s | 42 | 5.8 |
| M2 Pro | 32 GB | 200 GB/s | 40 | — |
| M2 Max | 96 GB | 400 GB/s | 44 | 6.2 |
| M2 Ultra | 192 GB | 800 GB/s | 50-60 | 11 |
| M3 Max | 128 GB | 400 GB/s | 46 | 7.8 |
| M4 | 32 GB | 120 GB/s | 33 | — |
| M4 Pro | 48 GB | 273 GB/s | 48 | — |
| **M4 Max** | 128 GB | **546 GB/s** | **58** | **12.5** |

[^2421^] [^2387^]

**Key insight:** M4 Max at 546 GB/s is the bandwidth king of the current lineup. MLX delivers **10-25% faster inference** than llama.cpp/Ollama on the same hardware [^2421^].

### 7.2 MLX-LM Speculative Decoding

MLX-LM provides built-in speculative decoding for **same-tokenizer** draft-target pairs [^2407^]:

```python
from mlx_lm import load, generate

model, tokenizer = load("./models/llama-3.1-8b-4bit")
draft_model, _ = load("mlx-community/Llama-3.2-1B-Instruct-4bit")

response = generate(
    model, tokenizer,
    prompt=prompt,
    max_tokens=512,
    draft_model=draft_model,
    num_draft_tokens=4,
    verbose=True,
)
```

**Expected results (M4 Max class):**
- Baseline: ~38 tok/s
- With SD: **62.4 tok/s (~1.6x)**
- Draft acceptance rate: **0.73** [^2389^]

### 7.3 Apple Silicon Specific Constraints

**Why SD behaves differently on Apple Silicon:** [^2407^]

1. **Unified memory = shared bus contention.** Both draft and target models stream weights across the same 200 GB/s bus (M2 Pro). The draft model is NOT "free" — each of the $k$ generation steps requires a full forward pass.
2. **GPU occupancy remains ~28%** regardless of configuration because the GPU is weight-streaming bound [^2407^].
3. **Verification cost DOES amortize** — verifying k candidates is nearly as fast as verifying one. The breakdown comes from **draft cost**, not verification [^2407^].
4. **Cross-tokenizer overhead:** Each draft cycle requires $k+1$ draft forward passes (the extra pass resynchronizes the drafter's KV cache after verification) [^2407^].

**Hardware-aware speedup formula for unified memory:** [^2492^]

The break-even acceptance threshold depends on:
- Token acceptance rate $\alpha$
- Memory bandwidth of platform
- Size ratio $r$ between draft and target
- Number of draft tokens $k$

For Bielik 11B (target) + ~0.8B draft on M2 Pro:
- $r \approx 0.071$ (less favorable than 70B-1B configs in literature)
- **k=2** is the safe operating point; achieves positive speedup in high-acceptance conditions
- **k=4 and beyond** are not recoverable at M2 Pro bandwidth without rarely-observed acceptance rates [^2492^]

### 7.4 ReDrafter on MLX

Apple implemented **ReDrafter in MLX** specifically for on-device inference [^2435^] [^2445^]:

- **M1 Max:** 1.37x speedup (7B model)
- **M2 Ultra:** Higher speedup, up to **2.3x**
- Optimal beam width (BW) is **lower** on less powerful GPUs:
  - M1 Max: BW=1 optimal for 7B
  - M2 Ultra: BW=3 optimal for 7B and 13B [^2435^]
- Performance declines at BW=4 for both devices due to verification cost [^2435^]

### 7.5 Cross-Family Speculative Decoding on MLX

The first systematic evaluation of cross-family speculative decoding on Apple Silicon extended MLX-LM with **UAG support** [^2492^] [^2493^]:

- Target: Bielik 11B-Instruct (Mistral-based)
- Drafts: Bielik 1.5B (Qwen-based), Qwen2.5-1.5B, Llama 3.2-1B
- **Context-aware translation is a prerequisite**, not an optimization — naive translation harms throughput in nearly all conditions [^2492^]
- Throughput is **strongly content-dependent**: up to **1.7x speedup** for structured/repetitive text; fails to outperform autoregressive for varied instruction-following content [^2492^]
- General-purpose drafters (Qwen2.5, Llama) outperformed Polish-specialized Bielik 1.5B due to tokenizer incompatibility [^2492^]

### 7.6 MLX-LM HTTP Server for Production

```bash
python3 -m mlx_lm.server \
  --model ./models/llama-3.1-8b-4bit \
  --port 8080 \
  --host 0.0.0.0
```

- OpenAI-compatible `/v1/chat/completions` endpoint [^2389^] [^2522^]
- Supports `temperature`, `max_tokens`, `top_p`, `top_k`, `stream`, `stop` [^2522^]
- **Not recommended for production** due to limited security checks; use behind reverse proxy [^2522^]
- A 14-machine M4 Pro fleet with nginx reverse-proxy replaced AUD $3,800/month cloud spend with AUD $38,000 one-time hardware cost [^2389^]

### 7.7 Third-Party MLX Implementations

**dflash-mlx** provides exact speculative decoding with OpenAI-compatible server [^2528^]:
- Defaults to Qwen3-4B BF16 target + DFlash draft
- `dflash-mlx-openai-server` exposes `/v1/chat/completions` with streaming SSE support
- ~12 GB download for default target+draft pair [^2528^]

---

## 8. Implementation Quick Reference

### 8.1 Decision Matrix

| Situation | Recommended Technique | Expected Speedup | Complexity |
|-----------|----------------------|-----------------|------------|
| Same-family models available (Llama 3.x, Qwen2.5) | Standard SD with small draft | **2-3x** | Low |
| No good draft model; can modify model | Medusa-1 heads | **2.2x** | Medium |
| Production serving, batch size 1-16 | EAGLE-3 | **2.4-3.7x** | Medium |
| Apple Silicon on-device, no extra model | ReDrafter (MLX) | **1.4-2.3x** | Low |
| No training, no extra model, plug-and-play | SWIFT or ConfLayers | **1.3-1.6x** | Low |
| Training from scratch possible | LayerSkip | **1.8-2.2x** | High |
| Code/repetitive structured output | N-gram speculation | **1.2-2x** | Very low |
| Any model, no training, no draft | Lookahead Decoding | **1.5-1.8x** | Low |
| Cross-tokenizer draft needed | UAG with context-aware translation | **1.2-1.7x** | Medium |

### 8.2 Tuning Checklist

1. **Measure baseline tok/s** before enabling anything
2. **Profile acceptance rate** on your actual prompts (legal >0.75, creative ~0.55) [^2389^]
3. **Start with k=4** for structured outputs, **k=2-3** for creative [^2389^]
4. **If acceptance <0.5:** Change draft model, fine-tune draft, or disable SD
5. **If batch size >32:** Disable SD or use adaptive k reduction
6. **On Apple Silicon:** Prefer k=2; k=4+ rarely pays off at 200 GB/s bandwidth [^2492^]
7. **Monitor GPU occupancy:** If already >50%, SD gains diminish [^2517^]

### 8.3 Key Formulas

| Metric | Formula |
|--------|---------|
| Expected accepted tokens | $\tau = (1 - \alpha^{k+1}) / (1 - \alpha)$ |
| Expected speedup | $\mathbb{E}[S] = \tau / (kc + 1)$ |
| Break-even on unified memory | $\alpha_{be} = r + \beta k$ (empirical fit) |

---

## References

[^2407^]: Cross-Family Speculative Decoding for Polish Language Models on Apple Silicon (arXiv:2604.16368, 2026)
[^2408^]: SPRINTER: Speeding up Speculative Decoding via Approximate Verification (arXiv:2502.04557, 2025)
[^2409^]: Speculative Decoding with CTC-based Draft Model (arXiv:2412.00061, 2024)
[^2410^]: EAGLE-3: Scaling up Inference Acceleration via Training-Time Test (arXiv:2503.01840, 2025)
[^2411^]: Break the Sequential Dependency of LLM Inference Using Lookahead Decoding (arXiv:2402.02057, 2024)
[^2419^]: Batch Speculative Decoding Done Right (arXiv:2510.22876, 2026)
[^2420^]: 3-Model Speculative Decoding / PyramidSD (arXiv:2510.12966, 2025)
[^2421^]: Apple Silicon for AI: M1 to M4 Buying Guide (LocalAIMaster, 2026)
[^2422^]: Speculative Decoding in Practice: EAGLE3 on GLM-4.7-Flash (HuggingFace blog, 2026)
[^2423^]: vLLM: Revolutionizing LLM Serving (Medium, 2025)
[^2424^]: AWS Neuron Developer Guide for Continuous Batching with Speculative Decoding
[^2425^]: Speculative Decoding | LLM Inference Handbook (BentoML)
[^2426^]: LayerSkip: Self-Speculative Decoding (Juejin, 2025)
[^2427^]: Faster Text Generation with Self-Speculative Decoding (HuggingFace blog, 2024)
[^2428^]: Speculative Decoding in vLLM (OpenLM, 2024)
[^2429^]: LayerSkip: Self-Speculative Decoding (CNBlogs, 2025)
[^2434^]: Fast and Accurate Causal Parallel Decoding using Jacobi Forcing (arXiv:2512.14681, 2025)
[^2435^]: Recurrent Drafter for Fast Speculative Decoding (arXiv:2403.09919, 2024)
[^2436^]: Medusa: Simple LLM Inference Acceleration Framework with Multiple Decoding Heads (arXiv:2401.10774, 2024)
[^2437^]: The Machine Learning Practitioner's Guide to Speculative Decoding (MachineLearningMastery, 2026)
[^2438^]: Speculative Decoding - llama.cpp documentation (Mintlify, 2026)
[^2439^]: LLM Inference Optimization (Medium, 2025)
[^2440^]: Fast and Accurate Causal Parallel Decoding using Jacobi Forcing (HaoAILab blog, 2025)
[^2441^]: CLLMs: Consistency Large Language Models (arXiv:2403.00835, 2024)
[^2442^]: NVIDIA TensorRT-LLM Now Supports Recurrent Drafting (NVIDIA blog, 2024)
[^2443^]: Apple AI Is Getting Better Thanks To A Partnership With NVIDIA (BGR, 2024)
[^2444^]: Recurrent Drafter (OpenReview, 2024)
[^2445^]: Recurrent Drafter for Fast Speculative Decoding (Apple ML Research, 2024)
[^2446^]: Apple embraces Nvidia GPUs to accelerate LLM inference (Yahoo Finance, 2025)
[^2447^]: Dynamic Tree Attention for MEDUSA (ICLR 2025)
[^2448^]: MEDUSA (ICML 2024, ACM)
[^2449^]: Bridging the Parallel Decoding of LLMs with the Diffusion Process (2025)
[^2450^]: Batch Speculative Decoding Done Right - Appendix E (arXiv:2510.22876, 2026)
[^2451^]: Pyramid Speculative Decoding (arXiv:2510.12966, 2025)
[^2452^]: 3-Model Speculative Decoding (arXiv:2510.12966v1, 2025)
[^2453^]: Batch Speculative Decoding Done Right (arXiv:2510.22876v1, 2025)
[^2454^]: EAGLE-3 paper (arXiv:2503.01840v1, 2025)
[^2455^]: Speculative Decoding - SGLang documentation (2026)
[^2456^]: vLLM vs TensorRT-LLM vs SGLang benchmarks (Spheron, 2026)
[^2464^]: SWIFT: On-the-Fly Self-Speculative Decoding (arXiv:2410.06916, 2024)
[^2465^]: Cacheback: Speculative Decoding With Nothing But Cache (arXiv:2511.21699, 2025)
[^2466^]: SWIFT (arXiv:2410.06916, 2024)
[^2467^]: Speculative Decoding | LLM Inference Handbook (BentoML)
[^2468^]: Boosting AI Speed with Speculative Decoding / EAGLE-3 (DataOpsLabs, 2026)
[^2469^]: EAGLE-3 Speculative Decoding Guide (E2E Networks, 2025)
[^2470^]: Swift: Self-Speculative Decoding (EmergentMind, 2024)
[^2471^]: SWIFT (OpenReview, 2024)
[^2472^]: SWIFT GitHub repository (hemingkx/SWIFT)
[^2474^]: Speculative Decoding analysis (philkrav.com, 2024)
[^2475^]: ConfLayers: Adaptive Confidence-based Layer Skipping review (TheMoonlight, 2026)
[^2492^]: Cross-Family Speculative Decoding for Polish Language Models on Apple Silicon (arXiv:2604.16368v2, 2026)
[^2493^]: Cross-Family Speculative Decoding on Apple Silicon (arXiv:2604.16368, 2026)
[^2494^]: Break the Sequential Dependency of LLM Inference Using Lookahead Decoding (arXiv:2402.02057 PDF)
[^2495^]: LayerSkip: Enabling Early Exit Inference and Self-Speculative Decoding (arXiv:2404.16710, 2024)
[^2496^]: LayerSkip (arXiv:2404.16710, 2024)
[^2497^]: Lookahead Decoding (arXiv:2402.02057, 2024)
[^2498^]: Lookahead Decoding (arXiv:2402.02057v1, 2024)
[^2499^]: Daily Papers / Lookahead (HuggingFace, 2026)
[^2500^]: LayerSkip (ACL 2024, Anthology)
[^2511^]: Speculative Decoding: How It Works & When To Use It (Redis blog, 2026)
[^2512^]: ConfLayers (arXiv:2604.14612, 2026)
[^2513^]: ConfLayers YouTube Shorts (2026)
[^2514^]: Speculative Decoding in Practice: The Free Lunch That Isn't Quite Free (TianPan, 2026)
[^2517^]: Why Your LLM Is Wasting 90% of Its GPU (Medium, 2026)
[^2522^]: MLX-LM documentation (Grokipedia, 2026)
[^2523^]: The Synergy of Speculative Decoding and Batching (arXiv:2310.18813)
[^2528^]: dflash-mlx: Exact speculative decoding on Apple Silicon (GitHub, 2026)
[^2387^]: Local LLMs Apple Silicon Mac 2026 Guide (SitePoint, 2026)
[^2389^]: Apple Silicon MLX LLM Inference Optimization Tutorial (Branch8, 2026)
[^1421^]: Speculative Decoding: Achieving 2-3x LLM Inference Speedup (Introl, 2026)
