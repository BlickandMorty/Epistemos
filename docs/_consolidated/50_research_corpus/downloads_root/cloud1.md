# Epistemos v1: Cloud-Native Agent Bridge — Surgical Wins

## Executive Summary

Epistemos is shipping v1 with a cloud artifact pipeline that covers the fundamentals but has four critical gaps: (1) the Anthropic structured output implementation is outdated (using forced `tool_use` instead of the native `output_format` beta released November 2025); (2) `ChatMessage.content` is a flat `String` that prevents streaming tool calls, thinking blocks, and multi-part content; (3) prompt caching is entirely absent, leaving 41–80% cost savings on the table; and (4) artifacts have no versioning — every "update" creates a new artifact rather than patching the existing one. The agent infrastructure (Goose, Hermes, agent_core, omega-mcp) contains at least six patterns that can be extracted surgically for cloud chat without touching the agent loop.[^1][^2][^3]

***

## Part 1: Cloud Artifact Pipeline Audit

### 1.1 Structured Output — Current State vs Best Practices

**OpenAI** (`json_schema` response format with streaming) — the current implementation is correct in pattern. OpenAI's `json_schema` structured output works with `stream: true` and the `gpt-4o-2024-08-06` and later families, yielding `delta` chunks that can be partially parsed. The one gap: streaming JSON deltas arrive as raw string fragments, not parsed partial objects, so the artifact card cannot update live without a dedicated partial-JSON parser on the Swift side.[^1]

**Anthropic** — this is where the current implementation is *stale*. The codebase uses forced `tool_use` to coerce structured output. Anthropic shipped a native **Structured Outputs beta** on November 14, 2025, supporting two distinct modes:[^4][^1]

- **JSON mode**: `output_format: { type: "json", schema: <JSONSchema> }` — model returns a bare JSON string guaranteed to match the schema
- **Strict tool use**: `strict: true` flag on individual tool definitions — input parameters are guaranteed to match the tool's `input_schema`

Both require the `anthropic-beta: structured-outputs-2025-11-13` header. The critical implication: forced `tool_use` is **incompatible with extended thinking** (`thinking: { type: "enabled" }`). By migrating to native structured outputs, the extended thinking path is unlocked without a workaround.[^5][^1]

**Google Gemini** — function calling via `FunctionDeclaration` + `Tool` pattern, with a `responseMimeType: "application/json"` fallback for raw JSON. No changes needed for v1.

### 1.2 Graph Context Injection

The `<knowledge_graph>` XML section in the system prompt is directionally correct — Anthropic's documentation explicitly recommends XML tags as the preferred context injection format for Claude. However, there are two gaps:[^5]

- The static graph context is placed *after* dynamic instructions in the system prompt, making it impossible to cache (cache boundaries must be at prefix positions)
- No provider-specific formatting: OpenAI models handle JSON inline better than XML; Gemini prefers Markdown-structured context

### 1.3 Artifact Lifecycle — What Native Competitors Do

Claude.ai's artifact system (updated late 2025) exposes three explicit operation modes: `create`, `update` (targeted string replacement of a specific range in the existing artifact — approximately 3–4× faster), and `rewrite` (full regeneration). Open WebUI (an open-source Claude.ai-inspired UI) implements a version selector in the artifact footer; each model edit creates a new version entry rather than overwriting the current one.[^2]

The current `ArtifactBlockView` creates a new artifact on every response that contains extractable content. This means a user saying "add a `timestamp` field to that JSON" gets *two* unlinked artifact cards rather than the existing card updating in place. This is the single highest-visibility UX gap relative to Claude.ai.

### 1.4 Streaming Structured JSON

OpenAI's streaming structured output emits `response.output_item.delta` events containing raw JSON token fragments. Reconstructing a valid partial object in real time requires either a SAX-style incremental JSON parser (e.g., `IkigaJSON`'s `StreamingJSONArrayDecoder` pattern) or a simpler "buffer until delimiter" approach for known schema shapes. Without this, the artifact card can only render once the full response completes, creating a blank card during generation for long structured outputs.[^6][^1]

