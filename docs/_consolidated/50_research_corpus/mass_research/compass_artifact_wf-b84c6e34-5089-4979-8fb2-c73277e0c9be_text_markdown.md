# Building Epistemos: a production-grade local-first macOS AI app

**Epistemos can ship as a competitive local-first AI application on M2 Pro 16GB by combining MLX-native inference with SSD-paged KV caching, TurboQuant compression, and direct distribution via Sparkle — but the 16GB ceiling demands aggressive memory discipline across every layer of the stack.** This report covers all ten technical domains requested, synthesizing findings from GitHub repos, papers, Apple documentation, and community benchmarks into actionable implementation guidance for a 231K-line Rust + Swift + Metal codebase.

---

## TurboQuant KV cache compression delivers real gains on Apple Silicon

Google Research's TurboQuant (arXiv 2504.19874, ICLR 2026) compresses KV cache to **3–4 bits with near-zero accuracy loss** via a two-stage pipeline: PolarQuant applies a random orthogonal rotation followed by Lloyd-Max optimal scalar quantizers, then QJL adds a 1-bit Johnson-Lindenstrauss correction on the residual. The method is training-free and data-oblivious — no calibration required. On H100 GPUs, the paper claims 8× attention speedup, but Apple Silicon tells a different story.

The production-ready MLX path today is `mlx-lm`'s built-in `QuantizedKVCache`, which uses standard affine quantization (not TurboQuant). It exposes three CLI parameters: `--kv-bits` (3, 4, or 8), `--kv-group-size` (default 64), and `--quantized-kv-start` (default 5000). The Python API is straightforward: `generate(model, tokenizer, prompt="...", kv_bits=4, kv_group_size=64)`. The `QuantizedKVCache` class stores keys/values via `mx.quantize()` and uses `mx.quantized_matmul()` for attention — all running on Metal.

A community TurboQuant port exists at `flovflo/turboquant-mlx-qwen35-kv` on HuggingFace, targeting `mlx-community/Qwen3.5-35B-A3B-4bit`. Its benchmarks on ~30GB Apple Silicon show **26% less generation wall time** at short context and **61% less at 2048-token context**, with ~44% cache size reduction. However, the authors explicitly caveat that the main quantizer is MLX affine quantization, not true PolarQuant, and the residual correction is a simplified sign sketch — not faithful QJL. A separate PR #1059 on `ml-explore/mlx-lm` proposes experimental TurboQuant integration but remains unmerged as of March 28, 2026.

**For the Swift/Python bridge question, the answer is: don't bridge.** Apple provides native Swift inference via `mlx-swift-lm` (formerly part of `mlx-swift-examples`), which runs the same Metal kernels as Python MLX. The high-level API uses `MLXLLM.loadContainer()` and `generate()` with streaming via `AsyncSequence`. However, **`mlx-swift-lm` does not yet expose `--kv-bits` or `QuantizedKVCache`** through its Swift API — this exists only on the Python side. If you must access Python-only features, the recommended patterns are either spawning `mlx_lm.server` as a subprocess and communicating via its OpenAI-compatible localhost API, or using `Process()` to invoke `mlx_lm.generate` directly. PythonKit exists but is fragile and unsuitable for production.

**Realistic M2 Pro 16GB expectations**: memory bandwidth is **200 GB/s** (vs 3.35 TB/s on H100), making inference fundamentally memory-bandwidth-bound. An 8B Q4 model generates ~13 tok/s. KV cache quantization from FP16 to Q4 enables **~4× more context** in the same memory budget — at 4K context, KV cache drops from ~512MB to ~144MB. The primary benefit is fitting longer contexts, not raw throughput. Convert all models with `--dtype float16` since M2 lacks native bf16 support.

---

## LocalLLMClient unifies MLX and llama.cpp behind a single Swift interface

