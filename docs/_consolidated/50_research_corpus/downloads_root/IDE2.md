# Epistemos v1: Native Code Editor + AI File Operations + Agent Bridge
## Implementation Guide — 2026-04-06

***

## Executive Summary

This guide covers the four interconnected features that transform Epistemos into a "PKM × IDE × AI" product: polishing the native `NSTextView`-based code editor (including minimap), adding AI-driven file operations modeled after Cursor's diff-and-apply workflow, extracting useful primitives from Goose/Hermes/agent_core without pulling in the agent loop, and hiding all agent UI behind `ShipGate`. Each section gives concrete, code-level advice without access to the actual source files.

***

## Feature 1: Code Editor Polish

### Current Line Highlight

The cleanest approach is to draw inside `NSTextView.drawBackground(in:)`. Override this method in `CodeTextView`, convert the current insertion-point character index to a line fragment rect via `NSLayoutManager`, and fill it with a very low-opacity color (e.g. `NSColor.selectedTextBackgroundColor.withAlphaComponent(0.12)`). Subscribe to `NSTextViewDidChangeSelectionNotification` to call `needsDisplay = true` on each cursor move. Keep the fill strictly a background layer so it never fights the syntax-highlighting attributes applied through `NSLayoutManager.setTemporaryAttributes(_:forCharacterRange:)`.[^1][^2][^3]

A key pitfall: do **not** apply the line highlight via `NSTextStorage` attribute changes, because any attribute change in `processEditing()` can silently move the insertion point to the end of the edited line. Temporary attributes (set on the layout manager directly) are invisible to `NSTextStorage` and therefore safe.[^4]

### Bracket Matching

On every selection change, get the character at `selectedRange.location` (and the character just before it). If it is `{`, `[`, or `(`, scan forward for the matching closer, accumulating a depth counter. If it is `}`, `]`, or `)`, scan backward for the matching opener. Once both positions are found, call `NSLayoutManager.setTemporaryAttributes([.backgroundColor: matchColor], forCharacterRange:)` for both glyphs, then clear them on the next selection change. Wrap the whole scan in a background `DispatchQueue.global(qos: .userInteractive)` task and dispatch back to main to apply—this keeps typing responsive even in multi-thousand-line files.[^2][^1]

### Indent Guides

Inside the same `drawBackground(in:)` override, iterate over visible line fragment rects using `NSLayoutManager.enumerateLineFragments(forGlyphRange:using:)`. For each line, count leading spaces (or tabs ÷ 4). For each indent level `n`, draw a 1-pixel-wide `NSBezierPath` at x = `leftPadding + n * indentWidth` using `NSColor.separatorColor.withAlphaComponent(0.3)`. This is pure Core Graphics and has zero interaction with `NSTextStorage`.[^5]

### Minimap

The minimap is the most complex piece. The recommended architecture is a dedicated `MinimapView: NSView` that:

1. **Renders a scaled snapshot** of the text at roughly 15–20% scale using a separate off-screen `NSTextView` (same `NSTextStorage` reference, different `NSLayoutManager`/`NSTextContainer` chain). Draw that layout manager into a `CGLayer` at reduced font size. Invalidate and redraw asynchronously on `NSTextStorageDidProcessEditingNotification`.[^6][^7]
2. **Draws a viewport indicator**: a translucent rounded rect corresponding to the visible portion of the main editor. Track the `NSScrollView.contentView.bounds` via KVO (`"documentVisibleRect"`) and convert to minimap coordinates.
3. **Handles click-to-scroll**: override `mouseDown(with:)`, map the click y-coordinate back to main-editor character index, call `NSTextView.scrollRangeToVisible()`.
4. **Communicates width via Auto Layout**: give `MinimapView` a fixed width constraint (~120 pt) and place it in a horizontal `NSStackView` alongside the main `NSScrollView`. The gutter already lives in the scroll view's ruler, so the minimap sits *outside* the scroll view entirely.

The two-`NSLayoutManager` approach (same storage, separate layout pipeline) is the correct macOS pattern and avoids the complexity of a manual bitmap re-render. Keep the minimap `NSLayoutManager` lazy—only lay out the visible minimap strip, not the entire document.[^6]

### Editor Switching in `NoteDetailWorkspaceView`

Call `CodeLanguage.detect(from: page.relativePath)` in the view builder. If the result is `.plainText`, show `ProseEditorRepresentable2`; otherwise show `CodeEditorView`. Gate this with a `@State var isCodeFile: Bool` that is computed once in `.onAppear` and invalidated when the file path changes. Avoid re-computing on every body evaluation.

