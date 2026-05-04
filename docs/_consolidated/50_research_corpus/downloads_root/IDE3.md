# Epistemos v1: Native Code Editor + AI File Operations + Agent Bridge

## Implementation Guide — April 2026

***

## Executive Summary

This document provides concrete implementation guidance for the four features outlined in the Epistemos v1 research prompt: code editor polish (minimap, line highlight, bracket matching, indent guides), AI file operations ("Cursor-native" apply pipeline), agent bridge extractions from Goose/Hermes/agent_core, and agent UI hiding. All features build directly on the existing architecture (`CodeEditorView`, `NoteChatState`, `LLMService`, `StructuredOutput`).

***

## Feature 1: Code Editor Polish + Minimap

### 1a. Minimap

The minimap is a scaled-down, read-only overview of the full document that tracks the viewport and lets the user click-to-scroll. VS Code renders colored blocks (rectangles) per token rather than actual glyphs when `renderCharacters` is disabled — this is the correct approach for performance at small scale.[^1]

**Architecture: `MinimapView.swift` (NSView subclass)**

```swift
class MinimapView: NSView {
    weak var textView: CodeTextView?
    weak var scrollView: NSScrollView?
    var tokenRects: [(rect: CGRect, color: NSColor)] = []   // built from token stream
    var viewportFraction: CGFloat = 0.0                     // what % of doc is visible
    var viewportOffset: CGFloat = 0.0                       // normalized scroll offset (0-1)
    
    private let scale: CGFloat = 0.12   // ~1/8th of normal character size
    private let lineHeight: CGFloat = 2.0
    private let charWidth: CGFloat = 1.2

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Draw token rectangles
        for entry in tokenRects {
            ctx.setFillColor(entry.color.cgColor)
            ctx.fill(entry.rect)
        }
        
        // 2. Draw viewport overlay
        let vpH = bounds.height * viewportFraction
        let vpY = bounds.height * viewportOffset
        let vpRect = CGRect(x: 0, y: vpY, width: bounds.width, height: vpH)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        ctx.fill(vpRect)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(0.5)
        ctx.stroke(vpRect)
    }
}
```

**Token rect generation** — in `CodeEditorView.updateTokenRects()`:

```swift
func buildMinimapRects(tokens: [CodeToken], layoutManager: NSLayoutManager) -> [(CGRect, NSColor)] {
    var result: [(CGRect, NSColor)] = []
    let scale: CGFloat = 0.12
    let lineH: CGFloat = 2.0
    let charW: CGFloat = 1.2
    for token in tokens {
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: token.range, actualCharacterRange: nil)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, lineGlyphRange, _ in
            let lineIdx = /* compute 0-based line number from usedRect.origin.y */
            let charStart = NSMaxRange(glyphRange) - lineGlyphRange.length
            let x = CGFloat(charStart) * charW
            let y = CGFloat(lineIdx) * lineH
            let w = CGFloat(token.length) * charW
            let rect = CGRect(x: x, y: y, width: w, height: lineH - 0.3)
            result.append((rect, token.tokenType.minimapColor))
        }
    }
    return result
}
```

**Scroll sync**: Register for `NSScrollView.didLiveScrollNotification` and `NSView.boundsDidChangeNotification` on `scrollView.contentView`. On each event, recompute `viewportFraction` and `viewportOffset`, then call `minimapView.needsDisplay = true`.

**Click-to-scroll**:

```swift
override func mouseDown(with event: NSEvent) {
    let clickY = convert(event.locationInWindow, from: nil).y
    let fraction = clickY / bounds.height
    scrollView?.contentView.scroll(to: CGPoint(
        x: 0,
        y: fraction * (scrollView!.documentView!.bounds.height - scrollView!.bounds.height)
    ))
    scrollView?.reflectScrolledClipView(scrollView!.contentView)
}
```

