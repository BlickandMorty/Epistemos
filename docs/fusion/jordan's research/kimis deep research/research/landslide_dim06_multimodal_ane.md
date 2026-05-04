# On-Device Multimodal AI on Apple Silicon: Deep Research Report

## 1. Executive Summary

Apple Silicon (M1–M4 series) has emerged as a uniquely capable platform for on-device multimodal AI inference, driven by three architectural advantages: **unified memory** (zero-copy CPU↔GPU data transfers), the **Apple Neural Engine (ANE)** (dedicated low-power AI accelerator), and the **MLX framework** (Apple’s native NumPy-like array framework optimized for Metal). This report surveys the state of vision-language models (VLMs), speech-to-text, real-time video analysis, and multimodal agent pipelines running entirely on Apple Silicon, with an emphasis on ANE-accelerated paths, model sizes, and measured performance numbers.

---

## 2. MLX-VLM: Vision-Language Models on Apple Silicon

### 2.1 Overview
**MLX-VLM** (by Blaizzy) is the de facto standard for running and fine-tuning Vision Language Models on Apple Silicon via Apple’s MLX framework [^2616^]. It supports 15+ model families including Qwen2-VL, LLaVA, Florence, Phi-4 Multimodal, Idefics3, Pixtral, PaliGemma, and Gemma 3n [^2616^] [^2655^].

### 2.2 Architecture & Key Features
- **Unified memory**: Image tensors and model weights share the same physical memory space, eliminating expensive CPU→GPU copies that plague discrete GPU setups [^2616^].
- **Modular adapter system**: Model-specific adapters in `mlx_vlm/models/` handle diverse VLM architectures (CLIP-style encoders, Perceiver cross-attention, early/late fusion) [^2616^].
- **Multi-modal inputs**: Images, audio, and video are supported via the `Multi-Modal Processor` [^2616^].
- **Quantization**: Native 4-bit and 8-bit quantization via `mlx-community` Hugging Face models; self-serve quantization via `mlx_vlm.convert` [^2616^].
- **Interfaces**: CLI, Gradio UI, Python API, and FastAPI server with OpenAI-compatible `/v1/chat/completions` endpoints [^2616^].

### 2.3 Performance Numbers

| Model / Config | Hardware | Speed | Notes |
|---|---|---|---|
| Qwen2.5-7B 4-bit | M1 Max + MLX | **63.7 tok/s** | 56% faster than Ollama GGUF [^290^] |
| Qwen2.5-14B 4-bit | M1 Max + MLX | **27.8 tok/s** | 28% faster than Ollama [^290^] |
| Qwen2.5-32B 4-bit | M1 Max + MLX | **12.5 tok/s** | 23% faster than Ollama [^290^] |
| LLaVA v1.5-7B Q4_K_M | Mac mini M2 24GB | **15.2 tok/s** decode; TTFT 12.7s | Via llama.cpp [^2646^] |
| LLaVA 7B | Mac M1 (Ollama) | **55.7 tok/s** | Very fast decode [^2643^] |
| MiniCPM-V 2.6 | iPad Pro M4 (llama.cpp) | **16–18 tok/s** | Real-time video capable [^2648^] |
| MiniCPM-V 4.0 | iPhone 16 Pro Max | **<2s first token; >17 tok/s** decode | No heating issues [^2642^] |
| MonkeyOCR (Qwen2.5-VL) | MacBook M4 Pro | **15–18s** per complex doc (MLX-VLM) | 3× faster than PyTorch CPU [^2657^] |

### 2.4 Omni Model Support
MLX-VLM explicitly supports **Omni Models**—VLMs with audio and video support—such as MiniCPM-o, Phi-4 Multimodal, and Gemma 3n [^2617^] [^2655^]. This enables pipelines that simultaneously process video frames, audio waveforms, and text prompts within a single model invocation.

### 2.5 vllm-mlx: Production Serving on Apple Silicon
`vllm-mlx` brings vLLM-style inference to Apple Silicon with **continuous batching, paged KV cache, prefix caching, and SSD-tiered cache** [^267^]. It achieves **21–87% higher throughput** than llama.cpp on Apple Silicon [^2656^] and exposes OpenAI + Anthropic API endpoints from a single process. It also supports audio (TTS/STT) via `mlx-audio` integration [^267^].

---

## 3. Core ML Multimodal Pipelines (Vision + Text)

