# Epistemos v1 — Definitive Implementation Blueprint

> **Index status**: SUPERSEDED-HISTORICAL — April 6, 2026 V1 blueprint. Superseded by [`docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`](IMPLEMENTATION_PLAN_FROM_ADVICE.md) (4-model council synthesis from 2026-04-22) + [`docs/MASTER_BUILD_PLAN.md`](MASTER_BUILD_PLAN.md) (operational doctrine). The `ShipGate.agentsEnabled = false` constraint reflects the V1 release moment; V1.5+ has different ship gates. **Not canonical for current execution.** Classified in [`docs/_INDEX.md §9`](_INDEX.md).

**Synthesized from**: 5 deep research reports, 20 codebase files, Goose/Hermes/agent_core analysis
**Date**: 2026-04-06
**Constraint**: `ShipGate.agentsEnabled = false` for release. Zero agent loops. Cloud chat only.

---

## The Vision in One Sentence

Epistemos fuses **Obsidian's knowledge graph** with **Cursor's AI file operations** and **Claude.ai's artifact system** into a single native macOS app where every note is a living document the AI can read, edit, and link — grounded in your personal knowledge base.

---

## Architecture Overview: Three Pillars

```
┌──────────────────────────────────────────────────────────────────┐
│                    PILLAR 1: NATIVE CODE EDITOR                  │
│  CodeEditorView + tree-sitter + minimap + bracket matching       │
│  + indent guides + current line highlight + breadcrumbs          │
│  + editor switching (prose ↔ code based on file extension)       │
├──────────────────────────────────────────────────────────────────┤
│                    PILLAR 2: AI FILE OPERATIONS                  │
│  noteBodyWriter/noteRangeWriter closures                         │
│  → Tool definitions (edit_file, insert_at_line, delete_lines)    │
│  → FileEditExecutor (validate → diff → preview → apply)          │
│  → DiffPreviewView in chat (green/red, Apply/Reject)             │
│  → Ask bar integration (single-line quick edits)                 │
│  → Skills system (code review, refactor, document, explain)      │
├──────────────────────────────────────────────────────────────────┤
│                    PILLAR 3: CLOUD CHAT HARDENING                │
│  ContentBlock-based messages (not flat String)                   │
│  → Prompt caching (90% cost reduction on Anthropic)              │
│  → Context compaction (80% threshold, head-tail strategy)        │
│  → Artifact versioning (update-in-place, version history)        │
│  → Vault tool use (search_notes, create_note, link_nodes)        │
│  → Extended thinking trail (collapsible reasoning UI)            │
│  → YAML graph context (54% accuracy improvement over XML)        │
│  → Streaming JSON for live artifact hydration                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## Phase 0: Structural Foundation (MUST DO FIRST)

### 0a. Upgrade ChatMessage to Content Blocks

**Why**: Every downstream feature depends on this. Flat `content: String` cannot represent tool calls, thinking blocks, or multi-part responses. This is the single highest-leverage structural change.

**The type** (in a new `LLMMessage.swift` or refactored `ChatMessage`):

```swift
enum MessageContentBlock: Codable, Sendable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: AnyCodable])
    case toolResult(toolUseId: String, content: String, isError: Bool)
    case thinking(String)           // Anthropic extended thinking
    case image(base64: String, mediaType: String)
}
```

**SDMessage migration**: Add `contentBlocks: Data?` (JSON-encoded `[MessageContentBlock]`), keep `content: String` as a computed convenience that joins `.text` blocks.

**Stream type upgrade** — replace `AsyncThrowingStream<String, Error>` with:

```swift
enum CloudStreamChunk: Sendable {
    case textDelta(String)
    case toolCallDelta(id: String, name: String, argumentsDelta: String)
    case thinking(String)
    case usage(inputTokens: Int, outputTokens: Int, cacheReadTokens: Int, cacheWriteTokens: Int)
    case done(stopReason: String)
}
```

**Files**: `ChatMessage.swift` (or equivalent), `SDMessage.swift`, `LLMService.swift` (stream return type), `CloudLLMClient.swift` (SSE parsing), `NoteChatState.swift` (stream consumption), `MessageBubble.swift` (rendering)

### 0b. Graph Context Format: XML → YAML

Research shows YAML achieves 54% higher reasoning accuracy and ~10% fewer tokens than XML for dense relational data. Switch `buildGraphContext()` output:

```yaml
knowledge_graph:
  - id: "abc123"
    title: "Quantum Computation"
    tags: [physics, computing]
    related: ["def456", "ghi789"]
    summary: "Overview of qubit state management..."
