# Local Model Stack: Gemma 4 & Qwopus/Qwen3.5 Deep Dive — April 2026

## Executive Summary

All 12 models you linked belong to two families: **Google Gemma 4** (dense 31B and pruned 21B MoE variants) and **Qwopus/Qwen3.5** (27B dense and 35B MoE variants with Claude Opus 4.6 reasoning distillation). Each exists in multiple quantization formats aimed at different hardware profiles. For your **M2 Pro 18 GB unified memory** MacBook, the sweet spot is the pruned Gemma 4 REAP (21B, ~15–16 GB at Q4) or Qwopus Q4_K_M (16.5 GB), with the larger variants reserved for higher-RAM laptops and desktops.

***

## Section 1: The Gemma 4 Family — Architecture First

Gemma 4 covers four model sizes: **E2B**, **E4B** (ultra-mobile edge models), **31B** (dense), and **26B A4B** (MoE). The two large variants are the ones you're interested in.[^1]

### Gemma 4 31B IT — The Dense Flagship

The 31B is a **fully dense transformer** with 60 layers, hybrid sliding-window + full global attention (every 6th layer is global), K=V weight sharing on global layers, and proportional RoPE (P-RoPE) for long-context. It supports text, image, and video input modalities with a **256K-token context window** across 140+ languages. On benchmarks it places #3 among open models on Chatbot Arena (as of April 2026) and scores 89.2% on AIME 2026 and 80.0% on LiveCodeBench v6. The trade-off is raw memory: BF16 = 61 GB, Q8 = 34 GB, Q4 = ~17–20 GB, but at Q4 you still need ~24–36 GB total for the KV cache at normal context lengths.[^2][^3][^4][^5][^6][^7]

**On Apple Silicon:** You need at least 36 GB of unified memory for practical use; the M4 Pro 48 GB is considered the sweet spot, and standard `mlx_lm` as of v0.31.2 does **not** yet support Gemma 4 — you need vMLX 1.3.26+ or Ollama.[^5][^8]

### Gemma 4 26B A4B — The MoE Speed-Accuracy Champion

The 26B A4B is a **Mixture-of-Experts** model: 26B total parameters loaded into memory, but only ~4B active per token, giving generation speed close to a 4B model while retaining near-31B reasoning quality. AIME 2026 score: 88.3% vs. 31B's 89.2% — a razor-thin gap. LiveCodeBench v6: 77.1% vs. 80.0% for 31B. On the NVIDIA DGX Spark, the 26B A4B achieves 23.7 t/s decode versus only 3.7 t/s for 31B BF16, and 3105 t/s prompt processing at pp2048. RAM: **18 GB at Q4, 28 GB at Q8**.[^9][^4][^10][^7][^1]

> **Critical distinction**: Although only 4B parameters are *active*, all 26B must be loaded into memory for routing. Do not confuse it with an actual 4B model.

***

## Section 2: All 12 Linked Models — Detailed Breakdown

### 2.1 Gemma 4 Variants

| Model | Format | Size | Target Hardware | Key Feature |
|---|---|---|---|---|
| `0xSero/gemma-4-21b-a4b-it-REAP` | BF16 safetensors | ~43 GB | 48 GB+ Mac/GPU | REAP-pruned: 20% of MoE experts removed[^11] |
| `dealignai/Gemma-4-31B-JANG_4M-CRACK` | MLX-native safetensors | 18 GB | 24 GB Mac (MLX) | Abliterated (uncensored), mixed 8/4-bit[^8] |
| `nvidia/Gemma-4-31B-IT-NVFP4` | NVFP4 (FP4 weights) | 32.7 GB | Blackwell GPUs only | 99.7% GPQA retention; attention layers NOT quantized[^12][^13] |
| `Intel/gemma-4-31B-it-int4-AutoRound` | INT4 (AutoRound) | 19.2 GB | vLLM + Intel/NVIDIA | 19.2 GB, gradient-descent optimal rounding[^12][^14] |

#### `0xSero/gemma-4-21b-a4b-it-REAP` — Pruned MoE for Mac

REAP (Routing-Enhanced Activation Pruning) removes the 20% least-used experts per layer (25 of 128), bringing total parameters from ~26B to **~21.34B** across 103 remaining experts. Crucially, active parameters per token remain ~4B since the router still selects 8 experts from the surviving pool. Disk/memory footprint drops from ~52 GB to **~43 GB (BF16)**, with ~18% total reduction. The developers ran calibration on 22,000 samples across coding, math, reasoning, tool-calling, and agentic tasks and found **12/14 blind quality comparisons were clean ties** with the original 26B A4B. VRAM at Q4: **~12 GB limited context, ~16 GB full 262K context**. This is the most M2-friendly Gemma 4 MoE variant.[^11][^15][^16]

