# Feature Spec: Symbol TOC Strip + Code Folding

> **Index status**: CANONICAL-OPERATIONAL — Symbol TOC strip + code folding feature spec — CodeSymbol struct (20-byte repr(C)) + Rust FFI + 3-step Swift impl with outline cache.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## For: Kimi (implementation agent)
## Priority: Ship-ready features for Epistemos code editor
## Reference: Antigravity editor screenshot showing both features

---

## FEATURE 1: Symbol TOC Strip (Right Edge)

### What It Is
A narrow vertical strip on the far-right edge of the code editor showing document symbols (MARK comments, functions, classes, structs, enums) as truncated clickable labels. Clicking a label scrolls the editor to that symbol. The currently visible section is highlighted.

### Visual Design (from Antigravity reference)
- Position: far-right edge, replaces or sits beside the minimap
- Width: ~80pt (same as current minimap, could share the space)
- Background: matches editor background (`theme.xcodeColors.editorBackground`)
- Each item: small truncated text label (11pt monospaced), ellipsized with `...`
- Items stack vertically, evenly spaced
- Active item (currently visible section): brighter text or subtle highlight
- Separator line on left edge (1pt, `separatorColor`)

### Architecture

#### Step 1: New Rust FFI Function

**File: `graph-engine/src/code_highlight.rs`**

Add a new struct and function to extract document symbols from the tree-sitter AST:

```rust
/// Document symbol for outline/TOC display.
#[repr(C)]
pub struct CodeSymbol {
    pub line: u32,           // 0-indexed line number
    pub col: u32,            // 0-indexed column
    pub name_start: u32,     // byte offset of name start
    pub name_end: u32,       // byte offset of name end
    pub kind: u8,            // 0=function, 1=class/struct, 2=enum, 3=protocol/trait, 4=mark_comment, 5=property
    pub depth: u8,           // nesting depth (0=top-level)
    pub _pad: [u8; 2],
}
// sizeof = 20 bytes

/// Extract document symbols (functions, classes, structs, MARK comments).
#[no_mangle]
pub unsafe extern "C" fn code_parse_symbols(
    code: *const c_char,
    code_len: u32,
    language: *const c_char,
    out_symbols: *mut CodeSymbol,
    max_symbols: u32,
) -> u32 {
    // Returns number of symbols written
}
```

**Implementation approach:**

1. Parse the code with tree-sitter (reuse existing cache)
2. Walk the AST looking for top-level and nested declarations:
   - **Functions:** `function_declaration`, `function_definition`, `function_item`, `method_declaration`
   - **Classes/Structs:** `class_declaration`, `struct_item`, `class_definition`, `struct_declaration`
   - **Enums:** `enum_item`, `enum_declaration`
   - **Protocols/Traits:** `protocol_declaration`, `trait_item`
   - **MARK comments:** Comments matching `// MARK: -` pattern (Swift), `// ---` (Rust), `# %%` (Python)
   - **Properties:** Top-level `let`/`var`/`const` declarations
3. For each symbol, extract the name via `node.child_by_field_name("name")` or regex on the text
4. Record line number via counting `\n` bytes before `node.start_byte()`
5. Record nesting depth from tree depth
6. Sort by line number
7. Write to output buffer, return count

**MARK comment detection (special case):**
```rust
// For Swift: "// MARK: - Something" → name = "Something", kind = 4
// For Rust:  "// --- Section Name ---" → name = "Section Name", kind = 4
// For Python: "# %% Cell Name" → name = "Cell Name", kind = 4
fn extract_mark_comment(text: &str) -> Option<&str> {
    if let Some(rest) = text.strip_prefix("// MARK: - ") { return Some(rest.trim()); }
    if let Some(rest) = text.strip_prefix("// MARK: ")  { return Some(rest.trim()); }
    if let Some(rest) = text.strip_prefix("// --- ")     { return Some(rest.trim_end_matches('-').trim()); }
    if let Some(rest) = text.strip_prefix("# %% ")       { return Some(rest.trim()); }
    None
}
```

**Add to FFI header (`graph-engine-bridge/graph_engine.h`):**
```c
typedef struct {
    uint32_t line;
    uint32_t col;
    uint32_t name_start;
    uint32_t name_end;
    uint8_t  kind;       // 0=function, 1=class/struct, 2=enum, 3=protocol, 4=mark, 5=property
    uint8_t  depth;
    uint8_t  _pad[2];
} CodeSymbol;

uint32_t code_parse_symbols(
    const char* code,
    uint32_t code_len,
    const char* language,
    CodeSymbol* out_symbols,
    uint32_t max_symbols
);
```