**Integration**: `CodeEditorView` becomes an `HStack { codeScrollView; MinimapView().frame(width: 80) }` in SwiftUI (or an `NSView` container with the minimap added as a sibling subview to the `NSScrollView`).

***

### 1b. Editor Switching in `NoteDetailWorkspaceView`

```swift
// In NoteDetailWorkspaceView body:
let lang = page.relativePath.map { CodeLanguage.detect(from: $0) } ?? .plaintext

if lang != .plaintext && lang != .markdown {
    CodeEditorView(page: page, language: lang)
        .id("code-\(page.id)")
} else {
    ProseEditorRepresentable2(page: page)
        .id("prose-\(page.id)")
}
```

`CodeLanguage.detect(from:)` already handles 30+ extensions — no new logic needed. Add `.unknown` / `.plaintext` as the default fallback.

***

### 1c. Current Line Highlight

Override `drawBackground(forGlyphRange:at:)` in a custom `NSLayoutManager` subclass:[^2]

```swift
class CodeLayoutManager: NSLayoutManager {
    var highlightedLineCharRange: NSRange = .init(location: NSNotFound, length: 0)
    var lineHighlightColor: NSColor = .white.withAlphaComponent(0.05)

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard highlightedLineCharRange.location != NSNotFound else { return }
        let glyphRange = self.glyphRange(forCharacterRange: highlightedLineCharRange,
                                         actualCharacterRange: nil)
        enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, _, _ in
            var lineRect = rect
            lineRect.origin.x += origin.x
            lineRect.origin.y += origin.y
            lineRect.size.width = self.firstTextView?.bounds.width ?? lineRect.size.width
            self.lineHighlightColor.setFill()
            NSBezierPath.fill(lineRect)
        }
    }
}
```

Update the highlight range in `textViewDidChangeSelection`:

```swift
func updateCurrentLineHighlight() {
    let sel = textView.selectedRange()
    let str = textView.string as NSString
    let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
    codeLayoutManager.highlightedLineCharRange = lineRange
    textView.setNeedsDisplay(textView.bounds)
}
```

***

### 1d. Bracket Matching

Listen to `NSTextView.didChangeSelectionNotification`. When the cursor is adjacent to `{`, `}`, `[`, `]`, `(`, `)`, find the match by counting nesting depth:

```swift
func findMatchingBracket(in string: String, at index: String.Index) -> String.Index? {
    let open: [Character: Character] = ["{":"}", "[":"]", "(":")"]
    let close: [Character: Character] = ["}":"{", "]":"[", ")":"("]
    let ch = string[index]
    if let target = open[ch] {
        // scan forward
        var depth = 1
        var i = string.index(after: index)
        while i < string.endIndex {
            if string[i] == ch { depth += 1 }
            else if string[i] == target { depth -= 1; if depth == 0 { return i } }
            i = string.index(after: i)
        }
    } else if let target = close[ch] {
        // scan backward
        var depth = 1
        var i = string.index(before: index)
        while i >= string.startIndex {
            if string[i] == ch { depth += 1 }
            else if string[i] == target { depth -= 1; if depth == 0 { return i } }
            if i == string.startIndex { break }
            i = string.index(before: i)
        }
    }
    return nil
}
```

Apply highlighting using `setTemporaryAttributes([.backgroundColor: bracketHighlightColor], forCharacterRange: matchRange)` on the layout manager. Clear previous bracket highlights at the start of each selection change.[^3]

***

### 1e. Indent Guides

Draw in the same `CodeLayoutManager.drawBackground` override, before calling `super`:[^2]

```swift
// Inside drawBackground override, after line highlight:
let indentColor = NSColor.white.withAlphaComponent(0.07)
let indentWidth: CGFloat = 4 * charWidth  // 4-space indent

enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, _, _, glyphRange, _ in
    var lineRect = rect; lineRect.origin += origin
    let charRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    let lineStr = (self.textStorage?.string as? NSString)?.substring(with: charRange) ?? ""
    let leadingSpaces = lineStr.prefix(while: { $0 == " " }).count
    let indentLevels = leadingSpaces / 4
    for level in 1...max(1, indentLevels) {
        let x = lineRect.origin.x + CGFloat(level) * indentWidth
        let guideRect = CGRect(x: x, y: lineRect.origin.y, width: 0.5, height: lineRect.height)
        indentColor.setFill()
        NSBezierPath.fill(guideRect)
    }
}
```