***

## Part 2: Extraction Matrix from Agent Infrastructure

### 2.1 Goose — Provider Trait Pattern

**What it is**: Goose's `Provider` trait is the single abstraction for all LLM interactions across 30+ providers.

**How it implements it** (from `crates/goose/src/providers/base.rs`):

```rust
#[async_trait]
pub trait Provider: Send + Sync {
    fn get_name(&self) -> &str;
    async fn stream(
        &self, model_config: &ModelConfig, session_id: &str,
        system: &str, messages: &[Message], tools: &[Tool],
    ) -> Result<MessageStream, ProviderError>;
    fn get_model_config(&self) -> ModelConfig;
    async fn supports_cache_control(&self) -> bool { false }
    fn manages_own_context(&self) -> bool { false }
}

pub type MessageStream = Pin<
    Box<dyn Stream<Item = Result<(Option<Message>, Option<ProviderUsage>), ProviderError>> + Send>
>;
```

**Can it work without the agent loop?** Yes — `stream()` and `complete()` are pure functions over `[Message]`. The agent loop is a separate `agent.rs` that calls these methods in a loop.

**Key insight to extract**: The `MessageStream` yields a **tuple** of `(Option<Message>, Option<ProviderUsage>)` per chunk. This means token usage is tracked mid-stream, not just at the end. `ProviderUsage` includes `cache_read_input_tokens` and `cache_write_input_tokens` — enabling real-time cost display. Our `AsyncThrowingStream<String, Error>` loses three things: usage tracking, tool-call vs. text distinction, and content block type information.

**Minimal extraction**: Add a `CloudStreamChunk` enum to the Swift layer:

```swift
enum CloudStreamChunk {
    case textDelta(String)
    case toolCallDelta(id: String, name: String, argumentsDelta: String)
    case thinking(String)          // Anthropic only
    case usage(inputTokens: Int, outputTokens: Int, cachedTokens: Int)
    case done
}
```

Change `AsyncThrowingStream<String, Error>` to `AsyncThrowingStream<CloudStreamChunk, Error>`. No agent loop needed.

**Native vs. agent-y?** Native — usage tracking and content block differentiation are core chat features, not agent features.

**Goose also has**: `complete_fast()` — tries a "fast" model first, falls back to the primary model on failure. This is extractable as a "quick follow-up" mode where Haiku/gpt-4o-mini handles simple requests automatically.

### 2.2 Goose — `supports_cache_control` Method

**What it is**: Each provider declares whether it supports prompt caching via a method on the `Provider` trait. When `true`, the provider wraps the system prompt content blocks with `cache_control` markers before sending.

**Can it work without the agent loop?** Yes — it is called before constructing the API request.

**Minimal extraction**: In the Swift `CloudConfigurableLLMClient`, add:

```swift
var supportsCacheControl: Bool { false } // override per provider
func buildSystemPrompt(base: String, graphContext: String) -> SystemPrompt {
    // Place static content (graph context) FIRST for caching
    // Add cache_control only if supportsCacheControl
}
```

**Impact**: Anthropic: 90% cost reduction on cached tokens ($0.30/M vs $3.00/M for cached vs uncached input), 85% latency reduction. OpenAI: automatic 50% reduction — no code changes, but keeping the system prompt prefix identical across turns is required. Google: explicit API flag, 75% discount. Studies show prompt caching reduces total API costs by 41–80% and TTFT by 13–31% for conversation-heavy workloads. The system prompt + knowledge graph section is the perfect caching target because it is static per conversation.[^3]

**Native vs. agent-y?** Deeply native — this is transparent infrastructure that makes every chat cheaper and faster.

### 2.3 Goose — Context Compaction Strategy

**What it is**: Goose compacts conversation history when it approaches the provider's context window limit.[^7]