#### Step 2: New SymbolTOCView in Swift

**File: `Epistemos/Views/Notes/CodeEditorView.swift`**

Add a new `SymbolTOCView` class (NSView) after the MinimapView class:

```swift
class SymbolTOCView: NSView {
    private weak var textView: CodeTextView?
    private weak var scrollView: NSScrollView?
    var backgroundColor: NSColor = .clear

    struct SymbolEntry {
        let name: String
        let line: Int        // 0-indexed
        let kind: UInt8      // 0=func, 1=class, 2=enum, 3=protocol, 4=mark, 5=prop
        let depth: UInt8
    }

    private var symbols: [SymbolEntry] = []
    private var activeIndex: Int = -1
    private let labelFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)

    init(textView: CodeTextView, scrollView: NSScrollView) { ... }

    /// Rebuild symbol list from Rust FFI. Call on textDidChange.
    func rebuildSymbols() {
        guard let tv = textView, !tv.string.isEmpty, !tv.language.isEmpty else {
            symbols = []
            setNeedsDisplay(bounds)
            return
        }

        let text = tv.string
        let language = tv.language
        let maxSymbols: UInt32 = 512
        let buffer = UnsafeMutablePointer<CodeSymbol>.allocate(capacity: Int(maxSymbols))
        defer { buffer.deallocate() }

        let count = language.withCString { langPtr in
            text.withCString { codePtr in
                code_parse_symbols(codePtr, UInt32(text.utf8.count), langPtr, buffer, maxSymbols)
            }
        }

        let utf8 = Array(text.utf8)
        var entries: [SymbolEntry] = []
        for i in 0..<Int(count) {
            let sym = buffer[i]
            let nameStart = Int(sym.name_start)
            let nameEnd = min(Int(sym.name_end), utf8.count)
            guard nameStart < nameEnd else { continue }
            let nameBytes = utf8[nameStart..<nameEnd]
            let name = String(bytes: nameBytes, encoding: .utf8) ?? "?"
            entries.append(SymbolEntry(name: name, line: Int(sym.line), kind: sym.kind, depth: sym.depth))
        }

        symbols = entries
        updateActiveSymbol()
        setNeedsDisplay(bounds)
    }

    /// Determine which symbol is currently visible based on scroll position.
    func updateActiveSymbol() {
        guard let tv = textView, let sv = scrollView else { return }
        guard let lm = tv.layoutManager, let tc = tv.textContainer else { return }

        let visibleRect = sv.contentView.bounds
        let midY = visibleRect.midY
        // Find the glyph at the vertical midpoint of the visible area
        let glyphIndex = lm.glyphIndex(for: NSPoint(x: 0, y: midY), in: tc)
        let charIndex = lm.characterIndexForGlyph(at: glyphIndex)
        // Count newlines before charIndex to get current line
        let prefix = (tv.string as NSString).substring(to: min(charIndex, (tv.string as NSString).length))
        let currentLine = prefix.components(separatedBy: "\n").count - 1

        // Find the last symbol whose line <= currentLine
        var newActive = -1
        for (i, sym) in symbols.enumerated() {
            if sym.line <= currentLine {
                newActive = i
            } else {
                break
            }
        }
        if newActive != activeIndex {
            activeIndex = newActive
            setNeedsDisplay(bounds)
        }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.set()
        dirtyRect.fill()

        // Left separator
        NSColor.separatorColor.withAlphaComponent(0.15).set()
        NSRect(x: 0, y: 0, width: 1, height: bounds.height).fill()

        guard !symbols.isEmpty else { return }

        let itemHeight: CGFloat = max(20, bounds.height / CGFloat(symbols.count))
        let maxLabelWidth = bounds.width - 8  // 4pt padding each side

        for (i, sym) in symbols.enumerated() {
            let y = CGFloat(i) * itemHeight
            guard y + itemHeight > dirtyRect.minY, y < dirtyRect.maxY else { continue }

            let isActive = i == activeIndex
            let textColor: NSColor = isActive
                ? .labelColor
                : .secondaryLabelColor.withAlphaComponent(0.6)

            // Truncate name to fit
            let displayName = sym.name
            let attrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: textColor
            ]

            // Icon prefix based on kind
            let icon: String
            switch sym.kind {
            case 0: icon = "f"    // function
            case 1: icon = "S"    // struct/class
            case 2: icon = "E"    // enum
            case 3: icon = "P"    // protocol
            case 4: icon = "—"    // MARK section
            default: icon = "·"
            }

            let label = "\(icon) \(displayName)" as NSString
            let size = label.size(withAttributes: attrs)

            // Truncate with ellipsis if too wide
            var drawLabel = label as String
            if size.width > maxLabelWidth {
                // Find how many chars fit
                var truncated = displayName
                while truncated.count > 3 {
                    truncated = String(truncated.dropLast())
                    let test = "\(icon) \(truncated)..." as NSString
                    if test.size(withAttributes: attrs).width <= maxLabelWidth {
                        drawLabel = "\(icon) \(truncated)..."
                        break
                    }
                }
            }

            // Active indicator: subtle background highlight
            if isActive {
                NSColor.labelColor.withAlphaComponent(0.08).set()
                NSRect(x: 1, y: y, width: bounds.width - 1, height: itemHeight).fill()
            }

            let drawPoint = NSPoint(x: 4, y: y + (itemHeight - size.height) / 2)
            (drawLabel as NSString).draw(at: drawPoint, withAttributes: attrs)
        }
    }

    // Click to scroll
    override func mouseDown(with event: NSEvent) {
        guard let tv = textView, let sv = scrollView else { return }
        let localY = convert(event.locationInWindow, from: nil).y
        let itemHeight = max(20, bounds.height / CGFloat(max(symbols.count, 1)))
        let index = Int(localY / itemHeight)
        guard index >= 0, index < symbols.count else { return }

        let targetLine = symbols[index].line
        // Scroll to that line
        let nsStr = tv.string as NSString
        var lineStart = 0
        var currentLine = 0
        while currentLine < targetLine, lineStart < nsStr.length {
            let range = nsStr.lineRange(for: NSRange(location: lineStart, length: 0))
            lineStart = NSMaxRange(range)
            currentLine += 1
        }

        let charRange = NSRange(location: min(lineStart, nsStr.length), length: 0)
        tv.setSelectedRange(charRange)
        tv.scrollRangeToVisible(charRange)
    }
}
```

