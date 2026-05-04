# TextKit 1 → TextKit 2 Migration — Prose Editor

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Context

The prose editor (`ClickableTextView` + `MarkdownTextStorage` + `ProseEditorRepresentable` + `PageStoragePool`) is built entirely on TextKit 1. TextKit 2 offers viewport-based rendering, a modern element tree model, and better performance at scale. This migration rebuilds the editor from scratch on TextKit 2 while preserving every existing behavior.

## Decisions

- **Clean room rebuild.** New files, informed by existing behavior, not line-by-line porting.
- **Live Preview engine** — Obsidian-beating quality. Markdown syntax collapses when cursor is elsewhere, inline images render, fenced code gets language-aware colors, checkboxes are clickable, callouts render styled, LaTeX renders inline. Raw syntax reappears when cursor enters the line.
- **Structured element model** via `NSTextContentStorageDelegate`. Paragraphs classified as heading/list/code/etc. for layout engine optimization. Internal only — does not change editing UX.
- **Extend Rust FFI parser** with `markdown_parse_structure()` for paragraph-level classification. Existing `markdown_parse()` stays for inline spans.
- **Pool NSTextContentStorage instances** (LRU 12 slots). Same swap pattern as current PageStoragePool.
- **Port drawing to NSTextLayoutFragment** enumeration. Pipe tables keep custom drawing; NSTextTable available in document mode.
- **Feature flag** for runtime A/B switching during migration.

---

## Architecture

### TextKit 2 Stack

```
NSScrollView
  └─ ProseTextView2 (NSTextView, usingTextLayoutManager: true)
       ├─ NSTextContentStorage (owns attributed string)
       │    └─ MarkdownContentStorage (delegate: provides element tree)
       ├─ NSTextLayoutManager (viewport-based, single container)
       │    └─ NSTextLayoutFragment enumeration (replaces glyph queries)
       └─ NSTextContainer (widthTracksTextView, infinite height)
```

### New Files

| New File | Replaces | Purpose |
|----------|----------|---------|
| `ProseTextView2.swift` | `ClickableTextView.swift` | NSTextView subclass, TextKit 2 backed |
| `MarkdownContentStorage.swift` | `MarkdownTextStorage.swift` | NSTextContentStorageDelegate for structured markdown |
| `ProseEditorRepresentable2.swift` | `ProseEditorRepresentable.swift` | NSViewRepresentable + Coordinator |
| `ProseStoragePool2.swift` | `PageStoragePool.swift` | LRU pool of NSTextContentStorage instances |

### What Stays the Same

- Single NSTextView instance across all tabs
- NSScrollView owns height (no SwiftUI layout feedback)
- `isRichText = false` — plain text markdown
- Rust FFI parser for inline style detection
- NSAttributedString keys for styling
- 300ms binding sync debounce
- 60ms AI token buffering
- `isFlushingTokens` / `isSwappingPage` / `isFolding` guards
- Data detection attribute application
- Fold marker insertion/removal logic
- Table alignment debounce (500ms)
- Right-click AI context menu
- Wikilink click handling
- Image drag-drop

---

## Structured Element Model

### Paragraph Types (from Rust parser)

| Type | Markdown Pattern | Rendering |
|------|-----------------|-----------|
| `heading(level: 1-6)` | `# ` through `######` | Scaled font, bold weight |
| `orderedList(depth, index)` | `1. ` / `  1. ` | Indented paragraph, list marker |
| `unorderedList(depth)` | `- ` / `  - ` | Indented paragraph, bullet |
| `taskList(depth, checked)` | `- [ ] ` / `- [x] ` | Checkbox + indent |
| `blockquote(depth)` | `> ` | Left border, muted background |
| `codeBlock(language)` | ` ``` ` | Monospace, background fill |
| `table` | `\|...\|` | Monospace, pipe-aligned grid |
| `horizontalRule` | `---` | Thin line, muted |
| `htmlComment` | `<!-- -->` | Nearly invisible |
| `body` | Everything else | Default paragraph style |

### New Rust FFI

```rust
#[repr(C)]
pub struct StructureSpan {
    pub start_byte: u32,
    pub end_byte: u32,
    pub para_type: u8,    // 0=body..9=htmlComment
    pub metadata: u16,    // heading level, list depth, etc.
}