### 3.1 Core ML as the Native Apple Stack
**Core ML** is Apple’s framework for deploying ML models on iOS, macOS, watchOS, and tvOS, optimized to run on CPU, GPU, and ANE with automatic compute-unit selection [^2621^]. For multimodal models, Core ML enables running vision encoders and text decoders as a single (or chunked) pipeline directly on the ANE.

### 3.2 Gemma 4 E2B: A Core ML Multimodal Reference
The **Gemma 4 E2B** model (2.3B effective parameters with Per-Layer Embeddings) is one of the most advanced Core ML-native multimodal deployments:
- **Inputs**: text, image (native 384×384 encoder, 196 tokens/image), audio (12-layer Conformer encoder), video (64 tokens/frame) [^2623^]
- **Context length**: 2048 tokens; Sliding Window Attention (28/35 layers are O(W)) [^2623^]
- **Performance**: **31.6 tok/s** on iPhone 17 Pro (default 4-chunk decode); **34.2 tok/s** with `LLM_3CHUNK=1` optimization [^2623^] [^2652^]

### 3.3 Qwen3-VL 2B on Core ML
**Qwen3-VL 2B** has been converted to Core ML with:
- DeepStack injection at L0/1/2 and interleaved mRoPE for 196 image tokens [^2623^]
- 28-layer GQA text backbone shipped as 6 INT8 body chunks + chunk_head + raw fp16 embed sidecar that Swift mmaps [^2623^]
- Vision tower reuses Qwen3-VL’s native ViT [^2623^]

### 3.4 Chunking for ANE Compatibility
A critical technique for running deep transformers on the ANE is **model chunking**. Directly converting a deep Transformer as a single Core ML model causes the MIL compiler to fail silently at ~8–10 connected Attention layers [^2652^]. The Gemma 4 E2B implementation divides the model into four chunks, each an independent `.mlpackage`, with a Swift `ChunkedEngine` accessing them sequentially. Each `MLModel.prediction` call incurs ~2.3 ms of XPC/dispatch overhead, so 4 chunks impose a ~9.2 ms baseline per token [^2652^].

---

## 4. ANE-Accelerated Image Understanding

### 4.1 What the ANE Provides
The **Apple Neural Engine (ANE)** is a dedicated NPU integrated into M-series chips, engineered for high-efficiency, low-power neural network inference [^2621^] [^2624^]. It excels at convolutions, matrix multiplies, and attention operations while consuming far less power than the GPU [^2633^].

### 4.2 ANE Optimization Principles (Apple Research)
Apple’s research team published principles for deploying Transformers on the ANE [^2633^]:
- **Fusing operations**: Combine SwiGLU, RMSNorm+Mul+Add into single kernels where possible.
- **Conv1×1 for matmul**: The ANE uses Conv1×1 for matrix multiplication, which carries an effective ~3× penalty vs. GPU MMA (matrix multiply accumulate) [^2652^].
- **Stateless I/O**: Core ML enforces stateless I/O; KV cache must be passed explicitly as inputs/outputs, unlike GPU frameworks that can maintain state in buffers [^2652^].
- **Pre-computed RoPE**: Compute rotary positional embeddings offline to avoid redundant ops [^2623^].
- **Quantization**: INT4/INT8 weights drastically reduce memory bandwidth, the ANE’s primary bottleneck [^2633^].

### 4.3 Case Study: distilbert on ANE
Apple’s optimized reference implementation of Hugging Face distilbert achieved **up to 10× faster inference** and **14× less memory** vs. baseline Core ML on iPhone 13 [^2633^]. At sequence length 128, batch size 1:
- **Latency**: 3.47 ms at 0.454W; 9.44 ms at 0.072W [^2633^]
- This demonstrates that ANE-optimized transformers can rival server-side ASIC performance in latency, at orders-of-magnitude lower power [^2633^].

### 4.4 Gemma 4 on ANE: From 11 to 31 tok/s
The MLBoy/CoreML-LLM project achieved **99.78% ANE operation placement** (7,294 of 7,310 ops) for Gemma 4 E2B by iteratively eliminating CPU-fallback ops [^2652^]. The key insight: whether the remaining ~16 ops could be placed on ANE determined the difference between **11 tok/s** and **31 tok/s** [^2652^].

