# Epistemos: Deep Analysis on Best Practices and the Custom Overpowered Approach

**Author:** Jordan | **Date:** March 28, 2026 | **Hardware:** M2 Pro 16GB

---

## The Core Thesis: Why This Architecture Is Uniquely Powerful

Most local AI apps fall into one of two traps. The first trap is wrapping Ollama in a pretty UI — a thin skin over someone else's inference engine, differentiated by nothing, competing on vibes. The second trap is building a cloud-only wrapper around OpenAI's API, which makes you a reseller of someone else's intelligence with zero moat. Epistemos does neither. It builds a *native inference engine* in the languages that Apple Silicon was designed to run (Swift, Rust, Metal), implements cutting-edge quantization research directly in GPU shaders, and treats cloud APIs as a genuine power extension rather than a crutch.

The result is a system where local inference isn't a compromise — it's a *feature*. Privacy, zero latency, offline operation, no token costs. And when you want cloud, you get the real thing: Anthropic's Computer Use, native MCP, extended thinking, true agentic workflows. Not a downgraded local approximation, but the actual frontier capability.

This section explains why each major architectural decision matters and how they compound into something greater than the sum of their parts.

---

## Decision 1: Both Local AND Cloud — The Dual-Brain Architecture

**The question you asked:** Should I include cloud LLMs or keep everything local?

**The answer:** Both, but with an honest boundary between them.

The critical insight is that local models (4B–27B parameters on consumer hardware) and cloud models (Opus 4.6, GPT-5.4) are not on a spectrum — they are qualitatively different tools. A 9B model running at 25 tok/s on your M2 Pro is extraordinary for thinking, drafting, code explanation, and fast iteration. But it *cannot* reliably execute a 12-step agentic workflow that requires navigating Safari, reading screen content, deciding what to click, waiting for a page to load, and adapting when something unexpected happens. That requires spatial reasoning, tool-calling precision, and multi-step planning that emerges only at frontier scale.

The Dual-Brain Architecture makes this explicit in the code:

**Local brain** handles modes `fast`, `thinking`, and `research`. These are the modes where latency matters, where privacy matters, where you don't want to wait for a network round-trip, and where the model's job is primarily *generating text* — reasoning through a problem, writing code, synthesizing information. Local models excel here.

**Cloud brain** handles modes `agent` and `liveAgent`. These are the modes where the model needs to *act in the world* — calling tools, controlling the computer, orchestrating multi-step workflows. Cloud models have been specifically trained for this (Anthropic's tool-use training, OpenAI's function-calling fine-tuning), and they do it reliably.

The key engineering principle: **never fake a capability.** If a local model can't reliably call tools, don't build a flimsy tool-calling wrapper that works 60% of the time. Instead, use grammar-constrained decoding (GBNF/structured output) to force valid JSON when local models *must* produce structured output, and route truly agentic tasks to cloud models that can handle them natively.

**Why this is overpowered:** Most competing apps either go all-local (and their agent features are broken) or all-cloud (and they have no privacy story). Epistemos is the only architecture that gives you *both* — genuine local privacy for thinking, genuine cloud power for acting — with an honest UI that tells you exactly which mode you're in and why.

---

## Decision 2: No Sidecar — Native Embedded Inference

**The principle:** Every inference call happens in-process. No Ollama daemon, no llama-server subprocess, no HTTP call to localhost.

**Why this matters more than most developers realize:**

When you run Ollama as a sidecar, your app starts a separate process that loads the model into its own memory space, exposes an HTTP API on localhost, and your Swift app makes URLSession requests to it. This introduces four problems that compound into a materially worse user experience.

First, **memory overhead.** The Ollama process itself consumes 200–400MB of RAM before loading any model. On a 16GB machine where every megabyte matters, this is the difference between fitting a 14B model comfortably and having it thrash swap.

Second, **latency.** Every token goes through JSON serialization, HTTP framing, TCP socket read, JSON deserialization. On an M2 Pro, this adds 2–5ms per token. At 25 tok/s, that's 50–125ms of pure overhead per second — enough to feel sluggish during streaming.

