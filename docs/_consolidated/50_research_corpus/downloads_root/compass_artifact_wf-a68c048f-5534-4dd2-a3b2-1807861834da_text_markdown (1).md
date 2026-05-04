# Optimizing LLMs for Epistemos on a 16GB M2 Pro Mac

Running 30B+ parameter models on a 16GB M2 Pro is technically possible but operationally marginal — **8B–14B models at 4-bit quantization deliver the best real-world experience**, hitting 15–30 tokens/sec with room for adequate context windows. This report provides the complete technical playbook for Epistemos: which models fit, how to squeeze maximum performance from Apple Silicon's unified memory, how TurboQuant can slash KV cache memory by 6×, which inference backends to use in Swift, and the bleeding-edge techniques that will matter most in 2026.

Epistemos is an ambitious local-first cognitive operating system built on Swift + Rust + Metal, with a multi-stage AI pipeline routing between local and cloud inference tiers. The architecture's `TriageService`, `ReasoningLoop`, and `MLXInferenceService` components need an inference backend that respects the 16GB memory ceiling while maximizing generation speed. Everything below is grounded in what works today, with specific commands, code, and download links.

---

## The hard math of fitting models in 16GB unified memory

Apple Silicon's unified memory architecture means CPU, GPU, and Neural Engine share a single **16GB LPDDR5 pool at ~200 GB/s bandwidth**. macOS itself consumes 3–4GB, leaving roughly **12–13GB for model weights, KV cache, and inference overhead**. The GPU can access about 66% of total RAM by default (~10.7GB), though this limit is adjustable.

**Token generation speed is fundamentally bandwidth-bound.** The formula is straightforward: `tok/s ≈ memory_bandwidth / model_size_in_memory`. For a 5GB Q4_K_M model on M2 Pro: `200 GB/s ÷ 5 GB ≈ 40 tok/s theoretical`, with real-world throughput at 50–70% of that (~20–28 tok/s). This means **smaller quantized models generate tokens faster**, not just because they fit — but because less data needs to traverse the memory bus per token.

The KV cache grows linearly with context length and can consume gigabytes at longer contexts. The formula: `KV_bytes = 2 × n_kv_heads × head_dim × n_layers × context_length × bytes_per_element`. For Qwen2.5-32B with FP16 at 32K context, that's **~8.6GB just for the cache** — more than the model leaves room for on 16GB. This is why context length is the critical tuning knob alongside quantization.

### Quantization options for 32B models on 16GB

| Quantization | File size (Qwen 32B) | Fits 16GB? | Quality | Recommendation |
|---|---|---|---|---|
| Q4_K_M | 19.9 GB | ❌ No | Excellent | Need 24GB+ |
| IQ4_XS | 17.7 GB | ❌ No | Very good | Need 24GB+ |
| Q3_K_M | 15.9 GB | ⚠️ Barely | Usable | Swap-heavy, ≤2K context |
| IQ3_XS | 13.7 GB | ⚠️ Tight | Noticeable loss | 2–4K context max |
| Q2_K | 12.3 GB | ✅ Fits | Severe loss | Not recommended |

**The honest verdict**: 32B models on 16GB are a science experiment, not a production configuration. Community consensus is clear — run **8B at Q4_K_M (~5GB) with 8K+ context** for a smooth experience, or **14B at Q4_K_M (~9GB) with 4K context** for better quality at acceptable speed.

### Overriding the GPU memory limit

macOS caps GPU wired memory at ~66% of total RAM by default. Override this to reclaim headroom:

```bash
# Allow 13GB of 16GB for GPU (aggressive — leaves 3GB for OS)
sudo sysctl iogpu.wired_limit_mb=13312

# More conservative: 12GB
sudo sysctl iogpu.wired_limit_mb=12288

# Persist across reboots (add to /etc/sysctl.conf)
echo "iogpu.wired_limit_mb=13312" | sudo tee -a /etc/sysctl.conf
```

Verify the change took effect by checking `ggml_metal_init: recommendedMaxWorkingSetSize` in llama.cpp logs.

---

## Models that actually fit and run well on 16GB

After exhaustive research across every major model family, here are the models worth running on Epistemos with a 16GB M2 Pro. Starred entries (★) are top picks.

### Comfortably fits (smooth experience)