#### `dealignai/Gemma-4-31B-JANG_4M-CRACK` — Abliterated, MLX-Optimized

This is Google's `gemma-4-31b-it` with **full abliteration** (refusal removal) applied via MPOA magnitude-preserving surgery, achieving 93.7% HarmBench compliance with only -2.0% MMLU degradation. The JANG_4M quantization profile applies **8-bit to attention layers** (Q/K/V/O, embeddings) and **4-bit to MLP layers** (gate, up, down proj), averaging **5.1 bits** overall, fitting in **18 GB**. Format is MLX-native safetensors for instant load. **Requires vMLX 1.3.26+** and 24 GB+ unified memory. The model retains the original multimodal vision encoder in float16 passthrough. This is the best option for users who want uncensored output on Apple Silicon without GGUF overhead.[^8]

#### `nvidia/Gemma-4-31B-IT-NVFP4` — NVFP4 Precision (Blackwell Only)

NVIDIA's quantization uses FP4 for weights but **does not quantize the attention layers** of the dense 31B model, which is why the checkpoint inflates to **32.7 GB** — comparable to an FP8 checkpoint. Quality retention is exceptional: 99.7% of baseline GPQA (75.46% vs. 75.71%). **Blackwell GPU-only** (RTX 5090, H200 Blackwell) — NVFP4 is unsupported on Ampere or Ada Lovelace GPUs. Intel's AutoRound INT4 at 19.2 GB is a practical alternative for older hardware. On NVIDIA DGX Spark, Intel's INT4 runs at ~12 t/s versus ~3.7 t/s for BF16.[^10][^12][^13]

#### `Intel/gemma-4-31B-it-int4-AutoRound` — Best Standard INT4

Intel's AutoRound algorithm uses **sign gradient descent** to find mathematically optimal rounding directions for each weight — superior to naive nearest-int rounding. The Gemma 4 31B AutoRound checkpoint is **19.2 GB** and is vLLM-compatible, making it the best general-purpose INT4 for non-Blackwell NVIDIA GPUs and Linux servers. Among community evaluations as of April 2026, it was the most widely tested INT4 alternative.[^12][^14][^17]

***

### 2.2 Qwopus — The Claude-Distilled Qwen3.5 Family

All Qwopus models share the same lineage: **Qwen3.5 base architecture** + **QLoRA fine-tuning on Claude Opus 4.6 reasoning traces** to distill Opus's structured Chain-of-Thought style into a local model.[^18][^19]

| Model | Format | Base | Size | Notes |
|---|---|---|---|---|
| `Jackrong/Qwopus3.5-27B-v3` | BF16 safetensors | Qwen3.5-27B | ~54 GB | Source model; best strict accuracy (95.73%)[^19] |
| `Jackrong/Qwopus3.5-27B-v3-GGUF` | GGUF (multi-quant) | Qwopus v3 | 16.5–54 GB | Q4_K_M = 16.5 GB @ 29–35 t/s[^20] |
| `caiovicentino1/Qwopus3.5-27B-v3-PolarQuant-Q5` | PolarQuant Q5 (safetensors) | Qwopus v3 | ~18.1 GB | Hadamard+Lloyd-Max Q5, runs at full FP16 speed[^21] |
| `YTan2000/Qwopus3.5-27B-v3-TQ3_4S` | TQ3_4S GGUF | Qwopus v3 | <16.5 GB | Walsh-Hadamard 3.5-bit; needs `turbo-tan/llama.cpp-tq3`[^22] |
| `samuelcardillo/Qwopus-MoE-35B-A3B` | BF16 safetensors | Qwen3.5-35B-A3B | ~72 GB | MoE source; 3B active/token[^23] |
| `samuelcardillo/Qwopus-MoE-35B-A3B-GGUF` | GGUF (Q4–Q8) | Qwopus MoE | 20–35 GB | Q4_K_M = 20 GB (24 GB GPU min)[^24] |

#### Qwopus3.5-27B-v3 — The Dense Flagship

