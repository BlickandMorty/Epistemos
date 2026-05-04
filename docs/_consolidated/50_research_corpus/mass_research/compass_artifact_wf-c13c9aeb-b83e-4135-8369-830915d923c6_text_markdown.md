# Optimizing LLM inference on 16GB Apple Silicon for Epistemos

**A 16GB M2 Pro can practically run dense models up to 14B parameters at 4-bit quantization and MoE models up to 30B total parameters, delivering 15–38 tokens/second.** The key to making Epistemos's upcoming multi-tier local model stack work within this memory envelope is a combination of aggressive quantization (Q4_K_M as the default), KV cache compression, speculative decoding, and a dual-backend architecture using both MLX and llama.cpp. The model landscape has shifted dramatically in 2025–2026: Qwen3.5-9B now rivals models 3–13× its size, Google's TurboQuant compresses KV caches 6× at runtime, and MoE architectures like Qwen3-30B-A3B deliver "30B-class" quality while activating only 3B parameters per token. For Epistemos—with its Rust backend, Metal rendering pipeline, and the deferred Omega model-routing stack—the architectural path forward is a protocol-based dual-backend abstraction over MLX-Swift and llama.cpp, with hardware-aware model selection and aggressive memory lifecycle management.

---

## The memory budget: what actually fits on 16GB

Apple Silicon's unified memory architecture gives both CPU and GPU zero-copy access to the same physical memory pool, eliminating PCIe transfer overhead that plagues discrete GPUs. On a 16GB M2 Pro, however, macOS and background processes consume **3–4GB**, leaving roughly **12–13GB** for model weights, KV cache, and runtime overhead. The M2 Pro's **200 GB/s memory bandwidth** is the hard ceiling for token generation speed, since generation is memory-bandwidth-bound: each token requires reading the entire model's weights once.

The practical model size limits at each quantization level break down clearly. At **Q4_K_M** (~4.5 bits per weight), a 7B model occupies ~3.8GB, an 8B model ~4.3GB, and a 14B model ~8.4GB. A **14B dense model at Q4_K_M is the practical maximum** for comfortable inference with usable context windows (4–8K tokens). Going larger requires either MoE models or extreme quantization: a 30B dense model at Q2_K takes ~10.5GB but suffers severe quality degradation (+0.87 perplexity). The sweet spot is **MoE architectures**—Qwen3-30B-A3B (30B total, 3B active) at Q4 fits in ~16GB and runs at an estimated 15–25 tok/s on M2 Pro, because only the 3B active parameters need to be read per token.

KV cache memory compounds the pressure significantly. For an 8B model with GQA (8 KV heads), the KV cache at FP16 consumes ~0.5GB at 4K context, ~1GB at 8K, and ~4.5GB at 32K. This means an 8B Q4 model (~4.3GB weights) plus 8K context (~1GB KV) plus OS overhead (~4GB) totals ~9.3GB—comfortable on 16GB. But a 14B Q4 model (~8.4GB) with 8K context pushes past 13GB, leaving minimal headroom. **Context windows beyond 8K tokens are impractical for models larger than 8B on 16GB without KV cache quantization.**

## MLX versus llama.cpp: the dual-backend question

Epistemos should support both backends. MLX is Apple's native ML framework, purpose-built for unified memory with lazy evaluation, zero-copy tensor operations, and optimized Metal compute shaders. llama.cpp offers the broadest model compatibility through GGUF and more mature speculative decoding support. Recent benchmarks show **MLX now matches or exceeds llama.cpp** on Apple Silicon: on M2 Pro with an 8B Q4 model, MLX achieves **24–38 tok/s generation** and **550–950 tok/s prompt processing** versus llama.cpp's 22–35 and 500–900 respectively. Academic benchmarks on M2 Ultra show MLX sustaining ~230 tok/s peak throughput versus llama.cpp's ~150.

MLX's memory advantages stem from three mechanisms. **Lazy evaluation** builds compute graphs without executing them, materializing arrays only when `mx.eval()` is called—this enables loading models larger than physical memory for operations like quantization conversion. **Wired memory support** (macOS 15+) locks model weights in physical RAM, preventing swap-induced slowdowns that destroy inference performance. **Rotating KV cache** (`--max-kv-size`) bounds memory growth for long conversations. One critical M2-specific optimization: MLX models stored as bf16 suffer emulated prefill because M1/M2 lack native bf16 support—**converting to fp16 via `mlx_lm.convert --dtype float16` significantly improves prefill speed**.

llama.cpp brings complementary strengths. Memory-mapped I/O (`mmap`) enables near-instant model loading (~0.9s for a Q4 7B versus ~4s for MLX). **Flash Attention is now the default** in recent builds and enables quantized KV cache modes: `--cache-type-k q8_0 --cache-type-v q8_0` halves KV cache memory with minimal quality loss (+0.05 perplexity), while Q4_0 KV cache reduces it to one-third. Threading should use only P-cores (`-t 8` on M2 Pro, which has 8 performance cores and 4 efficiency cores)—mixing E-cores decreases performance.