| Model | Params | Best quant | Size | Est. tok/s | Download |
|---|---|---|---|---|---|
| **Qwen3.5-9B** ★ | 9B | Q6_K | 7.5 GB | ~25 | huggingface.co/unsloth/Qwen3.5-9B-GGUF |
| **Gemma 3 12B QAT** ★ | 12B | Q4_0 (QAT) | ~7 GB | ~18 | huggingface.co/google/gemma-3-12b-it-qat-q4_0-gguf |
| **DeepSeek R1-Distill-Qwen-14B** ★ | 14B | Q4_K_M | ~9 GB | ~15 | huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF |
| **Phi-4-mini** ★ (reasoning) | 3.8B | Q8_0 | ~4 GB | ~60 | huggingface.co/unsloth/Phi-4-mini-reasoning-GGUF |
| Qwen 2.5 Coder 14B | 14B | Q4_K_M | ~9 GB | ~15 | huggingface.co/Qwen/Qwen2.5-Coder-14B-Instruct-GGUF |
| Qwen3-8B | 8B | Q8_0 | 8.7 GB | ~25 | huggingface.co/Qwen/Qwen3-8B-GGUF |
| Phi-4 | 14B | Q4_K_M | ~9 GB | ~15 | huggingface.co/microsoft/phi-4-gguf |
| Llama 3.1 8B | 8B | Q5_K_M | 5.7 GB | ~25 | huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF |
| Qwen3.5-4B | 4B | Q8_0 | 4.5 GB | ~50 | huggingface.co/unsloth/Qwen3.5-4B-GGUF |

### Tight fit (short context, some memory pressure)

| Model | Params | Quant needed | Size | Notes |
|---|---|---|---|---|
| Mistral Small 3.2 (24B) | 24B | Q3_K_M | ~12 GB | ≤4K context, ~8 tok/s |
| Codestral 22B | 22B | Q3_K_M | ~11 GB | FIM support for code completion |
| Devstral Small (24B) | 24B | Q3_K_M | ~12 GB | Agentic coding, Apache 2.0 |

### Does not fit usably

**QwQ-32B, Qwen 2.5 Coder 32B, Qwen3-32B, DeepSeek R1 (671B), DeepSeek V3 (671B), Llama 3.3 70B, Mistral Large, Command R+ (104B)** — none of these fit in 16GB at any quantization level that preserves usable quality. The 32B models require 24GB+ for acceptable inference; the 70B+ models need 48GB minimum.

**Google's QAT models deserve special attention.** The Gemma 3 12B QAT (Quantization-Aware Trained) variant from Google preserves near-full-precision quality at Q4_0, unlike post-training quantization which always degrades. At ~7GB, it fits perfectly on 16GB with generous context headroom.

**For Epistemos's TriageService routing**: Use Phi-4-mini-reasoning (3.8B, ~60 tok/s) for Tier 1 fast responses, and Qwen3.5-9B or DeepSeek R1-Distill-14B for Tier 2 deeper reasoning. This two-model strategy keeps total memory under control while providing quality differentiation.

---

## TurboQuant is a KV cache breakthrough, not weight compression

TurboQuant is a **KV cache compression algorithm** from Google Research (arXiv 2504.19874), published for ICLR 2026. This is a critical distinction: it does **not** compress model weights like GGUF quantization does. Instead, it compresses the runtime KV cache — the memory that grows with context length during inference. TurboQuant and GGUF quantization are complementary, not competing.

### How it works

TurboQuant uses a two-stage process. **Stage 1 (PolarQuant)** randomly rotates input vectors via Hadamard Transform, inducing a concentrated distribution that enables optimal Lloyd-Max scalar quantization per coordinate. **Stage 2 (QJL — Quantized Johnson-Lindenstrauss)** takes the residual error, projects it through a random matrix, and stores just the sign bit. The result is a provably unbiased estimator for attention score inner products at **3–4 bits per dimension** — an ~6× compression from FP16.

Key properties: data-oblivious (no calibration needed), applied online during inference, and within ~2.7× of Shannon's information-theoretic lower bound.

### Real benchmarks paint a nuanced picture

| Setup | Result |
|---|---|
| **Google H100 benchmarks** | 8× speedup for attention logits, 6× KV cache reduction |
| **Apple M4 Air (gguf-runner)** | 4.2% slower than Q8 overall, but **61% less KV cache memory** (15.4 → 7.9 GB) |
| **MLX (Qwen3.5-35B)** | **+32% prompt speed, +26% generation speed, −44% cache memory** |
| **llama.cpp fork (M5 Max)** | Speed parity with Q8_0, **4.6× compression** |