| Backend | Gemma 4 E2B on iPhone 17 Pro | Speed |
|---|---|---|
| Core ML ANE (optimized) | 99.78% ANE ops | **31 tok/s** [^2652^] |
| LiteRT-LM (Metal GPU) | Same device | **56.5 tok/s** [^2652^] |
| llama.cpp (Metal) | Same device | **38 tok/s** [^2652^] |

The 1.8× gap vs. LiteRT is structurally explained by: (1) 2.0× from single Metal command buffer vs. 4 XPC calls, (2) 1.3× from kernel fusion, (3) 1.2× from GPU native 8×8 MMA, (4) 1.1× from stateful KV buffer, (5) 1.1× from weight expansion [^2652^].

---

## 5. On-Device Speech-to-Text (Whisper on ANE)

### 5.1 Whisper.cpp + CoreML
**whisper.cpp** (Georgi Gerganov’s C/C++ port of OpenAI Whisper) supports Core ML acceleration on Apple Silicon, routing the encoder inference to the ANE [^2662^] [^2665^].

### 5.2 Performance: Real-Time Factors
Real-time factor (RTF) measures transcription speed relative to audio duration. RTF < 1.0 means faster-than-real-time.

| Model | M1 | M2 | M3 | Notes |
|---|---|---|---|---|
| Tiny | ~30× RT | ~35× RT | ~40× RT | Fastest [^2665^] |
| Base | ~15× RT | ~18× RT | ~22× RT | Good balance [^2665^] |
| Small | ~8× RT | ~10× RT | ~12× RT | Accurate [^2665^] |
| Medium | ~3× RT | ~4× RT | ~5× RT | High accuracy [^2665^] |
| Large-v3-turbo + CoreML | — | — | ~7× RT (RTF ~0.14) | ~7s audio in ~1s [^2651^] |

CoreML provides **2–3× faster** transcription than CPU-only and, when combined with Metal, reaches **8–12× faster** than CPU baseline [^2622^].

### 5.3 MLX-Audio: TTS & STT on MLX
**mlx-audio** (also by Blaizzy, the mlx-vlm author) is a speech library built on MLX for Apple Silicon [^2645^] [^2639^]. It supports:
- **TTS**: Dia-1.6B, multilingual models [^2641^]
- **STT**: Speech-to-text via Whisper-family models on MLX [^2645^]
- **STS**: Speech-to-speech [^2645^]
- **Quantization**: 3-bit, 4-bit, 6-bit, 8-bit [^2645^]
- **Swift package**: For iOS/macOS native integration [^2645^]

A streamlined local TTS demo using mlx-audio runs entirely on Apple Silicon with ~4GB disk space and a web interface [^2641^].

---

## 6. Real-Time Video Analysis on Apple Silicon

### 6.1 Video as a Multimodal Input
MLX-VLM supports video inputs by processing multiple frames through the vision encoder and projecting them into the language model [^2616^] [^2655^]. Video caching follows the same content-based approach as images: identical video frames map to the same cache entries, enabling speedups for repeated video analysis [^377^].

### 6.2 Performance Scaling with Frame Count
Higher frame counts increase latency but provide richer temporal understanding. Benchmarks on vllm-mlx show:
- **32-frame videos** achieve **24.7× speedup** on cache hits despite larger cache entries [^377^].
- Vision embedding caching provides **7.8× speedup** by eliminating the vision encoder forward pass; KV cache reuse adds **2.4×**; combined **19×** speedup [^377^].

### 6.3 MiniCPM-V: Real-Time Video on iPad
MiniCPM-V 2.6 (8B params) was the first end-side MLLM to support **real-time video understanding on iPad** [^2648^]. With llama.cpp/ollama forks, it achieves **16–18 tok/s** on iPad Pro M4 [^2648^].

MiniCPM-V 4.0 (4.1B params) further improves this with **<2s first-token delay and >17 tok/s decoding on iPhone 16 Pro Max** without heating [^2642^]. It outperforms GPT-4.1-mini on OpenCompass (69.0 avg score) [^2642^].

---

## 7. Multi-Modal Agent Capabilities (See + Hear + Reason)

### 7.1 The Omni-Model Pattern
A true multimodal agent must simultaneously process:
1. **Vision**: Camera frames, screenshots, documents (via ViT/SigLIP encoder)
2. **Audio**: Speech commands, environmental sound (via Conformer/Whisper encoder)
3. **Text**: Reasoning, planning, response generation (via transformer decoder)