For Epistemos's Swift architecture, the recommended integration pattern uses a protocol-based backend abstraction. The existing **LocalLLMClient** library (tattn/LocalLLMClient) already implements this exact pattern with `LocalLLMClientLlama` and `LocalLLMClientMLX` backends sharing a common `textStream(from:)` interface. Alternatively, MLX integrates via `mlx-swift-lm` and llama.cpp via either the official SPM package or the `mattt/llama.swift` precompiled XCFramework.

## TurboQuant and the 2025–2026 quantization revolution

**TurboQuant is a real and significant breakthrough** from Google Research, presented at ICLR 2026. It is specifically a **KV cache compression algorithm**, not a weight quantization method. TurboQuant quantizes key-value cache entries down to 2–4 bits per coordinate with zero accuracy loss and no training required, achieving **6× memory reduction** in KV cache and **up to 8× speedup** in computing attention logits. It maintains 100% recall on needle-in-a-haystack retrieval at 3.5 bits per channel up to 104K tokens.

TurboQuant works in two stages. PolarQuant (stage 1) randomly rotates data vectors via orthogonal matrices, then applies MSE-optimal scalar quantization per coordinate. QJL (stage 2) projects the residual quantization error into a lower-dimensional space using just 1 bit per dimension, eliminating systematic bias in attention score calculations. The result is within ~2.7× of Shannon's information-theoretic lower bound.

For Epistemos on 16GB, TurboQuant's impact is transformative: it **complements weight quantization** (a Q4_K_M model with TurboQuant KV cache could support 4× longer contexts in the same memory). A community MLX implementation was reportedly built within hours of the blog post, tested on a 35B model on Apple Silicon with 6/6 needle-in-a-haystack scores. llama.cpp integration is under active discussion, with experimental 3.25 bits/val and 4.25 bits/val KV cache types already showing 4.9× and 3.8× compression in the Metal backend.

The broader quantization landscape for Apple Silicon is dominated by **GGUF K-quants** and **MLX native 4-bit**, because GPTQ, AWQ, AQLM, QuIP#, ExLlamaV2, and HQQ all require CUDA and are irrelevant for Mac inference. The GGUF quantization quality ladder is well-established:

- **Q4_K_M** (~4.5 bpw): The recommended default. +0.054 perplexity increase over FP16 for 7B models. Best quality-to-size ratio for most use cases.
- **Q5_K_M** (~5.3 bpw): Excellent quality (+0.014 perplexity), ~25% larger than Q4_K_M. Ideal when memory permits.
- **Q3_K_M** (~3.4 bpw): Fits larger models but with substantial quality loss (+0.244 perplexity).
- **Q6_K** (~6.6 bpw): Near-lossless, good for critical reasoning and coding tasks.
- **Q8_0** (~8.5 bpw): Effectively lossless, fastest decode due to simple dequantization.

**I-quants (IQ4_XS, IQ3_XS, etc.) should be avoided as defaults on Apple Silicon**—their lookup-table access pattern is reportedly ~50% slower than K-quants on Apple's memory architecture. They're useful only when squeezing an extra few hundred MB matters more than speed. Mixed-precision quantization (the _M and _L variants) already allocates higher precision to attention projections and output layers automatically.

**BitNet 1.58-bit models** are increasingly practical. Microsoft's BitNet-b1.58-2B-4T achieves performance within 1–2 points of full-precision models on benchmarks, with **90%+ memory savings** and **2.46× faster inference** than FP16. The Falcon3 family offers 1.58-bit models from 1B to 10B parameters. However, BitNet requires native ternary training—post-training quantization to sub-2-bit causes severe degradation. The `bitnet.cpp` inference engine runs on M2, and llama.cpp supports a TQ1_0 format for ternary weights.

## The model landscape: what to ship in Epistemos

The model ecosystem has consolidated around a few clear winners for 16GB Apple Silicon. **Qwen3.5-9B is the single best all-rounder**: it beats models 3–13× its size, includes native vision capabilities in all sizes, supports hybrid thinking/non-thinking modes, has excellent tool calling, and requires only ~6.6GB at Q4. It effectively replaced the prior generation's need for separate text, vision, and reasoning models.

For reasoning-heavy tasks, **DeepSeek-R1-Distill-Qwen-14B** (~8.5GB at Q4) delivers 93.9% on MATH-500 and 53.1% on LiveCodeBench with always-on chain-of-thought reasoning. **Phi-4-reasoning** (14B, ~8.5GB at Q4) approaches full DeepSeek-R1 performance on STEM tasks, outperforming the R1-Distill-Llama-70B on many benchmarks. For coding, **Qwen2.5-Coder-7B** (~4.5GB at Q4) is purpose-built and matches GPT-4o at the 32B size.

