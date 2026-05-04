# Epistemos agent + model deep technical analysis

**Block Goose's pure-Rust agent core is the single highest-leverage dependency for eliminating Epistemos's Python subprocess.** Its Provider trait, 20+ provider integrations, and zero-IPC builtin extension system map cleanly onto the Swift 6 + Rust via UniFFI architecture. For local models, Gemma 4's release on April 2, 2026 shakes up the landscape but doesn't yet dethrone Qwen 3.5 as the default: Qwen3.5 4B achieves **97.5% tool-calling accuracy** and runs at 55–65 tok/s on M2 Pro, while Gemma 4's MLX tool-call parser remains unmerged. The 18GB M2 Pro memory constraint eliminates both the Gemma 4 26B-A4B MoE and Qwopus 27B from always-available duty—the production sweet spot is a **pinned 3.4GB router + cold-loaded 5.5GB reasoner**, leaving headroom for KV cache and the application itself.

---

## Section 1: Agent framework verdicts

### Block Goose — **Clone (selective crate dependency)**

Goose is a Block-backed, Apache-2.0 framework with **33.5K stars**, 3.1K forks, 3,961 commits, and v1.29.0 shipped March 31, 2026. It is the most mature open-source Rust agent framework available. The `goose` core crate provides the Provider trait, agent loop, extension manager, session persistence, and MCP client—all in pure Rust with `tokio` async.

**What to take** (specific paths):
- `crates/goose/src/providers/` — The entire Provider trait and all 20+ provider implementations (Anthropic, OpenAI, Google, Ollama, OpenRouter, Databricks, GitHub Copilot, Azure, xAI, Snowflake, LiteLLM, GCP Vertex). This saves months of HTTP streaming, SSE parsing, and format-adapter work.
- `crates/goose/src/agents/agent.rs` — The reply loop structure (stream → tool dispatch → context compaction → retry), though you'll want to add parallel tool execution.
- `crates/goose-mcp/` — Builtin extension implementations (Developer tools: shell, file read/write/edit, grep, glob). Zero-IPC architecture maps perfectly to compiled-into-binary native extensions.
- `rmcp` dependency (v0.9.1) — The official Rust MCP SDK, originally derived from Goose's internal MCP crates. Replaces both a Python MCP bridge and any need for a separate Swift MCP client.

**What to skip**: `goose-cli`, `goose-server` (Electron UI), `vendor/v8/` (20–30MB V8 engine for sandboxed code execution), and `lancedb` (5–10MB vector DB for tool routing—replace with your existing `sqlite-vec + tantivy`).

**License**: Apache-2.0, fully commercial-friendly. No copyleft contamination.

**Integration difficulty**: Moderate. The main engineering lift is writing UniFFI bindings for the `goose` crate (~2–4 weeks) and implementing a `MetalProvider` wrapping MLX-Swift inference (~1–2 weeks).

### OpenHarness (HKUDS/OpenHarness) — **Skip**

The user-provided URL `zhijiewong/openharness` does not exist. The closest match is HKUDS/OpenHarness, a Python-only "ultra-lightweight Claude Code alternative" with **12 stars, 24 commits, and 2 days of history**. Despite the "harness" name, this is an agent execution framework, not an evaluation/testing harness. It provides no BootstrapPacket, TraceCollector, ProgressStore, or CompletionChecker equivalents. Nothing here is portable to Swift or Rust, and the patterns (agent loop, tool validation, hooks) are standard implementations already present in Goose.

### Hermes Agent Self-Evolution — **Study (the GEPA algorithm, not the repo)**

NousResearch's repo has **17 stars and 5 commits**—only Phase 1 (skill file optimization) is implemented. However, the underlying algorithm is significant: **GEPA (Genetic-Pareto Prompt Evolution)**, published as an **ICLR 2026 Oral**, outperforms GRPO by 6% average using up to 35× fewer rollouts, all via API calls with zero GPU training.

The evolution pipeline reads execution traces, diagnoses failures via LLM reflection, proposes targeted mutations to prompts/skills, evaluates on a Pareto frontier, and gates changes through test suites before merging. This is an inference-time technique that costs **$2–10 per optimization run**.

**What to study**: The GEPA paper directly (arxiv.org/abs/2507.19457) and the `gepa-ai/gepa` library—not this thin wrapper. The trace-based reflective evolution pattern is portable to Rust and could drive self-optimizing retrieval prompts, evolving memory classification rules, or adaptive research assistant behavior in Epistemos's Living Vault.

