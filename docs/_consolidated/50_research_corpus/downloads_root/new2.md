# Building Epistemos: a hybrid local+cloud agent architecture on macOS

**Claude Managed Agents, launched April 8, 2026, provides Anthropic-hosted sandboxed agent sessions that complement — but should not replace — a local Rust agent loop.** The optimal architecture for Epistemos is a hybrid system: a Rust-native agent runtime (using the `rig` or `yoagent` crate) handles latency-sensitive, privacy-critical, and offline-capable tasks locally, while Claude Managed Agents handles complex multi-step reasoning and long-running cloud workflows. Rowboat's open-source knowledge graph patterns — Obsidian-compatible Markdown with wiki-links, two-layer ingestion, and event-sourced agent state — map cleanly onto a GRDB-backed Rust backend. The critical integration seam is MCP: a Rust MCP server built with the official `rmcp` crate exposes your local knowledge graph to both local and cloud agents, though cloud access requires a tunnel (ngrok or Cloudflare Tunnel) since Claude's managed agent infrastructure cannot reach `localhost`.

---

## Claude Managed Agents: the full API surface

Claude Managed Agents is a **public beta** providing composable, Anthropic-hosted agent infrastructure. The three core primitives are **Agents** (persisted, versioned configurations), **Environments** (secure container templates), and **Sessions** (running instances with per-session containers). Every request requires the beta header `anthropic-beta: managed-agents-2026-04-01`.

The mandatory flow is: create an Agent once (store its `agent_id`), optionally configure an Environment, then create a Session for each run. Sessions provision a fresh container workspace with bash, file operations, web search/fetch, and MCP tools. The agent loop runs on Anthropic's orchestration layer, decoupled from the container — if a container dies, the harness catches it as a tool-call error and Claude retries in a new container. Sessions persist through client disconnections and can run for **hours**. The session itself is an append-only event log stored durably outside the harness.