#### Step 3: Wire Into Layout

**File: `Epistemos/Views/Notes/CodeEditorView.swift`** — in `makeNSView`

Replace the current minimap-only right side with a split: minimap on top, TOC below. Or replace the minimap entirely with the TOC. Simplest approach — **replace minimap with TOC**:

```swift
// Replace MinimapView creation with SymbolTOCView
let tocView = SymbolTOCView(textView: textView, scrollView: scrollView)
tocView.translatesAutoresizingMaskIntoConstraints = false
tocView.backgroundColor = xc.editorBackground
container.addSubview(tocView)

// Update constraints — TOC replaces minimap position
NSLayoutConstraint.activate([
    // ... gutter and scrollView same as before ...
    tocView.topAnchor.constraint(equalTo: container.topAnchor),
    tocView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    tocView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    tocView.widthAnchor.constraint(equalToConstant: 100),  // slightly wider than minimap
])
```

Or **keep both** with a vertical split:
```
container
  ├─ gutter (48pt, left)
  ├─ scrollView (center)
  └─ rightPanel (100pt, right)
       ├─ MinimapView (top half)
       └─ SymbolTOCView (bottom half)
```

**Wire into Coordinator:**
- `textDidChange` → call `tocView.rebuildSymbols()`
- `scrollDidChange` → call `tocView.updateActiveSymbol()`
- Store `weak var tocView: SymbolTOCView?` in Coordinator

---

## FEATURE 2: Code Folding (Gutter Area)

### What It Is
Disclosure chevrons in the line number gutter next to lines that start foldable blocks (functions, classes, if/else, loops). Clicking a chevron collapses that block, replacing it with a `{ ... N lines }` placeholder. Clicking again unfolds.

### Architecture

#### Step 1: New Rust FFI Function for Fold Ranges

**File: `graph-engine/src/code_highlight.rs`**

Add a function to extract foldable ranges from the tree-sitter AST:

```rust
/// A foldable code region.
#[repr(C)]
pub struct CodeFoldRange {
    pub start_line: u32,   // line where fold indicator appears (0-indexed)
    pub end_line: u32,     // last line of the foldable block (0-indexed, inclusive)
    pub kind: u8,          // 0=function, 1=class/struct, 2=if/else, 3=loop, 4=block, 5=comment
    pub _pad: [u8; 3],
}
// sizeof = 12 bytes

/// Extract foldable ranges from code.
#[no_mangle]
pub unsafe extern "C" fn code_parse_fold_ranges(
    code: *const c_char,
    code_len: u32,
    language: *const c_char,
    out_ranges: *mut CodeFoldRange,
    max_ranges: u32,
) -> u32 {
    // Returns number of fold ranges written
}
```

**Implementation approach:**

1. Parse with tree-sitter (reuse cache)
2. Walk the AST looking for nodes that span multiple lines and have a body/block child:
   - `function_declaration` / `function_definition` / `function_item` → fold the body
   - `class_declaration` / `struct_item` / `enum_item` → fold the body
   - `if_statement` / `else_clause` → fold the consequence/alternative
   - `for_statement` / `while_statement` / `loop_expression` → fold the body
   - `switch_statement` / `match_expression` → fold the body
   - Multi-line comments → fold from second line to last line
   - `impl_item` / `extension_declaration` → fold the body
3. For each foldable node:
   - `start_line` = line of the opening brace or first line of the block
   - `end_line` = line of the closing brace
   - Only include if `end_line - start_line >= 2` (minimum 2 lines to be worth folding)
4. Sort by start_line
5. Write to buffer, return count

**Key: The fold indicator appears on `start_line` (the line with `{` or the function signature). The folded range hides lines `start_line + 1` through `end_line`.**

**Add to FFI header (`graph-engine-bridge/graph_engine.h`):**
```c
typedef struct {
    uint32_t start_line;
    uint32_t end_line;
    uint8_t  kind;
    uint8_t  _pad[3];
} CodeFoldRange;

uint32_t code_parse_fold_ranges(
    const char* code,
    uint32_t code_len,
    const char* language,
    CodeFoldRange* out_ranges,
    uint32_t max_ranges
);
```

#### Step 2: Fold State Management in CodeTextView

**File: `Epistemos/Views/Notes/CodeEditorView.swift`**

Add fold state tracking to CodeTextView:

```swift
// Add to CodeTextView class properties:

/// Cached fold ranges from tree-sitter
private var foldRanges: [(startLine: Int, endLine: Int, kind: UInt8)] = []

/// Currently folded line ranges. Key = start_line, Value = end_line
private var foldedRegions: [Int: Int] = [:]

/// Rebuild fold ranges from Rust FFI. Call on textDidChange.
func rebuildFoldRanges() {
    guard !language.isEmpty, !string.isEmpty else {
        foldRanges = []
        return
    }

    let text = string
    let maxRanges: UInt32 = 2048
    let buffer = UnsafeMutablePointer<CodeFoldRange>.allocate(capacity: Int(maxRanges))
    defer { buffer.deallocate() }

    let count = language.withCString { langPtr in
        text.withCString { codePtr in
            code_parse_fold_ranges(codePtr, UInt32(text.utf8.count), langPtr, buffer, maxRanges)
        }
    }

    var ranges: [(startLine: Int, endLine: Int, kind: UInt8)] = []
    for i in 0..<Int(count) {
        let r = buffer[i]
        ranges.append((Int(r.start_line), Int(r.end_line), r.kind))
    }
    foldRanges = ranges
}

/// Toggle fold state for a line. Returns true if state changed.
func toggleFold(atLine line: Int) -> Bool {
    if foldedRegions[line] != nil {
        // Unfold
        foldedRegions.removeValue(forKey: line)
        applyFoldState()
        return true
    }

    // Find the fold range that starts at this line
    guard let range = foldRanges.first(where: { $0.startLine == line }) else {
        return false
    }

    foldedRegions[line] = range.endLine
    applyFoldState()
    return true
}

/// Check if a line has a fold indicator (is start of a foldable range)
func foldKind(forLine line: Int) -> UInt8? {
    foldRanges.first(where: { $0.startLine == line })?.kind
}

/// Check if a line is currently folded (hidden)
func isLineFolded(_ line: Int) -> Bool {
    foldedRegions[line] != nil
}

/// Check if a line is hidden (inside a folded region)
func isLineHidden(_ line: Int) -> Bool {
    for (start, end) in foldedRegions {
        if line > start && line <= end {
            return true
        }
    }
    return false
}
```