Apple Silicon’s unified memory is uniquely suited for this: all three modalities reside in the same address space, accessible by CPU, GPU, and ANE without copies [^2616^].

### 7.2 Models Supporting See+Hear+Reason

| Model | Params | Modalities | Apple Silicon Support |
|---|---|---|---|
| **Phi-4 Multimodal** | — | Vision + Audio + Text | MLX-VLM [^2655^] |
| **MiniCPM-o 2.6/4.5** | 8B / 4.5B | Vision + Speech + Audio + Text | llama.cpp, MLX, vLLM [^2642^] |
| **Gemma 4 E2B** | 2.3B eff. | Text + Image + Audio + Video | CoreML-LLM (ANE-native) [^2623^] |
| **Qwen3-VL 2B** | 2B | Text + Image | Core ML (INT8 chunks) [^2623^] |
| **Gemma 3n** | — | Multimodal | MLX-VLM [^2655^] |

### 7.3 MLX Omni Server: Unified Local API
**MLX Omni Server** and **MLX Engine** provide OpenAI-compatible REST endpoints for chat, TTS, STT, and image generation—all running locally on Apple Silicon [^2660^] [^2661^]. This enables building agents that:
- Receive voice commands (`/v1/audio/transcriptions`)
- Analyze images/video (`/v1/chat/completions` with vision)
- Respond via text or synthesized speech (`/v1/audio/speech`)
- Use function calling and structured output [^2660^]

### 7.4 Putting It All Together: A Local Agent Pipeline
A hypothetical on-device agent on an M4 Mac with 36GB RAM could run:
1. **Audio input**: whisper.cpp CoreML (~7× real-time STT) [^2651^]
2. **Vision input**: Qwen2.5-VL 7B 4-bit via MLX-VLM (~15s per complex frame) [^2657^]
3. **Reasoning**: Phi-4 Multimodal or Gemma 4 E2B via Core ML ANE (~31 tok/s) [^2623^]
4. **Audio output**: mlx-audio TTS (Dia-1.6B) [^2641^]
All within unified memory, with no cloud dependency.

---

## 8. Vision Encoder Reuse & Prefix Caching

### 8.1 The Problem
Vision encoders are expensive. Each image can add thousands of "vision tokens" to the KV cache. Without reuse, identical images force full re-encoding for every query [^2485^].

### 8.2 Content-Based Image Caching in vllm-mlx
The **vllm-mlx** framework implements **content-based prefix caching** for vision embeddings [^377^]:
- On cache miss: normal prefilling; both encoder cache and KV cache are stored.
- On cache hit (same image hash): bypasses the vision encoder entirely; reuses stored encoder cache + KV cache.

Measured speedups on Apple Silicon:
- **Multi-turn image conversations**: Latency drops from **21.7 s to <1 s** (28× speedup) [^377^].
- **Vision embedding cache alone**: **7.8× speedup** [^377^].
- **KV cache reuse alone**: **2.4× speedup** [^377^].
- **Combined**: **19× speedup** [^377^].

### 8.3 VLCache: Computing 2% Vision Tokens, Reusing 98%
**VLCache** (arXiv 2025) is a research system for VLM cache reuse that stores vision encoder outputs and KV cache per image patch [^2625^]. On repeated images:
- Reuses 98% of vision tokens directly.
- Selectively recomputes only **2–5%** of early image tokens per layer to preserve accuracy.
- Achieves **1.2× to 16× TTFT speedup** depending on model and image token length [^2625^].

Key insight: cumulative error propagates from initial tokens to later ones, so recomputing a small fraction of early tokens effectively corrects the entire sequence [^2625^].

### 8.4 LMCache for Multimodal vLLM
LMCache extends prefix caching to multimodal models in vLLM V1 by hashing image-side tokens (`mm_hashes`) and caching their KV pairs [^2485^]. With Qwen-VL-2B:
- Second request with same image: **~100% KV hit rate**; streamed in **~1 s vs. ~18 s** cold-start [^2485^].
- This proves the same economics apply to vision prompts as to text-only workloads (where LMCache yields 3–10× TTFT speedups) [^2485^].