Responses stream back via **Server-Sent Events (SSE)**. Event types include user turns, tool results, status updates, and agent responses. The SDKs (Python, TypeScript, Go, Ruby, PHP, Java — **no Rust or C#**) handle SSE parsing automatically. For Epistemos, you'll consume the SSE stream from Rust using `reqwest` with tokio, parsing events manually.

**Pricing** is consumption-based: standard Claude token rates (Sonnet 4.6 at **$3/$15 per MTok** in/out) plus **$0.08 per session-hour** of active runtime. Idle time is free. Web search costs ~$0.01 per query. Rate limits are **60 creates/min** and **600 reads/min** per organization.

The relationship to existing APIs is clear: the Messages API gives you maximum flexibility with your own agent loop; the Agent SDK gives you Claude Code's tools running on your compute; Managed Agents gives you Anthropic running both the loop and the sandbox. For Epistemos, the Messages API remains the right choice for simple local LLM calls, while Managed Agents handles complex delegated tasks. **Managed Agents is first-party only** — unavailable on Bedrock, Vertex, or Foundry.

## MCP integration: the critical bridge between local and cloud

MCP (Model Context Protocol) is the integration standard connecting your local knowledge graph to both agent runtimes. The official Rust SDK is the **`rmcp` crate** (v0.16.0+, under `modelcontextprotocol/rust-sdk` on GitHub with 3.2k stars). It supports two transports: **stdio** for local connections (Claude Desktop, Claude Code) and **Streamable HTTP** for remote connections (Claude API, managed agents).

Building the MCP server in Rust is straightforward with `rmcp`'s procedural macros:

```rust
#[tool_router]
impl KnowledgeGraphServer {
    #[tool(description = "Full-text search over knowledge graph entities")]
    async fn search_entities(&self, #[tool(param)] query: String, 
                              #[tool(param)] limit: Option<u32>) -> Result<CallToolResult, McpError> {
        // FTS5 query against GRDB/SQLite
        Ok(CallToolResult::success(vec![Content::text(results_json)]))
    }
    
    #[tool(description = "Get entity with full Markdown content and backlinks")]
    async fn get_entity(&self, #[tool(param)] id: String) -> Result<CallToolResult, McpError> { ... }
    
    #[tool(description = "Traverse relationships from a source entity")]
    async fn query_graph(&self, #[tool(param)] source: String, 
                          #[tool(param)] depth: Option<u32>) -> Result<CallToolResult, McpError> { ... }
}
```

The `rmcp` crate requires `tokio`, `serde`, and `schemars` (for automatic JSON Schema generation from Rust types). For Streamable HTTP, add `axum` and use `StreamableHttpService` with a `LocalSessionManager`. Dependencies in `Cargo.toml`:

```toml
rmcp = { version = "0.16.0", features = ["server", "transport-io", "transport-streamable-http-server", "macros"] }
```

**The critical constraint: Claude Managed Agents cannot reach localhost.** All MCP connections from Claude's cloud originate from Anthropic's infrastructure. Your local MCP server must be exposed via a public HTTPS endpoint. The two viable options are **ngrok** (`ngrok http 8080` for development) and **Cloudflare Tunnel** (production-grade, outbound-only connections, stable URLs). Both require Bearer token authentication on the MCP server. The `rmcp` examples include `servers_simple_auth_streamhttp` for this exact pattern.

For local-only use (Claude Desktop, the local Rust agent loop), stdio transport works directly with zero network setup. The recommended architecture is to run the MCP server in **both modes simultaneously**: stdio for the local agent runtime, and Streamable HTTP (behind a tunnel) for cloud agent access.

## Rowboat's knowledge graph: patterns worth stealing

Rowboat is a TypeScript monorepo (Electron desktop + Next.js web + CLI) with **~7k GitHub stars** and an Apache 2.0 license. Its knowledge graph architecture is deliberately simple and highly portable to Rust.

**Storage is Obsidian-compatible plain Markdown** organized by entity type (`People/`, `Projects/`, `Organizations/`, `Topics/`) under `~/.rowboat/knowledge/`. Each note represents the *current state* of an entity — not raw history — using `[[Wiki Links]]` for relationships. The founders explicitly chose files over a graph database: "Each note should be usable by the user too, not just the AI." There is no complex graph traversal; retrieval happens at note level via full-text search and backlink resolution.

The ingestion pipeline uses a **two-layer architecture** that maps well to Rust:

- **Layer 1 (Raw Sync)**: Idempotent, append-only ingestion from sources (Gmail, Calendar, transcripts). Each item stored as its own Markdown file keyed by source ID. Sync state tracked to prevent re-ingestion.
- **Layer 2 (Entity Consolidation)**: A `note_creation` agent runs periodically in batches. It receives a lightweight index of the entire knowledge graph plus raw source files, then decides entity resolution — whether "Sarah" maps to existing "Sarah Chen" or creates a new entity. Multi-pass convergence means later batches see entities created by earlier ones.

**Note creation strictness levels** (low/medium/high) control graph growth, auto-inferred based on inbox volume. This is a smart pattern for preventing knowledge graph bloat.

Background agents use three schedule types: **cron** (recurring), **window** (at-most-once within a time range), and **one-time**. They cannot execute shell commands (safety constraint) but can use file handling tools and MCP tools. "Live Notes" — created by tagging `@rowboat` on a note — are automatically updated by background agents, tracking competitors, people, or projects across communications.

The agent runtime is **event-sourced**: `AgentState` is rebuilt from a JSONL event log on each iteration, with a distributed lock preventing concurrent execution and a message bus forwarding events to the UI. This pattern translates directly to Rust: `serde_json` for JSONL, `tokio::sync::Mutex` for locking, `tokio::sync::mpsc` for the event bus.

## How to adapt Rowboat's patterns to GRDB-backed Rust

Rowboat's Markdown-as-database approach can be enhanced with GRDB/SQLite while preserving the same abstractions. The hybrid approach: **Markdown files as the canonical human-readable format, SQLite/GRDB as the query index**.

| Rowboat (TypeScript/Files) | Epistemos (Rust/GRDB) |
|---|---|
| Markdown files on disk | Markdown content stored in GRDB `entities` table |
| Wiki-link parsing at runtime | Pre-parsed backlinks in `edges` table |
| Sequential file scan for search | FTS5 virtual table for instant full-text search |
| JSONL run logs | GRDB `agent_runs` table with JSON columns |
| JSON config files | GRDB `config` table or plist |
| Node.js `fs` operations | `rusqlite` via GRDB's SQLite engine |

The entity schema in GRDB/SQLite:

```sql
CREATE TABLE entities (id TEXT PRIMARY KEY, title TEXT, type TEXT, content TEXT, 
                       tags TEXT, created_at TEXT, updated_at TEXT);
CREATE VIRTUAL TABLE entities_fts USING fts5(title, content, tags);
CREATE TABLE edges (source_id TEXT, target_id TEXT, relationship TEXT, context TEXT);
CREATE INDEX idx_edges_source ON edges(source_id);
CREATE INDEX idx_edges_target ON edges(target_id);
```

The two-layer ingestion pipeline translates to Rust as: (1) a sync module per source using `reqwest` + source-specific APIs, writing raw items to a `raw_inbox` table; (2) a background `tokio::spawn` task that periodically batches raw items, builds the entity index, calls Claude via the Messages API for entity resolution, and writes consolidated entities back to GRDB. The strictness-level pattern controls the LLM's threshold for creating new entities versus merging into existing ones.

## The hybrid agent architecture: local Rust + cloud Claude

**The Rust agent loop should be complemented, not replaced.** The decision framework:

Route to the **local Rust agent** when the task is latency-sensitive (<500ms), involves privacy-sensitive data, works offline, or is simple enough for a smaller model. Route to **Claude Managed Agents** when the task requires complex multi-step reasoning, sandboxed code execution, web research, or will run for minutes to hours. A production system (Slipbox.ai, a macOS-native app with a similar architecture) reported **50% cost savings** using this hybrid approach with negligible quality impact.

The concrete data flow for Epistemos:

```
SwiftUI → UniFFI → Rust Task Router → ┬→ Local Agent (rig/yoagent + local MCP server)
                                        └→ Cloud Agent (reqwest → Claude Managed Agents API)
                                              ↓
                                        SSE stream → tokio channel → UniFFI callback → SwiftUI
```

For **streaming events from Rust to Swift**, use UniFFI's callback trait pattern:

```rust
#[uniffi::export(with_foreign)]
pub trait AgentEventHandler: Send + Sync {
    fn on_event(&self, event: AgentEvent);
}

#[derive(uniffi::Enum)]
pub enum AgentEvent {
    TextDelta { text: String },
    ToolStart { name: String },
    ToolResult { name: String, result: String },
    SessionStatus { status: String },
    Complete,
    Error { message: String },
}
```

Swift implements this trait and bridges events to `@Published` properties or `AsyncStream` for SwiftUI consumption. UniFFI (v0.31.0) fully supports `async fn` with `#[uniffi::export(async_runtime = "tokio")]`, converting Rust futures to Swift `async/await`.

For **triggering Claude Managed Agents from Rust**, the pattern is: create the Agent once at app startup (store the `agent_id` in GRDB), then create a Session per task. Use `reqwest` to POST to the sessions endpoint with the beta header, then consume the SSE response stream with `reqwest`'s streaming body. Forward parsed events through a `tokio::mpsc` channel to the UniFFI callback trait.

## Rust agent frameworks worth evaluating

Three Rust crates directly applicable to Epistemos's local agent runtime:

- **Rig** (`rig-core` crate, rig.rs): The most mature Rust AI agent framework. Unified LLM interface across OpenAI/Anthropic/Cohere, agent builder pattern, tool system with derive macros for schema generation, RAG support, streaming completions, and OpenTelemetry tracing. Production-proven at Dria, Neon, and others. Best choice for the primary local agent.

- **yoagent**: A focused agent loop library providing the full event stream (`AgentStart → TurnStart → MessageUpdate → ToolExecution → TurnEnd → AgentEnd`). Parallel tool execution by default, sub-agent support, 20+ LLM providers. The event model maps naturally to the `AgentEvent` UniFFI enum above.

- **graph-flow** (`rs-graph-llm`): LangGraph-inspired graph-based agent workflows in Rust. Conditional edges, state management, session persistence. Worth monitoring if you need complex multi-step local workflows.

For the MCP server, `rmcp` is the only serious choice — it's the official SDK under the `modelcontextprotocol` GitHub organization with full macro support for tool generation.

## Open-source alternatives and why Claude Managed Agents still wins for this use case

| Framework | Language | Local execution | MCP support | Managed hosting | Fit for Epistemos |
|---|---|---|---|---|---|
| **Claude Managed Agents** | REST API (any) | ❌ Cloud only | ✅ Via proxy | ✅ Anthropic | ✅ Best for cloud tasks |
| **LangGraph Platform** | Python/TS | ✅ Self-host | ✅ Since v1.0 | ✅ LangSmith | ❌ No Rust, Python dep |
| **CrewAI** | Python | ✅ Local | ✅ Native + A2A | ✅ Enterprise | ❌ Python-only |
| **MS Agent Framework** | Python/.NET | ✅ Local | ✅ Built-in | ✅ Azure | ❌ No Rust, Azure lock-in |
| **OpenAI Agents SDK** | Python/TS | ✅ Local | ✅ Tools | ❌ No hosting | ❌ No Rust |
| **Claude Agent SDK** | Python/TS | ✅ Local | ✅ Deepest | ❌ Use Managed | ❌ No Rust |

**None of the Python/TypeScript frameworks belong in Epistemos's critical path.** Since the app is migrating from Python to pure Rust, adding a Python framework dependency would be a step backward. The correct approach: use `rig` or `yoagent` for the local Rust agent loop, Claude Managed Agents via REST for cloud tasks, and `rmcp` for the MCP server. The Python frameworks are valuable as reference architectures for patterns (LangGraph's checkpointing, CrewAI's role-based delegation, Rowboat's entity consolidation) that you reimplement in Rust.

