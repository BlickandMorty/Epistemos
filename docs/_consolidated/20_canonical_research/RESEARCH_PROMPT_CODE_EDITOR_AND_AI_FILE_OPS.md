# Research Prompt: Native Code Editor + AI File Operations + Agent Bridge

> **Index status**: CANONICAL-RESEARCH — 2026-04-06 code editor polish + AI file operations research prompt (minimap + language switching + bracket matching + indent guides).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



**For:** Claude Code / Kimi Code / Deep Research
**Date:** 2026-04-06
**Context:** This is the continuation research prompt for Epistemos v1. Covers three interconnected features that together create a "PKM × IDE × AI" fusion product.

---

## FEATURE 1: Native Code Editor Polish + Minimap

### What's built (this session):
- `CodeEditorView.swift` — NSViewRepresentable wrapping CodeTextView (NSTextView subclass)
- Tree-sitter syntax highlighting via Rust FFI (`markdown_parse_code_tokens`) — 14 languages
- Line number gutter (`LineNumberGutter`) synchronized with scroll
- Status bar (line/col/language)
- `CodeLanguage.detect(from:)` — 30+ file extensions → language mapping
- Tab key inserts 4 spaces, no word wrap, horizontal scroll

### What's missing (build next):
1. **Minimap** — scaled-down overview on the right side (like Xcode/VS Code). Colored rectangles per token type, viewport indicator, click-to-scroll. See existing `MinimapView` pattern in VS Code (Canvas-based) or Xcode (Core Graphics).
2. **Editor switching** — `NoteDetailWorkspaceView.swift` needs to check `CodeLanguage.detect(from: page.relativePath)` and show `CodeEditorView` instead of `ProseEditorRepresentable2` when it's a code file.
3. **Current line highlight** — subtle background on the line where the cursor sits.
4. **Bracket matching** — highlight matching `{}`, `[]`, `()` when cursor is adjacent.
5. **Indent guides** — faint vertical lines at each indent level.
6. **Breadcrumb bar** — file path breadcrumbs at the top (like the Xcode screenshot).
7. **More languages** — add tree-sitter grammars for: YAML, TOML, Ruby, Java/Kotlin, SQL, Lua, GDScript, Zig, WGSL/GLSL/Metal shaders. Some may need new Cargo dependencies.

### Key files to read:
- `Epistemos/Views/Notes/CodeEditorView.swift` (the new editor)
- `graph-engine/src/code_highlight.rs` (tree-sitter tokenizer)
- `Epistemos/Views/Notes/MarkdownContentStorage.swift` (existing code block highlighting — reuse patterns)
- `Epistemos/Views/Notes/ProseTextView2.swift` (existing editor — for comparison)
- `Epistemos/Theme/EpistemosTheme.swift` lines 804-837 (token color mapping)

---

## FEATURE 2: AI File Operations (The Killer Feature)

### Vision:
Every chat (mini chat, main chat, ask bar) can READ, EDIT, and REPLACE the active file. The model sees the file content, proposes edits as structured tool calls, and the app applies them live — like Cursor but native and integrated with the knowledge graph.

### Architecture:

```
User types: "add error handling to the fetchData function"
    ↓
Chat sends: <note>{file content}</note> + <knowledge_graph>{neighbors}</knowledge_graph> + question
    ↓
Cloud model returns: tool_use block → edit_file(startLine: 42, endLine: 45, replacement: "...")
    ↓
App applies: CodeTextView.replaceRange(42...45, with: replacement)
    ↓
User sees: live diff in the editor, can accept/reject
```

### What exists:
- `NoteChatState.noteBodyProvider` — reads the active file ✓
- `NoteChatState.graphStateProvider` — reads graph neighborhood ✓
- `<knowledge_graph>` context injection in prompts ✓
- `generateStructured<T>` on CloudConfigurableLLMClient ✓ (can return structured tool calls)
- `ArtifactExtractor` — extracts code blocks from responses ✓

### What to build:

#### 2a. `noteBodyWriter` closure
Mirror of `noteBodyProvider`. Set by the editor coordinator when the chat is created.
```swift
var noteBodyWriter: ((String) -> Void)?            // replace entire file
var noteRangeWriter: ((Range<Int>, String) -> Void)? // replace line range
```