***

### 1f. Additional Tree-sitter Languages

Add to `graph-engine/Cargo.toml`:

```toml
tree-sitter-yaml = "0.6"      # crates.io
tree-sitter-toml = "0.6"      # crates.io
tree-sitter-ruby = "0.21"
tree-sitter-java = "0.21"
tree-sitter-kotlin = "0.3"
tree-sitter-sql = "0.2"
tree-sitter-lua = "0.2"       # crates.io
tree-sitter-zig = "0.3"
tree-sitter-glsl = "1.0"
```

In `code_highlight.rs`, register each language with the parser and add to the dispatch table. The kreuzberg-dev `tree-sitter-language-pack` crate bundles many of these together as a single dependency if individual crate maintenance becomes a concern.[^4]

***

## Feature 2: AI File Operations

This is the architectural centerpiece of Epistemos v1 — giving every chat window the ability to read, propose, and apply edits to the active file, analogous to Cursor's apply pipeline but native and integrated with the knowledge graph.

### 2a. The Core Pipeline

Based on analysis of how Cursor and similar tools implement file editing, the correct model is:[^5][^6]

1. **LLM receives** full file content + edit instruction
2. **LLM returns** structured operations: `[{start_line, end_line, replacement}]`  
3. **Operations applied in descending line order** (bottom to top) so line numbers remain valid[^6]
4. **Diff preview rendered** in chat before/after apply
5. **User accepts or rejects** each operation (or all at once)

Cursor applies edits immediately and uses "Keep" / "Undo" semantics rather than a staged preview. Epistemos should offer both modes: an auto-apply mode for power users and an explicit confirm mode (default).[^5]

***

### 2b. `noteBodyWriter` and `noteRangeWriter`

Add to `NoteChatState.swift`, mirroring `noteBodyProvider`:

```swift
// In NoteChatState:
var noteBodyWriter: ((String) -> Void)?
var noteRangeWriter: ((ClosedRange<Int>, String) -> Void)?  // line range (1-indexed), replacement

// In CodeEditorView coordinator (same pattern as wireNoteChatCallbacks in ProseEditorRepresentable2):
func wireNoteChatCallbacks(chatState: NoteChatState) {
    chatState.noteBodyWriter = { [weak self] newContent in
        DispatchQueue.main.async {
            self?.textView.string = newContent
            self?.textView.didChangeText()
        }
    }
    chatState.noteRangeWriter = { [weak self] lineRange, replacement in
        DispatchQueue.main.async {
            guard let tv = self?.textView else { return }
            let lines = tv.string.components(separatedBy: "\n")
            var newLines = lines
            let lo = lineRange.lowerBound - 1  // 0-indexed
            let hi = min(lineRange.upperBound - 1, lines.count - 1)
            let replacementLines = replacement.components(separatedBy: "\n")
            newLines.replaceSubrange(lo...hi, with: replacementLines)
            tv.string = newLines.joined(separator: "\n")
            tv.didChangeText()
        }
    }
}
```

***

### 2c. File Operation Tool Definitions

Add to `StructuredOutput.swift` a `FileEditTool` namespace:

```swift
enum FileEditTool {
    static let editFile = CloudJSONSchema(
        name: "edit_file",
        description: "Replace a range of lines in the active file. Use for targeted edits.",
        schema: [
            "type": "object",
            "properties": [
                "start_line": ["type": "integer", "description": "First line to replace (1-indexed)"],
                "end_line":   ["type": "integer", "description": "Last line to replace (1-indexed, inclusive)"],
                "replacement": ["type": "string", "description": "New content for the replaced lines"],
                "explanation": ["type": "string", "description": "Why this edit was made"]
            ],
            "required": ["start_line", "end_line", "replacement", "explanation"]
        ]
    )
    
    static let replaceFile = CloudJSONSchema(
        name: "replace_file",
        description: "Replace the entire file content. Use only when the edit affects more than 60% of lines.",
        schema: [
            "type": "object",
            "properties": [
                "content": ["type": "string"],
                "explanation": ["type": "string"]
            ],
            "required": ["content", "explanation"]
        ]
    )
    
    static let insertAtLine = CloudJSONSchema(
        name: "insert_at_line",
        description: "Insert new lines before a given line number.",
        schema: [
            "type": "object",
            "properties": [
                "line": ["type": "integer"],
                "content": ["type": "string"],
                "explanation": ["type": "string"]
            ],
            "required": ["line", "content"]
        ]
    )
    
    static let deleteLines = CloudJSONSchema(
        name: "delete_lines",
        description: "Delete a range of lines from the file.",
        schema: [
            "type": "object",
            "properties": [
                "start_line": ["type": "integer"],
                "end_line":   ["type": "integer"],
                "explanation": ["type": "string"]
            ],
            "required": ["start_line", "end_line"]
        ]
    )
    
    static let all: [CloudJSONSchema] = [editFile, replaceFile, insertAtLine, deleteLines]
}
```

***

### 2d. Tool Execution Engine

In `LLMService.swift` (or a new `FileEditExecutor.swift`):

```swift
struct FileEditOperation: Codable {
    let startLine: Int
    let endLine: Int
    let replacement: String
    let explanation: String?
    
    func validate(against fileLineCount: Int) throws {
        guard startLine >= 1, endLine <= fileLineCount, startLine <= endLine else {
            throw FileEditError.invalidRange(startLine, endLine, fileLineCount)
        }
    }
}

class FileEditExecutor {
    static func apply(
        operations: [FileEditOperation],
        writer: (ClosedRange<Int>, String) -> Void,
        lineCount: Int
    ) throws {
        // Sort descending so line numbers stay valid
        let sorted = try operations
            .map { op -> FileEditOperation in try op.validate(against: lineCount); return op }
            .sorted { $0.startLine > $1.startLine }
        
        for op in sorted {
            writer(op.startLine...op.endLine, op.replacement)
        }
    }
}
```

***

### 2e. Diff Preview in Chat

Create `FileEditArtifactView.swift` (modeled on `ArtifactBlockView`):

```swift
struct FileEditArtifactView: View {
    let operations: [FileEditOperation]
    let originalLines: [String]
    let onApply: ([FileEditOperation]) -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(operations.indices, id: \.self) { i in
                let op = operations[i]
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "pencil.and.outline")
                        Text("Lines \(op.startLine)–\(op.endLine)")
                            .font(.caption.monospaced())
                        Spacer()
                        Text(op.explanation ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    
                    // Removed lines (red)
                    ForEach(op.startLine...op.endLine, id: \.self) { ln in
                        let idx = ln - 1
                        if idx < originalLines.count {
                            DiffLineRow(prefix: "-", text: originalLines[idx], color: .red)
                        }
                    }
                    
                    // Added lines (green)
                    ForEach(op.replacement.components(separatedBy: "\n").indices, id: \.self) { i in
                        DiffLineRow(prefix: "+",
                                    text: op.replacement.components(separatedBy: "\n")[i],
                                    color: .green)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 0.5))
            }
            
            HStack(spacing: 8) {
                Button("Apply") { onApply(operations) }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                Button("Reject") { onReject() }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
            }
            .padding(.top, 8)
        }
        .padding(10)
    }
}

struct DiffLineRow: View {
    let prefix: String; let text: String; let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(prefix).font(.caption.monospaced()).foregroundStyle(color)
            Text(text).font(.caption.monospaced()).foregroundStyle(color.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10).padding(.vertical, 1)
        .background(color.opacity(0.08))
    }
}
```