#[no_mangle]
pub extern "C" fn markdown_parse_structure(
    text: *const c_char,
    out_spans: *mut StructureSpan,
    max_spans: u32,
) -> u32
```

Both `markdown_parse()` (inline spans) and `markdown_parse_structure()` (paragraph types) called per-edit. Structure call is O(lines-in-edited-paragraph).

### Delegate Flow

1. User types → `NSTextContentStorage` detects changed paragraph
2. Delegate `textContentStorage(_:textParagraphWith:)` called
3. Delegate calls `markdown_parse_structure()` on paragraph text
4. Returns `NSTextParagraph` with attributes matching type
5. Calls `markdown_parse()` for inline spans
6. Layout manager renders with new attributes

---

## Drawing & Coordinate Queries

### TextKit 1 → TextKit 2 Mapping

| TextKit 1 | TextKit 2 |
|-----------|-----------|
| `lm.glyphRange(forBoundingRect:in:)` | `tlm.enumerateTextLayoutFragments(from:options:)` with viewport rect |
| `lm.characterRange(forGlyphRange:)` | `fragment.rangeInElement` |
| `lm.glyphIndexForCharacter(at:)` | Not needed — work with fragments |
| `lm.lineFragmentRect(forGlyphAt:)` | `fragment.layoutFragmentFrame` |
| `lm.location(forGlyphAt:)` | `CTLineGetOffsetForStringIndex()` on `NSTextLineFragment.glyphOrigin` |
| `lm.addTemporaryAttribute` | `tlm.setRenderingAttributes([:], for:)` |
| `lm.ensureLayout(for:)` | `tlm.ensureLayout(for:)` |

### Table Drawing (Pipe Tables)

Port 3 draw methods to `NSTextLayoutFragment` enumeration:
1. `drawTableFills` — enumerate visible fragments, detect table lines, fill row backgrounds
2. `drawTableGridLines` — use `CTLine` from `NSTextLineFragment` for pipe x-positions, draw verticals
3. `drawFoldIndicators` — enumerate visible fragments, detect fold markers, draw triangles

### NSTextTable (Document Mode Only)

Document mode format bar inserts native `NSTextTable` + `NSTextTableBlock` for rich tables with resizable columns. Not used in the markdown prose editor.

### Focus Mode Dimming

`tlm.setRenderingAttributes([:], for:)` replaces `lm.addTemporaryAttribute(.foregroundColor, ...)`. Same effect — rendering-only attributes that don't modify text storage.

---

## Coordinator, AI Streaming, Page Swap

### Delegate Methods (Unchanged)

These NSTextViewDelegate methods work identically in TextKit 2:
- `textDidChange(_:)` — text change notification
- `textViewDidChangeSelection(_:)` — selection change
- `textView(_:doCommandBy:)` — command interception (Tab, Shift-Tab)
- `textView(_:clickedOnLink:at:)` — wikilink/blockref click

### AI Streaming

```
startNoteChatStream()
  → textContentStorage.performEditingTransaction {
      insert "<!-- ai-response -->" divider at end
    }
  → isFlushingTokens = true

appendNoteChatTokens(delta:)
  → textContentStorage.performEditingTransaction {
      append delta at end
    }

acceptNoteChatResponse()
  → Find divider, replace with "\n\n"

discardNoteChatResponse()
  → Find divider, delete from divider to end
```

`performEditingTransaction` replaces raw `storage.replaceCharacters`. Ensures content storage, layout manager, and element tree stay synchronized.

### Page Swap (Pool)

```
ProseStoragePool2 {
    slots: [String: PageSlot2]  // pageId → (NSTextContentStorage, selectionRange, scrollY)
    maxSlots: 12

    getOrCreate(pageId:, text:) → PageSlot2
    // Same LRU pattern: evict oldest when > 12
}