#### Step 3: Apply Fold State via NSLayoutManager

The fold visual is implemented by hiding glyphs using `NSLayoutManager`:

```swift
/// Apply current fold state — hide/show glyphs for folded regions.
private func applyFoldState() {
    guard let lm = layoutManager, let storage = textStorage else { return }
    let nsStr = string as NSString

    // First, show all glyphs
    let fullGlyphRange = NSRange(location: 0, length: lm.numberOfGlyphs)
    // Reset: there's no direct "show all" API, so we track and only hide folded ranges

    // Build line start offsets
    var lineStarts: [Int] = [0]
    nsStr.enumerateSubstrings(
        in: NSRange(location: 0, length: nsStr.length),
        options: [.byParagraphs, .substringNotRequired]
    ) { _, range, _, _ in
        lineStarts.append(NSMaxRange(range))
    }

    // For each folded region, replace content with placeholder
    // Strategy: Use NSTextStorage replacement with undo support
    // This is complex — simpler approach is to use a custom NSLayoutManagerDelegate
    // to skip drawing glyphs in folded ranges.

    // SIMPLEST APPROACH: Store fold state, and in the gutter + line numbering,
    // just show the fold indicators. The actual hiding is Phase 2.
    // Phase 1: Just show fold chevrons in gutter and handle clicks.

    setNeedsDisplay(visibleRect)
}
```

**Note for implementor:** Full glyph hiding is complex. Recommend implementing in two phases:
1. **Phase 1 (this spec):** Show fold chevrons in the gutter. Click logs "fold toggled at line N" but doesn't hide text yet.
2. **Phase 2 (follow-up):** Actually hide text using `NSLayoutManager` delegate or text replacement.

#### Step 4: Update LineNumberGutter for Fold Indicators

**File: `Epistemos/Views/Notes/CodeEditorView.swift`** — modify `LineNumberGutter`

Add fold chevron drawing to the gutter's `draw(_:)` method:

```swift
class LineNumberGutter: NSView {
    // ... existing properties ...

    // NEW: Reference to get fold state
    var foldStateProvider: CodeTextView? { textView }

    override func draw(_ dirtyRect: NSRect) {
        // ... existing background + separator drawing ...
        // ... existing line number drawing loop ...

        // Inside the line number loop, AFTER drawing the number:
        for lineNum in 1...totalLines {
            // ... existing glyph lookup and y-position code ...

            // Draw line number (existing)
            numStr.draw(at: drawPoint, withAttributes: isCurrentLine ? currentAttrs : attrs)

            // NEW: Draw fold chevron if this line starts a foldable range
            if let tv = textView,
               let _ = tv.foldKind(forLine: lineNum - 1) {  // 0-indexed
                let isFolded = tv.isLineFolded(lineNum - 1)
                let chevron = isFolded ? "▶" : "▼"
                let chevronAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 8, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.5)
                ]
                let chevronSize = (chevron as NSString).size(withAttributes: chevronAttrs)
                let chevronPoint = NSPoint(
                    x: 4,  // left edge of gutter
                    y: y + (lineRect.height - chevronSize.height) / 2
                )
                (chevron as NSString).draw(at: chevronPoint, withAttributes: chevronAttrs)
            }
        }
    }

    // NEW: Handle click on fold chevron
    override func mouseDown(with event: NSEvent) {
        guard let tv = textView else { return }
        let localPoint = convert(event.locationInWindow, from: nil)

        // Only respond to clicks in the left 16pt (chevron area)
        guard localPoint.x < 16 else { return }

        // Find which line was clicked
        let scrollView = tv.enclosingScrollView
        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let adjustedY = localPoint.y + visibleRect.origin.y

        // Walk lines to find which one contains this Y
        guard let lm = tv.layoutManager, let tc = tv.textContainer else { return }
        let glyphIndex = lm.glyphIndex(for: NSPoint(x: 0, y: adjustedY - tv.textContainerInset.height), in: tc)
        let charIndex = lm.characterIndexForGlyph(at: glyphIndex)
        let prefix = (tv.string as NSString).substring(to: min(charIndex, (tv.string as NSString).length))
        let clickedLine = prefix.components(separatedBy: "\n").count - 1  // 0-indexed

        if tv.toggleFold(atLine: clickedLine) {
            setNeedsDisplay(bounds)
        }
    }
}
```

#### Step 5: Wire Into Coordinator

