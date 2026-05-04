# Epistemos v5 Vision: Complete Architecture

> **Index status**: DEFERRED-RESEARCH — Vision/embedded-graph deferred; W9.24 graph embedding spec.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/superpowers/`.



**Date:** 2026-03-10 (fused from 2026-03-07 agent system design + 2026-03-10 Craft vision)
**Status:** Approved Design — ready for implementation planning
**Scope:** Block-based editor, multi-agent system with MLX local inference, Learning Pool, Graph NPCs, TTS, App Store + Pro distribution

---

## Table of Contents

1. [Vision & Summary](#1-vision--summary)
2. [Decision Record](#2-decision-record)
3. [Block-Based Editor Foundation](#3-block-based-editor-foundation)
4. [AI Model & Triage (4-Tier)](#4-ai-model--triage-4-tier)
5. [The Four Agents](#5-the-four-agents)
6. [Agentic UI/UX](#6-agentic-uiux)
7. [Agent Communication (Message Bus)](#7-agent-communication-message-bus)
8. [Memory System (Three-Tier)](#8-memory-system-three-tier)
9. [Learning Pool (Perplexica Port)](#9-learning-pool-perplexica-port)
10. [Graph NPCs & Agent Visualization](#10-graph-npcs--agent-visualization)
11. [Voice System (Chatterbox TTS)](#11-voice-system-chatterbox-tts)
12. [Trust Levels & Permissions](#12-trust-levels--permissions)
13. [Notifications](#13-notifications)
14. [Distribution (Lite vs Pro)](#14-distribution-lite-vs-pro)
15. [Swift/Rust Split](#15-swiftrust-split)
16. [Rich AI Output & Skills](#16-rich-ai-output--skills)
17. [Integration Layer & Data Flow](#17-integration-layer--data-flow)
18. [Source Repo Reference Map](#18-source-repo-reference-map)
19. [Competitive Analysis](#19-competitive-analysis)
20. [Implementation Phases](#20-implementation-phases)

---

## 1. Vision & Summary

Epistemos becomes a **multi-agent knowledge workstation** where specialized AI agents — each with their own personality, voice, memory, and workspace — collaborate to help the user manage notes, write research, and build software. Agents are visible as animated NPCs in the knowledge graph, with their own territory and gravity cluster.

The architecture has three layers built on a shared foundation:

1. **Block-Based Editor** — NSCollectionView replacing monolithic NSTextView, per-block TextKit 2, prose-feel default
2. **AI Model & Triage Expansion** — 4-tier routing with embedded MLX inference (Qwen), Ollama as advanced local tier, expanded cloud providers
3. **Multi-Agent System** — 4 specialized agents, floating glass assistant panel, autonomous agent loop with tool calling, persistent sessions, permission modes, rich output

The block model is the architectural spine — AI responses are blocks, agent operations target blocks, and the permission system controls block access.

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
- Block-based editor with per-block TextKit 2 and prose-feel default

---

## 2. Decision Record

Every design question asked and the user's exact answer:

| # | Question | Answer |
|---|---|---|
| 1 | Agent territory model (A: own tab/window, B: data sandbox, C: shared data + different personality) | **C with elements of A** — shared data, different personalities, but each agent has its own things |
| 3 | IDE level for Builder (A: viewer, B: editor+terminal, C: full IDE) | **B+ (editor + terminal + file tree, not full IDE)** |
| 4 | Notes Agent awareness (A: passive, B: active monitor, C: both) | **C** — passive search + subtle proactive signals without being annoying |
| 5 | Agent communication (A: manual handoff, B: @mention, C: shared clipboard) | **All, with ambient awareness** — agents listen and reach out intelligently |
| 6 | Writing Agent scope (A: academic, B: broad professional, C: configurable) | **All, configurable with presets as primary UX** |
| 8 | Model loading/memory (A: one at a time, B: small always loaded, C: auto budget) | **B, tiered with small model always resident** |
| 9 | Coding file territory (A: single folder, B: user-configured, C: both) | **C** — defaults to projects folder, can point at any directory |
| 10 | Autonomy level (A: full auto, B: semi-auto, C: configurable) | **C, configurable trust per agent, Claude Code agent loop pattern** |
| 11 | Triage intelligence (A: rule-based, B: model-driven, C: hybrid) | **B** — model-driven, small Qwen reasons about routing |
| 12 | Agent panel location (A: new tab, B: sidebar, C: in settings, D: floating) | **B** — sidebar in main home window |
| 13 | Deep computer use scope (A: file system, B: shell, C: system-level, D: all gated) | **D** — all of the above, gated by trust level per agent |
| 14 | Triage visibility (A: invisible, B: default chat, C: both modes) | **C** — it's the default chat (receptionist), routing decisions visible, reasoning hidden unless debug view toggled |
| 15 | Chat architecture (Option 1: toggle, 2: separate, 3: main chat + agent panel) | **Option 3** — main chat with agent awareness, agent work happens in agent panel |
| 16 | Agent panel primary view (A: dashboard, B: chat-first, C: split) | **A** — agent status dashboard with cards, tap card to open thread |
| 17 | Trust levels (A: binary, B: three tiers, C: granular toggles) | **B** — three tiers: Sandbox, Standard, Elevated |
| 18 | Real-time visibility (A: log, B: live feed, C: both + notifications) | **C** — live feed while working, persisted as reviewable log after, plus notifications |
| 19 | Agents in graph (A: no, B: as nodes, C: only work products) | **Yes, as animated NPC robots** with separate gravity cluster |
| 20 | NPC visual style (A: abstract geometric, B: robot avatar, C: aura/field) | **B** — tiny stylized robots with distinct silhouettes |
| 21 | Agent cluster relationship (A: tethered, B: bridged portal, C: orbital) | **B** — bridged with portal/wormhole visual |
| 22 | V1 scope | **ALL features** (triage, all 3 agents, agent panel, inter-agent communication, trust levels, graph NPCs, agent gravity cluster, notifications, MLX integration) |
| 23 | Learning Pool | Port Perplexica's full search pipeline to Swift+Rust as "Agent Knowledge Base" |
| — | Rust vs Swift | Swift for agents/UI/MLX, Rust for data processing/memory/tools/graph |
| — | Distribution | App Store Lite (free, sandboxed) + Direct Download Pro (paid, full power) |
| 31 | TTS Engine | Chatterbox Turbo via persistent Python daemon subprocess |
| 32 | Agent voices | Each agent gets a distinct default voice. User can clone custom voices with 5-15s audio sample. |
| 33 | Read Mode | Toggle per surface: notes, chat, graph summaries. Agents speak notifications and updates. |

---

## 3. Block-Based Editor Foundation

### Design Decision

Replace the monolithic NSTextView (ProseEditorRepresentable + MarkdownTextStorage + ClickableTextView) with a block-based NSCollectionView where each paragraph, heading, code block, image, etc. is an independent cell. One editor, two visual modes: **Prose** (blocks flow edge-to-edge, no visible boundaries) and **Structured** (block handles visible, drag-to-reorder, slash menu for inserting rich blocks).

### Document Model

**Current:**
```
SDPage {
    body: String          // raw markdown (entire document)
    needsVaultSync: Bool
}
```

**Proposed:**
```
SDPage {
    blocks: [SDBlock]     // ordered list via @Relationship
    needsVaultSync: Bool
}