On page switch:
1. Save current slot's selection + scroll position
2. Detach current contentStorage from textLayoutManager
3. Attach new slot's contentStorage to textLayoutManager
4. Restore selection + scroll position
5. Trigger re-highlight if needed (chunked)
```

---

## Testing

| Category | Count | Verifies |
|----------|-------|----------|
| TextKit 2 stack | 3 | View creation, element model wiring, viewport layout |
| Structured elements | 10 | Each paragraph type renders correctly |
| Inline highlighting | 8 | Bold, italic, strikethrough, code, wikilink, link, math, nesting |
| Marker collapsing | 8 | Each element type collapses on defocus, expands on focus. Active line tracks cursor. |
| Inline rendering | 6 | Images load async + display, checkboxes toggle, link URLs hide, LaTeX renders |
| Code highlighting | 4 | Language detection, token colors, multi-line blocks, unknown language fallback |
| Callout blocks | 3 | Type detection, colored border/icon, nested content |
| Rust FFI structure | 6 | `markdown_parse_structure()` returns correct types |
| Rust FFI code tokens | 4 | `markdown_parse_code_tokens()` returns correct spans for Swift/Python/JS |
| Drawing | 4 | Table fill, grid lines, fold indicators, focus dimming |
| Page swap | 4 | Pool creation, selection preservation, scroll preservation, LRU eviction |
| AI streaming | 5 | Token append, divider insertion, accept, discard, multi-turn |
| Coordinator | 5 | Binding sync, undo/redo, tab indent, wikilink click, data detection |
| Edge cases | 5 | Empty doc, single char, 100K lines, rapid page switch, concurrent AI + edit |

---

## Live Preview Engine (Beat Obsidian)

The defining quality feature. When the cursor is NOT on a line, markdown syntax collapses and the line renders as clean formatted text. When the cursor moves to a line, the raw syntax reappears for editing.

### Marker Collapsing (The #1 Feature)

**Mechanism:** Track the "active line" (paragraph containing cursor). On selection change:
1. Previous active line: re-apply collapsed rendering (hide markers)
2. New active line: show raw markdown with dimmed markers

**Implementation via `NSTextLayoutManagerDelegate`:**
- `textLayoutManager(_:textLayoutFragmentFor:in:)` — return custom `NSTextLayoutFragment` subclass
- Custom fragment's `draw(at:in:)` checks if its paragraph is the active line
- Active line: renders with visible (dimmed) markers — same as current TextKit 1
- Inactive line: renders with markers hidden (zero-width or `.clear` foreground) and formatted content

**What collapses per element type:**

| Element | Active Line (cursor here) | Inactive Line |
|---------|--------------------------|---------------|
| `# Heading` | `#` dimmed gray, "Heading" large bold | Just "Heading" large bold |
| `**bold**` | `**` dimmed, "bold" rendered bold | Just "bold" rendered bold |
| `*italic*` | `*` dimmed, "italic" rendered italic | Just "italic" rendered italic |
| `` `code` `` | backticks dimmed, "code" monospace pill | Just "code" monospace pill |
| `~~strike~~` | `~~` dimmed, "strike" strikethrough | Just "strike" strikethrough |
| `[text](url)` | Full syntax visible, "text" colored | Just "text" as clickable link |
| `[[wikilink]]` | `[[` `]]` dimmed, "wikilink" colored | Just "wikilink" as clickable link |
| `- [ ] task` | Full syntax, checkbox unchecked | Rendered checkbox + "task" |
| `- [x] done` | Full syntax, checkbox checked | Rendered checkbox (checked) + "done" |
| `> blockquote` | `>` dimmed, text with left border | Just text with left border |

**Performance:** Only 2 paragraphs restyle on each cursor move (old active + new active). O(1) per selection change, not O(document).

### Inline Image Rendering

When parser detects `![alt](path)`:
- **Active line:** Show raw markdown syntax
- **Inactive line:** Replace with `NSTextAttachment` containing the loaded image, sized to fit container width

Image loading is async (off main thread). Placeholder shown until loaded. Images cached per path.

### Fenced Code Syntax Highlighting