### 8.5 LM Studio’s Unified MLX Engine
LM Studio’s unified MLX engine architecture (v0.17.0+) weaves `mlx-lm` text models with `mlx-vlm` vision "add-ons" [^2619^]. This enables:
- **Prompt caching for text-only chats with VLMs**: previously exclusive to text-only LLMs, now available for VLMs, resulting in "drastically faster follow-up responses" [^2619^].
- Cross-turn KV cache for sequential generation with vision models [^2664^].

---

## 9. MobileLLM & Small Multimodal Models

### 9.1 MobileLLM Family (Meta)
**MobileLLM** is a family of sub-billion-parameter models (125M, 350M, 600M, 1B) optimized for on-device inference [^2634^]. Key design choices:
- **Deep-and-thin architecture**: More layers, smaller embeddings (better for mobile SoCs).
- **SwiGLU activation** and **Grouped Query Attention (GQA)** [^2634^].
- **Embedding/layer sharing** to reduce model size [^2634^].
- MobileLLM-R1 adds reasoning capabilities at 140M, 360M, and 950M sizes [^2632^].

**Performance**: The 950M model achieves 74.0 on MATH and 19.9 on LiveCodeBench, slightly outperforming Qwen3-0.6B [^2632^].

### 9.2 Gemma 3 4B / Gemma 4 E2B (Google)
- **Gemma 3 4B**: 4B parameters, 131K context, multimodal input support [^2663^].
- **Gemma 4 E2B**: 2.3B effective parameters with Per-Layer Embeddings (PLE); 2048 context; native text+image+audio+video on ANE at **31.6 tok/s** [^2623^] [^2652^].
- **Gemma 4 E4B**: 42-layer decoder, ~4B effective params, 100% ANE-resident, text-only, 5.5GB INT4 [^2623^].

### 9.3 SmolVLM2 / HuggingSnap
**SmolVLM2** is a compact open multimodal model that accepts arbitrary sequences of images, videos, and text. It powers **HuggingSnap**, an iOS app that runs entirely on-device to identify places and objects [^2627^].

### 9.4 Competitive Landscape of Small Multimodal Models

| Model | Params | License | Best For |
|---|---|---|---|
| MobileLLM-R1 950M | 950M | FAIR NC (non-commercial) | On-device reasoning [^2632^] |
| Gemma 3 270M | 270M | Permissive | Extreme power savings (25 convos < 1% battery) [^2632^] |
| Qwen3-0.6B | 600M | Apache-2.0 | Commercial on-device reasoning [^2632^] |
| MiniCPM-V 4.0 | 4.1B | Apache-2.0 | Vision+text on phones (<2s TTFT) [^2642^] |
| Gemma 4 E2B | 2.3B eff. | Gemma ToU | Full multimodal on ANE [^2623^] |
| OLMoE.Swift | — | Apache-2.0 | On-device chat (flight mode capable) [^2627^] |

---

## 10. Florence-2, LLaVA, and MiniCPM-V on Apple Silicon

### 10.1 Florence-2 (Microsoft)
**Florence-2** is Microsoft’s unified visual language model for object detection, segmentation, captioning, and grounding [^2644^].
- **Architecture**: DaViT vision encoder + encoder-decoder transformer (6+6 layers for base; 12+12 for large) [^2644^].
- **Training**: Multi-task learning on FLD-5B (5.4B annotations on 126M images) [^2644^].
- **MLX-VLM support**: Available via `mlx-community` conversions; runs natively on Apple Silicon [^2616^].

### 10.2 LLaVA on Apple Silicon
**LLaVA** (Large Language and Vision Assistant) is one of the most widely supported open VLMs on Apple Silicon:
- **MLX-VLM**: `mlx-community/llava-1.5-7b-4bit` runs via `mlx_vlm.generate` CLI [^2616^].
- **llama.cpp / Ollama**: LLaVA v1.5-7B Q4_K_M achieves **15.2 tok/s** decode on Mac mini M2 24GB [^2646^].
- **LM Studio**: Unified MLX engine supports LLaVA with prompt caching for faster follow-ups [^2619^].
- **vllm-mlx**: Supports LLaVA with continuous batching and prefix caching [^267^].