**License caution**: The repo is MIT, but Phase 4 plans to use Darwinian Evolver (AGPL v3). The core GEPA library is MIT-safe.

### SciAgent-Skills (jaechang-hits/scicraft) — **Skip**

The URL `jaechang-hits/SciAgent-Skills` does not exist. The closest match is `jaechang-hits/scicraft`: **0 stars, 0 forks, 1 commit**, containing 176 Markdown skill templates for life-sciences AI agents (genomics, drug discovery, proteomics). The skill template structure (frontmatter + progressive disclosure + registry.yaml) is clean but not novel. Skills are Claude Code plugin format, not MCP. The life-sciences focus makes 90%+ irrelevant for a general PKM app. CC-BY-4.0 license is fine, but there's nothing to integrate.

---

## Section 2: Goose deep dive

### Cargo workspace architecture

The workspace contains 8 crates under `crates/*`, with the `goose` core library as the central dependency:

| Crate | Purpose | Binary impact |
|-------|---------|--------------|
| `goose` | Core library: Provider trait, agent loop, extension manager, session persistence | **The target dependency** |
| `goose-mcp` | MCP server implementations (Developer, ComputerController, Platform extensions) | Take selectively |
| `goose-acp` | Agent Client Protocol (agents-as-providers) | Optional |
| `goose-acp-macros` | ACP proc macros | Optional |
| `goose-cli` | CLI binary (`goose`) | Skip |
| `goose-server` | HTTP/WS backend (`goosed`) | Skip |
| `goose-test` / `goose-test-support` | Test utilities | Dev only |

Key workspace dependencies: `rmcp` v0.9.1 (official Rust MCP SDK), `tokio` (async runtime), `reqwest` (HTTP + TLS), `serde`/`serde_json`, `lancedb` (vector DB—feature-gate out), `keyring` (macOS Keychain integration), `tracing`, `tera` (template engine for system prompts).

### Provider trait: every method and its adaptation path

The `Provider` trait in `crates/goose/src/providers/base.rs` is the architectural core. It uses `async_trait` with `Send + Sync` bounds and streams via `Pin<Box<dyn Stream<Item = Result<(Option<Message>, Option<ProviderUsage>), ProviderError>> + Send>>`.

**Core methods:**
- **`stream()`** — Primary method. Takes `ModelConfig`, `session_id`, system prompt, messages, and tools. Returns a `MessageStream` of partial chunks. Each cloud provider implements format-specific SSE parsing (`stream_openai_compat()` for OpenAI-compatible APIs, custom parsers for Anthropic and Google). For a local MLX provider, this becomes a direct `async_stream::stream!` yielding tokens without HTTP overhead.
- **`complete()`** — Non-streaming variant with default implementation that collects the stream. Used for quick one-shot completions.
- **`get_model_config()`** — Returns `ModelConfig` carrying model name, context limits, temperature, and tool shim configuration.
- **`get_name()`** — Provider identifier string ("anthropic", "openai", "ollama", etc.).
- **`complete_fast()`** — Uses a cheaper "fast model" variant for simple tasks.
- **`generate_session_name()`** — Produces a short title from conversation content.
- **`configure_oauth()`** — Initiates OAuth device code flow (used by Databricks, GitHub Copilot, OpenRouter).
- **`fetch_supported_models()`** — Dynamic model discovery from provider APIs.
- **`create_embeddings()`** — Via the `EmbeddingCapable` trait, producing `Vec<Vec<f32>>` through `/v1/embeddings` endpoints.

The companion **`ProviderDef`** trait serves as a metadata + factory interface, providing `metadata()` (ConfigKeys, known models, docs URL) and `from_env()` (constructor from environment variables).

**Adaptation for Epistemos**: The `MessageStream` type maps cleanly to Swift's `AsyncSequence` via UniFFI callbacks. A `MetalProvider` struct wrapping MLX-Swift would implement `stream()` by feeding tokens from local inference into an `async_stream::stream!` constructor. Tool-use JSON parsing from local model output would need custom implementation (Goose's providers parse tool calls from HTTP response bodies; a local provider would parse from generated text). The Lead/Worker pattern (`GOOSE_LEAD_PROVIDER`/`GOOSE_WORKER_PROVIDER`) already supports mixing cheap local routing with expensive cloud reasoning—directly applicable to the pinned-router + cold-loaded-reasoner architecture.

