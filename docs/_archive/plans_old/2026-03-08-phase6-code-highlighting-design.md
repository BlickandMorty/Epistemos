# Phase 6: Code Highlighting + Architectural Upgrades — Design

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Context

Phase 6 of the TextKit 2 migration. Phases 1-4 are complete (foundation, base highlighting, marker dimming, drawing). This phase adds language-aware code highlighting to fenced code blocks AND introduces key essay-grade architectural upgrades: custom `NSTextLayoutFragment` subclass, fragment caching, viewport-gated tokenization, and non-destructive folding.

## Decisions

- **tree-sitter** for tokenization. Not syntect. True AST, incremental reparsing, better accuracy for complex languages. Scoped tightly: fenced code blocks only, curated language set, per-block cache, viewport gating.
- **Custom `NSTextLayoutFragment` subclass** (`MarkdownLayoutFragment`). The pivotal TK2 architectural upgrade. Direct Core Graphics rendering in `draw(at:in:)`, fragment-level bitmap caching, viewport-natural lifecycle.
- **`shouldEnumerate` delegate** for non-destructive folding. Replaces the storage-rewriting `"…\n"` hack.
- **Pre-allocated buffers** for FFI. Caller-owns-buffer pattern (same as `markdown_parse_structure`). No mmap/ring-buffer — unnecessary at note-editor workload scale.
- **Code blocks get custom fragments first.** Other paragraph types follow in later phases.

## Sub-Phases

### 6a: tree-sitter in Rust + FFI

**Rust side:**

New file: `graph-engine/src/code_highlight.rs`

Depends on: `tree-sitter` crate + grammars for curated language set.

Curated languages (day one):
- Swift, Rust, Python, JavaScript/TypeScript, JSON, HTML/CSS, Shell/Bash, Go, C/C++

Unsupported languages → fallback to plain monospace (no tokenization attempt).

**Per-block tree cache:**
- `HashMap<u64, tree_sitter::Tree>` keyed by hash of code body text
- On edit within block: tree-sitter incremental `edit()` + `parse()` — reparses only delta
- On no change: serve cached tree, walk it for token spans

**FFI struct:**

```rust
#[repr(C)]
pub struct CodeToken {
    pub start: u32,       // byte offset into code block text
    pub end: u32,         // byte offset (exclusive)
    pub token_type: u8,   // 0=keyword, 1=string, 2=number, 3=comment,
                          // 4=function, 5=type, 6=operator, 7=punctuation,
                          // 8=variable, 9=property, 10=constant, 11=tag,
                          // 12=attribute, 255=plain
    pub _pad: [u8; 3],
}
```

**FFI function:**

```rust
#[no_mangle]
pub unsafe extern "C" fn markdown_parse_code_tokens(
    code: *const c_char,
    code_len: u32,
    language: *const c_char,  // null-terminated language tag from fence
    out_tokens: *mut CodeToken,
    max_tokens: u32,
) -> u32  // returns count written
```

Pre-allocated buffer: Swift allocates 4096-token buffer, passes pointer. Zero per-call heap allocation on either side.

**Language tag propagation:**

Extend `markdown_parse_structure()` to pack language enum into `StructureSpan.metadata` low byte for code block lines. The structure parser already tracks fence state — carry the language ID forward to each line inside the fence.

Language enum: 0=unknown, 1=swift, 2=rust, 3=python, 4=javascript, 5=typescript, 6=json, 7=html, 8=css, 9=shell, 10=go, 11=c, 12=cpp.

**tree-sitter node → token type mapping:**

Walk the syntax tree depth-first. Map node kinds to token types:
- `identifier` in function position → function(4)
- `identifier` in type position → type(5)
- `string_literal`, `string` → string(1)
- `integer_literal`, `float_literal` → number(2)
- `comment`, `line_comment`, `block_comment` → comment(3)
- `keyword`, language-specific keywords → keyword(0)
- Operators → operator(6)
- Punctuation → punctuation(7)
- Fallback → plain(255)

Each language grammar has its own node kind names. Map per-language in Rust.

