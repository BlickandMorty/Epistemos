# Claude Managed Agents & Rowboat: Integration Blueprint for Your Rust/Swift macOS PKM

## Executive Summary

Two major tools dropped this week that directly map to your PKM's architecture: **Claude Managed Agents** (Anthropic's new public beta API for fully hosted, cloud-run agent infrastructure) and **Rowboat** (an open-source, local-first AI coworker built on a Markdown knowledge graph). Neither should replace your existing Rust agent loop wholesale. Instead, the strongest architecture is a **hybrid layer**: your Rust backend handles local memory and incremental graph building (Rowboat-style), you expose that data as an MCP server, and Claude Managed Agents handles the heavy-lifting async tasks (multi-hour research, document generation, pipeline automation) via API. Your existing agent loop survives and is enhanced, not replaced.

***

## Part 1: Claude Managed Agents — The Full Picture

### What It Is and What Changed

Claude Managed Agents launched in public beta on April 8, 2026. It is a suite of composable REST APIs that gives developers a fully hosted agent runtime — meaning Anthropic runs the container, manages the state, handles context compaction, and provides built-in tool access. Previously, teams had to build all of this themselves using the raw Messages API: checking stop reasons, feeding tool results back into the message array, managing context as context windows approached their limits, and spinning up sandboxed environments for code execution.[^1][^2][^3]

The launch announcement confirmed full API access from day one — no reverse-engineering required. All production teams mentioned at launch (Notion, Sentry, Rakuten, Asana, Vibecode) are using the documented REST API endpoints.[^2][^4][^5]

### The Four Core Concepts

Everything in Claude Managed Agents is structured around four composable resources:[^6]

| Concept | Description | Created once? |
|---------|-------------|---------------|
| **Agent** | Model, system prompt, tools, MCP servers, skills | Yes — reference by ID |
| **Environment** | Cloud container config: packages, networking, mounts | Yes — reuse across sessions |
| **Session** | A running agent instance tied to an agent + environment | Per task |
| **Events** | Messages your app sends and streams back (SSE) | Per interaction |

Environments are the most powerful concept for your use case. You configure a cloud container once — specifying which packages are pre-installed (including `cargo` for Rust binaries, `pip` for Python, `npm` for Node), whether the container has unrestricted or limited network access, and what files to mount at session start. Every new session gets its own isolated container instance referencing that same environment config.[^7]

### API Endpoints and Beta Header

All requests require the `managed-agents-2026-04-01` beta header. The core REST surface is minimal:[^8][^7]

```
POST   /v1/environments              — create a container config
POST   /v1/sessions                  — start a session (agent + environment)
POST   /v1/sessions/{id}/events      — send a user message/event
GET    /v1/sessions/{id}/stream      — stream SSE responses
GET    /v1/sessions/{id}             — poll session status
POST   /v1/sessions/{id}/archive     — freeze without deleting
DELETE /v1/sessions/{id}             — full deletion
```

Sessions move through four states: `idle → running → rescheduling → terminated`. The `rescheduling` state is automatic retry on transient errors — you don't handle that yourself. Sessions persist through client disconnections, so your Swift frontend can drop and reconnect to the same session without losing progress.[^4][^8]

### Built-in Tools

Every session includes these tools without additional configuration:[^2]

- **Bash** — run shell commands in the managed container
- **File operations** — read, write, edit, glob, grep within the container
- **Web search + fetch** — live web access during sessions (billed at $10 per 1,000 searches)
- **MCP servers** — connect to any MCP-compatible external tool

The MCP connectivity is the critical bridge to your local PKM data. The networking config for environments supports `allow_mcp_servers: true` in limited networking mode, which permits the container to call out to your locally-hosted MCP server endpoints specifically.[^7]

### Pricing

Pricing has two components:[^2]

- **Token costs**: standard Anthropic API rates — Sonnet 4.6 at $3/M input, $15/M output; Opus 4.6 at $5/M input, $25/M output
- **Runtime**: $0.08 per session-hour of **active** execution time (measured in milliseconds; idle time waiting for input does not count)

For a task running 10 minutes of active compute, that's roughly $0.013 in runtime cost plus token costs. This is inexpensive for long-running tasks that would otherwise require you to host your own compute.

### What Is Still in Research Preview (Not Available by Default)

Three features require a separate access request at `claude.com/form/claude-managed-agents`:[^2]

