# Claude Code Session Prompt — Epistemos v1 Implementation

> **Index status**: CANONICAL-OPERATIONAL — PKM × IDE × AI session prompt (3 pillars: Code Editor + AI File Ops + Cloud Chat) with file map + CLAUDE.md constraints.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Paste this as your Claude Code session prompt. It contains everything needed to navigate the codebase and implement the three pillars: Native Code Editor, AI File Operations, and Cloud Chat Hardening.**

---

## SESSION OBJECTIVE

You are implementing the Epistemos v1 "PKM × IDE × AI" fusion — fusing Obsidian's knowledge graph with Cursor's AI file operations and Claude.ai's artifact system into one native macOS app. Every note is a living document the AI can read, edit, and link, grounded in the user's personal knowledge base.

Read `docs/IMPLEMENTATION_BLUEPRINT.md` for the full plan. Read `CLAUDE.md` for non-negotiable constraints. Read `docs/APP_ISSUES_AUTO_FIX.md` for open runtime issues to opportunistically fix.

---

## CRITICAL CONSTRAINTS (from CLAUDE.md)

- NO SIDECAR for INFERENCE — all inference in-process via Rust FFI or MLX-Swift
- REAL APIs ONLY — every endpoint verified against provider docs
- Zero test regressions against the test suite
- API keys in Keychain ONLY, never UserDefaults
- Use @Observable, not ObservableObject
- Use Swift Testing (@Test, #expect) for new tests
- All inference on background actors — never block @MainActor
- No try!, no force-unwraps, no print() in production paths
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync

---

## FILE MAP — Where Things Live

### Code Editor (Pillar 1)
- **The editor**: `Epistemos/Views/Notes/CodeEditorView.swift` — NSViewRepresentable + CodeTextView (NSTextView subclass) + LineNumberGutter
- **Language detection**: `CodeLanguage.detect(from:)` in CodeEditorView.swift — 30+ file extensions
- **Tree-sitter tokenizer**: `graph-engine/src/code_highlight.rs` — FFI function `markdown_parse_code_tokens`, 14 languages, token cache
- **Existing editor (reference)**: `Epistemos/Views/Notes/ProseTextView2.swift` — NSTextView subclass for prose
- **Syntax highlighting pipeline**: `Epistemos/Views/Notes/MarkdownContentStorage.swift` — 4-phase pipeline (structure → inline → code tokens)
- **Theme colors**: `Epistemos/Theme/EpistemosTheme.swift` lines 804-837 — token color mapping
- **Editor switching point**: `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` line ~962 — `noteEditorSurface(page:)` currently always shows ProseEditorView
- **Tree-sitter Cargo deps**: `graph-engine/Cargo.toml` — add new language crates here

### AI File Operations (Pillar 2)
- **Chat ↔ editor bridge**: `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` — `wireNoteChatCallbacks()` at line ~541 sets `noteBodyProvider`, `onStreamStart`, `onTokenFlush`, etc. — THIS IS THE PATTERN TO REPLICATE for CodeEditorView
- **Chat state machine**: `Epistemos/State/NoteChatState.swift` — `noteBodyProvider` at line 85, `submitQuery()`, `buildPrompt()`, display-paced token buffering. ADD `noteBodyWriter` and `noteRangeWriter` closures here
- **Structured output types**: `Epistemos/Engine/StructuredOutput.swift` — `CloudJSONSchema`, `StructuredGenerationResult<T>`, `JSONSchemaBuilder`. ADD `FileEditTool` namespace here
- **Cloud LLM gateway**: `Epistemos/Engine/LLMService.swift` — `CloudLLMClient` (18KB+), per-provider `generate*()` / `stream*()` / `generateStructured*()`. MODIFY stream return type to `CloudStreamChunk`
- **Artifact model**: `Epistemos/Models/Artifact.swift` — `Artifact` struct, `ArtifactKind` enum. ADD `.fileEdit` kind
- **Artifact extractor**: `Epistemos/Engine/ArtifactExtractor.swift` — regex-based extraction. ADD tool_use block detection
- **Artifact rendering**: `Epistemos/Views/Chat/ArtifactBlockView.swift` — interactive cards with copy/export
- **Message rendering**: `Epistemos/Views/Chat/MessageBubble.swift` — chat bubbles with artifacts, toolbar. ADD DiffPreviewView rendering
- **Triage routing**: `Epistemos/Engine/TriageService.swift` — routes queries by complexity to local/cloud

### Cloud Chat Hardening (Pillar 3)
- **Prompt caching reference**: `agent_core/src/prompt_caching.rs` — cache_control breakpoint placement (Anthropic API)
- **Context compaction reference**: `agent_core/src/compaction.rs` — 4-phase pipeline (boundary protect → tool replace → summarize → fold)
- **Tool catalog reference**: `omega-mcp/src/catalog.rs` — 32 tool definitions, macro-driven, JSON Schema strings
- **ShipGate**: `Epistemos/App/AppBootstrap.swift` lines 9-21 — `ShipGate.agentsEnabled` boolean
- **Agent UI surfaces**: `AgentPanelContainer.swift`, `AgentSessionPanel.swift`, `HermesSkillsView.swift`, `HermesExecutionGraphView.swift`

### Skills System
- **Hermes skills (extract prompts)**: `hermes-agent/hermes/skills/` — structured prompt templates
- **Skill router (TF-IDF)**: `agent_core/src/routing.rs` or `omega-mcp/src/catalog.rs`
- **Progressive disclosure format**: Level 0 (metadata ~100 words), Level 1 (instructions <500 lines), Level 2 (resources unbounded)

---

## IMPLEMENTATION PHASES (in dependency order)

### Phase 0: Foundation (DO FIRST — everything depends on this)
1. **Content blocks**: Replace `ChatMessage.content: String` with `content: [MessageContentBlock]` enum (text, toolUse, toolResult, thinking, image). Migrate SDMessage schema. Change stream type from `AsyncThrowingStream<String, Error>` to `AsyncThrowingStream<CloudStreamChunk, Error>`
2. **YAML graph context**: Change `buildGraphContext()` in NoteChatState to emit YAML instead of XML `<knowledge_graph>` tags. Use XML for Anthropic, YAML for OpenAI/Gemini

### Phase 1: Code Editor Polish
3. **Editor switching**: In `NoteDetailWorkspaceView.noteEditorSurface(page:)`, use `if let lang = CodeLanguage.detect(from: page.relativePath)` (no force unwraps) and show `CodeEditorView` for code files
4. **Current line highlight**: Override `drawBackground(in:)` in CodeTextView, fill line fragment rect with low-opacity color. Use `setTemporaryAttributes` on layout manager, NEVER modify NSTextStorage
5. **Bracket matching**: On selection change, scan for matching bracket with depth counter. Apply via `layoutManager.setTemporaryAttributes`. Cap scan at ±10K chars
6. **Indent guides**: In same `drawBackground` override, draw 0.5pt vertical lines at indent levels
7. **Minimap**: New `MinimapView: NSView`, Core Graphics canvas, colored rectangles per token. 80pt width, click-to-scroll, viewport indicator

### Phase 2: AI File Operations (THE KILLER FEATURE)
8. **Writer closures**: Add `noteBodyWriter` and `noteRangeWriter` to `NoteChatState`. Wire in CodeEditorView coordinator using `shouldChangeText → replaceCharacters → didChangeText` triad (preserves NSUndoManager). All text mutations MUST dispatch to main thread via `DispatchQueue.main.async` (never .sync). API keys retrieved from Keychain only, never UserDefaults
9. **Tool definitions**: Add `FileEditTool` namespace to `StructuredOutput.swift` with `edit_file`, `replace_file`, `insert_at_line`, `delete_lines` schemas
10. **FileEditExecutor**: Validate operations, sort descending by start_line, apply via writer. Bottom-to-top application keeps line numbers valid
11. **DiffPreviewView**: Green/red diff in chat, Apply/Reject buttons. Render in MessageBubble when toolUse blocks contain file-op tools
12. **Ask bar integration**: Detect file-edit intent, inject file context + tools

### Phase 3: Skills System
13. **SkillPromptLibrary**: Extract from Hermes skills/ as static prompt fragments. Enum with `systemPrompt` and `toolSubset` per skill
14. **Skill chip selector**: Generic `ChipGridView<EditorSkill>` above ask bar input. Selecting a skill prepends its system prompt
15. **User-created skills**: `.skill.md` files in vault, progressive disclosure format, "New Skill" button

### Phase 4: Cloud Hardening
16. **Prompt caching**: Restructure system blocks as [graph_context → system_prompt → file_content]. Add `cache_control: ephemeral` on stable blocks. Add beta headers for Anthropic
17. **Native Anthropic structured output**: Replace forced tool_use with `output_format: { type: "json" }` + `anthropic-beta: structured-outputs-2025-11-13`
18. **Context compaction**: 80% threshold trigger, head-tail strategy, Haiku/mini for summary, subtle toast
19. **Artifact versioning**: `artifactId` + `parentArtifactId`, detect update intent, update-in-place with version history
20. **Vault tool use**: `search_notes`, `create_note`, `link_nodes` as cloud function-calling tools. Execute locally, sanitize results, HITL confirmation for writes
21. **Extended thinking trail**: `thinking: { type: "enabled" }` for Anthropic, collapsible "Reasoning" UI

### Phase 5: Agent UI Cleanup
22. Gate all agent surfaces behind `ShipGate.agentsEnabled`. Repurpose: HermesSkillsView → ChipGridView, ToolApprovalBanner → vault tool confirmation, ReasoningExpander → AnalyticalTrailView

---

## TECHNICAL GOTCHAS

- **Apply edits bottom-to-top**: Sort `edit_file` operations by `start_line` descending before applying. Top-to-bottom corrupts line numbers
- **Never modify NSTextStorage for visual-only effects**: Use `layoutManager.setTemporaryAttributes` for line highlight, bracket matching. NSTextStorage changes move the cursor
- **Prompt cache is prefix-based**: Reordering system blocks invalidates the cache. Always: graph → system → file
- **Thinking + tool_use conflict**: Forced tool_use blocks extended thinking on Anthropic. Use native `output_format` instead
- **Context budget**: File + graph + system easily hits 8-12K tokens. If > 60% of context window, truncate graph to 5 neighbors
- **NSUndoManager**: All programmatic edits must use `shouldChangeText → replaceCharacters → didChangeText`. Users will ⌘Z AI edits
- **Threading**: Tree-sitter parsing, diff computation, token estimation → background. NSTextStorage/NSLayoutManager mutations → main thread ONLY
- **Tree-sitter incremental**: For files >2K lines, use `Tree.edit()` not full re-parse after AI edits
- **SDMessage migration**: Adding `contentBlocks: Data?` requires a lightweight SwiftData migration. Keep `content: String` as computed property joining `.text` blocks for backward compatibility

---

## VERIFICATION COMMANDS

```bash
# Swift build
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# Rust tests
cargo test --manifest-path graph-engine/Cargo.toml
cargo test --manifest-path agent_core/Cargo.toml
cargo test --manifest-path omega-mcp/Cargo.toml

# Swift tests
swift test

# Lint
swiftlint
```

After each task: run the relevant verification command before moving to the next.

---

## WHAT SUCCESS LOOKS LIKE

When done, a user can:
1. Open any code file and see syntax highlighting, line numbers, minimap, bracket matching, indent guides
2. Type "add error handling to the fetchData function" in the ask bar and see a green/red diff preview appear in the chat, click "Apply", and watch the code update live — with ⌘Z working
3. Select "Review" or "Refactor" skill chips before asking a question to get specialized, high-quality responses
4. Have the AI search their vault mid-conversation ("What did I write about quantum computing?") and get grounded answers with links to their notes
5. Have 50-turn conversations without hitting context limits (compaction handles it silently)
6. Pay 60-90% less in API costs (prompt caching handles it invisibly)
7. See the AI's reasoning process in a collapsible "Thinking" section
8. Create and manage custom skills through `.skill.md` files in their vault

This is Cursor + Obsidian + Claude.ai, fused into one native macOS experience.