Third, **lifecycle management.** You have to handle Ollama process crashes, port conflicts, startup delays, and the macOS permission dialogs that appear when a subprocess tries to bind a port. Users see "Ollama is not running" error dialogs. The app feels fragile.

Fourth, **App Store eligibility.** Sandboxed apps cannot spawn arbitrary subprocesses or bind network ports. A sidecar architecture permanently locks you out of the Mac App Store.

The native approach — linking Candle/mistral.rs as a Rust static library via UniFFI, or using MLX-Swift directly — eliminates all four problems. The model loads into your process's memory space. Tokens stream through a function call, not a network socket. There's no daemon to manage. And the whole thing can be sandboxed.

**The zero-copy advantage on Apple Silicon:** When you mmap a GGUF file in Rust and create a Metal buffer with `bytesNoCopy`, the GPU reads directly from the same physical memory pages. No copy. No DMA transfer. No PCIe bus. This is fundamentally impossible on discrete GPU architectures (NVIDIA) where CPU and GPU have separate memory spaces connected by a bus. It's the single biggest performance advantage of building natively on Apple Silicon, and sidecar architectures can't exploit it because the model lives in a different process's address space.

---

## Decision 3: TurboQuant as a First-Class Citizen

**What TurboQuant actually is:** A KV cache compression algorithm, not a weight quantization format. It complements GGUF/MLX weight quantization by compressing the *runtime* memory that grows with context length.

**Why it matters for 16GB:** On your M2 Pro, the model weights for a 14B Q4_K_M model consume about 9GB. That leaves 7GB for everything else — macOS, your app, the Metal framework overhead, and the KV cache. At 8K context with FP16 KV cache, the cache alone consumes 2–3GB, leaving barely enough room for the OS. At 32K context, it would need 8–12GB — impossible.

TurboQuant at turbo3 (3.25 bits per channel) compresses the KV cache by 4.6×. That 8K cache drops from 2–3GB to 0.4–0.65GB. The 32K cache drops from 8–12GB to 1.7–2.6GB. Suddenly, a 14B model can run at 32K context on 16GB. That's the difference between a toy demo and a production reasoning engine.

**The Rust + Metal implementation path:** PolarQuant's core operation — the Fast Walsh-Hadamard Transform — is a sequence of butterfly additions and subtractions with no floating-point multiplications. It runs in O(N log N), operates in-place, and its parallelism maps perfectly to Metal's SIMD groups. A custom MSL kernel for FWHT is roughly 15 lines of shader code. Lloyd-Max codebooks for the known Beta distribution can be precomputed offline and shipped as a static lookup table. The runtime quantization step is a vectorized range comparison — trivially fast on ARM NEON.

The decompression step (during attention computation) is similarly lightweight: apply inverse Hadamard rotation, dequantize from the codebook, compute attention scores. The whole pipeline adds less than 5% overhead to the attention kernel while saving 60–80% of KV cache memory.

**Current integration path:** The cleanest path today is llama.cpp's community TurboQuant fork (TheTom/llama-cpp-turboquant), which already has Metal GPU support and provides `--cache-type-k turbo3 --cache-type-v turbo3` flags. For MLX, the flovflo/turboquant-mlx implementation and OptiQ projects provide the same capability. Both are usable today, with upstream merges expected Q2 2026.

---

## Decision 4: All Models Stay on the Roster

**The principle:** Epistemos supports every model — not by running them all locally, but by routing intelligently.

The model registry is a manifest, not a capability gate. Every model from the smallest (Qwen 3.5 0.8B at ~4GB) to the largest (DeepSeek R1 at 671B, Llama 3.3 70B, Mistral Large at 675B) gets an entry. The entry carries honest metadata: RAM requirements, quantization options, expected performance, deployment mode (local/cloud/both), and capability flags (thinking, code, vision, tools).