When parser detects ` ```language `:
- Extend Rust FFI with `markdown_parse_code_tokens()` that returns language-aware token spans
- Token types: keyword, string, number, comment, function, type, operator, punctuation
- Map to colors from the current theme palette
- Highlighting runs only on visible code blocks (viewport-aware)

Supported languages (initial): Swift, Rust, Python, JavaScript/TypeScript, JSON, HTML/CSS, SQL, Shell/Bash, C/C++, Go, Ruby, Java, Kotlin, Markdown.

The Rust parser can use `tree-sitter` crates for accurate tokenization, or a simpler regex-based tokenizer for speed.

### Clickable Checkboxes

`- [ ]` and `- [x]` task list items:
- Render as actual checkbox glyphs (via `NSTextAttachment` or custom drawing)
- Click toggles the state: modifies the text storage (`[ ]` ↔ `[x]`)
- Checkbox aligned with list bullet position

### Callout Blocks

`> [!note]`, `> [!warning]`, `> [!tip]`, etc.:
- Detect callout type from the `[!type]` marker
- Render with colored left border, icon, and styled background
- Type determines color: note=blue, warning=yellow, tip=green, danger=red, info=cyan
- Callout title rendered as bold, content as normal text

### Inline LaTeX Rendering

`$...$` (inline) and `$$...$$` (block):
- **Active line:** Show raw LaTeX syntax
- **Inactive line:** Render via `NSTextAttachment` containing a rendered LaTeX image
- Rendering uses `NSAttributedString(html:)` with MathML, or a lightweight LaTeX→image renderer
- Block math (`$$`) centered, inline math (`$`) inline with text baseline

### Rendering Attribute Strategy

TextKit 2's `setRenderingAttributes(_:for:)` is the key API:
- Does NOT modify the text storage (markdown stays as-is on disk)
- Only affects rendering (what the user sees)
- Can be updated without triggering `processEditing` or relayout
- Perfect for the active-line/inactive-line switch

For marker collapsing specifically:
- Inactive markers: `setRenderingAttributes([.foregroundColor: .clear, .font: zeroWidthFont], for: markerRange)`
- Active markers: remove rendering attributes, show default styling

---

## Build Progression (Ground Up)

Every phase builds on the previous. Phase 0 fixes the existing document mode. Phases 1-11 build the new TextKit 2 prose editor.

### Mandatory Audit Gate

**Each phase requires 3 consecutive passing audits before advancing to the next phase.** An audit pass includes:
1. **Build** — `xcodebuild build` succeeds with zero errors
2. **Tests** — `xcodebuild test` passes all new/modified tests (pre-existing failures excluded)
3. **Rust tests** — `cargo test` passes (if Rust code changed)
4. **Code review** — spec compliance check (does code match plan?) + code quality check

A single failure resets the counter to 0. Fix the issue, then restart the 3-pass sequence. This prevents false-green passes from flaky tests or environment drift.

### Phase 0: Document Mode Gap Fixes

Shore up the existing TextKit 2 document editor with missing integrations before starting the prose editor rebuild. These features are already working in the TextKit 1 prose editor but absent from document mode.

| Gap | What's Missing | Integration Point | Debounce |
|-----|---------------|-------------------|----------|
| **Wikilinks** | `[[title]]` detection + `.link` attribute + click handling | `DocumentEditorRepresentable.Coordinator.textDidChange` | 300ms |
| **AI Chat** | `NoteChatState` callbacks (stream start, token flush, accept, discard) | `DocumentEditorRepresentable.Coordinator` + `NoteWindowManager` | — |
| **Data Detection** | `DataDetectionService.detect()` + underline styling + click handling | `DocumentEditorRepresentable.Coordinator.textDidChange` | 1s |
| **Rich Text TOC** | `TOCParser.parseRichText()` scanning font sizes (28pt=H1, 22pt=H2, 18pt=H3) | `NoteTableOfContents` + `DocumentEditorRepresentable` save callback | on save |
| **NL Entities** | Already works — `markPageDirty` writes plain-text body mirror, `notifyBodyChanged` triggers graph builder | Verified, no code change | — |

**Files modified:**
- `DocumentEditorRepresentable.swift` — add `isFlushingTokens`, wikilink task, data detection task, AI streaming methods, TOC callback, `onWikilinkClick` callback
- `DocumentTextView.swift` — add `mouseDown` click handler for detected data items, `scrollToCharacterOffset()`
- `NoteTableOfContents.swift` — add `TOCParser.parseRichText()` static method
- `NoteWindowManager.swift` — pass `noteChatState`, `onWikilinkClick`, `onTocChanged` to `DocumentEditorRepresentable`

**Wikilink detection:**
```swift
static func applyWikilinkAttributes(to storage: NSTextStorage) {
    let text = storage.string as NSString
    let fullRange = NSRange(location: 0, length: text.length)
    // Clear old wikilink links
    storage.enumerateAttribute(.link, in: fullRange) { value, range, _ in
        if let str = value as? String, str.hasPrefix("wikilink://") {
            storage.removeAttribute(.link, range: range)
        }
    }
    // Detect [[...]]
    let pattern = "\\[\\[([^\\]]+)\\]\\]"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
    storage.beginEditing()
    for match in regex.matches(in: text as String, range: fullRange) {
        guard match.numberOfRanges >= 2 else { continue }
        let innerRange = match.range(at: 1)
        let title = text.substring(with: innerRange)
        storage.addAttribute(.link, value: "wikilink://\(title)", range: innerRange)
        // Dim brackets
        let openRange = NSRange(location: match.range.location, length: 2)
        let closeRange = NSRange(location: NSMaxRange(innerRange), length: 2)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openRange)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeRange)
    }
    storage.endEditing()
}
```

**AI streaming methods (mirror ProseEditorRepresentable):**
```swift
private static let aiDivider = "\n\n<!-- ai-response -->\n\n"