Render `FileEditArtifactView` in `MessageBubble.swift` when a message's `artifacts` array contains a `.fileEdit` artifact type. Add a new case to the `ArtifactType` enum and thread it through `ArtifactExtractor`.

***

### 2f. Prompt Construction for File Edits

In `NoteChatState.buildSystemPrompt()` (or the message construction site), when a code file is active:

```swift
let fileContext = noteBodyProvider?() ?? ""
let lineCount = fileContext.components(separatedBy: "\n").count

let fileSection = """
<active_file path="\(page.relativePath ?? "untitled")">
\(fileContext)
</active_file>
<file_metadata>
total_lines: \(lineCount)
language: \(CodeLanguage.detect(from: page.relativePath ?? "").rawValue)
</file_metadata>
"""
```

This joins the existing `<knowledge_graph>` injection. Cache both the system prompt and `<knowledge_graph>` using Anthropic prompt caching (`cache_control: {type: "ephemeral"}`) since they are stable across turns. The file content block should NOT be cached since it changes as the user edits.[^7][^8]

***

### 2g. Ask Bar Integration

The ask bar should inject the same file context and tool definitions when a code file is active. The key UX patterns:[^9][^10]

- Short natural language → model picks the right tool (`edit_file` vs `insert_at_line` vs `replace_file`)
- Operations with single-digit line counts auto-apply after a 500ms preview delay
- Multi-operation edits always require explicit confirm
- "Reject all" undoes any already-applied operations via `NSTextView.undoManager`

***

## Feature 3: Agent Bridge (Surgical Extractions)

The constraint is strict: **no agent loop**. All extractions must enhance the existing cloud chat, not build autonomous behavior. `ShipGate.agentsEnabled` stays `false` for release.

### 3a. Extract: ProviderMessage Streaming Pattern from Goose

Goose's `ProviderMessage` enum is the cleanest model for typed streaming:[^11]

```rust
pub enum ProviderMessage {
    Text(String),
    ToolUse(ToolRequest),
    Thinking(String),
    Usage(TokenUsage),
    Done,
}
```

The equivalent Swift adaptation for `LLMService`:

```swift
enum LLMStreamEvent {
    case text(String)
    case toolUse(toolName: String, toolInput: [String: Any])
    case thinking(String)           // for Claude extended thinking
    case usage(inputTokens: Int, outputTokens: Int, cacheReadTokens: Int)
    case done
}
```

If `LLMService` already streams via `AsyncThrowingStream` or similar, map the Anthropic SSE events to `LLMStreamEvent` cases. This gives `NoteChatState` a typed stream to consume rather than raw text, enabling tool_use interception without the agent loop.

***

### 3b. Extract: Context Compaction from Goose/agent_core

Goose triggers auto-compaction at 80% of the model's context limit and uses a separate summarization call to condense older messages. The compaction prompt template (`compaction.md`) is the key extraction asset.[^12]

**Port to Epistemos**:

```swift
class ChatCompactor {
    static let summarizationPrompt = """
    You are summarizing a conversation for context preservation.
    Compress the following messages into a concise summary that preserves:
    - All decisions made and their rationale
    - All file edits applied and their locations
    - Key facts and constraints established
    - Open questions and next steps
    
    Output only the summary, no commentary.
    """
    
    static func shouldCompact(messages: [SDMessage], modelContextLimit: Int) -> Bool {
        let estimatedTokens = messages.reduce(0) { $0 + ($1.content.count / 4) }
        return Double(estimatedTokens) / Double(modelContextLimit) > 0.80
    }
    
    static func compact(
        messages: [SDMessage],
        using llm: CloudConfigurableLLMClient
    ) async throws -> SDMessage {
        // Keep last 4 messages in full; summarize everything before
        let recent = Array(messages.suffix(4))
        let toCompact = Array(messages.dropLast(4))
        let summary = try await llm.generate(
            system: summarizationPrompt,
            messages: toCompact.map(\.asLLMMessage)
        )
        return SDMessage(role: .system, content: "[Context summary]\n\(summary)")
    }
}
```