### 10.3 MiniCPM-V on Apple Silicon
**MiniCPM-V** is explicitly designed for end-side (on-device) multimodal deployment [^2648^] [^2642^]:
- **MiniCPM-V 2.6** (8B params): Surpasses GPT-4V on single-image, multi-image, and video understanding. Real-time video on iPad via llama.cpp at **16–18 tok/s** [^2648^].
- **MiniCPM-V 4.0** (4.1B params): Outperforms GPT-4.1-mini on OpenCompass. Runs on iPhone 16 Pro Max with **<2s TTFT and >17 tok/s** [^2642^].
- **MiniCPM-o 2.6/4.5**: Full-duplex omni-modal (vision + speech + audio + text) live streaming on phones [^2642^].
- **iOS App**: Open-source iOS app available; models run directly on iPhone/iPad [^2637^] [^2642^].

---

## 11. ANE Optimization Techniques for Multimodal Inference

### 11.1 The ANE Compiler & Dispatch Stack
The ANE is accessed through Core ML’s MIL (Model Intermediate Language) compiler. Key empirical constraints [^2652^]:
- **Graph depth limit**: ~8–10 connected Attention layers before silent MIL compiler failure.
- **Dispatch overhead**: ~2.3 ms per `MLModel.prediction` call (XPC to `ANECompilerService` daemon + IOKit queue placement).
- **Statelessness**: KV cache must be explicit I/O; no persistent state between calls.

### 11.2 Optimization Checklist
1. **Chunk deep models**: Split >10-layer transformers into independent Core ML chunks [^2652^].
2. **Eliminate CPU fallbacks**: Use `MLComputePlan` (Core ML 7+) to audit `preferredComputeUnit`; rewrite ops that route to CPU [^2652^].
3. **Use ANE-friendly ops**: `torch.softmax` → ANE; `exp/sum/div` manual softmax → CPU. `torch.nn.functional.gelu(approximate="tanh")` → ANE; strict GELU → CPU [^2652^].
4. **Pre-compute RoPE/cat-trick RMSNorm**: Avoid redundant per-token compute [^2623^].
5. **Quantize aggressively**: INT4 for weights, INT8 for activations where possible. Gemma 4 E2B ships at 3.1GB INT4 [^2623^].
6. **Minimize chunk count**: Each chunk adds 2.3 ms dispatch. Collapsing chunk 2+3 boosted Gemma 4 from 31.6 to 34.2 tok/s [^2623^].
7. **Conv2d Linear trick**: Replace Linear layers with Conv2d where the ANE compiler prefers them [^2623^].

### 11.3 MLX vs. Core ML ANE Trade-offs
| Aspect | MLX (Metal GPU) | Core ML ANE |
|---|---|---|
| **Ease of use** | Python-native, HuggingFace compatible | Requires coremltools conversion |
| **Model depth** | Unlimited | ~8–10 layers per chunk |
| **Peak throughput** | Higher (e.g., 56.5 tok/s Gemma 4 GPU) | Lower (e.g., 31 tok/s Gemma 4 ANE) |
| **Power efficiency** | Good | Excellent (ANE idles GPU) |
| **Quantization** | 3/4/6/8-bit via MLX | INT4/INT8 via coremltools |
| **Server features** | vllm-mlx: continuous batching, prefix cache | ChunkedEngine manual orchestration |
| **Unified memory** | ✅ Zero-copy | ✅ Zero-copy |

The optimal deployment often uses **both**: Core ML ANE for always-on, battery-sensitive tasks (e.g., wake-word, background transcription) and MLX on Metal for latency-sensitive interactive inference (e.g., chat, video analysis) [^2652^] [^290^].

---

## 12. Conclusion & Recommendations

Apple Silicon has matured into a premier platform for on-device multimodal AI. The convergence of MLX (Python-native, research-friendly), Core ML (production-native, ANE-accelerated), and unified memory enables pipelines that were impossible on consumer hardware just two years ago.

**Key takeaways:**
1. **MLX-VLM** is the fastest path to running state-of-the-art VLMs (Qwen2-VL, LLaVA, MiniCPM-V, Florence-2) on Macs, with 30–50% higher throughput than cross-platform alternatives [^290^].
2. **Core ML + ANE** is the optimal path for iOS deployment and battery-sensitive always-on inference, with Gemma 4 E2B serving as a blueprint for fully ANE-resident multimodal models at 31 tok/s [^2623^] [^2652^].
3. **Vision encoder caching** (prefix caching, VLCache, LMCache) is essential for multi-turn agents; it delivers 10–30× latency reduction on repeated images [^377^] [^2625^].
4. **Whisper + CoreML** achieves 7× real-time transcription, making always-on STT practical [^2651^].
5. **Small models** (MiniCPM-V 4.0, Gemma 4 E2B, MobileLLM) now deliver GPT-4V-class capabilities on phones, with sub-2-second first-token latency [^2642^] [^2623^].
6. **Omni models** (MiniCPM-o, Phi-4 Multimodal, Gemma 3n) enable true see+hear+reason agents, all runnable locally via MLX or Core ML [^2655^] [^2642^].