The v3 model fine-tunes Qwen3.5-27B with supervised fine-tuning (SFT) + LoRA, masking training only on assistant reasoning tokens. It achieves a strict pass rate of **95.73% (157/164)** on the evaluation suite, outperforming base Qwen3.5-27B (94.51%) and the earlier Claude-distilled v2 (92.68%). Key training details: 64-layer hybrid attention (linear + full), BF16 via Unsloth, answers validated by GPT-4.5-Pro and Claude Opus 4.6. Context window limitation: the LoRA training used 8,192-token sequences vs. Qwen3.5's native 262K, which means the distilled model works best within shorter contexts.[^19][^25]

**Important caveat**: Qwopus adds structured reasoning but sacrifices multimodal input (text-only vs. Qwen3.5's native text/image/video) and extended context. If multimodal or long-context is a priority, prefer the base Qwen3.5-27B.[^25]

#### `Jackrong/Qwopus3.5-27B-v3-GGUF` — The Practical Choice

The official GGUF version at Q4_K_M runs at **29–35 tokens/sec** with ~16.5 GB VRAM and supports the full 262K context. This is the go-to format for Ollama and llama.cpp. On an M2 Pro 18 GB, Q4_K_M is right at the edge — it will run but leaves minimal headroom for the KV cache. Q3_K_M or the TQ3_4S would be safer for your hardware.[^20][^18]

#### `caiovicentino1/Qwopus3.5-27B-v3-PolarQuant-Q5` — Research-Grade Compression

PolarQuant Q5 applies three stages: (1) block-wise normalization to the unit hypersphere, (2) Walsh-Hadamard rotation to make weight coordinates approximately Gaussian, then (3) Lloyd-Max optimal centroid quantization. The result outperforms standard GGUF Q5 in perplexity because PolarQuant places quantization levels where weight density is highest, rather than uniformly. When combined with torchao INT4 dequantization, it achieves **PPL 6.56 vs. 6.68 for direct absmax INT4**, while running at 43.1 t/s at 6.5 GB VRAM. The PolarQuant Q5 weights on Qwopus v3 **run at full FP16 speed (45.9 t/s) at 18.1 GB** — same memory as FP16 storage, making it a high-fidelity compressed distribution format rather than an inference quantization. For inference, the torchao INT4 path is more practical.[^26][^27][^28][^21]

#### `YTan2000/Qwopus3.5-27B-v3-TQ3_4S` — Experimental 3.5-bit GGUF

TQ3_4S is a **3.5-bit Walsh-Hadamard transform weight format** with four per-8 scales per 32-weight block, offering smaller size than Q4_K_M. Final perplexity: **6.3433**, competitive with standard 4-bit quantizations. It requires the fork `turbo-tan/llama.cpp-tq3` at runtime — not standard llama.cpp. Recommended only if you need sub-Q4 memory footprint and are comfortable running experimental tooling.[^22]

#### `samuelcardillo/Qwopus-MoE-35B-A3B` and `-GGUF` — The MoE Variant

Applies the same Qwopus QLoRA recipe (LoRA rank 32, attention-only targets, Unsloth + TRL) to the **Qwen3.5-35B-A3B** base — a 35B total parameter MoE model that activates only **~3B parameters per token**. Architecture: 40 transformer layers, 256 routed experts (8 active + 1 shared per token), hybrid Gated DeltaNet + MoE, 262K context. Because only 3B parameters are computed per token, it can run on **as little as 8 GB VRAM when quantized**, yet the full 35B weight matrix must still be loaded.[^29][^30][^23][^31][^24]

GGUF quantization sizes: Q4_K_M = **20 GB** (24 GB GPU minimum), Q5_K_M = 24 GB, Q6_K = 27 GB, Q8_0 = 35 GB. On a 24 GB GPU + 256 GB system RAM with MoE offloading, it can reach 25+ t/s. The APEX GGUF fork by `mudler` adds a 5+5 symmetric edge gradient calibration across all 40 layers on top of the Qwopus distillation.[^32][^24][^29]

***

## Section 3: RAM Requirements — Master Table

| Model | Format | M2 18 GB Runnable? | Recommended Min RAM | Notes |
|---|---|---|---|---|
| `gemma-4-21b-a4b-it-REAP` | BF16 | ❌ (43 GB) | 48 GB | Needs GGUF/MLX quant — community release expected[^15][^16] |
| `Gemma-4-31B-JANG_4M-CRACK` | MLX mixed 8/4-bit | ⚠️ Tight (18 GB weights, needs 24 GB+) | 24 GB | vMLX 1.3.26+ required[^8] |
| `Gemma-4-31B-IT-NVFP4` | FP4 | ❌ Blackwell only | 32 GB VRAM + Blackwell | Not for Mac at all[^13] |
| `gemma-4-31B-it-int4-AutoRound` | INT4 | ❌ (vLLM/GPU) | 24 GB VRAM (Linux) | No Mac support via standard tools[^12] |
| `Qwopus3.5-27B-v3` | BF16 | ❌ (54 GB) | 64 GB | Source weights only[^19] |
| `Qwopus3.5-27B-v3-GGUF (Q4_K_M)` | GGUF | ⚠️ Tight | 24 GB recommended | 16.5 GB weights; leaves minimal KV cache room[^18][^20] |
| `Qwopus3.5-27B-v3-GGUF (Q3_K_M)` | GGUF | ✅ | 18 GB | ~13–14 GB; comfortable for M2 18 GB |
| `Qwopus3.5-27B-v3-PolarQuant-Q5` | PolarQuant | ⚠️ (18.1 GB) | 24 GB | Inference path via torchao INT4 = 6.5 GB[^21] |
| `Qwopus3.5-27B-v3-TQ3_4S` | TQ3_4S GGUF | ✅ | 18 GB | Experimental runtime required[^22] |
| `Qwopus-MoE-35B-A3B` | BF16 | ❌ (72 GB) | 80 GB | Source weights[^23] |
| `Qwopus-MoE-35B-A3B-GGUF (Q4_K_M)` | GGUF | ❌ (20 GB) | 24 GB GPU | MoE offload can use system RAM[^24] |
| `Qwopus-MoE-35B-A3B-GGUF (Q8_0)` | GGUF | ❌ (35 GB) | 48 GB GPU | Single 48 GB GPU[^24] |

***

## Section 4: Recommended Local Stack by Use Case

### Tier 1 — M2 Pro 18 GB MacBook (Your Current Machine)

**Primary workhorse: `Qwopus3.5-27B-v3-GGUF` at Q3_K_M or Q4_K_M via Ollama/llama.cpp**
- Q4_K_M is the accuracy-performance sweet spot at 16.5 GB but leaves only ~1.5 GB for KV cache — workable for short to medium contexts[^18][^20]
- Q3_K_M (~13–14 GB) gives more comfortable headroom and the perplexity difference is modest
- Qwopus v3 is demonstrably better than base Qwen3.5 for **coding and tool-calling** under the Unsloth benchmarks[^19]

**Alternative: `Qwopus3.5-27B-v3-TQ3_4S`** for a smaller footprint with Hadamard-enhanced 3.5-bit quality — if you're comfortable running the `turbo-tan/llama.cpp-tq3` fork[^22]

**Gemma 4 option on your hardware: REAP GGUF** — the BF16 REAP model at 43 GB won't fit, but the developers explicitly invited the MLX/GGUF community to quantize it. Once MLX Q4 versions of REAP appear (expect them within days to weeks of this writing), they will land at ~10–12 GB and be your best Gemma 4 option on 18 GB.[^15][^11]

### Tier 2 — 24 GB VRAM GPU Laptop / Desktop

- **Best dense**: `Gemma-4-31B-JANG_4M-CRACK` at 18 GB (vMLX) — top reasoning quality + uncensored, or `Intel/gemma-4-31B-it-int4-AutoRound` at 19.2 GB (vLLM, Linux) for a censored production variant[^8][^12]
- **Best MoE**: `Qwopus-MoE-35B-A3B-GGUF` at Q4_K_M (20 GB) — Claude Opus reasoning in a 3B-active MoE for very fast generation with low KV cache cost[^24]
- **Tool calling specialist**: `Qwopus3.5-27B-v3-GGUF` at Q4_K_M remains the most reliable tool-calling model at this tier[^18]

### Tier 3 — 32–48 GB VRAM / Unified Memory Mac (M3 Max / M4 Max / M4 Pro 48 GB)

- **Best overall**: `Gemma 4 31B` GGUF (unsloth/bartowski) at Q4 (~20 GB) — current #3 open model on Chatbot Arena, GPQA 85.7%, multimodal, 256K context[^6][^5]
- **Best MoE**: `Gemma-4-26B-A4B` GGUF at Q4 (~18 GB) — 30+ t/s generation, near-31B quality, ideal for interactive use[^33][^4]
- **Reasoning/coding**: `Qwopus-MoE-35B-A3B-GGUF` at Q5_K_M or Q6_K for maximum Qwopus quality[^24]

### Tier 4 — 48 GB+ VRAM (Server / Workstation)

- `nvidia/Gemma-4-31B-IT-NVFP4` — only viable on Blackwell (RTX 5090, H200 Blackwell); 99.7% quality retention, weights at 32.7 GB, full 256K context needs 40+ GB[^34][^13]
- `0xSero/gemma-4-21b-a4b-it-REAP` in BF16 — fits on a 48 GB GPU, maximum quality REAP experiment[^11]
- `Qwopus-MoE-35B-A3B-GGUF` at Q8_0 (35 GB) — near-lossless MoE quality[^24]

***

## Section 5: Quantization Format Guide

| Format | Bits | Quality vs. FP16 | Compatibility | Best Use |
|---|---|---|---|---|
| **Q4_K_M** (GGUF) | 4-bit | Good (-3–5% bench) | Universal (llama.cpp, Ollama, LM Studio) | Default production choice[^35] |
| **Q3_K_M** (GGUF) | 3-bit | Moderate | Universal | RAM-constrained devices |
| **TQ3_4S** (GGUF) | 3.5-bit | Good (Hadamard rotation) | `turbo-tan/llama.cpp-tq3` only | Experimental compact[^22] |
| **PolarQuant Q5** | ~5-bit (storage) | Near-lossless (+0.02 PPL) | Custom PolarEngine/vLLM plugin | High-fidelity distribution + torchao INT4 inference[^26][^21] |
| **AutoRound INT4** | 4-bit | Near-lossless | vLLM (Intel/NVIDIA) | Server deployment, optimal rounding[^14] |
| **NVFP4** | 4-bit FP | 99.7% quality retention | Blackwell GPU only | Frontier servers[^13] |
| **JANG_4M** (MLX) | ~5.1-bit avg | -2% MMLU | Apple Silicon (vMLX 1.3.26+) | Mac production + uncensored[^8] |

***

## Section 6: Performance Benchmarks — Gemma 4 31B vs. 26B A4B vs. Qwen3.5-27B

| Benchmark | Gemma 4 31B | Gemma 4 26B A4B | Qwen3.5-27B |
|---|---|---|---|
| AIME 2026 | 89.2% [^7] | 88.3% [^7] | Leads[^36] |
| GPQA Diamond | 85.7% [^6] | — | 85.8%[^37] |
| LiveCodeBench v6 | 80.0% [^7] | 77.1% [^7] | 80.7%[^25] |
| Codeforces Elo | 2150 [^7] | 1718 [^7] | — |
| MMLU Pro | 85.2% [^7] | 82.6% [^7] | — |
| Decode speed (BF16) | ~3.7 t/s [^10] | ~23.7 t/s [^10] | — |
| SWE-bench Verified | — | — | 72.4%[^25] |

The 26B A4B's ~6.4× decode speed advantage over 31B dense at identical quality makes it the **best interactive local model** at this parameter range. Qwen3.5-27B leads on SWE-bench and near-ties on GPQA, confirming that Gemma 4 31B and Qwen3.5-27B are effectively **interchangeable flagship 27–31B models** depending on the task.[^36][^6]

***

## Section 7: Tool Calling Considerations

Tool calling reliability varies significantly by quantization level and model. Benchmarks of local models in March 2026 found that **Qwen3.5 4B achieves 97.5% pass rate** on single and multi-tool tasks at only 3.4 GB — the highest of any tested model — while larger models do not necessarily outperform it on structured function-calling. Qwopus3.5-27B-v3 explicitly documents that only the 27B model with Claude Opus reasoning distillation demonstrates stable tool-calling performance across quantizations. For your app, the key implication is: **include a dedicated small tool-calling model** (e.g., base Qwen3.5-4B or 7B at Q4_K_M) alongside the larger reasoning/chat model, rather than relying solely on the 27B quantized models for all tool calls.[^38][^18]

***

## Section 8: Selecting the Best Variants From Your List

### Tier-by-tier winners

**For M2 Pro 18 GB (your Mac):**
- **✅ Best pick**: `Jackrong/Qwopus3.5-27B-v3-GGUF` at Q3_K_M — best reasoning/coding distillation that fits comfortably
- **✅ Experimental**: `YTan2000/Qwopus3.5-27B-v3-TQ3_4S` — slightly smaller with comparable perplexity if you use the TQ fork

**For 24 GB GPU laptops:**
- **✅ Dense Gemma 4**: `dealignai/Gemma-4-31B-JANG_4M-CRACK` (18 GB MLX) or `Intel/gemma-4-31B-it-int4-AutoRound` (19.2 GB vLLM)
- **✅ MoE Qwopus**: `samuelcardillo/Qwopus-MoE-35B-A3B-GGUF` at Q4_K_M (20 GB)

**For 32–48 GB hardware:**
- **✅ Best Gemma**: Standard `unsloth/gemma-4-31B-it-GGUF` or `bartowski/google_gemma-4-31B-it-GGUF` (not on your linked list but the canonical GGUF releases)
- **✅ Best Qwopus MoE**: `samuelcardillo/Qwopus-MoE-35B-A3B-GGUF` at Q6_K (27 GB)

**Skip for now:**
- `nvidia/Gemma-4-31B-IT-NVFP4` — hardware-locked to Blackwell[^13]
- `samuelcardillo/Qwopus-MoE-35B-A3B` (BF16 full) — 72 GB, only useful as a source for re-quantization
- `Jackrong/Qwopus3.5-27B-v3` (BF16 full) — same, source weights for fine-tuning only
- `caiovicentino1/Qwopus3.5-27B-v3-PolarQuant-Q5` — requires PolarEngine vLLM plugin not yet mainstream; watch for updates[^21]

### Models not in your list worth adding

For a **complete robust stack**, these complement what you have:
- **`unsloth/gemma-4-31B-it-GGUF`** (Q4_K_M, ~20 GB) — canonical Gemma 4 31B GGUF for 32 GB+ devices[^39]
- **`unsloth/Qwen3.5-35B-A3B-GGUF`** — base MoE without Opus distill, useful as a comparison baseline
- **`Qwen3.5-27B` (base, GGUF)** — multimodal + 262K context, better for long-context tasks where Qwopus's 8K training limit matters[^25]
- **`Qwen3.5-4B` or `Qwen3.5-7B` (Q4_K_M)** — dedicated tool-calling models for agentic pipelines, higher reliability than 27B at function calling[^38]

***

## Conclusion

The two families complement each other well in a multi-laptop stack. **Gemma 4 models** (particularly the 26B A4B MoE and the pruned 21B REAP) bring multimodal support, 256K context, and frontier reasoning to Apple Silicon and consumer GPUs. **Qwopus models** bring Claude Opus-style structured reasoning and strong coding performance in a GGUF-native, Ollama-ready format. The JANG_4M CRACK and Intel AutoRound variants are the practical 24 GB GPU choices; the NVFP4 and full BF16 variants are for server or workstation use. On your M2 Pro 18 GB specifically, Qwopus Q3_K_M or Q4_K_M via Ollama is the only locally-runnable high-quality option from this list today — Gemma 4's MLX and GGUF ecosystem for the REAP 21B variant is actively being built out and worth monitoring.

---

## References

1. [Gemma 4 model overview | Google AI for Developers](https://ai.google.dev/gemma/docs/core) - Parameter sizes and quantization. Gemma 4 models are available in 4 parameter sizes: E2B, E4B, 31B a...

2. [A Visual Guide to Gemma 4 - by Maarten Grootendorst](https://newsletter.maartengrootendorst.com/p/a-visual-guide-to-gemma-4) - In particular, Gemma 4 - 31B has fewer layers (60 vs 62) but is a wider model.

3. [gemma-4-31b-it Model by Google - NVIDIA Build](https://build.nvidia.com/google/gemma-4-31b-it/modelcard) - Gemma 4 31B IT is an open multimodal model built by Google DeepMind that handles text and image inpu...

4. [Gemma 4 Hardware Requirements: RAM, VRAM, and Model Size ...](https://avenchat.com/blog/gemma-4-hardware-requirements) - See Gemma 4 hardware requirements by model size and quantization, including approximate memory needs...

5. [How to Run Gemma 4 31B on Mac: Complete Apple Silicon ...](https://cloudinsight.cc/en/blog/gemma-4-apple-silicon) - TL;DR: You can run Gemma 4 31B on Apple Silicon Macs, but you need at least 36GB of memory on an M4 ...

6. [[AINews] Gemma 4: The best small Multimodal Open Models ...](https://www.latent.space/p/ainews-gemma-4-the-best-small-multimodal) - Arena/Text: Arena reports Gemma-4-31B as #3 among open models (and #27 overall), with Gemma-4-26B-A4...

7. [Gemma 4 Benchmarks: How a 31B Model Competes with Giants 20 ...](https://gemma4all.com/blog/gemma-4-benchmarks-performance) - This article breaks down the performance data across reasoning, coding, vision, and more, so you can...

8. [dealignai/Gemma-4-31B-JANG_4M-CRACK - Hugging Face](https://huggingface.co/dealignai/Gemma-4-31B-JANG_4M-CRACK) - Metric, Value. Source, google/gemma-4-31b-it. Architecture, Dense Transformer + Hybrid Sliding/Globa...

9. [Gemma 4 - How to Run Locally | Unsloth Documentation](https://unsloth.ai/docs/models/gemma-4) - Gemma-4-31B needs 20GB RAM (4-bit) or 34GB (8-bit).

10. [Gemma 4 Day-1 Inference on NVIDIA DGX Spark](https://forums.developer.nvidia.com/t/gemma-4-day-1-inference-on-nvidia-dgx-spark-preliminary-benchmarks/365503) - Intel's Gemma 4 31B INT4 Autoround model runs at around 12t/s on a single spark and around 20t/s on ...

11. [0xSero/gemma-4-21b-a4b-it-REAP - Hugging Face](https://huggingface.co/0xSero/gemma-4-21b-a4b-it-REAP) - REAP removes 20% of MoE experts (25 of 128 per layer) while preserving the model's routing behavior....

12. [List of quantized Gemma 4 31B I'm evaluating:](https://x.com/bnjmn_marie/status/2041163708945010902) - List of quantized Gemma 4 31B I'm evaluating: - Intel/gemma-4-31B-it-int4-AutoRound (19.2 GB) - cyan...

13. [NVIDIA Gemma 4 31B Quantized on Hugging Face - LinkedIn](https://www.linkedin.com/posts/md-amanatullah12345_breaking-nvidia-just-quantized-gemma-4-activity-7446221024557330432-K4Qf) - BREAKING: NVIDIA just quantized Gemma 4 31B on Hugging Face NVFP4 compression = 4x smaller weights w...

14. [Qwen3.5 9B at 4-Bit: Intel's Quantized Model Runs Locally with 4x ...](https://www.youtube.com/watch?v=IaiyFSvRBf0) - This video locally installs Qwen3.5-9B-int4-AutoRound which is an int4 model with group_size 128 and...

15. [Hugging Face Launches Gemma-4-21B-REAP Model | Phemex News](https://phemex.com/news/article/hugging-face-unveils-gemma421breap-model-with-enhanced-reasoning-71109) - Hugging Face releases Gemma-4-21B-REAP model with strong reasoning performance, requiring 12GB VRAM ...

16. [Hugging Face Launches Gemma-4-21B-REAP Model with Strong ...](https://www.kucoin.com/news/flash/hugging-face-launches-gemma-4-21b-reap-model-with-strong-reasoning-performance) - Hugging Face released the Gemma-4-21B-REAP model on April 6 (UTC+8), demonstrating strong reasoning ...

17. [Intel Quantization Support - vLLM](https://docs.vllm.ai/en/v0.18.2/features/quantization/inc/) - AutoRound is Intel's advanced quantization algorithm designed for large language models(LLMs). It pr...

18. [Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled](https://huggingface.co/Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled) - The model's core directive is to leverage state-of-the-art Chain-of-Thought (CoT) distillation prima...

19. [Jackrong/Qwopus3.5-27B-v3 - Hugging Face](https://huggingface.co/Jackrong/Qwopus3.5-27B-v3) - Qwopus3.5-27B-v3 is a reasoning-enhanced model based on Qwen3.5-27B, designed to simultaneously impr...

20. [gag0/qwen35-opus-distil:35b-a3b-q6 - Ollama](https://ollama.com/gag0/qwen35-opus-distil:35b-a3b-q6) - Hardware usage remains unchanged: - About 16.5 GB VRAM with Q4_K_M quantization - 29–35 tok/s genera...

21. [caiovicentino1/Qwopus3.5-27B-v3-PolarQuant-Q5 - Hugging Face](https://huggingface.co/caiovicentino1/Qwopus3.5-27B-v3-PolarQuant-Q5) - Unlike GGUF (uniform quantization), PolarQuant places quantization levels where weight density is hi...

22. [YTan2000/Qwopus3.5-27B-v3-TQ3_4S - Hugging Face](https://huggingface.co/YTan2000/Qwopus3.5-27B-v3-TQ3_4S) - This release is a TQ3_4S GGUF quantization of Jackrong/Qwopus3.5-27B-v3 , which is itself derived fr...

23. [samuelcardillo/Qwopus-MoE-35B-A3B - Hugging Face](https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B) - Base Model, Qwen/Qwen3.5-35B-A3B ; Architecture, Mixture of Experts (MoE) ; Total Parameters, ~35B ;...

24. [samuelcardillo/Qwopus-MoE-35B-A3B-GGUF - Hugging Face](https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B-GGUF) - The Opus Distilled v2 is 16% faster but has an aggressive thinking mode that sometimes produces mini...

25. [Qwen3.5-27B Distilled vs Base: What You Gain | Awesome Agents](https://awesomeagents.ai/tools/qwen-27b-distilled-vs-qwen-27b-base/) - Choose the base Qwen3.5-27B for any real workload. It has verified benchmarks, 32x more context, mul...

26. [PolarQuant: Optimal Gaussian Weight Quantization via Hadamard ...](https://arxiv.org/html/2603.29078v1) - We present PolarQuant, a post-training weight quantization method for large language models (LLMs) t...

27. [caiovicentino1/Wan2.2-Animate-14B-PolarQuant-Q5 - Hugging Face](https://huggingface.co/caiovicentino1/Wan2.2-Animate-14B-PolarQuant-Q5) - Unlike GGUF (uniform quantization), PolarQuant places quantization levels where weight density is hi...

28. [PolarQuant: Optimal Gaussian Weight Quantization via Hadamard ...](https://arxiv.org/abs/2603.29078) - PolarQuant operates in three stages: (1) block-wise normalization to the unit hypersphere, (2) Walsh...

29. [mudler/Qwopus-MoE-35B-A3B-APEX-GGUF - Hugging Face](https://huggingface.co/mudler/Qwopus-MoE-35B-A3B-APEX-GGUF) - Architecture · Model: Qwopus-MoE-35B-A3B (qwen3_5_moe) · Layers: 40 (hybrid: linear attention + full...

30. [Qwen3.5-35B-A3B - Specs, API & Pricing - Puter Developer](https://developer.puter.com/ai/qwen/qwen3.5-35b-a3b/) - It uses a hybrid Gated DeltaNet + MoE architecture and can run on GPUs with as little as 8GB VRAM wh...

31. [Qwen3.5-35B-A3B: Specifications and GPU VRAM Requirements](https://apxml.com/models/qwen35-35b-a3b) - The MoE structure is detailed as having 256 total experts, with 8 routed experts and 1 shared expert...

32. [Qwen3.5 - How to Run Locally | Unsloth Documentation](https://unsloth.ai/docs/models/qwen3.5) - GGUF: Qwen3.5-35B-A3B-GGUF. For these tutorials, we will using llama.cpp for fast local inference, e...

33. [You can now run Google Gemma 4 locally! (5GB RAM min.) - Reddit](https://www.reddit.com/r/LocalLLM/comments/1sas4qd/you_can_now_run_google_gemma_4_locally_5gb_ram_min/) - 26B-A4B: 30+ tokens/s in near-full precision with ~30GB RAM / unified mem. 4-bit works on 16GB RAM. ...

34. [Gemma 4 31B and 26B A4B: Architecture and Memory Consumption](https://kaitchup.substack.com/p/gemma-4-31b-and-26b-a4b-architecture) - GPU Memory Consumption of Gemma 4 31B and 26B ... If you are going to use the model without quantiza...

35. [Local LLM Inference in 2026: The Complete Guide to Tools ...](https://blog.starmorph.com/blog/local-llm-inference-tools-guide) - Memory Requirements by Model Size ; 30-34B, 20 GB, 32 GB, Codestral 22B ; 70B, 40 GB, 64 GB, Llama 3...

36. [Gemma-4 31B vs Qwen3.5 27B: Hands-on Local ... - YouTube](https://www.youtube.com/watch?v=ZCKuK8UCsP4) - Gemma-4 31B vs Qwen3.5 27B: Hands-on Local Comparison of Two Top Dense Models. 6.5K views · 1 day ag...

37. [Claude 4.1 Opus (Non-reasoning) vs. Qwen3.5 27B (Reasoning)](https://llmbase.ai/compare/claude-4-1-opus,qwen3-5-27b/) - Detailed comparison of Claude 4.1 Opus (Non-reasoning), Qwen3.5 27B (Reasoning). Compare benchmarks,...

38. [I Tested 7 Local LLMs on Tool Calling | 2026 Eval Results](https://www.jdhodges.com/blog/local-llms-on-tool-calling-2026-pt1-local-lm/) - Every model's worst category was multi-tool. The task: call two or more tools in a single response (...

39. [unsloth/gemma-4-31B-it-GGUF - Hugging Face](https://huggingface.co/unsloth/gemma-4-31B-it-GGUF) - This hybrid design delivers the processing speed and low memory footprint of a lightweight model wit...

