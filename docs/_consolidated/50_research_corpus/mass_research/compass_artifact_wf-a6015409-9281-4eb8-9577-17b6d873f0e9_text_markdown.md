# Building Epistemos: a hybrid local-first + cloud AI architecture for macOS

**The most effective architecture for adding cloud AI to a local-first macOS app is deceptively simple: a protocol-based provider abstraction backed by AsyncThrowingStream, a confidence-based routing layer that defaults to local models, and BYOK (Bring Your Own API Key) authentication as the only legitimate auth path.** This approach mirrors what production tools like Claude Code, Cursor, and Continue.dev have validated at scale. The key insight from studying these systems is that minimal orchestration with maximum model trust outperforms complex scaffolding — Claude Code's entire agent loop is essentially a while-true loop with tool dispatch, and 90% of its code was written by itself.

This report synthesizes findings across seven research domains: cloud API integration patterns, the Model Context Protocol (MCP), Anthropic's Computer Use API, authentication models, model capability mapping, Claude Code's architecture, and hybrid dispatch design. Each section includes Swift-specific implementation guidance for Epistemos.

---

## How production apps integrate cloud APIs alongside local models

The dominant apps in this space — Continue.dev, Cursor, VS Code Copilot, and Void — each take a distinct architectural approach, but all converge on one principle: **a unified provider interface that abstracts away the differences between local and cloud inference**.

**Continue.dev** (open-source, TypeScript) implements an `ILLM` interface with a `BaseLLM` base class. Each provider (Anthropic, OpenAI, Gemini, Ollama) extends `BaseLLM` and only needs to implement provider-specific streaming methods — everything else (message compilation, token counting, context window management) is inherited. A separate `openai-adapters` package normalizes non-OpenAI APIs into OpenAI-compatible format, and a `toolSupport.ts` module handles capability detection per provider. **Cursor** routes all API calls through its own proxy service, which handles auth, rate limiting, and model selection. Its "Auto" mode automatically selects the best model based on task complexity, and Cursor 2.0 runs up to 8 parallel agents isolated via Git worktrees. **VS Code Copilot** uses the `vscode.lm` API as a universal adapter — extensions never communicate directly with provider APIs; instead, `vscode.lm.selectChatModels()` handles discovery and routing, making tool calling identical across all providers. **Void** (open-source, now paused) takes the privacy-maximalist approach: messages go directly to providers with zero backend dependency.

For Swift specifically, two libraries stand out as references. **AnyLanguageModel** by mattt (Hugging Face) mirrors Apple's Foundation Models framework API and supports CoreML, MLX, llama.cpp, Ollama, OpenAI, Anthropic, and Gemini through a single `import AnyLanguageModel` statement, using SPM package traits to conditionally include heavy local dependencies. **SwiftAI** by mi12labs offers a clean `any LLM` protocol with streaming via AsyncSequence and first-class tool support. Both are MIT-licensed and pre-1.0.

### The provider protocol Epistemos needs

Based on analysis of all these frameworks, the critical abstraction points for a Swift provider protocol are:

- **Streaming normalization**: Use `AsyncThrowingStream<StreamChunk, Error>` as the universal interface. Local providers wrap synchronous token callbacks into AsyncThrowingStream; cloud providers map SSE events into the same type. This is the single most important design decision.
- **System message handling**: Anthropic requires system messages as a separate parameter (not in the messages array), while OpenAI allows flexible placement. Design the protocol with system prompts as a separate parameter to satisfy all providers.
- **Message ordering validation**: Anthropic enforces strict user→assistant alternation; OpenAI and local models are flexible. The abstraction layer should validate and merge messages per-provider.
- **`maxTokens` always explicit**: Required by Anthropic, good practice universally.
- **Capability detection**: Each provider declares its capabilities (tool calling, vision, thinking, computer use) via a `LLMCapabilities` struct, allowing the app to adapt behavior dynamically.

The key provider-specific differences the abstraction must bridge:

| Aspect | OpenAI | Anthropic | Local (llama.cpp/MLX) |
|--------|--------|-----------|----------------------|
| Streaming format | `chat.completion.chunk` events | `content_block_delta` SSE events | Synchronous token callback |
| Auth header | `Authorization: Bearer` | `x-api-key` | None |
| Tool schema key | `parameters` inside `function` | `input_schema` | OpenAI-compatible |
| Tool call response | `tool_calls` array on message | `tool_use` content block | OpenAI-compatible |
| Arguments format | JSON string | Parsed JSON object | JSON string |
| Embeddings API | Full API | Not available | Local computation |