```

Keep XML for Anthropic-only conversations (Claude processes XML natively); use YAML for OpenAI/Gemini. Provider-aware formatting.

---

## Phase 1: Code Editor Polish (1-2 days)

### 1a. Editor Switching in NoteDetailWorkspaceView

```swift
// In noteEditorSurface(page:):
if let path = page.relativePath, let lang = CodeLanguage.detect(from: path) {
    CodeEditorView(initialContent: page.body ?? "", language: lang)
} else {
    ProseEditorView(page: page, isEditable: true)
}
```

**File**: `NoteDetailWorkspaceView.swift` line ~962

### 1b. Current Line Highlight

Override `drawBackground(in:)` in `CodeTextView`. Use `NSLayoutManager.setTemporaryAttributes` — NEVER modify `NSTextStorage` attributes (causes cursor jumps). Fill the line fragment rect with `theme.currentLineHighlightColor.withAlphaComponent(0.08)`. Subscribe to `didChangeSelectionNotification` → `needsDisplay = true`.

### 1c. Bracket Matching

On selection change: check character at cursor ± 1. If bracket, scan with depth counter (capped at ±10,000 chars for large files). Apply via `layoutManager.setTemporaryAttributes([.backgroundColor: matchColor])`. Clear on next selection change.

### 1d. Indent Guides

In the same `drawBackground` override: enumerate visible line fragments, count leading spaces ÷ 4, draw 0.5pt vertical `NSBezierPath` at each indent level with `separatorColor.withAlphaComponent(0.15)`.

### 1e. Minimap (MinimapView: NSView)

Architecture: Core Graphics canvas drawing colored rectangles per token type (VS Code pattern when `renderCharacters = false`). NOT a second NSTextView.

- `tokenRects: [(rect: CGRect, color: NSColor)]` — rebuilt on document change only
- Viewport indicator: translucent rect tracking `scrollView.contentView.bounds`
- Click-to-scroll: map click Y → proportional scroll offset
- Layout: fixed 80pt width, sibling to the scroll view (not inside it)
- Rebuild token rects asynchronously on `textDidChange`, not on scroll

### 1f. Additional Tree-Sitter Languages

Add to `graph-engine/Cargo.toml`: `tree-sitter-yaml`, `tree-sitter-toml`, `tree-sitter-ruby`, `tree-sitter-java`, `tree-sitter-kotlin`, `tree-sitter-sql` (DerekStride), `tree-sitter-lua`, `tree-sitter-zig`. Register in `code_highlight.rs` dispatch table. Expose same FFI pattern.

### 1g. Breadcrumb Bar

A horizontal `NSStackView` above the editor showing file path components. Each segment is a clickable `NSButton` that navigates the sidebar. Reuses the knowledge graph node title for vault-linked files.

---

## Phase 2: AI File Operations — The Killer Feature (3-5 days)

### 2a. Writer Closures on NoteChatState

Mirror the existing `noteBodyProvider` pattern:

```swift
// NoteChatState.swift — add alongside noteBodyProvider:
var noteBodyWriter: ((String) -> Void)?
var noteRangeWriter: ((ClosedRange<Int>, String) -> Void)?  // 1-indexed line range
```

Wire in `CodeEditorView`'s coordinator (same pattern as `ProseEditorRepresentable2.wireNoteChatCallbacks()`):

```swift
chatState.noteBodyWriter = { [weak textView] newContent in
    guard let tv = textView else { return }
    tv.shouldChangeText(in: NSRange(location: 0, length: tv.string.utf16.count),
                        replacementString: newContent)
    tv.textStorage?.replaceCharacters(in: NSRange(location: 0, length: tv.string.utf16.count),
                                       with: newContent)
    tv.didChangeText()  // registers with NSUndoManager
}

