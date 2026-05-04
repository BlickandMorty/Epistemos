# The real API landscape for AI reasoning apps in 2026

**Every major AI provider now offers a production API, but Swift SDK support remains scarce and many features developers assume exist are actually beta, deprecated, or nonexistent.** Of the 10+ providers researched, only Meta (via Llama Stack) and Apple (via MLX) ship official first-party Swift SDKs. Anthropic, OpenAI, Google, Mistral, DeepSeek, Cohere, and Qwen all lack one. The good news: nearly every cloud provider now exposes an OpenAI-compatible endpoint, meaning a single HTTP client can reach most of them. Computer use is real at both Anthropic and OpenAI, but both require your app to implement the screenshot-action loop — neither vendor controls your desktop remotely.

---

## Anthropic: Claude API

**Base URL:** `https://api.anthropic.com`
**Primary endpoint:** `POST /v1/messages`
**Auth:** `x-api-key` header + `anthropic-version: 2023-06-01`

### Models available

| Model | API identifier | Input / Output per MTok | Status |
|---|---|---|---|
| Claude Opus 4.6 | `claude-opus-4-6` | $5 / $25 | ✅ REAL |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | $3 / $15 | ✅ REAL |
| Claude Opus 4.5 | `claude-opus-4-5-20251101` | $5 / $25 | ✅ REAL |
| Claude Sonnet 4.5 | `claude-sonnet-4-5-20250929` | $3 / $15 | ✅ REAL |
| Claude Sonnet 4 | `claude-sonnet-4-20250514` | $3 / $15 | ✅ REAL |
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` | $1 / $5 | ✅ REAL |
| Claude Haiku 3.5 | `claude-3-5-haiku-20241022` | $0.80 / $4 | ✅ REAL |
| Claude Haiku 3 | `claude-3-haiku-20240307` | $0.25 / $1.25 | ⚠️ Retiring Apr 2026 |

### Feature audit

| Feature | Status | Notes |
|---|---|---|
| Tool use / function calling | ✅ REAL (GA) | JSON schema definitions, parallel + forced tool use |
| Vision (image input) | ✅ REAL (GA) | Base64 or URL, all current models |
| PDF support | ✅ REAL (GA) | Native text + visual extraction |
| Extended thinking | ✅ REAL (GA) | On Opus 4.6, Sonnet 4.6+ |
| Prompt caching | ✅ REAL (GA) | 5-min and 1-hour tiers, 0.1x read cost |
| Batch API | ✅ REAL (GA) | 50% discount, `/v1/messages/batches` |
| Citations | ✅ REAL (GA) | Source attribution in responses |
| Structured outputs | ✅ REAL (GA) | `output_config.format` on 4.5+ models |
| Web search tool | ✅ REAL (GA) | Server-side, $10/1K searches |
| Code execution tool | ✅ REAL (GA) | Sandboxed, free tier included |
| Streaming | ✅ REAL (GA) | SSE with fine-grained tool streaming |
| Token counting | ✅ REAL (GA) | `POST /v1/messages/count_tokens` |
| Computer use | ⚠️ BETA | See dedicated section below |
| Agent skills | ⚠️ BETA | PowerPoint, Excel, Word, PDF skills |
| Fast mode | ⚠️ BETA | Opus 4.6 only, 6x pricing |
| Free API tier | ❌ DOES NOT EXIST | Pay-per-token only, $5 minimum deposit |

### Computer use — how it actually works

Computer use is **not a separate API**. It is a set of Anthropic-defined tool types passed within the standard Messages API. Your app sends a request with tool definitions like `computer_20251124`, `text_editor_20250728`, and `bash_20250124`, along with a beta header (`anthropic-beta: computer-use-2025-11-24`). Claude returns `tool_use` content blocks specifying actions (click at coordinates, type text, take screenshot). **Your application must execute these actions and return screenshots as `tool_result` blocks.** Anthropic does not host or control any desktop.

A third-party macOS app **can** invoke computer use — it needs to capture screenshots (e.g., via CGWindowListCreateImage), simulate input (e.g., via CGEvent), and relay results through the API loop. This is entirely feasible and architecturally identical to Anthropic's reference Docker implementation.

### Claude Code

✅ **CLI tool, not an API.** Installed via `curl -fsSL https://claude.ai/install.sh | bash` (preferred) or `npm install -g @anthropic-ai/claude-code` (deprecated path). Uses the Messages API under the hood. Can be imported programmatically as a JS/TS module. Has `--print` mode for scripting. Can serve as an MCP server. **No separate "Claude Code API" exists.**

