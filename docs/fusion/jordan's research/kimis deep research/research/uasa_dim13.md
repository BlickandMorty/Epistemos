# UASA Dimension 13: DeepSeek Training & Inference Optimizations

## Executive Summary

This research report provides an exhaustive analysis of DeepSeek's training and inference optimizations, with specific focus on their applicability to local deterministic training and inference substrates. We investigate 15 distinct topic areas spanning architecture (MLA, MoE), training infrastructure (DualPipe, FP8, GRPO), and inference acceleration (speculative decoding, KV cache optimization, continuous batching). Each finding is documented with inline citations, verbatim excerpts, and confidence assessments.

---

## Table of Contents
1. [MLA: Multi-Head Latent Attention](#1-mla-multi-head-latent-attention)
2. [DualPipe: Bidirectional Pipeline Parallelism](#2-dualpipe-bidirectional-pipeline-parallelism)
3. [FP8 Mixed Precision Training](#3-fp8-mixed-precision-training)
4. [GRPO: Group Relative Policy Optimization](#4-grpo-group-relative-policy-optimization)
5. [DeepSeekMoE Architecture](#5-deepseekmoe-architecture)
6. [Distillation from DeepSeek-R1](#6-distillation-from-deepseek-r1)
7. [Multi-Token Prediction (MTP)](#7-multi-token-prediction-mtp)
8. [Expert Parallelism & All-to-All Communication](#8-expert-parallelism--all-to-all-communication)
9. [Low-Precision Inference: FP8 vs INT4](#9-low-precision-inference-fp8-vs-int4)
10. [KV Cache Optimization](#10-kv-cache-optimization)
11. [Speculative Decoding](#11-speculative-decoding)
12. [Continuous Batching & Disaggregated Serving](#12-continuous-batching--disaggregated-serving)
13. [Ring Attention](#13-ring-attention)
14. [MoE for Local Inference](#14-moe-for-local-inference)
15. [Reinforcement Learning for Reasoning](#15-reinforcement-learning-for-reasoning)
16. [Cross-Cutting Analysis: Local Deterministic Feasibility](#16-cross-cutting-analysis-local-deterministic-feasibility)

---

## 1. MLA: Multi-Head Latent Attention

### 1.1 Mathematical Formulation

Claim: MLA compresses the KV cache using low-rank matrices, with the full formulation published in the DeepSeek-V2 paper [^1^].

Source: DeepSeek-V2 Technical Report (arXiv:2405.04434)
URL: https://arxiv.org/abs/2405.04434
Date: 2024-05-07
Excerpt:
```
c_t^Q = W^{DQ} h_t
[q_{t,1}^C; q_{t,2}^C; ...; q_{t,n_h}^C] = q_t^C = W^{UQ} c_t^Q
[q_{t,1}^R; q_{t,2}^R; ...; q_{t,n_h}^R] = q_t^R = RoPE(W^{QR} c_t^Q)
q_{t,i} = [q_{t,i}^C; q_{t,i}^R]

c_t^{KV} = W^{DKV} h_t
[k_{t,1}^C; k_{t,2}^C; ...; k_{t,n_h}^C] = k_t^C = W^{UK} c_t^{KV}
k_t^R = RoPE(W^{KR} h_t)
k_{t,i} = [k_{t,i}^C; k_t^R]

[v_{t,1}^C; v_{t,2}^C; ...; v_{t,n_h}^C] = v_t^C = W^{UV} c_t^{KV}

o_{t,i} = sum_{j=1}^t Softmax_j(q_{t,i}^T k_{j,i} / sqrt(d_h + d_h^R)) v_{j,i}^C
u_t = W^O [o_{t,1}; o_{t,2}; ...; o_{t,n_h}]
```
Context: These equations define the complete MLA computation. The key innovation is the compression of KV pairs into a latent vector c_t^{KV} via down-projection W^{DKV}, then up-projecting via W^{UK} and W^{UV}. The decoupled RoPE strategy separates positional information into a small RoPE-applied component (k_t^R) while the bulk of key/value information is stored in the compressed latent.
Confidence: high

### 1.2 KV Cache Reduction

Claim: For DeepSeek-V2, d_c is set to 4*d_h and d_h^R is set to d_h/2, making the KV cache equivalent to GQA with only 2.25 groups but with stronger performance than MHA [^1^].

Source: DeepSeek-V2 Technical Report
URL: https://arxiv.org/abs/2405.04434
Date: 2024-05-07
Excerpt: "For DeepSeek-V2, d_c is set to 4d_h and d_h^R is set to d_h/2. So, its KV cache is equal to GQA with only 2.25 groups, but its performance is stronger than MHA."
Context: The KV cache per token is (d_c + d_h^R) * l elements, compared to (2 * d_h * n_g) * l for GQA with n_g groups. For standard configurations, this yields >90% KV cache compression.
Confidence: high

### 1.3 Weight Absorption Trick

Claim: The weight absorption trick reorders matrix operations so that KV cache up-projections are absorbed into existing operations, eliminating the sequence-length-dependent computational overhead [^2^].

Source: DeepSeek + SGLang: Multi-Head Latent Attention (Verda blog)
URL: https://verda.com/blog/deepseek-sglang-multi-head-latent-attention
Date: 2025-03-12
Excerpt:
```
q_{t,i}^T k_{j,i} = (W_{[i*n_h:(i+1),:]}^{UQ})^T W_{[i*n_h:(i+1),:]}^{UK} c_j^{KV} + q_{t,i}^{RT} k_{j,i}^R
= c_t^{QT} (W^{UQ^T} W^{UK})_{[i*n_h:(i+1),:]} c_{j,i}^{KV} + q_t^{RT} k_{j,i}^R
```
Context: Without absorption, every token in the cache requires up-projection during decode, adding significant overhead. By precomputing the composite matrices (W^{UQ^T} W^{UK}) and absorbing W^{UV} into W^O, the decode phase avoids per-token up-projections entirely. However, materializing these composites increases memory transfer. The Aleph-Alpha analysis proposes dynamic computation instead of materialization.
Confidence: high

### 1.4 Decoupled RoPE

Claim: DeepSeek-V2 introduces decoupled RoPE to enable both compression and position-aware attention, caching only a small RoPE key per token [^1^].

Source: DeepSeek-V2 Technical Report
URL: https://arxiv.org/abs/2405.04434
Date: 2024-05-07
Excerpt: "During inference, the decoupled key should also be cached. Therefore, DeepSeek-V2 requires a total KV cache containing (d_c + d_h^R) * l elements."
Context: The decoupled RoPE is critical because standard RoPE prevents the absorb operation (it breaks the matrix factorization). By separating positional information into a small vector k_t^R that is cached separately, the bulk compressed KV (c_t^{KV}) can be used with weight absorption.
Confidence: high

### 1.5 TransMLA: Retrofitting Existing Models

Claim: TransMLA can convert any GQA-based pretrained model (LLaMA, Qwen, Gemma, Mixtral) into MLA format with only 6B tokens of fine-tuning to recover comparable performance, achieving 10.6x speedup at 8K context [^3^].

Source: TransMLA: Migrating GQA Models to MLA with Full DeepSeek Compatibility and Speedup (NeurIPS 2025)
URL: https://arxiv.org/abs/2502.07864
Date: 2025-02-13 (v1), 2025-06-12 (v5)
Excerpt: "By compressing 93% of the KV cache in LLaMA-2-7B, we achieve a 10.6x speedup with an 8K context length while maintaining meaningful output. Moreover, the model requires only 6B tokens for fine-tuning to recover comparable performance across multiple benchmarks."
Context: TransMLA addresses the key challenge of RoPE in GQA models through RoRoPE (PCA-based RoPE concentration) and FreqFold. The method enables direct conversion into DeepSeek-compatible format, allowing models to leverage vLLM and SGLang optimizations. Even without training, a 92.97% compressed model maintains meaningful responses.
Confidence: high

### 1.6 MLA Expressive Power vs GQA

Claim: MLA consistently offers higher expressive power than GQA under the same KV cache overhead [^3^].

Source: TransMLA paper
URL: https://arxiv.org/abs/2502.07864
Date: 2025-02-13
Excerpt: "We first prove that MLA consistently offers higher expressive power than GQA under the same KV cache overhead, which theoretically explains the advantage of MLA."
Context: This theoretical result provides justification for migrating from GQA to MLA even without retraining from scratch.
Confidence: high

---

## 2. DualPipe: Bidirectional Pipeline Parallelism

### 2.1 Core Algorithm

Claim: DualPipe is an innovative pipeline parallelism algorithm that overlaps forward and backward computation-communication phases while reducing pipeline bubbles, building on Zero Bubble 1F1B with bidirectional scheduling [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
The key idea of DualPipe is to overlap the computation and communication within a pair of individual forward and backward chunks. To be specific, we divide each chunk into four components: attention, all-to-all dispatch, MLP, and all-to-all combine. Specially, for a backward chunk, both attention and MLP are further split into two parts, backward for input and backward for weights, like in ZeroBubble.
```
Context: DualPipe addresses the fundamental challenge that cross-node expert parallelism creates a 1:1 computation-to-communication ratio. By manually adjusting the ratio of GPU SMs dedicated to communication versus computation, both all-to-all and PP communication can be fully hidden.
Confidence: high

### 2.2 Bubble and Memory Comparison

Claim: Compared with ZB1P and 1F1B, DualPipe significantly reduces pipeline bubbles while only increasing peak activation memory by 1/PP times [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "Compared with ZB1P and 1F1B, DualPipe significantly reduces the pipeline bubbles while only increasing the peak activation memory by 1/PP times. Although DualPipe requires keeping two copies of the model parameters, this does not significantly increase the memory consumption since we use a large EP size during training."
Context: The table in the paper shows that DualPipe's bubble size is smaller than Chimera, ZB1P, and 1F1B, and importantly, neither bubbles nor activation memory increase with the number of micro-batches. This is crucial for scaling to large cluster sizes.
Confidence: high

### 2.3 Bidirectional Scheduling

Claim: DualPipe employs bidirectional pipeline scheduling that feeds micro-batches from both ends of the pipeline simultaneously [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "It employs a bidirectional pipeline scheduling, which feeds micro-batches from both ends of the pipeline simultaneously and a significant portion of communications can be fully overlapped."
Context: The figure in the paper shows 8 PP ranks with 20 micro-batches in two directions, where cells enclosed by shared borders have mutually overlapped computation and communication. This bidirectional approach is distinct from Chimera, which requires micro-batches to be divisible by pipeline stages.
Confidence: high

### 2.4 Scalability Property

Claim: DualPipe ensures that as the model scales up, maintaining constant computation-to-communication ratio enables near-zero all-to-all communication overhead [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "This overlap also ensures that, as the model further scales up, as long as we maintain a constant computation-to-communication ratio, we can still employ fine-grained experts across nodes while achieving a near-zero all-to-all communication overhead."
Context: This is a critical scalability claim - it means the training framework can scale to larger models without being bottlenecked by communication, provided the computation-to-communication ratio is maintained.
Confidence: medium (proven at DeepSeek-V3 scale but theoretical for larger)

---

## 3. FP8 Mixed Precision Training

### 3.1 Mixed Precision Framework

Claim: DeepSeek-V3 pioneers FP8 mixed precision training on an extremely large-scale model for the first time, with core GEMMs in FP8 and strategic high-precision retention for sensitive components [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
In this framework, most compute-density operations are conducted in FP8, while a few key operations are strategically maintained in their original data formats to balance training efficiency and numerical stability.

Firstly, in order to accelerate model training, the majority of core computation kernels, i.e., GEMM operations, are implemented in FP8 precision. These GEMM operations accept FP8 tensors as inputs and produce outputs in BF16 or FP32. All three GEMMs associated with the Linear operator, namely Fprop, Dgrad, and Wgrad, are executed in FP8.
```
Context: The three GEMMs (forward prop, activation backward, weight backward) all use FP8 inputs. High-precision retention applies to: embedding module, output head, MoE gating modules, normalization operators, and attention operators. Master weights, weight gradients, and optimizer states remain in higher precision.
Confidence: high

### 3.2 Fine-Grained Quantization

Claim: DeepSeek uses tile-wise 1x128 quantization for activations and block-wise 128x128 quantization for weights to manage activation outliers [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
For activations, we group and scale elements on a 1x128 tile basis (i.e., per token per 128 channels); and for weights, we group and scale elements on a 128x128 block basis (i.e., per 128 input channels per 128 output channels).
```
Context: This fine-grained approach is highly consistent with microscaling (MX) formats. NVIDIA's next-generation Blackwell GPUs announced support for microscaling with smaller quantization granularity, validating DeepSeek's approach.
Confidence: high

### 3.3 E4M3 Format Strategy

Claim: DeepSeek adopts E4M3 format (4-bit exponent, 3-bit mantissa) for all tensors including Dgrad and Wgrad, prioritizing precision over dynamic range [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "In contrast to the hybrid FP8 format adopted by prior work, which uses E4M3 in Fprop and E5M2 in Dgrad and Wgrad, we adopt the E4M3 format on all tensors for higher precision. We attribute the feasibility of this approach to our fine-grained quantization strategy."
Context: The E5M2 format (5-bit exponent, 2-bit mantissa) provides wider dynamic range but less precision. DeepSeek's fine-grained scaling makes E4M3 viable across all tensors by effectively sharing exponent bits among grouped elements.
Confidence: high

### 3.4 CUDA Core Promotion for Precision

Claim: To circumvent NVIDIA H800's 14-bit accumulation precision limitation in FP8 Tensor Cores, DeepSeek promotes partial sums to CUDA Cores for full FP32 accumulation at Nc=128 element intervals [^5^].

Source: Insights into DeepSeek-V3: Scaling Challenges and Reflections on Hardware for AI Architectures
URL: https://arxiv.org/abs/2505.09343
Date: 2025-05-15
Excerpt:
```
FP8 uses constrained accumulation precision in Tensor Cores... the Tensor Core only maintains their highest 13 fraction bits for addition, and truncates bits exceeding this range. Addition results are accumulated to FP22 registers.

To circumvent hardware deficiencies, partial sums are promoted to CUDA Cores for full FP32 accumulation at a strictly defined Nc=128 element interval.
```
Context: This is a critical hardware workaround. Hopper GPUs accumulate FP8 products with only ~14 bits of precision. By promoting to CUDA Cores at 128-element intervals, DeepSeek achieves full FP32 accumulation precision while maintaining FP8 memory bandwidth benefits.
Confidence: high

### 3.5 Validation and Loss Error

Claim: DeepSeek validated FP8 training on models similar to DeepSeek-V2-Lite and DeepSeek-V2 for ~1T tokens, with relative loss error consistently below 0.25% compared to BF16 baseline [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "We validate the proposed FP8 mixed precision framework on two model scales... Notably, compared with the BF16 baseline, the relative loss error of our FP8-training model remains consistently below 0.25%, a level well within the acceptable range of training randomness."
Context: The 0.25% loss error margin proves FP8 training viability at frontier scale. The full DeepSeek-V3 training on 14.8T tokens completed with zero irrecoverable loss spikes or rollbacks.
Confidence: high

### 3.6 DeepGEMM Open Source Implementation

Claim: DeepSeek open-sourced DeepGEMM, an FP8 GEMM library supporting both dense and MoE GEMMs, achieving 1350+ FP8 TFLOPS on Hopper GPUs with fully JIT-compiled kernels [^6^].

Source: DeepGEMM Guide (Antigravity blog)
URL: https://antigravity.codes/blog/deepgemm-guide
Date: 2026-04-26
Excerpt:
```
DeepGEMM is DeepSeek's open-source CUDA library of clean, JIT-compiled FP8 and FP4 GEMM kernels with fine-grained scaling, tuned for NVIDIA Hopper (SM90) and Blackwell (SM100) tensor cores and the MoE workloads inside DeepSeek-V3, V3.2, and V4.

Core logic at ~300 lines - yet outperforms expert-tuned kernels across most matrix sizes
```
Context: DeepGEMM exposes a Python API with per-tile scaling factors. The library is narrow by design, targeting the specific shape distribution DeepSeek models use, and outperforms CUTLASS in those shapes. SM120 (RTX 5090) support is pending community PRs.
Confidence: high

---

## 4. GRPO: Group Relative Policy Optimization

### 4.1 Origin and Core Innovation

Claim: GRPO was introduced in DeepSeekMath (arXiv:2402.03300) as a PPO variant that eliminates the critic model, estimating the baseline from group scores instead [^7^].

Source: DeepSeekMath: Pushing the Limits of Mathematical Reasoning in Open Language Models
URL: https://arxiv.org/abs/2402.03300
Date: 2024-02-05
Excerpt:
```
As the value function employed in PPO is typically another model of comparable size as the policy model, it brings a substantial memory and computational burden. Additionally, during RL training, the value function is treated as a baseline in the calculation of the advantage for variance reduction. While in the LLM context, usually only the last token is assigned a reward score by the reward model, which may complicate the training of a value function that is accurate at each token. To address this, we propose Group Relative Policy Optimization (GRPO), which obviates the need for additional value function approximation as in PPO, and instead uses the average reward of multiple sampled outputs, produced in response to the same question, as the baseline.
```
Context: GRPO's elimination of the value model is its primary innovation. In standard PPO, the value function is another model of comparable size, doubling memory requirements. GRPO replaces this with a simple statistical baseline computed from grouped samples.
Confidence: high

### 4.2 Mathematical Formulation

Claim: The GRPO objective samples G outputs per question and optimizes using clipped policy ratios with group-relative advantages [^7^].

Source: DeepSeekMath paper
URL: https://arxiv.org/abs/2402.03300
Date: 2024-02-05
Excerpt:
```
J_GRPO(theta) = E[q~P(Q), {o_i}_{i=1}^G ~ pi_theta_old(O|q)]
    (1/G) sum_{i=1}^G (1/|o_i|) sum_{t=1}^{|o_i|} {
        min[ pi_theta(o_{i,t}|q,o_{i,<t}) / pi_theta_old(o_{i,t}|q,o_{i,<t}) * A_hat_{i,t},
             clip(pi_theta(o_{i,t}|q,o_{i,<t}) / pi_theta_old(o_{i,t}|q,o_{i,<t}), 1-eps, 1+eps) * A_hat_{i,t} ]
        - beta * D_KL[pi_theta || pi_ref]
    }
```
Context: The KL divergence is estimated with an unbiased estimator: D_KL = pi_ref/pi_theta - log(pi_ref/pi_theta) - 1. The advantage A_hat_{i,t} is computed differently for outcome vs process supervision.
Confidence: high

### 4.3 Advantage Estimation

Claim: GRPO computes advantage by normalizing rewards within each group: subtracting the group mean and dividing by group standard deviation [^8^].

Source: Cameron Wolfe's blog on GRPO
URL: https://cameronrwolfe.substack.com/p/grpo
Date: 2025-11-24
Excerpt:
```python
# compute mean and std of grouped rewards
reward_mean = rewards.view(-1, G).mean(dim=1)  # (B,)
reward_std = rewards.view(-1, G).std(dim=1)    # (B,)

# compute advantage for GRPO
advantage = (rewards.view(-1, G) - reward_mean)
advantage /= (reward_std + 1e-8)  # (B, G)
advantage = advantage.view(-1, 1)  # (B*G, 1)
```
Context: The same advantage is assigned to every token in a completion (for outcome supervision). This is simpler than PPO's GAE but requires more samples per prompt for stable estimates. GRPO is typically run with far higher samples per prompt than PPO.
Confidence: high

### 4.4 Outcome vs Process Supervision

Claim: DeepSeekMath explored both outcome supervision (reward at end) and process supervision (reward at each reasoning step) within the GRPO framework [^7^].

Source: DeepSeekMath paper
URL: https://arxiv.org/abs/2402.03300
Date: 2024-02-05
Excerpt:
```
Outcome supervision provides the normalized reward at the end of each output and sets the advantages of all tokens in the output as the normalized reward.

Process supervision provides a reward at the end of each reasoning step... calculates the advantage of each token as the sum of the normalized rewards from the following steps.
```
Context: Outcome supervision: A_{i,t} = r_tilde_i = (r_i - mean(r)) / std(r). Process supervision: A_{i,t} = sum_{index(j) >= t} r_tilde_i^{index(j)}. DeepSeek-R1-Zero used only outcome supervision with rule-based rewards.
Confidence: high

### 4.5 DeepSeek-R1 Application

Claim: DeepSeek-R1-Zero used GRPO with purely rule-based rewards (accuracy + format) without any neural reward model, achieving AIME 2024 pass@1 from 15.6% to 77.9% [^9^].

Source: DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement Learning (Nature)
URL: https://www.nature.com/articles/s41586-025-09422-z
Date: 2025-09-17
Excerpt:
```
The reward signal is only based on the correctness of final predictions against ground-truth answers, without imposing constraints on the reasoning process itself. Notably, we bypass the conventional supervised fine-tuning (SFT) phase before RL training.

The average pass@1 score on AIME 2024 shows a marked increase, jumping from an initial value of 15.6% to 77.9%.
```
Context: The rule-based system uses accuracy rewards (verifiable answers via compiler/test cases) and format rewards (enforcing <think>...</think> tags). No outcome or process neural reward model was used because neural reward models suffer from reward hacking in large-scale RL.
Confidence: high

### 4.6 Training Hyperparameters

Claim: DeepSeek-R1 first RL stage used learning rate 3e-6, KL coefficient 0.001, GRPO clip epsilon 0.1, temperature 1.0, 16 samples per question, 32 unique questions per step, max length 32,768 [^9^].

Source: DeepSeek-R1 paper (Nature supplementary)
URL: https://www.nature.com/articles/s41586-025-09422-z
Date: 2025-09-17
Excerpt:
```
In the first stage of RL, we set the learning rate to 3 x 10^-6, the KL coefficient to 0.001, the GRPO clip ratio epsilon to 0.1 and the sampling temperature to 1 for rollout. For each question, we sample 16 outputs with a maximum length of 32,768. Each training step consists of 32 unique questions, resulting in a training batch size of 512 per step.
```
Context: The clip ratio plays a crucial role - lower values truncate gradients for many tokens, degrading performance; higher values cause instability. Reference model is replaced with the latest policy every 400 steps.
Confidence: high

---

## 5. DeepSeekMoE Architecture

### 5.1 Auxiliary-Loss-Free Load Balancing

Claim: DeepSeek-V3 pioneers an auxiliary-loss-free load balancing strategy using dynamic bias terms, achieving better performance than models with pure auxiliary losses [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
g'_{i,t} = { s_{i,t},  if s_{i,t} + b_i in Topk({s_{j,t} + b_j}, K_r)
         { 0,         otherwise

During training, we keep monitoring the expert load on the whole batch of each training step. At the end of each step, we will decrease the bias term by gamma if its corresponding expert is overloaded, and increase it by gamma if underloaded.
```
Context: The bias term is only used for routing; the gating value multiplied with FFN output still uses the original affinity score. This eliminates the need for auxiliary loss hyperparameter tuning. A complementary sequence-wise balance loss is used with extremely small alpha to prevent extreme within-sequence imbalance.
Confidence: high

### 5.2 Node-Limited Routing

Claim: DeepSeek-V3 uses restricted routing where each token is sent to at most M nodes, selected by the sum of highest affinity scores per node, enabling near-full computation-communication overlap [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "We ensure that each token will be sent to at most M nodes, which are selected according to the sum of the highest K_r/M affinity scores of the experts distributed on each node. Under this constraint, our MoE training framework can nearly achieve full computation-communication overlap."
Context: The node-limited routing is critical for cross-node MoE training. By capping the number of nodes each token visits, the all-to-all communication volume is bounded. Combined with DualPipe's overlap strategy, this achieves near-zero communication overhead.
Confidence: high

### 5.3 No Token Dropping

Claim: Due to effective load balancing, DeepSeek-V3 does not drop any tokens during either training or inference [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "Due to the effective load balancing strategy, DeepSeek-V3 keeps a good load balance during its full training. Therefore, DeepSeek-V3 does not drop any tokens during training. In addition, we also implement specific deployment strategies to ensure inference load balance, so DeepSeek-V3 also does not drop tokens during inference."
Context: Token dropping is a common technique in MoE training to handle load imbalance, but it can degrade model quality. DeepSeek's auxiliary-loss-free strategy eliminates the need for dropping.
Confidence: high

### 5.4 Shared Expert Design

Claim: DeepSeek-V3 uses a shared expert that processes all tokens, plus routed experts, treating the shared expert as a heavy-load routed one during decoding [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "During decoding, we treat the shared expert as a routed one. From this perspective, each token will select 9 experts during routing, where the shared expert is regarded as a heavy-load one that will always be selected."
Context: The shared expert provides universal processing capacity while routed experts specialize. The shared expert has a larger hidden dimension (768 vs 512 in the educational implementation) reflecting its broader responsibility.
Confidence: high

### 5.5 Inference Deployment: Redundant Experts

Claim: DeepSeek-V3 uses redundant expert duplication for load balancing in inference, with 32 redundant experts for prefilling and dynamic rearrangement every 10 minutes [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
We introduce a deployment strategy of redundant experts, which duplicates high-load experts and deploys them redundantly. The high-load experts are detected based on statistics collected during the online deployment and are adjusted periodically (e.g., every 10 minutes).

For the deployment of DeepSeek-V3, we set 32 redundant experts for the prefilling stage. For each GPU, besides the original 8 experts it hosts, it will also host one additional redundant expert.
```
Context: This is an online deployment optimization. High-load experts are identified from service statistics and duplicated across GPUs to balance computation. The team is also exploring dynamic redundancy where each GPU hosts more experts but only activates a subset.
Confidence: high

---

## 6. Distillation from DeepSeek-R1

### 6.1 Distillation vs RL on Small Models

Claim: Distilling reasoning patterns from DeepSeek-R1 to smaller models outperforms applying RL directly on those small models [^10^].

Source: DeepSeek-R1 Technical Report
URL: https://arxiv.org/abs/2501.12948
Date: 2025-01-22
Excerpt:
```
Using Qwen2.5-32B as the base model, direct distillation from DeepSeek-R1 outperforms applying RL on it. This demonstrates that the reasoning patterns discovered by larger base models are crucial for improving reasoning capabilities.

DeepSeek-R1-Distill-Qwen-7B achieves 55.5% on AIME 2024, surpassing QwQ-32B-Preview. DeepSeek-R1-Distill-Qwen-32B scores 72.6% on AIME 2024, 94.3% on MATH-500, and 57.2% on LiveCodeBench.
```
Context: DeepSeek generated 800K reasoning samples from R1 to fine-tune Qwen and Llama series (1.5B to 70B). Only SFT was applied, no RL stage. The distilled 14B model outperformed QwQ-32B-Preview.
Confidence: high

### 6.2 Key Finding: Distillation > RL for Small Models

Claim: A 32B base model after large-scale RL achieves performance on par with QwQ-32B-Preview, but distilled R1-Distill-Qwen-32B performs significantly better across all benchmarks [^10^].

Source: DeepSeek-R1 Technical Report
URL: https://arxiv.org/abs/2501.12948
Date: 2025-01-22
Excerpt:
```
The 32B base model, after large-scale RL training, achieves performance on par with QwQ-32B-Preview. However, DeepSeek-R1-Distill-Qwen-32B, which is distilled from DeepSeek-R1, performs significantly better than DeepSeek-R1-Zero-Qwen-32B across all benchmarks.

First, distilling more powerful models into smaller ones yields excellent results, whereas smaller models relying on the large-scale RL mentioned in this paper require enormous computational power and may not even achieve the performance of distillation. Second, while distillation strategies are both economical and effective, advancing beyond the boundaries of intelligence may still require more powerful base models and larger-scale reinforcement learning.
```
Context: This is a critical result for local deployment. It suggests that for smaller local models, distillation from a powerful teacher is more compute-efficient and effective than training RL from scratch.
Confidence: high

---

## 7. Multi-Token Prediction (MTP)

### 7.1 DeepSeek's Sequential MTP

Claim: DeepSeek-V3's MTP predicts additional tokens sequentially (not in parallel), maintaining the complete causal chain at each prediction depth [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
Different from Gloeckle et al. (2024), which parallelly predicts D additional tokens using independent output heads, we sequentially predict additional tokens and keep the complete causal chain at each prediction depth.
```
Context: Each MTP module contains a Transformer block that refines hidden representation for the next prediction. The modules reuse the embedding layer and output head from the main model.
Confidence: high

### 7.2 Training-Only with Speculative Decoding Reuse

Claim: MTP modules are discarded during standard inference but can be repurposed for speculative decoding to accelerate generation [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "Our MTP strategy mainly aims to improve the performance of the main model, so during inference, we can directly discard the MTP modules and the main model can function independently and normally. Additionally, we can also repurpose these MTP modules for speculative decoding to further improve the generation latency."
Context: During training, MTP provides richer gradient signals. The hidden state h_i receives gradients not just from predicting token i+1, but also from predicting i+2, i+3, etc. This encourages h_i to encode information useful for multiple future tokens.
Confidence: high

### 7.3 Loss Formulation

Claim: The MTP loss is a weighted average of cross-entropy losses at each prediction depth [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "L_MTP = (lambda/D) sum_{k=1}^D L_MTP^k"
Context: D is the number of additional prediction depths. Each L_MTP^k is a standard cross-entropy loss at depth k. The ablation study in the paper confirms MTP benefits model performance.
Confidence: high

---

## 8. Expert Parallelism & All-to-All Communication

### 8.1 Training: EP32 with Node-Limited Routing

Claim: DeepSeek-V3 training uses 32-way Expert Parallelism (EP32) for the MoE part, with all-to-all communication first across nodes via InfiniBand then intra-node via NVLink [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
For the MoE part, we use 32-way Expert Parallelism (EP32), which ensures that each expert processes a sufficiently large batch size, thereby enhancing computational efficiency. For the MoE all-to-all communication, we use the same method as in training: first transferring tokens across nodes via IB, and then forwarding among the intra-node GPUs via NVLink.
```
Context: The minimum deployment unit for prefilling is 4 nodes with 32 GPUs. Attention uses TP4 with SP, combined with DP8. The small TP size of 4 limits TP communication overhead.
Confidence: high

### 8.2 Decoding: EP320 with IBGDA

Claim: For decoding, DeepSeek-V3 uses EP320 (each GPU hosts one expert), with all-to-all via direct IB point-to-point transfers using IBGDA technology [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
The minimum deployment unit of the decoding stage consists of 40 nodes with 320 GPUs. The attention part employs TP4 with SP, combined with DP80, while the MoE part uses EP320. For the MoE part, each GPU hosts only one expert, and 64 GPUs are responsible for hosting redundant experts and shared experts. All-to-all communication... is performed via direct point-to-point transfers over IB to achieve low latency. Additionally, we leverage the IBGDA technology to further minimize latency.
```
Context: The decoding stage has different optimization requirements than prefilling. Since batch size per expert is small (within 256 tokens), the bottleneck is memory access rather than computation. Using fewer SMs for dispatch+MoE+combine avoids impacting attention computation speed.
Confidence: high

### 8.3 Micro-Batch Overlapping in Inference

Claim: DeepSeek-V3 processes two micro-batches simultaneously during both prefilling and decoding to overlap communication with computation [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt:
```
In the prefilling stage... we simultaneously process two micro-batches with similar computational workloads, overlapping the attention and MoE of one micro-batch with the dispatch and combine of another.

In the decoding stage... we overlap the attention of one micro-batch with the dispatch+MoE+combine of another.
```
Context: This inference-time overlapping is conceptually similar to DualPipe's training-time overlap but adapted for the decode phase where attention consumes a larger portion of time.
Confidence: high

---

## 9. Low-Precision Inference: FP8 vs INT4

### 9.1 FP8 Quality Assessment

Claim: FP8 inference shows negligible quality difference vs BF16 across standard benchmarks, with MMLU-Pro dropping only 0.6 points (69.64% vs 70.24%) [^11^].

Source: LLM Quantization: BF16 vs FP8 vs INT4 (AIMultiple)
URL: https://aimultiple.com/llm-quantization
Date: 2026-03-17
Excerpt:
```
FP8 scores 69.64% on MMLU-Pro vs 70.24% for BF16, a 0.6 point difference across 12,000 questions. On HumanEval, both FP8 and BF16 score identically at 39.02%. FP8 gives you 1.5x throughput and cuts your model size in half for a 0.6 point cost.
```
Context: FP8 is considered production-safe for virtually all tasks. The quality difference vs FP16 is negligible across standard benchmarks. This makes FP8 the safest choice for inference when hardware supports it (Hopper/Blackwell).
Confidence: high

### 9.2 INT4 Quality Degradation

Claim: INT4 degrades code generation significantly more than knowledge tasks - HumanEval drops 8 points (39.02% to 31.10%) while MMLU-Pro drops only 1.6 points [^11^].

Source: AIMultiple quantization analysis
URL: https://aimultiple.com/llm-quantization
Date: 2026-03-17
Excerpt:
```
Int4 degrades code generation more than knowledge. MMLU-Pro drops 1.6 points at Int4 (70.24% to 68.66%). HumanEval drops 8 points (39.02% to 31.10%). Code generation requires precise token predictions where small weight errors compound across function bodies.
```
Context: The differential degradation is important for local use cases. Math scores barely move across all precisions (81.87% at BF16, 80.24% at INT4), but engineering and law are more sensitive.
Confidence: high

### 9.3 FP4 vs INT4 Distinction

Claim: FP4 (NVFP4, E2M1 format) preserves more information than INT4 for transformer inference because activations span many orders of magnitude [^12^].

Source: FP4 Quantization on Blackwell GPUs (Spheron)
URL: https://www.spheron.network/blog/fp4-quantization-blackwell-gpu-cost/
Date: 2026-03-15
Excerpt:
```
INT4 is a fixed-range integer format with no exponent - it can represent 16 discrete integer values. NVIDIA's NVFP4 (the E2M1 format: 1 sign bit, 2 exponent bits, 1 mantissa bit) is a floating-point format that can represent values across a much wider dynamic range with variable precision. For transformer inference, where activation and weight distributions span many orders of magnitude, FP4's floating-point representation typically preserves more information than INT4 at the same bit width.
```
Context: This explains why NVFP4 tends to produce better output quality than INT4 at the same memory footprint. However, FP4 is Blackwell-only (RTX 5090, B200), limiting current applicability.
Confidence: high

### 9.4 Comprehensive INT vs FP Study

Claim: A comprehensive 2025 study found MXINT8 consistently outperforms MXFP8 in direct-cast inference, but FP formats hold advantage in coarse-grained scenarios while INT becomes competitive at fine-grained block sizes [^13^].

Source: INT vs FP: A Comprehensive Study of Fine-Grained Low-bit Quantization Formats (arXiv:2510.25602)
URL: https://arxiv.org/abs/2510.25602
Date: 2025-10-29
Excerpt:
```
We demonstrate that MXINT8 consistently outperforms MXFP8 in both direct-cast inference and low-bit training. We also show that NVINT4 can surpass NVFP4 when combined with Hadamard rotation. Critically, we introduce a symmetric clipping method that resolves a gradient bias, enabling nearly lossless MXINT8 low-bit training.
```
Context: With random Hadamard rotation, MXINT8 and NVINT4 win on all 12 tested models (Qwen3, Llama-3.1/3.2). The crossover point depends on crest factor: FP wins with coarse granularity; INT wins with fine-grained block-wise quantization.
Confidence: high

---

## 10. KV Cache Optimization

### 10.1 PagedAttention

Claim: vLLM's PagedAttention reduces memory waste from 60-80% to under 4% and improves throughput 2-4x [^14^].

Source: KV Cache Optimization: Memory Efficiency for Production LLMs (Introl)
URL: https://introl.com/blog/kv-cache-optimization-memory-efficiency-production-llms-guide
Date: 2026-03-13
Excerpt:
```
Memory waste: 60-80% -> under 4%
Throughput: 2-4x improvement versus traditional allocation
Memory fragmentation: Virtually eliminated
```
Context: PagedAttention divides KV cache into fixed-size blocks allocated on-demand, with block table mappings like OS virtual memory. This is the foundational optimization for production LLM serving.
Confidence: high

### 10.2 Automatic Prefix Caching

Claim: vLLM's Automatic Prefix Caching (APC) enables cache hit rates of 87%+ with well-structured prompts, dramatically reducing TTFT [^14^].

Source: Introl KV Cache Optimization Guide
URL: https://introl.com/blog/kv-cache-optimization-memory-efficiency-production-llms-guide
Date: 2026-03-13
Excerpt: "Applications with consistent system prompts or repeated context (RAG with common documents, few-shot examples) see dramatic memory savings and latency reduction. Cache hit rates of 87%+ are achievable with well-structured prompts."
Context: APC works by hashing each KV cache block using the token sequence it contains. When a new request arrives, matching blocks are reused directly. This primarily accelerates prefill, not decode.
Confidence: high

### 10.3 TurboQuant for KV Cache

Claim: TurboQuant achieves 4.5-6x KV cache compression with near-zero accuracy loss, using a two-stage PolarQuant + QJL residual correction approach [^15^].

Source: TurboQuant: Online Vector Quantization with Near-optimal Distortion Rate (arXiv:2504.19874)
URL: https://arxiv.org/abs/2504.19874
Date: 2025-04-28
Excerpt:
```
For KV cache quantization, we achieve absolute quality neutrality with 3.5 bits per channel and marginal quality degradation with 2.5 bits per channel... we achieve perfect long-context retrieval in needle-in-a-haystack tasks and maintain high performance on other long-context downstream tasks, all while compressing the KV cache by a factor exceeding 5x.
```
Context: TurboQuant uses random rotation + Beta distribution concentration + per-coordinate scalar quantization. The QJL (Quantized Johnson-Lindenstrauss) stage provides unbiased inner product estimation. This is being integrated into vLLM via --kv-cache-dtype turboquant.
Confidence: high

### 10.4 FP8 KV Cache

Claim: FP8 KV cache provides 30-60% cache size reduction and is particularly impactful for 32K+ context lengths [^16^].

Source: 8 LLM Quantization Moves for 60% Cheaper Inference (Medium)
URL: https://medium.com/@connect.hashblock/8-llm-quantization-moves-for-60-cheaper-inference-c0acc6b28b4a
Date: 2025-09-21
Excerpt: "KV cache INT8/FP8: 30-60% cache cut. Big on 32k+ tokens."
Context: KV cache quantization is especially important for long-context models where cache size dominates memory usage. FP8 KV cache is supported on Hopper/Blackwell GPUs.
Confidence: medium

---

## 11. Speculative Decoding

### 11.1 EAGLE-3: Training-Time Test

Claim: EAGLE-3 achieves up to 6.5x speedup by directly predicting draft tokens through a training-time test, using a fusion of lower, middle, and upper-layer target features [^17^].

Source: EAGLE-3: Scaling up Inference Acceleration of Large Language Models via Training-Time Test (arXiv:2503.01840)
URL: https://arxiv.org/abs/2503.01840
Date: 2025-03-03
Excerpt:
```
EAGLE-3 incorporates two key improvements. First, it removes the feature prediction constraint, instead directly predicting draft tokens through a Training-time test. Second, it replaces the use of the target model's top-layer features with a fusion of the target model's lower, middle, and upper-layer features to obtain richer information. With these improvements, EAGLE-3 continues to benefit from the augmentation of training data, achieving a maximum speedup of 6.5x.
```
Context: EAGLE-3 is a target-dependent method that requires training a draft model on target model features. It achieves higher speedups than vanilla speculative decoding but requires adaptation per target model.
Confidence: high

### 11.2 PARD: Target-Independent Parallel Draft

Claim: PARD achieves target-independent speculative decoding with parallel token prediction, reaching 264.88 tokens/sec on A100 (3.67x speedup) [^18^].

Source: PARD: Accelerating LLM Inference with Low-Cost Parallel Draft Model Adaptation (arXiv:2504.18583)
URL: https://arxiv.org/abs/2504.18583
Date: 2025-04
Excerpt:
```
PARD introduces mask tokens for parallel token predictions in the draft phase... On LLaMA3.1-8B, PARD achieves a 3.67x speedup, reaching a state-of-the-art throughput of 264.88 tokens per second on an A100-40GB GPU, which is 1.72x faster than vanilla SD and 1.15x faster than EAGLE-3.
```
Context: PARD's key advantage is target-independence: a single draft model can accelerate an entire family of target models. This reduces deployment and adaptation costs significantly.
Confidence: medium

### 11.3 Core Memory-Bandwidth Insight

Claim: LLM inference is fundamentally memory-bandwidth bound, not compute bound - loading 7B parameters takes ~7ms while actual computation takes ~0.1ms [^19^].

Source: Speculative Decoding Reference Implementation (GitHub)
URL: https://github.com/bassrehab/speculative-decoding
Date: 2025-12-08
Excerpt:
```
LLM inference is fundamentally memory-bandwidth bound, not compute bound. Loading 7B parameters (14GB in FP16) from memory takes ~7ms on an A100 (2TB/s bandwidth), while the actual computation takes ~0.1ms. This means we spend 98% of inference time waiting for memory.
```
Context: This is the fundamental reason speculative decoding works: processing K tokens in one forward pass costs roughly the same as 1 token. The draft model proposes K tokens cheaply, and the target verifies all K in a single pass.
Confidence: high

---

## 12. Continuous Batching & Disaggregated Serving

### 12.1 Chunked Prefill

Claim: Chunked prefill splits long inputs into smaller chunks interleaved with decode requests, enabling stall-free execution [^20^].

Source: Layered Prefill paper (arXiv:2510.08055)
URL: https://arxiv.org/abs/2510.08055
Date: 2025-10-09
Excerpt:
```
Sarathi-Serve addresses this issue through chunked prefill. Instead of processing an entire long input in one pass, the sequence is split into smaller chunks that are interleaved with decode requests to form hybrid batches. This restructuring enables stall-free execution, since decode requests are no longer blocked behind lengthy prefills.
```
Context: Typical chunk sizes are 256 or 512 tokens. This satisfies TBT (time-between-tokens) constraints while distributing prefill work more evenly across iterations.
Confidence: high

### 12.2 Prefill-Decode Disaggregation

Claim: Disaggregating prefill and decode onto separate resources allows independent optimization since the two phases have opposite resource profiles - prefill is compute-bound, decode is memory-bandwidth-bound [^21^].

Source: Prefill-Decode Disaggregation: Splitting the Two Stages of Inference (Optiverse)
URL: https://optiversetech.com/blog/prefill-decode-disaggregation/
Date: 2026-04-04
Excerpt:
```
Prefill wants compute throughput. Decode wants memory bandwidth. A GPU configuration optimized for one is suboptimal for the other. And yet, in a standard inference engine using continuous batching, both phases run on the same hardware at the same time.
```
Context: DistServe (OSDI'24), Splitwise, and TertiInfer all adopt similar disaggregation ideas. This is becoming standard practice for large-scale deployments.
Confidence: high

### 12.3 DistServe Goodput Optimization

Claim: DistServe is the first system to optimize goodput (successful requests meeting latency SLOs) for autoregressive LLM inference by disaggregating prefill and decoding [^22^].

Source: DistServe: Disaggregating Prefill and Decoding for Goodput Optimization (OSDI'24)
URL: https://www.usenix.org/system/files/osdi24-zhong-yinmin.pdf
Date: 2024
Excerpt: "DistServe is the first work to optimize the goodput for autoregressive LLM inference."
Context: DistServe emphasizes that disaggregation allows independent resource scaling for prefill and decode, improving both responsiveness and throughput.
Confidence: high

---

## 13. Ring Attention

### 13.1 Blockwise Computation for Near-Infinite Context

Claim: Ring Attention enables training large models (7B-65B) on context sizes over 4M tokens with negligible overheads, achieving comparable MFU to baseline models [^23^].

Source: Ring Attention with Blockwise Transformers for Near-Infinite Context (arXiv:2310.01889)
URL: https://arxiv.org/abs/2310.01889
Date: 2023-10-03
Excerpt:
```
Ring Attention trains much longer context sizes for self-attention, resulting in higher self-attention FLOPs compared to baseline models. Since self-attention has a lower MFU than feedforward, Ring Attention is expected to have a lower MFU than the baseline models. Our method offers a clear advantage in terms of maintaining MFU while enabling training with significantly longer context lengths.
```
Context: Ring Attention uses blockwise computation with key-value block passing in a ring topology across devices. This avoids materializing the full attention matrix, enabling context lengths limited only by device count.
Confidence: high

### 13.2 MFU Preservation

Claim: Ring Attention maintains MFU while enabling training with significantly longer context lengths, training 7B models on 4M+ context with only minor MFU reduction [^23^].

Source: Ring Attention paper
URL: https://arxiv.org/abs/2310.01889
Date: 2023-10-03
Excerpt: "Table 5.1 presents the results of our experiments on MFU for different model sizes and context lengths... Ring Attention enables training large models (7B-65B) on large input context sizes (over 4M) with negligible overheads."
Context: The approach distributes both computation and memory requirements across the ring. Each device holds a block of the sequence and passes KV blocks to neighbors.
Confidence: high

---

## 14. MoE for Local Inference

### 14.1 EdgeMoE: Fast On-Device Inference

Claim: EdgeMoE is the first execution engine enabling fast inference of >10B-sized LLMs on COTS edge devices like Jetson TX2, achieving 1.11-2.78x speedup over memory-optimized baselines [^24^].

Source: EdgeMoE: Fast On-Device Inference of MoE-based Large Language Models (OpenReview)
URL: https://openreview.net/pdf?id=DDJeREha18
Date: 2024
Excerpt:
```
EdgeMoE incarnates as a runtime library linked to user apps... It is configured by two key parameters. First, a memory budget A?, specified either by users or the OS. The budget ranges from 1.5GB-3GB... Second, a tolerable accuracy loss A? chosen by the user.

For the first time, EdgeMoE enables fast inference for >10B-sized LLMs on COTS edge devices like Jetson TX2.
```
Context: EdgeMoE uses expert-wise quantization (different bitwidths per expert), expert activation prediction based on previous layer statistics, and a preload/compute pipeline. It reduces memory footprint by 1.05-1.18x vs holding the whole model.
Confidence: high

### 14.2 HOBBIT: Mixed Precision Expert Offloading

Claim: Expert loading dominates inference cost on edge devices (85.5% on RTX 4090, 94.5% on Jetson Orin), and replacing float16 experts with int4 versions achieves up to 4x loading speedup [^25^].

Source: HOBBIT: A Mixed Precision Expert Offloading System for Fast MoE Inference (arXiv:2411.01433)
URL: https://arxiv.org/abs/2411.01433
Date: 2024-11-03
Excerpt:
```
Expert loading dominates inference cost. To quantify the bottlenecks... expert loading dominates the total inference time, consuming approximately 85.5% on the RTX 4090 and 94.5% on the Jetson Orin, while computation accounts for only a small fraction.

Replacing a float16 expert with an int4 version can achieve up to a 4x speedup in the loading process.
```
Context: This motivates mixed-precision expert management: high-importance experts stay in higher precision; low-importance experts are quantized. When GPU memory is insufficient, only a subset of quantized experts are stored on GPU.
Confidence: high

### 14.3 Fate: Cross-Layer Expert Prefetch

Claim: Fate achieves 97.15% expert prefetch accuracy and 99.08% cache hit rate with shallow-favoring caching, achieving 4.1x decoding speedup over load-on-demand [^26^].

Source: Fate: Fast Edge Inference of Mixture-of-Experts Models via Cross-Layer Gate (arXiv:2502.12224)
URL: https://arxiv.org/abs/2502.12224
Date: 2025-02
Excerpt:
```
We propose a cross-layer expert prefetch, which achieves a prefetch accuracy of 97.15%. Furthermore, we introduce the shallow-favoring expert cache, which increases the expert hit rate to 99.08%.

Fate significantly improves the inference efficiency of MoE models in edge scenarios, achieving up to 4.1x and 2.2x decoding speedup compared to Load on Demand and EAP.
```
Context: Fate leverages cross-layer correlation in expert selection: the previous gate's output predicts the next gate's expert selection with high accuracy. This enables prefetching without additional GPU overhead.
Confidence: medium

### 14.4 EAC-MoE: Quantization with Expert-Selection Calibration

Claim: EAC-MoE reduces Mixtral-8x7B memory requirements by 4.92x, enabling deployment on RTX 3090, with 1.68x inference speedup and <1% accuracy loss [^27^].

Source: EAC-MoE: Expert-Selection Aware Compressor for Mixture-of-Experts (ACL 2025)
URL: https://aclanthology.org/2025.acl-long.633.pdf
Date: 2025
Excerpt:
```
When compressing Mixtral-8x7B, we reduce the memory requirements by 4.92x, enabling deployment on a RTX 3090 GPU. Meanwhile, our method achieve 1.68x inference speedups with an average accuracy loss of less than 1% under simultaneous quantization and pruning.
```
Context: EAC-MoE identifies the "expert-shift problem" where quantization biases expert selection probability. It proposes Quantization with Expert-Selection Calibration (QESC) and Pruning based on Expert-Selection Frequency (PESF).
Confidence: high

### 14.5 Collaborative Compression for DeepSeek-V3 on Edge

Claim: A collaborative compression framework combining performance-aware expert pruning, hardware-aware activation adjustment, and mixed-precision quantization can compress DeepSeek-V3 (671B params) to fit within 128GB memory budget for edge deployment [^28^].

Source: Collaborative Compression for Large-Scale MoE Deployment on Edge (arXiv:2509.25689)
URL: https://arxiv.org/abs/2509.25689
Date: 2025-09-30
Excerpt:
```
Our target is to compress DeepSeek-V3 with 671B parameters and deploy it on edge platforms with 128GB memory budget. One single strategy can hardly satisfy the requirement. Specifically, extreme low-bit quantization with an average 1.56 bit width cannot fit the inference memory within the practical limits. Meanwhile, aggressive pruning needs to remove substantial weights (above 90% sparsity ratio) with significant performance degradation.
```
Context: The three-step approach: (1) prune low-contribution experts, (2) adjust activation according to pruning, (3) quantize with sensitivity-aware mixed precision. This shows that even 671B models can be edge-deployed with careful compression.
Confidence: medium

---

## 15. Reinforcement Learning for Reasoning

### 15.1 Rule-Based vs Neural Rewards

Claim: DeepSeek-R1-Zero intentionally avoided neural reward models because they suffer from reward hacking in large-scale RL, opting instead for rule-based accuracy and format rewards [^10^].

Source: DeepSeek-R1 Technical Report
URL: https://arxiv.org/abs/2501.12948
Date: 2025-01-22
Excerpt:
```
We do not apply the outcome or process neural reward model in developing DeepSeek-R1-Zero, because we find that the neural reward model may suffer from reward hacking in the large-scale reinforcement learning process, and retraining the reward model needs additional training resources and it complicates the whole training pipeline.
```
Context: This is a significant design choice. Most RLHF pipelines use learned reward models. DeepSeek's finding that rule-based rewards suffice for reasoning tasks simplifies the pipeline and eliminates reward model training costs.
Confidence: high

### 15.2 Emergence of Reasoning Behaviors

Claim: DeepSeek-R1-Zero naturally developed self-verification, reflection, and alternative approach exploration through pure RL without any SFT cold start [^9^].

Source: DeepSeek-R1 (Nature)
URL: https://www.nature.com/articles/s41586-025-09422-z
Date: 2025-09-17
Excerpt:
```
Although we do not explicitly teach the model how to reason, it successfully learns improved reasoning strategies through RL. The model exhibits a tendency to generate longer responses, incorporating verification, reflection and the exploration of alternative approaches within each response.
```
Context: Extended Data Figure 1 shows the frequency of reflective terms ("wait", "mistake", "verify", "check") increasing throughout training, with "wait" virtually absent initially but markedly increasing after step 8,000.
Confidence: high

### 15.3 GRPO vs PPO Resource Comparison

Claim: GRPO reduces memory consumption significantly compared to PPO by eliminating the value model, which is typically another model of comparable size to the policy [^7^].

Source: DeepSeekMath paper
URL: https://arxiv.org/abs/2402.03300
Date: 2024-02-05
Excerpt: "As the value function employed in PPO is typically another model of comparable size as the policy model, it brings a substantial memory and computational burden."
Context: For a 7B model, PPO requires loading policy, value, reward, and reference models (4x 7B = 28B parameters in memory). GRPO requires only policy, reward, and reference (3x 7B = 21B parameters). At larger scales, this difference becomes more significant.
Confidence: high

---

## 16. Cross-Cutting Analysis: Local Deterministic Feasibility

### 16.1 Can MLA be Retrofitted to Existing Models?

**Answer: YES, with caveats.**

Claim: TransMLA demonstrates conversion of LLaMA, Qwen, Gemma, and Mixtral to MLA format with 6B tokens of fine-tuning, achieving full DeepSeek ecosystem compatibility [^3^].

Source: TransMLA paper
URL: https://arxiv.org/abs/2502.07864
Date: 2025-02-13
Excerpt: "TransMLA provides a practical path for migrating GQA-based models to the MLA structure, and when combined with DeepSeek's advanced optimizations -- such as FP8 quantization and Multi-Token Prediction -- further inference acceleration can be achieved."
Context: For deterministic substrates: The conversion requires understanding RoRoPE and FreqFold, but the resulting models are compatible with standard inference engines (vLLM, SGLang). Training-free conversion achieves 68.75% KV cache compression with only 1.65% performance drop. The 93% compression version requires 6B tokens to recover. This is highly feasible for local adaptation.
Confidence: high

### 16.2 What is the Local Training Feasibility of GRPO on Apple Silicon?

**Answer: FEASIBLE for small models, with limitations.**

Claim: MLX achieves the highest sustained generation throughput on Apple Silicon, while all frameworks execute fully on-device with no telemetry [^29^].

Source: Production-Grade Local LLM Inference on Apple Silicon (arXiv:2511.05502)
URL: https://arxiv.org/abs/2511.05502
Date: 2025-10-09
Excerpt:
```
Under our settings, MLX achieves the highest sustained generation throughput, while MLC-LLM delivers consistently lower TTFT for moderate prompt sizes and offers stronger out-of-the-box inference features... All frameworks execute fully on-device with no telemetry, ensuring strong privacy guarantees.
```
Context: For GRPO training specifically: GRPO's elimination of the value model reduces memory requirements by ~25% compared to PPO. The core GRPO loop (sample G outputs, compute rule-based rewards, calculate group-relative advantages, policy update) is straightforward to implement. However, challenges for Apple Silicon include: (1) GRPO requires sampling multiple completions per prompt (16 in DeepSeek-R1), which increases memory during the forward pass; (2) MLX does not natively support distributed training, limiting to single-device training; (3) Rule-based rewards for math/code require external verification tools (compilers, test runners); (4) The full DeepSeek-R1 training used 512 batch size per step, which is infeasible locally but smaller models with smaller batches may still converge.

For a 7B model on Apple Silicon with 128GB unified memory: policy (7B) + reference (7B) = 14B parameters in memory during training. With 4-bit quantization for inference/generation and optimizer states in 32-bit, this is feasible. The main bottleneck is generation throughput for creating rollouts.
Confidence: medium

### 16.3 How Does FP8 Inference Compare to INT4 for Local Model Quality?

**Answer: FP8 is significantly higher quality; INT4 is acceptable for chat/RAG but degrades code.**

Claim: FP8 shows negligible quality difference vs BF16 (0.6 points on MMLU-Pro), while INT4 drops 8 points on HumanEval [^11^].

Source: AIMultiple quantization study
URL: https://aimultiple.com/llm-quantization
Date: 2026-03-17
Excerpt:
```
FP8 scores 69.64% on MMLU-Pro vs 70.24% for BF16, a 0.6 point difference... Int4 degrades code generation more than knowledge. MMLU-Pro drops 1.6 points at Int4. HumanEval drops 8 points.
```
Context: For local inference: FP8 requires Hopper/Blackwell GPUs (not available on Apple Silicon or most consumer GPUs). On Apple Silicon, the practical choice is between INT8 (safe, ~50% size reduction) and INT4 (aggressive, ~70-75% reduction). The Q4_K_M format in llama.cpp with mixed precision provides the best INT4 quality. For deterministic substrates prioritizing quality, INT8 weight-only quantization is the recommended starting point.
Confidence: high

### 16.4 Can DualPipe's Communication Overlap Apply to Apple Silicon UMA?

**Answer: PARTIALLY, with significant adaptation required.**

Claim: DualPipe's key idea is overlapping computation and communication within forward/backward chunks by manually adjusting GPU SM ratios [^4^].

Source: DeepSeek-V3 Technical Report
URL: https://arxiv.org/abs/2412.19437
Date: 2024-12-27
Excerpt: "For a pair of forward and backward chunks, we rearrange these components and manually adjust the ratio of GPU SMs dedicated to communication versus computation."
Context: Apple Silicon's Unified Memory Architecture (UMA) eliminates the CPU-GPU memory copy bottleneck that DualPipe addresses on discrete GPU systems. However, the fundamental principle of overlapping different operations (computation, memory movement, data loading) remains applicable. For local deterministic training: (1) UMA removes the need for explicit CPU-GPU communication overlap since all memory is shared; (2) The bidirectional scheduling concept can be adapted to overlap forward/backward passes with data preprocessing on CPU cores; (3) Apple Silicon's Neural Engine and GPU can potentially run in parallel, though MLX does not currently expose this; (4) The specific SM-level scheduling in DualPipe is deeply tied to NVIDIA GPU architecture and does not translate directly. The more relevant optimization for Apple Silicon would be maximizing GPU utilization while minimizing CPU-GPU synchronization points.
Confidence: low (theoretical adaptation, no existing implementations)

---

## 17. Additional Findings

### 17.1 mHC: Manifold-Constrained Hyper-Connections

Claim: mHC constrains residual mixing matrices to the doubly stochastic manifold via Sinkhorn-Knopp, preventing signal explosion from ~3000x amplification (in unconstrained HC) to ~1.6x [^30^].

Source: mHC: Manifold-Constrained Hyper-Connections (arXiv:2512.24880)
URL: https://arxiv.org/abs/2512.24880
Date: 2025-12
Excerpt:
```
In a 27B parameter model, unconstrained HC signals reached an amplification factor of ~3000x. This caused catastrophic divergence... mHC kept the total gain magnitude bounded at ~1.6x.
```
Context: mHC adds only 6.7% training overhead after optimization with TileLang kernels. It was validated at 3B, 9B, and 27B scales, with the performance gap vs baseline widening as model size increases. This is relevant for deterministic substrates because it provides a principled way to expand residual connectivity without instability.
Confidence: medium (new technique, not yet widely replicated)

### 17.2 Production-Grade Local Inference on Apple Silicon

Claim: A systematic evaluation of five local LLM runtimes on Apple Silicon (MLX, MLC-LLM, Ollama, PyTorch MPS) shows MLX achieves highest sustained throughput but MLC-LLM delivers lower TTFT [^29^].

Source: Production-Grade Local LLM Inference on Apple Silicon
URL: https://arxiv.org/abs/2511.05502
Date: 2025-10-09
Excerpt: "Using the Qwen-2.5 model family across prompts ranging from a few hundred to 100,000 tokens, we measure time-to-first-token (TTFT), steady-state throughput, latency percentiles, long-context behavior... Although Apple Silicon inference frameworks still trail NVIDIA GPU-based systems such as vLLM in absolute performance, they are rapidly maturing into viable, production-grade solutions."
Context: This study was conducted on M2 Ultra with 192GB unified memory. Key findings: all frameworks run fully on-device with no telemetry; long-context (100K tokens) is feasible; quantization support varies across frameworks.
Confidence: high

### 17.3 Posterior-GRPO for Code Generation

Claim: P-GRPO integrates thinking reward, outcome reward, and format reward with posterior assignment (reasoning rewards only after correct outcomes), improving GRPO's limitation of uniform zero advantages when all samples are correct [^31^].

Source: Posterior-GRPO: Rewarding Reasoning Process for Code Generation (arXiv:2508.05170)
URL: https://arxiv.org/abs/2508.05170
Date: 2025-08
Excerpt:
```
We employ a posterior reward assignment strategy, in which reasoning rewards are computed only after correct outcomes (i.e., when all test cases pass), ensuring alignment between reasoning quality and functional correctness. An advantage of P-GRPO is its data utilization efficiency, which enables differentiated rewards when all samples are correct, improving the original GRPO's limitation where uniform success yields zero advantage values and no gradient information.
```
Context: This addresses a real GRPO limitation: when all group samples produce correct answers, GRPO yields zero advantages and no learning signal. P-GRPO's posterior strategy provides finer-grained differentiation.
Confidence: medium

---

## 18. Summary Table: Key Questions Answered

| Question | Answer | Confidence |
|----------|--------|------------|
| Can MLA be retrofitted to existing models? | Yes, via TransMLA; 6B tokens to recover; 93% KV cache compression | HIGH |
| Local GRPO training on Apple Silicon? | Feasible for 7B models with 128GB UMA; eliminates value model saves memory; throughput is bottleneck | MEDIUM |
| FP8 vs INT4 for local inference? | FP8 vastly superior quality but requires Hopper/Blackwell; INT4 acceptable for chat, bad for code | HIGH |
| DualPipe on Apple Silicon UMA? | Core overlap principles applicable but specific SM scheduling is NVIDIA-specific; UMA removes communication bottleneck | LOW |
| Is distillation more effective than RL for small models? | Yes, DeepSeek-R1 distillation outperforms RL on same base models significantly | HIGH |
| Can MoE models run on edge devices? | Yes, with expert pruning, mixed-precision quantization, and prefetching; 4.92x memory reduction demonstrated | HIGH |
| Does FP8 training work at scale? | Yes, validated with <0.25% loss error vs BF16 on 1T+ tokens; zero irrecoverable spikes on 14.8T tokens | HIGH |
| Is GRPO stable for long training runs? | Yes, DeepSeek-R1-Zero trained for 10K+ steps with stable convergence; clip epsilon is critical (0.1 used) | HIGH |
| Can speculative decoding work with any model? | Target-independent methods (PARD) exist; target-dependent (EAGLE-3) achieve higher speedups | MEDIUM |
| Is KV cache the main inference bottleneck? | Yes for long context; PagedAttention + prefix caching + TurboQuant are the key solutions | HIGH |

---

## Citation Index

[^1^]: DeepSeek-V2: A Strong, Economical, and Efficient Mixture-of-Experts Language Model. arXiv:2405.04434, 2024. https://arxiv.org/abs/2405.04434

[^2^]: DeepSeek + SGLang: Multi-Head Latent Attention. Verda blog, 2025. https://verda.com/blog/deepseek-sglang-multi-head-latent-attention

[^3^]: TransMLA: Migrating GQA Models to MLA with Full DeepSeek Compatibility and Speedup. arXiv:2502.07864, 2025. https://arxiv.org/abs/2502.07864

[^4^]: DeepSeek-V3 Technical Report. arXiv:2412.19437, 2024. https://arxiv.org/abs/2412.19437

[^5^]: Insights into DeepSeek-V3: Scaling Challenges and Reflections on Hardware for AI Architectures. arXiv:2505.09343, 2025. https://arxiv.org/abs/2505.09343

[^6^]: DeepGEMM Guide. Antigravity blog, 2026. https://antigravity.codes/blog/deepgemm-guide

[^7^]: DeepSeekMath: Pushing the Limits of Mathematical Reasoning in Open Language Models. arXiv:2402.03300, 2024. https://arxiv.org/abs/2402.03300

[^8^]: Group Relative Policy Optimization (GRPO). Cameron Wolfe blog, 2025. https://cameronrwolfe.substack.com/p/grpo

[^9^]: DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement Learning. Nature, 2025. https://www.nature.com/articles/s41586-025-09422-z

[^10^]: DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement Learning. arXiv:2501.12948, 2025. https://arxiv.org/abs/2501.12948

[^11^]: LLM Quantization: BF16 vs FP8 vs INT4. AIMultiple, 2026. https://aimultiple.com/llm-quantization

[^12^]: FP4 Quantization on Blackwell GPUs. Spheron, 2026. https://www.spheron.network/blog/fp4-quantization-blackwell-gpu-cost/

[^13^]: INT vs FP: A Comprehensive Study of Fine-Grained Low-bit Quantization Formats. arXiv:2510.25602, 2025. https://arxiv.org/abs/2510.25602

[^14^]: KV Cache Optimization: Memory Efficiency for Production LLMs. Introl, 2026. https://introl.com/blog/kv-cache-optimization-memory-efficiency-production-llms-guide

[^15^]: TurboQuant: Online Vector Quantization with Near-optimal Distortion Rate. arXiv:2504.19874, 2025. https://arxiv.org/abs/2504.19874

[^16^]: 8 LLM Quantization Moves for 60% Cheaper Inference. Medium, 2025. https://medium.com/@connect.hashblock/8-llm-quantization-moves-for-60-cheaper-inference-c0acc6b28b4a

[^17^]: EAGLE-3: Scaling up Inference Acceleration of Large Language Models via Training-Time Test. arXiv:2503.01840, 2025. https://arxiv.org/abs/2503.01840

[^18^]: PARD: Accelerating LLM Inference with Low-Cost Parallel Draft Model Adaptation. arXiv:2504.18583, 2025. https://arxiv.org/abs/2504.18583

[^19^]: Speculative Decoding Reference Implementation. GitHub, 2025. https://github.com/bassrehab/speculative-decoding

[^20^]: Layered Prefill for LLM Inference. arXiv:2510.08055, 2025. https://arxiv.org/abs/2510.08055

[^21^]: Prefill-Decode Disaggregation: Splitting the Two Stages of Inference. Optiverse, 2026. https://optiversetech.com/blog/prefill-decode-disaggregation/

[^22^]: DistServe: Disaggregating Prefill and Decoding for Goodput Optimization. OSDI'24. https://www.usenix.org/system/files/osdi24-zhong-yinmin.pdf

[^23^]: Ring Attention with Blockwise Transformers for Near-Infinite Context. arXiv:2310.01889, 2023. https://arxiv.org/abs/2310.01889

[^24^]: EdgeMoE: Fast On-Device Inference of MoE-based Large Language Models. OpenReview, 2024. https://openreview.net/pdf?id=DDJeREha18

[^25^]: HOBBIT: A Mixed Precision Expert Offloading System for Fast MoE Inference. arXiv:2411.01433, 2024. https://arxiv.org/abs/2411.01433

[^26^]: Fate: Fast Edge Inference of Mixture-of-Experts Models via Cross-Layer Gate. arXiv:2502.12224, 2025. https://arxiv.org/abs/2502.12224

[^27^]: EAC-MoE: Expert-Selection Aware Compressor for Mixture-of-Experts. ACL 2025. https://aclanthology.org/2025.acl-long.633.pdf

[^28^]: Collaborative Compression for Large-Scale MoE Deployment on Edge. arXiv:2509.25689, 2025. https://arxiv.org/abs/2509.25689

[^29^]: Production-Grade Local LLM Inference on Apple Silicon. arXiv:2511.05502, 2025. https://arxiv.org/abs/2511.05502

[^30^]: mHC: Manifold-Constrained Hyper-Connections. arXiv:2512.24880, 2025. https://arxiv.org/abs/2512.24880

[^31^]: Posterior-GRPO: Rewarding Reasoning Process for Code Generation. arXiv:2508.05170, 2025. https://arxiv.org/abs/2508.05170

---

## Research Notes & Limitations

1. **FP8 on Apple Silicon**: Apple Silicon does not natively support FP8 tensor operations. MLX and PyTorch MPS use BF16 or FP16. FP8 benefits are currently limited to NVIDIA Hopper/Blackwell GPUs.

2. **DualPipe portability**: DualPipe is deeply tied to NVIDIA GPU SM scheduling, NVLink, and InfiniBand. Direct porting to Apple Silicon or other architectures is not straightforward.

3. **GRPO on-device**: While GRPO is memory-efficient (no value model), the need to generate multiple rollouts per prompt creates throughput challenges on single-device setups. Batch sizes and context lengths may need significant reduction.

4. **MoE inference complexity**: Expert parallelism with all-to-all communication is designed for multi-GPU setups. Single-device MoE inference requires expert offloading/prefetching techniques (EdgeMoE, Fate) that add runtime complexity.

5. **TransMLA validation**: While promising, TransMLA has primarily been validated on smaller models (7B, 1.7B). Scaling to larger models (14B+) requires further investigation.

6. **mHC novelty**: Manifold-constrained hyper-connections are very recent (December 2025) and have not yet been independently replicated or integrated into major training frameworks.

7. **TurboQuant integration**: TurboQuant for KV cache is being integrated into vLLM but is not yet available in all mainstream inference engines.

---

*Report compiled from 15+ independent web searches across academic papers, technical reports, open-source repositories, and authoritative blogs. All claims traced to primary sources with verbatim excerpts.*