chatState.noteRangeWriter = { [weak textView] lineRange, replacement in
    guard let tv = textView else { return }
    let nsRange = tv.nsRange(forLineRange: lineRange)  // helper using layoutManager
    tv.shouldChangeText(in: nsRange, replacementString: replacement)
    tv.textStorage?.replaceCharacters(in: nsRange, with: replacement)
    tv.didChangeText()
}
```

**Critical**: Always use `shouldChangeText → replaceCharacters → didChangeText` triad. This registers with `NSUndoManager` so ⌘Z works on AI edits. Never bypass this.

### 2b. Tool Definitions (FileEditTool namespace)

Add to `StructuredOutput.swift`:

```swift
enum FileEditTool {
    static let editFile = CloudJSONSchema(name: "edit_file", ...)
    static let replaceFile = CloudJSONSchema(name: "replace_file", ...)
    static let insertAtLine = CloudJSONSchema(name: "insert_at_line", ...)
    static let deleteLines = CloudJSONSchema(name: "delete_lines", ...)
    static let all: [CloudJSONSchema] = [editFile, replaceFile, insertAtLine, deleteLines]
}
```

Key schemas: `edit_file` has `start_line` (1-indexed), `end_line` (inclusive), `replacement`, `explanation`. For Anthropic: `tool_choice: { "type": "any" }`. For OpenAI: `response_format.json_schema` with `strict: true`.

### 2c. FileEditExecutor

```swift
class FileEditExecutor {
    static func apply(operations: [FileEditOperation],
                      writer: (ClosedRange<Int>, String) -> Void,
                      lineCount: Int) throws {
        // CRITICAL: Sort descending by start_line so line numbers stay valid
        let sorted = try operations
            .map { try $0.validated(against: lineCount); return $0 }
            .sorted { $0.startLine > $1.startLine }
        for op in sorted { writer(op.startLine...op.endLine, op.replacement) }
    }
}
```

### 2d. DiffPreviewView in Chat

Render inside `MessageBubble` when a message contains `.toolUse` blocks with file-op tool names. Green background for additions, red for removals. "Apply" and "Reject" buttons. Auto-apply mode (configurable): applies after 500ms preview with dismissable "Undo" banner.

### 2e. Prompt Construction for File Edits

```
You are editing <filename>. The active file contains:

<active_file path="Sources/MyFile.swift" lines="142" language="swift">
1 | import Foundation
2 | import SwiftUI
...
</active_file>

<knowledge_graph>
{YAML-formatted 20 connected nodes}
</knowledge_graph>

Respond ONLY with a single tool call. Do not explain outside the tool's explanation field.
```

Line-numbering the file is critical — maps directly to `start_line`/`end_line`, dramatically reduces off-by-one errors.

### 2f. Ask Bar Integration

The ask bar (toolbar quick-ask) should detect file-edit intent:
- Contains "line N" → prepend `read_file_range(N-2, N+2)` for context
- Contains "add imports" → map to `insert_at_line(1, ...)`
- Contains "rename X to Y" → client-side find/replace first, model verifies
- Short natural language → model auto-selects the right tool

---

## Phase 3: Skills System (1-2 days)

### 3a. SkillPromptLibrary

Extract from `hermes-agent/hermes/skills/` as static prompt fragments:

```swift
enum EditorSkill: String, CaseIterable, Identifiable {
    case codeReview = "Review"
    case addErrorHandling = "Harden"
    case writeTests = "Test"
    case explainCode = "Explain"
    case refactorCode = "Refactor"
    case documentCode = "Document"
    case renameSymbol = "Rename"