### MCP (Model Context Protocol)

✅ **Real open standard, production.** Wire format is JSON-RPC 2.0 over stdio (local) or Streamable HTTP (remote). Official spec at modelcontextprotocol.io, version `2025-11-25`. Official SDKs exist in **10 languages** including a Tier 3 **Swift SDK** at `modelcontextprotocol/swift-sdk`. The Claude API also has an MCP Connector feature for direct server connections.

### SDKs and Swift status

| SDK | Package | Status |
|---|---|---|
| Python | `pip install anthropic` | ✅ Official |
| TypeScript | `npm install @anthropic-ai/sdk` | ✅ Official |
| Go | `anthropics/anthropic-sdk-go` | ✅ Official |
| Java | Maven | ⚠️ Official beta |
| Swift (Claude API) | — | ❌ DOES NOT EXIST |
| Swift (MCP) | `modelcontextprotocol/swift-sdk` | ✅ Official Tier 3 |
| Community Swift | `SwiftAnthropic`, `AnthropicSwiftSDK` | 🔧 COMMUNITY |

**Rate limits** use a tiered system: Tier 1 ($5 deposit, $100/mo), scaling to Tier 4 ($400 deposit, $200K/mo). Token bucket algorithm with RPM, ITPM, and OTPM limits per model family.

---

## OpenAI: the platform with three API layers

**Base URL:** `https://api.openai.com/v1/`

OpenAI now maintains **three API surfaces**: Chat Completions (stable workhorse), Responses (primary going forward), and Realtime (voice/multimodal). The Assistants API is deprecated with a sunset date of **August 26, 2026**.

### The Responses API is now primary

✅ **`POST /v1/responses`** — introduced March 2025, now OpenAI's recommended API. It combines Chat Completions' simplicity with built-in tools: **web search**, **file search**, **computer use**, **code interpreter**, **image generation**, **MCP servers**, and **function calling**. It supports background mode for long-running tasks, conversation state via the Conversations API, and WebSocket streaming. Chat Completions remains fully supported but lacks built-in tools.

### Models (selected, as of March 2026)

| Model | Input / Output per MTok | Notes |
|---|---|---|
| gpt-5.4 | $2.50 / $15.00 | Latest flagship |
| gpt-5.4-mini | $0.75 / $4.50 | Fast, affordable |
| gpt-5.4-nano | $0.20 / $1.25 | Ultra-cheap |
| gpt-4.1 | $2.00 / $8.00 | 1M context |
| gpt-4o | $2.50 / $10.00 | Still widely used |
| gpt-4o-mini | $0.15 / $0.60 | Budget |
| o3 | $2.00 / $8.00 | Reasoning |
| o4-mini | $0.55 / $2.20 | Cheap reasoning |

### Computer use — the real API surface

⚠️ **PREVIEW.** OpenAI offers a `computer-use-preview` model (snapshot `2025-03-11`) accessible through the Responses API. Like Anthropic's implementation, your app sends screenshots and receives action instructions. The model does **not** directly control any computer. Requires **Tier 3+ access** plus company verification. GPT-5.4 also includes computer use training. **Operator** was a consumer product integrated into ChatGPT in July 2025 — ❌ there is no standalone "Operator API."

A third-party macOS app **can** use OpenAI's computer use via the Responses API, implementing the same screenshot → action → screenshot loop as with Anthropic.

### Codex and Realtime

