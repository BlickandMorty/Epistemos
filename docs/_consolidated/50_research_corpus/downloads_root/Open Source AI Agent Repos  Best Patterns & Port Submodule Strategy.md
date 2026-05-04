# Open Source AI Agent Repos: Best Patterns & Port/Submodule Strategy

## Executive Summary

Three repos were dissected at the source level: **rowboatlabs/rowboat** (TypeScript multi-agent pipeline platform), **Gitlawb/openclaude** (TypeScript fork of Claude Code CLI with an extended QueryEngine), and **multica-ai/multica** (Go-based agentic SaaS platform with TypeScript frontend). Together they represent three distinct architectural philosophies for building AI agent systems. The best patterns from each are directly applicable to a Swift-native app, and the correct porting strategy is *selective extraction + FFI bridge for performance-critical Rust pieces* rather than blanket submodule inclusion.

***

## Repo Architecture Overview

| Repo | Core Language | Agent Pattern | Key Innovation |
|------|--------------|---------------|----------------|
| rowboatlabs/rowboat | TypeScript (Next.js + OpenAI Agents SDK) | Multi-agent pipeline with structured handoffs | Typed agent handoffs, RAG tool factory, mock tool simulation |
| Gitlawb/openclaude | TypeScript (Bun) | Single stateful QueryEngine, async generator loop | Resumable sessions, budget/turn guards, snip compaction |
| multica-ai/multica | Go (server) + TypeScript (frontend) | Daemon poll loop, concurrent task execution | Provider-agnostic dispatch, GC lifecycle, cancellation polling |

***

## Best Patterns by Category

### 1. Typed Agent Handoffs (rowboat)

Rowboat's `agent-handoffs.ts` is the cleanest handoff pattern across all three repos. Every inter-agent transfer is a typed `Handoff` object created via `createAgentHandoff()` which enforces:

- **Sanitized tool names** — agent names are slugified with regex (`/[^a-zA-Z0-9_-]/g`) and capped at 50 chars to satisfy OpenAI's function-name rules
- **Input validation with safe fallback** — `schema.safeParse(input)` is tried first; on failure, `schema.parse({})` produces a valid default instead of crashing
- **Context-scoped history filtering** — `filterForPipeline` trims input history to the last 10 items; `filterForTask` allows 20, keeping token usage bounded
- **Pipeline state injection** — `createPipelineHandoff` injects a system message with current step/total/results into `data.newItems` before the receiving agent sees context

**Port verdict:** These are pure logic patterns. Extract as Swift `struct AgentHandoff` with a protocol-typed `onHandoff` closure. No Rust needed — the regex sanitization and Zod-equivalent validation maps directly to `Codable` + custom validators.

### 2. Tool Factory Pattern (rowboat)

Rowboat's `agent-tools.ts` defines five independent `invoke*` helpers that are composed into `Tool` objects:

- `invokeRagTool` — embedding lookup → Qdrant vector search → bulk doc fetch with paginated source listing
- `invokeMockTool` — LLM-simulated tool responses using `generateText` for prototyping without real backends
- `invokeWebhookTool` — JWT-signed webhook dispatch with SHA-256 body hashing and 5-minute expiry
- `invokeMcpTool` — dynamic MCP server resolution from project config, single call + close pattern
- `invokeComposioTool` — third-party integration via connected account resolution

The factory functions like `createRagTool` and `createMockTool` wrap these invokers into typed SDK `Tool` objects with Zod schemas. This separation of *invocation logic* from *tool declaration* is the key insight — it makes each tool independently testable.

**Port verdict:** In Swift, map each `invoke*` to an `async func` on a `ToolProvider` actor. The `createRagTool` factory becomes a static method returning a `Tool` struct. The JWT signing in `invokeWebhookTool` uses `CryptoKit`'s HMAC-SHA256 — no third-party dependency needed.

### 3. QueryEngine Stateful Agent Loop (openclaude)

Openclaude's `QueryEngine` class is the most sophisticated agent loop across all three repos. Key patterns:

- **AsyncGenerator turn loop** — `submitMessage` is an `AsyncGenerator<SDKMessage>`, yielding messages incrementally rather than buffering. This matches Swift's `AsyncThrowingStream`
- **Permission denial tracking** — a wrapped `canUseTool` closure intercepts every tool decision, accumulating `SDKPermissionDenial` records that are emitted on the final result
- **Multi-exit result system** — five distinct result subtypes: `success`, `error_max_turns`, `error_max_budget_usd`, `error_max_structured_output_retries`, `error_during_execution`. Each carries `stop_reason`, `num_turns`, `total_cost_usd`, and `modelUsage`
- **Budget gates** — USD budget is checked after every message; structured output retries are counted and capped via `MAX_STRUCTURED_OUTPUT_RETRIES`
- **Snip compaction** — injected via `snipReplay` callback so the feature-gated compaction module stays decoupled from the engine core
- **Memory persistence across turns** — `mutableMessages`, `readFileState`, `totalUsage`, `discoveredSkillNames`, and `loadedNestedMemoryPaths` all persist across multiple `submitMessage` calls within one engine instance