SDBlock {
    id: UUID
    page: SDPage                  // @Relationship inverse
    parentBlockId: String?        // flat parent-child (existing pattern, SwiftData-safe)
    order: Int                    // position within parent
    type: BlockType               // .paragraph, .heading(level), .code(language),
                                  // .image, .table, .mermaid, .aiResponse,
                                  // .divider, .quote, .list, .checkbox,
                                  // .callout, .embed
    content: String               // markdown content for text blocks
    metadata: [String: String]    // block-level properties (@key=value)
    depth: Int                    // nesting level
    isCollapsed: Bool             // fold state

    // Computed (not stored):
    var children: [SDBlock]       // filtered by parentBlockId from page.blocks
}
```

**Migration from existing SDBlock:** The current `SDBlock` entity already exists with `pageId`, `parentBlockId`, `order`, `depth`, `isCollapsed`, and `sourceStartUTF16/sourceEndUTF16`. The migration adds `type: BlockType` (new), `metadata: [String: String]` (new), and `content: String` (replaces source range pointers). The `sourceStartUTF16/sourceEndUTF16` fields drop since blocks own their content directly. SwiftData lightweight migration handles field additions; the source-range-to-content conversion requires a one-time migration pass on first launch.

### Markdown Round-Trip

The vault still stores `.md` files. The block model is an in-memory representation only:

- **Load:** Markdown parser splits file into blocks by type (headings, paragraphs, code fences, etc.)
- **Save:** Block serializer emits valid markdown from the block tree
- **Compatibility:** Vault stays Obsidian-readable. No proprietary format.

`SDPage.body` becomes a computed property that serializes blocks on read.

### Rendering Pipeline

```
SDPage.blocks
  → DiffableDataSource (animated insert/delete/move, only diffs what changed)
    → NSCollectionView (cell reuse, only visible blocks in memory)
      ├─ ParagraphCell → mini NSTextView with TextKit 2
      ├─ HeadingCell → styled NSTextView (larger font, weight)
      ├─ CodeBlockCell → syntax-highlighted NSTextView
      ├─ ImageCell → async NSImageView + caption
      ├─ MermaidCell → SVG rendered from mermaid source
      ├─ AIResponseCell → streaming content + accept/discard controls
      ├─ TableCell → NSGridView or custom renderer
      ├─ EmbedCell → transclusion (block ref / page embed)
      └─ DividerCell → horizontal rule