The "Qwen Opus Distilled" models are **community fine-tunes by "Jackrong"** of Qwen3.5 base models, distilled from Claude 4.6 Opus reasoning chains via SFT + LoRA. Available in 2B, 9B, 27B, and 35B-A3B variants, they feature structured `<think>` reasoning in Claude's style. These are not official Alibaba releases—quality may vary, and they are text-only (no vision). The 9B variant fits easily on 16GB.

For vision tasks, **Gemma 3 12B QAT** (~7GB at int4) provides Google's official quantization-aware-trained checkpoint with strong image understanding and 128K context. **Qwen3.5** natively supports vision in all sizes from 4B up. **Phi-4-multimodal** (5.6B) handles text, speech, and vision simultaneously.

**Llama 4 Scout does not fit on 16GB**—its 109B total MoE architecture requires ~54.5GB even at int4. There are no small dense Llama 4 variants; the smallest is Scout at 109B total. Llama 3.2 1B/3B remain available for basic tasks.

The recommended model tiers for Epistemos on 16GB:

| Model | Size at Q4 | Speed (est.) | Best for |
|---|---|---|---|
| Qwen3.5-9B | ~6.6 GB | ~30 tok/s | General use, vision, reasoning |
| DeepSeek-R1-Distill-Qwen-14B | ~8.5 GB | ~20 tok/s | Deep reasoning, math |
| Phi-4-mini (3.8B) | ~2.5 GB | ~50 tok/s | Fast responses, constrained tasks |
| Qwen2.5-Coder-7B | ~4.5 GB | ~35 tok/s | Code generation |
| Gemma 3 12B QAT | ~7 GB | ~25 tok/s | Vision, multilingual |
| Qwen3.5-4B | ~3.4 GB | ~45 tok/s | Lightweight multimodal |

Pre-quantized models are abundant. The **mlx-community** namespace on Hugging Face hosts hundreds of MLX-format models at 4-bit and 8-bit for all major families. For GGUF, **bartowski** provides the most comprehensive quantizations (every major model, IQ2_XXS through Q8_0), and **Unsloth** offers Dynamic 2.0 quantizations that selectively upcast important layers for near-SOTA quality at Q4.

## Speed optimization: extracting maximum performance

Token generation on M2 Pro follows a simple formula: **TG ≈ memory_bandwidth ÷ model_size_bytes**. With 200 GB/s bandwidth and a Q4 7B model at ~3.8GB, the theoretical maximum is ~52 tok/s; practical measurements show 30–40 tok/s due to quantization compute overhead and memory access patterns. Benchmarks on M2 Pro 16GB using Ollama show: deepseek-r1:1.5b at **83 tok/s**, llama3.2:3b at **56 tok/s**, gemma3:4b at **43 tok/s**, deepseek-r1:8b at **29 tok/s**, gemma3:12b at **18 tok/s**, and phi4:14b at **15 tok/s**. Models exceeding ~14GB (like mistral-small:24b at 1.18 tok/s) cause severe paging and are unusable.

**Speculative decoding** is the single largest speed optimization available. A small draft model (0.5B–1B) predicts candidate tokens that the main model verifies in a single batched forward pass, yielding **1.5–3× speedup** with mathematically identical output quality. Optimal pairings for 16GB: Llama 3.2 1B (~0.6GB) drafting for any 8B target gives ~1.83× speedup; Qwen 0.5B drafting for Qwen 14B gives up to 2.5× on structured tasks. Both MLX (via mlx-lm) and llama.cpp (`llama-speculative` binary) support this natively. LM Studio 0.3.10+ provides a UI toggle. The memory cost is small: a 1B draft model adds only ~0.6GB. Advanced methods like **EAGLE-3** achieve 2–6× speedup using lightweight draft heads attached to the target model, but these aren't yet in llama.cpp (available in vLLM and SGLang).

**Prompt caching** eliminates redundant computation across conversation turns. In llama.cpp server mode, `cache_prompt = true` reuses KV cache for identical token prefixes, reducing latency by **50%+** for multi-turn conversations. Disk-based slot persistence (`--slot-save-path`) enables session resumption. MLX supports prompt cache reuse for shared prefixes, though this is currently broken for hybrid-architecture models (sliding window attention, SSM layers) and works correctly only for pure full-attention architectures.

The optimal llama.cpp configuration for M2 Pro 16GB uses: `-ngl 999` (all layers on GPU), `-c 4096` (conservative context), `-b 512` (batch size), `-t 8` (P-cores only), `-fa 1` (flash attention), and `--cache-type-k q8_0` for quantized KV cache. For MLX, use `mx.compile()` for cached computation graphs and convert bf16 models to fp16 for M2 compatibility.