## Concrete integration plan for Epistemos

**Phase 1 — MCP knowledge graph server (Rust, 2-3 weeks)**
Build a Rust binary using `rmcp` that opens your GRDB/SQLite database read-only and exposes five tools: `search_entities` (FTS5), `get_entity`, `get_backlinks`, `query_graph`, and `list_entities`. Support both stdio (for local agent) and Streamable HTTP (for cloud agent via tunnel) transports simultaneously. Add Bearer token authentication on the HTTP transport.

**Phase 2 — Local agent runtime (Rust, 2-3 weeks)**
Integrate `rig-core` as the local agent loop. Define tools that call into the MCP server (or call GRDB directly for lower latency). Implement the `AgentEventHandler` callback trait via UniFFI. Build the two-layer ingestion pipeline inspired by Rowboat: raw sync from sources → periodic entity consolidation via Claude Messages API. Store all state in GRDB.

**Phase 3 — Claude Managed Agents integration (Rust, 1-2 weeks)**
Create a `ManagedAgentClient` module in Rust that wraps `reqwest` calls to the Managed Agents API. Create your Agent once (with the MCP server's tunnel URL configured), then expose a `start_cloud_session(task: String)` function to Swift that creates a session, streams SSE events, and forwards them through UniFFI. Persist cloud session results back to GRDB.

**Phase 4 — Task router and hybrid orchestration (Rust, 1-2 weeks)**
Build a router that evaluates incoming tasks against criteria (complexity, privacy sensitivity, connectivity, cost budget) and dispatches to either the local `rig` agent or a Claude Managed Agent session. Implement context serialization for local-to-cloud handoffs: the router packages relevant entity context from GRDB as the session's initial prompt.

**Phase 5 — Background agents (Rust, 1 week)**
Implement Rowboat-style scheduling (cron, window, one-time) using `tokio` timers. Background tasks trigger the local agent runtime for entity consolidation, "live note" updates, and periodic graph maintenance. These run entirely locally — no cloud dependency for background processing.

## Conclusion

The architecture that emerges is a **three-layer system**: GRDB as the canonical persistence layer, a Rust MCP server as the universal tool interface, and two agent runtimes (local `rig` + cloud Managed Agents) selected by a task router. The key insight from Rowboat is that a knowledge graph doesn't need a graph database — **Markdown content indexed by SQLite FTS5 with an edges table for backlinks** is sufficient, human-readable, and fast on Apple Silicon. The key constraint from Claude Managed Agents is that **MCP servers must be publicly reachable** from Anthropic's infrastructure, making a Cloudflare Tunnel a production requirement for exposing local data to cloud agents. The key architectural decision is to **keep the Rust agent loop as the primary runtime** — it handles 80% of tasks locally with zero marginal cost and sub-second latency — and use Managed Agents only for tasks that genuinely require Claude's full reasoning capability in a sandboxed environment.