**For developers building on-device multimodal agents:**
- Prototype with **MLX-VLM** on macOS for rapid iteration.
- Deploy to iOS via **Core ML** conversion for ANE efficiency.
- Cache vision embeddings aggressively across turns and requests.
- Use **vllm-mlx** or **MLX Omni Server** for OpenAI-compatible local API endpoints.
- Combine **mlx-audio** (TTS/STT) with **mlx-vlm** (vision+text) for complete multimodal loops.

---

## References

[^2616^]: MLX-VLM: Running Vision Language Models Locally on Apple Silicon. Starlog, 2026. https://starlog.is/articles/llm-engineering/blaizzy-mlx-vlm/

[^2617^]: Running VLMs / Multimodal Models on Mac with Apple's MLX. Medium, 2025. https://medium.com/@manyi.yim/running-vlms-multimodal-models-on-mac-with-apples-mlx-3de220a72e05

[^2618^]: Fine-Tune Industrial Vision-Language Models on Apple Silicon with MLX-VLM. Atomic Loops. https://www.atomicloops.com/technologies/llm-engineering-and-fine-tuning/fine-tune-industrial-vision-language-models-on-apple-silicon-with-mlx-vlm-and-hugging-face-transformers

[^2619^]: Introducing the unified multi-modal MLX engine architecture in LM Studio. LM Studio, 2025. https://lmstudio.ai/blog/unified-mlx-engine

[^2620^]: Vision AI on Apple Silicon: A Practical Guide to MLX-VLM. DZone, 2025. https://dzone.com/articles/vision-ai-apple-silicon-guide-mlx-vlm

[^2621^]: Understanding Apple's Neural Engine: AI Revolution with M-Series Processors. SimplifyCpp. https://simplifycpp.org/books/Assembly/Understanding_Apple_s_Neural_Engine_AI_Revolution_with_M_Series_Processors.pdf

[^2622^]: Whisper Speech-to-Text Setup - Voice Mode. https://voice-mode.readthedocs.io/en/latest/guides/whisper-setup/

[^2623^]: CoreML-Models README (Gemma 4 E2B, Qwen3-VL 2B). MLBoy, 2026. https://github.com/john-rocky/CoreML-Models/blob/master/README.md

[^2624^]: Everything we actually know about the Apple Neural Engine (ANE). Hollance GitHub, 2020. https://github.com/hollance/neural-engine

[^2625^]: VLCache: Computing 2% Vision Tokens and Reusing 98% for Vision–Language Inference. arXiv, 2025. https://arxiv.org/html/2512.12977v1

[^2627^]: Awesome Mobile LLMs (stevelaskaridis). GitHub, 2026. https://github.com/stevelaskaridis/awesome-mobile-llm

[^2628^]: MobileLLM-R1: Tiny Models Can Also Reason! The Kaitchup, 2025. https://kaitchup.substack.com/p/mobilellm-r1-tiny-models-can-also

[^2632^]: Meta's new small reasoning model shows industry shift toward tiny AI. VentureBeat, 2025. https://venturebeat.com/ai/metas-new-small-reasoning-model-shows-industry-shift-toward-tiny-ai-for

[^2633^]: Deploying Transformers on the Apple Neural Engine. Apple Machine Learning Research, 2022. https://machinelearning.apple.com/research/neural-engine-transformers

[^2634^]: On-device AI — MobileLLM: Optimizing Sub-billion Parameter Language Models. Medium, 2024. https://medium.com/byte-sized-ai/on-device-ai-mobilellm-optimizing-sub-billion-parameter-language-models-for-on-device-use-cases-885cc311daa6

[^2637^]: MiniCPM-V 4.0 and MiniCPM-o 2.6: Revolutionizing On-Device Multimodal AI. https://www.xugj520.cn/en/archives/minicpm-on-device-ai.html

[^2638^]: MLX-Audio download. SourceForge, 2026. https://sourceforge.net/projects/mlx-audio.mirror/