**Codex CLI** is ✅ real, open-source, distributed via npm. The old `code-davinci` API is ❌ sunset. Modern Codex models (`gpt-5.x-codex`) are ✅ available via the Responses API only. The **Realtime API** is ✅ GA, supporting WebRTC, WebSocket, and SIP transports for low-latency voice and multimodal streaming.

### SDKs and Swift status

| SDK | Package | Status |
|---|---|---|
| Python | `pip install openai` | ✅ Official |
| TypeScript | `npm install openai` | ✅ Official |
| C# / .NET | NuGet `OpenAI` | ✅ Official |
| Java | OpenAI Java SDK | ✅ Official |
| Go | `github.com/openai/openai-go` | ⚠️ Official beta |
| Swift | — | ❌ DOES NOT EXIST |
| Community Swift | `MacPaw/OpenAI`, `SwiftOpenAI` | 🔧 COMMUNITY |

**Free tier exists** but is limited — $100 max credit, restricted models and rate limits. Paid tiers from Tier 1 ($5) to Tier 5 ($1K+, $200K/mo limit).

---

## Google: Gemini, Gemma, and the Firebase pivot

**Base URL:** `https://generativelanguage.googleapis.com`
**OpenAI-compatible endpoint:** `https://generativelanguage.googleapis.com/v1beta/openai/`

### Gemini models

The **Gemini 2.5 family is stable/GA**: `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`. The **Gemini 3.x family is preview-only**: `gemini-3.1-pro-preview`, `gemini-3-flash-preview`, `gemini-3.1-flash-lite-preview`. Gemini 2.0 and 1.5 are deprecated or shut down.

**All confirmed features:** ✅ grounding with Google Search, ✅ code execution, ✅ function calling, ✅ thinking mode with controllable budgets, ✅ context caching (paid tier, 75% savings), ✅ structured outputs/JSON mode, ✅ 1M token context, ✅ batch API (50% off), ✅ Live API for bidirectional streaming, ✅ OpenAI SDK compatibility.

**Free tier is real** — no credit card required, includes Gemini 2.5 Pro/Flash/Flash-Lite. **Not available in EU/EEA/UK/Switzerland.** Free tier limits: 5 RPM for 2.5 Pro, 10 RPM for 2.5 Flash.

### Gemma: local-only, not API-served

❌ **Gemma is NOT available through the Gemini API.** It is a download-and-run-locally family of open-weight models. Distributed via Kaggle and Hugging Face (`google/gemma-3-*`). Current lineup: Gemma 3 (1B–27B), Gemma 3n for mobile, Gemma 3 QAT for consumer hardware. Google provides **Gemma.cpp** (official C++ inference) and **MediaPipe LLM Inference API** for on-device. MLX-format weights are 🔧 community-converted, not official Google artifacts — though Google acknowledges MLX as a supported framework.

### The Swift situation is complicated

The standalone `generative-ai-swift` SDK is ❌ **deprecated and archived**. The current official path for Swift developers is ✅ **Firebase AI Logic** (`FirebaseAILogic` library within `firebase-ios-sdk`). This requires Firebase as a dependency. **There is no standalone Google GenAI SDK for Swift** — server-side Swift developers must use the REST API directly.

Official SDKs: Python (`google-genai`), JavaScript (`@google/genai`), Go (`google.golang.org/genai`), Java (`com.google.genai`), C# (`Google.GenAI`) — all GA.

---

## Meta, DeepSeek, Qwen, Mistral, and Cohere

### Meta / Llama

The **Llama API at llama.com** is ⚠️ **preview/limited rollout** — not yet full GA. It serves Llama 4 Scout (17B active, 16 experts) and Maverick (17B active, 128 experts) with OpenAI SDK compatibility. **Llama Stack** (`meta-llama/llama-stack`) is the official framework with a **real Swift client** at `llama-stack-client-swift` — this is the only provider besides Apple with an official first-party Swift SDK for LLM inference. Models use the **Llama Community License** (commercial use allowed under 700M MAU). 25+ API partners (AWS Bedrock, Groq, Cerebras, Together AI, etc.) serve Llama models.

### DeepSeek

