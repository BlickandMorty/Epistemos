# Epistemos Agent System — Complete Design Document

**Date:** 2026-03-07
**Status:** Approved — ready for implementation
**Scope:** Multi-agent system with MLX local inference, Learning Pool, Graph NPCs, TTS, App Store + Pro distribution

---

## Table of Contents

1. [Vision & Summary](#1-vision--summary)
2. [Decision Record](#2-decision-record)
3. [System Architecture](#3-system-architecture)
4. [Model Provider Layer (MLX Integration)](#4-model-provider-layer)
5. [The Four Agents](#5-the-four-agents)
6. [Agent Communication (Message Bus)](#6-agent-communication)
7. [Memory System (Three-Tier)](#7-memory-system)
8. [Learning Pool (Perplexica Port)](#8-learning-pool)
9. [Graph NPCs & Agent Visualization](#9-graph-npcs--agent-visualization)
10. [Voice System (Chatterbox TTS)](#10-voice-system)
11. [Trust Levels & Permissions](#11-trust-levels--permissions)
12. [Notifications](#12-notifications)
13. [Distribution (Lite vs Pro)](#13-distribution)
14. [Swift/Rust Split](#14-swiftrust-split)
15. [Source Repo Reference Map](#15-source-repo-reference-map)
16. [Competitive Analysis](#16-competitive-analysis)
17. [Implementation Phases](#17-implementation-phases)

---

## 1. Vision & Summary

Epistemos becomes a **multi-agent knowledge workstation** where specialized AI agents — each with their own personality, voice, memory, and workspace — collaborate to help the user manage notes, write research, and build software. Agents are visible as animated NPCs in the knowledge graph, with their own territory and gravity cluster.

**Core agents:**
- **Triage** — always-on lightweight classifier (Qwen 0.8B + Apple AI), routes tasks
- **Librarian** — reads, organizes, tags, connects notes. Proactive insights.
- **Writer** — configurable writing assistant with presets. Academic, technical, creative.
- **Builder** — code generation, project management, integrated IDE (editor + terminal + file tree)

**Key differentiators vs every other agent framework:**
- Only native macOS/Swift agent framework in existence
- MLX-first local inference on Apple Silicon (no Python, no server process for LLM)
- Graph NPC visualization — agents are visible animated entities in the knowledge graph
- Chatterbox TTS — each agent has a distinct voice, voice cloning with 5s audio sample
- Learning Pool — built-in research engine (Perplexica port) any agent can query
- Three-tier memory with Rust-powered semantic search
- Trust levels enforced structurally in Rust (not runtime checks in Swift)

---

## 2. Decision Record

Every design question asked and the user's exact answer:

| # | Question | Answer |
|---|---|---|
| 1 | Agent territory model (A: own tab/window, B: data sandbox, C: shared data + different personality) | "C maybe A on the fence between i want them all to have their own things not as a gate but because they are all good for 1 thing" — **C with elements of A** |
| 3 | IDE level for Builder (A: viewer, B: editor+terminal, C: full IDE) | "is C too much is there no middle ground before it... maybe not used as main IDE but surely IDE" — **B+ (editor + terminal + file tree, not full IDE)** |
| 4 | Notes Agent awareness (A: passive, B: active monitor, C: both) | **C** — passive search + subtle proactive signals without being annoying |
| 5 | Agent communication (A: manual handoff, B: @mention, C: shared clipboard) | "all of the above... i can both mention an agent and an agent can mention another agent there should be a chat and a settings like panel for toggling... agents listen and reach out intelligently" — **All, with ambient awareness** |
| 6 | Writing Agent scope (A: academic, B: broad professional, C: configurable) | "a,b,c all of them panel that has style subject, length, time, etc. research method via chat that model knows how to decode your chain of thought instruction into actionable steps... presets are used much more here so that users dont have to go through the process of just using it" — **All, configurable with presets as primary UX** |
| 8 | Model loading/memory (A: one at a time, B: small always loaded, C: auto budget) | "B. I want to have like an efficient low powered model that is intelligent enough to wake others up do things like summarize the graph nodes, answer answers quick and be like a direct triage to apple ai like they could work hand in hand. i could honestly get two efficient qwen models mixed with like a ML protocol or something then they work with me to dispatch other agents maybe?" — **B, tiered with small model always resident** |
| 9 | Coding file territory (A: single folder, B: user-configured, C: both) | **C** — defaults to projects folder, can point at any directory |
| 10 | Autonomy level (A: full auto, B: semi-auto, C: configurable) | "C yes configurable you can place trust in an agent more than another with more tasks and more deep computer use. i want to use the claude code thing where they use claude code in the qwen models to improve it" — **C, configurable trust per agent, Claude Code agent loop pattern** |
| 11 | Triage intelligence (A: rule-based, B: model-driven, C: hybrid) | **B** — model-driven, small Qwen reasons about routing |
| 12 | Agent panel location (A: new tab, B: sidebar, C: in settings, D: floating) | **B** — sidebar that sits in the main home window |
| 13 | Deep computer use scope (A: file system, B: shell, C: system-level, D: all gated) | **D** — all of the above, gated by trust level per agent |
| 14 | Triage visibility (A: invisible, B: default chat, C: both modes) | **C** — it's the default chat (receptionist), routing decisions visible ("Routing to Builder..."), reasoning hidden unless debug view toggled |
| 15 | Chat architecture (Option 1: toggle, 2: separate, 3: main chat + agent panel) | **Option 3** — main chat with agent awareness, agent work happens in agent panel. "needs to be robust enough" |
| 16 | Agent panel primary view (A: dashboard, B: chat-first, C: split) | **A** — agent status dashboard with cards, tap card to open thread |
| 17 | Trust levels (A: binary, B: three tiers, C: granular toggles) | **B** — three tiers: Sandbox, Standard, Elevated |
| 18 | Real-time visibility (A: log, B: live feed, C: both + notifications) | **C** — live feed while working, persisted as reviewable log after, plus notifications |
| 19 | Agents in graph (A: no, B: as nodes, C: only work products) | "yes so agents are NPC robot like things that will float around the graph and attach to nodes it works on... an entire section separate from the other nodes with its own gravity that has agent work and agent knowledge graph abstracted" — **Yes, as animated NPC nodes with separate gravity cluster** |
| 20 | NPC visual style (A: abstract geometric, B: robot avatar, C: aura/field) | **B** — tiny stylized robots with distinct silhouettes |
| 21 | Agent cluster relationship (A: tethered, B: bridged portal, C: orbital) | **B** — bridged with portal/wormhole visual between main graph and agent territory |
| 22 | V1 scope | **ALL features** (A through K — triage, all 3 agents, agent panel, inter-agent communication, trust levels, graph NPCs, agent gravity cluster, notifications, MLX integration) |
| 23 | Learning Pool | Port Perplexica's full search pipeline to Swift+Rust as "Agent Knowledge Base." Visible as section in home window. Agents pull from it automatically. |
| — | Rust vs Swift | Approved split: Swift for agents/UI/MLX, Rust for data processing/memory/tools/graph |
| — | Distribution | App Store Lite (free, sandboxed) + Direct Download Pro (paid, full power). Cannot prompt in-app to download Pro (Apple rule 3.1.1). Info in Settings only. |
| 31 | TTS Engine | Chatterbox Turbo via persistent Python daemon subprocess |
| 32 | Agent voices | Each agent gets a distinct default voice. User can clone custom voices with 5-15s audio sample. |
| 33 | Read Mode | Toggle per surface: notes, chat, graph summaries. Agents speak notifications and updates. |

---

## 3. System Architecture

```
+---------------------------------------------------------------------+
|                        EPISTEMOS APP                                 |
|                                                                      |
|  +----------+  +----------+  +----------+  +------------------+    |
|  | Main Chat|  |  Notes   |  |  Graph   |  |   Agent Panel    |    |
|  |(Triage)  |  |  Editor  |  |  (Metal) |  |  (Dashboard +    |    |
|  |          |  |          |  |  + NPCs  |  |   Command Chat)  |    |
|  +----+-----+  +----+-----+  +----+-----+  +-------+----------+    |
|       |              |             |                 |               |
|  -----+--------------+-------------+-----------------+------------- |
|                          MESSAGE BUS                                 |
|  ------------------------------------------------------------------ |
|       |              |             |                 |               |
|  +----+-------------------------------------------------+--------+ |
|  |                    AGENT ENGINE                       |        | |
|  |                                                       |        | |
|  |  +---------+  +----------+  +----------+             |        | |
|  |  | Triage  |  | Librarian|  |  Writer  |             |        | |
|  |  | (0.8B)  |->| (2B)     |  |  (4B/   |             |        | |
|  |  | +AppleAI|  |          |  |   Cloud) |             |        | |
|  |  +----+----+  +----------+  +----------+             |        | |
|  |       |                                               |        | |
|  |  +----+----+  +------------------------------+       |        | |
|  |  | Builder |  |         LEARNING POOL         |       |        | |
|  |  | (Coder/ |  |  (Perplexica port: web search,|       |        | |
|  |  |  Cloud) |  |   academic, RAG, widgets)     |       |        | |
|  |  +---------+  +------------------------------+       |        | |
|  |                                                       |        | |
|  |  +------------------------------------------------+  |        | |
|  |  |              TOOL REGISTRY (MCP)               |  |        | |
|  |  |  file_read | file_write | shell_exec           |  |        | |
|  |  |  note_search | web_search | url_fetch          |  |        | |
|  |  |  graph_query | embeddings | learning_pool      |  |        | |
|  |  +------------------------------------------------+  |        | |
|  |                                                       |        | |
|  |  +------------------------------------------------+  |        | |
|  |  |           MODEL PROVIDER LAYER                 |  |        | |
|  |  |  MLX (Qwen local) | Apple AI | LLMService     |  |        | |
|  |  |  (Anthropic/OpenAI/Google/Kimi/Ollama)         |  |        | |
|  |  +------------------------------------------------+  |        | |
|  |                                                       |        | |
|  |  +------------------------------------------------+  |        | |
|  |  |              MEMORY SYSTEM                     |  |        | |
|  |  |  Working (context) | Episodic (sessions)       |  |        | |
|  |  |  Semantic (embeddings + knowledge graph)       |  |        | |
|  |  +------------------------------------------------+  |        | |
|  +-------------------------------------------------------+        | |
|                                                                      |
|  +---------------------------------------------------------------+ |
|  |              PERSISTENCE                                       | |
|  |  SwiftData | Vault (.md files) | Agent Workspaces (fs)        | |
|  +---------------------------------------------------------------+ |
|                                                                      |
|  +---------------------------------------------------------------+ |
|  |              VOICE (Chatterbox TTS)                            | |
|  |  Python daemon subprocess | Per-agent voices | Read Mode      | |
|  +---------------------------------------------------------------+ |
+---------------------------------------------------------------------+
```

**Key architectural decisions:**

1. **Message Bus** — central async message bus (Swift actor). All UI surfaces and agents connect to it. Messages are typed enums, routed, and logged. Inspired by OpenClaw's gateway + Confluent's event bus pattern, implemented as native Swift actors.

2. **Agent Engine** — Swift actor owning all agent lifecycles. Each agent is an isolated actor with its own memory, tool permissions, and conversation thread. Inspired by OpenClaw's session routing, using Swift's actor model instead of child processes.

3. **Model Provider Layer** — existing `LLMService` extended with `MLXProvider`. Any agent can use any model. Triage picks the best model per task.

4. **Learning Pool** — Perplexica's search pipeline ported to Swift+Rust. Web search (Brave), academic search, RAG over documents, widgets.

5. **Tool Registry** — MCP-compatible tool definitions. Each agent gets a filtered subset based on trust level (OpenClaw's tool profiles pattern).

6. **Voice** — Chatterbox Turbo TTS via persistent Python daemon subprocess. Each agent has a distinct voice. Voice cloning supported.

---

## 4. Model Provider Layer

### MLX Integration

MLX is Apple's ML framework for Apple Silicon. Runs models directly on GPU via Metal with unified memory (CPU and GPU share memory on M-series chips).

**Dependencies to add:**
```
mlx-swift-lm  ->  https://github.com/ml-explore/mlx-swift-lm (branch: main)
swift-transformers  ->  https://github.com/huggingface/swift-transformers (from: 1.1.9)
```

These two packages pull in 7 transitive dependencies (mlx-swift, swift-jinja, yyjson, swift-numerics, swift-collections, swift-crypto, swift-asn1) — all internal plumbing, never used directly.

**Reference implementation:** `mlxchat-main/MLXChat/Engine/MLXEngine.swift`

**Key code to port from MLXChat:**
- `MLXEngine` actor — model loading, GPU memory management, streaming generation
- Tool call parsing — Qwen 3.5 XML function format (`parseToolCall` at line 377-455)
- Chat template patching — Qwen 3.5 4B has buggy Jinja template for `enable_thinking=false`, MLXChat patches at runtime
- Repetition detection and trimming
- Think tag stripping

**Model allocation strategy:**

| Model | Size | Purpose | Loaded When |
|-------|------|---------|-------------|
| Qwen 3.5 0.8B Q4 | ~700MB | Triage classification, memory compaction, quick answers | Always (app launch) |
| Qwen 3.5 2B Q4 | ~1.8GB | Librarian tasks, note analysis | On demand (Librarian activated) |
| Qwen 3.5 4B Q4 | ~2.8GB | Writer drafts, Builder code gen | On demand (swaps out 2B) |
| Qwen 3.5 9B Q4 | ~5.6GB | Complex code, deep analysis | On demand (high-memory Macs only) |
| Cloud (Claude/GPT) | 0MB local | Architecture decisions, complex research, quality writing | Via existing LLMService |

**Memory management:**
- Small model (0.8B) always resident — triage + compaction
- Larger models swap in/out based on which agent needs them
- `GPU.set(memoryLimit:)` from MLX controls ceiling
- When swapping: unload current model, clear cache, load new model (~2-5s)

**Integration with existing LLMService:**
- Add `MLXClient` conforming to `LLMClientProtocol`
- `generate()` and `stream()` methods delegate to `MLXEngine` actor
- Triage service upgraded: instead of keyword complexity scores, small Qwen classifies intent
- Provider selection: MLX for local fast tasks, cloud for quality tasks, Apple Intelligence for trivial tasks

### Provider Architecture (extended from current)

```
LLMService
  |-- AnthropicClient     (existing)
  |-- OpenAIClient         (existing)
  |-- GoogleClient         (existing)
  |-- KimiClient           (existing)
  |-- OllamaClient         (existing, Pro only)
  |-- AppleIntelligenceClient (existing)
  |-- MLXClient            (NEW)
       |-- MLXEngine actor
       |-- Model loading/unloading
       |-- Streaming generation
       |-- Tool call parsing (Qwen XML format)
```

---

## 5. The Four Agents

### Agent 0: Triage ("Front Desk")

Not a full agent — a lightweight classifier that's always on.

| Property | Value |
|---|---|
| Model | Qwen 3.5 0.8B (MLX, always loaded ~700MB) + Apple Intelligence |
| Role | Classify user intent, route to agents, answer trivial questions directly |
| Trust Level | N/A — routes, doesn't execute tools |
| Memory | None of its own — reads shared context |
| UI Home | Main Chat (invisible routing, visible as receptionist) |

**How it works:**

1. User types in main chat
2. Triage model classifies intent using few-shot prompt with ~100 example mappings:
   - "build me a parser" -> Builder
   - "summarize my notes on quantum computing" -> Librarian
   - "help me rewrite this methodology section" -> Writer
   - "what time is it" -> answer directly (Apple Intelligence)
   - "research recent papers on CRISPR" -> Writer + Learning Pool
3. For ambiguous requests, it asks: "Should I route this to the Writer or the Builder?"
4. Shows routing pill in main chat: "-> Routing to Builder" — tap opens Agent Panel
5. Logs corrections: user says "no, that's for the Writer" -> stored as new few-shot example

**Intent classification prompt structure:**
```
You are a task router. Classify the user's message into one of:
- DIRECT: Answer immediately (greetings, time, simple facts)
- LIBRARIAN: Note organization, search, connections, tagging
- WRITER: Prose improvement, research writing, article drafting
- BUILDER: Code generation, file creation, terminal commands, IDE work
- LEARNING_POOL: Web search, academic research, current events

Examples:
"organize my notes from last week" -> LIBRARIAN
"write me a swift function that..." -> BUILDER
"help me polish this paragraph" -> WRITER
"what's the latest on CRISPR research" -> LEARNING_POOL
"hi" -> DIRECT
...

User message: {input}
Classification:
```

**Why 0.8B is enough:** Classification, not generation. Picks from 5 categories. <100ms latency target.

**Inspired by:** CoPaw's command handler (routes /commands), upgraded to model-driven. OpenClaw's session routing (config -> agent), upgraded to intelligent.

---

### Agent 1: Librarian

| Property | Value |
|---|---|
| Model | Qwen 3.5 2B (MLX) for quick tasks. Cloud (Claude) for deep analysis. |
| Role | Read, organize, tag, connect, and surface insights from all notes |
| Trust Level | Default: Standard (read/write notes, no shell, no system) |
| Memory | Episodic (per-session thread) + Semantic (full note index via embeddings in Rust memory-engine) |
| UI Home | Notes sidebar + Agent Panel card |
| Tools | `note_search`, `note_read`, `note_tag`, `note_move`, `graph_query`, `embedding_search`, `learning_pool_search` |

**Passive mode (always running in background):**
- Watches note edits via `NotesUIState` observation
- When note saved, Rust `memory-engine` re-embeds it
- Periodically scans for:
  - Untagged notes -> suggests tags (subtle badge on sidebar)
  - Contradictions between notes -> flags with dot indicator
  - Missing connections -> "This note mentions X, which relates to your note Y"
- Signals appear as subtle badges/dots in Notes sidebar

**Active mode (user invokes):**
- "@librarian find everything I wrote about transformer architectures"
- "@librarian organize my research folder by topic"
- "@librarian what connects my notes on MLX and my notes on Qwen?"
- Uses `graph_query` for knowledge graph traversal
- Uses `embedding_search` (Rust) for semantic similarity
- Can invoke Learning Pool for web/academic supplementation

**Proactive agent-to-agent:**
- When Writer drafts, Librarian surfaces relevant notes
- When Builder creates files, Librarian indexes them in knowledge graph
- Communication via message bus inbox

---

### Agent 2: Writer

| Property | Value |
|---|---|
| Model | Cloud-first (Claude/GPT-4) for quality. Qwen 3.5 4B (MLX) for quick edits. |
| Role | Improve, draft, and structure written content across configurable styles |
| Trust Level | Default: Standard |
| Memory | Episodic (per-document thread) + Style presets (persistent config) |
| UI Home | Notes editor (integrates with existing per-note chat) + Agent Panel card |
| Tools | `note_read`, `note_write`, `note_search`, `learning_pool_search`, `learning_pool_academic`, `embedding_search` |

**Preset system (primary UX):**

```
+-------------------------------------+
|  Writer Presets                     |
|                                     |
|  * Academic Paper    o Blog Post   |
|  o Technical Doc     o Grant       |
|  o Literature Review o Custom      |
|                                     |
|  Style:    [Formal        v]       |
|  Length:   [======*===] ~2000w     |
|  Depth:   [========*=] Deep        |
|  Method:  [Analytical     v]       |
|  Tone:    [Objective      v]       |
|  Citation: [APA 7th       v]       |
|                                     |
|  [Save as Preset]  [Apply]         |
+-------------------------------------+
```

- Presets are the 80% path — tap preset and everything configures
- Manual dials for power users
- Writer's system prompt dynamically built from settings

**Chain-of-thought instruction decoding:**
When user gives loose instruction like "take my rough notes and turn them into a proper methodology section for my CRISPR paper, maybe 1500 words, needs to reference the three studies I cited last week":

1. Parses into structured plan (task, source, length, style, dependencies)
2. Shows plan in Agent Panel for approval
3. Requests dependencies from other agents (e.g., Librarian finds citations)
4. Executes with streaming output into note editor

**Integration with existing note editor:**
- Streams into existing per-note chat sidebar (`NoteChatState`)
- Accept/discard flow already exists (the `---` divider pattern)
- Upgrades existing `NotesOperation` enum from fixed ops to full agent with presets

**Proactive agent-to-agent:**
- Checks with Librarian before completing: "Are there notes that contradict this claim?"
- After completing, notifies Librarian to index new content
- Can request Builder to format citations or generate code

---

### Agent 3: Builder

| Property | Value |
|---|---|
| Model | Qwen 3.5 4B-9B Coder (MLX) for code gen. Cloud (Claude) for architecture. |
| Role | Write code, manage projects, execute commands, build software |
| Trust Level | Default: Standard. Configurable up to Elevated. |
| Memory | Episodic (per-project thread) + Project context (file tree, recent edits) |
| UI Home | Agent Panel (dedicated Builder workspace) + Notes sidebar "Agents" section |
| Tools | `file_read`, `file_write`, `file_delete`, `shell_exec` (gated), `note_search`, `learning_pool_search`, `graph_query` |

**Workspace (B+ IDE):**

```
+-----------------------------------------------------+
|  Builder Workspace                                   |
|                                                      |
|  +----------+  +--------------------------------+   |
|  | File Tree |  |  Editor (syntax highlighted)   |   |
|  |           |  |                                |   |
|  | > src/    |  |  import Foundation             |   |
|  |   main.sw |  |                                |   |
|  |   util.sw |  |  struct Parser {               |   |
|  | > tests/  |  |      func parse(_ input:       |   |
|  |   test.sw |  |          String) -> AST {       |   |
|  |           |  |          // ...                |   |
|  |           |  |      }                         |   |
|  |           |  |  }                             |   |
|  +----------+  +--------------------------------+   |
|  | Activity  |  |  Terminal                       |   |
|  | Log       |  |  $ swift build                  |   |
|  |           |  |  Build complete! (0.42s)        |   |
|  | v Created |  |  $ swift test                   |   |
|  |   main.sw |  |  All tests passed (3/3)         |   |
|  | v Ran     |  |  $                              |   |
|  |   build   |  |                                |   |
|  +----------+  +--------------------------------+   |
+-----------------------------------------------------+
```

- File tree scoped to project folder (default: `~/Epistemos-Projects/{project}/`)
- User can point at any folder
- Syntax highlighting via `NSTextView` with language-specific `NSTextStorage`
- Terminal pane streams shell output in real time
- Activity log shows every action (Claude Code transparency pattern)

**The Claude Code agent loop (Swift+Rust):**

```
while !task.isComplete && iterations < maxIterations {
    1. Build context: system prompt + project files + conversation + tool results
    2. Call model (MLX Qwen-Coder or Cloud Claude)
    3. Parse response for tool calls (Qwen XML format or Claude native)
    4. If tool call:
       a. Validate against trust level (Rust tool-sandbox)
       b. If trust requires approval -> show in UI, wait for user
       c. Execute tool (Rust tool-sandbox)
       d. Stream result to activity log + feed back to model
       e. Emit notification if significant action
    5. If text response:
       a. Stream to Builder chat
       b. Check if task is complete
    6. Update todo list (Manus pattern -- rewrite goals into recent context)
}
```

**Proactive agent-to-agent:**
- After creating files, mentions Librarian to index in knowledge graph
- When encountering research questions, queries Learning Pool
- When generating docs, asks Writer to review prose
- Before completing, notifies user with summary of all changes

---

## 6. Agent Communication

### Message Bus Architecture

Central async message bus — every agent and UI surface connects.

```
                    +---------------------+
                    |    MESSAGE BUS      |
                    |  (Swift Actor)      |
                    |                     |
                    |  Route | Log | Fan  |
                    +--+--+--+--+--+-----+
                       |  |  |  |  |
         +-------------+  |  |  |  +--------------+
         |        +-------+  |  +--------+        |
         v        v          v           v        v
    +---------+ +--------+ +--------+ +--------+ +------+
    | Triage  | |Librarian| | Writer | |Builder | |  UI  |
    |         | |        | |        | |        | |Views |
    +---------+ +--------+ +--------+ +--------+ +------+
```

**Message types:**

```swift
enum AgentMessage: Sendable {
    // Routing
    case taskAssignment(from: AgentID, to: AgentID, task: AgentTask)
    case taskComplete(from: AgentID, result: AgentResult)

    // Agent-to-agent (@mention)
    case mention(from: AgentID, to: AgentID, context: String, request: String)
    case mentionResponse(from: AgentID, to: AgentID, response: String)

    // Proactive signals
    case insight(from: AgentID, relevantTo: AgentID?, content: String)
    case indexRequest(from: AgentID, content: IndexableContent)

    // UI updates
    case statusUpdate(from: AgentID, status: AgentStatus)
    case notification(from: AgentID, message: String, speak: Bool)
    case activityLog(from: AgentID, action: String, detail: String)

    // Learning Pool
    case searchRequest(from: AgentID, query: SearchQuery)
    case searchResult(to: AgentID, results: [SearchChunk])
}
```

**Ambient awareness:** Every agent subscribes to the bus via `AsyncStream<AgentMessage>`. Each agent has a filter — Librarian listens for `indexRequest` and `mention`, Builder for `taskAssignment`, etc. When an agent publishes an `insight`, all agents receive it and independently decide whether to act.

**@mention flow:**
1. User types "@writer polish this paragraph" in any chat
2. Bus routes `mention` to Writer
3. Writer processes in its own thread, responds via `mentionResponse`
4. Bus delivers response to originating UI surface

**Agent-initiated mentions:**
1. Builder finishes creating files -> publishes `mention(to: .librarian, request: "Index these 5 new files")`
2. Librarian receives, indexes, responds
3. Builder receives confirmation, continues

**Inspired by:**
- Claude Code TeammateTool — JSON inbox files on disk. Adapted to in-memory Swift actor mailboxes.
- OpenClaw ACP — bidirectional RPC. Our message bus is the native Swift equivalent.
- Confluent's event bus pattern — pub/sub. We use typed enums for compile-time safety.

---

## 7. Memory System

### Tier 1: Working Memory (per-agent context buffer)

| Property | Detail |
|---|---|
| Storage | In-memory array of `ChatMessage` per agent thread |
| Capacity | Governed by model context window (4K-32K tokens) |
| Compaction | When 70% full, summarize older messages |
| Compaction model | Small Qwen 0.8B (fast, cheap) |
| Todo rewriting | Before each turn, rewrite current goals into recent context (Manus pattern) |

### Tier 2: Episodic Memory (per-agent session history)

| Property | Detail |
|---|---|
| Storage | SwiftData (`SDAgentThread` model) |
| Scope | Per agent + per project/document |
| Contents | Compacted summaries + key decisions + tool results |
| Retrieval | On new session, loads last N compacted summaries as context |
| Pruning | After 90 days, auto-archive (searchable, not loaded) |

### Tier 3: Semantic Memory (shared knowledge base)

| Property | Detail |
|---|---|
| Storage | Rust `memory-engine` crate (embeddings + vector index) |
| Embedding model | Small local embedding model via MLX or sentence-transformers |
| Index | All notes, agent-generated files, Learning Pool results |
| Search | Cosine similarity (vector) + BM25 (keyword) hybrid |
| Graph integration | Semantic edges in knowledge graph |
| Shared | All agents can query. Only Librarian writes (prevents conflicts). |

**How tiers connect (example):**
```
User asks Builder: "refactor the parser using the pattern I described last week"

Tier 1 (Working): No mention of parser pattern in current context
        |
Tier 2 (Episodic): "3 sessions ago, user discussed visitor pattern for AST parsing"
        |
Tier 3 (Semantic): Note 'Design Patterns for Parsers' has 0.92 similarity.
        |
Builder has full context. Proceeds with refactor.
```

**Inspired by:**
- CoPaw MemoryManager — semantic search + compaction with configurable threshold (70% ratio)
- OpenClaw memory plugin — swappable backends. Our Rust crate is the native equivalent.
- Mem0 — dynamic memory extraction from conversations
- Perplexica RAG — chunk + embed + cosine search, implemented in Rust

---

## 8. Learning Pool (Perplexica Port)

The always-available research engine that any agent can query.

### Pipeline (ported from Perplexica)

```
+------------------------------------------------------+
|                   LEARNING POOL                       |
|                                                       |
|  +-------------+  +--------------+  +------------+  |
|  |  Classifier  |  |  Researcher  |  |  Widgets   |  |
|  |  (intent +   |  |  (ReACT      |  |  (weather, |  |
|  |   source     |  |   loop with  |  |   stocks,  |  |
|  |   selection) |  |   tools)     |  |   calc)    |  |
|  +------+-------+  +------+-------+  +-----+------+  |
|         |                 |                 |         |
|  +------+-----------------+-----------------+------+ |
|  |              SEARCH TOOLS                        | |
|  |  web_search (Brave) | academic_search (Brave)   | |
|  |  url_scrape         | note_search (local)       | |
|  |  upload_search (RAG)| graph_query (Rust)        | |
|  +------------------------------------------------------+
|                                                       |
|  +--------------------------------------------------+ |
|  |              ANSWER WRITER                        | |
|  |  Combines sources + widgets -> cited answer       | |
|  +--------------------------------------------------+ |
|                                                       |
|  Implementation: Rust learning-pool crate             |
|  Source: Ported from Perplexica (TypeScript -> Rust)   |
+------------------------------------------------------+
```

**Steps:**

1. **Classify** — LLM determines: skip search? which sources? which widgets? Rewrite query as standalone.
   - Source: `Perplexica-master/src/lib/agents/search/classifier.ts`

2. **Research** (parallel with widgets) — ReACT loop:
   - LLM picks tools: `web_search`, `academic_search`, `url_scrape`, `upload_search`
   - Execute in parallel (Swift TaskGroup, Rust for fetching)
   - Feed results back, LLM decides: done or search more?
   - Iteration limits: Speed (2), Balanced (6), Quality (25)
   - Source: `Perplexica-master/src/lib/agents/search/researcher/`

3. **Write Answer** — LLM combines research + widgets into cited response
   - Source: `Perplexica-master/src/lib/agents/search/`

**What changes from Perplexica:**
- SearXNG replaced with Brave Search (from MLXChat's `BraveSearchService.swift`)
- Next.js SSE replaced with Swift `AsyncStream`
- SQLite+Drizzle replaced with SwiftData
- Zod schemas replaced with Swift `Codable`
- Node.js EventEmitter replaced with message bus

**UI in home window:**

```
+------------------------------------------+
|  Learning Pool                           |
|                                          |
|  [Search anything...              ]     |
|                                          |
|  Mode: * Speed  o Balanced  o Quality   |
|  Sources: [x] Web  [x] Academic  [x] Notes |
|                                          |
|  +------------------------------------+  |
|  |  Recent Searches                   |  |
|  |                                    |  |
|  |  "CRISPR delivery mechanisms"      |  |
|  |     3 web + 5 academic sources    |  |
|  |     12 min ago                    |  |
|  +------------------------------------+  |
|                                          |
|  [Upload Document]  for RAG search       |
+------------------------------------------+
```

---

## 9. Graph NPCs & Agent Visualization

### NPC Node Types (new, added to Rust graph-engine)

Existing node types: Note(0), Chat(1), Idea(2), Source(3), Folder(4), Quote(5), Tag(6), Block(7).

| New Node Type | ID | Purpose |
|---|---|---|
| `Agent` | 8 | The NPC itself |
| `CodeFile` | 9 | Source code files created by Builder |
| `CodeFolder` | 10 | Project directories |
| `Draft` | 11 | Writing drafts created by Writer |
| `SearchResult` | 12 | Learning Pool results cached in graph |

New edge types:

| New Edge Type | Meaning |
|---|---|
| `agentWorkedOn` | Agent -> Node it modified/created |
| `agentAttachedTo` | Agent -> Node it's currently working on (animated) |
| `bridgedTo` | Main graph node -> Agent territory node (portal) |
| `derivedFrom` | Agent-created node -> source note/query that inspired it |

### NPC Visual Design

Tiny stylized robot avatars (~20px), color-coded per agent:

- **Librarian** — blue glow
- **Writer** — green glow
- **Builder** — orange glow
- **Triage** — white glow (~16px, smaller)

**Animation states:**
- **Idle:** gentle bobbing (sinusoidal Y offset, 2s period)
- **Working:** glow pulses, small particle trail as it moves
- **Attached:** orbits the node it's working on (circular path, 3s period)
- **Moving:** smooth interpolation between nodes (ease-in-out, 500ms)

**Rust implementation:**

```rust
pub struct AgentNPCState {
    pub agent_id: u8,              // 0=Triage, 1=Librarian, 2=Writer, 3=Builder
    pub position: [f32; 3],        // Current world position
    pub target_node: Option<u64>,  // Node ID it's moving toward / attached to
    pub state: NPCAnimState,       // Idle, Working, Attached, Moving
    pub glow_color: [f32; 4],      // RGBA
    pub glow_intensity: f32,       // 0.0-1.0, pulses when working
    pub trail_points: Vec<[f32; 3]>, // Recent positions for particle trail
}

pub enum NPCAnimState {
    Idle,
    Moving(f32),    // progress 0-1
    Attached(f32),  // angle in radians
    Working(f32),   // pulse phase
}
```

### Agent Territory (Separate Gravity Cluster)

```
MAIN KNOWLEDGE GRAPH                    AGENT TERRITORY
(your notes, sources, ideas)            (agent work products)

    o---o---o                              []-[]
    |   |   |                              |   |
    o---o---o                              []--[]--[]
        |                                      |
        |         .....BRIDGE.....             |
        o---------. portal node  .-------------[]
                  ...............
```

**Physics separation:**
- Main graph has own force simulation (existing)
- Agent territory has own force simulation (new instance)
- Two simulations run independently
- Bridge is special edge with very weak spring force
- Agent territory has tighter gravity, weaker repulsion (compact workspace)

**Portal interaction:**
- Click portal -> smooth camera transition into agent territory
- Main graph fades to 20% opacity
- Click "Back to Graph" or portal -> zoom back
- Portal shows activity indicator when agents working

**Territory zones (per agent):**

```
AGENT TERRITORY
|
+-- LIBRARIAN ZONE (blue tint)
|   +-- Tagged note clusters
|   +-- Connection maps
|   +-- Insight nodes
|
+-- WRITER ZONE (green tint)
|   +-- Draft nodes
|   +-- Citation edges -> Source nodes in main graph
|   +-- Version history edges between drafts
|
+-- BUILDER ZONE (orange tint)
    +-- Project folder nodes
    +-- Code file nodes
    +-- Build result nodes
    +-- Dependency edges between files
```

### Agent Section in Notes Sidebar

```
+-------------------------+
|  NOTES SIDEBAR          |
|                         |
|  > Research             |
|    main.swift           |
|    util.swift           |
|  > Journal              |
|    2026-03-07           |
|                         |
|  v AGENTS               |
|    v [bot] Librarian    |
|      > Tag Reports      |
|      > Connection Maps  |
|    v [bot] Writer       |
|      > Drafts           |
|        Methods v2       |
|        Abstract v1      |
|    v [bot] Builder      |
|      > parser-project   |
|        main.swift       |
|        ast.swift        |
+-------------------------+
```

- Collapsible "AGENTS" section in existing `NotesSidebar`
- Each agent has sub-section with folder tree
- Files are real files on disk (agent workspace folder)
- Browsable and editable outside agent mode

**NPC behavior rules:**

| Event | NPC Action |
|---|---|
| Agent receives task | NPC moves from territory to target node |
| Agent reads a note | NPC attaches, glow dims (reading) |
| Agent writes/modifies | NPC attaches, glow brightens + pulses (working) |
| Agent creates file/note | New node appears in territory, NPC moves there |
| Agent @mentions another | NPC briefly moves toward mentioned agent's zone |
| Agent completes task | NPC returns to home zone, celebration animation |
| Agent idle | NPC bobs gently in home zone |
| Agent proactive insight | NPC moves to relevant node, particle burst |

---

## 10. Voice System (Chatterbox TTS)

### Architecture

```
Swift App
   |
   |  spawn once on app launch (when voice enabled)
   v
Python Daemon (persistent subprocess)
   |  Chatterbox Turbo model loaded in MPS (GPU)
   |  ~2-3 GB VRAM, stays resident
   |
   |  stdin/stdout JSON protocol:
   |  -> {"text": "...", "agent": "librarian", "ref_audio": "...", "output": "/tmp/out.wav"}
   |  <- {"status": "ok", "duration_ms": 450}
   |
Swift receives WAV -> AVAudioEngine -> plays through speakers
```

**Model:** Chatterbox Turbo (350M params). Latency ~300-900ms per sentence. Supports paralinguistic tags: `[laugh]`, `[sigh]`, `[cough]`, `[gasp]`, `[chuckle]`, etc.

**Reference implementation:** `chatterbox-master/src/chatterbox/tts_turbo.py`

### Per-Agent Voices

| Agent | Default Voice Character | Cloneable |
|---|---|---|
| Triage | Neutral, quick, receptionist | Yes (5s sample) |
| Librarian | Calm, measured, professorial | Yes (5s sample) |
| Writer | Articulate, warm, editorial | Yes (5s sample) |
| Builder | Direct, technical, efficient | Yes (5s sample) |

Users can record a 5-15 second voice sample to clone any voice for any agent.

### Voice Integration Points

| Feature | How |
|---|---|
| Agent notifications | Agent completes task -> TTS speaks summary |
| Read Mode (Notes) | Toggle on note -> reads full text. Progress bar. Pause/resume. |
| Read Mode (Papers) | Same toggle for research papers |
| Read Mode (Chat) | Toggle on chat -> assistant messages spoken as they complete |
| Graph node summary | Select node -> inspector summary -> toggle "always read" -> spoken |
| Agent updates | "I found 3 notes that contradict your CRISPR hypothesis." |
| Proactive alerts | Subtle chime + spoken insight |

### Voice Settings

```
+-------------------------------------+
|  Voice Settings                     |
|                                     |
|  Master Toggle:  [* On]             |
|                                     |
|  Agent Voices:                      |
|  Librarian  [Default v] [Record]   |
|  Writer     [Default v] [Record]   |
|  Builder    [Default v] [Record]   |
|                                     |
|  Read Mode:                         |
|  [x] Notes    [x] Chat    [ ] Always|
|  [x] Graph Summaries                |
|                                     |
|  Speed: [====*====] 1.0x           |
|  Volume: [======*==] 80%           |
+-------------------------------------+
```

---

## 11. Trust Levels & Permissions

Three tiers, configured per agent in Agent Panel settings.

| Level | Can Do | Can't Do |
|---|---|---|
| **Sandbox** | Read own folder only | Write, delete, shell, anything outside folder |
| **Standard** | Read/write own folder + whitelisted commands (`swift`, `cargo`, `npm`, `git`) | Delete outside folder, arbitrary shell, system actions |
| **Elevated** (Pro only) | Full file system, arbitrary shell, AppleScript | Nothing blocked |

**Enforcement in Rust `tool-sandbox` crate:**

```rust
pub enum TrustLevel {
    Sandbox,
    Standard,
    Elevated,
}

pub struct ToolPermission {
    pub trust_level: TrustLevel,
    pub agent_workspace: PathBuf,
    pub whitelisted_commands: Vec<String>,
}

pub fn validate_tool_call(
    call: &ToolCall,
    permission: &ToolPermission,
) -> Result<(), ToolDenied> {
    match call {
        ToolCall::FileRead(path) => validate_path_access(path, permission),
        ToolCall::FileWrite(path, _) => validate_write_access(path, permission),
        ToolCall::FileDelete(path) => validate_delete_access(path, permission),
        ToolCall::ShellExec(cmd, _) => validate_shell_access(cmd, permission),
        ToolCall::SystemAction(_) => validate_system_access(permission),
        _ => Ok(()),
    }
}
```

Trust validation happens in Rust, not Swift. The Rust layer is the enforcement boundary — even a bug in Swift can't bypass permissions.

**Semi-autonomous approval dialog:**

```
+----------------------------------------+
|  [bot] Builder wants to:              |
|                                        |
|  Run command: swift build              |
|  In: ~/Epistemos-Projects/parser/     |
|                                        |
|  [Allow]  [Allow All This Session]     |
|  [Deny]   [Configure Trust ->]         |
+----------------------------------------+
```

"Allow All This Session" — bulk-approve for current task, resets next session.

---

## 12. Notifications

Three channels:

| Channel | When | Example |
|---|---|---|
| macOS notification | Task complete, error, needs approval | "Builder: Build succeeded. 3 files created." |
| In-app badge | Proactive insight, connection found | Blue dot on agent's sidebar section |
| Voice (Chatterbox) | When voice enabled + notification fires | Librarian speaks the update |

Per-agent notification settings with "Require approval for" sub-toggles for semi-autonomous trust.

---

## 13. Distribution

### App Store Lite vs Direct Download Pro

Two builds from same codebase, feature-gated at compile time (`#if EPISTEMOS_PRO`).

| Feature | Lite (App Store, Free) | Pro (Direct, Paid) |
|---|---|---|
| MLX local inference | YES | YES |
| Apple Intelligence | YES | YES |
| Cloud APIs | YES | YES |
| All 4 agents | YES | YES |
| Agent Panel + Dashboard | YES | YES |
| Agent communication | YES | YES |
| Learning Pool | YES | YES |
| Graph NPCs | YES | YES |
| Three-tier memory | YES | YES |
| TTS (Chatterbox) | YES | YES |
| Voice cloning | YES | YES |
| Builder file ops (sandbox) | YES | YES |
| Builder file ops (any folder) | NO | YES |
| Shell/terminal execution | NO | YES |
| Elevated trust level | NO | YES |
| Ollama integration | NO | YES |
| System actions (AppleScript) | NO | YES |

**Lite is a real product, not a crippled trial.**

**Apple rule 3.1.1:** Cannot prompt users in App Store app to buy/download externally. Settings can say "Some Builder features require Epistemos Pro" but cannot link to purchase.

---

## 14. Swift/Rust Split

| Component | Language | Why |
|---|---|---|
| Agent Engine (lifecycle, bus, orchestration) | **Swift** | Needs @MainActor, @Observable, direct SwiftUI binding |
| Model Providers (MLX, LLMService, Apple AI) | **Swift** | MLX-Swift and Apple Intelligence are Swift-native |
| UI (agent panel, dashboard, editor, chat) | **Swift** | SwiftUI/AppKit |
| Learning Pool (search pipeline, RAG, embeddings) | **Rust** | CPU-bound data processing. Same work as graph engine. |
| Tool Execution (file ops, shell, sandboxing) | **Rust** | Type system enforces safety at compile time |
| Memory Engine (embedding storage, vector search) | **Rust** | Vector math, cosine similarity, memory-mapped storage |
| Graph NPCs (agent visualization, animation) | **Rust** | Already rendering graph in Metal via Rust |

### Rust Crate Structure

```
rust/
+-- graph-engine/          # EXISTING -- nodes, edges, physics, Metal
+-- learning-pool/         # NEW -- Perplexica port (search, RAG, widgets)
+-- memory-engine/         # NEW -- embeddings, vector search, compaction
+-- tool-sandbox/          # NEW -- file ops, shell exec, permission enforcement
+-- agent-bridge/          # NEW -- FFI header unifying all crates
```

FFI boundary: Swift sends commands ("search for X", "embed this text", "execute this tool with these permissions"), Rust does computation and returns results.

---

## 15. Source Repo Reference Map

Every component traces back to a studied repo. **These repos contain the reference implementations to port from.**

### MLXChat (`/Users/jojo/mlxchat-main/`)

| Component | File | What to Port |
|---|---|---|
| MLX model loading, GPU memory, streaming | `MLXChat/Engine/MLXEngine.swift` | `MLXEngine` actor, `loadModel()`, `generateChat()`, GPU memory management |
| Qwen tool call parsing (XML format) | `MLXChat/Engine/MLXEngine.swift:377-455` | `parseToolCall()`, `parseXMLParameters()`, `makeToolCall()` |
| Chat template patching (Qwen 3.5 4B bug) | `MLXChat/Engine/MLXEngine.swift:315-361` | `correctedChatTemplateIfNeeded()`, `patchQwen35_4BNonThinkingTemplate()` |
| Repetition detection + trimming | `MLXChat/Engine/MLXEngine.swift:490-569` | `hasRepetition()`, `trimRepetition()` |
| Think tag stripping | `MLXChat/Engine/MLXEngine.swift:571-602` | `stripThinkingTags()` |
| Model registry (Qwen variants) | `MLXChat/Models/ModelRegistry.swift` | `ModelSpec`, `ModelRegistry` |
| Brave Search API | `MLXChat/Tools/BraveSearchService.swift` | `BraveSearchService.search()` |
| URL fetching + HTML stripping | `MLXChat/Tools/WebFetchService.swift` | `WebFetchService.fetch()`, `stripHTML()` |
| Tool schema definitions (MCP-compatible) | `MLXChat/Tools/ToolDefinitions.swift` | `ToolRegistry`, `ToolSpec` format, `JSONValue` helpers |
| Settings/config patterns | `MLXChat/ViewModels/SettingsManager.swift` | UserDefaults persistence, GPU memory options |

### Perplexica (`/Users/jojo/Perplexica-master/`)

| Component | File | What to Port |
|---|---|---|
| Search pipeline orchestrator | `src/lib/agents/search/index.ts` | `SearchAgent` class: classify -> research -> write |
| Query classification (structured) | `src/lib/agents/search/classifier.ts` | Zod schema -> Swift Codable. Classification logic. |
| ReACT researcher loop | `src/lib/agents/search/researcher/index.ts` | Tool-calling loop with iteration limits |
| Web search action | `src/lib/agents/search/researcher/actions/webSearch.ts` | SearXNG -> Brave Search adaptation |
| Academic search action | `src/lib/agents/search/researcher/actions/academicSearch.ts` | Academic engine search |
| Social/discussion search | `src/lib/agents/search/researcher/actions/socialSearch.ts` | Forum/Reddit search |
| URL scraping action | `src/lib/agents/search/researcher/actions/scrapeUrl.ts` | Fetch + parse web pages |
| Upload search (RAG) | `src/lib/agents/search/researcher/actions/uploadsSearch.ts` | Vector search over user docs |
| Weather widget | `src/lib/agents/search/widgets/weather.ts` | Open-Meteo API integration |
| Stock widget | `src/lib/agents/search/widgets/stock.ts` | Yahoo Finance integration |
| Calculation widget | `src/lib/agents/search/widgets/calc.ts` | Math expression evaluation |
| LLM provider abstraction | `src/lib/models/base/llm.ts` | `BaseLLM` interface pattern |
| Embedding abstraction | `src/lib/models/base/embedding.ts` | `BaseEmbedding` interface pattern |
| File upload + chunking | `src/lib/uploads/manager.ts` | PDF parse, chunk, embed, store |
| Session/block streaming | `src/lib/session.ts` | EventEmitter -> Swift AsyncStream |
| DB schema (chats, messages) | `src/lib/db/schema.ts` | SQLite -> SwiftData adaptation |
| Prompts (classifier, researcher, writer) | `src/lib/prompts/search/` | System prompts for each pipeline stage |

### CoPaw (`/Users/jojo/CoPaw-main/`)

| Component | File | What to Port |
|---|---|---|
| ReACT agent loop | `src/copaw/agents/react_agent.py` | Reasoning -> Act -> Observe cycle, max_iters=50 |
| Memory compaction | `src/copaw/agents/memory/` | Summarize when context 70% full, compaction ratio |
| Skill-as-directory pattern | `src/copaw/agents/skills_manager.py` | Modular capabilities loaded from filesystem |
| Hot-reload config | `src/copaw/config/` | Watch config changes, rebuild agent without restart |
| Hook system (pre/post reasoning) | `src/copaw/agents/react_agent.py` | Bootstrap hook, memory compaction hook |
| Session isolation | `src/copaw/app/runner/session.py` | Per-user, per-context JSON session files |
| Model provider factory | `src/copaw/agents/model_factory.py` | Create model + formatter by provider type |
| Command handler | `src/copaw/agents/command_handler.py` | /compact, /new, /clear, /history commands |
| Built-in tools (shell, file, browser) | `src/copaw/agents/tools/` | Tool implementations with sandboxing |
| Cron/scheduled tasks | `src/copaw/app/crons/` | Background job scheduling for agents |

### OpenClaw (`/Users/jojo/openclaw-main/`)

| Component | File | What to Port |
|---|---|---|
| Tool profiles (safety tiers) | `src/agents/tool-catalog.ts` | Curated tool sets: minimal, coding, messaging, full |
| Session-based agent routing | `src/routing/` | Map context -> agent deterministically |
| Sub-agent spawning | Sessions spawn tool | Agent A delegates to Agent B |
| Config-as-source-of-truth | Config schema | All agent/tool/channel config in one place |
| Process isolation model | ACP protocol | Crash containment (we use Swift actors instead) |
| Plugin slot architecture | `src/plugin-sdk/` | Memory plugin, context engine plugin |
| Permission model | `dangerous-tools.ts` | Explicit dangerous ops list, pre-validation |
| Bidirectional agent-gateway RPC | `src/acp/` | Gateway validates then executes tools |
| Tool dispatch + validation | Tool execution pipeline | Validate permissions before every tool call |
| Session management + TTL | Session lifecycle | 30-min session timeout, state persistence |
| Auth profiles + failover | `src/agents/auth-profiles/` | Model selection with automatic failover on rate limit |

### Chatterbox (`/Users/jojo/chatterbox-master/`)

| Component | File | What to Port |
|---|---|---|
| TTS Turbo API | `src/chatterbox/tts_turbo.py` | `ChatterboxTurboTTS.from_pretrained()`, `.generate()` |
| Multilingual TTS | `src/chatterbox/mtl_tts.py` | 23+ language support |
| Voice conversion | `src/chatterbox/vc.py` | Change speaker of existing audio |
| macOS example | `example_for_mac.py` | MPS device usage on Apple Silicon |
| Paralinguistic tags | Model vocabulary | `[laugh]`, `[sigh]`, `[cough]`, `[gasp]`, `[chuckle]`, etc. |
| Audio output format | torchaudio save | 24kHz mono WAV, -27 LUFS normalized |
| Python daemon pattern | (design, not in repo) | stdin/stdout JSON protocol for Swift IPC |

---

## 16. Competitive Analysis

### Frameworks Studied

| Framework | Strength | Weakness | What We Steal |
|---|---|---|---|
| **Claude Code / Agent SDK** | TeammateTool (multi-agent), inbox messaging, git worktree isolation, MCP tools | 7x token cost, cloud-only | Inbox messaging, transparency pattern, todo rewriting |
| **OpenAI Agents SDK** | Minimal (agents-as-tools), native language primitives, AgentKit canvas | No local inference support | Simplicity, agents-as-tools pattern |
| **LangGraph** | Graph-based workflows, precise control, DAG execution | Complex, Python-only | Reducer logic for concurrent state, error recovery |
| **CrewAI** | Role-based teams, natural delegation | Struggles with dynamic adaptation | Role/personality framing |
| **Manus** | Context engineering (todo rewriting), multi-agent internal | Cloud VMs, closed source | Todo list rewriting, continuous replanning |
| **CoPaw** | Skill system, memory compaction, hot-reload, channel abstraction | Single-agent only (multi planned) | Skill directories, 70% compaction, hooks |
| **OpenClaw** | Process isolation, tool profiles, ACP protocol, plugin slots | TypeScript, no local inference | Tool profiles, session routing, config-driven |
| **Qwen-Agent** | Built for Qwen models, function calling, code interpreter | Python, no multi-agent orchestration | Qwen-specific tool call format |
| **SwiftAgent** | Swift-native, MCP, MLX inference | Early-stage, single-agent only | Proof that Swift+MLX+MCP is viable |

### The Gap We Fill

**No native macOS/Swift agent framework exists.** Every competitor is Python or TypeScript, cloud-first.

Our unique advantages:
1. **MLX-first local inference** — direct Metal GPU, no server process
2. **Graph NPC visualization** — no other framework has visual agent observability like this
3. **Chatterbox voice** — agents with distinct voices, local TTS
4. **Rust-enforced trust** — permissions enforced at compile time, not runtime
5. **Apple Silicon optimized** — unified memory model, MPS for TTS, Metal for graph
6. **Memory-pressure-aware** — graceful model switching based on available RAM
7. **Integrated knowledge graph** — agents don't just process text, they navigate a visual knowledge space

### Industry Insights (2026)

- "Professional developers don't vibe, they control." — transparency over autonomy
- Coordination tax: accuracy saturates beyond 4 agents. Structured topology required.
- Context engineering is the bottleneck, not model quality
- MCP has won as the tool protocol standard
- Three-tier memory (working/episodic/semantic) is consensus architecture
- Progressive tool disclosure: don't flood context with all tool descriptions
- Only 11% of orgs had deployed agentic AI by mid-2025. 40% of projects will be cancelled by 2027. The bar is low — shipping something that works is the differentiator.

---

## 17. Implementation Phases

Suggested phasing (exact plan to be created separately):

### Phase 1: Foundation
- Add MLX dependencies to Epistemos Xcode project
- Implement `MLXProvider` conforming to `LLMClientProtocol`
- Port `MLXEngine` actor from MLXChat
- Basic model loading, generation, streaming
- Test with Qwen 3.5 0.8B

### Phase 2: Agent Engine Core
- `AgentEngine` actor (lifecycle management)
- `MessageBus` actor (typed message routing)
- Agent protocol + base implementation
- Triage classifier (few-shot intent classification)
- Agent Panel UI (dashboard with status cards)

### Phase 3: Librarian Agent
- Note indexing via Rust `memory-engine` crate
- Embedding generation (local model)
- Semantic search (cosine + BM25 hybrid)
- Passive monitoring (background scanning)
- Proactive signal UI (badges, dots)

### Phase 4: Writer Agent
- Preset system (SwiftData storage)
- Configurable system prompt generation
- Chain-of-thought instruction parsing
- Integration with existing per-note chat
- Agent-to-agent mention (Librarian for citations)

### Phase 5: Builder Agent
- Syntax-highlighted code editor (NSTextView variant)
- File tree view (scoped to workspace)
- Terminal pane (Process + pipes)
- Claude Code agent loop (generate -> tool -> validate -> execute -> repeat)
- Trust level enforcement (Rust `tool-sandbox` crate)
- Activity log

### Phase 6: Learning Pool
- Port Perplexica classifier to Swift
- Port researcher ReACT loop
- Brave Search integration (reuse MLXChat code)
- RAG pipeline (Rust: chunk, embed, store, search)
- Widget system (weather, stocks, calc)
- Learning Pool UI in home window

### Phase 7: Graph NPCs
- New node/edge types in Rust graph-engine
- `AgentNPCState` struct + animation system
- NPC Metal shader (robot sprite + glow + trail)
- Separate physics simulation for agent territory
- Bridge/portal rendering + camera transition
- Zone background tinting
- Agent section in Notes sidebar

### Phase 8: Voice System
- Bundle Python + Chatterbox Turbo
- Persistent daemon subprocess (stdin/stdout JSON)
- Swift wrapper (`ChatterboxTTSEngine`)
- AVAudioEngine playback pipeline
- Per-agent voice config + voice cloning UI
- Read Mode toggles (notes, chat, graph)

### Phase 9: Memory System
- Tier 1: Working memory with compaction (70% threshold)
- Tier 2: Episodic memory (SwiftData `SDAgentThread`)
- Tier 3: Semantic memory (Rust `memory-engine` vector index)
- Todo rewriting (Manus pattern)
- Cross-tier retrieval pipeline

### Phase 10: Polish & Distribution
- App Store Lite build configuration
- Pro build configuration (#if EPISTEMOS_PRO)
- Notification system (macOS + in-app + voice)
- Trust settings UI
- Voice settings UI
- Performance tuning (model swap latency, memory pressure)
- Testing across M1/M2/M3/M4

---

## Appendix: External Dependencies to Add

### Swift Package Manager
```
mlx-swift-lm        https://github.com/ml-explore/mlx-swift-lm          branch: main
swift-transformers   https://github.com/huggingface/swift-transformers    from: 1.1.9
```

### Rust Cargo (new crates in workspace)
```
learning-pool/Cargo.toml    (reqwest, serde, serde_json, tiktoken-rs)
memory-engine/Cargo.toml    (ndarray, serde, memmap2)
tool-sandbox/Cargo.toml     (nix for shell exec, serde)
agent-bridge/Cargo.toml     (cbindgen for FFI header generation)
```

### Python (bundled for TTS)
```
chatterbox-tts    (PyTorch 2.6, torchaudio, transformers, diffusers)
```

### Models (downloaded on first use)
```
mlx-community/Qwen3.5-0.8B-MLX-4bit   (~700MB, always-on triage)
mlx-community/Qwen3.5-2B-MLX-4bit     (~1.8GB, Librarian)
mlx-community/Qwen3.5-4B-MLX-4bit     (~2.8GB, Writer/Builder)
ResembleAI/chatterbox-turbo            (~1.5GB, TTS)
```