    var id: String { rawValue }
    var systemPrompt: String { ... }  // populated from hermes skill templates
    var toolSubset: [CloudJSONSchema] { ... }  // which file-op tools to expose
    var icon: String { ... }  // SF Symbol name
}
```

### 3b. Skill Chip Selector in Ask Bar

Repurpose `HermesSkillsView`'s chip-grid layout as a generic `ChipGridView<T>` shown above the ask bar input when a code file is active. Selecting a skill prepends its system prompt and limits tools to `toolSubset`. The UI pattern:

```
┌─────────────────────────────────────────────┐
│ [Review] [Harden] [Test] [Explain] [Refactor] │
├─────────────────────────────────────────────┤
│ > fix the null check on line 42             │
└─────────────────────────────────────────────┘
```

### 3c. User-Created Skills

Allow users to create custom skills stored as `.skill.md` files in the vault. Each file follows the Hermes progressive disclosure format:
- **Level 0** (metadata): name, description, tags (~100 words)
- **Level 1** (instructions): system prompt, constraints (<500 lines)
- **Level 2** (resources): examples, templates (unbounded)

The skill chip grid shows both built-in and user skills. Creating a skill: "New Skill" button opens a note editor pre-populated with the `.skill.md` template. The skill router (`skill_router.rs` TF-IDF) can auto-suggest relevant skills based on the file content.

---

## Phase 4: Cloud Chat Hardening (3-5 days)

### 4a. Prompt Caching (Priority 1 — 90% cost reduction on Anthropic)

**Structure system blocks as**: `[graph_context (stable, cached), system_prompt (semi-stable, cached), file_content (volatile, NOT cached)]`.

For Anthropic: add `anthropic-beta: prompt-caching-2024-07-31` header. Add `cache_control: { type: "ephemeral" }` on the last stable content block.

```swift
func buildAnthropicSystem(graphContext: String, systemPrompt: String) -> [[String: Any]] {
    [
        ["type": "text", "text": graphContext,
         "cache_control": ["type": "ephemeral"]],   // cache boundary 1
        ["type": "text", "text": systemPrompt,
         "cache_control": ["type": "ephemeral"]],   // cache boundary 2
    ]
}
```

For OpenAI: caching is automatic for identical prefixes ≥1,024 tokens. Keep graph context as the first system message (never changes mid-conversation).

Track `cache_read_input_tokens` and `cache_creation_input_tokens` from responses. Display savings in token usage overlay.

### 4b. Migrate Anthropic Structured Output to Native

Replace forced `tool_use` with `output_format: { type: "json", schema: T.jsonSchema }` + `anthropic-beta: structured-outputs-2025-11-13` header. This unlocks extended thinking for structured output requests (forced `tool_use` blocks thinking).

### 4c. Context Compaction (80% threshold, head-tail strategy)

```swift
class ChatCompactor {
    static func shouldCompact(messages: [SDMessage], contextLimit: Int) -> Bool {
        let est = messages.reduce(0) { $0 + ($1.content.count / 4) }
        return Double(est) / Double(contextLimit) > 0.80
    }