**How it implements it** (from GitHub issue #3485): Goose's `/summarize` flow triggered automatically when token count approaches the limit. The strategy:[^7]
1. Retain the most recent N turns verbatim (recency bias)
2. Summarize the remainder into a single assistant "summary" message that replaces the older turns
3. Preserve `<knowledge_graph>` context — it is injected fresh each time, not summarized away
4. Signal the user via a subtle toast ("context was compacted") without interrupting flow

A known antipattern from Goose's own issues: tool-pair summarization that is too aggressive on large-context models causes the agent to respond to stale summaries. The fix: only compact when within 15% of the context limit, not at a fixed turn count.[^8]

**Can it work without the agent loop?** Yes — it operates on `[ChatMessage]` before sending to the API.

**Minimal extraction for cloud chat** (Swift pseudo-code):

```swift
func compactIfNeeded(_ history: [ChatMessage], limit: Int) -> [ChatMessage] {
    let tokenEstimate = estimateTokens(history)
    guard tokenEstimate > Int(Double(limit) * 0.85) else { return history }
    let recent = Array(history.suffix(8))          // keep last 4 turns verbatim
    let older = Array(history.dropLast(8))
    let summary = await summarizeViaModel(older)   // one API call to Haiku/gpt-4o-mini
    return [ChatMessage(role: .assistant, content: "[Previous context: \(summary)]")] + recent
}
```

**Native vs. agent-y?** Native — this is invisible infrastructure users never see. The compaction happens before the API call and leaves no trace in the UI.

### 2.4 Hermes Skills → Cloud System Prompts

**What it is**: Hermes has a `skills/` directory of reusable prompt templates for specific task types (summarization, analysis, research, writing, etc.).

**Can it work without the agent loop?** Yes — skills are pure text templates.

**Minimal extraction**: Create a `CloudSkill` enum mapping task types to system prompt overlays. On conversation create, auto-detect or allow the user to select a skill:

```swift
enum CloudSkill: String {
    case general, research, coding, writing, analysis, brainstorm
    var systemPromptSuffix: String { /* extracted from Hermes skills/ */ }
}
```

This makes Epistemos feel like it has "modes" without needing agents. The graph context is the base; the skill suffix is appended. **Native vs. agent-y?** Native — system prompt selection is a standard chat feature (Claude.ai Project Instructions, ChatGPT Custom Instructions).

### 2.5 agent_core — Prompt Caching Layer

The `prompt_caching.rs` module in `agent_core` manages `cache_control` marker placement in the Anthropic message format. The key insight is that `cache_control: { type: "ephemeral" }` must be placed on the *last* content block of the **system prompt** array (not the user message), and the boundary must fall *after* all static content.[^9]

**Minimal extraction**:

```swift
// For Anthropic requests
func buildAnthropicSystem(base: String, graphContext: String) -> [[String: Any]] {
    return [
        ["type": "text", "text": graphContext],                          // static, cacheable
        ["type": "text", "text": base,
         "cache_control": ["type": "ephemeral"]]                        // cache boundary here
    ]
}
```

For OpenAI, no markers are needed — caching is automatic, but the system message must be identical across turns. Separating graph context from conversational instructions (which may vary) into two separate system messages enables OpenAI to cache only the stable prefix.

### 2.6 omega-mcp — Vault Operations as Cloud Tool Use

**What it is**: The omega-mcp catalog defines MCP tool definitions for vault read/write operations (note creation, graph linking, search).

**Can it work without the agent loop?** Yes — cloud function-calling (`tool_use` in Anthropic, `tools` in OpenAI) requires only a tool definition JSON and a result handler. No MCP protocol or subprocess needed.

**Minimal vault tool definitions to extract**:

```swift
let vaultTools: [CloudTool] = [
    .init(name: "search_notes",
          description: "Search the user's knowledge vault by keyword or semantic query",
          inputSchema: { "query": string, "limit": integer }),
    .init(name: "create_note",
          description: "Create a new note in the vault with title and content",
          inputSchema: { "title": string, "content": string, "tags": [string] }),
    .init(name: "link_nodes",
          description: "Create a bidirectional link between two existing notes",
          inputSchema: { "sourceTitle": string, "targetTitle": string })
]
```

When the model calls `search_notes`, the client executes a local vault query and returns results as a tool response. No MCP runtime, no subprocess. **Native vs. agent-y?** Native — this is equivalent to ChatGPT's memory tool, which feels completely native to users.

### 2.7 agent_core Security Patterns for Tool Use

The `agent_core` security module validates tool call results before returning them to the model — specifically guarding against prompt injection in tool responses (a tool returns a string that contains `</tool_result>` or attempts to hijack the conversation). For vault `search_notes`, sanitize returned note content by stripping any model-instruction-like patterns before inserting into the tool response. This is a one-function addition to the tool result handler.

***

## Part 3: "Just Works" Cloud Chat Upgrade Plan

Ordered by impact-to-effort ratio, with the constraint that nothing touches the agent loop or ShipGate.

### Priority 1 — Prompt Caching (1–2 days, 41–80% cost reduction)

**Files to modify**: `CloudConfigurableLLMClient.swift`, `ChatViewModel.swift` (or equivalent conversation builder)

**Changes**:
1. Move `<knowledge_graph>` section to be the *first* content block in the system prompt (before task instructions)
2. For Anthropic: add `anthropic-beta: prompt-caching-2024-07-31` header; wrap the graph context block with `cache_control: { type: "ephemeral" }`
3. For OpenAI: split the system message into two (`SystemMessage` array): first element = graph context (never changes), second = task instructions (may vary). OpenAI caches the first 1,024+ tokens automatically

**Expected outcome**: First turn of each conversation writes the cache; all subsequent turns read it. On a typical 10-turn conversation with a 4,000-token graph context, this reduces cost by ~60% and latency by ~0.5 seconds per turn.

### Priority 2 — Upgrade ChatMessage to Content Blocks (2–3 days)

**Files to modify**: `ChatMessage.swift` (or equivalent message model), all call sites

**Change**: Replace `content: String` with `content: [MessageContentBlock]` where:

```swift
enum MessageContentBlock {
    case text(String)
    case toolUse(id: String, name: String, input: [String: Any])
    case toolResult(toolUseId: String, content: String)
    case thinking(String)    // Anthropic extended thinking
    case image(Data, mimeType: String)
}
```

This is non-negotiable for priorities 3–8 to work. A flat string cannot represent tool call inputs, thinking blocks, or multi-part responses. The SwiftData `SDMessage` model needs a corresponding schema migration.

### Priority 3 — Migrate Anthropic to Native Structured Outputs (1 day)

**Files to modify**: `CloudConfigurableLLMClient.swift` (Anthropic branch of `generateStructured<T>`)

**Change**: Replace forced `tool_use` with `output_format: { type: "json", schema: T.jsonSchema }` and the `anthropic-beta: structured-outputs-2025-11-13` header. Remove the `tool_use` parsing logic for structured generation. This also unlocks extended thinking for non-structured-output requests (since forced `tool_use` currently blocks it).[^1]

### Priority 4 — Multi-Turn Artifact Versioning (2–3 days)

**Files to modify**: `ArtifactExtractor.swift`, `SDMessage.swift`, `ArtifactBlockView.swift`, `ChatViewModel.swift`

**Changes**:
1. Add `artifactId: UUID` to `Artifact` — stable identifier across message turns
2. Add `parentArtifactId: UUID?` to `Artifact` — links a refined artifact to its predecessor
3. In `ChatViewModel`, detect when a user message contains update-intent language ("update the JSON", "add a field", "change X to Y") and inject the current artifact's content into the context as `urrent_artifact>` rather than re-rendering from scratch
4. In `ArtifactBlockView`, add a version badge and tap-to-navigate-history control in the footer

**Behavior**: The model sees the existing artifact content in context; its response overwrites the artifact card in place while adding the previous version to a history stack accessible via the footer control.

### Priority 5 — Vault Tool Use via Cloud Function Calling (3–4 days)

**Files to modify**: `CloudConfigurableLLMClient.swift`, new `VaultToolHandler.swift`

**Add**:
- `search_notes`, `create_note`, `link_nodes` as tool definitions passed in all chat requests
- A `VaultToolHandler` that intercepts `tool_use` content blocks for these tool names, executes them against the local graph, and returns a `tool_result` message back to the model
- The model then continues its response with the search results or confirms the creation

This makes Epistemos feel like "Claude.ai with actual memory" — the model can search and create notes mid-conversation.

### Priority 6 — Context Compaction for Long Conversations (2 days)

**Files to modify**: `CloudConfigurableLLMClient.swift` or `ChatViewModel.swift`

**Add**: A `compactHistoryIfNeeded()` function called before each API request. Trigger at 85% of the provider's context limit. Use the cheapest available model for the summary call (Haiku, gpt-4o-mini, Flash). Show a subtle "context was summarized" indicator in the conversation timeline.

### Priority 7 — Anthropic Extended Thinking as Visible Reasoning Trail (2 days)

**Files to modify**: `CloudConfigurableLLMClient.swift` (stream handler), `ChatBubbleView.swift` or equivalent

**Add**: When provider is Anthropic and the user asks a complex question (heuristic: message length > 200 chars, or user explicitly requests "think carefully"), enable `thinking: { type: "enabled", budgetTokens: 8000 }`. Stream `thinking_delta` events into a collapsible "Reasoning" disclosure group above the answer bubble. This is directly analogous to Claude.ai's thinking feature and makes the Anthropic integration feel premium.[^3]

### Priority 8 — OpenAI Web Search + Citation-to-Graph (2–3 days)

**Files to modify**: `CloudConfigurableLLMClient.swift` (OpenAI branch), new `CitationGraphHandler.swift`

**Add**: Pass `web_search: {}` as a tool when the conversation is in a "research" skill mode. Parse `url_citation` annotations from the response. Offer a one-tap "Add to graph" action on each citation in the rendered message, calling `create_note` with the citation URL, title, and a summary.[^10]

### Priority 9 — Streaming JSON for Live Artifact Card Updates (3–4 days, lower priority)

**Files to modify**: `CloudConfigurableLLMClient.swift` (structured output streaming), `ArtifactBlockView.swift`

**Add**: A `PartialJSONParser` that accumulates `text_delta` chunks and attempts to decode into the target schema at each checkpoint (e.g., after each complete key-value pair). Emit partial `StructuredGenerationResult` events. `ArtifactBlockView` observes these via a `@Published` partial-result property and renders field-by-field as they arrive.

### Priority 10 — Preference Learning / Auto-Routing (1 week, post-v1)

**Add**: A lightweight `ProviderPreferencesStore` (SwiftData or UserDefaults) that records `(taskType, providerChoice, thumbsUp/Down)` triples. Surface as "Suggested: Claude for analysis" in the provider picker. This is a pure UX layer with no API changes. Academic work on LLM routing using contextual multi-armed bandit approaches shows cost reductions over 2× without quality loss — but a simple frequency-based tracker is sufficient for v1.[^11][^12]

***

## Part 4: Agent UI Hide List

All items below reference the current agent infrastructure that must be hidden before App Store submission to avoid confusing users with unfinished features.

| View / Entry | Location | Disposition | Rationale |
|---|---|---|---|
| Hermes agent settings panel | Settings → AI | Gate behind `ShipGate.agentsEnabled` | Complete implementation exists, just not ready |
| Omega/MCP server configuration | Settings → Integrations | Gate behind `ShipGate.agentsEnabled` | Will be repurposed for cloud tool use in v1.1 |
| Agent task queue view | Main navigation sidebar | Remove entirely | Dead code in v1; confuses PKM-first positioning |
| "Run as Agent" toolbar button | Chat toolbar | Gate behind `ShipGate.agentsEnabled` | Repurpose button as "Use Skills" for cloud |
| Goose integration toggle | Settings → Advanced | Remove entirely | Not applicable to Swift app distribution |
| MCP tool execution log | Debug panel | Gate behind `ShipGate.agentsEnabled` | Useful for development, noisy for users |
| Agent status indicator | Window chrome / titlebar | Remove entirely | No agents in v1 |
| "Teach Hermes" feedback flow | Context menu on messages | **Repurpose**: become thumbs-up/down for preference learning | The UX pattern is correct, rewire backend |
| Agent capability badge on models | Model picker | Remove entirely | Misleading when agents are gated |
| MCP skill browser | Skills sheet | Gate behind `ShipGate.agentsEnabled` | Cloud skills (Priority 4) will replace this |
| Hermes memory view | Settings → Memory | Gate behind `ShipGate.agentsEnabled` | Lightweight preference tracking (Priority 10) replaces this for v1 |

The **feature flag pattern** recommended for all `ShipGate` checks in Swift is a typed `FeatureFlags` struct injected into the SwiftUI environment, with per-distribution default values:[^13][^14]

```swift
struct ShipGate {
    let agentsEnabled: Bool
    static let release = ShipGate(agentsEnabled: false)
    static let debug = ShipGate(agentsEnabled: true)
}
// Inject: .environment(\.shipGate, .release) in production scene
```

This approach has zero runtime overhead for release builds and requires no remote config service.[^13]

***

## Part 5: Goose Provider Trait vs. CloudConfigurableLLMClient

| Dimension | Goose `Provider` (Rust) | Epistemos `CloudConfigurableLLMClient` (Swift) |
|---|---|---|
| **Stream return type** | `MessageStream` = `Pin<Box<dyn Stream<Item=Result<(Option<Message>, Option<ProviderUsage>), ProviderError>> + Send>>` | `AsyncThrowingStream<String, Error>` |
| **Usage tracking** | Per-chunk, with `cache_read_input_tokens` | Post-response only (if at all) |
| **Content block model** | `Vec<MessageContent>` (text, tool_use, tool_result, thinking, image) | `content: String` (flat) |
| **Cache control** | `async fn supports_cache_control() -> bool` per provider; markers in message construction | Not implemented |
| **Fallback model** | `complete_fast()` tries fast model first, falls back | Not implemented |
| **Context awareness** | `manages_own_context()` flag; `context_limit` in `ModelInfo` | Not tracked |
| **Retry logic** | `retry_config()` with exponential backoff in `retry.rs` | Unknown |
| **Provider metadata** | `ProviderMetadata` with `known_models`, `context_limit`, `input_token_cost` per model | Likely enum-based |
| **Model aliasing** | `get_current_model()` returns actual model used, not alias | Not tracked |
| **Tool definitions** | `&[Tool]` passed per call, decoupled from provider | Structured output only |

**Verdict**: Goose's trait is more complete but is designed for a Rust async runtime. The patterns to adopt in Swift are: (1) typed stream chunk with usage tuple, (2) `supports_cache_control` as a per-provider computed property, (3) `complete_fast` pattern for follow-up summarization, and (4) `ModelInfo` with `context_limit` for compaction triggering. The Swift async/await model makes adopting Goose's `Pin<Box<dyn Stream>>` pattern straightforward via `AsyncThrowingStream<CloudStreamChunk, Error>`.

***

## Summary of Wins by Category

| Category | Source | Impact | Effort | Priority |
|---|---|---|---|---|
| Prompt caching | agent_core / Goose | 41–80% cost reduction, 85% latency reduction | Low | 1 |
| Content blocks upgrade | Goose Message type | Unlocks all downstream features | Medium | 2 |
| Anthropic native structured output | Anthropic API beta | Unblocks extended thinking, cleaner code | Low | 3 |
| Artifact versioning | Claude.ai pattern | Highest-visibility UX gap vs. Claude.ai | Medium | 4 |
| Vault tool use | omega-mcp catalog | "AI that knows your notes" | Medium-High | 5 |
| Context compaction | Goose / agent_core | Prevents conversation death at 128K | Low-Medium | 6 |
| Extended thinking trail | Anthropic API | Premium Anthropic feel | Low | 7 |
| Web search + citation graph | OpenAI API | Premium OpenAI feel | Medium | 8 |
| Streaming JSON live update | OpenAI streaming | Polish | High | 9 |
| Preference routing | Research literature | Personalization | High (defer) | 10 |

---

## References

1. [Claude Structured Outputs: Guaranteed JSON Schema Compliance](https://techbytes.app/posts/claude-structured-outputs-json-schema-api/) - Use JSON outputs for direct structured responses, or strict tool use for precise function calling wi...

2. [Artifacts - Open WebUI](https://docs.openwebui.com/features/chat-conversations/chat-features/code-execution/artifacts/) - Editing and iterating: Ask an LLM within the chat to edit or iterate on the content, and these updat...

3. [jamesrochabrun/SwiftAnthropic: An open-source Swift ... - GitHub](https://github.com/jamesrochabrun/SwiftAnthropic) - Extended Thinking. Claude 3.7 Sonnet offers enhanced reasoning capabilities with extended thinking m...

4. [Anthropic boosts Claude API with Structured Outputs - Tessl](https://tessl.io/blog/anthropic-brings-structured-outputs-to-claude-developer-platform-making-api-responses-more-reliable/) - Anthropic's Structured Outputs let you enforce strict JSON schemas ... “Can anyone explain how this ...

5. [Introducing advanced tool use on the Claude Developer Platform](https://www.anthropic.com/engineering/advanced-tool-use) - JSON Schema excels at defining structure–types ... These three features work together to solve diffe...

6. [orlandos-nl/IkigaJSON: A high performance JSON library in Swift](https://github.com/orlandos-nl/IkigaJSON) - IkigaJSON is a really fast JSON parser. IkigaJSON is competitive to the modern Foundation JSON in be...

7. [Improve Goose's Context Window Management · Issue #3485 - GitHub](https://github.com/block/goose/issues/3485) - Solution: Improve the existing /summarization flow + add some benchmarking. Have the flow trigger mo...

8. [Tool-pair summarization is too aggressive for large context models](https://github.com/block/goose/issues/7415) - Agent repeatedly responded to stale summaries instead of the user's actual message; Users had to say...

9. [Structured outputs - Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs) - JSON Schema limitations. Structured outputs support standard JSON Schema with some limitations. Both...

10. [Agentic Design Pattern #1: Tool Calling - DAGWorks's Substack](https://blog.dagworks.io/p/agentic-design-pattern-1-tool-calling) - In this post we'll be talking about how to use “tool-calling” to build an agent that responds to a q...

11. [ICLR Poster RouteLLM: Learning to Route LLMs from Preference Data](https://iclr.cc/virtual/2025/poster/30737) - To address this trade-off, we introduce a training framework for learning efficient router models th...

12. [[PDF] SELECT-THEN-ROUTE: Taxonomy guided Routing for LLMs](https://aclanthology.org/anthology-files/pdf/emnlp/2025.emnlp-industry.28.pdf) - 2025. RouteLLM: Learning · to route LLMs from preference data. In The Thir- teenth International Con...

13. [Feature flags in Swift - Swift with Majid](https://swiftwithmajid.com/2025/09/16/feature-flags-in-swift/) - Then we can use compilation conditions in code to understand which scheme is active now. ... You can...

14. [iOS feature flags: Swift patterns - Statsig](https://www.statsig.com/perspectives/ios-feature-flags-swift-patterns) - Unlock the power of feature flags in iOS development. Learn to implement them in Swift for seamless ...