### Additional Tree-Sitter Grammars

The following crates are available on crates.io and follow the standard tree-sitter Cargo pattern:[^8][^9]

| Language | Crate | Notes |
|----------|-------|-------|
| YAML | `tree-sitter-yaml` | Stable, official TS org |
| TOML | `tree-sitter-toml` | Stable |
| Ruby | `tree-sitter-ruby` | Official TS org, has `Package.swift`[^10] |
| SQL | `tree-sitter-sql` (DerekStride) | Most complete SQL grammar[^11] |
| Zig | `tree-sitter-zig` | Available, actively maintained[^9] |
| Java | `tree-sitter-java` | Official TS org |
| Kotlin | `tree-sitter-kotlin` | Community, decent coverage |
| Lua | `tree-sitter-lua` | Stable |
| WGSL | `tree-sitter-wgsl` | Smaller community but functional |
| GDScript | `tree-sitter-gdscript` | Community |

In `code_highlight.rs`, follow the same `extern "C" fn tree_sitter_X() -> Language` pattern you already use for the 14 existing languages. Add each to the `match language` dispatch table and expose the token stream over FFI exactly as before.

***

## Feature 2: AI File Operations

### The Cursor Mental Model

Cursor's apply mechanism is not magic: the IDE extension gathers the file content and sends it with a strict prompt, the LLM returns a diff (or a structured JSON describing the edit), and the IDE extension parses and applies it via editor buffer APIs—never via direct filesystem writes. The LLM never has filesystem access; it only generates text. The key design choices are: (1) structured output so parsing is reliable, (2) diff preview before apply, and (3) a confirmation gate so users stay in control.[^12][^13][^14]

Epistemos can do better than Cursor here: the knowledge graph context means the model can understand *why* a function exists, not just *what* it does.

### `noteBodyWriter` and `noteRangeWriter` Closures

Mirror the existing `noteBodyProvider` pattern exactly. In `CodeEditorView`'s `NSViewRepresentable.makeCoordinator()`, capture a reference to the `NSTextView` and set:

```swift
chatState.noteBodyWriter = { [weak textView] newContent in
    guard let tv = textView else { return }
    tv.textStorage?.replaceCharacters(
        in: NSRange(location: 0, length: tv.string.utf16.count),
        with: newContent
    )
    tv.undoManager?.registerUndo(withTarget: tv) { ... } // preserve undo
}

chatState.noteRangeWriter = { [weak textView] lineRange, replacement in
    guard let tv = textView else { return }
    let nsRange = tv.nsRange(forLineRange: lineRange) // helper you'll write
    tv.shouldChangeText(in: nsRange, replacementString: replacement)
    tv.textStorage?.replaceCharacters(in: nsRange, with: replacement)
    tv.didChangeText()
}
```

The `nsRange(forLineRange:)` helper should enumerate `NSLayoutManager.lineFragmentRect(forGlyphAt:effectiveRange:)` to find the byte ranges for line `n`—this is the same pattern used in `LineNumberGutter`.[^15]

**Always go through `NSTextStorage.replaceCharacters(in:with:)` rather than `NSTextView.insertText(_:)`** for programmatic edits, so the existing syntax highlighting pipeline (triggered by `processEditing()`) fires automatically.

### Tool Definition Schema

Define these as `CloudJSONSchema` objects. For Anthropic's tool_use, the schema goes in `input_schema`; for OpenAI's json_schema mode, it goes in `schema`. The most important tools:[^16][^17][^18]

```json
{
  "edit_file": {
    "start_line": "integer (1-indexed)",
    "end_line": "integer (inclusive)",
    "replacement": "string (newline-separated lines to substitute)",
    "explanation": "string (human-readable rationale, shown in diff header)"
  },
  "replace_file": {
    "content": "string (complete new file content)"
  },
  "insert_at_line": {
    "line": "integer (insert BEFORE this line)",
    "content": "string"
  },
  "delete_lines": {
    "start_line": "integer",
    "end_line": "integer"
  },
  "read_file_range": {
    "start_line": "integer",
    "end_line": "integer"
  }
}
```

For Anthropic, force the model to use exactly one tool per response by setting `tool_choice: { "type": "any" }`. This guarantees you always get a `tool_use` block, never free text. For OpenAI, set `response_format: { "type": "json_schema" }` with `strict: true`.[^17][^16]

### Tool Execution Engine