```

**Key benefits:**
- Per-block TextKit 2 eliminates height estimation bugs and scrollbar juggery
- Cell reuse: constant memory regardless of document length
- Heterogeneous content is native (code, diagrams, images are first-class block types)
- DiffableDataSource gives animated block reordering for free

### Prose Feel

In default "Prose" mode:
- Blocks render edge-to-edge with no visible separators or handles
- Keyboard navigation flows seamlessly between cells (↓ at end of paragraph → start of next)
- Return splits a paragraph block at cursor position
- Backspace at start of paragraph merges with previous block
- Text selection spans across multiple cells with custom gesture handling
- Block handles appear only on hover over left margin

"Structured" mode reveals block handles, enables drag-to-reorder, and shows the slash command insert menu between blocks.

**Known complexity — cross-cell text selection:** Selecting text across multiple collection view cells is the single hardest problem in block-based editors. The approach: implement a custom `NSTextInputClient` on the collection view that coordinates selection state across cells, tracking a `SelectionRange(startBlock, startOffset, endBlock, endOffset)`. This is a multi-month engineering challenge and the primary risk.

**Mermaid rendering:** Mermaid source blocks render to SVG via an embedded hidden `WKWebView` running mermaid.js. The SVG output is captured and displayed as an `NSImage` in the `MermaidCell`. The WebView is shared (singleton) and renders asynchronously.

### Component Migration

| Current Component | Replacement |
|---|---|
| `ProseEditorRepresentable` (800-line Coordinator) | `BlockEditorView` + `DocumentCoordinator` + per-cell coordinators |
| `MarkdownTextStorage` | Per-block TextKit 2 styling within each cell |
| `ClickableTextView` | Each text cell's mini NSTextView; wikilink handling in cell delegate |
| `PageStoragePool` (LRU 12) | SDBlock persistence (blocks are SwiftData entities) |
| Fold system (storage rewrite) | `SDBlock.collapsed` hides children |
| Block refs / transclusion | `EmbedCell` block type |
| AI divider (`---`) | `AIResponseCell` block type |

### What Stays Unchanged

- `SDPage` as SwiftData entity (gains `blocks` relationship)
- Vault sync to `.md` files
- Graph engine (Rust FFI)
- All State classes (adapted but not rewritten)
- Theme system and view modifiers

---

## 4. AI Model & Triage (4-Tier)

### System Architecture

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

### Four-Tier Triage

```
Tier 1: Apple Intelligence    (free, instant, ~4K context)
  ↓ fallback
Tier 2: Qwen/Gemma via MLX Swift    (free, fast, on-device, primary local route)
  ↓ fallback
Tier 3: Ollama                (user-managed advanced local models)
  ↓ fallback