### Agent loop: flow and comparison to hand-rolled implementation

The agent loop in `crates/goose/src/agents/agent.rs` follows a straightforward streaming-dispatch-loop pattern:

**Flow**: Assemble system prompt (Tera-templated with extension info) → Gather tools from all enabled extensions → **Enter loop**: call `provider.stream()` → emit chunks to UI channel → if response contains `tool_use` blocks, check permissions via `PermissionManager`, dispatch each tool call sequentially through `ExtensionManager`, collect `tool_result`, append as user message, continue loop → if no tool_use, break → persist session to JSONL.

**Context compaction** is reactive: triggered only by `ProviderError::ContextLengthExceeded`, with up to 3 truncation attempts per turn. The truncation strategy in `truncate.rs` removes older messages from the middle while preserving system prompt and recent context. For Epistemos, this should be replaced with proactive compaction using estimated token counts before hitting the provider's limit.

**Retry logic** uses `RetryConfig` with defaults of 3 retries, 1000ms initial interval, 2.0× backoff, 60s max. Recipe-level retry adds shell-command success checks and failure prompt injection.

**The critical gap is sequential tool execution.** Goose dispatches each `tool_call` individually via `await`, with no `futures::try_join_all` for independent tools. A hand-rolled loop using `try_join_all` would yield significant latency improvements when an LLM requests multiple independent tool calls (e.g., reading 3 files simultaneously). This is the single most impactful change to make in a fork or upstream PR.

**Cancellation** is via interrupt signal propagation, not `tokio::CancellationToken`. For a SwiftUI app with structured concurrency, adding `CancellationToken` support to the agent loop is necessary for clean task lifecycle management.

### MCP crate: replacing Python bridges

Goose migrated from internal MCP crates to **`rmcp` v0.9.1**, the official Rust MCP SDK that was originally based on Goose's implementation. The `rmcp` crate provides both client and server functionality, compliant with the March 2025 MCP standard (not yet the June 2025 update).

The `goose-mcp` crate implements **MCP servers** (extensions exposing tools to the agent), while the agent acts as an **MCP client** calling those tools. This architecture supports both **builtin** (in-process, zero IPC function calls) and **external** (stdio/SSE/StreamableHTTP) transports.

**Can it replace the Python MCP bridge?** Yes. Builtin extensions eliminate IPC entirely. External MCP servers connect via stdio or HTTP with no Python intermediary. For Swift ↔ Rust MCP communication, expose `rmcp` types through UniFFI or use StreamableHTTP transport from the Swift side.

### Extension system: builtin architecture and tool mapping

Goose supports 6 extension types. The **builtin** and **platform** types compile directly into the binary with zero IPC overhead—the agent calls extension methods as regular Rust function calls:

**Builtin extensions** (in `goose-mcp/`): Developer extension provides shell execution, file read/write/edit, grep/search, and glob matching. Computer Controller provides screen interaction and accessibility APIs. These are the core coding tools Epistemos needs.

**Platform extensions** (always active): `todo` (task management), `chatrecall` (history recall), `extensionmanager` (runtime extension management via `platform__manage_extensions` tool).

All tools use a namespacing convention: `{extension_name}__{tool_name}` (e.g., `developer__write_file`). A LanceDB-based vector index enables intelligent tool selection from large tool sets, but this can be replaced with Epistemos's existing `sqlite-vec + tantivy` stack.

For mapping Epistemos's 50+ tools: core coding tools (file ops, shell, grep) map directly to Goose's Developer extension. macOS-specific tools (AXUIElement accessibility, ScreenCaptureKit) would be implemented as a custom builtin "macOS" extension. Memory search would be a builtin extension wrapping the existing `sqlite-vec + tantivy` implementation.

### Binary size estimate

| Configuration | Estimated size (stripped release) |
|---|---|
| `goose` crate alone (no LanceDB, no V8) | **10–15 MB** |
| With LanceDB (tool routing) | 20–25 MB |
| With V8 (sandboxed code execution) | 40–55 MB |

The **5–15MB target is achievable** by feature-gating LanceDB and V8. Key dependencies: `tokio` (~2–3MB), `reqwest` with rustls (~2–3MB), `rmcp` (~500KB–1MB), `serde` (~500KB), `tera` (~500KB). Using Apple's native TLS via `reqwest-native-tls` instead of rustls would save ~1MB. Unused provider implementations can be feature-gated to reduce code size further. V1.29.0 already shows a trend toward modular feature gates ("Feature-gate local inference dependencies").

