# Open Source AI Agent Repos: Best Patterns & Port/Submodule Strategy

## Executive Summary

Three repositories were dissected at the source level: **[rowboatlabs/rowboat](https://github.com/rowboatlabs/rowboat)** (TypeScript multi-agent pipeline platform), **[Gitlawb/openclaude](https://github.com/Gitlawb/openclaude)** (TypeScript open-source coding-agent CLI for OpenAI, Gemini, DeepSeek, Ollama, Codex, and 200+ models via OpenAI-compatible APIs), and **[multica-ai/multica](https://github.com/multica-ai/multica)** (Go-based agentic SaaS platform with TypeScript frontend). Together they represent three distinct architectural philosophies for building AI agent systems.

The recommendation is **selective extraction and direct Swift porting** for almost everything — not blanket submodule inclusion. None of the three repos are good submodule candidates for a Swift/Rust project because all three use languages (TypeScript/Go) that create significant FFI friction. The patterns you want are *architectural*, not *library*: you need the idea, not the npm package. The one exception is multica's Go daemon, which could be compiled as a standalone binary and invoked via subprocess from Swift.

***

## Repo Architecture at a Glance

| Repo | Core Lang | Agent Pattern | Key Innovation |
|------|-----------|---------------|---------------|
| rowboatlabs/rowboat | TypeScript (Next.js + OpenAI Agents SDK) | Multi-agent pipeline with structured handoffs | Typed handoff system, RAG tool factory, mock tool simulation |
| Gitlawb/openclaude | TypeScript (Bun) | Single stateful `QueryEngine`, async generator loop | Resumable sessions, budget/turn guards, snip compaction injection |
| multica-ai/multica | Go (server) + TypeScript (frontend) | Daemon poll loop, concurrent task execution | Provider-agnostic `Backend` interface, GC lifecycle, cancellation polling |

***

## Pattern 1: Typed Agent Handoffs (rowboat)

Rowboat's [`agent-handoffs.ts`](https://github.com/rowboatlabs/rowboat/blob/main/apps/rowboat/src/application/lib/agents-runtime/agent-handoffs.ts) is the cleanest handoff system across all three repos. Every inter-agent transfer is a typed `Handoff` object created via `createAgentHandoff()`, which enforces three hard constraints:

- **Sanitized tool names** — agent names are slugified with regex `(/[^a-zA-Z0-9_-]/g)` and capped at 50 characters to satisfy OpenAI's function-name rules
- **Input validation with safe fallback** — `schema.safeParse(input)` is tried first; on failure, `schema.parse({})` produces a valid default instead of crashing
- **Context-scoped history filtering** — `filterForPipeline` trims input history to the last 10 items; `filterForTask` allows 20, keeping token usage bounded

The `createPipelineHandoff` function injects a system message carrying `currentStep`, `totalSteps`, and `stepResults` into `data.newItems` before the receiving agent sees any context. This lets every downstream agent in a pipeline know exactly where it sits without any global state.

Three handoff context types are supported — `pipeline`, `task`, and `direct` — each with a corresponding Zod schema (`PipelineContext`, `TaskContext`, `HandoffContext`) and a default `inputFilter`. The separation of *context type* from *input schema* from *filter logic* keeps each piece independently testable.

**Swift port verdict:** These are pure value type patterns. Model as `struct AgentHandoff` with a `HandoffContextType` enum and a `@escaping (AgentMessage, [Message]) -> HandoffInputData` filter closure. The regex sanitization maps directly to Swift's `String.replacingOccurrences` + a character set allowlist. No Rust needed.

***

## Pattern 2: Tool Factory with Invoke/Create Separation (rowboat)

Rowboat's [`agent-tools.ts`](https://github.com/rowboatlabs/rowboat/blob/main/apps/rowboat/src/application/lib/agents-runtime/agent-tools.ts) defines five independent `invoke*` helpers that are each composed into SDK `Tool` objects by a corresponding `create*` factory. The separation of *invocation logic* from *tool declaration* is the key insight — it makes each tool independently testable and mockable.

The full set of tool invokers:

- `invokeRagTool` — embedding lookup → Qdrant vector search → bulk doc fetch with paginated source listing; supports `chunks` vs `content` return modes
- `invokeMockTool` — LLM-simulated tool responses using `generateText` for prototyping without real backends; ships a system prompt that explains the mock context
- `invokeWebhookTool` — JWT-signed webhook dispatch using `SignJWT` from `jose`, with SHA-256 body hashing and a 5-minute expiry window
- `invokeMcpTool` — dynamic MCP server resolution from project config, single `callTool` + `close` pattern
- `invokeComposioTool` — third-party integration via connected account resolution
- `invokeGenerateImageTool` — Gemini image generation with S3 upload fallback; images stored at `generated_images/<a>/<b>/<uuid>.png` with UUID-based sharding

The `createTools` dispatch function in `agent-tools.ts` centralizes all tool construction behind a single map, using boolean flags (`mockTool`, `isMcp`, `isComposio`, `isGeminiImage`, `isWebhook`) as discriminators. This avoids scattered `instanceof` checks elsewhere in the codebase.

**Swift port verdict:** Map each `invoke*` to an `async func` on a `ToolProvider` actor. The `create*` factories become static methods on a `ToolFactory` struct returning `Tool` value types. JWT signing in `invokeWebhookTool` uses `CryptoKit`'s HMAC-SHA256 — no third-party dependency. The S3 upload pattern maps to Swift's `URLSession` + AWS SDK for Swift.

***

## Pattern 3: QueryEngine — The Stateful Agent Loop (openclaude)

Openclaude's [`QueryEngine.ts`](https://github.com/Gitlawb/openclaude/blob/main/src/QueryEngine.ts) is the most sophisticated agent loop across all three repos. It owns the full query lifecycle and session state for a conversation. One `QueryEngine` per conversation; each `submitMessage()` call starts a new turn within the same stateful instance.

### State Persistence Across Turns

The following state persists across all `submitMessage()` calls:

- `mutableMessages` — full conversation history
- `readFileState` — file cache keyed by path
- `totalUsage` — accumulated `NonNullableUsage` across all turns
- `permissionDenials` — array of `SDKPermissionDenial` records
- `discoveredSkillNames` — cleared at start of each turn to prevent unbounded growth
- `loadedNestedMemoryPaths` — persists across turns for memory deduplication

### AsyncGenerator Turn Loop

`submitMessage` is an `AsyncGenerator<SDKMessage, void, unknown>`, yielding messages incrementally rather than buffering. This matches Swift's `AsyncThrowingStream` precisely.

### Permission Denial Tracking

A wrapped `canUseTool` closure intercepts every tool decision, accumulating `SDKPermissionDenial` records that are included in the final result message. This gives callers a complete audit trail of what the agent tried to do but couldn't.

### Multi-Exit Result System

Five distinct result subtypes exist:

| Subtype | Trigger |
|---------|---------|
| `success` | Normal completion |
| `error_max_turns` | Turn count reached `maxTurns` |
| `error_max_budget_usd` | `getTotalCost() >= maxBudgetUsd` |
| `error_max_structured_output_retries` | Structured output tool called ≥ `MAX_STRUCTURED_OUTPUT_RETRIES` times |
| `error_during_execution` | `isResultSuccessful()` returns false on the final message |

Each carries `stop_reason`, `num_turns`, `total_cost_usd`, `usage`, and `modelUsage`.

### Snip Compaction Injection

The `snipReplay` callback is injected via the `QueryEngineConfig` rather than imported directly. This keeps feature-gated strings out of the core engine file, which matters for automated excluded-strings checks. The `ask()` convenience wrapper wires `snipReplay` when the `HISTORY_SNIP` feature flag is enabled, then clears pre-compaction messages from `mutableMessages` to bound memory in long sessions.

**Swift port verdict:** This is the single highest-value pattern to port. Map `QueryEngine` to a Swift `actor QueryEngine` with `func submitMessage(_ prompt: String) -> AsyncThrowingStream<AgentMessage, Error>`. Budget/turn checks become `guard` statements in the stream loop. Permission denial tracking maps to a `private(set) var permissionDenials: [PermissionDenial]` on the actor. Snip compaction injection becomes an `Optional<(AgentMessage, [Message]) -> SnipResult?>` parameter on `init`.

***

## Pattern 4: Provider-Agnostic `Backend` Interface (multica)

Multica's [`agent.go`](https://github.com/multica-ai/multica/blob/main/server/pkg/agent/agent.go) defines the cleanest provider-agnostic dispatch seen in any of the three repos. The `Backend` interface has exactly one method:

```go
Execute(ctx context.Context, prompt string, opts ExecOptions) (*Session, error)
```

The `New(agentType string, cfg Config)` factory maps string names to concrete backends — `claude`, `codex`, `copilot`, `opencode`, `openclaw`, `hermes`, `gemini`, `pi`, `cursor`. Adding a new provider requires only registering a new case in the switch — no changes to any dispatch logic.

`Session` streams two channels:
- `Messages <-chan Message` — events as the agent works (text, thinking, tool-use, tool-result, status, error, log)
- `Result <-chan Result` — exactly one final value, then closes

The `ExecOptions` struct carries `Cwd`, `Model`, `SystemPrompt`, `MaxTurns`, `Timeout`, `ResumeSessionID`, `CustomArgs`, and `McpConfig`. The `Task` type in `types.go` maps one-to-one to `AgentData` which carries `Skills`, `Instructions`, `CustomEnv`, `CustomArgs`, and `McpConfig` for full per-task agent customization.

**Swift port verdict:** Model as `protocol AgentBackend { func execute(_ prompt: String, options: ExecOptions) async throws -> AsyncThrowingStream<AgentMessage, Error> }`. Register backends in a `BackendRegistry: [String: any AgentBackend.Type]`. This gives the same open/closed principle as multica's switch statement.

***

## Pattern 5: Daemon Poll Loop with Semaphore Concurrency (multica)

Multica's `pollLoop` in [`daemon.go`](https://github.com/multica-ai/multica/blob/main/server/internal/daemon/daemon.go) is a production-grade work-stealing pattern. The full daemon lifecycle is orchestrated in `Run()`, which launches four goroutines before entering `pollLoop`:

```
go d.workspaceSyncLoop(ctx)   // discovers new workspaces every ~30s
go d.heartbeatLoop(ctx)       // keepalive pings to server
go d.gcLoop(ctx)              // filesystem cleanup of old workdirs
go d.serveHealth(ctx, ...)    // /health endpoint for external monitoring
return d.pollLoop(ctx)        // blocking main loop
```

Key `pollLoop` mechanics:

- **Semaphore-based concurrency cap** — a buffered channel `sem` of size `MaxConcurrentTasks` gates task pickup; if the semaphore is full, the loop skips to sleep
- **Round-robin runtime selection** — `pollOffset` rotates through runtime IDs so no single runtime is always tried first
- **Claim → Start → Execute → Complete lifecycle** — tasks go through explicit API state transitions; `FailTask` is the fallback for any error in the chain
- **Server-side cancellation polling** — a goroutine polls `GetTaskStatus` every 5 seconds during execution; on `cancelled`, it calls `runCancel()` and closes a done channel
- **Session resume with fallback** — if `PriorSessionID` is set and execution fails with an empty `SessionID`, the daemon retries with a fresh session and merges token usage from both attempts

The `workspaceState` struct tracks per-workspace `runtimeIDs`, `reposVersion`, and `allowedRepoURLs`. The `repoRefreshMu` mutex uses a double-checked locking pattern to avoid redundant API calls when multiple tasks race to ensure the same repo is ready.

**Swift/Rust port verdict:** This is an excellent candidate for Rust, not Swift. The concurrent polling loop, channel-based semaphore, atomic `activeTasks` counter, and cancellation polling map precisely to Tokio's `Semaphore::new(max_concurrent)` + `mpsc` channels + `CancellationToken`. Write this as a Rust `daemon` crate and expose it to Swift via a `cbindgen`-generated C header, calling it from Swift with `@_silgen_name`.

***

## Pattern 6: Batched Message Drain with 500ms Flush (multica)

Inside `executeAndDrain`, multica runs a background goroutine that buffers tool use/result/thinking/text messages into a `batch` slice, then flushes every 500ms or at end:

```go
ticker := time.NewTicker(500 * time.Millisecond)
// select on session.Messages and ticker.C
// flush() sends batch to server, resets
```

This prevents HTTP request storms when the agent is making rapid tool calls, while still providing near-real-time streaming. A `callIDToTool` map resolves tool names for `tool_result` messages that arrive without the tool name — a common pattern in streaming APIs where the result message doesn't repeat the tool name.

**Swift port verdict:** Use a `Task.sleep(for: .milliseconds(500))` loop inside an actor or a `Timer.publish` pipeline. The `callIDToTool` lookup maps directly to `var callIDToTool: [String: String]` on the actor. This can be ported to Swift directly — Rust is only warranted if it becomes a performance bottleneck.

***

## Pattern 7: Multi-Model Usage Tracking (all three repos)

All three repos track token usage, but in importantly different ways:

| Repo | Approach | Key Insight |
|------|----------|-------------|
| rowboat | `UsageTracker.track()` with typed events (`LLM_USAGE`, `EMBEDDING_MODEL_USAGE`, `COMPOSIO_TOOL_USAGE`) passed through every invoke function | Event-typed tracking lets you audit by category |
| openclaude | `NonNullableUsage` accumulated across streaming events; `message_start` resets current usage; `message_stop` adds to total; `getModelUsage()` returns per-model breakdown | Streaming-aware: handles partial messages |
| multica | `map[string]TokenUsage` keyed by model name with `mergeUsage` for session-resume merging | Handles multi-session token aggregation elegantly |

Multica's `TaskUsageEntry` type tracks `InputTokens`, `OutputTokens`, `CacheReadTokens`, and `CacheWriteTokens` per model. The `mergeUsage` function handles the resume-retry case where two separate sessions' tokens must be combined into a single usage report.

**Swift port verdict:** Adopt multica's model-keyed map. Declare `var usageByModel: [String: TokenUsage]` on the `QueryEngine` actor with a `mutating func mergeUsage(_ other: [String: TokenUsage])`. Add rowboat's event-type classification as an associated value on a `UsageEvent` enum.

***

## Pattern 8: Feature Flag–Gated Modules (openclaude)

Openclaude uses `feature('COORDINATOR_MODE')` and `feature('HISTORY_SNIP')` for dead-code elimination at Bun bundle time. Feature-gated modules are only `require()`d if the feature is enabled, keeping the base bundle lean:

```typescript
const snipModule = feature('HISTORY_SNIP')
  ? require('./services/compact/snipCompact.js')
  : null
```

The injected `snipReplay` callback in `QueryEngineConfig` is the Swift-portable version of this pattern — it avoids conditional imports leaking feature-gated strings into the core file, which matters for automated code-exclusion tooling.

**Swift port verdict:** Use compile-time `#if FEATURE_HISTORY_SNIP` flags or inject optional protocol-typed dependencies in `QueryEngine.init`. The injection approach is more testable; the compile-flag approach is better for App Store builds where dead-code elimination matters for binary size.

***

## Port vs. Submodule Decision Matrix

| Component | Source | Recommended Action | Rationale |
|-----------|--------|--------------------|-----------|
| `QueryEngine` stateful agent loop | openclaude | **Port to Swift** | Maps to `actor` + `AsyncThrowingStream`; pure logic |
| Typed agent handoff system | rowboat | **Port to Swift** | Pure value types, no async primitives needed |
| Tool factory (`invoke*`/`create*` separation) | rowboat | **Port to Swift** | `protocol ToolInvoker` + actor pattern |
| JWT-signed webhook tool | rowboat | **Port to Swift** | `CryptoKit` handles HMAC-SHA256 natively |
| `AgentBackend` protocol + factory | multica | **Port to Swift** | `protocol AgentBackend` is a 1:1 translation |
| Budget + turn guards | openclaude | **Port to Swift** | `guard` statements in stream loop |
| Feature flag injection (snipReplay) | openclaude | **Port to Swift** | Optional closure on `QueryEngine.init` |
| Usage tracking (model-keyed map) | multica | **Port to Swift** | Trivial dictionary accumulation |
| Batched 500ms message flush | multica | **Port to Swift** (first) / **Rust** (if perf-critical) | Start simple; Rust only if needed |
| Daemon poll loop + semaphore concurrency | multica | **Port to Rust** | Tokio semaphore + channels is a near-exact translation |
| GC lifecycle for workdirs | multica | **Port to Rust** | Periodic filesystem task = Tokio `spawn_blocking` |
| RAG vector search (Qdrant) | rowboat | **Replicate** | Qdrant has a Swift client; don't submodule the TS version |

### Why Submodules Won't Work Here

Git submodules make sense only when (1) you want upstream fixes automatically, (2) the component has minimal language-boundary friction, and (3) porting would require re-implementing a large, stable algorithm. None of those conditions hold for any of the three repos when targeting Swift/Rust:

- All three are TypeScript or Go — every call from Swift requires FFI or a subprocess, adding latency and complexity
- The patterns you want are *architectural*, not *library* — you need the idea, not the npm package
- Submoduling TypeScript into a Swift app ships dead weight (node_modules, Bun runtime dependency)

**The one viable exception:** multica's Go server can be compiled as a standalone `multica-daemon` binary and invoked via subprocess from Swift (similar to how multica itself calls agent CLIs). This is legitimate if you want the full workspace + repo cache + GC system running as a background daemon on macOS.

***

## Recommended Swift Implementation Roadmap

### Phase 1 — Core Agent Loop
1. Define `AgentMessage` enum mirroring openclaude's SDK message types (`assistant`, `user`, `progress`, `result` with five subtypes)
2. Implement `actor QueryEngine` with `func submitMessage(_ prompt: String) -> AsyncThrowingStream<AgentMessage, Error>`
3. Add `maxBudgetUSD: Double?`, `maxTurns: Int?`, and `private(set) var permissionDenials: [PermissionDenial]`
4. Inject `snipReplay: ((AgentMessage, [Message]) -> SnipResult?)?` as an optional `init` parameter

### Phase 2 — Tool System
1. Define `protocol ToolInvoker { func invoke(_ input: [String: Any]) async throws -> String }`
2. Implement `RagToolInvoker`, `WebhookToolInvoker` (using `CryptoKit` HMAC-SHA256), `McpToolInvoker`, `MockToolInvoker`
3. Create `ToolFactory.make(_ config: ToolConfig) -> any ToolInvoker` dispatch function

### Phase 3 — Multi-Agent Handoffs
1. Define `struct AgentHandoff` with `targetAgent`, `contextType: HandoffContextType`, `onHandoff: @escaping Closure`
2. Implement `sanitizeAgentName(_ name: String) -> String` for function-name compliance
3. Add `createPipelineHandoff` with context message injection into `newItems`

### Phase 4 — Provider-Agnostic Dispatch
1. Define `protocol AgentBackend { func execute(...) async throws -> AsyncThrowingStream<AgentMessage, Error> }`
2. Create `BackendRegistry: [String: any AgentBackend.Type]` with `claude`, `codex`, `gemini` entries
3. Port multica's `AgentData`/`Task`/`SkillData` types to Swift `Codable` structs

### Phase 5 — Rust Daemon (Optional, for concurrent task execution)
1. Create `multica-daemon-rs` Rust crate with Tokio runtime
2. Implement `PollLoop` with `Arc<Semaphore>::new(max_concurrent)` and round-robin runtime selection
3. Add cancellation polling task spawned per execution
4. Expose via `cbindgen`-generated C header; call from Swift with `@_silgen_name`

***

## Licensing Notes

| Repo | License | Status |
|------|---------|--------|
| rowboatlabs/rowboat | Apache-2.0 | Freely portable; attribution in comments recommended |
| Gitlawb/openclaude | MIT | Freely portable; review Anthropic's original Claude Code license as it applies to the fork |
| multica-ai/multica | Apache-2.0 | Freely portable; check specific patent clauses if applicable |

Always attribute architectural inspiration in comments even when the license permits silent reuse — it helps future maintainers trace design decisions back to the original source.