The `tattn/LocalLLMClient` Swift package (v0.4.6, MIT license, 169 stars) provides the cleanest dual-backend abstraction available. It wraps three backends behind a unified API: `LocalLLMClientLlama` (GGUF via llama.cpp), `LocalLLMClientMLX` (MLX models via mlx-swift-lm), and `LocalLLMClientFoundationModels` (Apple's on-device models for macOS 26+). Both the high-level `LLMSession` and low-level `LocalLLMClient` APIs support **streaming via Swift Concurrency's `AsyncSequence`**:

```swift
let session = LLMSession(model: .mlx(id: "mlx-community/Qwen3-1.7B-4bit"))
for try await text in session.streamResponse(to: "Hello") { print(text) }
```

SPM integration uses `branch: "main"` (recommended over tag pinning). The package includes a `FileDownloader` with HuggingFace integration, multimodal support on both backends, and experimental tool calling via Swift macros. The author's stated motivation — "I want MLX for faster performance but need llama.cpp for newer models" — reflects the real tradeoff.

The official **llama.cpp XCFramework** from `ggml-org` (latest build **b8559**, March 27, 2026) ships as a precompiled binary with **full Metal GPU support** — the build script bundles `ggml-metal.metal` shaders as `default.metallib`. Integration is via SPM `binaryTarget` pointing to the release ZIP. The framework exposes the raw C API (`llama_model_load_from_file`, `llama_decode`, etc.) with no Swift wrapper — you must build your own async streaming layer.

| Dimension | LocalLLMClient | Raw XCFramework |
|---|---|---|
| API ergonomics | Native Swift async/await, chat types | Raw C API, manual bridging |
| Streaming | Built-in `AsyncSequence` | Manual token loop |
| Model formats | GGUF + MLX + FoundationModels | GGUF only |
| Maintenance risk | **Single developer** (bus factor = 1) | 1000+ contributors, daily releases |
| Production status | Explicitly "experimental" | Battle-tested C API |

**Recommendation for Epistemos**: Use LocalLLMClient for rapid prototyping and MLX integration, but plan a thin custom Swift wrapper around the XCFramework for the llama.cpp path if LocalLLMClient's maintenance stalls. Also consider `mattt/AnyLanguageModel` (by Hugging Face's @mattt), which uses Apple's FoundationModels API shape and supports MLX, llama.cpp, CoreML, and cloud providers via Swift 6.1 package traits.

---

## oMLX's SSD-paged KV cache is the key to large model inference on 16GB

The `jundot/omlx` project (7,100+ GitHub stars, Apache 2.0) is a native macOS LLM inference server built on MLX with a **two-tier paged KV cache** inspired by vLLM's PagedAttention. The architecture divides KV cache into fixed-size blocks managed via a radix tree for prefix matching, with a hot tier in unified memory and a cold tier persisted to SSD in safetensors format at `~/.omlx/cache`. When memory fills, LRU blocks evict to disk; on follow-up requests with matching prefixes, blocks restore from SSD in milliseconds rather than requiring full recomputation.

**The performance difference is dramatic**: the author reports that across 30 agent iterations, Ollama takes 30 minutes while oMLX completes in under 70 seconds — a **25× improvement**. First cold-start requests still require full prefill (~10 seconds for long contexts), but TTFT drops to **1–3 seconds** on subsequent requests with overlapping prefixes. Cache blocks survive server restarts.

The API runs at **`http://localhost:8000/v1`** (configurable via `--port` or `OMLX_PORT`), exposing both OpenAI and Anthropic-compatible endpoints. Drop-in compatible with Claude Code, Cursor, and any OpenAI client. Streaming uses standard Server-Sent Events.

**Critical caveat for 16GB**: oMLX pages *KV cache* to SSD, not model weights. A dense 27B model at Q4 still requires ~17GB for weights alone, exceeding 16GB. The realistic options on 16GB are **Qwen3.5-35B-A3B** (MoE, activates only 3B parameters per token, fits in ~18GB with aggressive settings) or 9B-class models (~6.6GB at Q4). For Swift integration, use `URLSession.shared.bytes(for:)` with `AsyncSequence` to parse SSE streams:

```swift
let (bytes, _) = try await URLSession.shared.bytes(for: request)
for try await line in bytes.lines {
    guard line.hasPrefix("data: "), line != "data: [DONE]" else { continue }
    // Parse OpenAI ChatCompletionChunk JSON
}
```

Compared to Ollama, oMLX uses ~50% less memory for the same model (MLX advantage), runs **1.5–2× faster** on token generation, and supports continuous batching. Ollama's advantage is its massive model library and cross-platform support.

---

## GGUF downloads require careful authentication and resumable transfer handling

HuggingFace's programmatic download pattern uses the `/resolve/` endpoint: `https://huggingface.co/{org}/{repo}/resolve/{revision}/{filename}`. The `{revision}` can be `main`, a branch, tag, or commit hash. Files larger than a few MB redirect to Cloudfront CDN for global distribution. Rate limits are generous: **3,000–5,000 resolver requests per 5-minute window** for authenticated users, with HTTP 429 responses including `RateLimit` headers per IETF draft.

**Gated models** (Gemma, Llama) require two steps: the user must first agree to terms on the model page (auto-approved for Gemma), then authenticate via `Authorization: Bearer hf_xxx` header. Fine-grained tokens scoped to specific repos with read-only access are recommended for production apps.

For **resumable downloads in Swift**, `URLSessionDownloadTask` with background sessions is the production pattern. The task writes directly to disk (~4MB RAM overhead regardless of file size), automatically handles `Range` headers and ETags for resume, and continues downloading even when the app is suspended. HuggingFace's CDN supports all requirements: `Accept-Ranges: bytes`, ETags, and `Last-Modified` headers. Store `cancelByProducingResumeData()` output for pause/resume, and catch `URLError.downloadTaskResumeData` for error recovery. Set `countOfBytesClientExpectsToReceive` to the expected file size for system scheduling optimization.

---

## Gemma 3 QAT bakes quantization resilience into the weights themselves

Google's Quantization-Aware Training for Gemma 3 runs **~5,000 additional training steps** with knowledge distillation from the bf16 checkpoint, teaching the model to be robust under int4 quantization. The result: a **54% reduction in perplexity degradation** when quantizing to Q4_0 compared to naive post-training quantization. Gemma 3 27B drops from 54GB (bf16) to **14.1GB (int4)** — fitting on a 16GB Mac with room for KV cache.

**The critical implementation detail**: QAT models require **no special inference handling**. The `google/gemma-3-27b-it-qat-q4_0-gguf` file works identically to any standard GGUF Q4_0 model in llama.cpp, Ollama, or MLX. QAT's quality improvement is baked into the weights during training. Note that Google specifically targeted Q4_0 — community re-quantizations to Q4_K_M or other formats exist (via Bartowski) but the QAT training benefit applies specifically to Q4_0. The download URL is `https://huggingface.co/google/gemma-3-27b-it-qat-q4_0-gguf/resolve/main/gemma-3-27b-it-q4_0.gguf` (~15.6GB, gated).

---

## The GPU memory override works but demands caution at 16GB

`sudo sysctl iogpu.wired_limit_mb=14336` is a **real, functional kernel parameter** on macOS 15+ that overrides Metal's `recommendedMaxWorkingSetSize`. It works immediately without reboot across all M1–M4 chips. The default allocation caps GPU wired memory at ~66% of total RAM for ≤36GB machines — roughly **10.67GB on a 16GB M2 Pro**. Setting it to 14336 (14GB) leaves only ~2GB for macOS itself.

**Stability risks are significant at this ceiling**: expect system lockups, aggressive swap thrashing, and potential kernel panics if any background process needs memory. Multiple community sources recommend a safer range of **10–12GB** (10240–12288). The setting is **not persistent across reboots** (reverts to 0/default), which is actually a safety feature — a hard reboot always recovers. Persistence requires either `/etc/sysctl.conf` (may need SIP disabled) or a LaunchDaemon plist.

