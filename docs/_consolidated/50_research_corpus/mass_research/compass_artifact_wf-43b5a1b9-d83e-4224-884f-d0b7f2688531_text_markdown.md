# Building Epistemos: a native high-performance LLM inference engine in Rust, Swift, and Metal

**The most viable path to a custom, embedded LLM inference engine on macOS is a mistral.rs (Rust) core linked via UniFFI to Swift, with custom Metal compute shaders for attention and quantization, TurboQuant for KV cache compression, and a tiered model registry routing between local inference and cloud APIs.** This architecture delivers native, in-process inference without sidecar processes, achieves 15–80 tok/s on M2 Pro depending on model size, and can extend context capacity 6× through geometric vector quantization of the KV cache. What follows is a deeply technical blueprint for building this system, grounded in what is production-ready today and what remains on the research frontier.

---

## 1. The inference engine core: mistral.rs + Candle + Metal

The foundation of Epistemos should be **mistral.rs**, a complete Rust-native LLM inference engine built atop Hugging Face's Candle framework. It provides PagedAttention, continuous batching, speculative decoding, GGUF loading, and — critically — a Metal backend that runs natively on Apple Silicon. Unlike llama.cpp, mistral.rs is designed as an embeddable Rust library, not just a server binary.

**Candle** provides the tensor computation layer with first-class Metal support. Enabling `--features metal` and calling `Device::new_metal(0)?` routes all tensor operations to GPU compute shaders. Candle loads GGUF quantized models natively and implements dozens of transformer architectures (Llama, Mistral, Phi, Qwen, Gemma). Benchmarks on M1 show Candle competitive with llama.cpp for Mistral-7B Q4 GGUF inference, and the `metal-candle` community crate claims **25.9× faster** embeddings than MLX for batch workloads.

The Rust-to-Swift FFI boundary is best handled by **Mozilla's UniFFI**, which is production-proven (used in Firefox iOS) and generates Swift bindings with native `async/await` support. Rust `async fn` becomes Swift `async` — no manual callback wiring. For streaming token generation:

```rust
#[uniffi::export]
impl InferenceEngine {
    pub async fn generate_stream(&self, prompt: String, callback: Box<dyn TokenCallback>) {
        // mistral.rs streaming internally, callback per token
    }
}
```

On the Swift side, this becomes a clean `AsyncStream<String>` that drives SwiftUI updates on `@MainActor`. The alternative — cbindgen with C function pointers — offers lower latency for the hot path but requires manual memory management. For Epistemos, **UniFFI for the control plane and cbindgen for the streaming data plane** is the optimal hybrid.

**Zero-copy memory is the killer advantage on Apple Silicon.** The unified memory architecture means an mmap'd GGUF file can be accessed by both CPU (Rust) and GPU (Metal) without any data transfer:

```rust
let mmap = unsafe { MmapOptions::new().map(&file)? };
// Hand pointer to Swift/Metal:
// device.makeBuffer(bytesNoCopy: rustPointer, length: size, options: .storageModeShared)
```

No DMA, no PCIe transfer, no copy. The `storageModeShared` Metal buffer points to the same physical pages that Rust allocated. This is fundamentally impossible on discrete GPU architectures and is why Apple Silicon is uniquely suited for this design.

---

## 2. TurboQuant and PolarQuant: compressing the KV cache to 3 bits with near-zero quality loss

**TurboQuant** (Google Research, ICLR 2026) is the most important recent advance for on-device inference. It compresses KV caches to **3.5 bits per channel with zero measurable accuracy loss**, achieving **6× memory reduction** and **8× attention computation speedup**. The algorithm is data-oblivious — no calibration data required — making it ideal for real-time inference.

**Stage 1 — PolarQuant** works by randomly rotating input vectors using an orthogonal matrix (the Hadamard transform is one choice), which causes coordinates to follow a concentrated Beta distribution: `f(x) = Γ(d/2)/(√π·Γ((d-1)/2)) · (1-x²)^((d-3)/2)`. The algorithm then groups coordinates into pairs, maps them to polar coordinates (radius + angles), and recursively applies polar transformations until distilled to a single radius and a collection of angles. Because these angles follow a known concentrated distribution, they quantize cleanly with a fixed circular grid optimized via **Lloyd-Max scalar quantization**. The critical insight: zero per-block normalization overhead — no stored scales or zero-points needed.