The threshold and tool-call cutoff patterns from Goose (`GOOSE_AUTO_COMPACT_THRESHOLD`, `GOOSE_TOOL_CALL_CUTOFF`) should become per-chat settings in Epistemos settings.[^12]

***

### 3c. Extract: Prompt Caching from agent_core

Anthropic prompt caching reduces costs by 10x for cached reads and requires a minimum of 1,024 tokens for Claude Sonnet. The cache marker goes on the last stable block before variable content:[^13]

```swift
// In LLMService.generateStructuredAnthropic (or the message builder):
func buildCachedRequest(system: String, fileContent: String?, messages: [LLMMessage]) -> AnthropicRequest {
    var systemBlocks: [ContentBlock] = [
        ContentBlock(type: "text", text: system,
                     cacheControl: CacheControl(type: "ephemeral"))  // cache system prompt
    ]
    if let graph = graphContextProvider?() {
        systemBlocks.append(ContentBlock(type: "text", text: graph,
                                         cacheControl: CacheControl(type: "ephemeral"))) // cache graph
    }
    // File content: NOT cached (changes per edit)
    if let fc = fileContent {
        systemBlocks.append(ContentBlock(type: "text", text: fc))
    }
    return AnthropicRequest(system: systemBlocks, messages: messages)
}
```

Track `cache_read_input_tokens` and `cache_creation_input_tokens` from the response to report savings in the debug/token usage overlay.[^14]

***

### 3d. Extract: Tool Catalog Pattern from omega-mcp

`omega-mcp`'s `catalog.rs` provides a registry of tool definitions. The pattern to extract: a static catalog that emits tool definitions in either Anthropic or OpenAI format depending on the active provider.

```swift
// In StructuredOutput.swift:
struct CloudTool {
    let name: String
    let description: String
    let inputSchema: [String: Any]  // JSON Schema object
    
    func asAnthropicTool() -> [String: Any] {
        return ["name": name, "description": description, "input_schema": inputSchema]
    }
    
    func asOpenAITool() -> [String: Any] {
        return ["type": "function", "function": [
            "name": name, "description": description, "parameters": inputSchema
        ]]
    }
}

enum ToolCatalog {
    static let fileOps: [CloudTool] = FileEditTool.all.map { schema in
        CloudTool(name: schema.name, description: schema.description,
                  inputSchema: schema.schema)
    }
    static let readOnly: [CloudTool] = [/* read_file_range, list_file_tree, etc. */]
}
```

This mirrors the Goose provider abstraction where tool formats are translated per-provider.[^11]

***

### 3e. Extract: Hermes Skill Prompts

From `hermes-agent/hermes/skills/`, the value is the prompt template engineering — not the execution machinery. Extract skill prompt files as static strings in a `SkillPromptLibrary.swift`:

```swift
enum SkillPromptLibrary {
    static let codeReview = """
    You are reviewing code for clarity, correctness, and Swift idioms.
    Focus on: error handling, optionals safety, memory management, API usage.
    Do not rewrite; provide specific, actionable suggestions with line references.
    """
    
    static let documentationWriter = """
    Generate Apple-style documentation comments for the following Swift code.
    Use /// triple-slash format. Include parameters, returns, throws where applicable.
    """
    
    static let refactorHelper = """
    You are refactoring Swift code. Preserve exact behavior. Improve:
    - Naming clarity, function decomposition, protocol conformances
    Output only the refactored code blocks, no explanation.
    """
}
```

These can be surface as quick-select chips in the ask bar ("Review", "Document", "Refactor") that prepend the skill prompt to the user's message.

***

## Feature 4: Hide Agent UI

### Audit Results (files to act on)