    static func compact(messages: [SDMessage],
                        using llm: CloudConfigurableLLMClient) async throws -> [SDMessage] {
        let recent = Array(messages.suffix(8))  // keep last 4 turns verbatim
        let older = Array(messages.dropLast(8))
        let summary = try await llm.generate(
            system: Self.summarizationPrompt,
            messages: older.map(\.asLLMMessage)
        )
        return [SDMessage(role: .system, content: "[Context summary]\n\(summary)")] + recent
    }
}
```

Use Haiku/gpt-4o-mini for the summary call. Show subtle toast "context was summarized". The compaction marker `[Context summary]` enables detection on subsequent compactions (fold the old summary into the new one — iterative, not destructive). **Critical**: When compacting, preserve any thinking blocks from the recent window. Only the older messages (being summarized) lose their thinking blocks — the summary captures their decisions. Never strip thinking blocks from messages that remain in the active window.

### 4d. Artifact Versioning (update-in-place)

Add `artifactId: UUID` and `parentArtifactId: UUID?` to `Artifact`. When the user says "update the JSON" / "add a field" / "change X to Y":
1. Detect update intent (heuristic: references existing artifact)
2. Inject `<current_artifact>` into context with the existing content
3. Model returns a replacement or a search/replace delta
4. UI updates the existing artifact card in-place, adds old version to history stack
5. Version badge + tap-to-navigate in `ArtifactBlockView` footer

Adopt Claude's "Replace-is-all-you-need" pattern: `search_string` + `replacement_string` for surgical updates. Massive token savings for large artifacts.

### 4e. Vault Tool Use (the PKM differentiator)

Expose as cloud function-calling tools (NOT MCP, no subprocess):

```swift
let vaultTools: [CloudTool] = [
    .init(name: "search_notes", description: "Search the knowledge vault",
          inputSchema: { "query": string, "limit": integer }),
    .init(name: "create_note", description: "Create a new vault note",
          inputSchema: { "title": string, "content": string, "tags": [string] }),
    .init(name: "link_nodes", description: "Link two notes bidirectionally",
          inputSchema: { "sourceTitle": string, "targetTitle": string }),
]
```

When model calls `search_notes`, execute locally against the vault index and return results as `tool_result`. Sanitize returned note content (strip model-instruction-like patterns — extracted from `agent_core/security.rs`). Require user confirmation for write operations (create/link).

This makes Epistemos feel like "Claude.ai with actual memory" — the model can search your notes and create new ones mid-conversation.

### 4f. Extended Thinking Trail

When provider is Anthropic: enable `thinking: { type: "enabled", budgetTokens: 8000 }` for complex queries. Stream `thinking` content blocks into a collapsible "Reasoning" disclosure group above the answer bubble. Rebrand `AgentReasoningView` → `AnalyticalTrailView`.

### 4g. Streaming JSON for Live Artifact Hydration

For OpenAI structured output streaming: forward every `text_delta` chunk to the UI immediately (stream everything — never buffer). Simultaneously accumulate into a parse buffer and attempt partial JSON decode at each complete key-value pair. Emit partial `StructuredGenerationResult` alongside the raw text stream. `ArtifactBlockView` renders field-by-field as they arrive while the raw text continues flowing. Eliminates the blank card during long structured generation. The accumulation is for parsing only — tokens are always forwarded immediately to the delegate.

---

## Phase 5: Agent UI Disposition (1 day)

| File | Action | Rationale |
|------|--------|-----------|
| `AgentPanelContainer.swift` | Gate `ShipGate.agentsEnabled` | Full agent surface |
| `AgentSessionPanel.swift` | Repurpose as `ChatSessionPanel` | Session management UI is reusable |
| `HermesSkillsView.swift` | Extract to `ChipGridView<EditorSkill>` | UI pattern is good, rebrand |
| `HermesExecutionGraphView.swift` | Gate `ShipGate.agentsEnabled` | Pure agent UI |
| Agent status indicator | Remove | No agents in v1 |
| "Teach Hermes" feedback | Repurpose → thumbs up/down preference learning | UX correct, rewire backend |
| Agent capability badge on models | Remove | Misleading without agents |
| MCP tool execution log | Gate `ShipGate.agentsEnabled` | Dev-only |
| Hermes memory view | Gate `ShipGate.agentsEnabled` | Replaced by preference tracker |
| ReasoningExpander | Repurpose → `AnalyticalTrailView` | Thinking blocks are cloud chat feature |
| ToolApprovalBanner | Repurpose → vault tool confirmation | Safety for cloud tool_use |

---

## Execution Order (by dependency + impact)

```
Week 1: Foundation + Editor
  Day 1: [0a] Content blocks upgrade (unlocks everything)
  Day 2: [0b] YAML graph context + [1a] Editor switching
  Day 3: [1b] Current line highlight + [1c] Bracket matching + [1d] Indent guides
  Day 4: [2a] noteBodyWriter/noteRangeWriter + [2b] Tool definitions