For models that fit locally (≤14B at Q4_K_M on 16GB), the app downloads GGUF weights and runs inference natively. For models that are marginal (14B–27B), the app uses TurboQuant + oMLX SSD offloading if the user opts in, with clear performance warnings. For models that don't fit (32B+, 70B+, MoE monsters), the app routes to cloud APIs — DeepSeek at $0.28/MTok for budget, Claude/GPT for premium.

**Why this is the right architecture:** Users upgrade their hardware. The M4 Max ships with 128GB unified memory — enough to run Llama 3.3 70B locally. By building the model registry as a scalable manifest rather than hard-coding "these models work, these don't," Epistemos automatically unlocks larger local models as users move to more powerful machines. The `requiresExternalServer(systemRAMGB:)` method on each model entry dynamically computes whether local inference is feasible on *this specific machine*, not on a hardcoded assumption.

---

## Decision 5: Real APIs Only — No Fake Features

**The principle:** Every feature in the app must be backed by a real, documented API endpoint that the provider actually ships. No shims, no mocks dressed up as features, no "coming soon" pretending to be "works now."

This is not just an engineering principle — it's a product integrity principle. When a user sees "Computer Use" in the Epistemos UI, it should mean actual Anthropic Computer Use with the screenshot-action loop, not a mock that takes a screenshot and pretends to click things. When they see "Tool Calling," it should mean the model actually invokes tools reliably, not that you've wrapped a local 4B model in a flimsy JSON extractor that fails 40% of the time.

**The honest capability matrix:**

Local models get: fast response, thinking mode (/think tokens for supported models), text generation, embeddings, basic structured output via grammar constraints. Local models do NOT get: agent mode, computer use, live agent, multi-step agentic workflows, or reliable tool calling.

Cloud models get: everything the local models get, plus native tool calling, computer use (Anthropic only), extended thinking, MCP server connections, and multi-step agent orchestration.

The UI reflects this honestly — agent and liveAgent modes are grayed out when a local model is selected, with a clear explanation: "Agent mode requires a cloud model. Local models excel at thinking and generation."

---

## Decision 6: The Custom Rust + Swift + Metal Stack

**Why Rust for the inference core:**

Rust gives you three things no other language provides simultaneously: zero-cost abstractions, fearless concurrency, and C-level performance. The inference engine needs to manage mmap'd model files, coordinate Metal GPU command buffers, stream tokens across an FFI boundary, and handle KV cache lifecycle — all concurrently, all without data races, all without garbage collection pauses. Rust's ownership system makes these guarantees at compile time.