**Stage 2 — QJL** (Quantized Johnson-Lindenstrauss) takes the quantization residual from Stage 1, applies random projection, and stores only sign bits (+1/−1). An unbiased estimator recovers accurate inner products for attention computation. This adds just 1 extra bit per element for bias correction.

**Metal implementation is feasible and partially exists.** A community contributor has integrated TurboQuant into llama.cpp with Metal GPU support, providing `turbo3` (3.25 bits/value, 4.9× compression) and `turbo4` (4.25 bits/value, 3.8× compression) cache types. The Walsh-Hadamard Transform is particularly GPU-friendly: it uses only additions and subtractions (no floating-point multiplications), runs in O(N log N), operates in-place, and its butterfly stages are perfectly parallel. A custom MSL kernel for FWHT:

```metal
kernel void fast_walsh_hadamard(
    device float *data [[buffer(0)]],
    constant uint &n [[buffer(1)]],
    constant uint &stage [[buffer(2)]],  // log2 of current butterfly span
    uint tid [[thread_position_in_grid]])
{
    uint h = 1u << stage;
    uint block = tid / h;
    uint offset = tid % h;
    uint i = block * (h * 2) + offset;
    float x = data[i];
    float y = data[i + h];
    data[i]     = x + y;
    data[i + h] = x - y;
}
```

Lloyd-Max quantization codebooks can be **precomputed offline** for the known Beta distribution at various bit widths (2, 3, 4 bits) and dimensions (128, 256). The runtime quantization step reduces to a simple range comparison against precomputed boundaries — trivially vectorizable with ARM NEON `vclt` and `vbsl` instructions. Pre-generated codebooks ship with TurboQuant implementations.

**On M2 Pro with 16GB, TurboQuant transforms what's possible.** A 14B model's KV cache at 32K context consumes roughly 4–6GB in FP16. With TurboQuant turbo3, this drops to under 1GB, potentially allowing 14B models to run with 32K+ context where they would otherwise be memory-constrained. The practical ceiling shifts from "14B at 4K context" to "14B at 32K context" — a qualitative leap in capability.

---

## 3. The quantization frontier: from 4-bit to 2-bit and beyond

The landscape of weight quantization in 2025–2026 has matured significantly, with several methods achieving production quality at aggressive bit widths. Here is what works and what doesn't on Apple Silicon:

**GGUF Q4_K_M remains the pragmatic default** for local inference — it's production-proven, runs natively via llama.cpp/Metal with zero setup overhead, and adds only ~0.05 perplexity. But the frontier has moved well beyond 4 bits.

**QuIP#** achieves 2-bit weight quantization using the same mathematical primitive as PolarQuant: a Randomized Hadamard Transform that makes weight distributions sub-Gaussian (no outliers), followed by E8 lattice vector quantization. Llama 2 70B at 2 bits achieves ~4.15 WikiText2 perplexity — remarkable for halving the bits. The Hadamard rotation step is shared with PolarQuant, creating a theoretical unification path: PolarQuant for KV cache, QuIP# for weights, sharing the same Hadamard infrastructure. However, QuIP# requires Hessian computation and hours of calibration, and **currently has no Metal implementation** (CUDA only).

**HQQ (Half-Quadratic Quantization)** stands out as the fastest path to sub-4-bit: it requires **no calibration data**, quantizes Llama-2-70B in under 5 minutes, and ties GPTQ/AWQ quality at 4 bits. At 2 bits, quality degrades more than calibrated methods but remains useful. HQQ's calibration-free nature makes it ideal for an app like Epistemos where users may want to quantize arbitrary models locally.