The execution pipeline in `NoteChatState` (or a new `FileOpExecutor`):

1. Receive a `tool_use` response block from `generateStructured<T>`.
2. **Validate**: check that `start_line <= end_line`, both are within `[1, totalLines]`, and `replacement` is not nil. If validation fails, send a `tool_result` error back to the model (so it can self-correct) rather than crashing.
3. **Build a diff**: compute the unified diff between old lines `start_line...end_line` and the replacement lines. Store as an array of `DiffLine` enum: `.context`, `.removed(text)`, `.added(text)`.
4. **Publish the diff** to a `@Published var pendingEdit: FileEdit?` on `NoteChatState`.
5. The chat view observes this and renders a `DiffPreviewView`. The user taps "Apply" or "Reject".
6. On "Apply", call `noteRangeWriter(lineRange, replacement)`. On "Reject", send `tool_result: { "error": "user rejected" }` back to the model.

Auto-apply mode (for power users) skips step 4–6: apply immediately and show a dismissable "Undo" banner.

### Diff Preview in Chat

Create a `DiffPreviewView` that renders inside `MessageBubble` (following the `ArtifactBlockView` pattern already in the codebase). Use `NSAttributedString`/`AttributedString` for coloring:[^19]

- Removed lines: `NSColor.systemRed.withAlphaComponent(0.15)` background, `NSColor.systemRed` text prefix `−`
- Added lines: `NSColor.systemGreen.withAlphaComponent(0.15)` background, `NSColor.systemGreen` text prefix `+`
- Context lines: `NSColor.secondaryLabelColor` text[^20]

The diff header should show the filename and line range. The "Apply" / "Reject" buttons should be `NSButton` instances wired to the `NoteChatState` action closures.

### Ask Bar Integration

The ask bar is the highest-leverage entry point. For single-line requests like "fix the bug on line 42":

1. Detect intent: if the ask contains "line N", prepend `read_file_range(N-2, N+2)` to give the model context.
2. For "add imports", map to `insert_at_line(1, ...)`.
3. For "rename X to Y", generate a `replace_file` with all occurrences substituted client-side first (using `String.replacingOccurrences(of:with:)`), then let the model verify.

This keeps the model call count low: one round-trip for most edits.

### Prompt Construction

The file-op system prompt should follow this structure:
```
You are editing <filename>. The active file contains:

<file>
{entire file content, line-numbered}
</file>

<knowledge_graph>
{20 connected nodes — existing context injection}
</knowledge_graph>

Respond ONLY with a single tool call. Do not explain. Do not add prose.
```

Line-numbering the injected file is critical—it directly maps to `start_line`/`end_line` in the tool schema and dramatically reduces off-by-one errors.[^14][^12]

***

## Feature 3: Agent Bridge — Surgical Extraction

The guiding principle: extract **data structures and algorithms**, not execution loops. `ShipGate.agentsEnabled = false` must remain the release posture.

### What to Take from Goose

Goose's `Provider` trait is a clean `async fn complete(messages: &[Message], config: &ModelConfig) -> Result<Response>` interface. Since Epistemos already has `LLMService.swift` with per-provider implementations, the value here is the **`Message` type** and the **`ProviderMetadata` struct**, not the trait itself. Translate these to Swift:[^21]

```swift
struct LLMMessage: Codable {
    enum Role: String, Codable { case system, user, assistant, tool }
    let role: Role
    let content: [ContentBlock]  // mirrors Goose's Vec<Content>
}

enum ContentBlock: Codable {
    case text(String)
    case toolUse(id: String, name: String, input: AnyCodable)
    case toolResult(toolUseId: String, content: String, isError: Bool)
    case image(base64: String, mediaType: String)
}
```

This is the message schema both Anthropic and OpenAI converge on. If your current `LLMService` uses flat `String` content, migrating to `[ContentBlock]` is the single highest-leverage structural change—it enables images, tool calls, and tool results in one unified type.[^22][^21]

### What to Take from Goose's Compaction (`truncate.rs`)

Goose uses **head-tail compaction**: keep the system message + first N tokens (task context) + last M tokens (recent work), discard the middle. The implementation in Swift:[^23][^24]