### 6b: Custom `MarkdownLayoutFragment`

**New file:** `Epistemos/Views/Notes/MarkdownLayoutFragment.swift`

```swift
class MarkdownLayoutFragment: NSTextLayoutFragment {
    var paragraphType: UInt8
    var isActiveLine: Bool
    var codeTokens: [CodeToken]?
    var languageId: UInt8
    var cachedRender: CGImage?

    override func draw(at point: CGPoint, in ctx: CGContext) {
        if let cached = cachedRender {
            ctx.draw(cached, in: renderBounds.offsetBy(dx: point.x, dy: point.y))
            return
        }
        super.draw(at: point, in: ctx)
        if let tokens = codeTokens {
            drawCodeTokenOverlay(tokens, in: ctx, at: point)
        }
        cachedRender = captureCurrentRender()
    }
}
```

**Vending via delegate:**

`NSTextLayoutManagerDelegate` method on `MarkdownContentStorage` (or a new delegate object):

```swift
func textLayoutManager(
    _ tlm: NSTextLayoutManager,
    textLayoutFragmentFor location: NSTextLocation,
    in textElement: NSTextElement
) -> NSTextLayoutFragment
```

For code block paragraphs: return `MarkdownLayoutFragment` with tokens populated.
For all other paragraphs: return default `NSTextLayoutFragment` (current behavior unchanged).

**Code token rendering in `draw()`:**

Use `CTLine` from the fragment's `NSTextLineFragment` to get glyph positions. For each `CodeToken` span, draw a colored rect or override the foreground color at the exact glyph positions. This bypasses the attribute system entirely for code blocks.

**Theme mapping (token type → color):**

| Token Type | Color Source |
|-----------|-------------|
| keyword | theme accent (blue) |
| string | green from palette |
| number | orange from palette |
| comment | gray, italic |
| function | purple from palette |
| type | teal from palette |
| operator | foreground dimmed |
| punctuation | foreground dimmed |
| variable | foreground |
| property | derived from accent |
| constant | orange from palette |
| tag | accent |
| attribute | green from palette |
| plain | foreground monospace |

Add ~6 new computed color properties to `EpistemosTheme`, derived from existing base palette.

### 6c: Fragment Hash Cache + Viewport Gating

**Fragment cache:**

Key: `(paragraph_text_hash: UInt64, theme_id: UInt8, is_active_line: Bool, language_id: UInt8)`
Value: `CGImage` (the rendered bitmap)

Cache lives on `MarkdownContentStorage`. LRU eviction at 256 entries (covers ~10 screenfuls of code blocks).

**Cache invalidation:**
- Keystroke within code block → that fragment's cache entry removed
- Theme change → entire cache cleared
- Cursor move → old + new active line entries removed (2 entries, O(1))
- Page swap → cache transferred with per-page state

**Viewport gating:**

Before tokenizing a code block paragraph, check if it's within the visible range ± 1 screenful.

Visible range comes from `NSTextViewportLayoutController` via the text view's `visibleRect`. Convert to text range using `textLayoutManager.enumerateTextLayoutFragments(from:options:)`.

If the code paragraph is outside the viewport buffer:
- Return plain monospace paragraph (no tokenization)
- When the paragraph scrolls into view, the delegate is called again (TK2 does this naturally via viewport-driven layout)

This means scrolling into a code block triggers tokenization on first appearance, then cache serves it on subsequent visits.

### 6d: Non-Destructive Folding

**Fold state in Rust:**

New fold state: `HashSet<u32>` of folded heading line indices.

New FFI functions:
```rust
#[no_mangle]
pub unsafe extern "C" fn markdown_set_fold(line_index: u32, folded: bool);

#[no_mangle]
pub unsafe extern "C" fn markdown_is_folded(line_index: u32) -> bool;

#[no_mangle]
pub unsafe extern "C" fn markdown_fold_range(
    heading_line: u32,
    out_start: *mut u32,
    out_end: *mut u32,
) -> bool;  // returns false if not a heading
```

`markdown_fold_range` returns the line range that would be hidden when folding a heading (from heading+1 to the next heading of equal or higher level, or end of document).

