# Epistemos v5 Vision: Craft-Inspired Architecture

**Date:** 2026-03-10
**Status:** Design Only (no implementation planning)
**Scope:** Comprehensive vision document covering block-based editor, AI model expansion, and agentic UI/UX
**Inspiration:** Architectural analysis of Craft's native editor, AI routing, and agent system

---

## Overview

This document describes a unified architectural vision for Epistemos v5, inspired by Craft's native text editor architecture and agentic AI capabilities. The design has three layers built on a shared foundation:

1. **Block-Based Editor** — NSCollectionView replacing monolithic NSTextView, per-block TextKit 2, prose-feel default
2. **AI Model & Triage Expansion** — 4-tier routing with embedded MLX inference (Qwen), Ollama as advanced local tier, expanded cloud providers
3. **Agentic UI/UX** — floating glass assistant panel, autonomous agent loop with tool calling, persistent sessions, permission modes, rich output

The block model is the architectural spine — AI responses are blocks, agent operations target blocks, and the permission system controls block access.

---

## Section 1: Block-Based Editor Foundation

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
    depth: Int                    // nesting level (renamed from existing `depth`)
    isCollapsed: Bool             // fold state (already exists on SDBlock)

    // Computed (not stored):
    var children: [SDBlock]       // filtered by parentBlockId from page.blocks
}
```

**Note — Migration from existing SDBlock:** The current `SDBlock` entity already exists with `pageId`, `parentBlockId`, `order`, `depth`, `isCollapsed`, and `sourceStartUTF16/sourceEndUTF16`. The migration adds `type: BlockType` (new), `metadata: [String: String]` (new), and `content: String` (replaces source range pointers with actual content). The `sourceStartUTF16/sourceEndUTF16` fields are dropped since blocks now own their content directly rather than pointing into a monolithic string. SwiftData lightweight migration handles field additions; the source-range-to-content conversion requires a one-time migration pass on first launch.

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

**Known complexity — cross-cell text selection:** Selecting text across multiple collection view cells is the single hardest problem in block-based editors. NSCollectionView cells are independent views with no native cross-cell selection. The approach: implement a custom `NSTextInputClient` on the collection view that coordinates selection state across cells, tracking a `SelectionRange(startBlock, startOffset, endBlock, endOffset)`. Mouse drag and Shift+arrow key extend selection across block boundaries. This is a multi-month engineering challenge and the primary risk in the block-based approach.

**Mermaid rendering:** Mermaid source blocks render to SVG via an embedded hidden `WKWebView` running mermaid.js. The SVG output is captured and displayed as an `NSImage` in the `MermaidCell`. The WebView is shared (singleton) and renders asynchronously — the cell shows a placeholder until rendering completes.

### Component Migration

| Current Component | Replacement |
|---|---|
| `ProseEditorRepresentable` (800-line Coordinator) | `BlockEditorView` + `DocumentCoordinator` + per-cell coordinators |
| `MarkdownTextStorage` | Per-block TextKit 2 styling within each cell |
| `ClickableTextView` | Each text cell's mini NSTextView; wikilink handling in cell delegate |
| `PageStoragePool` (LRU 12) | SDBlock persistence (blocks are SwiftData entities; no in-memory storage cache needed) |
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

## Section 2: AI Model & Triage Expansion

### Design Decision

Expand from 2-tier triage (Apple Intelligence vs. Cloud) to 4-tier routing with embedded local inference via MLX Swift and Qwen models. Ollama becomes an advanced local tier for power users. New cloud providers added.

### Four-Tier Triage

```
Tier 1: Apple Intelligence    (free, instant, ~4K context)
  ↓ fallback
Tier 2: Qwen via MLX Swift    (free, fast, on-device, 128K context)
  ↓ fallback
Tier 3: Ollama                (user-managed advanced local models)
  ↓ fallback