✅ **Production API** at `https://api.deepseek.com`, fully OpenAI-compatible. Two endpoints: `deepseek-chat` (standard) and `deepseek-reasoner` (chain-of-thought). **Extremely cheap**: $0.28/MTok input, $0.42/MTok output, with automatic caching at $0.028/MTok. Features include function calling, JSON mode, FIM completion (beta). ❌ No vision in the main API. ⚠️ **Reliability is a real concern**: **78+ tracked outages** since January 2025, averaging 2.7 incidents per month. Production apps should implement fallback providers. All model weights are **MIT licensed** on Hugging Face. ❌ No official Swift SDK, but OpenAI-compatible clients work.

### Qwen / Alibaba

✅ **DashScope API is available internationally** — not China-only. International endpoints at `dashscope-intl.aliyuncs.com` (Singapore) and `dashscope-us.aliyuncs.com` (Virginia). OpenAI-compatible mode supported. Massive model lineup including Qwen3-Max, Qwen3.5-Plus/Flash, vision models (Qwen-VL), coding models, and open-weight models served via API. Open weights on Hugging Face under **Apache 2.0** license (most models). ❌ No official Swift SDK.

### Mistral

✅ **Production API** at `https://api.mistral.ai/v1/`, OpenAI-compatible. Current flagship: Mistral Large 3 (675B MoE, Apache 2.0). Key differentiator: ✅ **real FIM endpoint** at `/v1/fim/completions` with separate Codestral endpoint at `codestral.mistral.ai`. ⚠️ **Agents API is beta** with conversation state, handoffs, MCP support, and built-in tools (web search, code interpreter, image gen). SDKs: Python (`mistralai`), TypeScript (`@mistralai/mistralai`). ❌ No Swift SDK. Free "Experiment" tier available.

### Cohere

✅ **Production API** at `https://api.cohere.com/` (v2). Standout features: ✅ **dedicated Rerank endpoint** (`/v2/rerank`) and ✅ **Embed endpoint** (`/v2/embed`) with multimodal support — unique capabilities not offered by most competitors. Current flagship: Command A. OpenAI SDK compatibility available. SDKs: Python (`cohere`), TypeScript (`cohere-ai`), Java, Go. ❌ No Swift SDK. ✅ **Free trial key** (1,000 API calls/month, not for production).

---

## Local inference frameworks for macOS

### Ollama

✅ **Production.** REST API at `http://localhost:11434`. Exposes both native endpoints (`/api/chat`, `/api/generate`, `/api/embed`) and **OpenAI-compatible endpoints** (`/v1/chat/completions`, `/v1/embeddings`, `/v1/models`, `/v1/responses`). Also has **Anthropic-compatible** endpoints. Supports streaming, vision, tool calling, JSON mode, and thinking models. Official SDKs: Python (`ollama`), JavaScript (`ollama`). ❌ No official Swift SDK. A macOS app connects via HTTP to the Ollama service.

### llama.cpp

✅ **Production.** `llama-server` exposes OpenAI-compatible endpoints at `http://localhost:8080/v1` plus native endpoints for completion, tokenization, embedding, fill-in-middle, and reranking. Supports parallel decoding, continuous batching, speculative decoding, structured output, and tool use. Can be embedded as a **C/C++ library** directly in a macOS app via Swift/C++ interop. Community Swift bindings exist (`llama-cpp-swift`, `StanfordBDHG/llama.cpp` XCFramework). ❌ No official Swift bindings.

### MLX (Apple)

✅ **Official Apple framework.** The most relevant local inference option for a macOS app.

- **`mlx-swift`** (`github.com/ml-explore/mlx-swift`) — Low-level ML array framework for Swift. MIT licensed. Supports macOS, iOS, iPadOS, visionOS.
- **`mlx-swift-lm`** (`github.com/ml-explore/mlx-swift-lm`) — **High-level LLM and VLM inference in Swift.** Provides `MLXLLM`, `MLXVLM`, `MLXLMCommon`, and `MLXEmbedders` libraries. Loads models from Hugging Face Hub, supports chat sessions with streaming, LoRA fine-tuning. This is the key package for Epistemos.
- **`mlx-swift-examples`** — Official example apps including LLMEval and chat demos for iOS/macOS.
- Models hosted on Hugging Face `mlx-community` organization. Compatible with LLaMA, Gemma, Qwen, DeepSeek, Mistral, and most major architectures.