**An app cannot automate this from the sandbox.** It requires root/sudo privileges. A direct-distribution notarized app can prompt for admin credentials via `NSAppleScript("do shell script ... with administrator privileges")` or `SMJobBless` for a privileged helper. The third-party VRAM Pro app demonstrates this pattern. This is fundamentally incompatible with Mac App Store distribution.

---

## Direct distribution is the pragmatic path for ML inference apps

**JIT entitlements are compatible with both distribution channels** — Apple DTS Engineer Quinn confirmed in November 2025 that `com.apple.security.cs.allow-jit` and `com.apple.security.cs.allow-unsigned-executable-memory` are "unrestricted" entitlements usable by any developer on both Mac App Store and direct distribution. However, the deeper issue is that **Metal-based ML inference doesn't need JIT entitlements at all**. Metal shader compilation is handled by the system driver, not by user-space JIT. These entitlements are for JavaScript engines, WebAssembly runtimes, and emulators.

The real blockers for Mac App Store are sandbox restrictions (no `sysctl` GPU tuning, no arbitrary model file paths) and update velocity (App Review delays vs. daily llama.cpp builds). No mainstream LLM inference app (LM Studio, Ollama, etc.) ships on the Mac App Store.

**Sparkle 2.8.1** (latest stable, November 2025) provides production-grade auto-updates for direct distribution: Ed25519 signing via `generate_keys`, delta binary diffs for smaller downloads, beta/stable update channels via `sparkle:channel` in appcast items, phased rollouts, and full sandbox support via XPC services. Integration is via SPM dependency. The pre-release 2.9.0-beta.2 adds markdown release notes and signed appcast feeds. Sparkle has been in production for 20 years with 8,751+ stars.

---

## Prompt repetition is a zero-cost quality boost for non-reasoning inference

Leviathan, Kalman, and Matias (Google Research, arXiv 2512.14982, December 2025) demonstrate that simply **duplicating the entire user prompt** — transforming `<QUERY>` to `<QUERY><QUERY>` — improves non-reasoning LLM output across the board. The mechanism: the second copy's tokens can attend to every token in the first copy, effectively enabling bidirectional attention within a unidirectional architecture. The technique scored **47 wins out of 70 benchmark-model combinations with zero losses** (p < 0.1, McNemar test) across Gemini, GPT-4o, Claude, and DeepSeek.

The most dramatic single result: Gemini 2.0 Flash Lite on NameIndex improved from **21.33% to 97.33%** — a 76 percentage point gain. Gains are largest on positional retrieval tasks and options-first multiple choice, moderate on general reasoning benchmarks (ARC, GSM8K, MMLU-Pro). Critically, the technique adds **no output tokens** — it only extends the parallelizable prefill stage, so latency impact is negligible for most models.

**For Qwen 3.5 specifically**: the technique is likely applicable in **non-thinking mode** (set `enable_thinking: false`), particularly for smaller models (0.8B–9B) that default to non-thinking. However, Qwen 3.5's hybrid Gated DeltaNet + MoE architecture uses linear attention in some layers — an untested variable not covered by the paper. In thinking mode (default for ≥27B), prompt repetition is expected to be neutral since CoT reasoning already involves internal re-processing. A replication study (Shaier et al., 2025) found "often insignificant gains" when repeating only the question, but Leviathan et al. argue that repeating the **entire prompt** including context is what drives the gains.

---

## REAP prunes 20% of MoE experts with minimal quality loss

REAP (Router-weighted Expert Activation Pruning, arXiv 2510.13999, Cerebras/ICLR 2026) scores each expert by the product of its **router gate-value** and **activation norm**, averaged over tokens where the router activated it. Experts with the lowest combined saliency are pruned layer-by-layer, with router weights renormalized post-pruning. The paper proves that expert **merging** causes "functional subspace collapse" — an irreducible error from losing the router's input-dependent modulation — making pruning strictly superior for generative tasks.

