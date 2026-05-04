# Custom Text Engine Research — Xcode-Grade 120fps Code Editor

> **Index status**: CANONICAL-RESEARCH — 2026-04-07 120fps code editor research (Zed GPU renderer + Nova CoreText + Sublime rope tree + VSCode chunked buffer).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



## For: Implementation planning (multi-session project)
## Date: 2026-04-07

---

## How the Fast Editors Do It

### Zed (Rust + Metal)
**Architecture:** Custom GPU renderer (GPUI) that treats text like a video game.

**Pipeline:**
1. **Text shaping** — CoreText converts characters → glyphs + positions (cached per text-font pair)
2. **Glyph rasterization** — CoreText rasterizes alpha-only bitmaps for each glyph (16 sub-pixel variants per glyph for crisp rendering)
3. **Atlas packing** — Rasterized glyphs packed into a GPU texture atlas using bin-packing (etagere)
4. **GPU drawing** — Single instanced Metal draw call per frame. Each glyph instance = `{target_position, atlas_position, size, color}`. Fragment shader samples alpha from atlas, multiplies by color.

**Why it's fast:** The CPU only reshapes changed text. Everything else is a GPU bandwidth operation — copying pixels from atlas to framebuffer. Unchanged text reuses cached glyphs. Syntax colors are just a `float4 color` per glyph instance — no re-rasterization needed.

**Key insight:** Text is NOT rendered through NSTextView/TextKit. CoreText is used ONLY for shaping (character → glyph mapping) and rasterization (glyph → pixels). Layout, scrolling, and drawing are entirely custom.