The "8× speedup" headline applies specifically to attention logit computation on H100 GPUs. End-to-end speedups on Apple Silicon are more modest — the real win is **memory savings that enable longer context windows or larger models**.

### How to use TurboQuant today

TurboQuant is **not yet merged into upstream llama.cpp, Ollama, or MLX**. Community implementations exist:

**llama.cpp fork (most mature for Apple Silicon):**
```bash
git clone https://github.com/TheTom/llama-cpp-turboquant.git
cd llama-cpp-turboquant && git checkout feature/turboquant-kv-cache
cmake -B build -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j

./build/bin/llama-server -m model.gguf \
  -ngl 99 -c 65536 -fa on \
  --cache-type-k turbo3 --cache-type-v turbo3 \
  --host 0.0.0.0 --port 8080
```

`turbo3` gives 3.5 bits-per-weight (4.6× compression); `turbo4` gives 4.25 bpw (3.8× compression).

**MLX integration** is available via `flovflo/turboquant-mlx-qwen35-kv` on HuggingFace and the OptiQ project (`mlx-community/Qwen3.5-9B-OptiQ-4bit`).

### When TurboQuant matters for Epistemos

Benefits scale with context length. At 2K tokens, the KV cache savings are negligible and TurboQuant adds overhead. At **32K+ tokens, it saves gigabytes** — potentially the difference between fitting a model or swapping to disk. For Epistemos's reasoning pipeline with long multi-turn contexts, TurboQuant combined with Q4_K_M weights could enable 14B models to run at 8K+ context on 16GB, where they'd otherwise be limited to 4K.

The official Google code release is expected around Q2 2026. Until then, the TheTom/llama-cpp-turboquant fork is the most production-ready option for Apple Silicon.

---

## llama.cpp, MLX, and Ollama configuration for M2 Pro

### llama.cpp optimal settings

```bash
# Build with Metal support
cmake -S . -B build -DGGML_METAL=ON -DBUILD_SHARED_LIBS=ON
cmake --build build -j

# Optimal server configuration for M2 Pro 16GB
./build/bin/llama-server \
  -m model-8b-q4_k_m.gguf \
  --host 127.0.0.1 --port 8080 \
  -ngl 999 \               # Full GPU offload (Metal)
  -c 8192 \                # Context window (adjust to model)
  -b 512 \                 # Batch size for prompt processing
  -t 4 \                   # Threads: use P-cores only
  --flash-attn \           # Always enable — reduces memory, no quality cost
  --cache-type-k q8_0 \    # KV cache quantization (halves cache memory)
  --cache-type-v q8_0 \    # Negligible quality impact (+0.004 ppl)
  --mlock                  # Prevent model pages from being swapped
```

**Flash attention** (`-fa`) is essential — it's free performance and memory savings with no quality downside. It must be enabled for KV cache quantization to work. First run triggers Metal shader compilation (adds a few seconds).

**Thread count**: Start at `-t 4` (P-cores only). Testing up to 6 may help prefill, but going higher can **reduce** generation speed due to contention. Token generation is GPU-bound when using Metal.

### MLX commands and setup

MLX consistently outperforms llama.cpp on Apple Silicon in benchmarks — **~230 tok/s vs ~150 tok/s** on M2 Ultra (Qwen-2.5), with the gap widening at larger batch sizes. This comes from zero-copy unified memory operations, lazy evaluation enabling operation fusion, and Metal kernel optimization.

```bash
pip install mlx-lm

# Chat with a model
mlx_lm.chat --model mlx-community/Qwen3.5-9B-4bit

# Generate with specific parameters
mlx_lm.generate --model mlx-community/Qwen3.5-9B-4bit \
  --prompt "Analyze this code..." --max-tokens 2048

# Benchmark (measure actual performance on your hardware)
mlx_lm.benchmark --model mlx-community/Qwen3.5-9B-4bit -p 2048 -g 128

# Quantize a model yourself (4-bit default)
mlx_lm.convert --model Qwen/Qwen3.5-9B-Instruct -q \
  --upload-repo mlx-community/Qwen3.5-9B-4bit

# Rotating KV cache for long-context with limited memory
mlx_lm.generate --model ... --max-kv-size 512
```

### Ollama for quick setup

Ollama wraps llama.cpp with a daemon and REST API. For 16GB Macs, these environment variables are critical:

```bash
# Set these via launchctl (for .dmg install) or shell exports (brew)
launchctl setenv OLLAMA_FLASH_ATTENTION "1"       # Must enable
launchctl setenv OLLAMA_KV_CACHE_TYPE "q8_0"      # Halves KV cache memory
launchctl setenv OLLAMA_KEEP_ALIVE "-1"            # Keep model loaded
launchctl setenv OLLAMA_MAX_LOADED_MODELS "1"      # One model at a time
launchctl setenv OLLAMA_NUM_PARALLEL "1"           # Single request only
# Restart Ollama after setting
```

**Ollama adds significant overhead** — benchmarks show 20–40 tok/s where llama.cpp achieves 150+ and MLX 230+. This overhead comes from the daemon abstraction and inter-process communication. For Epistemos production use, direct integration is strongly preferred.

---

## Swift implementation architecture for Epistemos

### Recommended inference stack

The architecture should provide a dual-backend system with MLX-Swift as the primary engine and llama.cpp as fallback for broader GGUF model compatibility:

```
┌─────────────────────────────────────────────┐
│        Epistemos SwiftUI Interface          │
│  (AsyncStream-based token streaming)        │
├─────────────────────────────────────────────┤
│         LLM Service / TriageService         │
│  (Context management, memory monitoring)    │
├─────────────────┬───────────────────────────┤
│   MLX Backend   │  llama.cpp Backend        │
│  (preferred)    │  (GGUF fallback)          │
├─────────────────┴───────────────────────────┤
│   Model Manager (download, cache, select)   │
│   Adaptive quantization selection           │
└─────────────────────────────────────────────┘
```

**MLX-Swift** is the recommended primary backend. Apple officially presented MLX at WWDC 2025 as the framework for integrating custom LLMs. Key advantages: true zero-copy operations on unified memory, lazy evaluation with operation fusion, native Swift API via `mlx-swift-lm`, and >90% GPU utilization.

```swift
// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.10.0"),
    // For LLM-specific functionality:
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "0.1.0")
]
```

**LocalLLMClient** (github.com/tattn/LocalLLMClient) provides the best dual-backend abstraction — a single Swift API wrapping both llama.cpp AND MLX with modular imports:

```swift
import LocalLLMClient
import LocalLLMClientLlama  // or LocalLLMClientMLX

let client = try await LocalLLMClient.llama(url: modelURL, parameter: .init(
    context: 4096, temperature: 0.7, topK: 40, topP: 0.9
))

let input = LLMInput.chat([
    .system("You are a helpful reasoning assistant."),
    .user("Analyze this knowledge graph relationship...")
])

for try await text in try await client.textStream(from: input) {
    // Stream tokens to Epistemos UI
}
```

### Adaptive quantization selection

Epistemos should automatically select the best model quantization based on available system memory:

```swift
import Foundation

struct AdaptiveModelSelector {
    static func selectOptimal(modelSizeB: Double, contextLength: Int = 4096) -> QuantizationLevel? {
        let totalRAM = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        let availableForModel = totalRAM * 0.60  // Reserve 40% for OS + KV cache
        let kvCacheGB = (Double(contextLength) / 4096.0) * (modelSizeB / 7.0) * 0.5
        let budgetForWeights = availableForModel - kvCacheGB
        
        // Pick highest quality quantization that fits the budget
        return QuantizationLevel.allCases.reversed().first { q in
            modelSizeB * q.gbPerBillion <= budgetForWeights
        }
    }
}
// 16GB Mac: returns Q8_0 for 7B, Q4_K_M for 14B, nil for 32B+
```

### Streaming token generation pattern

```swift
@Observable
class ChatViewModel {
    var currentResponse: String = ""
    var isGenerating = false
    private var generationTask: Task<Void, Never>?
    
    func send(prompt: String) {
        isGenerating = true
        generationTask = Task { @MainActor in
            do {
                for try await token in llmService.generateStream(prompt: prompt) {
                    currentResponse += token  // SwiftUI re-renders automatically
                }
            } catch { /* handle error */ }
            isGenerating = false
        }
    }
    
    func stopGeneration() { generationTask?.cancel() }
}
```

### Speculative decoding for speed

Speculative decoding is **fully supported on Metal** in llama.cpp and produces **mathematically identical output** to standard decoding. A small draft model (0.5–1B) proposes candidate tokens; the target model verifies them in a single batch pass. Practical speedups: **1.5–2.3×**.

