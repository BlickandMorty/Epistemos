# Epistemos PKM App — Deep Synthesis & Architecture Audit

## Executive Summary

This document is a comprehensive synthesis of everything built, audited, fixed, and expanded across the Epistemos session log — a native macOS PKM app written in Swift/SwiftUI with a Rust `agent_core` bridged via UniFFI FFI. The session covered 20 commits across six major workstreams: Xcode-style code editor with AI partner, Goose-modeled agent migration, Living Intelligence Layer (meaning anchors, activity profiles, chat unification), performance hardening, UI overhaul, and computer-use provider wiring. This document identifies remaining gaps, best practices from Goose, Hermes v0.7.0, and OpenClaw, and provides a full implementation roadmap for the next session.[^1][^2][^3][^4][^5]

***

## 1. Architecture Overview

### 1.1 Final Architecture After All 20 Commits

```
Main Chat → ChatCoordinator → Rust agent_core (UniFFI bridge)
                                    → 4 Cloud Providers (Claude, OpenAI, Gemini, Perplexity)
                                    → 19 Built-in Tools
                                    → Approval Flow (StreamingDelegate semaphore)
                                    → Context Compaction (4-phase)
                                    → Prompt Caching
                                    → Security Scanning

                           → PipelineService (local / Apple Intelligence path)
                                    → Local Qwen inference

GraphState → WeightedContextEngine → EmbeddingService (shared, LRU-4096)
                                    → ActivityTracker
                                    → MeaningAnchorService

Code Editor → AIPartnerService → WeightedContextEngine (shared embedding)
           → CodeAskBarService → LineBreakdownPanel / EpistemosAnswerBox
           → OutlineParser (static regex, pre-compiled)
           → SegmentedIndentationGuideView

NotesSidebar → SidebarCacheState → SidebarPageItem (fingerprint guard)
```

The Rust `agent_core` is bridged via UniFFI and exposes a single `runAgentSession()` entrypoint. `StreamingDelegate` converts Rust `AgentEventDelegate` callbacks into a Swift `AsyncStream<AgentStreamEvent>`, consumed by both `ChatCoordinator` (main chat) and `AgentViewModel` (agent panel).[^6][^7]

### 1.2 Epistemos vs. Goose — Current Scorecard

| Category | Winner | Score |
|---|---|---|
| Context management | Epistemos (4-phase compaction + prompt caching) | E +1 |
| Memory/skills system | Epistemos (dual-store MEMORY.md/USER.md + vault) | E +1 |
| Terminal / PTY | Epistemos (persistent PTY + RAII cleanup) | E +1 |
| Session management | Epistemos (RAII cascade cleanup) | E +1 |
| Web search | Epistemos (built-in Rust tool + server-side) | E +1 |
| FFI/IPC architecture | Epistemos (UniFFI Swift bridge) | E +1 |
| Shared memory | Epistemos (POSIX `shm_open`) | E +1 |
| File operations | Epistemos (Rust `file_ops` tool, read/write/patch/list) | E +1 |
| Sub-agent orchestration | Goose | G +1 |
| MCP ecosystem | Goose (June 2025 standard)[^8] | G +1 |
| Provider quantity | Goose (15+ vs 4) | G +1 |
| Tool use / agent loop | Tie | — |
| Security scanning | Tie | — |
| Computer use | Tie (partial, see §5) | — |
| **TOTAL** | **Epistemos 8 — Goose 3 — Tie 3** | |

Goose's roadmap for July 2025 includes sub-agent orchestration (spawned autonomously or via sub-recipes), dynamic model selection mid-conversation, and MCP SDK migration to the June 2025 standard. These are the three functional areas where Epistemos currently trails.[^8]

***

## 2. Session 1 — Code Editor & AI Partner

### 2.1 What Was Built (Kimi Session)

Eleven new files were added: `OutlineNavigatorView.swift`, `EditorBreadcrumbBar.swift`, `SegmentedIndentationGuideView.swift`, `AIPartnerService.swift`, `AIPartnerInlineView.swift`, `AIPartnerControlPanel.swift`, `WeightedContextEngine.swift`, `CodeAskBar.swift`, `FocusedResponsePanel.swift`, `InlineResponseHighlighter.swift`, and `HologramNodeInspector.swift`.