---

## Section 3: Model recommendations

### Router model (always pinned, <3.5GB)

**Winner: Qwen3.5 4B Instruct, MLX native 4-bit — 3.4GB, ~55–65 tok/s**

In JD Hodges's March 2026 evaluation across 13 models, Qwen3.5 4B achieved **97.5% tool-calling accuracy**—the highest of any model tested at this size. It excels at intent classification, argument parsing, and structured JSON output. At 3.4GB it fits comfortably alongside a reasoner model with memory to spare. The MLX-community model (`mlx-community/Qwen3.5-4B-Instruct-4bit`) is production-ready with native Metal acceleration.

**Runner-up**: Gemma 4 E2B 4-bit at ~1.5GB offers multimodal capability (text + image + audio) and 128K context, but its MLX tool-call parser is not yet upstream. Monitor the EJellerson/gemma4-local-operator patch. If merged and validated, Gemma 4 E2B becomes a compelling ultra-compact router.

### Reasoner model (cold-loaded, 5–8GB)

**Winner: Qwen3.5 9B, MLX native 4-bit — 5.5GB, ~35–42 tok/s**

With the 3.4GB router pinned, 5.5GB for the reasoner leaves ~4–5GB for KV cache and system overhead on 18GB—a comfortable margin for conversations up to 16K context. Qwen3.5 9B delivers strong reasoning, coding, and long-form writing performance. Cold-load time from SSD is approximately **1.5 seconds**.

**Upgrade path**: Gemma 4 E4B 4-bit at ~3GB with thinking mode enabled delivers impressive reasoning (42.5% AIME, 52% LiveCodeBench) in a tiny footprint. It supports image and audio input natively. As the MLX ecosystem matures around Gemma 4, this becomes the preferred multimodal reasoner.

**Maximum quality option**: Mistral Nemo 12B 4-bit at ~7.5GB and 92.5% tool-calling accuracy. Fits alongside the router (~11GB combined) with ~2–3GB headroom. Slower at 25–32 tok/s but significantly higher quality for complex tasks.

### Agent model (tool-calling, reliable structured output)

**Winner: Qwen3.5 4B (dual-duty with router) or Qwen3.5 9B with structured output enforcement**

For the 18GB M2 Pro, the practical strategy is to use the **router model for simple tool calls and the reasoner for complex multi-tool agent workflows**. The Qwen3.5 family has the most mature tool-calling ecosystem in MLX, with established parsers and community validation.

**Stretch option**: Qwopus3.5-27B-v3 (Claude 4.6 Opus-distilled Qwen3.5-27B) achieves **95.73% HumanEval** and has specialized RL training for tool-calling. At Q3_K_M via llama.cpp sidecar (~11–12GB), it can run in exclusive mode (router evicted), but this adds 5–10 seconds for model swapping and requires the experimental llama.cpp backend. Reserve for complex agentic tasks where quality justifies the latency.

### Why not Gemma 4 26B-A4B MoE?

The 26B-A4B MoE model is tantalizing—**97% of Gemma 4 31B quality at 3.8B active compute cost**, with 88.3% AIME and 77.1% LiveCodeBench. However, **all 25.2B parameters must reside in memory** for MoE routing, requiring ~16–18GB at 4-bit. With macOS overhead (~4–5GB), this exceeds 18GB and causes memory pressure, thermal throttling, and swap. On a **24GB+ machine**, this becomes the clear winner for all tiers. For now, it's a skip on M2 Pro 18GB.

---

## Section 4: TurboQuant and quantization analysis

### The two meanings of "TurboQuant"

**TurboQuant (academic, Zandieh et al., ICLR 2026)** is a **KV cache compression** algorithm, not a weight quantization method. It multiplies each KV vector by a randomized Hadamard matrix, transforming unpredictable distributions into a known Beta distribution, then applies Lloyd-Max optimal scalar quantization using pre-computed codebooks. The technique is **data-oblivious** (no calibration needed), within 2.7× of the Shannon information-theoretic limit, and achieves 3.5-bit KV cache that scores identically to FP16 on LongBench. A community Metal implementation exists and reports ~0.9× decode throughput on Apple Silicon.