#### 2b. File operation tool definitions
Define as `CloudJSONSchema` objects that get sent with structured output requests:
```json
{
  "name": "edit_file",
  "description": "Edit specific lines in the active file",
  "schema": {
    "type": "object",
    "properties": {
      "start_line": {"type": "integer"},
      "end_line": {"type": "integer"},
      "replacement": {"type": "string"},
      "explanation": {"type": "string"}
    },
    "required": ["start_line", "end_line", "replacement"]
  }
}
```

Also: `replace_file`, `insert_at_line`, `delete_lines`, `read_file_range`

#### 2c. Tool execution engine
When the model returns a tool_use response:
1. Parse the tool name + arguments
2. Validate (line numbers in range, etc.)
3. Show a diff preview in the chat (green=added, red=removed)
4. Auto-apply OR wait for user confirmation (configurable)
5. Apply to the editor via `noteRangeWriter`

#### 2d. Diff preview in chat
When the model proposes a file edit, show it as a special artifact:
```
┌─ Edit: lines 42-45 ──────────────────────┐
│ - let data = try await fetch(url)         │ (red)
│ + do {                                    │ (green)
│ +     let data = try await fetch(url)     │
│ + } catch {                               │
│ +     logger.error("Fetch failed: \(e)")  │
│ +     throw AppError.networkFailed        │
│ + }                                       │
│                    [Apply] [Reject]        │
└───────────────────────────────────────────┘
```

#### 2e. Ask bar integration
The ask bar (toolbar quick-ask) should be able to trigger file ops too:
- "fix the bug on line 42" → reads file, proposes edit
- "add imports for Foundation and SwiftUI" → inserts at top
- "rename fetchData to loadContent" → find/replace across file

### Key files to read:
- `Epistemos/State/NoteChatState.swift` (noteBodyProvider, graphStateProvider)
- `Epistemos/Engine/StructuredOutput.swift` (CloudJSONSchema, generateStructured)
- `Epistemos/Engine/LLMService.swift` (generateStructuredOpenAI, generateStructuredAnthropic)
- `Epistemos/Views/Chat/MessageBubble.swift` (where to add diff preview)
- `Epistemos/Views/Chat/ArtifactBlockView.swift` (artifact rendering pattern)
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (wireNoteChatCallbacks)
- `Epistemos/Views/Notes/CodeEditorView.swift` (new code editor)

---

## FEATURE 3: Agent Bridge (Surgical Extraction)

### This is covered in:
`docs/RESEARCH_PROMPT_CLOUD_NATIVE_AGENT_BRIDGE.md`

### Summary of what to extract:
- **From Goose:** Provider trait, Message types, context compaction, streaming architecture
- **From Hermes:** Skills/prompt templates, procedural memory
- **From agent_core:** Prompt caching, compaction, security patterns
- **From omega-mcp:** Tool catalog → cloud function-calling tool definitions

### Key constraint:
All extractions must work WITHOUT the agent loop. They enhance the cloud chat, not build an agent. ShipGate.agentsEnabled stays false for release.

### Key files to read:
- `docs/GOOSE_REPLACEMENT_STRATEGY.md` (what to take from Goose)
- `docs/GOOSE_AGENT_RESEARCH.md` (detailed Goose analysis)
- `docs/HERMES_INTEGRATION_RESEARCH.md` (Hermes architecture)
- `agent_core/src/agent_loop.rs` (compaction patterns)
- `agent_core/src/prompt_caching.rs` (caching patterns)
- `omega-mcp/src/catalog.rs` (tool definitions)
- `hermes-agent/hermes/skills/` (skill prompt templates)
- `Epistemos/App/AppBootstrap.swift` (ShipGate)

---

## FEATURE 4: Hide Agent UI

### Every visible agent surface must be:
- **Removed** if dead code
- **Gated** behind `ShipGate.agentsEnabled` if useful for dev
- **Repurposed** if the UI pattern is good for cloud chat