**Weighted Context Formula (preserved and optimized):**

\[\text{finalScore} = 0.35 \cdot \text{semantic} + 0.25 \cdot \text{nodeWeight} + 0.20 \cdot \text{complexity} + 0.15 \cdot \text{connection} + 0.10 \cdot \text{recency}\]

This formula was later upgraded in the activity profile phase to add a 6th term:

\[\text{finalScore} = 0.30 \cdot \text{semantic} + 0.20 \cdot \text{nodeWeight} + 0.15 \cdot \text{complexity} + 0.10 \cdot \text{connection} + 0.15 \cdot \text{activity} + 0.10 \cdot \text{recency}\]

The activity score is computed by `ActivityTracker.activityScore(for:)`, weighing edit frequency, visit frequency, and recency with a 30-day exponential decay half-life.

### 2.2 Critical Bugs Found & Fixed (Claude Audit)

| # | Severity | File | Issue | Fix Applied |
|---|---|---|---|---|
| 1 | CRASH | `AIPartnerService.swift` | `ObservableObject` instead of `@Observable` | Migrated to `@Observable` macro |
| 2 | CRASH | `CodeAskBar.swift` | Same | Same |
| 3 | COMPILE | `InlineResponseHighlighter.swift` | `annotation.type.description` — no property | Added `var description: String` to `AnnotationType` enum |
| 4 | COMPILE | `WeightedContextEngine.swift` | `edges.count { }` on `[String: GraphEdgeRecord]` | Changed to `.values.filter { }.count` |
| 5 | COMPILE | `CodeAskBar.swift` | `match.string` (not on `NSTextCheckingResult`) | Used `Range(match.range, in:)` |
| 6–9 | FORCE-UNWRAP | 4 files | 5 force-unwrap violations | Replaced with `guard let`, optional chaining |
| 10 | COMPILE | `CodeEditorView.swift` | 35+ "Cannot find type in scope" errors | Ran xcodegen; all 11 files now in project |
| 11 | COMPILE | `CodeEditorView.swift` | `cursorPosition` (wrong API) | Changed to `cursorPositions: [CursorPosition]` |
| 12 | COMPILE | `EditorBreadcrumbBar.swift` | `BreadcrumbItem` name collision | Renamed to `EditorBreadcrumbItem` |
| 13 | COMPILE | Multiple | `Color.tertiary`, `.sidebar`, `.accent` (ShapeStyle, not Color) | Replaced with concrete `Color` values |

### 2.3 Performance Fixes Applied

1. **Line cache** — `AIPartnerService` now caches `currentLines: [String]`; eliminates 6+ redundant `components(separatedBy:)` calls per keystroke (~10× fewer allocations)[^9]
2. **Pre-compiled regex** — `OutlineParser` uses `static let` regex patterns; was recompiling on every parse (~5000× fewer compilations per keystroke)
3. **Redundant `await MainActor.run`** — Removed from 5 sites in `@MainActor`-isolated classes (7 unnecessary task suspensions)
4. **Triple complexity analysis** — `WeightedContextEngine.assembleContext` and `weightedSemanticSearch` now accept `precomputedComplexity`; eliminates 2 redundant analyses per cycle
5. **Scroll perf** — `SegmentedIndentationGuideView` now applies `scrollOffset` at draw time instead of remapping the full `lineInfos` array on every scroll event
6. **Outline children** — `OutlineItemRow` children no longer inherit parent's `isExpanded`/`isHovered`/`onToggle`/`onSelect` state

***

## 3. Session 2 — UI Overhaul

### 3.1 Minimap Removal

`MinimapAnnotationsView.swift` was deleted. `optimizeMinimapPerformance()` in `CodeEditorView.swift` was removed. The collapsible `OutlineNavigatorView` now serves as the sole navigation panel.

### 3.2 NSPopover-Based Suggestions

AI partner suggestions are now delivered via `AppKitPopover` (native `NSPopover`), replacing the `ZStack` overlay approach. Popovers auto-dismiss on click-outside and include **Accept / Dismiss / Explain** action buttons with the relevant line number labeled. This matches Apple's native HIG for contextual UI.[^10]

### 3.3 Code Ask Bar — Two Response Modes