Sources: [Zed Blog](https://zed.dev/blog/videogame), [GPUI README](https://github.com/zed-industries/zed/blob/main/crates/gpui/README.md)

---

### Nova (Panic) — Custom CoreText Engine
**Architecture:** Custom text layout manager written from scratch in Objective-C/Swift, replacing Apple's TextKit entirely.

**Key facts:**
- Panic wrote their own text layout engine to fix bugs in Apple's layout manager
- The custom engine boosted performance and fixed rendering bugs
- Uses CoreText for shaping but custom layout/drawing pipeline
- Native macOS look and feel preserved

Source: [MacStories Review](https://www.macstories.net/reviews/nova-review-panics-code-editor-demonstrates-why-mac-like-design-matters/)

---

### CodeEdit (CodeEditTextView) — CoreText + Lazy Layout
**Architecture:** Custom `NSView` subclass using CoreText directly (not NSTextView, not TextKit).

**Key facts:**
- Loads million-line files in milliseconds
- Lazy layout — only lays out visible lines
- Multiple cursor support
- Pure Swift, no TextKit dependency
- Dependencies: TextStory (ChimeHQ), swift-collections

**Why they built it:** STTextView had performance problems with large documents that they couldn't optimize out. Their custom CoreText approach solved it.

Source: [CodeEditTextView GitHub](https://github.com/CodeEditApp/CodeEditTextView), [TextKit 2 blog post](https://mjtsai.com/blog/2025/08/15/textkit-2-the-promised-land/)

---

## The Three Approaches Ranked

| Approach | Performance | Effort | Native Look | Syntax Colors |
|----------|------------|--------|-------------|---------------|
| **Metal GPU renderer** (Zed-style) | Best (120fps guaranteed) | 3-6 months | Requires careful tuning | Per-glyph coloring in shader |
| **CoreText direct** (CodeEdit-style) | Excellent (million-line files) | 2-4 weeks | Native (uses CoreText shaping) | Applied as CTRun attributes |
| **TextKit 2 optimized** (current) | Acceptable for <30KB files | Done | Native | Via temporary attributes |

---

## RECOMMENDATION: CodeEdit's Approach (CoreText Direct)

### Why

1. **Already proven** — CodeEditTextView loads million-line files in milliseconds. It's not theoretical.
2. **Pure Swift** — No Rust, no Metal shaders, no WGSL. Fits Epistemos's Swift codebase.
3. **NSView subclass** — Works with NSScrollView, standard AppKit patterns. Can be wrapped in NSViewRepresentable.
4. **CoreText shaping** — Text looks identical to native macOS apps (same as Xcode).
5. **Lazy layout** — Only visible lines are laid out. Off-screen lines are estimated by height.
6. **Already has syntax highlighting integration** — CodeEditSourceEditor adds tree-sitter on top.
7. **2 dependencies** — TextStory + swift-collections. Minimal.

### How It Works (Conceptual)

```
Document (String)
    ↓
LineStorage (array of line metadata: offset, height, attributes)
    ↓
ViewportLayoutManager
    ├── Determines which lines are visible (scroll position + view height)
    ├── Calls CoreText to shape ONLY visible lines
    └── Caches line heights for scroll estimation
    ↓
NSView.draw(_:)
    ├── For each visible line:
    │   ├── Create CTLine from attributed string slice
    │   ├── Draw CTLine at calculated Y position
    │   └── Cache the CTLine for reuse
    └── Draw gutter (line numbers) in parallel
    ↓
Scroll handling
    ├── New visible lines → shape and draw
    ├── Old visible lines → remove from cache
    └── Estimate total content height from line count × average line height
```

### What We'd Build

1. **`EpistemosTextView`** — NSView subclass, NOT NSTextView
   - CoreText for text shaping (`CTTypesetter` → `CTLine`)
   - Viewport-only layout (only lay out visible lines)
   - Line height cache (estimate off-screen heights)
   - CALayer-based current line highlight
   - Gutter overlay for line numbers

2. **Syntax highlighting** — Our existing Rust FFI tree-sitter
   - Tokenize on background thread
   - Apply colors as `CTRun` foreground color attributes
   - Incremental re-tokenization on edit (only changed paragraphs)

3. **SwiftUI bridge** — NSViewRepresentable wrapper
   - `$text` binding
   - `$selection` binding
   - Theme environment

4. **Minimap** — Separate CALayer or NSView
   - Scaled-down CoreText rendering (2pt font)
   - Section headers from `// MARK:` comments
   - Click-to-scroll

### Integration with Existing Code

| Existing Component | Reuse? | How |
|-------------------|--------|-----|
| `graph-engine/src/code_highlight.rs` | ✅ Yes | Tree-sitter tokenization on background thread |
| `CodeLanguage.detect()` | ✅ Yes | File extension → language detection |
| `EpistemosTheme.XcodeCodeColors` | ✅ Yes | Token type → NSColor mapping |
| `CodeSyntaxHighlighter` | ✅ Yes | FFI call wrapper |
| `CodeEditorView` (mchakravarty) | ❌ Remove | Replace with custom engine |

### Estimated Effort

| Phase | Work | Time |
|-------|------|------|
| Phase 1: Basic text rendering | CoreText NSView, viewport layout, scroll | 1 session |
| Phase 2: Editing | Keyboard input, cursor, selection, undo | 1-2 sessions |
| Phase 3: Syntax highlighting | Rust FFI on background thread, color application | 1 session |
| Phase 4: Gutter + minimap | Line numbers, minimap, current line highlight | 1 session |
| Phase 5: Polish | Bracket matching, indent guides, find/replace | 1-2 sessions |

Total: **5-8 sessions** for an Xcode-grade code editor.

### Alternative: Use CodeEditTextView Directly

Instead of building from scratch, we could **add CodeEditTextView + CodeEditSourceEditor as SPM dependencies**. They've already solved the hard problems. The risk: they're marked "not production ready" and have their own bugs. But their CoreText engine IS fast.

```
https://github.com/CodeEditApp/CodeEditTextView
https://github.com/CodeEditApp/CodeEditSourceEditor
```

This would be a **1-2 session integration** instead of 5-8 sessions building from scratch.

---

## Sources

- [Zed Blog: Leveraging Rust and the GPU to render UIs at 120fps](https://zed.dev/blog/videogame)
- [GPUI Framework Deep Wiki](https://deepwiki.com/zed-industries/zed/2.2-ui-framework-(gpui))
- [Zed Metal Shaders Discussion](https://github.com/zed-industries/zed/discussions/14592)
- [CodeEditTextView](https://github.com/CodeEditApp/CodeEditTextView)
- [CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor)
- [TextKit 2: The Promised Land](https://mjtsai.com/blog/2025/08/15/textkit-2-the-promised-land/)
- [Nova Review (MacStories)](https://www.macstories.net/reviews/nova-review-panics-code-editor-demonstrates-why-mac-like-design-matters/)
- [STTextView](https://github.com/krzyzanowskim/STTextView)
- [Core Text Documentation](https://developer.apple.com/documentation/coretext/)
- [Metal Text Rendering with SDFs](https://metalbyexample.com/rendering-text-in-metal-with-signed-distance-fields/)