**BitNet b1.58** represents the endgame of quantization — ternary weights {-1, 0, 1} trained from scratch. Microsoft's BitNet b1.58 2B4T (April 2025, MIT license) is competitive with full-precision 2B models on standard benchmarks while consuming **0.4GB vs 2GB**. The official `bitnet.cpp` (25K+ GitHub stars) includes optimized ARM kernels that run on Apple M2. The limitation: only models trained natively in ternary format are available, with the largest being 8B parameters.

**For Apple Silicon specifically**, the recommended quantization stack for Epistemos:

- **Weights:** GGUF Q4_K_M via llama.cpp/Candle for maximum compatibility, or MLX native 4-bit for Apple-optimized throughput
- **KV cache:** TurboQuant turbo3/turbo4 via the llama.cpp Metal community implementation
- **Aggressive option:** HQQ 3-bit for fitting larger models (calibration-free, fast to apply)
- **Future:** QuIP# 2-bit when Metal kernels become available; BitNet b1.58 for models trained with ternary weights

**EXL2** deserves special mention for its variable bits-per-weight approach — sensitivity analysis determines which layers need more bits, then per-layer precision is allocated to hit a target average. This is the most mature production implementation of dynamic quantization. Unfortunately, it remains **CUDA-only** (ExLlamaV2/V3 target NVIDIA exclusively).

**MoE quantization** requires different strategies. DeepSeek V3's recommended deployment uses DQ3_K_M (Dynamic 3-bit) with intelligent allocation: 76% of FFN expert weights at 3-bit, 21% at 4-bit, 3% at 6-bit, achieving **≤0.4% accuracy loss** versus FP8 with 12% less memory than static 4-bit.

---

## 4. Metal shaders for transformer inference: what exists and what to build custom

Multiple open-source implementations provide production-ready Metal compute shaders for every transformer operation. The question is not whether Metal can run transformers — it can — but how to maximize throughput.

**metalQwen3** (GitHub: BoltzmannEntropy/metalQwen3) provides a complete, working Metal implementation of an entire transformer architecture: RMSNorm, quantized matmul (Q8_0), softmax, SwiGLU, RoPE, multi-head attention with KV cache, and batched execution with buffer pooling. This is the clearest proof that a fully custom Metal transformer is viable today.

**metal-flash-attention** (Philip Turner) is the highest-performance attention implementation on Apple Silicon. It exploits `simdgroup_async_copy` — an undocumented hardware feature available since A14 — to achieve **2–4× faster attention** than MLX at moderate sequence lengths. Benchmarks on M-series chips:

| Sequence length | metal-flash-attention | MLX | PyTorch MPS |
|---|---|---|---|
| 256 tokens | 0.20ms | 0.52ms | 2.90ms |
| 1024 tokens | 0.48ms | 1.74ms | 31.09ms |
| 2048 tokens | 1.05ms | 3.27ms | 86.08ms |

**Custom kernels can outperform MLX's general-purpose kernels for specific architectures.** The ZMLX project (a Triton-style kernel toolkit for MLX) achieves +12% decode speed on LFM2-8B and +7% on LFM2-24B through fused MoE gating/SwiGLU kernels. The key insight: **kernel fusion** eliminates intermediate buffer round-trips to device memory. A fused `gather_qmm_swiglu` kernel (~800 lines C++/Metal) replaces three separate dispatches with one, cutting HBM round-trips from 3 to 1.

**Key Metal programming principles for Apple Silicon ML:**

Apple GPUs use **32 threads per SIMD group** and are architecturally optimized for intra-SIMD communication over threadgroup memory. Philip Turner's metal-benchmarks research reveals: *"The Apple GPU was designed to have slower communication between SIMD groups in a threadgroup, but faster communication within a single SIMD."* This means algorithms should maximize `simd_shuffle` and `simd_sum` over threadgroup barriers.

Memory coalescing operates in **128-byte transactions** — loading a single float wastes 96% of bus capacity. Use `float4` (16 bytes) or larger vectorized loads. For weight matrices, ensure contiguous access patterns across threads in a SIMD group.

The roofline crossover on Apple Silicon is approximately **19 FLOP/byte**. Below this, kernels are memory-bound (most elementwise operations, softmax, layer norm, small-batch matmul). Above, compute-bound (large matmul). Most LLM decode operations are memory-bound, which is why TurboQuant's memory reduction translates directly to speedup.