Tier 4: Cloud API             (most capable, costs money, needs internet)
```

### Embedded Local Inference (MLX Swift + Qwen/Gemma)

No external software required. MLX Swift runs Qwen and Gemma models directly in-process using Apple Silicon unified memory.

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
- Low memory mode on 8GB machines: defer to Tier 1 (Apple AI) + Tier 4 (Cloud) only

**User routing requirements locked 2026-03-12:**
- Apple on-device models stay first in the routing stack.
- Qwen is the primary MLX local family after Apple.
- Gemma is the secondary MLX local family and should ship as an available local fallback, not as an afterthought.
- Ollama remains optional. It is not the default local path.

**Model management UI:**
- First launch: pre-download the recommended small local set so the app already has a Qwen model and a Gemma model ready for offline routing
- Models stored in `~/Library/Application Support/Epistemos/Models/`
- Settings panel for downloading additional models, importing custom MLX models, viewing disk usage, and choosing which family handles triage versus general local fallback
- One model loaded at a time (swap unloads previous)

**Service architecture:**
```swift
actor MLXInferenceService {
    private var loadedModel: MLXModel?
    private let modelsDirectory: URL

    func generate(prompt: String, system: String, stream: Bool) -> AsyncStream<String>
    func availableModels() -> [LocalModelProfile]
    func downloadModel(_ spec: QwenModelSpec, progress: (Double) -> Void) async throws
    func deleteModel(_ name: String) throws
    func isModelLoaded() -> Bool
}
```

**MLX dependencies to add:**
```
mlx-swift-lm        https://github.com/ml-explore/mlx-swift-lm          branch: main
swift-transformers   https://github.com/huggingface/swift-transformers    from: 1.1.9
```

These pull in 7 transitive dependencies (mlx-swift, swift-jinja, yyjson, swift-numerics, swift-collections, swift-crypto, swift-asn1) — all internal plumbing.

**Key code to port from MLXChat (`mlxchat-main/MLXChat/Engine/MLXEngine.swift`):**
- `MLXEngine` actor — model loading, GPU memory management, streaming generation
- Tool call parsing — Qwen 3.5 XML function format (`parseToolCall` at line 377-455)
- Chat template patching — Qwen 3.5 4B has buggy Jinja template for `enable_thinking=false`
- Repetition detection and trimming
- Think tag stripping

**Integration with existing LLMService:**
- Add `MLXClient` conforming to `LLMClientProtocol`
- `generate()` and `stream()` methods delegate to `MLXEngine` actor
- Triage service upgraded: instead of keyword complexity scores, small Qwen classifies intent

**Provider architecture (extended from current):**
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

### Ollama Integration (Tier 3)

Ollama remains supported as an optional power-user feature. If triage detects Ollama running (`localhost:11434`), those models join the routing pool. For well-known model families (llama, deepseek, qwen, phi, mistral), triage has built-in capability profiles. For unknown models, parameter count serves as a heuristic.

```swift
enum LocalModelSource {
    case embedded(MLXModel)      // Qwen via MLX (Tier 2)
    case ollama(OllamaModel)     // External Ollama (Tier 3)
    case appleIntelligence       // FoundationModels (Tier 1)
}
```

### Cloud Providers (Tier 4)

| Provider | Default Model | Why |
|----------|---------------|-----|
| **OpenAI** (existing) | gpt-5.3 | General purpose |
| **OpenAI GPT-5 Nano** (new) | gpt-5-nano | 400K context, speed/cost optimized, batch operations |
| **Anthropic** (existing) | claude-sonnet-4-6 | Best JSON compliance, best for enrichment |
| **Google** (existing) | gemini-2.5-flash | 1M context, auto-selected for massive documents |
| **DeepSeek** (new) | deepseek-r1 | Strong reasoning, very cheap |
| **xAI Grok** (new) | grok-3 | Fast, good at code |
| **Kimi** (existing) | kimi-k2.5 | Alternative |

### Updated Routing Table

| Operation | Complexity | Tier 1 (Apple AI) | Tier 2 (Qwen/MLX) | Tier 3 (Ollama) | Tier 4 (Cloud) |
|-----------|-----------|--------------------|--------------------|-----------------|----------------|
| Grammar fix | 0.15 | **Primary** | Fallback | - | - |
| Summarize | 0.20 | Primary | **If >4K context** | - | Fallback |
| Rewrite | 0.25 | Primary | **If tone variant** | - | Fallback |
| Continue | 0.30 | - | **Primary (3B)** | If 3B struggles | Fallback |
| Ask (simple) | 0.35 | - | **Primary (3B)** | If reasoning needed | Fallback |
| Outline | 0.40 | - | If 7B available | If specialized model | **Primary** |
| Expand | 0.50 | - | If 7B available | If large model | **Primary** |
| Analyze | 0.60 | - | - | If 70B+ model | **Primary** |
| Learn (.learn) | 0.70 | - | - | - | **Primary (always)** |

### TriageDecision Expansion

Current `TriageDecision` is binary (`.appleIntelligence` | `.apiProvider`). Proposed:

```swift
enum TriageDecision {
    case appleIntelligence
    case mlxLocal(model: String)     // NEW: embedded Qwen via MLX
    case ollama(model: String)       // NEW: external Ollama server
    case cloud(provider: LLMProviderType)  // renamed from .apiProvider
}
```

`TriageService` gains a reference to `MLXInferenceService` alongside the existing `LLMService`. The fallback chain iterates tiers in order, skipping unavailable ones.

### Privacy Mode

User-level toggle: **"Prefer Local"**. When enabled, triage biases toward local models, only falling to cloud when local literally can't handle it.

### Cost-Aware Routing

Extend CostTracker with monthly budget. At 80% budget, aggressively route to local. At 100%, cloud disabled with notification.

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

Why 0.8B is enough: Classification, not generation. Picks from 5 categories. <100ms latency target.

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
| Model | Cloud-first (Claude/GPT) for quality. Qwen 3.5 4B (MLX) for quick edits. |
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
When user gives loose instruction like "take my rough notes and turn them into a proper methodology section":
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
|  +----------+  +--------------------------------+   |
|  | File Tree |  |  Editor (syntax highlighted)   |   |
|  |           |  |                                |   |
|  | > src/    |  |  import Foundation             |   |
|  |   main.sw |  |  struct Parser {               |   |
|  |   util.sw |  |      func parse(_ input:       |   |
|  | > tests/  |  |          String) -> AST {       |   |
|  |   test.sw |  |          // ...                |   |
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

---

## 6. Agentic UI/UX

### 6a. Floating Glass Assistant Panel

**Design decision:** Primary AI interface is a floating `NSPanel` with glass effect (backdrop blur) that hovers over the document as a sibling window. Document stays scrollable and editable underneath. Pass-through hit testing for clicks outside the panel.

**Implementation:** `NSPanel` (non-activating auxiliary window) positioned relative to the note window. Draggable, resizable, dismissible. Keyboard shortcut ⌘⇧A to toggle.

**Panel layout (top to bottom):**
1. **Header bar** — model indicator (e.g., "Qwen 3B"), permission mode toggle (Read/Suggest/Write), close button
2. **Session dropdown** — switch between sessions, "+" for new session
3. **Conversation area** — scrollable message thread with rich content (markdown, code, diagrams, diffs)
4. **Input bar** — text input with slash command chips below
5. **Progress/controls** — progress bar during agent execution, Stop/Pause buttons

### 6b. Persistent Agent Sessions

Agent sessions are first-class SwiftData entities:

```swift
SDAgentSession {
    id: UUID
    pageId: UUID                    // which note spawned this
    status: SessionStatus           // .active, .completed, .paused, .failed
    messages: [SDAgentMessage]      // separate entity from SDMessage (avoids inverse conflict with SDChat)
    createdAt: Date
    title: String                   // auto-generated or user-named
    model: String                   // which model was used
    inputTokens: Int                // cost tracking
    outputTokens: Int
}