func startNoteChatStream(_ query: String) {
    guard let ts = textView?.textStorage else { return }
    isFlushingTokens = true
    ts.replaceCharacters(in: NSRange(location: ts.length, length: 0), with: Self.aiDivider)
    isFlushingTokens = false
    textView?.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
}

func appendNoteChatTokens(_ delta: String) {
    guard let ts = textView?.textStorage else { return }
    isFlushingTokens = true
    ts.replaceCharacters(in: NSRange(location: ts.length, length: 0), with: delta)
    isFlushingTokens = false
    textView?.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
}

func acceptNoteChatResponse() { /* find divider, replace with "\n\n" */ }
func discardNoteChatResponse() { /* find divider, delete from divider to end */ }
```

**Rich text TOC parser:**
```swift
static func parseRichText(_ attributedText: NSAttributedString) -> [TOCItem] {
    var items: [TOCItem] = []
    let string = attributedText.string as NSString
    string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .byParagraphs) {
        substring, paraRange, _, _ in
        guard let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard paraRange.location < attributedText.length else { return }
        let font = attributedText.attributes(at: paraRange.location, effectiveRange: nil)[.font] as? NSFont
        let level: Int? = switch font?.pointSize {
            case .some(let s) where s >= 26: 1
            case .some(let s) where s >= 20: 2
            case .some(let s) where s >= 17: 3
            default: nil
        }
        if let level {
            items.append(TOCItem(level: level, title: substring.trimmingCharacters(in: .whitespacesAndNewlines),
                                 charOffset: paraRange.location, kind: .heading))
        }
    }
    return items
}
```

### Phase 1: Foundation

`ProseTextView2` + `MarkdownContentStorage` + Rust FFI structure parser. Plain text renders with paragraph types.

### Phase 2: Base Highlighting

Wire Rust inline parser. Bold/italic/code/wikilinks styled with visible markers (same as TK1).

### Phase 3: Marker Collapsing

Active-line tracking. Markers collapse on inactive lines. The "Live Preview" feel.

### Phase 4: Drawing

Port table fills, grid lines, fold indicators to `NSTextLayoutFragment`. Focus dimming via rendering attributes.

### Phase 5: Inline Rendering

Image attachments, checkbox toggles, link URL hiding on inactive lines.

### Phase 6: Code Highlighting

Rust FFI code tokenizer. Language-aware colors in fenced blocks.

### Phase 7: Callouts + LaTeX

Callout block rendering. Inline/block LaTeX rendering.

### Phase 8: Coordinator

`ProseEditorRepresentable2` with full Coordinator. Binding sync, AI streaming, page swap pool, undo, commands, BTK edit translation, fold behavior, data detection, block-property chips, block ref semantics. Must preserve all 5-layer save pipeline contracts and NoteWindowManager notification contracts.

### Phase 9: Overlay Subsystems

Port geometry-dependent subsystems to `NSTextLayoutFragment` enumeration:
- `BlockRefAutocomplete` — popover positioning via layout fragment rects
- `TransclusionOverlayManager` — visible-range overlays via viewport enumeration
- `EditableTransclusionView` — inline transclusion positioning

### Phase 10: Integration + Parity

Wire into `ProseEditorView` + `NoteWindowManager`. Feature flag for A/B switching. Full test suite. Cross-launch persistence (`PageEditorCache`). Edge case testing. Performance benchmarks.

### Phase 11: Cutover

Remove TextKit 1 files. Delete feature flag.

### Feature Flag (Phases 10-11)

```swift
// NotesUIState
var useTextKit2Editor = false  // Toggle at runtime for A/B
```

`ProseEditorView` checks flag, renders `ProseEditorRepresentable` (TK1) or `ProseEditorRepresentable2` (TK2).

---

## Full Prose Editor Ontology

The current prose editor is NOT just "an NSTextView with markdown styling." It is a stack of storage, caching, save, overlay, BTK, and note-window contracts. Every layer must be accounted for.

### Core Stack

| Layer | File | Line | Role |
|-------|------|------|------|
| SwiftUI shell | `ProseEditorView.swift` | :22 | Binding sync, save debounce, page lifecycle |
| AppKit bridge | `ProseEditorRepresentable.swift` | :28 | NSViewRepresentable + 800-line Coordinator |
| Editor view | `ClickableTextView.swift` | :25 | NSTextView subclass with custom drawing |
| Custom storage | `MarkdownTextStorage.swift` | :16 | NSTextStorage subclass, live highlighting |

**Construction:** Manual TextKit 1 stack: `MarkdownTextStorage → NSLayoutManager → NSTextContainer → ClickableTextView` in `ProseEditorRepresentable.swift:68`. `NSScrollView` is the real scroll host (not SwiftUI).

### Editor Lifetime Model

- **One persistent NSTextView.** Page switches swap `MarkdownTextStorage` instances, NOT tearing down the view. `ProseEditorRepresentable.swift:8,281`
- **Per-page state** (storage, undo, scroll, selection) lives in `PageStoragePool.swift:16`
- **Cross-launch persistence** (scroll/selection across app restarts) in `PageEditorCache.swift:13`
- Architecture = one shared editor surface + per-page storage swapping + per-page undo managers + page cache invalidation/prewarming

### Persistence Model

- Canonical storage: plain `.md` files via `NoteFileStorage.swift:10`
- Read/write: `NoteFileStorage.swift:46,67`
- External reload signaling: notification-based via `NoteFileStorage.swift:147`, consumed in `ProseEditorView.swift:91`

**Save pipeline (5 layers):**
1. 300ms binding sync — `ProseEditorRepresentable.swift:656`
2. 3s direct file write bypass — `ProseEditorRepresentable.swift:665`
3. 5s SwiftUI/SwiftData debounce — `ProseEditorView.swift:131`
4. Flush on disappear/termination — `ProseEditorView.swift:101`
5. Page-swap flush before storage swap — `ProseEditorRepresentable.swift:288`

**Critical:** Prose mode writes plain `String` bodies (`ProseEditorView.swift:145`). If TK2 prose becomes attachment-rich, that is NEW behavior, not a migration.

### Styling / Parsing Ontology

`MarkdownTextStorage` is the styling engine:
- Incremental paragraph restyling: `:82` (processEditing)
- Full restyle / theme restyle: `:150`
- Line-level syntax (headings, lists, quotes, code, tables, HR, math): `:220`
- Inline styling via Rust FFI (`markdown_parse()`): `:571`

**Supported semantic elements:**
headings, lists, numbered lists, task lists, fenced code blocks, quotes, callouts, horizontal rules, inline/block math, markdown tables, wikilinks, block refs, trailing `@key=value` block-property chips

**Custom attributes/contracts in text:**
- Wikilinks: `.link = "wikilink://..."` — `:697`
- Block refs: `.link = "blockref://..."` + `EpistemosBlockRef` — `:750`
- Block-property chips: `:522`
- Detected-data: `DataDetectionService.swift:96`

### View-Level Behavior (ClickableTextView)

NOT passive. It owns:
- Transparent custom drawing: `:92`
- Table fill/grid rendering: `:101`
- Fold triangle rendering: `:303`
- Live-resize width freezing (Pitfall #9): `:69`
- Per-page undo override: `:54`
- Focus-mode dimming via temporary attributes: `:890`
- Find/replace: `:381`
- Zoom (scaling): `:464`
- QuickLook: `:550`
- Image insert + drag/drop: `:563,625`
- OCR: `:625`
- Context menu: `:721`

### Coordinator / Behavior Layer

The Coordinator (`ProseEditorRepresentable.swift:520`) owns:
- Link click routing: `:615`
- Block-ref autocomplete trigger: `:710`
- BTK edit translation via `BlockEditTranslator.swift:6`: `:713`
- Table key semantics + auto-alignment: `:754,1061`
- Data detection debounce/styling: `:1039`
- AI streaming into storage: `:1183`
- Fold/unfold behavior: `:1250`

**Critical oddity:** Folds literally rewrite storage to `"…\n"` (`:1287`). Not visual-only. Easy to miss in migration.

### Overlay / Popover Subsystems (Geometry-Dependent)

| Component | File | Depends On |
|-----------|------|-----------|
| Block ref autocomplete popover | `BlockRefAutocomplete.swift:9` | NSLayoutManager geometry |
| Visible-range transclusion overlays | `TransclusionOverlayManager.swift:16` | NSLayoutManager visible glyph ranges |
| Editable inline transclusion | `EditableTransclusionView.swift:8` | NSLayoutManager geometry |

**These are the biggest TextKit 2 rewrite surfaces** — they depend on `NSLayoutManager` glyph ranges and line fragment rects for positioning.

### Note Window Contracts

NoteWindowManager is wired to editor notifications/assumptions:
- Word count / TOC refresh on `NSText.didChangeNotification`: `:802`
- Idea / brain dump hooks: `:805`
- AI context actions: `:821`
- Block property sheet: `:831`
- Translation presentation: `:844`
- Mode-switch flush via `PageStoragePool`: `:1055`

**Toolbar formatting is markdown insertion, not attributed editing:** `:586,1494`

### Migration Decision Matrix

| Subsystem | Must Preserve | Can Redesign | Should Delete |
|-----------|:------------:|:------------:|:-------------:|
| Plain-markdown canonical storage | ✅ | | |
| One-editor/per-page-storage-swap | ✅ | | |
| Custom markdown restyling engine | | ✅ (TK2 delegate) | |
| Geometry-driven table drawing | | ✅ (NSTextLayoutFragment) | |
| Geometry-driven transclusion overlays | | ✅ (NSTextLayoutFragment) | |
| Geometry-driven autocomplete popovers | | ✅ (NSTextLayoutFragment) | |
| BTK text-edit translation | ✅ | | |
| Notification contracts to NoteWindowManager | ✅ | | |
| Fold-by-storage-rewrite behavior | ✅ | | |
| Per-page undo managers | ✅ | | |
| External body reload notifications | ✅ | | |
| 5-layer save pipeline | ✅ | | |
| Cross-launch scroll/selection cache | ✅ | | |
| Block-property chips | ✅ | | |
| Block ref semantics | ✅ | | |

---

## TextKit 1 API Surface (Audit Reference)

60+ unique TextKit 1 API calls across 4+ core files (~3,500+ lines):

- **MarkdownTextStorage** (~1200 lines): `processEditing()` override, backing `NSMutableAttributedString`, `beginEditing/endEditing/edited` lifecycle, ~30 `addAttributes` calls, Rust FFI inline parser
- **ClickableTextView** (~930 lines): 3 `drawBackground` overrides with 8 `NSLayoutManager` glyph queries, temporary attributes for focus dimming, live resize freeze/unfreeze, zoom, QuickLook, OCR, image insert
- **ProseEditorRepresentable** (~1340 lines): Storage→LayoutManager→Container stack creation, `addLayoutManager`/`removeLayoutManager` for page swap, `shouldChangeText`/`didChangeText` undo, BTK edit translation, fold operations, AI streaming, data detection, table alignment
- **PageStoragePool** (~240 lines): LRU cache of `MarkdownTextStorage` instances, `removeLayoutManager`/`addLayoutManager` swap, chunked inline styling
- **PageEditorCache**: Cross-launch scroll/selection persistence
- **BlockRefAutocomplete**: Layout-geometry-dependent popover
- **TransclusionOverlayManager**: Layout-geometry-dependent overlays
- **BlockEditTranslator**: BTK edit translation

### Critical Hot Paths

1. `processEditing()` → per-keystroke highlighting (must stay O(paragraph))
2. `textDidChange` → binding sync (debounced 300ms)
3. `drawBackground` → 8 glyph/fragment queries per visible table/fold
4. Token flushing → `replaceCharacters` + `scrollRangeToVisible`
5. Transclusion overlay positioning → visible glyph range + line fragment rects