In Coordinator's `textDidChange`:
```swift
tv.rebuildFoldRanges()
```

---

## INTEGRATION: Putting It All Together

### Modified Layout (container constraints)

```
container (NSView)
  ├─ LineNumberGutter  (48pt, left)     — now with fold chevrons
  ├─ NSScrollView      (flexible, center)
  │  └─ CodeTextView
  ├─ MinimapView       (60pt, right)    — narrower to make room
  └─ SymbolTOCView     (100pt, far right) — NEW
```

**Updated constraints in `makeNSView`:**
```swift
NSLayoutConstraint.activate([
    gutterView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
    gutterView.topAnchor.constraint(equalTo: container.topAnchor),
    gutterView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    gutterView.widthAnchor.constraint(equalToConstant: 48),

    scrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor),
    scrollView.topAnchor.constraint(equalTo: container.topAnchor),
    scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    scrollView.trailingAnchor.constraint(equalTo: minimapView.leadingAnchor),

    minimapView.topAnchor.constraint(equalTo: container.topAnchor),
    minimapView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    minimapView.trailingAnchor.constraint(equalTo: tocView.leadingAnchor),
    minimapView.widthAnchor.constraint(equalToConstant: 60),

    tocView.topAnchor.constraint(equalTo: container.topAnchor),
    tocView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    tocView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    tocView.widthAnchor.constraint(equalToConstant: 100),
])
```

### Coordinator Updates

```swift
class Coordinator: NSObject {
    // ... existing properties ...
    weak var tocView: SymbolTOCView?   // NEW

    @objc func textDidChange(_ notification: Notification) {
        guard let tv = textView else { return }
        tv.highlightSyntax(theme: parent.theme)
        tv.updateCurrentLinePosition()
        tv.rebuildFoldRanges()                              // NEW
        gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
        minimapView?.rebuildTokenRects(theme: parent.theme)
        tocView?.rebuildSymbols()                            // NEW
        parent.onContentChange?(tv.string)
    }

    @objc func selectionDidChange(_ notification: Notification) {
        // ... existing code ...
    }

    @objc func scrollDidChange(_ notification: Notification) {
        gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
        minimapView?.setNeedsDisplay(minimapView?.bounds ?? .zero)
        textView?.applyHighlighting(theme: parent.theme, fullPass: false)
        tocView?.updateActiveSymbol()                        // NEW
    }
}
```

---

## FILES TO MODIFY

| File | Changes |
|------|---------|
| `graph-engine/src/code_highlight.rs` | Add `CodeSymbol` struct, `code_parse_symbols()` function, `CodeFoldRange` struct, `code_parse_fold_ranges()` function |
| `graph-engine-bridge/graph_engine.h` | Add C declarations for new structs and FFI functions |
| `Epistemos/Views/Notes/CodeEditorView.swift` | Add `SymbolTOCView` class, add fold state to `CodeTextView`, update `LineNumberGutter` for chevrons, update layout constraints, update Coordinator |

## FILES NOT TO MODIFY

| File | Why |
|------|-----|
| `ProseEditorView.swift` | Prose editor is separate |
| `ProseTextView2.swift` | Prose editor is separate |
| `EpistemosTheme.swift` | No theme changes needed (reuses `xcodeColors`) |

---

## BUILD AND TEST

```bash
# Rust
cargo test --manifest-path graph-engine/Cargo.toml

# Swift
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
```

### Verification Checklist

**Symbol TOC:**
- [ ] Open a Swift file with `// MARK: -` comments — TOC shows section names
- [ ] Open a Rust file with functions — TOC shows function names
- [ ] Click a TOC item — editor scrolls to that symbol
- [ ] Scroll the editor — active TOC item updates
- [ ] Open a Python file — TOC shows class/function names

**Code Folding:**
- [ ] Open a file with functions — fold chevrons (▼) appear in gutter
- [ ] Click a chevron — state toggles to ▶ (visual only for Phase 1)
- [ ] Edit the file — fold ranges update correctly
- [ ] Fold chevrons only appear on lines that start foldable blocks

---

## CONSTRAINTS (from CLAUDE.md)

- No `try!`, no force-unwraps, no `print()` in production
- `DispatchQueue.main.async` in UniFFI callbacks, NEVER `.sync`
- Every `unsafe` block gets `// SAFETY:` comment (in Rust)
- Use `@Observable`, not `ObservableObject`
- Do not edit `.xcodeproj` directly