1. **Multi-agent coordination** — agents spawning and directing sub-agents
2. **Outcomes/self-evaluation** — Claude iterating until it meets defined success criteria
3. **Memory** — cross-session persistent memory

The last one matters for your PKM: **cross-session memory is not included in the public beta**. This means if you want agents to remember context across separate sessions, you must implement that yourself via MCP or by passing prior context in the system prompt. This is actually an argument *for* keeping your local Markdown graph rather than depending on Anthropic's managed memory layer.

### Three API Paths Compared

Anthropic now explicitly documents three distinct paths:[^9][^10][^2]

| Path | Control | Infrastructure | Best for |
|------|---------|----------------|---------|
| **Messages API** | Maximum | You build everything | Custom loops, unusual memory architectures |
| **Claude Agent SDK** | High | Self-hosted process | Programmatic agents, CI/CD pipelines |
| **Managed Agents** | Less | Anthropic runs it | Long-running async tasks, no infra overhead |

The Agent SDK is worth understanding because it powers Claude Code and is available as a Python/TypeScript library (`claude-agent-sdk`). It handles the agent loop, context compaction, and built-in tool execution for you, but you still run the process yourself. The key trade-off: Managed Agents gets you to production in days; the SDK gives you more control but requires hosting. The Messages API gives you maximum flexibility but maximum boilerplate.[^11][^3]

***

## Part 2: Rowboat — Architecture Deep Dive

### What Rowboat Actually Is