For Epistemos on 16GB, pair **Qwen3.5-4B Q8_0 (4.5GB) + Phi-4-mini Q4 (~2GB)** as target + draft for a total of ~6.5GB with ~1.5× speedup. Or use llama.cpp's **n-gram speculation** (no draft model, zero extra memory):

```bash
llama-speculative \
  -m Qwen3.5-9B-Q4_K_M.gguf \     # target
  -md Qwen3.5-0.8B-Q8_0.gguf \    # draft (tiny)
  -ngl 999 -ngld 999 \
  --draft-max 16 --draft-min 4 --draft-p-min 0.9
```

---

## Speed optimization techniques beyond quantization

### Prompt caching saves the most time for multi-turn conversations

KV cache reuse eliminates redundant computation for shared prompt prefixes. When Epistemos sends the same system prompt across turns, cached KV data means only new tokens need processing. One user reported **>50% reduction in response latency** from this alone.

In llama.cpp server mode, set `cache_prompt: true` in API requests (now default). The server matches incoming prompts to existing slots based on prefix similarity. For persistent caching: `--prompt-cache FNAME` saves KV state to disk between sessions.

**Host-memory prompt caching** (PR #16391, March 2026) stores pre-computed prompt representations in system RAM, hot-swapping into GPU context on demand. This is ideal for Epistemos's system prompt pattern.

### Metal GPU is the correct compute path

llama.cpp's Metal backend uses hand-tuned MSL (Metal Shading Language) kernels optimized for Apple GPU architecture. Benchmarks show Metal outperforming Vulkan by **3.8× for prompt processing and 1.8× for generation** on M2 Max. Key Metal optimizations include operation fusion (combining RMS norm + multiply into single dispatches), concurrent kernel execution for independent operations, and residency sets (macOS 15+) that keep GPU memory wired.

### Skip the Neural Engine for LLM inference

The Apple Neural Engine is designed for fixed-size, fixed-graph networks. LLMs need variable-length sequences and autoregressive generation — a fundamental mismatch. The best ANE result for LLMs: ANEMLL achieves ~9 tok/s on 8B models where Metal GPU does 93+ tok/s. ANE's value is in battery efficiency (2W vs 20W), not speed. **For Epistemos, use Metal GPU exclusively.**

### BitNet 1-bit models offer a glimpse of the future

Microsoft's BitNet b1.58 2B4T is the first natively-trained ternary ({-1, 0, +1}) model. At **0.4GB memory** and **0.028J per inference** (12× more efficient than Qwen2.5), it runs on Apple M2 via `bitnet.cpp`. However, only a 2B model exists — not competitive at 7B+ scale yet. Worth watching for Epistemos's Tier 1 fast-response pipeline as larger ternary models emerge.

### The maximum speed configuration for M2 Pro

Combining every applicable technique:

```bash
# Ultimate speed config for M2 Pro 16GB
sudo sysctl iogpu.wired_limit_mb=13312  # Maximize GPU memory

llama-server -m Qwen3.5-9B-Q4_K_M.gguf \
  -ngl 999 \                    # Full Metal GPU offload
  -t 4 \                        # P-cores only
  -b 512 \                      # Batch size for prefill
  -c 8192 \                     # Context window
  --flash-attn \                # Flash attention (always)
  --cache-type-k q8_0 \         # Quantized KV cache
  --cache-type-v q4_0 \         # Aggressive V-cache quant
  --mlock \                     # Lock in memory
  -sps 0.5 \                   # Slot prefix similarity for cache reuse
  --metrics                     # Monitor performance
```

Expected result: **~25–30 tok/s generation, ~400 tok/s prompt processing** with Qwen3.5-9B Q4_K_M, 8K context, on M2 Pro 16GB.

---

## Claude Code as the development accelerator for Epistemos

Claude Code is Anthropic's agentic CLI tool that understands codebases and executes tasks autonomously. For Epistemos's complex Swift + Rust + Metal architecture, it's the most capable coding assistant available — developer Thomas Ricouard notes "nothing comes close to Claude's code for SwiftUI."

### Installation and setup

```bash
curl -fsSL https://claude.ai/install.sh | bash   # Native binary
# Or: brew install claude-code
```

### Essential CLAUDE.md for Epistemos

Place this at the project root to give Claude Code persistent context:

```markdown
# Epistemos: Local-First Cognitive Operating System

## Architecture
- Swift 6.0 frontend (SwiftUI + AppKit), Rust backend (FFI), Metal rendering
- Multi-stage AI pipeline: TriageService → ReasoningLoop → LLMEngine
- Inference: MLX-Swift (primary) + llama.cpp via C++ interop (fallback)
- Local-first: all data persisted locally, CRDT sync between devices

## Project Map
- `App/` — Entry point, scenes, WindowGroup
- `Features/Chat/` — Chat interface, AI streaming, token display
- `Features/Graph/` — MetalGraphView, spatial node visualization
- `Core/Inference/` — LLMEngine, ModelLoader, MLXInferenceService
- `Core/FFI/` — GraphBridge.swift, Rust FFI boundary
- `Bridging/` — C++ interop headers for llama.cpp

## Build & Test
- Build: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify`
- Test: `swift test`

## Code Standards
- Use @Observable, not ObservableObject
- Use Swift Testing (@Test, #expect) for new tests
- All inference on background actors — never block @MainActor
- Handle Metal memory pressure gracefully
- Guard all FFI boundaries: no force unwraps, no from_utf8_unchecked

## DO NOT
- Edit .xcodeproj directly — use xcodegen
- Commit model files (.gguf, .safetensors, .mlx)
- Use DispatchQueue.main.asyncAfter — use Task { @MainActor }
- Mix TextKit 1 and TextKit 2 APIs
```

### XcodeBuildMCP integration

This MCP server gives Claude Code structured Xcode build feedback — far superior to parsing raw xcodebuild output:

```json
// .mcp.json (commit to repo)
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest", "mcp"],
      "env": {
        "INCREMENTAL_BUILDS_ENABLED": "true",
        "XCODEBUILDMCP_DYNAMIC_TOOLS": "true"
      }
    }
  }
}
```

### Effective prompting for Epistemos's inference layer

```
"I need to add MLX-Swift model inference to the LLMEngine.