**TQ3_4S (llama.cpp fork)** is a **weight quantization** format inspired by TurboQuant's rotation technique but applied to model weights. It uses Walsh-Hadamard Transform + Lloyd-Max codebooks at 3.5 bits/weight. It requires an experimental llama.cpp fork (`turbo-tan/llama.cpp-tq3`), is not in mainline llama.cpp, and has **zero MLX support**. Not production-ready.

### Unsloth Dynamic 2.0 vs standard GGUF vs MLX native

**Unsloth Dynamic 2.0** is the current state-of-the-art for GGUF quantization. It analyzes per-tensor KL Divergence contribution and assigns custom bit-widths (2–16 bit) to each tensor based on sensitivity. Important layers (e.g., `attn_k_b` in DeepSeek) get 8-bit; insensitive layers get 2–4 bit. It uses model-specific calibration on curated conversational datasets (300K–1.5M tokens). Results: **≤2% perplexity increase** from full precision at comparable sizes, consistently outperforming standard imatrix and QAT quants on 5-shot MMLU.

**The critical MLX compatibility issue**: MLX-Swift natively accelerates only Q4_0, Q4_1, and Q8_0 GGUF types. All K-quants (Q4_K_M, Q5_K_M, Q6_K) and Unsloth Dynamic types are **cast to float16** when loaded through MLX's GGUF reader, negating the quantization benefit and inflating memory usage. This makes Dynamic 2.0 irrelevant for MLX-Swift production apps.

**For Epistemos, the correct quantization strategy is MLX native safetensors exclusively.** MLX supports affine quantization at 2, 4, 6, and 8-bit with configurable group sizes, plus mxfp4, mxfp8, and nvfp4 formats. The mlx-community on HuggingFace provides day-0 conversions for every major model release. The 4-bit affine format delivers ~90–92% quality retention at optimal Metal-accelerated speed. The 6-bit format (~97% quality) is the sweet spot when memory allows.

### Quantization decision matrix for 18GB Apple Silicon

| Method | Format | MLX-Swift native | Quality/size | Production-ready |
|--------|--------|-----------------|-------------|-----------------|
| **MLX 4-bit affine** | safetensors | ✅ Full acceleration | Good (90–92%) | ✅ Yes |
| **MLX 6-bit affine** | safetensors | ✅ Full acceleration | **Excellent (97%)** | ✅ Yes |
| **MLX 8-bit affine** | safetensors | ✅ Full acceleration | Near-lossless (99%) | ✅ Yes |
| Unsloth Dynamic 2.0 | GGUF | ❌ Cast to FP16 | SOTA for GGUF | ✅ (llama.cpp only) |
| Standard Q4_K_M | GGUF | ❌ Cast to FP16 | Good (92%) | ✅ (llama.cpp only) |
| TQ3_4S | GGUF (fork) | ❌ None | Untested | ❌ Experimental |
| GPTQ / AWQ | safetensors | ❌ None | Good (91–93%) | ❌ CUDA only |

**Recommendation**: Use MLX native 4-bit safetensors for all production models. If a model is only available in GGUF and you need K-quant quality, use llama.cpp as a sidecar backend. Never mix GGUF K-quants with MLX-Swift.

---

## Section 5: Integration roadmap

### What to take from Goose

1. **Depend on the `goose` crate as a Cargo dependency** (not the whole workspace). Pin to a specific git commit or tag for stability.
2. **Feature-gate aggressively**: Disable LanceDB (replace with `sqlite-vec + tantivy`), V8, and unused providers. Target the 10–15MB binary range.
3. **Write UniFFI bindings** exposing: `Agent` (with streaming reply as callback-based), provider creation factory, `ExtensionManager`, `Message`/`Tool`/`ProviderUsage` types. Estimated effort: 2–4 weeks.
4. **Implement `MetalProvider`** wrapping MLX-Swift inference via the Provider trait's `stream()` method. The `MessageStream` type (`Pin<Box<dyn Stream>>`) accepts any async token source. Estimated effort: 1–2 weeks.
5. **Fork the agent loop** to add `futures::try_join_all` for parallel tool execution and `tokio::CancellationToken` for SwiftUI task lifecycle integration.
6. **Bridge builtin extensions** (Developer tools) directly into the binary. Implement a custom "macOS" extension for AXUIElement and ScreenCaptureKit tools.
7. **Replace session persistence** with a protocol-based adapter backed by SQLite (compatible with existing Epistemos storage) rather than JSONL files.