| File | Action | Rationale |
|------|--------|-----------|
| `AgentPanelContainer.swift` | Gate with `ShipGate.agentsEnabled` | Entire panel is agent-only |
| `AgentSessionPanel.swift` | Gate with `ShipGate.agentsEnabled` | Session management is agent-only |
| `HermesSkillsView.swift` | **Repurpose** as skill chip selector in ask bar | UI pattern (chip grid) is useful for cloud chat |
| `HermesExecutionGraphView.swift` | Gate with `ShipGate.agentsEnabled` | Execution graph is agent-only; not applicable to cloud chat |
| Menu items referencing agents | Remove or gate | Dead code in release build |

### ShipGate Pattern

```swift
// In AppBootstrap.swift, ShipGate struct:
struct ShipGate {
    static let agentsEnabled: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["ENABLE_AGENTS"] == "1"
        #else
        return false
        #endif
    }()
    
    // New gate for file ops (gradual rollout)
    static let fileOpsEnabled: Bool = true  // ship with v1
    
    // New gate for compaction
    static let chatCompactionEnabled: Bool = true
}
```

Wrap all agent views:

```swift
if ShipGate.agentsEnabled {
    AgentPanelContainer(...)
}
```

The `HermesSkillsView` chip-grid layout should be extracted to a generic `ChipGridView<T>` and reused by the ask bar's skill prompt selector, keeping the UI work rather than discarding it.

***

## Implementation Order

Given the codebase state (code editor built, AI ops brainstormed, agents researched), the recommended sequencing by risk and user impact:

| Priority | Feature | Complexity | Unlock |
|----------|---------|-----------|--------|
| 1 | Editor switching (`NoteDetailWorkspaceView`) | Low | Activates CodeEditorView for all code files |
| 2 | Current line highlight | Low | Core polish; reuses existing NSLayoutManager |
| 3 | File edit tool definitions + `noteRangeWriter` | Medium | Foundation for everything AI ops |
| 4 | Diff preview artifact (`FileEditArtifactView`) | Medium | User-facing AI ops experience |
| 5 | Bracket matching | Medium | Polish |
| 6 | Prompt caching | Low | Cost reduction; 10x cheaper repeated requests |
| 7 | Minimap | High | Big visual feature; standalone NSView |
| 8 | Context compaction | Medium | Long-session quality |
| 9 | Indent guides | Low | Polish |
| 10 | Additional tree-sitter languages | Low | Expand coverage |
| 11 | Hide agent UI | Low | Release hygiene |
| 12 | Skill prompt library / ask bar chips | Low | Discoverability |

***

## Key Technical Constraints and Gotchas

- **Apply operations bottom-to-top**: If multiple `edit_file` operations are returned in one response, always sort by `start_line` descending before applying. Applying top-to-bottom shifts line numbers and corrupts subsequent operations.[^6]
- **NSLayoutManager vs TextKit 2**: Epistemos uses NSLayoutManager (TextKit 1) for the code editor. STTextView is a TextKit 2 alternative but the migration cost is non-trivial. Stay on NSLayoutManager for v1; the `drawBackground` override pattern works cleanly.[^15][^2]
- **Minimap performance**: Rebuild `tokenRects` only on document change, not on every scroll. Scroll events should only update `viewportOffset` and trigger a cheap `needsDisplay`.
- **Prompt cache invalidation**: Anthropic's prompt cache is prefix-based — any change to a prefix-matched block invalidates the cache. Structure system blocks as: `[system (stable), graph (semi-stable), file (volatile)]`. Never reorder these.[^16]
- **Bracket matching on large files**: The bracket scan is O(n) in the worst case. Cap the scan range at ±10,000 characters from the cursor to avoid lag on megabyte files.
- **Diff rejection with undo**: When the user rejects a diff, call `textView.undoManager?.undo()` rather than storing a snapshot. This integrates naturally with ⌘Z behavior.

---

## References