A community-created model `0xSero/Qwen-3.5-28B-A3B-REAP` (uploaded ~March 27, 2026) applies 20% pruning to Qwen3.5-35B-A3B, reducing experts from 256 to 205 per MoE layer. Benchmark results show **HumanEval pass@1 drops from 76.2% to 73.2%** (-3%), MMLU drops from 84.34% to 80.89% (-3.45%), while several benchmarks (BoolQ, OpenBookQA, ARC-Challenge) actually improve slightly. Model size drops from ~71GB to ~53GB in bf16.

**No special inference configuration is needed.** REAP performs structural pruning — experts are physically removed, not zeroed out. The resulting model is saved as standard safetensors with updated config files. It works as a drop-in replacement in vLLM, HuggingFace Transformers, and can be converted to GGUF via llama.cpp's conversion scripts. Router weight renormalization is baked into the saved weights. Throughput speedup is minimal (~1×) at 20% compression; the primary benefit is **~25% memory reduction**.

---

## UniFFI is the right Rust–Swift bridge for a codebase this size

Mozilla's UniFFI (v0.30.0 / bindgen v0.31.0, 4.5K stars) is the clear choice for bridging 94K lines of Rust with 137K lines of Swift. It maps Rust `async fn` to native Swift `async`/`await` by generating four scaffolding functions per async method (`RustFuture` handle, poll, complete, free), with Swift driving the future to completion. Every UniFFI object lives in an `Arc<T>` — all interfaces must be `Send + Sync`, enforced at compile time, with interior mutability via `RwLock` or `Mutex`.

**Proc-macros are the recommended approach** over UDL for large projects — better developer experience, inline with Rust code, and full feature parity. The key organizational pattern for 94K+ lines is a **multi-crate workspace**: core business logic crates with no UniFFI dependency, thin FFI facade crate(s) with `#[uniffi::export]` annotations, and one `cdylib` crate that combines everything. Use `--library` mode for binding generation to automatically discover all UniFFI-annotated crates.

Error handling maps cleanly: Rust `Result<T, E>` becomes Swift `throws`, with `thiserror` + `#[derive(uniffi::Error)]` generating proper Swift `Error`-conforming enums. For complex errors, wrap `anyhow::Error` in a newtype. Rust panics translate to private error types — fatal in non-throwing Swift functions.

**Key production considerations**: no built-in cancellation support (implement via shared atomic flags), no direct Rust actor → Swift actor mapping (use `Send + Sync` objects with interior mutability), partial Swift 6 support (may need manual `@Sendable` annotations), and reference cycle risk between Rust objects and Swift callback implementations (design clear ownership hierarchies). For build optimization, `lto = "fat"` + `panic = "abort"` + `strip = true` reduced one team's binary from 31MB to 7.1MB. Pin exact versions (`=0.30.0`) since UniFFI is pre-1.0.

The main alternative, `chinedufn/swift-bridge`, offers tighter Swift-specific integration (transparent structs, `~Copyable` support) but is a single-maintainer project with no multi-language support — inappropriate for a codebase of this scale.

---

## Conclusion: the architecture Epistemos should adopt

The optimal stack for a 16GB M2 Pro is tighter than it appears. **oMLX's SSD-paged KV cache is the single highest-leverage component** — it transforms the 16GB constraint from a hard wall into a manageable performance gradient, enabling multi-turn agent workflows that would otherwise require 64GB+ machines. Pair it with MLX-native inference (via `mlx-swift-lm` for Swift integration) and `--kv-bits 4` for KV compression once the Swift API catches up to the Python side.

For model selection, Qwen3.5-35B-A3B (MoE, 3B active parameters) is the sweet spot — consider applying REAP 20% pruning to further reduce memory. Gemma 3 27B QAT is viable but tight at 14.1GB without KV cache headroom. Ship via direct distribution with Sparkle auto-updates rather than fighting Mac App Store sandbox limitations. Bridge Rust and Swift through UniFFI proc-macros with a thin facade crate pattern. And implement prompt repetition as a free quality boost whenever running in non-thinking mode — it costs only prefill tokens and reliably improves output across model families.