Week 2: AI Ops + Skills
  Day 5: [2c] FileEditExecutor + [2d] DiffPreviewView
  Day 6: [2e] Prompt construction + [2f] Ask bar integration
  Day 7: [3a] SkillPromptLibrary + [3b] Skill chip selector
  Day 8: [3c] User-created skills (.skill.md format)

Week 3: Cloud Hardening
  Day 9:  [4a] Prompt caching + [4b] Native Anthropic structured output
  Day 10: [4c] Context compaction + [4d] Artifact versioning
  Day 11: [4e] Vault tool use + [4f] Extended thinking trail
  Day 12: [5] Agent UI disposition + [1e] Minimap

Week 4: Polish
  Day 13: [4g] Streaming JSON + [1f] Additional tree-sitter languages
  Day 14: [1g] Breadcrumb bar + preference learning foundation
```

---

## Key Technical Constraints

1. **Apply operations bottom-to-top**: Multiple `edit_file` ops must sort by `start_line` descending before applying. Top-to-bottom shifts line numbers.
2. **NSTextStorage vs NSLayoutManager**: Line highlight and bracket matching use `setTemporaryAttributes` on the layout manager. Never modify `NSTextStorage` attributes for visual-only effects (causes cursor jumps).
3. **Prompt cache invalidation**: Anthropic's cache is prefix-based. Any change to a prefix block invalidates everything after it. Structure: `[graph (stable), system (semi-stable), file (volatile)]`. Never reorder.
4. **Context window budget**: File + graph + system can consume 8-12K tokens. If `file_tokens + graph_tokens > 0.6 * contextWindow`, truncate graph to 5 most relevant neighbors.
5. **Thinking + tool_use**: Forced `tool_use` is incompatible with extended thinking on Anthropic. Native `output_format` fixes this.
6. **Undo safety**: All programmatic edits must go through the `shouldChangeText → replaceCharacters → didChangeText` triad. Users will ⌘Z AI edits.
7. **Threading**: Token estimation, diff computation, tree-sitter parsing → background. Any NSTextStorage/NSLayoutManager mutation → main thread only.
8. **Tree-sitter incremental parsing**: For files >2000 lines, use `Tree.edit()` for incremental re-parse after AI edits rather than full re-parse.

---

## What Makes This Different from Cursor/Obsidian/Claude.ai

| Feature | Cursor | Obsidian | Claude.ai | Epistemos |
|---------|--------|----------|-----------|-----------|
| Code editing with AI | ✅ | ❌ | ❌ | ✅ |
| Knowledge graph | ❌ | ✅ (plugins) | ❌ | ✅ (native Metal) |
| AI grounded in your notes | ❌ | ❌ | ❌ | ✅ |
| Artifact versioning | ❌ | ❌ | ✅ | ✅ |
| Skills system | ❌ | ❌ | ❌ | ✅ |
| Note creation from chat | ❌ | ❌ | ❌ | ✅ (vault tools) |
| Graph-aware context | ❌ | ❌ | ❌ | ✅ (20 neighbors) |
| Diff preview in chat | ✅ | ❌ | ❌ | ✅ |
| User-created skills | ❌ | ❌ | ❌ | ✅ (.skill.md) |
| Prompt caching | N/A | N/A | Built-in | ✅ (90% savings) |

The fusion point: **every chat is grounded in your knowledge graph, every edit is a graph-aware operation, every artifact can become a note, every note can become context**. No other tool does this.