1. [VS Code tips — The editor.minimap.renderCharacters setting](https://www.youtube.com/watch?v=f1TTFWJKWKc) - Today's VS Code setting: editor.minimap.renderCharacters When you disable editor.minimap.renderChara...

2. [drawBackground(forGlyphRange:at:) - Apple Developer](https://developer.apple.com/documentation/appkit/nslayoutmanager/drawbackground(forglyphrange:at:)) - This method is called by NSTextView for drawing. You can override it to perform additional drawing, ...

3. [NSTextView and Syntax Highlighting - cocoa-dev@lists.apple.com](https://cocoa-dev.apple.narkive.com/Qhu50yyS/nstextview-and-syntax-highlighting) - In my text-editing app, there are some special characters I'd like to highlight whenever they are en...

4. [Cargo.toml - kreuzberg-dev/tree-sitter-language-pack - GitHub](https://github.com/kreuzberg-dev/tree-sitter-language-pack/blob/main/crates/ts-pack-core/Cargo.toml) - Comprehensive tree-sitter grammar compilation with polyglot bindings — Rust, Python, Node.js, Go, Ja...

5. [Cursor automatically applies AI edits without showing diff preview or ...](https://forum.cursor.com/t/cursor-automatically-applies-ai-edits-without-showing-diff-preview-or-undo-keep-options/154011) - Previously, Cursor showed a diff preview with options like Undo, Keep, or Apply, but those options h...

6. [Building Cursor with Cursor: A Step-by-Step Guide to Creating Your ...](https://dev.to/zachary62/building-cursor-with-cursor-a-step-by-step-guide-to-creating-your-own-ai-coding-agent-17c4) - In this step-by-step guide, we'll dive deep into the code to show you how to build a powerful AI ass...

7. [How to Use Prompt Caching and Cache Control with Anthropic Models](https://www.firecrawl.dev/blog/using-prompt-caching-with-anthropic) - Anthropic recently launched prompt caching and cache control in beta, allowing you to cache large co...

8. [Prompt caching - Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) - Prompt caching references the entire prompt - tools , system , and messages (in that order) up to an...

9. [[Regression] AI edits applying automatically without Diff/Approval UI](https://forum.cursor.com/t/regression-ai-edits-applying-automatically-without-diff-approval-ui/154887) - Cursor should show the inline diff view with “Accept” and “Reject” buttons for all file modification...

10. [Does the cursor.sh inline-diff-suggestions feature exist in Neovim ...](https://www.reddit.com/r/neovim/comments/1auh6of/does_the_cursorsh_inlinediffsuggestions_feature/) - After the edits complete, they can visit each individual change and accept, reject, or ask for anoth...

11. [Providers - Goose - Mintlify](https://www.mintlify.com/block/goose/concepts/providers) - Handles authentication and API keys; Streams responses back to the agent; Manages tool calling proto...

12. [Smart Context Management | goose - GitHub Pages](https://block.github.io/goose/docs/guides/sessions/smart-context-management/) - goose automatically compacts (summarizes) older parts of your conversation when approaching token li...

13. [Understanding Prompt Caching for API Efficiency - Instructor](https://python.useinstructor.com/concepts/prompt_caching/) - Prompt Caching is a feature that allows you to cache portions of your prompt, optimizing performance...

14. [SwiftAnthropic/README.md at main - GitHub](https://github.com/jamesrochabrun/SwiftAnthropic/blob/main/README.md) - When Claude decides to use one of the tools you've provided, it will return a response with a stop_r...

15. [STTextView - Swift Package Registry](https://swiftpackageregistry.com/krzyzanowskim/STTextView) - The goal of this project is to build NSTextView/UITextView replacement reusable component utilizing ...

16. [A quick guide on prompt caching with OpenAI, Anthropic, and Google](https://prompthub.substack.com/p/a-quick-guide-on-prompt-caching-with) - In this post, we'll cover how you can use prompt caching with three major providers: OpenAI, Anthrop...