```swift
func compactMessages(_ messages: [LLMMessage], budget: Int) -> [LLMMessage] {
    let tokens = messages.map { estimateTokens($0) }
    let total = tokens.reduce(0, +)
    guard total > budget else { return messages }
    
    // Always keep system message
    var kept: [LLMMessage] = messages.filter { $0.role == .system }
    var remaining = messages.filter { $0.role != .system }
    
    let headBudget = Int(Double(budget) * 0.2) // 20% for task context
    let tailBudget = budget - headBudget
    
    // Fill head
    var headTokens = 0
    var headMessages: [LLMMessage] = []
    for msg in remaining {
        let t = estimateTokens(msg)
        if headTokens + t <= headBudget { headMessages.append(msg); headTokens += t }
        else { break }
    }
    
    // Fill tail (from end)
    var tailTokens = 0
    var tailMessages: [LLMMessage] = []
    for msg in remaining.reversed() {
        let t = estimateTokens(msg)
        if tailTokens + t <= tailBudget { tailMessages.insert(msg, at: 0); tailTokens += t }
        else { break }
    }
    
    return kept + headMessages + tailMessages
}
```

Trigger this inside `NoteChatState` before every cloud call when `estimatedTokens > 0.8 * contextWindow`. OpenAI also exposes server-side compaction via `context_management.compact_threshold`, but client-side gives you control over what's preserved.[^25]

### What to Take from `agent_core`: Prompt Caching

Anthropic's prompt caching uses `cache_control: { "type": "ephemeral" }` on content blocks. For Epistemos, the highest-value cache point is the system prompt + `<knowledge_graph>` context, which changes rarely but is large. Add a `isCacheable: Bool` flag to `ContentBlock` and emit the cache control header only for those blocks. This can cut 60–80% of input token costs on repeat file-edit requests where the file hasn't changed.[^18]

### What to Take from `omega-mcp`: Tool Catalog

The omega-mcp catalog is a registry of tool definitions keyed by string name. In Swift, this maps directly to a `[String: CloudJSONSchema]` dictionary on `NoteChatState`. Populate it dynamically based on context:
- Always include: `edit_file`, `replace_file`, `insert_at_line`, `delete_lines`
- Include conditionally: `read_file_range` only if the file exceeds 300 lines (otherwise the full file is already in context)
- Never include agent tools (`bash`, `computer`, `web_search`) when `ShipGate.agentsEnabled == false`

### What to Take from Hermes: Skill Prompt Templates

Hermes skill templates are structured system-prompt fragments keyed by task type. Bring this as a `SkillLibrary` enum with static `systemPrompt` and `userPromptTemplate` properties:

```swift
enum EditorSkill {
    case codeReview, addErrorHandling, writeTests, explainCode, renameSymbol
    
    var systemPrompt: String { ... }  // populated from hermes-agent/hermes/skills/
    var toolSubset: [String] { ... }  // which file-op tools to expose
}
```

This gives the ask bar a "mode" selector without building a full agent loop.

***

## Feature 4: Agent UI Audit

### Hide Strategy

The rule is: dead code → delete, useful UI pattern → repurpose for cloud chat, live agent surface → gate behind `ShipGate.agentsEnabled`.[^26]

| File | Action | Rationale |
|------|--------|-----------|
| `AgentPanelContainer.swift` | Gate behind `ShipGate.agentsEnabled` | Panel layout pattern is good; keep it off for release |
| `AgentSessionPanel.swift` | Repurpose as `ChatSessionPanel` for multi-turn file editing | The session management UI is reusable |
| `HermesSkillsView.swift` | Convert to `EditorSkillPicker` using `EditorSkill` enum above | Good UX; remove Hermes branding |
| `HermesExecutionGraphView.swift` | Delete if execution graph is not shown in cloud mode | Pure agent UI, no cloud equivalent |

For menu items and toolbar buttons: audit `MainMenu.xib` and any `NSToolbarItem` registrations. Any item whose action sends to an agent-specific target (`AgentController`, `HermesController`) should be removed from the toolbar and menu entirely in release. Keep them in a `#if DEBUG` block or behind `ShipGate` for internal testing.

***

## Cross-Feature Architecture Notes

### Undo / Redo Safety

All programmatic text edits (from AI file ops) must use the `NSTextView.shouldChangeText(in:replacementString:)` → `replaceCharacters` → `didChangeText()` triad. This registers the change with `NSUndoManager` automatically. Never bypass this—users will expect `⌘Z` to undo AI edits, and breaking undo is the fastest way to destroy trust in a power tool.[^27]

### Threading Model

The rule for all four features:
- **Background**: token estimation, diff computation, tree-sitter parsing, minimap layout
- **Main thread only**: any `NSTextStorage` or `NSLayoutManager` mutation, any `@Published` property change on `NoteChatState`