**MLX does not expose an HTTP server.** It is an embedded library. LM Studio uses MLX as one of its backends.

⚠️ Apple's own documentation notes MLX is "intended for research and not for production deployment," but WWDC 2025 sessions actively pushed broader adoption with full Swift API support and iOS examples. The positioning is evolving.

### LM Studio

✅ **Free for personal and commercial use.** Local server at `http://localhost:1234` with **OpenAI-compatible**, **Anthropic-compatible**, and native REST endpoints. Supports `/v1/chat/completions`, `/v1/responses`, and `/v1/messages`. Official SDKs: TypeScript (`@lmstudio/sdk`), Python (`lmstudio`). Ships both llama.cpp and MLX inference backends. Headless daemon mode available via `llmster`.

---

## Which APIs have official Swift SDKs?

This is the critical question for Epistemos. The answer is stark:

| Provider | Official Swift SDK? | Details |
|---|---|---|
| Anthropic (Claude API) | ❌ No | Community: `SwiftAnthropic`, `AnthropicSwiftSDK` |
| Anthropic (MCP) | ✅ Yes | `modelcontextprotocol/swift-sdk` (Tier 3) |
| OpenAI | ❌ No | Community: `MacPaw/OpenAI`, `SwiftOpenAI` |
| Google (Gemini) | ⚠️ Complicated | Standalone deprecated; ✅ Firebase AI Logic is current path |
| Meta (Llama Stack) | ✅ Yes | `llama-stack-client-swift` |
| DeepSeek | ❌ No | Community: `DeepSwiftSeek`, `DeepSeekKit` |
| Qwen / Alibaba | ❌ No | — |
| Mistral | ❌ No | — |
| Cohere | ❌ No | — |
| Apple MLX | ✅ Yes | `mlx-swift`, `mlx-swift-lm` |
| Ollama | ❌ No | — |
| LM Studio | ❌ No | TypeScript and Python only |

**The practical implication:** For a macOS app, the most reliable integration path for cloud APIs is to use the **OpenAI-compatible endpoint pattern** with a single HTTP client, since nearly every provider now supports it.

---

## OpenAI-compatible endpoint map

Nearly every provider now supports the OpenAI Chat Completions format, enabling a single client to reach multiple backends:

| Provider | Base URL | Notes |
|---|---|---|
| OpenAI | `https://api.openai.com/v1` | Canonical |
| Anthropic | ❌ Not compatible | Must use Messages API |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai/` | ✅ Real |
| DeepSeek | `https://api.deepseek.com/v1` | ✅ Full compat |
| Qwen / DashScope | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` | ✅ Real |
| Mistral | `https://api.mistral.ai/v1` | ✅ Native compat |
| Cohere | Compatibility endpoint documented | ✅ Real |
| Meta Llama API | `https://api.llama.com/compat/v1` (check) | ✅ Claimed |
| Ollama | `http://localhost:11434/v1` | ✅ Real |
| llama.cpp | `http://localhost:8080/v1` | ✅ Real |
| LM Studio | `http://localhost:1234/v1` | ✅ Real |

Anthropic is the notable exception — it uses its own Messages API format and does not offer an OpenAI-compatible endpoint.

---

## Tool use and function calling interoperability

Tool use schemas are **not interoperable** across providers. While the concept is similar (define tools with JSON Schema, model returns tool call requests), the wire formats differ:

- **OpenAI format**: `tools` array with `type: "function"`, `function.name`, `function.parameters`. Used by OpenAI, Mistral, DeepSeek, Qwen, Ollama, llama.cpp, LM Studio.
- **Anthropic format**: `tools` array with `name`, `description`, `input_schema`. Different field names and response structure (`tool_use` content blocks vs. `tool_calls`).
- **Google format**: `tools` with `function_declarations` containing `name`, `description`, `parameters`. Yet another schema variant.
- **Cohere format**: v2 API uses OpenAI-compatible tool format; native format uses `tools` with a different schema.