**`shouldEnumerate` delegate:**

```swift
func textContentManager(
    _ tcm: NSTextContentManager,
    shouldEnumerate textElement: NSTextElement,
    options: NSTextContentManager.EnumerationOptions
) -> Bool {
    let lineIndex = lineIndex(for: textElement)
    return !isWithinFoldedRange(lineIndex)
}
```

`isWithinFoldedRange` checks against the Rust fold state. The heading line itself is always enumerated (it's the fold toggle). Only lines under it are skipped.

**Fold toggle:**
1. User clicks heading triangle (or keyboard shortcut)
2. Call `markdown_set_fold(headingLine, folded: !current)`
3. Get fold range via `markdown_fold_range(headingLine)`
4. Convert line range to `NSTextRange`
5. Call `textContentStorage.processEditing(for:, options: [.layout])` or `textLayoutManager.invalidateLayout(for:)` to trigger re-enumeration
6. `shouldEnumerate` returns false for folded lines → they vanish
7. Draw fold indicator (▶) on the heading fragment

**Expand:** Same flow but `shouldEnumerate` returns true → fragments materialize.

**What this fixes:**
- No storage rewriting — text stays intact
- No zone protection gaps
- No offset drift after fold/unfold
- Undo is unaffected (fold is view state, not document mutation)
- AI streaming and fold state are orthogonal

**Migration:** Replace the storage-rewriting fold code in `ProseEditorRepresentable2` Coordinator. TK1 path keeps its existing fold behavior.

## Files Modified/Created

### New Files
| File | Purpose |
|------|---------|
| `graph-engine/src/code_highlight.rs` | tree-sitter integration, per-block cache, token emission |
| `Epistemos/Views/Notes/MarkdownLayoutFragment.swift` | Custom NSTextLayoutFragment subclass |

### Modified Files
| File | Changes |
|------|---------|
| `graph-engine/src/markdown.rs` | Language tag extraction, fold state, `markdown_parse_code_tokens` FFI |
| `graph-engine/src/lib.rs` | Module declaration, FFI exports |
| `graph-engine/Cargo.toml` | tree-sitter + grammar dependencies |
| `graph-engine-bridge/graph_engine.h` | New FFI declarations |
| `Epistemos/Views/Notes/MarkdownContentStorage.swift` | Viewport gating, code token application, shouldEnumerate delegate, fragment cache |
| `Epistemos/Views/Notes/ProseTextView2.swift` | Wire layout manager delegate for custom fragments |
| `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` | Replace storage-rewriting folds with delegate-based folds |
| `Epistemos/Theme/EpistemosTheme.swift` (or equivalent) | Code token color palette |

## Testing

| Category | Count | Verifies |
|----------|-------|----------|
| tree-sitter tokenization | 10 | Each curated language produces correct token types |
| FFI round-trip | 4 | Pre-allocated buffer, language tag propagation, edge cases |
| Fragment rendering | 4 | Custom fragment created for code, default for non-code, cache hit, cache miss |
| Viewport gating | 3 | Off-screen blocks not tokenized, on-scroll tokenization triggers, near-visible buffer |
| Fragment cache | 4 | Cache hit, cache invalidation on edit, theme change clears, cursor move clears 2 |
| Fold delegate | 5 | Fold hides lines, unfold restores, nested headings, fold at end of doc, fold + edit |
| Language detection | 3 | Known language, unknown language fallback, no language tag |
| Edge cases | 4 | Empty code block, single-line block, giant code block (1000+ lines), rapid edit in code block |

## Performance Targets

| Operation | Target | Mechanism |
|-----------|--------|-----------|
| Tokenize typical code block (50 lines) | <5ms | tree-sitter incremental parse |
| Re-tokenize after edit | <1ms | tree-sitter edit() + parse() delta |
| Scroll through cached code block | 0ms | Fragment bitmap cache hit |
| Fold/unfold | <2ms | shouldEnumerate + localized invalidation |
| Theme switch on code blocks | <10ms | Cache clear + re-tokenize visible blocks only |