---

## MCP brings a universal tool layer to both local and cloud models

The Model Context Protocol (MCP), introduced by Anthropic in November 2024 and donated to the Linux Foundation's Agentic AI Foundation in December 2025, has become the standard for connecting AI applications to external tools and data sources. The ecosystem now includes **19,000+ MCP servers**, with 97M+ monthly SDK downloads.

MCP defines three roles: **Hosts** (applications like Epistemos), **Clients** (connectors maintaining 1:1 server connections), and **Servers** (services providing tools, resources, and prompts). Communication uses **JSON-RPC 2.0** over two primary transports: **stdio** for local subprocess servers (filesystem, git, databases) and **Streamable HTTP** for remote servers. The latest spec version is 2025-11-25.

### Two paths for integrating MCP with Claude

The Anthropic API now **natively supports MCP** through the MCP Connector (public beta since May 2025). You can pass remote MCP server URLs directly in the Messages API request, and Anthropic's infrastructure handles connection management, tool discovery, and execution:

```json
{
  "mcp_servers": [{
    "type": "url",
    "url": "https://your-server.com/mcp/",
    "name": "my-tools",
    "authorization_token": "YOUR_TOKEN",
    "tool_configuration": {"enabled": true, "allowed_tools": ["search"]}
  }]
}
```

This is the simplest integration path — no client-side MCP code needed. However, it's limited to remote HTTP servers and tools only (not resources or prompts). The alternative is **client-side MCP**, where Epistemos acts as the MCP host using the official Swift SDK and orchestrates tool calls directly.

### The official Swift SDK is production-ready

The official SDK at `github.com/modelcontextprotocol/swift-sdk` (1.2k stars) implements the full protocol. It requires Swift 6.0+ and macOS 13.0+:

```swift
import MCP
let client = Client(name: "Epistemos", version: "1.0.0")

// Local server via stdio
let transport = StdioTransport()
try await client.connect(transport: transport)

// Discover tools
let (tools, _) = try await client.listTools()

// Call a tool
let (content, isError) = try await client.callTool(
    name: "search", arguments: ["query": "recent changes"]
)
```

**Critical macOS note**: Stdio servers require disabling app sandboxing since the app must launch child processes. The SDK also supports `HTTPClientTransport` for remote servers and implements sampling (server-initiated LLM requests), resource subscriptions, request batching, and notification handlers.

### How Claude Code uses MCP as a model for Epistemos

Claude Code's MCP integration demonstrates the most mature pattern. It supports three configuration scopes (local per-project, project-shared via `.mcp.json`, and user-global), all three transports (HTTP recommended for remote, stdio for local), and a **Tool Search** feature that defers tool schema loading — only tool names are indexed at session start, with full schemas loaded on-demand when Claude needs them. This reduces context usage by **~47%** when many MCP servers are connected. Tool Search requires Sonnet 4+ or Opus 4+ models. Claude Code can also expose itself as an MCP server (`claude mcp serve`), letting other tools like Cursor access its built-in file editing, bash, and search capabilities.

---

## Computer Use turns Epistemos into a screen-controlling agent

Anthropic's Computer Use API enables Claude to see screenshots, move the mouse, click, type, and navigate applications. It's a beta feature available on **all current Claude models** (Opus 4.6, Sonnet 4.6, Opus 4.5, Sonnet 4.5, Haiku 4.5, and earlier 4.x models) with the appropriate beta header.

### The API is schema-less and action-based

The computer use tool is built into the model — you don't provide an input schema. You declare display dimensions and Claude returns action requests:

```json
{"type": "computer_20251124", "name": "computer",
 "display_width_px": 1024, "display_height_px": 768}
```

Available actions include `screenshot`, `left_click` (with coordinates), `type`, `key` (combos like `ctrl+s`), `mouse_move`, `scroll`, `double_click`, `left_click_drag`, `hold_key`, `wait`, and `zoom` (for viewing specific screen regions at full resolution). Claude responds with `stop_reason: "tool_use"` and your app executes the action, captures a new screenshot, and returns it as a base64-encoded PNG `tool_result`.

### The agentic loop is straightforward

The core cycle is: **capture screenshot → send to Claude → execute requested action → capture new screenshot → repeat until Claude responds with text instead of tool calls**. Anthropic explicitly recommends **XGA resolution (1024×768)** for screenshots, with images constrained to max 1568 pixels on the longest edge and ~1.15 megapixels total.

### macOS implementation requires three coordinate spaces

This is the trickiest part of a macOS implementation. There are three coordinate systems to bridge:

- **Native pixels**: What ScreenCaptureKit returns on Retina displays (e.g., 2880×1800 on a 14" MacBook Pro)
- **macOS points**: What CGEvent coordinates use (e.g., 1440×900) — **CGEvent operates in point space**
- **API coordinates**: What Claude sees (1024×768 per Anthropic's recommendation)

The correct approach: capture screenshots using `SCScreenshotManager` or `CGWindowListCreateImage` with `.nominalResolution` (point-sized output), resize to 1024×768 for the API, then when Claude returns coordinates `(cx, cy)`, map back: `pointX = cx × (screenWidth / 1024)`, `pointY = cy × (screenHeight / 768)`. CGEvent uses these point coordinates directly.

**Required permissions**: Accessibility (for CGEvent posting to other apps — `AXIsProcessTrustedWithOptions`), Screen Recording (`CGPreflightScreenCaptureAccess()`), and importantly, **the app cannot be sandboxed** for App Store distribution if it controls other apps.

### Safety guardrails are non-negotiable

Anthropic's official recommendations include running computer use in isolated environments, requiring human confirmation for destructive actions (financial transactions, file deletion, email sending), domain allowlisting to reduce prompt injection risk, and keeping credentials out of the model's view. Claude has built-in prompt injection classifiers that detect malicious on-screen content, but the model remains vulnerable to commands found in screenshots that conflict with user instructions. Implement a **kill switch** (global hotkey), action rate limiting (~30 actions/minute), coordinate validation, and logging of every screenshot and action.

---

## The subscription versus API key divide is absolute

**Anthropic maintains two completely separate authentication systems, and the boundary is aggressively enforced.** Claude.ai subscriptions (Pro at $20/mo, Max at $100-200/mo) use OAuth tokens with prefix `sk-ant-oat01-*`. Console API keys (pay-as-you-go per-token) have prefix `sk-ant-api03-*`. You cannot use subscription tokens for API access — they're rejected with "OAuth authentication is currently not supported."

### Claude Code's authentication reveals the full picture

Claude Code uses a strict priority chain: cloud provider credentials (Bedrock/Vertex/Foundry) → `ANTHROPIC_AUTH_TOKEN` env var (Bearer header for proxies) → `ANTHROPIC_API_KEY` env var (X-Api-Key header) → `apiKeyHelper` script (dynamic credentials from vaults) → subscription OAuth from `/login`. The OAuth flow uses OAuth 2.0 with PKCE, opening a browser to `claude.ai/oauth/authorize`, with tokens stored in `~/.claude/.credentials.json`. **Critically, if `ANTHROPIC_API_KEY` is set, it takes precedence over subscription OAuth**, which can cause unexpected API billing.

### For third-party apps, BYOK is the only legitimate path

Anthropic's February 2026 TOS clarification made this explicit: "Using OAuth tokens obtained through Claude Free, Pro, or Max accounts in any other product, tool, or service is not permitted and constitutes a violation of the Consumer Terms of Service." Anthropic does not offer a third-party OAuth flow. Community proxy tools (CLIProxyAPI, claude-max-api-proxy, Meridian) that bridge subscription auth to API-compatible endpoints are all TOS violations, and Anthropic has actively blocked these since January 2026.

OpenAI maintains the same separation — ChatGPT Plus/Pro subscriptions provide zero API access. However, OpenAI has invested in robust third-party OAuth for Custom GPTs and its Apps SDK (MCP), supporting OAuth 2.1 with PKCE and Dynamic Client Registration.

**The recommended pattern for Epistemos**: BYOK with Keychain storage. Users generate API keys at `console.anthropic.com` and paste them in. Store keys using the Security framework with `kSecAttrAccessibleWhenUnlocked` and `kSecAttrSynchronizable: false` (preventing iCloud sync). Never store in UserDefaults or plist files. Support multiple providers (Anthropic, OpenAI, Google) with separate Keychain entries.

---

## Every current Claude model supports tool use, but thinking capabilities diverge

All current Anthropic models (Opus 4.6, Sonnet 4.6, Opus 4.5, Sonnet 4.5, Haiku 4.5, and all 4.x models) support **tool use, parallel tool use, computer use (beta), vision, and PDF processing**. The differentiation lies in thinking capabilities and newer features.

### The thinking model evolution matters for Epistemos

**Claude 4.6 models** (Opus 4.6, Sonnet 4.6) introduce **adaptive thinking** — Claude decides when and how deeply to think. Use `thinking: {type: "adaptive"}` with an optional `effort` parameter (low/medium/high/max). The old `budget_tokens` parameter is deprecated for these models. Interleaved thinking (thinking blocks between tool calls) is automatic.

**Claude 4.x models** (Opus 4/4.1/4.5, Sonnet 4/4.5, Haiku 4.5) use **extended thinking** with explicit budget: `thinking: {type: "enabled", budget_tokens: N}` (minimum 1,024 tokens). They return summarized thinking tokens. Interleaved thinking requires the beta header `interleaved-thinking-2025-05-14`.

**Anthropic provides the best programmatic capability detection** via `GET /v1/models`, which returns a structured `capabilities` object including booleans for `batch`, `citations`, `code_execution`, `computer_use`, `thinking` variants, `effort` levels, `structured_outputs`, and `context_management` strategies. **OpenAI's `/v1/models` endpoint returns only basic metadata — no capability information**, requiring a static mapping. Gemini's `models.get()` falls in between.

### Cross-provider capability summary

| Feature | Anthropic Claude | OpenAI GPT/o-series | Google Gemini |
|---------|-----------------|---------------------|---------------|
| Tool use / function calling | All current models | All GPT-4+, all o-series, all GPT-5 | All Gemini 1.5+ |
| Computer use | Beta on all current models | CUA via Responses API (GPT-5.4 default) | No API equivalent |
| Adaptive/extended thinking | 4.6 adaptive; 4.x extended | Reasoning levels in GPT-5+; dedicated o-series | thinking_level in Gemini 3.x |
| Web search (server-side) | Web search tool | Built-in web search tool | Built-in Google Search grounding |
| Structured outputs | Sonnet 4.5+, Opus 4.1+ | All recent models | Gemini 3 only |
| Capability detection API | Excellent | Poor (no metadata) | Moderate |

**Recommendation for Epistemos**: Use Anthropic's Models API as the primary capability source. Maintain a static fallback map for OpenAI models. Always use pinned model versions (e.g., `claude-opus-4-6-20260204`) for production stability. "Deep Research" is a consumer product feature at all three providers, not a separate API endpoint — but web search tools with high `max_uses` plus extended thinking effectively enable research-like behavior.

---

## Claude Code's architecture offers a blueprint for Epistemos

Claude Code ships as a **single ~10.5MB `cli.js` file** built with TypeScript, React/Ink (terminal UI), and Bun, with vendored ripgrep binaries and Tree-sitter WASM modules. Its source is available at `github.com/anthropics/claude-code` under commercial terms. Remarkably, **90% of its code is written by Claude Code itself**, with the ~12-person team pushing 60-100 internal releases daily.

### The master loop is deliberately minimal

Anthropic's explicit philosophy is **"the product is the model"** — minimal scaffolding, maximum model trust. The entire agent loop:

```
while (true) {
  const response = await callAPI(messages);
  messages.push(response);
  if (response.stop_reason === "end_turn") break;
  const results = await executeTools(response);
  messages.push({ role: "user", content: results });
}
```

The model decides which tools to use, in what order, and how to combine them. The harness only executes. An async dual-buffer queue (`h2A`) enables pause/resume and user interjections mid-task without full restarts.

### The tool set is small and orthogonal

Claude Code uses ~15 built-in tools following a consistent JSON-call → sandboxed-execution → plain-text-result interface. The core six — **Read, Write, Edit, Bash, Glob, Grep** — cover 95% of coding work. Sub-agents (via the Task tool) handle exploration and parallel work but **cannot spawn their own sub-agents**, preventing recursive explosion. Sub-agents get a subset of the main agent's tools and operate in separate context windows.

### Context management avoids RAG entirely

**Claude Code does not use RAG, embeddings, or vector databases.** Instead, it uses **"just-in-time" context** — maintaining lightweight identifiers (file paths, stored queries) and using Glob/Grep/Read to dynamically load data at runtime. A Compressor triggers at ~92% context window usage, summarizing conversation history while preserving architectural decisions, unresolved bugs, and the 5 most recently accessed files. `CLAUDE.md` files provide persistent project memory loaded at session start. TodoWrite serves as structured in-session memory, with system messages injecting the current TODO state after tool uses.

### Ten patterns Epistemos should adopt

The most transferable patterns from Claude Code are: **(1)** Simple loop with smart model — don't over-engineer orchestration; **(2)** minimal, orthogonal tool set with clear purpose per tool; **(3)** depth-limited sub-agents that feed results back as regular tool outputs; **(4)** just-in-time context retrieval over pre-loaded embeddings; **(5)** compaction with careful preservation of critical context; **(6)** three-tier permissions (allow/ask/deny) with per-tool granularity; **(7)** diffs-first transparency for all changes; **(8)** MCP for extensibility rather than custom integrations; **(9)** progressive disclosure for large codebases via search tools; and **(10)** context engineering over prompt engineering — optimizing the entire configuration of system prompts, tool definitions, conversation history, and memory, not just individual prompts.

---

## Designing the hybrid dispatch layer

The academically validated pattern for hybrid local-cloud routing is **confidence-based escalation**: route every request to the local model first, compute a confidence score, and escalate to cloud only when confidence falls below a threshold. Research by Xin (2025) found this approach achieves **94% accuracy** (vs 95% cloud-only, 72% local-only) while **reducing cloud API usage by 61%** and median latency by 40%.

For a practical macOS app, a simpler approach works well: a **lightweight local classifier** (7B model, ~8GB RAM, always loaded) categorizes requests into types (GENERAL, CODE, REASONING, AGENTIC) and dispatches accordingly. Classification takes <300ms with temperature 0.0 and max tokens 10. Tasks requiring tool use, web search, computer use, or multi-step reasoning route to cloud; everything else stays local. On M4 Mac Studio, cold-loading a 7B model from NVMe takes 3-5 seconds — the fix is disclosure, not speed.

### Tool calling requires a translation layer

The tool calling formats differ significantly. Anthropic uses `input_schema` with `tool_use` content blocks and parsed JSON objects for arguments. OpenAI wraps tools in `function` objects with `parameters` and returns JSON strings for arguments. The pragmatic approach: **use OpenAI format as the canonical internal representation** (since Ollama and local models also speak it), then write thin adapter layers that convert to Anthropic's format when needed. This is exactly what LiteLLM and Vercel AI SDK do in production.

### Streaming in Swift is native with modern async/await

Swift's `URLSession.AsyncBytes` handles SSE streaming naturally:

```swift
let (bytes, _) = try await URLSession.shared.bytes(for: request)
for try await line in bytes.lines {
    guard let token = parseSSE(line) else { continue }
    continuation.yield(.text(token))
}
```

Anthropic's streaming uses typed events (`content_block_start`, `content_block_delta`, `content_block_stop`, `message_start`, `message_delta`, `message_stop`) with subtypes for text and tool use deltas — richer than OpenAI's simpler `choices[0].delta.content` format. The mattt/EventSource library provides spec-compliant SSE parsing with AsyncSequence support.

### Fallback and error handling complete the picture

Implement a **graceful degradation hierarchy**: primary cloud model → secondary cloud provider → local large model → local small model → cached/offline response. For rate limiting, both Anthropic and OpenAI return 429 with `Retry-After` headers — implement exponential backoff with jitter (base 0.5s, max 60s, cap at 7 retries). Show clear status to users: "Using local model (offline)" vs "Connected to Claude," and track token usage with cost estimates per provider using the `usage` object in every API response.

---

## Conclusion

Building Epistemos as a hybrid local-first + cloud AI application is architecturally tractable because the patterns have been battle-tested by Claude Code, Cursor, Continue.dev, and others. The most important decisions are:

**Use BYOK authentication exclusively** — subscription-based auth is explicitly prohibited by Anthropic's TOS, actively blocked technically, and economically unsustainable. The Anthropic Console API key (`sk-ant-api03-*`) stored in macOS Keychain is the only legitimate path.

**Adopt Claude Code's minimal loop philosophy** — a simple while-true loop with tool dispatch, depth-limited sub-agents, and just-in-time context retrieval outperforms complex orchestration. The model is the intelligence; the app is the harness.

**Leverage the MCP Swift SDK for extensibility** — the official `modelcontextprotocol/swift-sdk` is production-ready, and the MCP Connector in Anthropic's API eliminates client-side complexity for remote servers. Tool Search (deferring schema loading) is essential when many servers are connected.

**Use Anthropic's Models API for dynamic capability detection** — it returns structured capabilities per model, enabling Epistemos to adapt its UI and behavior based on what the selected model actually supports, rather than maintaining brittle static mappings.

**Design for the three-coordinate-space problem early** — computer use on macOS requires mapping between API coordinates (1024×768), macOS points, and native Retina pixels. Getting this wrong causes clicks to land in the wrong place, and it's the single most common implementation bug.

The broader landscape is converging rapidly: MCP is becoming universal (adopted by Anthropic, OpenAI, Google, Microsoft), tool use is table-stakes across all providers, and the economic boundary between subscriptions and API access is hardening. Building on official APIs with clean abstractions positions Epistemos for whatever comes next.