SDAgentMessage {
    id: UUID
    session: SDAgentSession         // @Relationship inverse
    role: MessageRole               // .user, .assistant, .toolCall, .toolResult
    content: String
    toolName: String?               // for .toolCall / .toolResult
    timestamp: Date
}
```

**Note:** `SDAgentMessage` is a separate entity from the existing `SDMessage` (which has an inverse relationship to `SDChat`). A single SwiftData entity can't have two inverse relationships to different parent types.

- Sessions persist across app launches
- Multiple sessions can run in parallel
- Completed sessions can be revisited, continued, or output re-inserted
- "AI History" browsable per note

### 6c. Permission / Autonomy Modes

| Mode | What AI Can Do | UX |
|------|---------------|-----|
| **Read** (default for queries) | Analyze, summarize, answer questions. Cannot modify blocks. | Responses in floating panel only |
| **Suggest** | Proposes edits as diff blocks with green/red highlighting. User approves each. | Diff blocks in document, Accept/Skip per edit |
| **Write** (default for operations) | Directly inserts/modifies blocks. Used for rewrite, continue, expand. | Changes appear immediately, undo available |

Toggle via segmented control in floating panel header. Free-text queries default to Read. Explicit operations (context menu rewrite, continue) default to Write.

**Mapping to existing NoteChatState:** The current inline divider flow (stream below `---`, accept/discard) maps to **Write** mode. **Suggest** mode introduces diff blocks as a new approach. **Read** mode is new — responses appear only in the floating panel. The existing `onAccept`/`onDiscard` callbacks evolve: in Write mode they work on `AIResponseCell` blocks; in Suggest mode they work on diff blocks (Apply/Skip per edit).

### 6d. Autonomous Agent System

**The ReAct Loop:**
```
User Goal → AgentExecutor
  ├─ THINK: LLM decides next action
  ├─ ACT: Execute tool from toolkit
  ├─ OBSERVE: Feed result back to LLM
  └─ LOOP until: goal complete, needs input, or max steps (20)
```

**AgentExecutor:**
```swift
actor AgentExecutor {
    let session: SDAgentSession
    let toolkit: AgentToolkit
    let inference: InferenceRouter    // routes to appropriate model tier
    let maxSteps: Int = 20

    func execute(goal: String) -> AsyncStream<AgentEvent>
    // Events: .thinking, .toolCall, .toolResult, .complete, .needsInput, .error
}
```

### 6e. Agent Toolkit

| Tool | What It Does | Permission |
|------|-------------|------------|
| `search_notes(query)` | Full-text + trigram search across vault | Read |
| `read_note(id)` | Get note's full content as blocks | Read |
| `query_graph(node, depth)` | Traverse knowledge graph connections | Read |
| `list_notes(folder, filter)` | Browse vault structure | Read |
| `web_search(query)` | Search the web | Read |
| `fetch_url(url)` | Read a web page's content | Read |
| `create_note(title, blocks)` | Create new note in vault | Write |
| `edit_block(noteId, blockId, content)` | Modify a specific block | Write |
| `insert_blocks(noteId, position, blocks)` | Add blocks to a note | Write |
| `delete_blocks(noteId, blockIds)` | Remove blocks | Write |
| `move_blocks(noteId, blockIds, position)` | Reorder blocks | Write |
| `create_graph_link(from, to, type)` | Add edge to knowledge graph | Write |

Builder additionally gets: `file_read`, `file_write`, `file_delete`, `shell_exec` (gated by trust level).

**Model routing for agents:** Tool calling works best on capable models. Agent execution routes to Tier 3 (Ollama 7B+) or Tier 4 (Cloud) based on goal complexity. Simple single-tool operations can use Tier 2 (Qwen 3B).

### 6f. Agent Panel (Dashboard)

```
+-------------------------+
|  AGENT PANEL            |
|                         |
|  [Triage] [Librarian]  |
|  [Writer] [Builder]    |
|                         |
|  Status: Working        |
|  "Analyzing 12 notes"   |
|                         |
|  Live feed:             |
|  > Read: quantum.md     |
|  > Found 3 connections  |
|  > Tagging: #physics    |
|                         |
|  [Open Thread]          |
+-------------------------+
```

- Agent status dashboard with cards, tap card to open thread
- Live feed while working, persisted as reviewable log after
- Agent section in Notes sidebar (collapsible, shows agent files/outputs)

---

## 7. Agent Communication (Message Bus)

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

---

## 8. Memory System (Three-Tier)

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

---

## 9. Learning Pool (Perplexica Port)

The always-available research engine that any agent can query.

### Pipeline

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
|  +-----------------------------------------------------+
|                                                       |
|  +--------------------------------------------------+ |
|  |              ANSWER WRITER                        | |
|  |  Combines sources + widgets -> cited answer       | |
|  +--------------------------------------------------+ |
|                                                       |
|  Implementation: Rust learning-pool crate             |
+------------------------------------------------------+
```

**Steps:**

1. **Classify** — LLM determines: skip search? which sources? which widgets? Rewrite query as standalone.
2. **Research** (parallel with widgets) — ReACT loop: LLM picks tools, execute in parallel (Swift TaskGroup, Rust for fetching), feed results back, LLM decides: done or search more? Iteration limits: Speed (2), Balanced (6), Quality (25).
3. **Write Answer** — LLM combines research + widgets into cited response.