Violating this causes the classic TextKit data race where the layout manager and the storage disagree on character ranges, producing phantom highlights or crashes during fast typing.

### Syntax Highlighting + AI Edits

When `noteRangeWriter` replaces lines, `NSTextStorage.processEditing()` fires and the tree-sitter re-tokenizer should run on the `editedRange`. Verify that `code_highlight.rs` accepts a partial re-parse (incremental update via `tree_sitter::Tree.edit()`) rather than a full re-parse on every AI edit. For files under ~2,000 lines this is fine either way; above that, incremental parsing is essential for responsiveness.[^28]

### Context Window Budget

With a full file in `<file>`, the knowledge graph in `<knowledge_graph>`, and a system prompt, a 500-line file easily consumes 8–12k tokens. Keep a hard budget: if `file_tokens + graph_tokens > 0.6 * contextWindow`, truncate the knowledge graph to the 5 most semantically relevant neighbors rather than 20. This leaves room for multi-turn edits without hitting compaction on the first request.[^29][^23]

***

## Implementation Order Recommendation

The safest ship sequence, given that `ShipGate.agentsEnabled = false` for release:

1. **Editor switching** (30 min) — mechanical `CodeLanguage.detect` check in `NoteDetailWorkspaceView`. Immediate user value.
2. **Current line highlight** (1 hr) — `drawBackground` override, safe and isolated.
3. **`noteBodyWriter` / `noteRangeWriter`** (2 hr) — the plumbing for all AI ops.
4. **Tool schema + Anthropic/OpenAI dispatch** (3 hr) — wire `generateStructured` to file-op tools.
5. **Diff preview in chat** (3 hr) — `DiffPreviewView` inside `MessageBubble`.
6. **Agent UI audit** (1 hr) — delete/gate per the table above.
7. **Bracket matching + indent guides** (2 hr) — editor polish.
8. **Minimap** (4–6 hr) — two-NSLayoutManager approach.
9. **Context compaction** (2 hr) — head-tail Swift implementation.
10. **Additional tree-sitter grammars** (1 hr per language) — YAML, TOML, SQL, Zig first.

Items 1–6 constitute the "AI file ops ship" milestone. Items 7–10 are polish and infrastructure that can ship in the following sprint.

---

## References