Candle (Hugging Face's Rust ML framework) provides the tensor computation layer with a Metal backend. mistral.rs builds on Candle to provide a complete inference engine with PagedAttention, continuous batching, and speculative decoding. Both are designed to be embedded as libraries, not run as servers.

**Why Swift for the UI and app lifecycle:**

SwiftUI with @Observable gives you a reactive UI that updates at 60fps as tokens stream in, with zero manual state management. Metal interop is native — MTLBuffer, MTLCommandQueue, MTLComputePipelineState are all first-class Swift types. The app lifecycle (launch, background, memory pressure) is handled by the system, not by you.

**Why Metal for compute:**

Metal is the only GPU compute API on Apple Silicon. Every watt of GPU power on your M2 Pro is accessed through Metal. Custom MSL kernels for attention, matmul, and quantization operations can outperform general-purpose frameworks (MLX, MPS) by 10–30% for specific model architectures, because they can fuse operations that generic frameworks keep separate.

**The UniFFI bridge:**

Mozilla's UniFFI generates Swift bindings from Rust with native async/await support. Rust `async fn` becomes Swift `async` — tokens stream from the Rust inference engine to the SwiftUI view through a natural AsyncStream, with no manual callback wiring, no manual memory management, and no unsafe code at the Swift level.

---

## The Compounding Effect: Why This Stack Is Overpowered

Each of these decisions is individually strong. Together, they compound:

**Zero-copy model loading** (mmap in Rust → Metal bytesNoCopy) means the model loads in seconds, not minutes. **TurboQuant KV cache compression** means you can run 14B models at 32K context where competitors are limited to 4K. **Native embedded inference** means zero IPC overhead, zero daemon management, and App Store eligibility. **Dual-brain routing** means you get genuine local privacy AND genuine cloud agent power. **Honest capability gating** means your agent features actually work, because you only enable them for models that can handle them. **Scalable model registry** means the app grows with the user's hardware.

No competing macOS AI app has all six of these properties simultaneously. Most have zero or one.

---

## Best Practices for Implementation

**1. Build bottom-up, test at every layer.** Start with the foundation types (ModelBackend, KVCacheConfig, model enum). Then build the inference services (MLX, GGUF, Cloud). Then build the routing layer. Then build the UI. Each layer gets tests before the next layer starts. The existing 2,679-test suite is sacred — zero regressions.

**2. The inference hot path must be allocation-free.** During token generation, the only allocations should be the output string buffer. No Dictionary lookups, no Array resizes, no closure captures that trigger ARC. Profile with Instruments (Allocations + Time Profiler) after every major change.

**3. Metal shaders go in .metal files, not string literals.** Precompile Metal shader libraries at build time using the Xcode build pipeline. Runtime shader compilation adds 2–5 seconds to first inference — unacceptable for UX.

**4. Error handling is a feature, not a chore.** Every inference failure gets a user-visible error message that explains what went wrong and what to do about it. "Model too large for available memory — try Q4 quantization or a smaller model" is infinitely better than a crash or a hang.

**5. The Settings UI is the product.** Model selection, quantization options, TurboQuant toggle, cloud API configuration, agent mode selection — these are not afterthoughts. They are the primary interaction surface for power users. Make them beautiful, informative, and honest.

**6. Ship direct distribution first.** Notarize + Sparkle for auto-updates. The Omega agent system requires unsandboxed access (CGEvent, AXUIElement, ScreenCaptureKit). A sandboxed "lite" version for the Mac App Store can follow once the core is proven.

**7. Cloud API keys go in the macOS Keychain.** Never UserDefaults, never a plist, never a file on disk. The Keychain is encrypted, access-controlled, and backed up by iCloud Keychain. Use the Security framework directly — `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`.

**8. The subscription proxy is an advanced/optional feature.** Not everyone wants to risk their Claude Max account. Offer it as a power-user feature with clear warnings about ToS implications. The primary cloud path should always be official API keys.

---

## Why You Should Absolutely Include Cloud LLMs

You asked this directly, so here's the direct answer: **Yes, include cloud LLMs. It's a non-brainer.**

The local-only pitch is "complete privacy, zero cost, works offline." That's a real value proposition for a significant user segment. But it's not the *whole* value proposition. Cloud LLMs unlock capabilities that are impossible locally:

**Computer Use** is a killer feature. Having Claude watch your screen, navigate to a website, fill out a form, extract data, and bring it back — all while you watch — is a genuinely transformative experience. It only works with cloud models (Anthropic's computer use API, OpenAI's computer-use-preview). No local model can do this reliably.

**Tool calling at production quality** requires frontier models. A 14B local model can produce valid JSON about 80% of the time with grammar constraints. Claude Opus produces valid, correct tool calls about 99.5% of the time, without grammar constraints, because it was specifically trained for it. For agentic workflows where a single bad tool call can corrupt state, that 19.5% gap is the difference between "impressive demo" and "actually useful tool."

**Context windows** at cloud scale (200K tokens for Claude, 1M for Gemini) enable research workflows that are physically impossible on 16GB. Feeding an entire codebase, a set of research papers, and a detailed analysis prompt into a single context window is how serious knowledge work gets done.

**The marketing narrative writes itself:** "Epistemos is a local-first cognitive OS that runs entirely on your machine. When you want to extend its capabilities, connect to Claude, OpenAI, or Gemini for frontier intelligence, computer use, and agentic workflows. Your local models handle thinking. The cloud handles doing."

This is a better story than "local only" or "cloud only." It's the honest story.