**What changes from Perplexica:**
- SearXNG replaced with Brave Search (from MLXChat's `BraveSearchService.swift`)
- Next.js SSE replaced with Swift `AsyncStream`
- SQLite+Drizzle replaced with SwiftData
- Zod schemas replaced with Swift `Codable`
- Node.js EventEmitter replaced with message bus

**Learning Pool UI in home window:**

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
|  |  "CRISPR delivery mechanisms"      |  |
|  |     3 web + 5 academic sources    |  |
|  |     12 min ago                    |  |
|  +------------------------------------+  |
|                                          |
|  [Upload Document]  for RAG search       |
+------------------------------------------+
```

---

## 10. Graph NPCs & Agent Visualization

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

## 11. Voice System (Chatterbox TTS)

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
|  Engine:       [Chatterbox v]       |
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

Voice requirements locked 2026-03-12:
- Settings must expose Chatterbox, Fish Speech, Voicebox, and Resemble AI as selectable engines.
- Per-agent engine selection is required, not just per-agent voice selection.
- Custom/cloned voice flows must be surfaced where supported, with Chatterbox custom voice specifically preserved.
- Current local reference material verified on disk: `/Users/jojo/projects/logic to implement/chatterbox-master` and `/Users/jojo/projects/logic to implement/fish-speech-main`.

---

## 12. Trust Levels & Permissions

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

## 13. Notifications

Three channels:

| Channel | When | Example |
|---|---|---|
| macOS notification | Task complete, error, needs approval | "Builder: Build succeeded. 3 files created." |
| In-app badge | Proactive insight, connection found | Blue dot on agent's sidebar section |
| Voice (Chatterbox) | When voice enabled + notification fires | Librarian speaks the update |

Per-agent notification settings with "Require approval for" sub-toggles for semi-autonomous trust.

---

## 14. Distribution (Lite vs Pro)

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

## 15. Swift/Rust Split

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

FFI boundary: Swift sends commands, Rust does computation and returns results.

### Rust Cargo Dependencies (new crates)

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
mlx-community/Qwen3.5-9B-MLX-4bit     (~5.6GB, high-memory Macs)
ResembleAI/chatterbox-turbo            (~1.5GB, TTS)
```

---

## 16. Rich AI Output & Skills

### Rich Output (Block-Based)

With block-based editor, AI responses parse into native block types:

| Content | Block Type | Rendering |
|---------|-----------|-----------|
| Text | `ParagraphCell` | Standard markdown |
| Code | `CodeBlockCell` | Syntax-highlighted |
| Tables | `TableCell` | NSGridView |
| Mermaid | `MermaidCell` | Rendered SVG |
| Math/LaTeX | `MathCell` | Deferred — requires LaTeX rendering solution |

Token buffer (60ms) flush handler detects block boundaries (code fences, mermaid markers) and creates appropriate cells during streaming.

### Skills (Reusable Agent Recipes)

Pre-built goal templates invoked via slash commands:

```swift
SDSkill {
    name: String              // "Weekly Review"
    command: String           // "weekly-review"
    goalTemplate: String      // "Review all notes modified this week..."
    defaultPermission: Mode   // .write
    requiredTools: [String]   // ["search_notes", "read_note", "create_note"]
}
```

**Built-in skills:**
- `/outline` — Create outline of connections between notes in a folder
- `/research` — Search web for sources related to selected text
- `/restructure` — Analyze note structure and suggest improvements
- `/connect` — Find related notes and create graph links
- `/summarize-vault` — Create summary note for a tag or folder

Users can create custom skills from the settings panel.

---

## 17. Integration Layer & Data Flow

### The Block Model as Integration Spine

The block model eliminates the need for a separate integration layer:
- AI responses are blocks (AIResponseCell)
- Agent operations target blocks (edit_block, insert_blocks)
- Permission system controls block access
- Rich output is native block types (MermaidCell, CodeBlockCell)

### End-to-End Data Flow

```
User query in floating panel
  → AgentExecutor receives goal
    → TriageService routes to model tier
    → Agent executes tools against block model
    → DiffableDataSource animates changes
    → Vault sync serializes blocks → markdown → .md file
```

### Cross-Cutting Concerns

| Concern | Implementation |
|---------|---------------|
| Undo | Each agent step is an undo group. Full execution reversible as batch. |
| Conflict | Write operations serialized per-note. Concurrent reads allowed. |
| Streaming | 60ms token buffer. Tokens stream into AIResponseCell or floating panel. |
| Offline | Tier 1 + Tier 2 work fully offline. Web tools degrade gracefully. |
| Cost tracking | Per-session: model, tokens, tools called. Visible in session metadata. |
| Graph sync | Agent-created notes/links queue as pending nodes/edges in GraphStore. |

### New Components

| Component | Type | Description |
|-----------|------|-------------|
| `SDBlock` | SwiftData entity | Block data model (extended from existing) |
| `SDAgentSession` | SwiftData entity | Persistent agent session |
| `SDAgentMessage` | SwiftData entity | Agent message (separate from SDMessage) |
| `SDSkill` | SwiftData entity | Reusable agent recipe |
| `BlockEditorView` | NSViewRepresentable | Collection view editor |
| `DocumentCoordinator` | Class | Manages block ordering, focus, cross-cell navigation |
| `FloatingAssistantPanel` | NSPanel subclass | Glass overlay window |
| `AgentExecutor` | Actor | ReAct loop runner |
| `AgentEngine` | Actor | Agent lifecycle management |
| `MessageBus` | Actor | Typed message routing |
| `AgentToolkit` | Protocol + impls | App services wrapped as callable tools |
| `MLXInferenceService` | Actor | MLX Swift inference wrapper |
| `BlockParser` | Struct | Markdown → [SDBlock] |
| `BlockSerializer` | Struct | [SDBlock] → Markdown |

### Modified Components

| Component | Change |
|-----------|--------|
| `SDPage` | Adds `blocks` relationship. `body` becomes computed. |
| `TriageService` | 4-tier routing via expanded `TriageDecision` enum, MLX awareness, Ollama auto-detection |
| `TriageDecision` | Expanded from 2 cases to 4: `.appleIntelligence`, `.mlxLocal`, `.ollama`, `.cloud` |
| `LLMProviderType` | Add `.deepseek` and `.grok` cases |
| `LLMService` | New `MLXClient` + request builders for DeepSeek (OpenAI-compatible API) and Grok |
| `NoteChatState` | Routes to AgentExecutor for multi-step goals. Permission mode controls tool access. |
| `CostTracker` | Add `monthlyBudgetUSD` alongside existing `dailyBudgetUSD`. 80%/100% threshold logic. |
| `VaultSyncService` | Serialize blocks → markdown via `BlockSerializer` |
| `PipelineService` | Enrichment passes refactored as agent steps |
| `GraphStore` | API unchanged; new node/edge types for NPCs; used by agent toolkit |
| `GraphState` | New NPC animation state management |

### Unchanged Components

- `PhysicsCoordinator`
- Theme system and view modifiers
- `AppEnvironment`, `AppBootstrap`
- All existing Rust `graph-engine` code (extended, not rewritten)

---

## 18. Source Repo Reference Map

Every component traces back to a studied repo. These repos contain the reference implementations to port from.

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
| Tool schema definitions (MCP-compatible) | `MLXChat/Tools/ToolDefinitions.swift` | `ToolRegistry`, `ToolSpec` format |
| Settings/config patterns | `MLXChat/ViewModels/SettingsManager.swift` | UserDefaults persistence, GPU memory options |

### Perplexica (`/Users/jojo/Perplexica-master/`)

| Component | File | What to Port |
|---|---|---|
| Search pipeline orchestrator | `src/lib/agents/search/index.ts` | `SearchAgent` class: classify -> research -> write |
| Query classification | `src/lib/agents/search/classifier.ts` | Zod schema -> Swift Codable |
| ReACT researcher loop | `src/lib/agents/search/researcher/index.ts` | Tool-calling loop with iteration limits |
| Web search action | `src/lib/agents/search/researcher/actions/webSearch.ts` | SearXNG -> Brave Search adaptation |
| Academic search | `src/lib/agents/search/researcher/actions/academicSearch.ts` | Academic engine search |
| URL scraping | `src/lib/agents/search/researcher/actions/scrapeUrl.ts` | Fetch + parse web pages |
| Upload search (RAG) | `src/lib/agents/search/researcher/actions/uploadsSearch.ts` | Vector search over user docs |
| Widgets (weather/stock/calc) | `src/lib/agents/search/widgets/` | Open-Meteo, Yahoo Finance, math eval |
| File upload + chunking | `src/lib/uploads/manager.ts` | PDF parse, chunk, embed, store |
| Prompts | `src/lib/prompts/search/` | System prompts for each pipeline stage |

### CoPaw (`/Users/jojo/CoPaw-main/`)

| Component | File | What to Port |
|---|---|---|
| ReACT agent loop | `src/copaw/agents/react_agent.py` | Reasoning -> Act -> Observe cycle, max_iters=50 |
| Memory compaction | `src/copaw/agents/memory/` | Summarize when context 70% full |
| Skill-as-directory pattern | `src/copaw/agents/skills_manager.py` | Modular capabilities loaded from filesystem |
| Hot-reload config | `src/copaw/config/` | Watch config changes, rebuild agent without restart |
| Hook system | `src/copaw/agents/react_agent.py` | Bootstrap hook, memory compaction hook |
| Built-in tools | `src/copaw/agents/tools/` | Tool implementations with sandboxing |

### OpenClaw (`/Users/jojo/openclaw-main/`)

| Component | File | What to Port |
|---|---|---|
| Tool profiles (safety tiers) | `src/agents/tool-catalog.ts` | Curated tool sets: minimal, coding, messaging, full |
| Session-based agent routing | `src/routing/` | Map context -> agent deterministically |
| Permission model | `dangerous-tools.ts` | Explicit dangerous ops list, pre-validation |
| Bidirectional agent RPC | `src/acp/` | Gateway validates then executes tools |
| Auth profiles + failover | `src/agents/auth-profiles/` | Model selection with automatic failover on rate limit |

### Chatterbox (`/Users/jojo/chatterbox-master/`)

| Component | File | What to Port |
|---|---|---|
| TTS Turbo API | `src/chatterbox/tts_turbo.py` | `ChatterboxTurboTTS.from_pretrained()`, `.generate()` |
| Voice conversion | `src/chatterbox/vc.py` | Change speaker of existing audio |
| macOS example | `example_for_mac.py` | MPS device usage on Apple Silicon |
| Paralinguistic tags | Model vocabulary | `[laugh]`, `[sigh]`, `[cough]`, `[gasp]`, `[chuckle]`, etc. |

---

## 19. Competitive Analysis

### Frameworks Studied

| Framework | Strength | Weakness | What We Steal |
|---|---|---|---|
| **Claude Code / Agent SDK** | TeammateTool, inbox messaging, git worktree isolation, MCP tools | 7x token cost, cloud-only | Inbox messaging, transparency pattern, todo rewriting |
| **OpenAI Agents SDK** | Minimal (agents-as-tools), native language primitives | No local inference | Simplicity, agents-as-tools pattern |
| **LangGraph** | Graph-based workflows, DAG execution | Complex, Python-only | Reducer logic for concurrent state |
| **CrewAI** | Role-based teams, natural delegation | Struggles with dynamic adaptation | Role/personality framing |
| **Manus** | Context engineering (todo rewriting), multi-agent | Cloud VMs, closed source | Todo list rewriting, continuous replanning |
| **CoPaw** | Skill system, memory compaction, hot-reload | Single-agent only | Skill directories, 70% compaction, hooks |
| **OpenClaw** | Process isolation, tool profiles, ACP protocol | TypeScript, no local inference | Tool profiles, session routing, config-driven |
| **Qwen-Agent** | Built for Qwen models, function calling | Python, no multi-agent | Qwen-specific tool call format |
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
7. **Integrated knowledge graph** — agents navigate a visual knowledge space
8. **Block-based editor** — AI responses as native block types, not plain text

### Industry Insights (2026)

- "Professional developers don't vibe, they control." — transparency over autonomy
- Coordination tax: accuracy saturates beyond 4 agents. Structured topology required.
- Context engineering is the bottleneck, not model quality
- MCP has won as the tool protocol standard
- Three-tier memory (working/episodic/semantic) is consensus architecture
- Progressive tool disclosure: don't flood context with all tool descriptions
- Only 11% of orgs had deployed agentic AI by mid-2025. Shipping something that works is the differentiator.

---

## 20. Implementation Phases

### Phase 1: MLX Foundation
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

### Phase 3: Memory System
- Tier 1: Working memory with compaction (70% threshold)
- Tier 2: Episodic memory (SwiftData `SDAgentThread`)
- Tier 3: Semantic memory (Rust `memory-engine` vector index)
- Todo rewriting (Manus pattern)
- Cross-tier retrieval pipeline

### Phase 4: Librarian Agent
- Note indexing via Rust `memory-engine` crate
- Embedding generation (local model)
- Semantic search (cosine + BM25 hybrid)
- Passive monitoring (background scanning)
- Proactive signal UI (badges, dots)

### Phase 5: Writer Agent
- Preset system (SwiftData storage)
- Configurable system prompt generation
- Chain-of-thought instruction parsing
- Integration with existing per-note chat
- Agent-to-agent mention (Librarian for citations)

### Phase 6: Builder Agent
- Syntax-highlighted code editor (NSTextView variant)
- File tree view (scoped to workspace)
- Terminal pane (Process + pipes)
- Claude Code agent loop
- Trust level enforcement (Rust `tool-sandbox` crate)
- Activity log

### Phase 7: Learning Pool
- Port Perplexica classifier to Swift
- Port researcher ReACT loop
- Brave Search integration (reuse MLXChat code)
- RAG pipeline (Rust: chunk, embed, store, search)
- Widget system (weather, stocks, calc)
- Learning Pool UI in home window

### Phase 8: Graph NPCs
- New node/edge types in Rust graph-engine
- `AgentNPCState` struct + animation system
- NPC Metal shader (robot sprite + glow + trail)
- Separate physics simulation for agent territory
- Bridge/portal rendering + camera transition
- Zone background tinting
- Agent section in Notes sidebar

### Phase 9: Voice System
- Bundle Python + Chatterbox Turbo
- Persistent daemon subprocess (stdin/stdout JSON)
- Swift wrapper (`ChatterboxTTSEngine`)
- AVAudioEngine playback pipeline
- Per-agent voice config + voice cloning UI
- Read Mode toggles (notes, chat, graph)

### Phase 10: Block-Based Editor
- `SDBlock` entity migration
- `BlockParser` / `BlockSerializer` (markdown round-trip)
- `BlockEditorView` (NSCollectionView)
- Per-block TextKit 2 cells (ParagraphCell, HeadingCell, CodeBlockCell, etc.)
- Cross-cell navigation and keyboard flow
- Prose mode (edge-to-edge, no visible handles)
- Structured mode (handles, slash menu, drag-to-reorder)
- Cross-cell text selection (the hard one)

### Phase 11: Polish & Distribution
- App Store Lite build configuration
- Pro build configuration (`#if EPISTEMOS_PRO`)
- Notification system (macOS + in-app + voice)
- Trust settings UI
- Voice settings UI
- Skills system + custom skill creation
- Performance tuning (model swap latency, memory pressure)
- Testing across M1/M2/M3/M4