Context:
- LLMEngine.swift coordinates inference across backends
- ModelLoader.swift handles GGUF/MLX model loading via mmap
- The pipeline: Tokenize → KV-Cache init → Generate (streaming) → Decode
- Must use AsyncStream<String> for streaming tokens to SwiftUI
- Keep inference on a background actor to avoid blocking @MainActor
- Handle Metal GPU memory pressure with graceful degradation
- Support KV cache reuse across multi-turn conversations

Build and verify after every change."
```

**Critical workflow tips**: Close Xcode before heavy Claude Code editing sessions (Xcode's file watcher can corrupt Core Data stores). Use XcodeGen to manage project structure instead of editing `.xcodeproj` directly. Claude defaults to iOS 16-era SwiftUI patterns — the CLAUDE.md standards section corrects this.

---

## Conclusion: a practical strategy for Epistemos on 16GB

The optimal approach for Epistemos is a **tiered model strategy**, not a single model:

- **Tier 1 (fast triage)**: Phi-4-mini-reasoning at Q8_0 (~4GB, ~60 tok/s) — instant responses for simple queries, classification, and the TriageService's complexity assessment. Replace the current keyword-matching heuristic with this model's actual reasoning capability.
- **Tier 2 (deep reasoning)**: Qwen3.5-9B at Q4_K_M (~5.7GB, ~25 tok/s) or DeepSeek R1-Distill-Qwen-14B at Q4_K_M (~9GB, ~15 tok/s) — substantive analysis, multi-step reasoning, the ReasoningLoop's primary engine.
- **Combined footprint**: Under 10GB for Tier 1 + Tier 2, leaving ample room for KV cache, Metal rendering, and the Rust graph engine.

Use **MLX-Swift as the primary inference backend** for native Swift integration, zero-copy memory, and best Apple Silicon performance. Keep llama.cpp as a fallback for GGUF models that lack MLX variants. Enable flash attention, Q8_0 KV cache quantization, and prompt caching universally. When TurboQuant lands in upstream llama.cpp (expected Q2 2026), adopt it immediately for long-context scenarios — the 6× KV cache compression is transformative for memory-constrained devices.

The 32B+ models the user asked about (QwQ-32B, Qwen 2.5 Coder 32B) are not viable on 16GB at quality levels worth using. The 14B class — Qwen 2.5 Coder 14B, DeepSeek R1-Distill-Qwen-14B, Phi-4 — represents the true quality ceiling for this hardware. For production deployment, optimize around these models rather than chasing marginal 32B configurations that swap to disk and generate 2 tokens per second.