There are two distinct products under the "Rowboat" name that require disambiguation. The Y Combinator listing describes a multi-agent IDE for building customer support agents. The GitHub repository at [rowboatlabs/rowboat](https://github.com/rowboatlabs/rowboat) is a different product: a local-first AI coworker that builds a persistent knowledge graph from your work data. This report focuses on the latter, which is directly relevant to your PKM.[^12][^13]

Rowboat is Apache-2.0 licensed with 5,500+ stars and 443 forks. The codebase is primarily TypeScript (96.8%) with a small Python component (0.8%). It ships as an Electron desktop app for Mac/Windows/Linux.[^14][^15]

### The Two Core Systems

Rowboat is architecturally split into two independent but connected parts:[^16]

**1. Living Context Graph**: Background services continuously ingest data from Gmail, Google Calendar, Fireflies, and voice memos. A graph builder processes this raw content into a structured Markdown knowledge vault organized around people, organizations, projects, and topics. This vault is stored locally at `~/.rowboat/knowledge/` in Obsidian-compatible plain Markdown with `[[backlinks]]`.[^17]

**2. Local Assistant**: An AI agent that reads from the knowledge graph, fetches relevant nodes before executing tasks, and can operate your local machine via shell access and MCP tools. It runs on demand or as scheduled background tasks.[^16]

### The Knowledge Graph Pipeline

The graph builder (`build_graph.ts`) is the architectural heart and the component most worth adapting for your Rust backend:[^17]

```
Content Sources → Change Detection → Batch Processing → Entity Extraction → Linked Notes
  Gmail              mtime + SHA-256    10 files/batch    AI agent run        People/
  Calendar           every 30s          full index        creates/updates     Orgs/
  Fireflies          state JSON         passed to agent   notes via tools     Projects/
  Voice Memos                                                                 Topics/
```

**Change Detection**: Every file is tracked by both modification time and SHA-256 content hash. `mtime` is checked first (cheap); hash is only computed when `mtime` changes. State is written to `knowledge_graph_state.json` and committed to version history after each batch.[^17]

**Entity Resolution via Knowledge Index**: Before each batch run, the system builds a `KnowledgeIndex` — a structured table of all known people (with emails, aliases, org links), organizations, projects, and topics. This index is passed directly into the agent's prompt. The agent resolves ambiguous entities ("JD" → "John Doe") against this index without needing to grep or search the filesystem. This is a key performance optimization for context efficiency.[^17]

**Batch Size of 10**: Files are processed in batches of 10, not one at a time. The agent sees patterns across multiple sources simultaneously, enabling cross-entity relationship detection.[^17]

**Note Templates**: Each entity type has a typed schema stored as Markdown frontmatter:

```markdown
# John Doe

**Email:** [email protected]
**Organization:** [[Acme Corp]]
**Role:** CEO
**Aliases:** JD, John

## Context
Met with John on 2026-02-28 to discuss [[Rowboat]] project...

## Related
- [[Acme Corp]]
- [[Rowboat]]
```

### MCP Integration

Rowboat supports MCP servers via `~/.rowboat/config/composio.json`. This means Rowboat's local assistant can call any MCP-compatible tool, and — critically — Rowboat itself can be wrapped as an MCP resource, exposing your knowledge graph to external agents like Claude Managed Agents.[^18][^14][^16]

### What Rowboat Does Not Do

Rowboat is **not** a multi-agent orchestration framework — it has a single local assistant running on top of a knowledge graph. It is also not model-agnostic at the orchestration layer (it uses OpenAI Agents SDK internally for the agent harness), though it supports any model for completion calls via Ollama, LM Studio, or hosted APIs. If you want to run Rowboat-style memory with Claude models throughout, you would need to adapt the graph builder to use your preferred LLM while keeping the storage architecture.[^19][^20]

***

## Part 3: The Integration Decision — Should You Replace Your Agent Loop?

### Short Answer

**No. Keep your Rust agent loop for local tasks.** The decision should be whether to *add* Managed Agents for specific use cases, not whether to rip out your existing infrastructure.

Here is the reasoning in concrete terms:

Your current architecture likely has a `wrist agent loop` (Rust engine) handling:
- Tool calls against local data
- Conversation history and context management
- Real-time, low-latency interactions

Claude Managed Agents handles:
- Long-running tasks (minutes to hours) that would block your UI
- Tasks requiring a full cloud container (code compilation, heavy processing)
- Asynchronous work that should persist through app restarts

These are **complementary workloads**, not competing ones. The latency profile alone makes them distinct: your local Rust loop handles interactive queries in milliseconds; Managed Agents is for fire-and-forget tasks you check back on later.[^6]

### When to Use Each Path

| Task Type | Use | Reason |
|-----------|-----|--------|
| Real-time chat, Q&A over notes | Rust agent loop (Messages API) | Low latency, full control |
| Deep research session (30+ min) | Managed Agents | Runs async, persists through disconnect |
| Summarize today's notes | Rust loop + local LLM | Privacy, speed |
| Generate slide deck from graph | Managed Agents (Agent Skills) | Built-in document generation |
| Background graph building | Rust background worker | Always-on, no API cost |
| Multi-step web research pipeline | Managed Agents | Built-in web search + Bash |
| Query specific node in graph | Rust via MCP | Instant, no cloud round trip |
| Cross-session memory | Your local Markdown vault | Managed memory in research preview only |

***

## Part 4: Concrete Integration Architecture

### The Hybrid Design

```
┌──────────────────────────────────────────────────┐
│  Swift Frontend (macOS)                          │
│  - Chat UI, voice input, graph visualization    │
│  - Session management (local + Managed Agents)  │
└──────────┬───────────────────┬───────────────────┘
           │                   │
    Local queries          Async task trigger
           │                   │
           ▼                   ▼
┌──────────────────┐   ┌─────────────────────────┐
│  Rust Backend    │   │  Anthropic API           │
│  - Agent loop    │   │  Claude Managed Agents   │
│  - Graph builder │◄──┤  - Environment (cloud)   │
│  - MCP server    │   │  - Sessions (per task)   │
│  - Markdown vault│   │  - SSE streaming         │
└──────────────────┘   └─────────────────────────┘
        │
   ~/.your_app/
   knowledge/
   ├── People/
   ├── Projects/
   ├── Topics/
   └── Inbox/ (raw sources)
```

### Step 1: Adopt Rowboat's Graph Architecture in Rust

The key algorithms to port from Rowboat's TypeScript to your Rust backend:

**Change Detection Worker** (runs every 30s or on file system event):
```rust
struct FileState {
    mtime: SystemTime,
    hash: [u8; 32],  // SHA-256
    last_processed: DateTime<Utc>,
}

struct GraphState {
    processed_files: HashMap<PathBuf, FileState>,
    last_build_time: DateTime<Utc>,
}
```
Use `mtime` first, compute SHA-256 only on mtime change. Serialize state to `knowledge_graph_state.json` after each batch.[^17]

**Entity-Typed Vault Structure**: Organize your `~/.yourapp/knowledge/` into `People/`, `Projects/`, `Topics/`, `Decisions/`, `Notes/`, and custom entity types relevant to your PKM domain. Each note uses Markdown with `[[wikilinks]]` for cross-references.[^17]

**Knowledge Index**: Before each batch extraction run, scan all existing notes to build a typed index. Format it as a Markdown table and pass it in the extraction prompt. This prevents duplicate entity creation and enables cross-source entity merging.[^17]

**Batch Size**: Process 10–15 new/changed files per agent run. This is enough to detect cross-entity patterns without overwhelming the context window.[^17]

### Step 2: Build an MCP Server in Rust

Expose your knowledge vault as an MCP server. This is the bridge that lets both your local agent loop and Claude Managed Agents read and write to the same data store. The MCP tools to implement:

```
pkm_search(query: string) → [Note]      # semantic or full-text search
pkm_get(path: string) → Note            # fetch a specific note
pkm_write(path, content) → void         # create or update a note
pkm_list_entity(type: EntityType) → [Entity]  # list People, Projects, etc.
pkm_graph_neighbors(node_id) → [Node]   # traverse backlinks
```

There are existing Rust MCP server frameworks you can build on. Once your MCP server is running locally, you can expose it via a tunneling service (ngrok, Cloudflare Tunnel) or a local network endpoint for Managed Agents sessions to call.[^21][^7]

For the environment networking config, use `limited` mode with `allow_mcp_servers: true` to grant only the managed container access to your MCP endpoint:[^7]

```json
{
  "type": "cloud",
  "networking": {
    "type": "limited",
    "allowed_hosts": ["your-mcp-tunnel.example.com"],
    "allow_mcp_servers": true
  }
}
```

### Step 3: Trigger Managed Agents from Swift

Your Swift frontend triggers a Managed Agents session when the user initiates a long-running task. The session creation call is straightforward:

```swift
// 1. POST /v1/sessions
let session = try await anthropicClient.createSession(
    agentId: deepResearchAgentId,
    environmentId: standardEnvId,
    vaultIds: [credentialVaultId]  // optional OAuth creds
)

// 2. Send task as event
try await anthropicClient.sendEvent(
    sessionId: session.id,
    content: "Research the latest papers on [topic] and synthesize findings into my knowledge graph."
)

// 3. Stream SSE responses
for await event in anthropicClient.streamEvents(sessionId: session.id) {
    await MainActor.run { updateUI(with: event) }
}
```

Sessions persist through disconnections — store the `session.id` locally and reconnect to the stream at any time. The session status polling endpoint (`GET /v1/sessions/{id}`) lets you check progress without maintaining an open SSE connection.[^22][^8]

There is also a [Swift Claude Code SDK](https://github.com/jamesrochabrun/ClaudeCodeSDK) with MCP integration support that provides Swift-native patterns for this kind of integration.[^23]

### Step 4: Close the Loop — Managed Agents Write Back to Your Graph

This is the most important architectural decision: when a Managed Agents session completes research or generates content, it should write results back to your local knowledge graph via the MCP server. Configure the agent's system prompt to use your `pkm_write` and `pkm_search` tools throughout the session, not just at the end. This way:

- Research findings are incrementally committed to the graph as the session progresses
- If a session is interrupted, partial work is not lost
- The local graph stays authoritative — Anthropic's servers hold execution state, your machine holds persistent memory[^2]

This design also sidesteps the research preview limitation: since cross-session memory is not available in public beta, your local Markdown vault **is** the memory layer.[^2]

***

## Part 5: Rowboat Patterns Worth Stealing vs. Skipping

### Steal These

- **mtime + hash change detection** — the exact algorithm Rowboat uses is efficient and Rust-idiomatic[^17]
- **Typed entity vault** (People, Orgs, Projects, Topics) — applies directly to a PKM[^17]
- **Knowledge index as prompt context** — passing a structured index to the extraction agent prevents grep calls and enforces entity resolution[^17]
- **Background service with partial saves** — state is committed after each batch so errors don't cause full reprocessing[^17]
- **Obsidian-compatible Markdown with `[[wikilinks]]`** — plain text, human-inspectable, compatible with the broader ecosystem[^14][^19]

### Skip These

- **OpenAI Agents SDK dependency** — Rowboat's orchestration layer depends on OpenAI's SDK. Since you're on Claude, you'll use Claude's APIs throughout instead.[^20]
- **Electron/TypeScript stack** — Rowboat is TypeScript-first. Your native Rust/Swift architecture is a significant advantage for macOS performance and integration. Do not adopt Rowboat's runtime; adopt its *architecture patterns*.
- **Gmail/Calendar sync via OAuth** — Rowboat's integrations are web-focused. Your PKM likely has native macOS data sources (Notes, Calendar via EventKit, Mail via MailKit) that you can tap directly without OAuth round trips.
- **Composio dependency for tools** — Rowboat uses Composio.dev as a tool integration layer. An MCP server is the cleaner native alternative for your architecture.[^14]

***

## Part 6: Answering Your Specific Questions

### "Should I replace my entire Rust agent loop?"

**No.** Keep it for all interactive, low-latency, and local tasks. Add Managed Agents as a separate execution path for async heavy-lifting. The cost profile of Managed Agents ($0.08/session-hour active) makes it cost-inefficient for short interactive queries; your local loop is free for those.[^2]

### "Does Claude Managed Agents work only for Claude, or can I use it with other models?"

Managed Agents is **Claude-only** — it is Anthropic's proprietary infrastructure. If you want to use the same infrastructure pattern with other models, you would need the Messages API (for direct model access) or a self-hosted alternative. This is why the Rowboat architecture pattern (local graph + MCP exposure) is valuable: it is model-agnostic. Your Rust MCP server can serve both Claude Managed Agents sessions and local Ollama sessions.[^5][^2]

### "Can I use the Agent SDK instead of Managed Agents?"

Yes, and it is worth understanding both. The Claude Agent SDK (formerly Claude Code SDK) manages the agent loop for you and is available as a Python/TypeScript library. It runs on your own infrastructure. For a native macOS app, embedding a Claude Agent SDK process as a subprocess adds complexity — the Managed Agents REST API is a cleaner fit for a Swift frontend calling out to an async backend. The SDK makes more sense for server-side or CLI-oriented deployments.[^24][^11]

### "Is there an open-source alternative to Claude Managed Agents I can self-host?"

For the orchestration harness specifically, there is no direct open-source equivalent with the same level of production polish. The closest pattern is the **Claude Agent SDK** for self-hosted execution. For the broader multi-agent orchestration pattern, [CrewAI](https://crewai.com) and LangGraph offer open-source orchestration but require you to build the sandboxing and state management yourself. Rowboat's open-source codebase gives you the memory/graph layer. Combining Rowboat's architecture + the Claude Agent SDK gives you an approximation of Managed Agents that runs locally, at the cost of infrastructure complexity.[^3][^16]

***

## Conclusion

The optimal integration strategy for your Rust/Swift macOS PKM is:

1. **Port Rowboat's knowledge graph pipeline to Rust** — change detection, entity typing, knowledge index, batch extraction. This is the persistent memory layer, and it should live locally.
2. **Expose the graph as an MCP server** — this is the universal bridge between your local data and any external agent, whether Claude Managed Agents or a local Ollama model.
3. **Keep your existing Rust agent loop** for interactive, low-latency, and privacy-sensitive tasks.
4. **Add Claude Managed Agents API integration** for long-running async tasks — triggered from Swift, streaming results back, writing outputs to your local graph via MCP.
5. **Do not depend on Managed Agents' research-preview memory** — your local Markdown vault is your cross-session memory. This is the correct design regardless of what Anthropic eventually ships in GA.

The net result is an architecture where the local app handles identity, memory, and real-time interaction, while Anthropic's infrastructure handles heavy compute — and MCP is the protocol binding them together.

---

## References

1. [Claude Platform - Claude API Docs](https://platform.claude.com/docs/en/release-notes/overview) - Updates to the Claude Platform, including the Claude API, client SDKs, and the Claude Console.

2. [Claude Managed Agents? Everything You Need to Know](https://www.lowcode.agency/blog/claude-managed-agents) - Claude Managed Agents lets you build and deploy production AI agents without building the infrastruc...

3. [Claude Agent SDK: Subagents, Sessions and Why It's Worth It](https://www.ksred.com/the-claude-agent-sdk-what-it-is-and-why-its-worth-understanding/) - The SDK runs by spawning a Claude Code CLI process as a subprocess rather than being a pure API libr...

4. [Anthropic has released Claude Managed Agents, a suite of APIs ...](https://x.com/ai_for_success/status/2041929141516472772)

5. [Claude Managed Agents, now in public beta | Claude | 27 ...](https://www.linkedin.com/posts/claude_claude-managed-agents-now-in-public-beta-activity-7447693438180995072-AjCH) - Introducing Claude Managed Agents, now in public beta on the Claude Platform. Shipping a production ...

6. [Claude Managed Agents overview - Claude API Docs](https://platform.claude.com/docs/en/managed-agents/overview) - When to use Claude Managed Agents ; Long-running execution - Tasks that run for minutes or hours wit...

7. [Cloud environment setup - Claude API Docs](https://platform.claude.com/docs/en/managed-agents/environments) - All Managed Agents API requests require the managed-agents-2026-04-01 beta header. The SDK sets the ...

8. [Start a session - Claude API Docs](https://platform.claude.com/docs/en/managed-agents/sessions) - All Managed Agents API requests require the managed-agents-2026-04-01 beta header. The SDK sets the ...

9. [Using the Messages API - Claude Console](https://platform.claude.com/docs/en/build-with-claude/working-with-messages) - Practical patterns and examples for using the Messages API effectively

10. [Three Ways To Build AI Agents With Claude](https://cobusgreyling.substack.com/p/three-ways-to-build-ai-agents-with) - The SDK gives you the full programmatic surface. Subagents as child processes. Tool allowlists. Mess...

11. [securevibes/docs/references/claude-agent-sdk-guide.md ...](https://github.com/anshumanbh/securevibes/blob/main/docs/references/claude-agent-sdk-guide.md) - A security system to protect your vibecoded apps. Contribute to anshumanbh/securevibes development b...

12. [RowBoat Labs: Open-source AI-assisted agent builder | Y Combinator](https://www.ycombinator.com/companies/rowboat-labs) - RowBoat is a pre-trained customer support LLM agent that seamlessly plugs into your systems, handles...

13. [What Does Rowboat Labs Do? - Company Overview - PromptLoop](https://www.promptloop.com/directory/what-does-rowboatlabs-com-do) - Rowboat Labs is an open-source AI IDE and agent platform that enables organizations to build, deploy...

14. [rowboat/README.md at main · rowboatlabs/rowboat](https://github.com/rowboatlabs/rowboat/blob/main/README.md) - Open-source AI coworker, with memory. Contribute to rowboatlabs/rowboat development by creating an a...

15. [GitHub - rowboatlabs/rowboat: Open-source AI coworker, with memory](https://github.com/rowboatlabs/rowboat) - Open-source AI coworker that turns work into a knowledge graph and acts on it. Rowboat connects to y...

16. [Rowboat – AI coworker that turns your work into a knowledge graph ...](https://news.ycombinator.com/item?id=46962641)

17. [Knowledge System Architecture - Rowboat - Mintlify](https://www.mintlify.com/rowboatlabs/rowboat/development/architecture/knowledge-system) - The graph builder runs every 30 seconds, checking all source folders for new/changed content. It use...

18. [Open-source AI coworker, with memory | James Chang - LinkedIn](https://www.linkedin.com/posts/james-chang-b6268534_github-rowboatlabsrowboat-open-source-activity-7428977274730844160-nx3Z) - MCP (Model Context Protocol) is that socket: a standardized, client‑server bridge that lets models c...

19. [Rowboat: The Open-Source AI Coworker That Actually Remembers](https://groundy.com/articles/rowboat-open-source-ai-coworker-that-actually/) - Rowboat is an open-source AI coworker with persistent memory that builds a knowledge graph from your...

20. [Meet Rowboat: An Open-Source IDE for Building Complex Multi ...](https://www.marktechpost.com/2025/04/24/meet-rowboat-an-open-source-ide-for-building-complex-multi-agent-systems/) - A Coding Implementation for Creating, Annotating, and Visualizing Complex Biological Knowledge Graph...

21. [Rust MCP Servers - LobeHub](https://lobehub.com/mcp/yourusername-rust-mcp-servers) - Stable, high-performance Model Context Protocol (MCP) servers written in Rust providing reliable alt...

22. [Work with sessions - Claude API Docsplatform.claude.com › docs › agent-sdk › sessions](https://platform.claude.com/docs/en/agent-sdk/sessions) - How sessions persist agent conversation history, and when to use continue, resume, and fork to retur...

23. [jamesrochabrun/ClaudeCodeSDK: Swift Claude Code SDK - GitHub](https://github.com/jamesrochabrun/ClaudeCodeSDK) - ClaudeCodeSDK provides full support for MCP integration. Using MCP with Configuration File. Create a...

24. [Best Multi-Agent Frameworks in 2026 - GuruSup](https://gurusup.com/blog/best-multi-agent-frameworks-2026) - Anthropic's SDK takes a tool-use-first approach where agents are Claude models equipped with tools, ...