1. [NSLayoutManager | Apple Developer Documentation](https://developer.apple.com/documentation/AppKit/NSLayoutManager) - NSLayoutManager maps Unicode character codes to glyphs, sets the glyphs in a series of NSTextContain...

2. [NSTextView and Syntax Highlighting - cocoa-dev@lists.apple.com](https://cocoa-dev.apple.narkive.com/Qhu50yyS/nstextview-and-syntax-highlighting) - In my text-editing app, there are some special characters I'd like to highlight whenever they are en...

3. [Get & Highlight Current Word in an NSTextView - Stack Overflow](https://stackoverflow.com/questions/12554501/get-highlight-current-word-in-an-nstextview) - I'm not sure how to go about this : I mean my main concern is getting current position within NSText...

4. [Why the Selection Changes When You Do Syntax Highlighting in a ...](https://christiantietze.de/posts/2017/11/syntax-highlight-nstextstorage-insertion-point-change/) - In short: when you type and the attributes of the line change, the insertion point is moved to the e...

5. [Core Graphics on macOS Tutorial - Kodeco](https://www.kodeco.com/1101-core-graphics-on-macos-tutorial) - Core Graphics is Apple's 2D drawing engine for OS X. Discover how to build a great disc info app for...

6. [Scrollable NSTextView with custom NSTextStorage for formatting](https://stackoverflow.com/questions/71286431/scrollable-nstextview-with-custom-nstextstorage-for-formatting) - I'm trying to make a text editor with formatting for Mac OS. Which I have working using an NSTextVie...

7. [How to make scrollable NSTextView in AppKit #330 - GitHub](https://github.com/onmyway133/blog/issues/330) - For easy Auto Layout, we use Anchors for UIScrollView . Things worth mentioned for vertical scrollin...

8. [tree-sitter/tree-sitter v0.25.0 on GitHub - NewReleases.io](https://newreleases.io/project/github/tree-sitter/tree-sitter/release/v0.25.0) - Changelog. [0.25.0] — 2025-02-01. Notices. This is a large release. As such, a few major changes and...

9. [tree-sitter-zig - crates.io: Rust Package Registry](https://crates.io/crates/tree-sitter-zig) - Run the following Cargo command in your project directory: cargo add tree-sitter-zig. Or add the fol...

10. [tree-sitter-ruby/Package.swift at master - GitHub](https://github.com/tree-sitter/tree-sitter-ruby/blob/master/Package.swift) - Ruby grammar for tree-sitter. Contribute to tree-sitter/tree-sitter-ruby development by creating an ...

11. [Cargo.toml - DerekStride/tree-sitter-sql - GitHub](https://github.com/DerekStride/tree-sitter-sql/blob/main/Cargo.toml) - SQL grammar for tree-sitter. Contribute to DerekStride/tree-sitter-sql development by creating an ac...

12. [How Cursor Works: Inside an AI Coding Agent - LinkedIn](https://www.linkedin.com/pulse/how-cursor-works-inside-ai-coding-agent-midhun-k-sprhc) - Cursor is designed as an AI-native development environment, meaning artificial intelligence is built...

13. [How do LLM-powered tools in IDEs edit files? #171782 - GitHub](https://github.com/orgs/community/discussions/171782) - I've been exploring how LLM-powered assistants (like GitHub Copilot, Cursor, or other IDE-integrated...

14. [How Cursor works – Deep dive into vibe coding - BitPeak](https://bitpeak.com/how-cursor-works-deep-dive-into-vibe-coding/) - In this article, we'll break down the core architecture of Cursor AI, explore the mechanics of vibe ...

15. [Displaying Line Numbers with NSTextView — Noodlings - Noodlesoft](https://www.noodlesoft.com/blog/2008/10/05/displaying-line-numbers-with-nstextview/) - To integrate: just create the line number view and set it as the vertical ruler. · The view will exp...

16. [Claude API Structured Output: Complete Guide to Schema ...](https://thomas-wiegold.com/blog/claude-api-structured-output/) - Strict tool use mode adds strict: true to your tool definitions, ensuring that when Claude calls fun...

17. [How to get consistent structured output from Claude - DEV Community](https://dev.to/heuperman/how-to-get-consistent-structured-output-from-claude-20o5) - Utilising Tool Use to get structured data. Fortunately there is a simple trick we can use to get con...

18. [Structured outputs - Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs) - Using both features together. JSON outputs and strict tool use solve different problems and can be u...

19. [AttributedString - Making Text More Beautiful Than Ever](https://fatbobman.com/en/posts/attributedstring/) - This article will provide a comprehensive introduction to AttributedString and demonstrate how to cr...

20. [Diff colors should show green for insert, red for delete #5430 - GitHub](https://github.com/facebook/jest/issues/5430) - The colors in the DIFF view are reversed as opposed to most other popular tools. Normally green is f...

21. [Custom Providers - Goose - Mintlify](https://www.mintlify.com/block/goose/guides/custom-providers) - Goose offers two approaches: declarative configuration for OpenAI-compatible APIs, and full Rust tra...

22. [CLI Providers | goose - GitHub Pages](https://block.github.io/goose/docs/guides/cli-providers/) - The CLI providers automatically filter out goose's extension information from system prompts since t...

23. [How to Implement Context Engineering Strategies for your Agent ...](https://newsletter.victordibia.com/p/context-engineering-101-how-agents) - Three core strategies for context engineering: compaction, isolation, and agentic memory. A benchmar...

24. [Smart Context Management | goose - GitHub Pages](https://block.github.io/goose/docs/guides/sessions/smart-context-management/) - goose uses a two-tiered approach to context management: Auto-Compaction: Proactively summarizes conv...

25. [Compaction | OpenAI API](https://developers.openai.com/api/docs/guides/compaction/) - Overview. To support long-running interactions, you can use compaction to reduce context size while ...

26. [How To Use Cursor AI (Full Tutorial For Beginners 2025) - YouTube](https://www.youtube.com/watch?v=cE84Q5IRR6U) - Cursor AI is an advanced code editor designed to enhance your productivity by integrating AI seamles...

27. [NSTextView | Apple Developer Documentation](https://developer.apple.com/documentation/AppKit/NSTextView?language=objc) - Overview. The NSTextView class is the front-end class to the AppKit text system. The class draws the...

28. [On-the-Fly Syntax Highlighting: Generalisation and Speed-ups](https://arxiv.org/pdf/2402.08754.pdf) - ...necessitates the capacity to perform grammatical analysis on the code under
consideration, even i...

29. [Building an internal agent: Context window compaction - Lethain.com](https://lethain.com/agents-context-compaction/) - When you run out of space in the context window, your agent either needs to give up, or it needs to ...