[^2639^]: mlx-audio: Speech Processing Library on Apple Silicon. Dev.to, 2026. https://dev.to/stelixx-insider/mlx-audio-speech-processing-library-on-apple-silicon-1254

[^2641^]: local-text-to-speech-mlx (memextech). GitHub, 2025. https://github.com/memextech/local-text-to-speech-mlx

[^2642^]: MiniCPM-o: A Gemini 2.5 Flash Level MLLM for Vision, Speech, and Full-Duplex Multimodal Live Streaming on Your Phone. OpenBMB, 2025. https://github.com/OpenBMB/MiniCPM-o

[^2643^]: Multimodal LLMs on a Mac M1: A Quick Test. Medium, 2024. https://prashantdandriyal.medium.com/multimodal-llms-on-a-mac-m1-a-quick-test-5397bd33a6b6

[^2644^]: Introducing Florence-2: Microsoft's Latest Multi-Modal, Compact Visual Language Model. Datature, 2024. https://datature.com/blog/introducing-florence-2-microsofts-latest-multi-modal-compact-visual-language-model

[^2645^]: mlx-audio (Blaizzy). GitHub, 2026. https://github.com/Blaizzy/mlx-audio

[^2646^]: LLaVA 1.5 7B on Mac mini M2 24GB. WillItRunAI, 2023. https://willitrunai.com/can-run/llava-1.5-7b-on-m2-24gb

[^2648^]: MiniCPM-V: A GPT-4V Level MLLM for Single Image, Multi Image and Video on Your Phone. OpenBMB, 2023. https://github.com/QAdottech/MiniCPM-V

[^2651^]: whisper.cpp Local Inference on Mac: Offline Transcription with CoreML & Apple Silicon. Neosophie, 2026. https://neosophie.com/en/blog/20260218-local-whisper

[^2652^]: Running Gemma4 on Apple Neural Engine. MLBoy Medium, 2026. https://rockyshikoku.medium.com/running-gemma4-on-apple-neural-engine-79fa0cb39dd2

[^2655^]: MLX-VLM: Vision Language Models on Apple Silicon. Pyshine, 2026. https://pyshine.com/MLX-VLM-Vision-Language-Models-Apple-Silicon/

[^2656^]: Research: vllm-mlx on Apple Silicon achieves 21% to 87% higher throughput than llama.cpp. Reddit r/LocalLLaMA, 2026. https://www.reddit.com/r/LocalLLaMA/comments/1qssxhx/research_vllmmlx_on_apple_silicon_achieves_21_to/

[^2657^]: MonkeyOCR-MLX: Apple Silicon Optimized OCR. HuggingFace, 2025. https://huggingface.co/Jimmi42/MonkeyOCR-Apple-Silicon

[^2660^]: mlxengine: Run powerful AI models locally on your Mac. GitHub, 2025. https://github.com/justrach/mlxengine

[^2661^]: mlx-omni-server 0.3.6. PyPI, 2025. https://pypi.org/project/mlx-omni-server/0.3.6/

[^2662^]: whisper.cpp Core ML support. HuggingFace Spaces, 2024. https://huggingface.co/spaces/natasa365/whisper.cpp/blob/51a70ff562d542957340414f6539b84b6cad0bb2/README.md

[^2664^]: Cross-turn KV cache for VisionModelKit sequential generation. LM Studio mlx-engine, 2026. https://github.com/lmstudio-ai/mlx-engine/issues/287

[^2665^]: Why Whisper.cpp on Apple Silicon Changes Everything. Sotto, 2025. https://sotto.to/blog/whisper-cpp-apple-silicon

[^267^]: vllm-mlx: Apple Silicon MLX Backend for vLLM. GitHub, 2025. https://github.com/waybarrios/vllm-mlx

[^290^]: Local LLM Speed: RTX 3060, Qwen2 & Llama Benchmark Results. https://singhajit.com/llm-inference-speed-comparison/

[^377^]: Native LLM and MLLM Inference at Scale on Apple Silicon. arXiv, 2026. https://arxiv.org/pdf/2601.19139

[^2485^]: LMCache Extends Its Turbo-Boost to Multimodal Models in vLLM V1. LMCache Blog, 2025. https://blog.lmcache.ai/en/2025/07/03/lmcache-extends-its-turbo-boost-to-multimodal-models-in-vllm-v1/