Tier 4: Cloud API             (most capable, costs money, needs internet)
```

### Embedded Local Inference (MLX Swift + Qwen)

No external software required. MLX Swift runs Qwen models directly in-process using Apple Silicon unified memory.

**Default models:**

| Model | Size | Download | Triage Role |
|-------|------|----------|-------------|
| Qwen 2.5 3B Instruct | ~2.2GB | Recommended default | Primary Tier 2 |
| Qwen 2.5 1.5B Instruct | ~1.2GB | Lightweight option | Fallback Tier 2 |
| Qwen 2.5 7B Instruct | ~5GB | Optional | Advanced Tier 2 |
| Qwen 2.5 Coder 3B | ~2.2GB | Optional | Auto-selected for code operations |

**Model management:**
- First launch: prompt to download recommended model (Qwen 2.5 3B, ~2.2GB)
- Models stored in `~/Library/Application Support/Epistemos/Models/`
- Settings panel for downloading additional models, importing custom MLX models, viewing disk usage
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

### Ollama Integration (Tier 3)

Ollama remains supported as an optional power-user feature. If triage detects Ollama running (`localhost:11434`), those models join the routing pool. For well-known model families (llama, deepseek, qwen, phi, mistral), triage has built-in capability profiles. For unknown models, parameter count serves as a heuristic.

```swift
enum LocalModelSource {
    case embedded(MLXModel)      // Qwen via MLX (Tier 2)
    case ollama(OllamaModel)     // External Ollama (Tier 3)
    case appleIntelligence       // FoundationModels (Tier 1)
}
```

### New Cloud Providers (Tier 4)

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

**Note:** Operation names use existing `NotesOperation` enum cases. "Research" in the routing table maps to `.learn`. If renamed, update the enum explicitly.

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

`TriageService` gains a reference to `MLXInferenceService` alongside the existing `LLMService`. The fallback chain iterates tiers in order, skipping unavailable ones (e.g., if no MLX model downloaded, skip Tier 2).

### Dependencies

- **mlx-swift** (Apple): SPM dependency for embedded inference. Requires macOS 14+.
- **Memory budget:** Loading a 2.2GB Qwen 3B model into unified memory alongside the app (~200MB), graph engine, and Metal renderer. On 8GB machines this is tight — the design should include a "low memory" mode that defers to Tier 1 (Apple AI) + Tier 4 (Cloud) only, skipping local model loading.
- **Model names:** Cloud model names (gpt-5.3, gpt-5-nano, etc.) are current as of March 2026 but should be verified when implementation begins, as these models evolve rapidly.

### Privacy Mode

User-level toggle: **"Prefer Local"**. When enabled, triage biases toward local models, only falling to cloud when local literally can't handle it (no model available, or content exceeds context window).

### Cost-Aware Routing

Extend CostTracker with monthly budget. At 80% budget, aggressively route to local. At 100%, cloud disabled with notification.

---

## Section 3: Agentic UI/UX

### 3a. Floating Glass Assistant Panel

**Design decision:** Primary AI interface is a floating `NSPanel` with glass effect (backdrop blur) that hovers over the document as a sibling window. Document stays scrollable and editable underneath. Pass-through hit testing for clicks outside the panel.

**Implementation:** `NSPanel` (non-activating auxiliary window) positioned relative to the note window. Draggable, resizable, dismissible. Keyboard shortcut ⌘⇧A to toggle.

**Panel layout (top to bottom):**
1. **Header bar** — model indicator (e.g., "Qwen 3B"), permission mode toggle (Read/Suggest/Write), close button
2. **Session dropdown** — switch between sessions, "+" for new session
3. **Conversation area** — scrollable message thread with rich content (markdown, code, diagrams, diffs)
4. **Input bar** — text input with slash command chips below
5. **Progress/controls** — progress bar during agent execution, Stop/Pause buttons

### 3b. Persistent Agent Sessions

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

### 3c. Permission / Autonomy Modes

| Mode | What AI Can Do | UX |
|------|---------------|-----|
| **Read** (default for queries) | Analyze, summarize, answer questions. Cannot modify blocks. | Responses in floating panel only |
| **Suggest** | Proposes edits as diff blocks with green/red highlighting. User approves each. | Diff blocks in document, Accept/Skip per edit |
| **Write** (default for operations) | Directly inserts/modifies blocks. Used for rewrite, continue, expand. | Changes appear immediately, undo available |

Toggle via segmented control in floating panel header. Free-text queries default to Read. Explicit operations (context menu rewrite, continue) default to Write.

**Mapping to existing NoteChatState:** The current inline divider flow (stream below `---`, accept/discard) maps to **Write** mode in the new system. **Suggest** mode introduces diff blocks as a new approach replacing the divider for review-first operations. **Read** mode is new — responses appear only in the floating panel, never touching the document. The existing `onAccept`/`onDiscard` callbacks evolve: in Write mode they work on `AIResponseCell` blocks; in Suggest mode they work on diff blocks (Apply/Skip per edit).

### 3d. Autonomous Agent System

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

**Agent Toolkit:**

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

**Model routing for agents:** Tool calling works best on capable models. Agent execution routes to Tier 3 (Ollama 7B+) or Tier 4 (Cloud) based on goal complexity. Simple single-tool operations can use Tier 2 (Qwen 3B).

### 3e. Rich AI Output

With block-based editor, AI responses parse into native block types:

| Content | Block Type | Rendering |
|---------|-----------|-----------|
| Text | `ParagraphCell` | Standard markdown |
| Code | `CodeBlockCell` | Syntax-highlighted |
| Tables | `TableCell` | NSGridView |
| Mermaid | `MermaidCell` | Rendered SVG |
| Math/LaTeX | `MathCell` | Deferred — requires LaTeX rendering solution (embedded WKWebView with MathJax, or native renderer). No mature AppKit-native option exists. |

Token buffer (60ms) flush handler detects block boundaries (code fences, mermaid markers) and creates appropriate cells during streaming.

### 3f. Skills (Reusable Agent Recipes)

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

## Section 4: Integration Layer

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
| `SDBlock` | SwiftData entity | Block data model |
| `SDAgentSession` | SwiftData entity | Persistent agent session |
| `SDSkill` | SwiftData entity | Reusable agent recipe |
| `BlockEditorView` | NSViewRepresentable | Collection view editor |
| `DocumentCoordinator` | Class | Manages block ordering, focus, cross-cell navigation |
| `FloatingAssistantPanel` | NSPanel subclass | Glass overlay window |
| `AgentExecutor` | Actor | ReAct loop runner |
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
| `LLMService` | New request builders for DeepSeek (OpenAI-compatible API) and Grok. GPT-5 Nano as additional OpenAI model. |
| `NoteChatState` | Routes to AgentExecutor for multi-step goals. Permission mode controls tool access. |
| `CostTracker` | Add `monthlyBudgetUSD` alongside existing `dailyBudgetUSD`. 80%/100% threshold logic for budget-aware routing. |
| `VaultSyncService` | Serialize blocks → markdown via `BlockSerializer` |
| `PipelineService` | Enrichment passes refactored as agent steps |
| `GraphStore` | API unchanged but used by agent toolkit (`create_graph_link` uses existing mutation methods + pending queue) |

### Unchanged Components

- `GraphState` (Rust FFI)
- `PhysicsCoordinator`
- Theme system and view modifiers
- `AppEnvironment`, `AppBootstrap`
- All Rust `graph-engine` code