The `ask()` convenience wrapper creates a `QueryEngine`, delegates to `submitMessage`, then writes back the `readFileCache` — clean separation of engine lifecycle from session convenience.

**Port verdict:** This is the single highest-value pattern to port to Swift. Map `QueryEngine` to a Swift `actor QueryEngine` with an `AsyncThrowingStream<AgentMessage, Error>` return from `submitMessage`. The budget/turn checks become `guard` statements in the stream loop. Permission denial tracking maps to an `@Published var permissionDenials` array.

### 4. Daemon Poll Loop with Concurrent Task Execution (multica)

Multica's `pollLoop` in `daemon.go` is a production-grade work-stealing pattern:

- **Semaphore-based concurrency cap** — a buffered channel `sem` of size `MaxConcurrentTasks` gates task pickup; if full, the loop skips to sleep
- **Round-robin runtime selection** — `pollOffset` rotates through runtime IDs so no single runtime is always tried first
- **Claim → Start → Execute → Complete lifecycle** — tasks go through explicit API calls at each state transition; `FailTask` is the fallback for any error in the chain
- **Server-side cancellation polling** — a goroutine polls `GetTaskStatus` every 5 seconds during execution; on `cancelled`, it calls `runCancel()` and closes `cancelledByPoll`
- **Session resume with fallback** — if `PriorSessionID` is set and execution fails with an empty `SessionID`, the daemon retries with a fresh session and merges token usage from both attempts
- **Drain timeout** — `executeAndDrain` sets a `drainTimeout = opts.Timeout + 30s` so a stuck stdout pipe can't block indefinitely

**Port verdict:** This is an excellent candidate for Rust (not Swift). The concurrent polling loop, channel-based semaphore, and atomic counters (`activeTasks`, `toolCount`) map precisely to Tokio's `Semaphore` + `mpsc` channels. Write this as a Rust `daemon` crate and expose it to Swift via a C FFI layer using `cbindgen`.

### 5. Message Drain with Batched Reporting (multica)

Inside `executeAndDrain`, multica runs a background goroutine that buffers tool use/result/thinking/text messages into a `batch` slice, then flushes every 500ms or at end:

```go
ticker := time.NewTicker(500 * time.Millisecond)
// ... select on session.Messages and ticker.C
// flush() sends batch to server, resets
```

This batched 500ms flush pattern prevents HTTP request storms when the agent is making rapid tool calls, while still providing near-real-time streaming to the UI. The `callIDToTool` map resolves tool names for `tool_result` messages that arrive without the tool name (common in streaming APIs).

**Port verdict:** In Swift, use a `Timer.publish` combine pipeline or `Task.sleep` loop to debounce streaming messages. The `callIDToTool` lookup is directly expressible as a Swift `Dictionary<String, String>` on the actor.

### 6. Usage Tracking with Multi-Model Aggregation

All three repos track token usage, but in different ways:

- **Rowboat** uses a `UsageTracker` with typed events (`LLM_USAGE`, `EMBEDDING_MODEL_USAGE`, `COMPOSIO_TOOL_USAGE`) passed as a parameter through every invoke function
- **Openclaude** accumulates `NonNullableUsage` across streaming events (`message_start` resets current; `message_stop` adds to total), and `getModelUsage()` returns a per-model breakdown
- **Multica** uses a `map[string]agent.TokenUsage` keyed by model name with a `mergeUsage` function for session-resume merging

Multica's `mergeUsage` is particularly elegant — it handles the case where a retry adds tokens from two separate sessions by iterating both maps.

**Port verdict:** Adopt multica's model-keyed map approach. In Swift: `var usageByModel: [String: TokenUsage]` on the actor, with a `mergeUsage(_ other: [String: TokenUsage])` mutating function.

### 7. Provider-Agnostic Agent Dispatch (multica types.go)

Multica's `Task` type carries an `AgentData` struct with `Skills`, `Instructions`, `CustomEnv`, `CustomArgs`, and `McpConfig`. The `handleTask` function resolves the provider from `runtimeIndex` and dispatches to `agent.New(provider, config)`, which is a factory for different backend CLIs. This means adding a new agent provider (e.g., Gemini CLI, GPT-4o CLI) only requires registering a new `AgentEntry` in `cfg.Agents` — no code changes in the dispatch layer.

**Port verdict:** In Swift, model this as a `protocol AgentBackend` with `func execute(_ prompt: String, options: ExecOptions) async throws -> AsyncThrowingStream<AgentMessage, Error>`. Register backends in a `BackendRegistry: [String: any AgentBackend.Type]`. This gives you the same open/closed principle.

### 8. Coordinator Mode & Feature Flags (openclaude)

Openclaude uses `feature('COORDINATOR_MODE')` and `feature('HISTORY_SNIP')` for dead-code elimination at bundle time. The coordinator module is only `require()`d if the feature is enabled, keeping the base bundle lean. This is Bun-specific but the pattern translates:

- Feature-gated modules are injected via constructor parameters (e.g., `snipReplay` callback in `QueryEngine`)
- This avoids conditional imports leaking feature-gated strings into the core file (important for automated exclusion checks)

**Port verdict:** In Swift, use compile-time `#if` flags (`#if COORDINATOR_MODE`) or inject feature modules as optional protocol-typed dependencies in the `QueryEngine` init. The injection pattern is directly portable.

***

## What to Port to Rust vs. Swift vs. Submodule

| Component | Source Repo | Recommended Action |
|-----------|-------------|-------------------|
| QueryEngine (stateful agent loop) | openclaude | **Port to Swift** — maps to `actor` + `AsyncThrowingStream` |
| Agent handoff typed system | rowboat | **Port to Swift** — pure value types, no async primitives needed |
| Tool factory pattern | rowboat | **Port to Swift** — protocol-based `ToolProvider` actor |
| Daemon poll loop + semaphore concurrency | multica | **Port to Rust** — Tokio semaphore + channels are a near-exact translation |
| Message drain with batched flush | multica | **Port to Swift** (simple) or **Rust** (if perf-critical) |
| JWT-signed webhook tool | rowboat | **Port to Swift** — `CryptoKit` handles HMAC-SHA256 natively |
| RAG vector search tool | rowboat | **Submodule or replicate** — Qdrant client SDKs exist for both Rust and Swift |
| Usage tracking / model aggregation | multica | **Port to Swift** — trivial dictionary accumulation |
| Provider-agnostic dispatch | multica | **Port to Swift** — `protocol AgentBackend` pattern |
| Budget + turn guards | openclaude | **Port to Swift** — `guard` statements in stream loop |
| Snip compaction injection | openclaude | **Port to Swift** — optional closure parameter on `QueryEngine` |
| GC lifecycle for workdirs | multica | **Port to Rust** — filesystem ops + periodic goroutine = Tokio task |

### When to Use a Git Submodule Instead

Use a submodule only when:
1. You want **upstream fixes automatically** and the upstream is actively maintained
2. The component has **minimal language-boundary friction** (a pure REST API client, a data schema, or documentation)
3. Porting would require **re-implementing a large, stable algorithm** that changes rarely

None of the three repos are good candidates for direct submodule inclusion in a Swift/Rust project because:
- All three are TypeScript/Go — every usage from Swift requires an FFI bridge or a subprocess call, adding latency and complexity
- The patterns you want are *architectural*, not *library* — you need the idea, not the NPM package
- Submoduling TypeScript into a Swift app ships dead weight (node_modules, Bun runtime dependency)

The exception: **multica's Go server** could be compiled as a standalone binary and called via subprocess from Swift (similar to how openclaude calls agent CLIs). This is viable if you want the full workspace + repo cache + GC system running as a background daemon on macOS.

***

## Recommended Swift Implementation Plan

### Phase 1: Core Agent Loop
1. Define `AgentMessage` enum mirroring openclaude's SDK message types (assistant, user, progress, result subtypes)
2. Implement `actor QueryEngine` with `func submitMessage(_ prompt: String) -> AsyncThrowingStream<AgentMessage, Error>`
3. Add budget guard (`maxBudgetUSD`), turn guard (`maxTurns`), and permission denial accumulator
4. Inject `snipReplay: ((AgentMessage, [Message]) -> SnipResult?)?` as optional closure

### Phase 2: Tool System
1. Define `protocol ToolInvoker` with `func invoke(_ input: [String: Any]) async throws -> String`
2. Implement `RagToolInvoker`, `WebhookToolInvoker`, `McpToolInvoker` conforming to the protocol
3. Create `ToolFactory.makeRagTool(config:)` static builders returning `Tool` structs with schemas

### Phase 3: Multi-Agent Handoffs
1. Define `struct AgentHandoff` with `targetAgent`, `contextType` (pipeline/task/direct), `onHandoff` closure
2. Implement `sanitizeAgentName(_ name: String) -> String` for tool-name compliance
3. Add pipeline state injection via `HandoffInputFilter` closure composing new context messages

### Phase 4: Rust Daemon (Optional)
1. Create a Rust crate `multica-daemon-rs` with Tokio runtime
2. Implement `PollLoop` with `Semaphore::new(max_concurrent)` and round-robin runtime rotation
3. Expose via `cbindgen`-generated C header, call from Swift via `@_silgen_name`

***

## Licensing Notes

- **rowboatlabs/rowboat** — check repo license before porting; MIT or Apache-2 patterns are freely portable
- **Gitlawb/openclaude** — appears to be an MIT-licensed fork of Claude Code (Anthropic's CLI); review Anthropic's original license as it applies to the fork
- **multica-ai/multica** — has a LICENSE file; verify before porting the daemon pattern

Always attribute architectural inspiration in comments, even when license allows silent reuse — it helps future maintainers trace design decisions.