### Files to audit:
- `Epistemos/Views/AgentPanelContainer.swift`
- `Epistemos/Views/AgentSessionPanel.swift`
- `Epistemos/Views/HermesSkillsView.swift`
- `Epistemos/Views/HermesExecutionGraphView.swift`
- Any menu items, toolbar buttons, settings entries referencing agents

---

## 20 FILES FOR DEEP RESEARCH

These are the most important files to read for implementing all 4 features:

### Code Editor + AI Ops (your codebase):
1. `Epistemos/Views/Notes/CodeEditorView.swift` — the new code editor
2. `Epistemos/Views/Notes/ProseTextView2.swift` — existing editor architecture
3. `Epistemos/Views/Notes/MarkdownContentStorage.swift` — syntax highlighting pipeline
4. `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` — editor ↔ SwiftUI bridge
5. `Epistemos/State/NoteChatState.swift` — chat ↔ editor integration
6. `Epistemos/Engine/StructuredOutput.swift` — structured output types
7. `Epistemos/Engine/LLMService.swift` — cloud provider implementations
8. `Epistemos/Views/Chat/ArtifactBlockView.swift` — artifact rendering
9. `Epistemos/Views/Chat/MessageBubble.swift` — chat message rendering
10. `graph-engine/src/code_highlight.rs` — tree-sitter tokenizer

### Agent Bridge (your codebase):
11. `docs/GOOSE_REPLACEMENT_STRATEGY.md` — Goose adoption plan
12. `docs/GOOSE_AGENT_RESEARCH.md` — detailed Goose analysis
13. `agent_core/src/prompt_caching.rs` — prompt caching to extract
14. `agent_core/src/compaction.rs` — context compaction to extract
15. `omega-mcp/src/catalog.rs` — tool catalog to convert to cloud tools

### External (clone/fetch):
16. `github.com/block/goose/crates/goose/src/providers/base.rs` — Provider trait
17. `github.com/block/goose/crates/goose/src/message.rs` — Message types
18. `github.com/block/goose/crates/goose/src/agents/truncate.rs` — context compaction
19. Cursor's approach to AI file editing (research online — their "apply" mechanism)
20. `conversation_export_full.md` — GPT's full hardening + ship prompt (in repo root)

---

## BRAINSTORM PRESERVATION

### From this session (Claude Code 2026-04-06):

**Cloud Artifact Pipeline (completed):**
- Phase 1+2: Structured output — OpenAI json_schema + Anthropic tool_use
- Phase 3: Artifact extraction from responses → SDMessage persistence
- Phase 4: ArtifactBlockView interactive cards with copy/export
- Graph context injection: `<knowledge_graph>` with 20 connected nodes

**Graph Hardening (completed):**
- Label cache (3%/5% threshold), glow overdraw cap (24 instances)
- Selection-only glow, selection-aware labels
- Triple buffering + semaphore, viewport culling disabled during physics
- Observation throttle (>2px), semantic neighbor data race fix
- sRGB pixel format, camera lambda 6.5, node size scaling

**Features (completed):**
- Water-bead node shader + wobble
- Graph title overlay (typewriter + blur reveal)
- Pinned inspector panels (follow nodes, persist across deselection)
- Ship gate (SHIP_MODE=release excludes agent crates)
- SDF labels (screen-constant sizing, dead zone, per-type thresholds)

**Code Editor (built this session):**
- CodeEditorView with tree-sitter highlighting, line numbers, status bar
- 14 languages, 30+ file extensions detected
- Missing: minimap, bracket matching, indent guides, editor switching

**AI File Operations (brainstormed, not built):**
- noteBodyWriter + noteRangeWriter closures
- Tool definitions: edit_file, replace_file, insert_at_line, delete_lines
- Diff preview artifact in chat
- Ask bar integration for inline edits
- "Like Cursor but native and integrated with your knowledge graph"

**Agent Bridge (researched, not built):**
- Extract Provider trait, Message types, compaction from Goose
- Extract skill prompts, procedural memory from Hermes
- Extract prompt caching, compaction from agent_core
- Convert omega-mcp tool catalog to cloud tool_use definitions
- All extractions work WITHOUT agent loop