**Metal 4** (announced WWDC 2025, shipping in macOS 26) introduces first-class tensor resources (`MTLTensor`), a machine learning command encoder (`MTL4MachineLearningCommandEncoder`), and **Metal Performance Primitives (MPP)** — matrix multiply, convolution, and reduction operations optimized per-device that can be called directly from shader code:

```metal
#include <MetalPerformancePrimitives/MetalPerformancePrimitives.h>
using namespace mpp;
constexpr tensor_ops::matmul2d_descriptor matmulDesc(
    /* M */ 1, /* N */ 64, /* K */ 16,
    /* left transpose */ false, /* right transpose */ true,
    /* reduced precision */ true
);
tensor_ops::matmul2d<matmulDesc, execution_thread> matmulOp;
```

**AMX (Apple Matrix Extension)** is a CPU-side matrix coprocessor — not accessible from Metal. It powers the Accelerate framework's BLAS routines (`cblas_sgemm`), achieving 0.90–1.49 TFLOPS FP32 across M1–M4. The GPU (1.36–2.9 TFLOPS via MPS) consistently outperforms AMX by 1.5–2×. For Epistemos, use GPU (Metal) as the primary compute path and AMX (via Accelerate) only for CPU fallback operations.

---

## 5. Speculative decoding: practical speedups for single-user macOS inference

During standard autoregressive decoding at batch size 1, the M2 Pro GPU is **severely underutilized** — the operation is memory-bandwidth-bound with only ~2 FLOPs per byte loaded. Speculative decoding directly addresses this by filling idle GPU compute cycles with parallel token verification.

**The recommended implementation priority for Epistemos:**

**Phase 1 — Token Recycling** is the highest-value first implementation. It's train-free, adds less than 2MB memory overhead (an adjacency matrix of candidate tokens), and achieves **~2× speedup** — 31% better than previous train-free methods and 25% better than Medusa on some benchmarks. The algorithm stores all candidate tokens (including rejected speculative tokens) in an adjacency matrix, then uses BFS to construct draft trees before each decoding step. Implementation in Rust is straightforward: a `HashMap<TokenId, Vec<TokenId>>` adjacency structure plus BFS tree construction, with tree attention verification in a Metal compute shader.

**Phase 2 — EAGLE** (Extrapolation Algorithm for Greater Language-model Efficiency) offers the best speedup-to-complexity ratio. EAGLE operates at the feature level — a lightweight auto-regression head (~5% parameter overhead) predicts next-token features from the second-to-top transformer layer, then uses tree-structured verification. It achieves **~3× speedup** over vanilla decoding and is production-deployed in vLLM and TensorRT-LLM. Pre-trained EAGLE weights exist for many popular models on HuggingFace. EAGLE is **lossless** — the generated text distribution is identical to standard autoregressive decoding.

**Phase 3 — KV cache persistence** eliminates prefill latency for repeated prompts. Serializing the KV cache for common system prompts to disk (via `memmap2` in Rust, stored as safetensors or custom binary) can reduce time-to-first-token from **15.7 seconds to 577ms** — a 27× improvement measured on Gemma 3 12B. Anthropic's API achieves 85% latency reduction via prefix caching; locally, the approach is to hash token blocks (128-token granularity) and map to stored KV tensor files.

Apple's own **ReDrafter** paper confirmed speculative decoding effectiveness on Apple Silicon: M2 Ultra achieved 2.3× speedup on Vicuna models. A critical finding: **float16 is consistently faster than bfloat16** on Metal, and the optimal beam width for M2 Pro is likely 1–2 (smaller than datacenter GPUs).

---

## 6. Scalable architecture: local inference up to 14B, cloud beyond

**On M2 Pro with 16GB, the practical local inference ceiling is 14B parameters at Q4_K_M quantization.** Beyond this, models either don't fit or require such aggressive quantization that quality degrades unacceptably. Measured tok/s on M2 Pro via Ollama:

| Model | Size | tok/s | Verdict |
|---|---|---|---|
| Llama 3.2 1B | Q4_K_M ~0.7GB | **82** | Instant, autocomplete |
| Llama 3.2 3B | Q4_K_M ~2GB | **56** | Comfortable streaming |
| DeepSeek R1 Distill 8B | Q4_K_M ~4.5GB | **29** | Good interactive chat |
| Gemma 3 12B | Q4_K_M ~7.5GB | **18** | Solid, approaching floor |
| Phi-4 14B | Q4_K_M ~8.5GB | **15** | Minimum viable speed |
| Mistral Small 24B | Q4_K_M ~14GB | **1.2** | Swap thrashing — unusable |

**Model sharding on Apple Silicon works differently than on discrete GPUs.** The `-ngl` flag in llama.cpp controls GPU vs CPU layer placement, but since unified memory means both access the same physical RAM, the benefit is purely computational — Metal compute shaders are 3–5× faster per layer than CPU NEON. For models at the boundary (13–14GB total with KV cache), running all layers on GPU via Metal is critical. The `recommendedMaxWorkingSetSize` API reports available GPU memory (~75% of unified memory = ~12GB on 16GB systems).

**For MoE models**, a different strategy applies. DeepSeek V3's 671B parameters are impossible to run locally (386GB at Q4), but the MoE architecture means only 37B parameters (~21GB at 4-bit) are active per token. On systems with ≥48GB (M3 Max/M4 Max), Flash-MoE demonstrates 4.36 tok/s on 397B MoE models by streaming expert weights from NVMe SSD using OS page cache (71% hit rate). On 16GB M2 Pro, MoE models of this scale must route to cloud APIs.

**Cloud routing should follow a tiered cost-optimization strategy:**

- **Budget tier:** DeepSeek V3.2 at $0.28/$0.42 per million tokens — 96% cheaper than comparable proprietary models
- **Reasoning tier:** DeepSeek R1 at $0.55/$2.19 or o4-mini at $1.10/$4.40
- **Premium tier:** Claude Sonnet 4.6 at $3.00/$15.00 for coding, Gemini 2.5 Pro at $1.25/$10.00 for 2M context
- **Ultra tier:** Claude Opus 4.6, o3-pro for mission-critical analysis

The model registry should be a remote JSON manifest fetched periodically, with local SQLite cache. Each entry carries capability flags (chat, code, vision, function calling, reasoning), deployment mode (local/cloud/both), memory requirements, and expected performance metrics. New models are added by updating the manifest — no app update required.

**Disk offloading for dense models is impractical.** M2 Pro NVMe bandwidth is 5–7 GB/s, but a 7B Q4_K_M model at 28 tok/s requires scanning 4.5GB per token = **126 GB/s** — a 20× deficit. Apple's "LLM in a Flash" paper (ICLR 2025) shows promise for FFN sparsity exploitation (loading only activated neurons from flash), achieving 4–5× speedup over naive loading, but this technique requires sparse activation patterns not present in most dense models.

---

## 7. The CLAUDE.md audit prompt for Epistemos

The following is a comprehensive audit specification for Claude Code or Codex to validate the Epistemos codebase:

```markdown
# CLAUDE.md — Epistemos Codebase Audit Specification

## CRITICAL CONSTRAINTS
- **NO SIDECAR PROCESSES.** All LLM inference MUST run in-process via Rust FFI. 
  Reject any code using `Process()`, `NSTask`, `posix_spawn`, `fork/exec`, 
  or HTTP calls to localhost for inference. The ONLY acceptable inference paths are:
  1. Rust library linked via UniFFI/cbindgen calling Candle/mistral.rs Metal backend
  2. llama.cpp compiled as static library (.a) linked directly into the Swift target
  3. MLX-Swift framework calls
  Any localhost:port inference server (Ollama, llama-server, vllm-serve) is a FAILURE.

## API INTEGRATION AUDIT
For every cloud API integration:
1. Verify the base URL matches the provider's official documentation:
   - OpenAI: https://api.openai.com/v1/
   - Anthropic: https://api.anthropic.com/v1/
   - Google: https://generativelanguage.googleapis.com/v1beta/
   - DeepSeek: https://api.deepseek.com/v1/
   - Mistral: https://api.mistral.ai/v1/
   - Cohere: https://api.cohere.com/v2/
2. Verify every model ID string exists in the provider's current model list.
   Cross-reference: https://platform.openai.com/docs/models, 
   https://docs.anthropic.com/en/docs/about-claude/models, etc.
3. Verify capability flags match reality:
   - Does the model actually support function calling? (Check provider docs)
   - Does the model actually support vision/image input?
   - Is the stated context window accurate?
   - Is the stated pricing current?
4. Flag any model entry claiming capabilities not documented by the provider.
5. Verify all SDKs: mark official SDKs (openai-swift is NOT official — OpenAI has 
   no official Swift SDK). Community SDKs must be clearly labeled.

## MODEL REGISTRY COMPLETENESS
Verify the registry includes entries for:
- Local models: Llama 3.2 (1B, 3B, 8B), Qwen 2.5 (0.5B-14B), Phi-4, 
  Gemma 3 (1B, 4B, 12B), Mistral 7B, DeepSeek R1 Distill (1.5B-14B)
- Cloud-only models: GPT-5/5.2/5 Mini, Claude Opus/Sonnet/Haiku 4.x, 
  Gemini 2.5 Pro/Flash, DeepSeek R1 671B, DeepSeek V3, Llama 3.3 70B, 
  Mistral Large, Command R+
- Each entry MUST have: honest deployment mode (local/cloud/both), 
  minimum RAM for local, quantization format, measured tok/s on target hardware
- No model should claim local deployment if it exceeds 12GB after quantization 
  on a 16GB system

## RUST FFI SAFETY AUDIT
For every `extern "C"` function and FFI boundary:
1. Check for undefined behavior:
   - No dangling pointers passed across FFI
   - No use-after-free (especially for callback closures)
   - All raw pointers validated before dereference
   - String conversions handle null terminators correctly
2. Error handling:
   - Rust panics MUST NOT cross FFI boundary (use catch_unwind or Result)
   - C error codes properly mapped to Swift errors
   - UniFFI Result<T,E> properly maps to Swift throws
3. Thread safety:
   - Inference runs on background thread (never block main/UI thread)
   - All types passed across FFI are Send + Sync
   - No data races on shared KV cache or model state
4. Memory ownership:
   - Clear ownership semantics for every buffer passed across FFI
   - Metal buffers created with bytesNoCopy must not outlive Rust allocations
   - Deallocators properly registered for zero-copy buffers

## METAL SHADER CORRECTNESS
For every .metal / MSL kernel:
1. Numerical correctness:
   - Softmax uses numerically stable max-subtract-exp pattern
   - RMSNorm epsilon is applied (not omitted)
   - RoPE frequency computation matches model's rope_theta and dimensions
   - Quantized matmul dequantization matches GGUF format specification exactly
2. Synchronization:
   - threadgroup_barrier(mem_flags::mem_threadgroup) present before 
     reading threadgroup memory written by other threads
   - No race conditions on shared buffers
3. Performance:
   - Memory accesses are coalesced (128-byte transactions)
   - Uses float4 or larger vector types for bulk loads
   - SIMD group operations (simd_sum, simd_shuffle) preferred over 
     threadgroup reductions where possible
   - Threadgroup size ≤ 256 for memory-heavy kernels

## QUANTIZATION CORRECTNESS
1. TurboQuant implementation:
   - Hadamard transform produces orthogonal rotation (verify H * H^T = I)
   - Lloyd-Max codebooks match precomputed values for target distribution
   - QJL sign-bit storage preserves inner product estimation property
   - Compression ratio matches claimed bits-per-value
2. GGUF dequantization:
   - Q4_K_M block format: 256 values per block, 6 scales, min values
   - Q8_0: 32 values per block, single scale factor
   - Verify against llama.cpp reference implementation

## COMPUTER USE / AGENT AUDIT
If Anthropic computer use or OpenAI computer use is implemented:
1. Verify the screenshot-action loop:
   - Screenshot captured → sent to model → model returns action → 
     action executed → new screenshot captured → loop
   - No fake "computer use" that just calls tool functions without screenshots
2. Anthropic: uses computer-use-2025-01-24 tool with proper 
   display_width_px, display_height_px parameters
3. OpenAI: uses the computer_use_preview tool type properly
4. Both: proper coordinate scaling between screenshot resolution and 
   actual screen coordinates
```