## Architecture patterns from LM Studio, Ollama, and Jan

The existing ecosystem offers proven patterns for Epistemos's model management layer. **LM Studio** uses a dual-backend architecture (llama.cpp for GGUF, a custom `mlx-engine` for MLX models) with three loading strategies: JIT (auto-load on request), manual CLI, and GUI. Its **TTL-based auto-unload** pattern is ideal for 16GB: models auto-evict after a configurable idle period, and new JIT-loaded models automatically replace previous ones. LM Studio's unified MLX engine conditionally loads a `VisionAddOn` from `mlx-vlm` for multimodal models.

**Ollama** uses Docker-inspired content-addressable blob storage with SHA256 digests, enabling deduplication of shared base weights across model variants—critical for disk efficiency when supporting dozens of models. Its Modelfile format provides declarative model configuration. Memory management uses a 5-minute default idle unload (`keep_alive` parameter), with the scheduler evaluating VRAM requirements before loading and queuing requests if memory is insufficient. A `waitForVRAMRecovery()` function polls GPU memory until 90% of expected VRAM is reported free after unload.

For Epistemos's Swift implementation, runtime memory monitoring uses `os_proc_available_memory()` for available system memory and `GPU.Memory.snapshot()` for MLX GPU allocations. Model unloading in MLX requires nil-ing all model references and calling `GPU.Memory.clearCache()`. In llama.cpp, `llama_model_free()` and `llama_context_free()` handle cleanup. The **swift-huggingface** package (official, released December 2025) provides resume-capable model downloads with Python-compatible caching at `~/.cache/huggingface/hub/`.

The model registry should store `ModelDescriptor` objects with estimated RAM requirements, capabilities (reasoning, coding, vision, tool calling), and compatibility badges (✅ "Runs great" / ⚠️ "May be slow" / ❌ "Not enough RAM") computed from `ProcessInfo.processInfo.physicalMemory` at launch. Auto-selection logic should default to the largest model that fits within 60% of available memory, leaving 40% for KV cache, framework overhead, and OS breathing room.

## Practical integration roadmap for Epistemos

Given the codebase audit's mention of the deferred "Omega and agent-based model-routing stacks," the inference layer should be designed as a clean, protocol-bounded module that connects through the existing Rust FFI bridge or directly via Swift. The recommended architecture layers three components: a **ModelRegistry** (Codable JSON database of model metadata), a **DownloadManager** (wrapping swift-huggingface with progress tracking), and an **InferenceEngine** (protocol-based backend abstraction dispatching to MLXBackend or LlamaCppBackend based on model format).

The critical memory management strategy for 16GB is **single-model-at-a-time by default** with TTL-based auto-unload. Keep a small draft model (1B, ~0.6GB) permanently loaded for speculative decoding when a larger model is active. Clear KV cache between conversations. Wire model memory on macOS 15+ to prevent swap. Default to Q4_K_M models in the 7–9B range (~4–6.6GB), reserving ~6GB for KV cache, framework overhead, and OS.

The combination of Qwen3.5-9B at Q4 (~6.6GB) with TurboQuant KV cache compression, speculative decoding via a 0.6B draft model, and prompt caching represents the optimal configuration for Epistemos on M2 Pro 16GB: strong reasoning, native vision, tool calling support, and an estimated 25–35 tokens/second with room for 8K+ context windows. This configuration leaves approximately 5GB of headroom for the existing Metal graph renderer, Rust engine, TextKit 2 editor, and OS—tight but workable given the audit's identification of memory optimization opportunities in the current codebase.

## Conclusion

The 16GB M2 Pro is far more capable for local LLM inference than its memory spec suggests, thanks to unified memory's zero-copy advantage, mature quantization ecosystems, and the MoE model revolution. Three developments change the equation for Epistemos specifically: **TurboQuant's runtime KV cache compression** makes longer contexts viable without additional model memory cost; **Qwen3.5-9B's multimodal capability at 6.6GB** eliminates the need for separate vision and text models; and **mlx-swift-lm's native Swift bindings** integrate cleanly with Epistemos's existing Swift+Rust architecture. The primary technical risks are KV cache memory pressure during long conversations (mitigated by TurboQuant and Q8 cache quantization), model-switching memory leaks (mitigated by explicit `GPU.Memory.clearCache()` lifecycle management), and the broken MLX prefix caching for hybrid-attention architectures (requires monitoring upstream fixes). The path from the current deferred Omega stack to a production inference layer is architecturally clean: the protocol-based dual-backend pattern, content-addressable model storage, and hardware-aware model selection UI are all proven patterns with open-source reference implementations.