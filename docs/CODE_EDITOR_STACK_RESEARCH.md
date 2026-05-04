# Code Editor Stack Research — Best Path Forward

> **Index status**: CANONICAL-RESEARCH — 2026-04-07 best-path research for Xcode-grade editor (CodeEditorView recommended + Zed/Nova/VSCode patterns); 120fps target.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



## For: Implementation (Kimi or Claude)
## Date: 2026-04-07

---

## Goal

Build an Xcode-grade code editor surface inside Epistemos that:
- Renders visible text with syntax highlighting (tree-sitter powered)
- Has a smooth minimap with section headers (like Xcode's `// MARK:` rendering)
- Has line numbers in a gutter
- Is native macOS (no web views, no Electron)
- Works on macOS 14+ (Sonoma/Tahoe) without invisible text bugs
- Matches Xcode's dark mode (charcoal `#1F1F24`, NOT OLED black)
- Is smooth at 120fps on ProMotion displays
- Is minimal — fewest dependencies possible

---

## Options Evaluated

### Option A: CodeEditorView (mchakravarty) ⭐ RECOMMENDED

**Repo:** [github.com/mchakravarty/CodeEditorView](https://github.com/mchakravarty/CodeEditorView)
**License:** Apache 2.0
**Maturity:** 4 years development, 343 commits, 11 releases, pre-1.0 but actively maintained

**What it is:** A SwiftUI-native code editor view inspired by Xcode, based on TextKit 2.

**Why it's the best fit:**
1. **Pure SwiftUI API** — `CodeEditor(text: $text, position: $position, messages: $messages, language: .swift())` with environment-based theming
2. **TextKit 2** — Uses `NSTextLayoutManager` with viewport-only layout, no `drawBackground` override (avoids the Tahoe bug entirely)
3. **Minimap with document outline** — macOS-only feature that renders section headers from `// MARK:` comments, just like Xcode
4. **Current line highlighting, bracket matching, bracket insertion** — all built in
5. **Configurable themes** — `Theme.defaultDark` / `Theme.defaultLight` via environment
6. **Inline messages** — warnings/errors/info displayed inline
7. **macOS 12+** compatibility
8. **No external dependencies** — pure Swift, no tree-sitter dependency (uses regex-based FSM tokenizer)
9. **Code completion + identifier info** on macOS

**Tradeoffs:**
- Uses regex tokenizer, NOT tree-sitter. Less accurate than tree-sitter for complex grammars but works for all common languages. We can potentially replace its tokenizer with our Rust tree-sitter FFI later.
- Pre-1.0 quality — some known bugs
- Minimap uses the macOS typesetter API (not available on iOS, but we don't need iOS)

**Integration effort:** LOW — add SPM dependency, replace `TextEditor` with `CodeEditor`, wire theme

### Option B: CodeEditSourceEditor (CodeEdit project)

**Repo:** [github.com/CodeEditApp/CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor)
**License:** MIT

**What it is:** The editor component from CodeEdit (open-source Xcode replacement), powered by tree-sitter.

**Pros:**
- Tree-sitter native (via SwiftTreeSitter from ChimeHQ)
- Minimap, line numbers, bracket matching, code completion
- SwiftUI + AppKit APIs
- MIT license

**Cons:**
- **"Not ready for production use"** per their own README
- Heavy dependency tree (SwiftTreeSitter, CodeEditTextView, CodeEditLanguages)
- Designed for CodeEdit's architecture, may be hard to integrate standalone
- Uses a custom text view (CodeEditTextView), not NSTextView or TextKit 2

**Integration effort:** MEDIUM-HIGH — many dependencies, custom text view architecture

### Option C: STTextView + Neon

**Repo:** [github.com/krzyzanowskim/STTextView](https://github.com/krzyzanowskim/STTextView) + [github.com/ChimeHQ/Neon](https://github.com/ChimeHQ/Neon)

**What it is:** STTextView is a complete NSTextView replacement using TextKit 2. Neon is a tree-sitter-based syntax highlighting library. Together they form a code editor.

**Pros:**
- Most mature TextKit 2 implementation (1,163 commits, 113 releases, v2.2.0+)
- macOS 14+ (perfect for Tahoe)
- Line numbers built in (`showsLineNumbers = true`)
- SwiftUI wrapper included
- Neon provides tree-sitter integration via TreeSitterClient
- Text-system agnostic — Neon works with any text system

**Cons:**
- Two separate packages to integrate and coordinate
- No built-in minimap (would need to build one)
- No built-in bracket matching (would need to add)
- Neon's tree-sitter integration adds complexity (SwiftTreeSitter + language grammars)

**Integration effort:** HIGH — two packages, no minimap, need to build several features

### Option D: Keep Custom NSTextView (Current Approach)

**What it is:** The existing `CodeTextView` NSTextView subclass with our `drawBackground` override.

**Pros:**
- Already built, has all features (gutter, minimap, syntax highlighting, bracket matching)
- Uses our existing Rust tree-sitter FFI (no new dependencies)

**Cons:**
- **Broken on macOS Tahoe** — invisible text due to `drawBackground` overpaint
- TextKit 1 — eager full-document layout, poor performance on large files
- `drawBackground` override is fundamentally incompatible with Sonoma+'s `clipsToBounds = false`
- Every fix attempt has failed across multiple sessions

**Integration effort:** ZERO (already exists) but UNFIXABLE on Tahoe without rewriting the rendering pipeline

### Option E: SwiftUI TextEditor (Current Working Fallback)

**What it is:** The pure SwiftUI `TextEditor` that's currently showing text.

**Pros:**
- Works on Tahoe ✅
- Zero dependencies
- Editable, scrollable

**Cons:**
- No syntax highlighting
- No line numbers
- No minimap
- No bracket matching
- No current line highlight
- No code-specific features at all

---

## RECOMMENDATION: Option A (CodeEditorView by mchakravarty)

### Why

1. **It works.** TextKit 2 viewport rendering doesn't use `drawBackground`, so it avoids the Tahoe bug entirely.
2. **It looks like Xcode.** Minimap with `// MARK:` section headers, syntax colors, dark theme — all Xcode-inspired.
3. **Minimal integration.** One SPM dependency, one SwiftUI view. No container NSView, no constraints, no NSViewRepresentable headaches.
4. **Fewest dependencies.** Pure Swift, no tree-sitter SPM packages needed (uses regex tokenizer). Our Rust FFI tree-sitter can be wired in later for better accuracy.
5. **Dark mode matches Xcode.** Has `Theme.defaultDark` that uses Xcode's charcoal palette, not OLED black.

### Integration Plan

**Step 1: Add SPM dependency**
In Xcode: File → Add Package Dependencies → `https://github.com/mchakravarty/CodeEditorView`

**Step 2: Replace the SwiftUI TextEditor fallback**
```swift
import CodeEditorView

struct CodeEditorView: View {
    let initialContent: String
    let language: String
    let onContentChange: ((String) -> Void)?

    @Environment(UIState.self) private var ui
    @State private var text: String = ""
    @State private var position: CodeEditor.Position = .init()
    @State private var messages: Set<Located<Message>> = []

    var body: some View {
        VStack(spacing: 0) {
            CodeEditor(
                text: $text,
                position: $position,
                messages: $messages,
                language: codeEditorLanguage
            )
            .environment(\.codeEditorTheme,
                ui.theme.isDark ? Theme.defaultDark : Theme.defaultLight)
            .onAppear { text = initialContent }
            .onChange(of: text) { _, newValue in
                onContentChange?(newValue)
            }

            // Status bar
            HStack(spacing: 16) {
                Text("Line: \(position.selections.first?.line ?? 1)  Col: \(position.selections.first?.column ?? 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(CodeLanguage.displayName(for: language))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.bar)
        }
    }

    private var codeEditorLanguage: LanguageConfiguration {
        switch language {
        case "swift": return .swift()
        case "python": return .python()
        case "javascript": return .javaScript()
        case "json": return .json()
        case "html": return .html()
        case "css": return .css()
        case "rust": return .rust() // if available
        default: return .none
        }
    }
}
```

**Step 3: Custom Xcode theme (if defaults don't match)**
```swift
extension Theme {
    static let epistemosDark = Theme(
        // ... customize with XcodeCodeColors values from EpistemosTheme.swift
    )
}
```

**Step 4: Remove old CodeEditorRepresentable and CodeTextView**
Once CodeEditorView works with the SPM package, the old NSViewRepresentable bridge, CodeTextView subclass, LineNumberGutter, and MinimapView classes can be removed (~800 lines of dead code).

### What We Keep

- `CodeLanguage.detect(from:)` — file extension detection (line 22-88)
- `EpistemosTheme.XcodeCodeColors` — color values for theme customization
- `graph-engine/src/code_highlight.rs` — Rust FFI tree-sitter tokenization (for future integration)
- `CodeInspectorPreview` / `CodeInspectorEditor` — graph node inspector views

### What We Remove

- `CodeEditorRepresentable` — the broken NSViewRepresentable
- `CodeTextView` — the NSTextView subclass with `drawBackground` issue
- `LineNumberGutter` — replaced by CodeEditorView's built-in gutter
- `MinimapView` — replaced by CodeEditorView's built-in minimap

---

## Minimap Quality Notes

### What Xcode's Minimap Does
- Renders actual scaled-down text (not pixel blocks)
- Shows `// MARK: -` section headers as readable bold labels
- On hover: shows symbol name at cursor position
- On Cmd+hover: shows list of all symbols
- Highlights bracket pairs with blue brackets on hover
- Shows git changes, breakpoints, cursor position

### What CodeEditorView's Minimap Does
- Renders scaled-down text using macOS typesetter API
- Shows document outline with section headers
- Click to scroll
- Viewport indicator

This is much closer to Xcode's quality than our current pixel-rect minimap.

---

## Dark Mode

### Xcode Default Dark (what we want)
- Background: `#1F1F24` (charcoal)
- Foreground: `#DFDFE0` (light gray)
- Current line: `#23252B`
- NOT OLED black (`#000000`)

### CodeEditorView's Theme.defaultDark
- Should closely match Xcode's palette
- Can be customized via the `Theme` struct to use exact `XcodeCodeColors` values

---

## Alternative: If CodeEditorView Doesn't Work

If CodeEditorView has its own rendering issues on Tahoe, the fallback plan is:

1. **Keep SwiftUI TextEditor** for text rendering (proven working)
2. **Add syntax highlighting via AttributedString** — use our Rust FFI to tokenize, convert tokens to `AttributedString` with colors, pass to a custom `Text` view
3. **Build a simple gutter overlay** — SwiftUI `HStack` with line numbers
4. **Skip minimap** for v1, add later

This is more work but uses only proven-working SwiftUI primitives.

---

## Sources

- [CodeEditorView](https://github.com/mchakravarty/CodeEditorView) — Xcode-inspired SwiftUI code editor
- [CodeEditorView Architecture](https://github.com/mchakravarty/CodeEditorView/blob/main/Documentation/Overview.md) — Internal design docs
- [CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor) — Tree-sitter powered editor (not production ready)
- [STTextView](https://github.com/krzyzanowskim/STTextView) — TextKit 2 NSTextView replacement
- [Neon](https://github.com/ChimeHQ/Neon) — Tree-sitter syntax highlighting library
- [Scintilla Bug #2402](https://sourceforge.net/p/scintilla/bugs/2402/) — Root cause of invisible text on Sonoma
- [Xcode Minimap Features](https://verbalraj.medium.com/xcodes-minimap-2023d662c2a4) — How Xcode's minimap works