For Epistemos, building an abstraction layer that normalizes tool definitions across providers is essential. The OpenAI format is the de facto standard — Mistral, DeepSeek, Qwen, and all local frameworks adopt it.

---

## Common misconceptions to guard against

These are features developers frequently assume exist but **do not**:

- ❌ **"Anthropic has a Swift SDK"** — It does not. Only community packages exist. (MCP has an official Swift SDK, but the Claude API does not.)
- ❌ **"OpenAI has a Swift SDK"** — It does not. `MacPaw/OpenAI` is community-maintained.
- ❌ **"Google still has a standalone Swift SDK"** — `generative-ai-swift` is archived. Firebase AI Logic is the replacement.
- ❌ **"Operator has an API"** — Operator was a consumer product folded into ChatGPT. The computer use *capability* exists in the Responses API, but "Operator" is not an API.
- ❌ **"Computer use means the AI controls your computer"** — Both Anthropic and OpenAI require YOUR app to execute actions and send screenshots. The API returns instructions, not control.
- ❌ **"Gemma models are available via the Gemini API"** — They are not. Gemma is local-only (or Vertex AI deployment).
- ❌ **"DeepSeek has vision in its main API"** — The `deepseek-chat` and `deepseek-reasoner` endpoints do not support image input.
- ❌ **"The Assistants API is the recommended OpenAI API"** — It's deprecated. Responses API is now primary.
- ❌ **"Anthropic's API is free to try"** — There is no free tier. $5 minimum deposit required.
- ❌ **"MLX has a server/REST API"** — MLX is an embedded library only. No HTTP server.

---

## Local model distribution and licenses

| Model Family | Official Source | License | Commercial Use |
|---|---|---|---|
| Llama 4 | llama.com, HuggingFace `meta-llama/` | Llama 4 Community License | ✅ Yes (under 700M MAU) |
| DeepSeek V3.2 / R1 | HuggingFace `deepseek-ai/` | **MIT** | ✅ Fully permissive |
| Qwen 3 / 3.5 | HuggingFace `Qwen/`, ModelScope | **Apache 2.0** | ✅ Fully permissive |
| Gemma 3 | Kaggle, HuggingFace `google/` | Gemma Terms of Use | ✅ Yes, with restrictions |
| Mistral (open) | HuggingFace `mistralai/` | **Apache 2.0** | ✅ Fully permissive |

DeepSeek and Qwen offer the most permissive licenses (MIT and Apache 2.0 respectively). Llama's community license is more restrictive for large-scale deployment. All models are available in GGUF format for llama.cpp/Ollama and many in MLX format via the `mlx-community` Hugging Face organization.

---

## Conclusion: what Epistemos should actually build against

For a local-first macOS reasoning app, the architecture should layer three integration tiers. **Tier 1 (embedded):** MLX via `mlx-swift-lm` for zero-dependency local inference — this is the only production-quality path for running models directly inside a Swift app on Apple Silicon. **Tier 2 (local server):** Ollama or LM Studio via their OpenAI-compatible HTTP endpoints at localhost, giving access to the full GGUF model ecosystem with minimal code. **Tier 3 (cloud):** A unified HTTP client targeting the OpenAI-compatible endpoint pattern, covering OpenAI, Google, DeepSeek, Qwen, Mistral, and Cohere — with a separate Anthropic adapter for the Messages API format.

The MCP Swift SDK (`modelcontextprotocol/swift-sdk`) is real and official — building MCP server/client support into Epistemos would enable integration with Claude Desktop, Cursor, and the broader MCP ecosystem. For computer use features, both Anthropic and OpenAI provide real APIs, but Epistemos must implement the entire screenshot-capture and input-simulation layer natively using macOS APIs. No provider offers turnkey desktop control — they all return action instructions that your app must execute.