### Models to ship as defaults

| Tier | Model | Format | Size | Ships with app? |
|------|-------|--------|------|----------------|
| Router (pinned) | Qwen3.5 4B Instruct | MLX 4-bit safetensors | 3.4 GB | Yes (first-run download) |
| Reasoner (cold) | Qwen3.5 9B | MLX 4-bit safetensors | 5.5 GB | Optional download |
| Multimodal | Gemma 4 E4B | MLX 4-bit safetensors | 3.0 GB | Optional download |
| Agent (stretch) | Qwopus3.5-27B-v3 | GGUF Q3_K_M (llama.cpp) | 11 GB | Optional, exclusive mode |

**Migration path**: When Gemma 4's MLX tool-call parser is merged upstream (estimated 4–6 weeks), re-evaluate Gemma 4 E2B as the router (~1.5GB, freeing 2GB for larger reasoner) and Gemma 4 E4B as the primary reasoner/agent with multimodal and thinking mode.

### Self-evolution patterns to port

Adapt GEPA's trace-based reflective evolution for Epistemos's Living Vault:
- **Execution trace → LLM diagnosis → targeted mutation → Pareto selection → constraint gates** is language-agnostic at the protocol level (send prompts to LLM API, parse responses).
- Apply to: self-optimizing retrieval prompts, evolving memory classification rules (ADD/UPDATE/DELETE/NOOP heuristics), adaptive note organization.
- Implement constraint gates in Rust: test suite pass, semantic preservation check, size limits, before committing changes to the Living Vault.
- Cost: ~$2–10 per optimization cycle via cloud API calls. No GPU training required.

### Updated binary size and performance targets

| Component | Target | Achievable? |
|-----------|--------|------------|
| `agent_core` crate (Goose-derived) | **8–12 MB** | ✅ With aggressive feature-gating |
| Cold start to first token | **<10ms** (agent binary) | ✅ Rust startup is ~1ms; 10ms budget covers IPC setup |
| Model load (router, from SSD cache) | **~1 second** | ✅ 3.4GB ÷ 3.5 GB/s SSD |
| Model load (reasoner, cold) | **~1.5 seconds** | ✅ 5.5GB ÷ 3.5 GB/s SSD |
| Router inference | **55–65 tok/s** | ✅ Qwen3.5 4B on M2 Pro MLX |
| Reasoner inference | **35–42 tok/s** | ✅ Qwen3.5 9B on M2 Pro MLX |
| Zero-copy IPC | **Apple Silicon UMA** | ✅ MLX uses unified memory natively |
| Total memory (router + reasoner + app + OS) | **~15–16 GB of 18 GB** | ✅ With 2–3GB headroom |

### Conclusion with novel insights

The Goose crate is not just a reference implementation—it's a production-grade agent runtime that eliminates the need to hand-roll HTTP streaming, provider format adapters, MCP compliance, extension lifecycle management, and session persistence. The `rmcp` SDK underneath it is now the official Rust MCP SDK. Taking Goose as a Cargo dependency and layering UniFFI bindings on top is the highest-leverage architectural decision available.

The quantization landscape has a sharp dividing line that most evaluations miss: **MLX-Swift only natively accelerates its own safetensors format**. Unsloth Dynamic 2.0 and K-quants are irrelevant on MLX despite being SOTA on llama.cpp. This simplifies the decision to a single rule: always use mlx-community 4-bit or 6-bit conversions.

The most surprising finding is the **Gemma 4 tool-calling gap**. Despite Google training native function calling into the model, the MLX ecosystem shipped day-0 support for inference but not for tool-call parsing. This makes Qwen 3.5's mature ecosystem more valuable today than Gemma 4's superior benchmarks. The window for Gemma 4 to become the default is 4–6 weeks—track the upstream parser merge.

Finally, the 18GB constraint is more binding than it appears. After macOS overhead, only **12–13GB is usable** for models and KV cache. This rules out all 26B+ models for always-available duty and makes the 4B router + 9B reasoner split the only viable dual-model configuration. The path to unlock the Gemma 4 26B-A4B MoE—the model with the best quality-per-compute ratio available—is a hardware upgrade to 24GB+ or SSD-streaming expert loading (the `flash-moe` pattern). Plan the architecture to accommodate this upgrade path.