---

## 8. Recommended implementation architecture

The full system design for Epistemos follows a layered architecture that cleanly separates concerns:

```
┌─────────────────────────────────────────────┐
│  Swift macOS App (SwiftUI)                  │
│  @MainActor: UI, model selection, settings  │
├─────────────────────────────────────────────┤
│  Routing Layer (Swift)                      │
│  LocalInference ←→ CloudAPI dispatcher      │
│  Model registry + adaptive selection        │
├─────────────────────────────────────────────┤
│  UniFFI Bridge (generated)                  │
│  Async token streaming, error mapping       │
├─────────────────────────────────────────────┤
│  Rust Inference Core                        │
│  mistral.rs TextModelBuilder               │
│  KV cache manager (TurboQuant compression) │
│  Speculative decoding (Token Recycling)    │
│  mmap model loader + Metal buffer handoff  │
├─────────────────────────────────────────────┤
│  Candle Metal Backend                       │
│  Custom MSL kernels: attention, RMSNorm,   │
│  RoPE, SwiGLU, quantized matmul            │
│  Flash attention (metal-flash-attention)   │
├─────────────────────────────────────────────┤
│  Apple Silicon (M2 Pro)                     │
│  19 GPU cores, 200 GB/s, 16GB unified      │
│  Zero-copy: CPU ↔ GPU same physical memory │
└─────────────────────────────────────────────┘
```

**What is production-ready today** (March 2026): Candle with Metal backend; mistral.rs as embeddable Rust library with Metal + PagedAttention; GGUF model loading with quantized inference; UniFFI Rust→Swift async bindings; llama.cpp as Swift Package with Metal; flash attention in Metal (metal-flash-attention, 2–4× faster than MLX); complete Metal shader implementations for all transformer operations (metalQwen3); Metal 4 with native tensor types and ML command encoder; TurboQuant KV cache compression via llama.cpp community Metal implementation.

**What remains experimental:** Metal 4 `MTL4MachineLearningCommandEncoder` (very new, needs adoption); paged attention on Metal in vllm-metal (rough edges); QuIP# 2-bit on Metal (CUDA-only currently); EAGLE speculative decoding on Apple Silicon (works but needs EAGLE weight availability per model); M5 Neural Accelerator integration via Metal 4 Tensor APIs.

## Conclusion

Building a native embedded inference engine for macOS is not only feasible — the tooling has reached a critical mass where it's the **superior** approach to wrapping existing servers. The Rust + Metal combination exploits Apple Silicon's unified memory in ways that sidecar architectures fundamentally cannot: zero-copy model loading, shared KV caches between CPU preprocessing and GPU compute, and in-process streaming without IPC overhead.

The three highest-impact technical investments are: **(1)** TurboQuant KV cache compression, which extends the effective context window 4–6× on memory-constrained devices and already has a working Metal implementation; **(2)** custom fused Metal kernels (RMSNorm + residual, gather_qmm_swiglu), which eliminate intermediate memory round-trips and yield 7–12% decode speed improvements over general-purpose frameworks; and **(3)** Token Recycling speculative decoding, which delivers ~2× tok/s improvement with zero training cost and minimal memory overhead — the ideal first optimization for a single-user app where the GPU is chronically underutilized during autoregressive decode.

The architecture's adaptive routing between local inference (≤14B models at Q4_K_M) and cloud APIs (DeepSeek V3 at $0.28/M tokens for budget, Claude/GPT-5 for premium) transforms a 16GB laptop into a system that meaningfully supports *every* model — not by running everything locally, but by making the routing transparent and the local experience fast enough that users prefer it when privacy and latency matter.