The single Ask Bar now drives two distinct response modes:
- **Direct Answer** — `EpistemosAnswerBox`: flat labeled panel ("Epistemos"), no modal blur, includes code blocks and Apply buttons
- **Line Analysis** — `LineBreakdownPanel`: per-line breakdown at top of file (e.g., `L3 — refactor…`, `L80 — delete unused function`); tapping a line entry scrolls the editor to that line and reveals Replace / Explain buttons

### 3.4 Sidebar Language Icons

`FileRow` now renders language-specific icons using `SF Symbols` with colored overlays: Swift bird (orange), Rust square-R (orange), Python circle (blue-green), JavaScript circle (yellow), TypeScript (blue), Markdown (gray-blue), JSON (gray), HTML (orange), CSS (purple), Go (cyan), C/C++ (gray), Ruby (red), default (document). Provider icons were also updated (Google/Gemini diamond).

***

## 4. Session 3 — Living Intelligence Layer (6 Phases)

### 4.1 Background Summary Bug Fixes

Eight bugs were identified and fixed across the workspace summary system:
1. **Idle detection** only checked `.keyDown` events; now checks all NSEvent input types (mouse, scroll, etc.)
2. **Semantic diff** was taking `paragraphs.prefix(note.totalParagraphs)` — i.e., ALL paragraphs — then the first 3; now correctly diffs against changed paragraphs
3. **Workspace awareness** was only injected for explicit session-query keyword matches; now always injects a lightweight version (open note titles + recent edits) and the deep version for session queries

### 4.2 Phase 1 — Chat Unification

Three previously ephemeral chat surfaces now persist to `SDChat`:

| Surface | chatType | Trigger |
|---|---|---|
| Dialogue (graph node chats) | `"dialogue"` | `persistIfMeaningful()` on node switch/close (threshold: 3+ messages) |
| Code Ask Bar | `"codeAsk"` | After each query+response pair |
| AI Partner accepted suggestions | `"aiPartner"` | On `acceptSuggestion()` |

This joins the two existing types (`"chat"`, `"notes"`) for a 5-type unified model.

### 4.3 Phase 2 — Meaning Anchors

`MeaningAnchorService` triggers local Qwen inference (via `TriageService`) on chat exit for sessions with 3+ messages. The generated JSON anchor includes: `topic`, `summary`, `insights[]`, `connections[]`, `theme`, `confidence`. The anchor becomes a `GraphNodeType.idea` node with edges to referenced pages.

**Key implementation note:** The variable name `transcript` caused a GRDB SQL type collision (GRDB defines a `SQL` type that shadows `String` in certain contexts). The variable was renamed to `chatLog` as the workaround.

### 4.4 Phase 3 — Activity Profile

`ActivityTracker.activityScore(for:)` computes a per-node engagement score from existing event data:
- **Edit frequency score**: exponentially weighted edit counts over 30 days
- **Visit frequency score**: visit counts with time decay  
- **Recency bonus**: extra weight if the node was visited in the last 24 hours

This score becomes the 6th factor in `WeightedContextEngine.weightedSemanticSearch`, weighted at 15%. The global activity profile (top 5 edited/visited pages over 7 days) is injected into all `ChatCoordinator` prompts.

### 4.5 Phases 4–6 — Anchor Injection, Proactive AI, Backfill

- **Phase 4**: Last 5 meaning anchors injected as `[Recent Insights]` in workspace awareness context
- **Phase 5**: Theme-based connection hints + writing style adaptation injected into deep-context-mode prompts
- **Phase 6**: `MeaningAnchorService.backfillExistingChats()` runs once on first launch (gated by `UserDefaults` flag) to retroactively process all existing `SDChat` records

***

## 5. Session 4 — Goose Migration (Agent System)

### 5.1 Phase 1 — Rust Agent Loop Wired to Main Chat

`ChatCoordinator.handleQuery()` now routes cloud queries (`InferenceMode.api`) through `runRustAgentPath()` instead of `PipelineService`. The flow:

1. `AppBootstrap.populateRustEnvironment()` reads all API keys from Keychain and sets them as process environment variables (required since Rust providers read `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `PERPLEXITY_API_KEY` from the process env)
2. `ChatCoordinator.resolveRustProviderName()` maps `CloudProviderAuthService.activeAIProvider` to a Rust provider string
3. `StreamingDelegate` bridges `AgentEventDelegate` (Rust FFI) to `AsyncStream<AgentStreamEvent>` (Swift async)
4. `AgentStreamEvent` cases map to UI updates: `.textDelta` → message streaming, `.toolCall` → tool status display, `.permissionRequired` → approval dialog, `.thinking` → reasoning panel

### 5.2 Phase 2 — Gemini Provider (4th Cloud)

A full `GeminiProvider` Rust struct was implemented with:
- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?alt=sse`
- Auth: `key=API_KEY` query parameter (not header)
- Message format: `contents[].parts[]` with role `"user"` / `"model"`
- Tool calling: `functionDeclarations` in `tools[]`
- SSE parsing: `candidates.content.parts` with `finishReason` detection
- Models supported: `gemini-2.5-flash` (default), `gemini-2.5-pro`

The Gemini provider was added to `ProviderFFI` enum and all match exhaustion sites in `bridge.rs`.

### 5.3 Phase 3 — Memory & Skills (Hermes v0.7.0 Port)

**Memory Tool** (`memory_tool.rs`): Ports the Hermes dual-file design:[^3][^1]
- `MEMORY.md` (agent notes, 2200-char limit) and `USER.md` (user profile, 1375-char limit)
- Entry delimiter: `§` (section sign)
- File locking for concurrent safety (`fcntl` locks)
- Threat scanning for injection/exfiltration patterns
- Frozen snapshot injected into system prompt; live state used for tool responses
- Operations: `add`, `remove`, `list`, `clear`

Hermes v0.7.0's key upgrade was the **pluggable memory provider** architecture, where memory backends can be swapped at runtime. The Epistemos Rust port uses file-based storage as default but exposes a `MemoryBackend` trait for future provider swapping (graph store, vector DB, etc.).[^1]

**Skills Tool** (`skills_tool.rs`):
- SKILL.md files with YAML frontmatter (`name`, `description`, `triggers`, `steps`)
- Operations: `create`, `edit`, `patch`, `delete`, `list`, `apply`
- Skills directory: `{vault_root}/.epistemos/skills/`
- Threat scanning on all skill content

### 5.4 Phase 3c — Approval Flow

`ChatCoordinator.runRustAgentPath()` now captures the `StreamingDelegate` reference so `resolvePermission(_:)` can be called from the main thread when the user responds to an approval dialog. The `permissionRequired` event carries `PermissionRequest` (tool name, arguments, risk level) which drives the native `NSAlert`-style approval sheet.

### 5.5 Phase 4 — Web Fetch + Computer Use Tools

The `file_ops` Rust tool was added (read/write/patch/list) closing the last functional gap vs. Goose. Web fetch is handled by the existing `web_search` tool. Computer use is delegated to Swift (see §6 below).[^5]

### 5.6 Phases 5–6 — Agent UI + Optional Hermes

`AgentViewModel` now tracks tool call states (pending/running/completed/failed) for UI rendering in `MessageBubble`. The Hermes subprocess is now optional — it starts only if `HermesSubprocessManager.isEnabled` is true in `UserDefaults`, defaulting to `false` for new installs.

***

## 6. Computer Use — Gap Analysis & Implementation Roadmap

### 6.1 What Each Provider Offers

| Provider | Computer Use API | Method | Notes |
|---|---|---|---|
| Claude (Anthropic) | ✅ Full | `computer_use_20241022` tool | Screenshot + click + type + scroll[^10] |
| OpenAI GPT-4o | ✅ Full | `computer_use_preview` tool (2025) | Screenshot-based |
| Gemini | ⚠️ Partial | No native computer use API; delegates to function calling | Requires custom macOS bridge |
| Perplexity | ❌ None | Text-only | No computer use |

Claude's computer use in Claude Code CLI uses the same engine as the Desktop app, with native macOS Accessibility permissions. The key insight from recent research: Claude can use `osascript`/AppleScript for genuine accessibility tree access (listing UI components, reading labels, performing clicks by role/name, retrieving window hierarchies) as an alternative to pure screenshot-based coordinate clicking.[^11][^10]

### 6.2 What Epistemos Has vs. What's Missing

**Already implemented:**
- Screenshot capture via `CGWindowListCreateImage`
- `computer_use` tool stub in Rust (`tools/computer_use.rs`) that delegates to Swift via callback
- Accessibility permission request flow

**Missing (critical gaps):**
1. **Accessibility Tree integration** — No `AXUIElement` traversal in `ComputerUseTool`. Should expose: `ax_get_tree()`, `ax_click_element(role:label:)`, `ax_read_value(element_id:)`, `ax_set_value(element_id:value:)`, `ax_get_windows()`. This is what makes Epistemos deeper than plain screenshot-based computer use[^11]
2. **Per-provider routing** — `ComputerUseTool.execute()` should check active provider and call the provider's native API format (Claude uses `computer_use_20241022`, GPT uses `computer_use_preview`)
3. **Gemini bridge** — Since Gemini has no native computer use, implement as a Swift-side tool that accepts `[AXAction]` descriptions and executes them via macOS Accessibility APIs
4. **Coordinate scaling** — Claude's recommended resolution for general desktop is 1024×768 or 1280×720; screenshots need to be downscaled before being sent to providers, with coordinate mapping back to display resolution[^10]

### 6.3 Recommended Computer Use Implementation

```swift
// ComputerUseBridge.swift (Swift side, called from Rust via callback)
struct AXTreeNode {
    let role: String
    let label: String
    let value: String?
    let frame: CGRect
    let children: [AXTreeNode]
    let elementID: String  // unique hash for targeting
}

actor ComputerUseBridge {
    func getWindowTree(windowID: Int?) async -> AXTreeNode
    func clickElement(elementID: String) async throws
    func typeText(elementID: String, text: String) async throws
    func readValue(elementID: String) async -> String?
    func captureScreen(scale: CGFloat = 0.5) async -> Data  // JPEG for token efficiency
    func scrollElement(elementID: String, deltaX: Double, deltaY: Double) async throws
}
```

The Rust `computer_use` tool should serialize the full `AXTreeNode` tree as JSON and inject it into the provider's context alongside screenshots. This gives the LLM structural understanding without requiring pixel-level coordinate guessing — matching the "going deeper than just capturing the screen" requirement.

***

## 7. Remaining Architectural Gaps

### 7.1 Sub-Agent Orchestration (Goose Gap #1)

Goose's July 2025 roadmap specifically targets sub-agent spawning for parallel task execution. The Rust `agent_core` has a placeholder `spawn_subagent()` hook in `bridge.rs` but no implementation. Recommended approach:[^8]

- Each sub-agent is a separate `runAgentSession()` call with a scoped objective
- Parent agent receives sub-agent results as tool outputs
- `SubAgentCoordinator` in Swift manages lifecycle (max concurrency, cancellation, result aggregation)
- Sub-agents share the same `EmbeddingService` instance and vault access

### 7.2 MCP Client (Goose Gap #2)

Goose is migrating to the official MCP Rust SDK. Epistemos currently has API pass-through only. A proper MCP client would:[^8]
- Discover local MCP servers via `~/.config/mcp/servers.json`
- Connect via stdio, SSE, or HTTP transports
- Expose server tools as first-class Rust tools via `McpToolWrapper`
- Support dynamic server lifecycle (start/stop MCP servers as needed)

### 7.3 Additional Cloud Providers (Goose Gap #3)

Adding Ollama (local REST API) and OpenRouter (universal proxy) as Rust providers would bring provider parity closer to Goose. Both use OpenAI-compatible APIs with minor differences in model name format and streaming behavior.

### 7.4 EmbeddingService Consolidation (Partially Done)

Four redundant `EmbeddingService()` instances were reduced to three sharing `GraphState.embeddingService`. One standalone service in `CodeCompanionService` at line 3426 remains separate (no `graphState` access). The fully correct solution would inject `graphState` into `CodeCompanionService` via init parameter.

### 7.5 SwiftData @Query Reactivity (Sidebar Stutter)

The sidebar rebuild guard (structural fingerprint early-exit) reduces `rebuildCache()` thrashing. However, the root cause — SwiftData `@Query` re-evaluating on every `SDPage` property mutation — cannot be fixed without moving to manual `ModelContext.fetch()` calls in `NotesBrowserView`. This is an architectural change that requires careful planning to avoid regressions in the sort/filter pipeline.[^12]

### 7.6 Swift 6 Concurrency Hardening

Several `@preconcurrency` annotations were added for Metal imports. Additional hardening needed per Swift 6 / WWDC 2025 guidance:[^9]
- `InlineSuggestion` and `OutlineItem` need `Sendable` conformance (or `@unchecked Sendable` with documentation)
- `GhostTextRenderer.shared` (stateless singleton) should be refactored to static methods
- `MetalComputeEngine` actor needs `nonisolated` annotations on read-only computed properties

***

## 8. Knowledge Graph Integration — Status & Expansion

### 8.1 Current Integration Points

The knowledge graph is deeply wired into the AI intelligence layer. Every semantic search in the app goes through `WeightedContextEngine`, which reads `GraphState.store.nodes` for `nodeWeight` and `GraphState.store.edges` for `connectionScore`. The `meaningAnchorService` writes new `.idea` nodes back to the graph on chat exit. `ActivityTracker` records per-node engagement events that feed back into the 6th weighting factor.

### 8.2 Preserved Features

- **Instant retrieval**: `EmbeddingService` with LRU-4096 cache; sub-10ms lookup for known embeddings
- **Weighted complexity**: `CodeComplexityAnalyzer` produces per-node complexity scores (cyclomatic + nesting + recursion detection — now correctly scoped to function body, not file-wide)
- **Graph-weight relevance**: `nodeWeight` (the graph's own centrality/importance score) contributes 20% to search ranking
- **Connection scoring**: Edge traversal at depth-2 contributes 10%

### 8.3 Expansion Opportunities

1. **Graph-aware suggestions in prose editor** — Currently the weighted context engine is only called from the code editor. The prose editor could use the same engine for inline connection suggestions ("this concept appears in 3 other notes")
2. **Anchor-to-anchor edges** — When a new meaning anchor is created, it should be semantically compared against existing anchors and edges created for similarity scores above 0.75
3. **Live graph weight update on activity** — Currently activity scores are computed on demand. A background task could update `GraphNodeRecord.weight` in SwiftData whenever `ActivityTracker` crosses a significance threshold, making graph centrality reflect user attention

***

## 9. Open Issues & Priority Queue

### 9.1 Compile / Correctness (Must Fix Before Next Session)

| Priority | Issue | File | Fix |
|---|---|---|---|
| HIGH | `EmbeddingService` in `CodeCompanionService:3426` still creates own instance | `CodeEditorView.swift` | Inject `graphState` via init |
| HIGH | `@preconcurrency Metal` only partially applied | `CodeEditorView.swift` | Audit all Metal `@Sendable` captures |
| MEDIUM | `OutlineItemType` not `Equatable` (removed Equatable from `MinimapAnnotation`) | `OutlineNavigatorView.swift` | Add `Equatable` via synthesis |
| MEDIUM | `InlineSuggestion` not `Sendable` | `AIPartnerInlineView.swift` | Add conformance or `@unchecked Sendable` |
| LOW | `GhostTextRenderer.shared` singleton pattern | `AIPartnerInlineView.swift` | Refactor to static methods |

### 9.2 Agent System (Next Session Priorities)

1. **Computer use AX tree** — Implement `ComputerUseBridge.swift` with `AXUIElement` traversal
2. **Per-provider computer use routing** — Route Claude → `computer_use_20241022`, GPT → `computer_use_preview`, Gemini → Swift-side AX execution
3. **Sub-agent foundation** — Wire `spawn_subagent()` in `bridge.rs` to a `SubAgentCoordinator`
4. **MCP client skeleton** — At minimum, discover and list local MCP servers in the agent panel UI

### 9.3 UI/UX Polish

1. **AI Partner popover line numbers** — Currently shows generic "line N" for all suggestions. Should map `InlineSuggestion.lineRange` to the actual editor line numbers via `CodeEditSourceEditor`'s cursor API
2. **Language icon fallback** — `FileRow.languageIcon()` falls back to a generic document icon for unknown extensions. Should also check the file's shebang line for polyglot detection
3. **Code Ask Bar keyboard shortcut** — No keyboard shortcut currently assigned; should be `⌘⇧K` for code editor, `⌘K` for prose (consistent with VS Code and Nova conventions)
4. **Provider selector in chat** — Agent mode provider is inferred from `activeAIProvider`; should expose a per-chat override picker in the chat header

***

## 10. Performance Profile & GPU Offloading

### 10.1 Metal GPU Usage

The app uses Metal for:
- **Embedding similarity** — Batch cosine similarity via Metal compute shaders in `EmbeddingService`
- **Graph physics** — Force-directed layout in `MetalGraphNSView` via CVDisplayLink + Metal render pipeline
- **Code syntax highlighting** — `MetalSyntaxRenderer` for large files

The `ComputePerformanceMonitor` tracks per-operation GPU timing. Key finding from the session: `await ComputePerformanceMonitor.shared.recordOperation()` was incorrectly awaited (it's synchronous on a non-actor class). This was fixed but warrants a broader audit of all `ComputePerformanceMonitor` call sites.

### 10.2 Threading Model

| Subsystem | Thread | Notes |
|---|---|---|
| Graph physics + render | CVDisplayLink thread | NSView, not SwiftUI observation context |
| Embedding batch compute | Metal command queue (GPU) | Async via `MTLCommandBuffer.commit()` |
| Agent loop (Rust) | Dedicated Rust thread pool (Tokio) | Bridges to Swift via UniFFI callbacks |
| Semantic search | `@MainActor` (all `@Observable` classes) | Awaited from Task context |
| Activity tracking | `@MainActor` | Lightweight, no GPU |
| SwiftData persistence | SwiftData background context | Separate `ModelContext` per service |

The `await MainActor.run` removals in Phase 2 were correct: all `@Observable` services are `@MainActor`-isolated, so method calls from within the same actor context do not need an actor hop.[^12][^9]

### 10.3 Swift Performance Best Practices Applied

Per WWDC 2025 Swift guidance:[^9]
- Pre-allocated collections where final size is known (e.g., `lineInfos.reserveCapacity(lineCount)`)
- Replaced `flatMap + prefix` chains with direct iteration in `OutlineParser`
- Eliminated intermediate array creation in `gatherAndHighlightContext()`
- `@Observable` over `ObservableObject` throughout — reduces observation granularity from per-object to per-property[^12]

***

## 11. Hermes v0.7.0 Features — Adoption Status

| Hermes Feature | Status in Epistemos |
|---|---|
| Dual-file memory (MEMORY.md + USER.md) | ✅ Ported to Rust `memory_tool.rs` |
| Entry delimiter (§) + char limits | ✅ Ported |
| File locking for concurrent safety | ✅ Ported (fcntl) |
| Threat scanning (injection/exfiltration) | ✅ Ported |
| Frozen snapshot for system prompt | ✅ Ported |
| Skills (SKILL.md YAML frontmatter) | ✅ Ported to `skills_tool.rs` |
| Pluggable memory provider architecture[^1] | ⚠️ Trait defined, only file backend implemented |
| Credential pool rotation | ❌ Not implemented |
| Inline diff previews before file writes | ❌ Not implemented |
| Stale file detection | ❌ Not implemented |
| Improved approval state machine | ⚠️ Semaphore-based (works, not a full state machine) |

The three unimplemented Hermes features (credential rotation, inline diffs, stale file detection) are medium-priority additions. Credential pool rotation is especially valuable for high-throughput agent sessions where a single API key may hit rate limits.

***

## 12. OpenClaw Architecture — Relevant Patterns

OpenClaw's macOS app acts as a menu-bar companion that owns permissions and manages a local Gateway via `launchd`. Its key architectural insight relevant to Epistemos:[^4]

- **Gateway as optional launchd service** — The Gateway (agent runtime) can be managed as a `LaunchAgent` rather than a child process. This maps directly to what Epistemos is doing with Hermes: making it optional and eventually replacing it with the in-process Rust runtime
- **PeekabooBridge for UI automation** — OpenClaw's `PeekabooBridge` is their accessibility tree bridge, analogous to the `ComputerUseBridge` design proposed in §6.3
- **Remote mode** — OpenClaw supports connecting to a Gateway over SSH/Tailscale. This is a future expansion opportunity for Epistemos — running the agent core remotely on a more powerful machine

***

## 13. Summary: What Works, What's Gaps, What's Next

### What Works Well
- Full 6-factor semantic search with graph weights, complexity, activity, and recency
- Rust agent loop wired to main chat with 4 cloud providers and 19 tools
- Meaning anchors auto-generated on chat exit and inserted as graph nodes
- Chat unification across 5 surfaces (SDChat persists everything)
- Native NSPopover AI suggestions with line-number attribution
- Sidebar rebuild guard eliminating most stutter from prose editor saves
- Memory and skills ported from Hermes v0.7.0 with threat scanning
- Build is clean: zero errors, zero warnings in Epistemos code

### Critical Gaps
1. Computer use AX tree not implemented (screenshots only)
2. Sub-agent orchestration not wired
3. MCP client absent
4. EmbeddingService still has one non-shared instance
5. Pluggable memory backend is a stub (only file backend)

### Recommended Next Session Order
1. Implement `ComputerUseBridge.swift` with full AXUIElement traversal
2. Wire per-provider computer use routing (Claude native, Gemini via bridge)
3. Sub-agent foundation in `bridge.rs` + `SubAgentCoordinator.swift`
4. Credential pool rotation in Rust (map `[String]` per provider, rotate on 429)
5. Inline diff previews for `file_ops` write/patch operations
6. MCP server discovery and tool registration

---

## References

1. [Hermes Agent V0.7.0 Modular Memory System Makes AI Learn ...](https://goldstarlinks.com/hermes-agent-v0-7-0-modular-memory-system/) - Hermes Agent V0.7.0 modular memory system introduces a plug-in memory architecture that lets you swa...

2. [Block Launches Open-Source AI Framework Codename Goose - InfoQ](https://www.infoq.com/news/2025/02/codename-goose/) - Block's Open Source Program Office has launched Codename Goose, an open-source, non-commercial AI ag...

3. [Hermes Agent V0.7.0 Modular Memory System Redefines Long ...](https://www.linkedin.com/pulse/hermes-agent-v070-modular-memory-system-redefines-long-term-goldie-3dkyc) - 7.0 modular memory system changes how AI agents store knowledge because memory is no longer temporar...

4. [macOS App - OpenClaw Docs](https://docs.openclaw.ai/platforms/macos) - The macOS app is the menu‑bar companion for OpenClaw. It owns permissions, manages/attaches to the G...

5. [goose Architecture - GitHub Pages](https://block.github.io/goose/docs/goose-architecture/) - Goose, an open source AI Agent, builds upon the basic interaction framework of Large Language Models...

6. [Calling Rust code from Swift on iOS and macOS - StrathWeb](https://www.strathweb.com/2023/07/calling-rust-code-from-swift/) - UniFFI can be used to elegantly create C bindings and generate bridge C# code that allows for callin...

7. [Multiplatform with Rust on iOS - by Tjeerd in 't Veen](https://mobilesystemdesign.substack.com/p/multiplatform-with-rust-on-ios-2c4) - UniFFI can also generate FFI code for Kotlin and even Python. ... UniFFI examines our Rust code and ...

8. [goose Roadmap (July 2025) #3319 - GitHub](https://github.com/block/goose/discussions/3319) - Support the Full MCP Standard. Goose was among the first agents to support the Model Context Protoco...

9. [WWDC 2025 - Improve memory usage and performance with Swift](https://dev.to/arshtechpro/wwdc-2025-improve-memory-usage-and-performance-with-swift-4kbd) - Performance optimization in Swift requires a systematic approach that goes beyond micro-optimization...

10. [Let Claude use your computer from the CLI - Claude Code Docs](https://code.claude.com/docs/en/computer-use) - Enable computer use in the Claude Code CLI so Claude can open apps, click, type, and see your screen...

11. [I built a tool that lets Claude Code see and interact with desktop app ...](https://www.reddit.com/r/ClaudeAI/comments/1sbdq3d/i_built_a_tool_that_lets_claude_code_see_and/) - This is a Claude and Claude Code discussion subreddit to help you make a fully informed decision abo...

12. [Unveiling the Observation and SwiftData Frameworks](https://fatbobman.com/en/posts/new-frameworks-new-mindset/) - Today, I will focus on the concept of “New Mindset”, and introduce two new frameworks launched last ...

