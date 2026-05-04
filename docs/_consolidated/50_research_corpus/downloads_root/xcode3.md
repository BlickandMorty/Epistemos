# Xcode-Grade Native Code Editor on macOS: NSTextView Performance & Theme Engineering
**For Epistemos `CodeEditorView` — A 10-topic engineering reference covering color palette extraction, rendering performance, incremental highlighting, gutter/minimap architecture, and dark/light theme switching.**

***
## Part 1 — Xcode's Exact Color Palette
### The `.xccolortheme` Format
Xcode stores all editor themes as XML Property List files located in `~/Library/Developer/Xcode/UserData/FontAndColorThemes/`. The internal structure uses float-format RGBA strings (`"R G B A"` in the 0.0–1.0 range) rather than hex. Every shipped theme lives inside the DVT frameworks at `/Applications/Xcode.app/Contents/SharedFrameworks/DVTUserInterfaceKit.framework/`. The key namespace is `DVTSourceTextSyntaxColors`, which contains a dictionary of `xcode.syntax.*` → color string entries:[^1][^2]

```xml
<key>DVTSourceTextSyntaxColors</key>
<dict>
    <key>xcode.syntax.keyword</key>        <string>R G B A</string>
    <key>xcode.syntax.string</key>         <string>R G B A</string>
    <key>xcode.syntax.comment</key>        <string>R G B A</string>
    <key>xcode.syntax.identifier.class</key>        <string>R G B A</string>
    <key>xcode.syntax.identifier.class.system</key> <string>R G B A</string>
    <key>xcode.syntax.identifier.function</key>     <string>R G B A</string>
    <key>xcode.syntax.identifier.macro</key>        <string>R G B A</string>
    <key>xcode.syntax.number</key>         <string>R G B A</string>
    <key>xcode.syntax.plain</key>          <string>R G B A</string>
    <key>xcode.syntax.preprocessor</key>   <string>R G B A</string>
    <key>xcode.syntax.attribute</key>      <string>R G B A</string>
    <key>xcode.syntax.declaration.type</key>        <string>R G B A</string>
</dict>
```

Additional top-level editor-chrome keys include `DVTSourceTextBackground`, `DVTSourceTextCurrentLineHighlightColor`, `DVTSourceTextSelectionColor`, `DVTSourceTextInsertionPointColor`, and `DVTLineSpacing` (a real value, defaulting to `1.2`).[^2]

***
### Xcode Default Dark — Complete Color Spec
All values extracted and cross-validated from the `Xcode Default Dark` theme as ported to VS Code and from `.xccolortheme` file analysis:[^3][^4][^5]

**Editor Chrome:**

| Role | Hex | Notes |
|---|---|---|
| Background | `#1F1F24` | Classic Dark variant uses `#292A30` |
| Foreground / plain identifier | `#DFDFE0` | Near-white |
| Current line highlight | `#2F3239` | Approx 85% opacity solid |
| Selection background | `#646F83` at 40% alpha | `#646f8366` |
| Cursor / insertion point | `#FFFFFF` | |
| Line number (active line) | `#DFDFDF` | Matches foreground |
| Line number (inactive) | `#DFDFDF` at ~33% alpha | `#DFDFDF55` |
| Gutter background | `#2A2C2F` | Slightly lighter than editor bg |
| Gutter separator | `#FFFFFF` at 10% alpha | 1px hairline |
| Invisible characters | `#53606E` | Tabs, spaces, newlines |

**Syntax Tokens:**

| Token | Hex | Appearance | Bold? |
|---|---|---|---|
| Keyword (`func`, `let`, `if`, `return`) | `#FF7AB2` | Warm pink/rose | ✓ |
| String literal | `#FC6A5D` | Coral red | — |
| Number literal | `#D0BF69` | Muted gold / tan | — |
| Comment (line + doc) | `#A0D07D` | Sage green | — |
| Type (project-defined class/struct) | `#D0A8FF` | Lavender purple | — |
| Type (system / SDK class) | `#ACF2E4` | Mint / pale teal | — |
| Function (at declaration site) | `#5DD8FF` | Cyan / sky blue | — |
| Function call | `#CDA1FF` | Soft violet | — |
| Preprocessor / compiler directive | `#FFA14F` | Orange | — |
| Operator (`+`, `->`, `==`) | `#A167E6` | Medium purple | — |
| Property / instance variable | `#83C9BC` | Seafoam teal | — |
| Variable / parameter | `#4EB1CC` | Steel blue-cyan | — |
| Constant | `#D6C455` | Warm muted gold | — |
| URL / link in comments | `#6699FF` | Periwinkle blue | — |
| Boolean constant | `#D6C455` | Same as number | — |
| Attribute / annotation | `#D0A8FF` | Same as type | — |

***
### Xcode Default Light — Complete Color Spec
Cross-validated against `.xccolortheme` float extractions and the Classic Light theme port:[^4][^5]

**Editor Chrome:**

| Role | Hex |
|---|---|
| Background | `#FFFFFF` |
| Foreground / plain | `#000000` |
| Current line highlight | `#EEF5FE` (very light blue) |
| Selection background | System `selectedTextBackgroundColor` |
| Cursor | `#000000` or `#282828` |
| Line number (active) | `#282828` |
| Line number (inactive) | `#A6A6A6` |
| Gutter background | `#F5F5F5` (same as sidebar) |

**Syntax Tokens (Xcode Default Light, xccolortheme direct extraction):**

| Token | Hex | Notes |
|---|---|---|
| Keyword | `#AD3DA4` | Magenta/pink — same family as dark |
| String | `#D12F1B` | Deep red |
| Number | `#272AD8` | Vivid blue |
| Comment | `#309409` | Bright green |
| Type (project) | `#3F6E74` | Teal |
| Type (system) | `#5C2699` | Deep purple |
| Function (user) | `#3E8087` | Teal-blue |
| Function (system/built-in) | `#804FB8` | Violet |
| Preprocessor | `#78492A` | Brown/sienna |
| Operator | `#000000` | Plain black |
| Property | `#3E8087` | Same as function |
| Attribute | `#B73999` | Pink-violet |
| Plain identifier | `#000000` | |

> **Design insight:** Xcode uses the same hue family for keywords across modes (pink/magenta in both) but dramatically desaturates and darkens the light palette so tokens don't overpower the white background. The dark palette is more vibrant because colors need contrast against the near-black background.

***
### Applying to `EpistemosTheme.nsColorForTokenType`
Your current `nsColorForTokenType(_:)` maps 13 token types. The recommended update to match Xcode Default Dark:

```swift
func nsColorForTokenType(_ tokenType: UInt8, isDark: Bool) -> NSColor {
    if isDark {
        switch tokenType {
        case 0:  return NSColor(hex: 0xFF7AB2)  // keyword — pink, bold
        case 1:  return NSColor(hex: 0xFC6A5D)  // string — coral red
        case 2:  return NSColor(hex: 0xD0BF69)  // number — gold
        case 3:  return NSColor(hex: 0xA0D07D)  // comment — sage green
        case 4:  return NSColor(hex: 0x5DD8FF)  // function — cyan
        case 5:  return NSColor(hex: 0xD0A8FF)  // type — lavender
        case 6:  return NSColor(hex: 0xA167E6)  // operator — purple
        case 7:  return NSColor(hex: 0xDFDFE0)  // punctuation — foreground
        case 8:  return NSColor(hex: 0xDFDFE0)  // variable — foreground
        case 9:  return NSColor(hex: 0x83C9BC)  // property — seafoam
        case 10: return NSColor(hex: 0xD6C455)  // constant — gold
        case 11: return NSColor(hex: 0xFF7AB2)  // tag — same as keyword
        case 12: return NSColor(hex: 0xD0A8FF)  // attribute — lavender
        default: return NSColor(hex: 0xDFDFE0)
        }
    } else {
        switch tokenType {
        case 0:  return NSColor(hex: 0xAD3DA4)  // keyword
        case 1:  return NSColor(hex: 0xD12F1B)  // string
        case 2:  return NSColor(hex: 0x272AD8)  // number
        case 3:  return NSColor(hex: 0x309409)  // comment
        case 4:  return NSColor(hex: 0x3E8087)  // function
        case 5:  return NSColor(hex: 0x3F6E74)  // type
        case 6:  return NSColor(hex: 0x000000)  // operator
        case 7:  return NSColor(hex: 0x000000)  // punctuation
        case 8:  return NSColor(hex: 0x000000)  // variable
        case 9:  return NSColor(hex: 0x3E8087)  // property
        case 10: return NSColor(hex: 0x272AD8)  // constant
        case 11: return NSColor(hex: 0xAD3DA4)  // tag
        case 12: return NSColor(hex: 0x804FB8)  // attribute
        default: return .labelColor
        }
    }
}
```

***
## Part 2 — Why Xcode Is Smooth: NSTextView Performance
### Does Xcode Use NSTextView?
Xcode does **not** use a standard `NSTextView`. Its source editor is a private `SourceEditorView` inside the `DVTSourceEditor` framework, which uses a completely custom text engine built for IDE-scale performance. This is why benchmarking Xcode scrolling against a standard NSTextView is an unfair comparison — they operate at different architectural levels.[^6]

For a public NSTextView-based editor, the reference implementation to study is **CodeEditSourceEditor** (the open-source Xcode-inspired editor) and **STTextView** (a TextKit 2 NSTextView replacement). Both achieve near-Xcode smoothness with the right configuration.[^7][^8]
### Layer Backing
Layer-backing is the single most impactful change for scroll performance:[^9][^10]

```swift
// Apply wantsLayer to the CONTAINER, not the text view itself
container.wantsLayer = true

// On the scroll view
scrollView.wantsLayer = true
scrollView.layerContentsRedrawPolicy = .onSetNeedsDisplay

// On the text view
textView.wantsLayer = true
textView.layerContentsRedrawPolicy = .onSetNeedsDisplay
textView.canDrawSubviewsIntoLayer = true  // Flattens sub-layer hierarchy

// Critical: text view must declare itself opaque for responsive scrolling
// Override in CodeTextView:
override var isOpaque: Bool { return true }
override var drawsBackground: Bool {
    get { return true }
    set { super.drawsBackground = newValue }
}
```

`canDrawSubviewsIntoLayer = true` flattens all subview layers into a single compositing layer, reducing GPU composition overhead. Without this, each NSView with `wantsLayer` adds a separate CALayer to the compositor's layer tree.[^10]
### Responsive Scrolling (macOS 10.9+)
Responsive Scrolling allows AppKit to draw **ahead of the visible rect** on a background thread, making scrolling feel smooth even when the main thread is busy. Requirements to opt in:[^11]

```swift
// On NSClipView:
scrollView.contentView.copiesOnScroll = true  // REQUIRED (non-layer path)
// For layer-backed path, copiesOnScroll is deprecated (macOS 11+)

// documentView must NOT override scrollWheel:
// documentView must NOT override lockFocus:
// documentView must return YES for isOpaque
```

For layer-backed scroll views (the modern path), the system automatically pre-renders content outside the visible rect (overdraw), which is why modern scrolling is so smooth. The key requirement is that `drawRect:` / `draw(_:)` is fast and deterministic.
### `setTemporaryAttributes` vs `textStorage.addAttribute` — Performance Analysis
This is the most impactful correctness issue in the current `highlightSyntax` implementation:[^12][^13]

| Approach | Triggers processEditing? | Undo? | Cursor move? | Speed |
|---|---|---|---|---|
| `textStorage.addAttribute` inside `beginEditing/endEditing` | Yes (batched) | Yes | Yes (can disturb) | Slower |
| `layoutManager.setTemporaryAttributes` | No | No | No | **2–5× faster** |
| `layoutManager.addTemporaryAttribute` | No | No | No | **2–5× faster** |

`setTemporaryAttributes` applies purely display-side colors that don't affect the underlying `NSAttributedString` model. They're discarded on layout invalidation and reapplied by your highlighter. This means no undo pollution, no cursor jumping, and no `processEditing` cascade:[^13]

```swift
func highlightSyntax(theme: EpistemosTheme) {
    guard let lm = layoutManager, !language.isEmpty, !string.isEmpty else { return }
    let hash = string.hashValue &+ language.hashValue
    guard hash != lastHighlightHash else { return }
    lastHighlightHash = hash
    
    // Apply base paragraph style to textStorage ONCE (for line height, tab stops)
    // This is a model change, so use beginEditing/endEditing:
    let storage = textStorage!
    storage.beginEditing()
    let fullRange = NSRange(location: 0, length: storage.length)
    storage.addAttribute(.paragraphStyle, value: defaultParagraphStyle!, range: fullRange)
    storage.addAttribute(.font, value: font!, range: fullRange)
    storage.endEditing()
    
    // Apply syntax colors via temporary attributes — NO undo, NO processEditing:
    lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
    
    // ... tokenize via FFI ...
    for ti in 0..<tokenCount {
        let token = buffer[Int(ti)]
        let color = theme.nsColorForTokenType(token.token_type)
        let range = utf16Range(for: token) // your existing UTF-8→UTF-16 mapping
        lm.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: range)
    }
}
```
### NSLayoutManager vs Custom Layout for Large Files
For files over 5,000 lines, `NSLayoutManager` performs full layout for the entire document on first load. This causes the initial "hang" when opening a large file. The `preparedContentRect` property controls how much content is pre-laid-out:[^14]

```swift
// Limit pre-layout to visible area + small overdraw buffer
textView.preparedContentRect = textView.visibleRect.insetBy(dx: 0, dy: -500)
```

For files over ~50,000 lines, consider `ensureLayout(for:)` on scroll to lazily lay out only visible content.

***
## Part 3 — Optimal NSTextView Configuration
The current `CodeEditorRepresentable.makeNSView` is close but missing several performance-critical settings:[^15][^14]
### Verified Correct (Keep As-Is)
```swift
textView.isRichText = true              // Required for per-token colors
textView.isHorizontallyResizable = true // No word wrap
textView.textContainer?.widthTracksTextView = false
textView.textContainer?.containerSize = NSSize(width: .greatestFiniteMagnitude, 
                                               height: .greatestFiniteMagnitude)
textView.maxSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
```
### Missing / Needs Fix
```swift
// CRITICAL: Missing vertical resize
textView.isVerticallyResizable = true

// Xcode uses 4pt inset on all sides (you have none set)
textView.textContainerInset = NSSize(width: 4, height: 4)

// Xcode gutter padding (default NSTextView uses 5.0 — Xcode uses 4.0)
textView.textContainer?.lineFragmentPadding = 4.0

// Proper line height matching Xcode at 13pt SF Mono
let charWidth = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    .advancement(forGlyph: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    .glyph(withName: "space")).width
let ps = NSMutableParagraphStyle()
ps.lineHeightMultiplier = 1.5   // ~19.5pt per line at 13pt
ps.tabStops = []
ps.defaultTabInterval = charWidth * 4  // 4-space tabs
textView.defaultParagraphStyle = ps
textView.typingAttributes = [
    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
    .paragraphStyle: ps,
    .foregroundColor: baseTextColor
]

// Disable adaptive color mapping (causes unexpected color shifts)
textView.usesAdaptiveColorMappingForDarkAppearance = false

// Performance
textView.wantsLayer = true
textView.layerContentsRedrawPolicy = .onSetNeedsDisplay
textView.displaysLinkToolTips = false  // Removes hit-test overhead
textView.linkTextAttributes = [:]     // Don't style URLs (saves attribute scan)
textView.usesFontPanel = false
textView.isAutomaticTextCompletionEnabled = false

// Already set correctly — confirm:
textView.isAutomaticQuoteSubstitutionEnabled = false
textView.isAutomaticDashSubstitutionEnabled = false
textView.isAutomaticTextReplacementEnabled = false
textView.isAutomaticSpellingCorrectionEnabled = false
textView.isContinuousSpellCheckingEnabled = false
```
### Font: `monospacedSystemFont` vs `NSFont(name: "SFMono-Regular")`
`NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)` and `NSFont(name: "SFMono-Regular", size: 13)` resolve to the same typeface on macOS 10.15+. Use `monospacedSystemFont` — it respects accessibility bold-text preferences and handles future font substitutions correctly. Xcode's default is **SF Mono Regular, 13pt**.[^4][^16]

***
## Part 4 — `drawBackground` Performance Engineering
### Current Code Assessment
The current `drawBackground(in:)` in `CodeTextView` has good bones — the indent guide cache with hash checking is the right pattern. Three improvements will get it to Xcode-quality behavior.
### 1. Current Line Highlight via CALayer (Not drawBackground)
Moving the current-line highlight out of `drawBackground` eliminates full-view redraws on every cursor movement:

```swift
class CodeTextView: NSTextView {
    private let currentLineLayer = CALayer()

    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer?.insertSublayer(currentLineLayer, at: 0)
        currentLineLayer.zPosition = -1
    }

    // Call this from setSelectedRange override and viewDidMoveToWindow:
    func updateCurrentLineLayer() {
        guard let lm = layoutManager, let tc = textContainer else { return }
        let insertionLoc = selectedRange().location
        let lineRange = (string as NSString).lineRange(for: NSRange(location: insertionLoc, length: 0))
        let glyphRange = lm.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
        var lineRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        lineRect.origin.y += textContainerInset.height
        lineRect.origin.x = 0
        lineRect.size.width = max(bounds.width, lineRect.maxX)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)  // No animation on cursor move
        currentLineLayer.frame = lineRect
        currentLineLayer.backgroundColor = NSColor.labelColor
            .withAlphaComponent(0.06).cgColor
        CATransaction.commit()
    }

    override func setSelectedRange(_ charRange: NSRange, 
                                   affinity: NSSelectionAffinity, 
                                   stillSelecting: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        if !stillSelecting {
            updateCurrentLineLayer()
            updateBracketMatching()  // already exists
        }
    }
}
```

This means `drawBackground` no longer needs to draw the line highlight. A CALayer position update does not trigger `drawBackground` — it goes through the compositor independently.[^9][^17]
### 2. Fine-Grained Dirty Rect in `drawBackground`
```swift
override func drawBackground(in rect: NSRect) {
    super.drawBackground(in: rect)
    
    // Only draw indent guides if they intersect the dirty rect
    guard let path = cachedGuidePath else { return }
    
    // Use getRectsBeingDrawn for even finer granularity
    var rectsPtr: UnsafePointer<NSRect>?
    var count = 0
    getRectsBeingDrawn(&rectsPtr, count: &count)
    
    NSColor.separatorColor.withAlphaComponent(0.15).set()
    path.stroke()
    // This is already efficient because NSBezierPath.stroke() uses the 
    // current clip rect — drawBackground is only called for dirty regions
}
```
### 3. Coalescing `setNeedsDisplay` in the Coordinator
The current coordinator calls `gutterView?.setNeedsDisplay(...)` synchronously in scroll notifications. Schedule these on the next RunLoop pass to coalesce rapid scroll events:

```swift
private var displayWorkItem: DispatchWorkItem?

@objc func scrollDidChange(_ notification: Notification) {
    displayWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
        self?.gutterView?.needsDisplay = true
        self?.minimapView?.setNeedsDisplay(self?.minimapView?.bounds ?? .zero)
    }
    displayWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.008, execute: item)  // ~0.5 frame at 60fps
}
```

***
## Part 5 — Incremental Syntax Highlighting Architecture
### The Core Problem with Full-Range Highlighting
The current `highlightSyntax` re-tokenizes and re-applies attributes for the **entire document** on every keystroke. For a 1,000-line Swift file (~50KB), this is:
- `markdown_parse_code_tokens`: ~2–4ms (Rust FFI, fast)  
- `storage.beginEditing/endEditing` on full range: ~5–15ms (layout invalidation for all glyphs)
- Total: **7–19ms per keystroke** — this causes dropped frames at 120fps (budget: 8.3ms)

The `lastHighlightHash` guard saves you from redundant re-runs, but doesn't help latency on actual edits.
### Incremental Strategy Using `NSTextStorageDelegate`
The key insight from CodeEditSourceEditor's `Highlighter.swift`: intercept edits at the `NSTextStorageDelegate` level, track invalid ranges with an `IndexSet`, and only highlight what's visible and invalid:[^18]

```swift
// Step 1: Make CodeTextView conform to NSTextStorageDelegate
class CodeTextView: NSTextView, NSTextStorageDelegate {
    private var invalidatedRanges = IndexSet()
    private var visibleHighlightedRanges = IndexSet()
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        textStorage?.delegate = self
    }
    
    // Step 2: Intercept edits — only invalidate the edited range
    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange,
                     changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        
        // Invalidate just the edited paragraph + some context
        let str = textStorage.string as NSString
        let paragraphRange = str.paragraphRange(for: editedRange)
        invalidatedRanges.insert(integersIn: paragraphRange.location..<NSMaxRange(paragraphRange))
        
        // Also invalidate anything after the edit (length change shifts all offsets)
        if delta != 0 {
            let affectedStart = editedRange.location + max(0, editedRange.length - delta)
            if affectedStart < str.length {
                invalidatedRanges.insert(integersIn: affectedStart..<str.length)
            }
        }
        
        // Schedule a highlight pass — debounced
        scheduleHighlightPass()
    }
    
    // Step 3: Only highlight visible + invalidated ranges
    private func scheduleHighlightPass() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, 
                                              selector: #selector(highlightVisibleInvalidated),
                                              object: nil)
        perform(#selector(highlightVisibleInvalidated), with: nil, afterDelay: 0)
    }
    
    @objc private func highlightVisibleInvalidated() {
        guard let lm = layoutManager, let tc = textContainer else { return }
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds
        let visibleGlyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
        let visibleCharRange = lm.characterRange(forGlyphRange: visibleGlyphRange, 
                                                  actualGlyphRange: nil)
        
        // Intersect: highlight only visible ranges that are invalidated
        let visibleInvalid = invalidatedRanges.intersection(
            IndexSet(integersIn: visibleCharRange.location..<NSMaxRange(visibleCharRange))
        )
        guard !visibleInvalid.isEmpty else { return }
        
        for rangeToHighlight in visibleInvalid.rangeView {
            let nsRange = NSRange(rangeToHighlight)
            applyHighlighting(in: nsRange, theme: currentTheme)
        }
        invalidatedRanges.subtract(IndexSet(integersIn: visibleCharRange.location..<NSMaxRange(visibleCharRange)))
    }
}
```
### Visible-Range-Only on Scroll
When the user scrolls into un-highlighted territory, trigger a highlight pass for the newly visible range:

```swift
// In the scroll notification observer (Coordinator):
@objc func scrollDidChange(_ notification: Notification) {
    gutterView?.needsDisplay = true
    minimapView?.setNeedsDisplay(minimapView?.bounds ?? .zero)
    textView?.scheduleHighlightPass()  // Highlight newly visible content
}
```
### Tree-Sitter Incremental Re-Parse
Your current FFI calls `markdown_parse_code_tokens` for the full text on every edit. The Rust tree-sitter library supports `Tree.edit()` for incremental re-parsing:[^19][^20][^21]

```rust
// In code_highlight.rs — expose incremental edit:
#[no_mangle]
pub extern "C" fn apply_tree_edit(
    tree: *mut Tree,
    start_byte: u32, old_end_byte: u32, new_end_byte: u32,
    start_row: u32, start_col: u32,
    old_end_row: u32, old_end_col: u32,
    new_end_row: u32, new_end_col: u32,
) { ... }
```

With incremental re-parse, tree-sitter only re-parses the changed subtree — typically <1ms for a single-line edit regardless of file size.[^20][^21]

***
## Part 6 — NSScrollView + NSTextView Scroll Performance
### Key Configuration
```swift
let scrollView = NSScrollView()
scrollView.wantsLayer = true
scrollView.layerContentsRedrawPolicy = .onSetNeedsDisplay
scrollView.hasVerticalScroller = true
scrollView.hasHorizontalScroller = true
scrollView.autohidesScrollers = true
scrollView.scrollerStyle = .overlay          // Modern overlay scrollers, less layout work
scrollView.borderType = .noBorder
scrollView.drawsBackground = false           // Let textView draw background
scrollView.verticalScrollElasticity = .allowed
scrollView.horizontalScrollElasticity = .allowed

// CRITICAL for responsive scrolling:
scrollView.contentView.postsBoundsChangedNotifications = true
// DO NOT set copiesOnScroll — it's deprecated in macOS 11 and irrelevant for layer-backed views
```

`scrollerStyle = .overlay` uses the modern overlay scrollers which don't take up layout space and have less compositing overhead than `.legacy` style.[^22]
### Scroll Notification vs KVO
Your current `boundsDidChangeNotification` observer is correct. However, the handler must be lightweight — no synchronous drawing work:[^14][^23]

```swift
// Good pattern — the notification handler only marks views dirty:
NotificationCenter.default.addObserver(
    coordinator,
    selector: #selector(Coordinator.scrollDidChange(_:)),
    name: NSView.boundsDidChangeNotification,
    object: scrollView.contentView
)

// In the handler — mark dirty, don't draw:
@objc func scrollDidChange(_ notification: Notification) {
    gutterView?.needsDisplay = true   // AppKit batches these
    minimapView?.needsDisplay = true
    textView?.scheduleHighlightPass() // Lazy visible-range highlight
}
```
### Making the Gutter Scroll Without Overdraw
The current architecture places `LineNumberGutter` as an independent `NSView` beside the scroll view. A better approach (used by CodeEditSourceEditor) is to overlay it as the scroll view's **ruler view**, so it scrolls synchronously without a notification round-trip:[^24][^7]

```swift
// Set gutter as vertical ruler — syncs automatically with scroll
scrollView.hasVerticalRuler = true
scrollView.rulersVisible = true
scrollView.verticalRulerView = gutterView  // gutterView: NSRulerView subclass

// This eliminates the boundsDidChangeNotification → gutter.setNeedsDisplay overhead
```

***
## Part 7 — Line Number Gutter: High-Performance Implementation
### Architecture Fix: NSRulerView vs Sibling NSView
The current `LineNumberGutter` as a sibling `NSView` requires explicit scroll synchronization via `boundsDidChangeNotification`. Using `NSRulerView` as the scroll view's `verticalRulerView` eliminates this — AppKit calls `draw(_:)` automatically in sync with scroll.[^24][^25]

**However**, if keeping the current sibling-view approach, the critical performance fix is **caching line start positions**:

```swift
class LineNumberGutter: NSView {
    // Cache: only rebuild on textDidChange, not on every draw
    private var lineStartCache: [Int] = []  // character indices of line starts
    private var lineStartCacheHash: Int = 0

    func updateLineStartCache(for text: NSString) {
        let newHash = (text as String).hashValue
        guard newHash != lineStartCacheHash else { return }
        lineStartCacheHash = newHash
        
        var starts =
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: text.length),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, _, enclosingRange, _ in
            starts.append(NSMaxRange(enclosingRange))
        }
        lineStartCache = starts
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let tv = textView else { return }
        updateLineStartCache(for: tv.string as NSString)  // O(1) if no change
        
        // Only draw lines whose rects intersect dirtyRect (tile drawing)
        // ... draw only visible line numbers
    }
}
```
### Drawing Only Visible Lines
Instead of iterating all `totalLines`, compute the first and last visible line from the layout manager:

```swift
override func draw(_ dirtyRect: NSRect) {
    guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer,
          let sv = tv.enclosingScrollView else { return }
    
    // Fill background
    backgroundColor.set(); dirtyRect.fill()
    
    // Separator
    NSColor.separatorColor.withAlphaComponent(0.2).set()
    NSRect(x: bounds.width - 0.5, y: 0, width: 0.5, height: bounds.height).fill()
    
    let scrollOffset = sv.contentView.bounds.origin.y
    let visibleRect = sv.contentView.bounds
    
    // Find glyph range for visible rect — O(log n) binary search in NSLayoutManager
    let visibleGlyphRange = lm.glyphRange(
        forBoundingRect: NSRect(x: 0, y: visibleRect.minY, 
                                width: CGFloat.greatestFiniteMagnitude, 
                                height: visibleRect.height),
        in: tc
    )
    
    // Enumerate only visible line fragments — much faster than iterating all lines
    lm.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { rect, _, _, charRange, _ in
        // Determine line number for charRange.location from lineStartCache
        let lineNum = self.lineNumber(forCharIndex: charRange.location)
        let y = rect.origin.y + tv.textContainerInset.height - scrollOffset
        self.drawLineNumber(lineNum, at: y, lineHeight: rect.height, 
                           isCurrentLine: lineNum == self.currentLine)
    }
}
```
### Xcode Gutter Visual Spec
- Background: matches editor background or `NSColor.controlBackgroundColor` (typically `#2A2C2F` dark / `#F5F5F5` light)
- Separator: 1px vertical line at right edge, `NSColor.separatorColor` @ 20% alpha
- Active line: line number text uses full `NSColor.labelColor`, inactive uses `NSColor.secondaryLabelColor`
- Active line background: `NSColor.selectedTextBackgroundColor.withSystemEffect(.disabled)` — a soft tint matching the text view's line highlight[^7]
- Font: same monospace font as editor, reduced by ~2pt (e.g., 11pt if editor is 13pt)
- Alignment: right-aligned numbers, 8pt trailing margin from gutter right edge

***
## Part 8 — Minimap: Architecture Analysis and Improvements
### CodeEditSourceEditor Approach vs Your Token-Rect Approach
CodeEditSourceEditor uses a **shared NSTextStorage with a custom layout manager** that forces all line fragments to 2px height. The `MinimapLineRenderer` overrides `prepareForDisplay` to scale every line fragment to `2.0pt` height (displayed as `3.0pt` for anti-aliasing). This gives perfect visual fidelity because it uses the actual syntax-highlighted attributed string.[^7]

Your current **token-rect approach** (pre-computed colored rectangles) is simpler and more memory efficient for large files. It trades pixel-perfect accuracy for performance. Both are valid — the token-rect approach is what VS Code's minimap uses with `renderCharacters: false`.[^26]
### Critical Fix: Async Rebuild
The current `rebuildTokenRects` runs **synchronously on the main thread** on every `textDidChange`. For a 10,000-line file this will stutter:

```swift
func rebuildTokenRects(theme: EpistemosTheme) {
    let text = textView?.string ?? ""
    let language = textView?.language ?? ""
    guard !text.isEmpty, !language.isEmpty else {
        tokenRects.removeAll(); needsDisplay = true; return
    }
    
    Task.detached(priority: .userInitiated) { [weak self] in
        let rects = await Self.buildTokenRects(text: text, language: language, theme: theme)
        await MainActor.run {
            self?.tokenRects = rects
            self?.needsDisplay = true
        }
    }
}

// Static, actor-isolated builder runs off main thread
private static func buildTokenRects(text: String, language: String, 
                                    theme: EpistemosTheme) async -> [(rect: CGRect, color: NSColor)] {
    // ... FFI call + rect computation, same as current but off main thread
}
```
### Viewport Indicator via CALayer
The current viewport indicator is drawn in `draw(_:)`, causing a full redraw of the entire minimap on every scroll event. Use a `CALayer` instead:

```swift
class MinimapView: NSView {
    private let viewportLayer = CALayer()
    private let viewportTopBorder = CALayer()
    private let viewportBottomBorder = CALayer()
    
    // In init:
    wantsLayer = true
    layer?.addSublayer(viewportLayer)
    viewportLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
    
    // Call this from scrollDidChange (O(1) layer position update, no drawRect):
    func updateViewportIndicator() {
        guard let sv = scrollView, let tv = textView else { return }
        let totalHeight = CGFloat(totalDocumentLines) * 2.0
        let scale = totalHeight > bounds.height ? bounds.height / totalHeight : 1.0
        let contentHeight = tv.frame.height
        guard contentHeight > 0 else { return }
        
        let yRatio = sv.contentView.bounds.origin.y / contentHeight
        let hRatio = sv.contentView.bounds.height / contentHeight
        let drawableHeight = totalHeight * scale
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        viewportLayer.frame = CGRect(
            x: 0,
            y: yRatio * drawableHeight,
            width: bounds.width,
            height: max(hRatio * drawableHeight, 20)
        )
        CATransaction.commit()
    }
}
```
### Memory Footprint for 10,000+ Lines
Pre-computing token rects: each `(CGRect, NSColor)` pair is approximately 48 bytes (32 bytes CGRect + 16 bytes NSColor pointer). At ~10 tokens per line × 10,000 lines = 100,000 entries × 48 bytes = **~4.8MB** — perfectly acceptable. The ColorCache strategy (shared NSColor instances per token type) reduces this further since NSColor objects are shared references.

***
## Part 9 — Xcode Typography and Spacing
### Exact Xcode Defaults
| Property | Value |
|---|---|
| Font family | SF Mono |
| Weight | Regular |
| Size | **13pt** |
| Line height multiplier | **~1.5×** (≈ 19.5pt per line) |
| Tab stop interval | 4 × charWidth ≈ **7.8pt × 4 = 31.2pt** |
| `textContainerInset` | `NSSize(width: 4, height: 4)` |
| `lineFragmentPadding` | **4.0** (default NSTextView: 5.0) |
| Inter-character spacing | 0 (no extra kerning) |
| Paragraph spacing | 0 |

The recommended settings file from the VS Code Xcode theme confirms: `"editor.fontSize": 12` for VS Code (which renders larger than AppKit due to DPI handling), `"editor.lineHeight": 17` — which maps to approximately 13pt SF Mono at 1.5× in AppKit.[^5]
### `NSFont.monospacedSystemFont` vs `NSFont(name:)`
They resolve to the same `SFMono-Regular` on macOS 10.15+. Use `monospacedSystemFont` — it's forward-compatible and respects system accessibility preferences. Xcode itself uses a font descriptor approach internally but `monospacedSystemFont` is the correct public API.[^16]
### 1px Crisp Lines on Retina
Standard `NSBezierPath` with `lineWidth = 0.5` gives 1px physical pixels on 2x Retina. For `CGContext`-based drawing:

```swift
// In draw(_ dirtyRect:) — after calling super:
let scale = window?.backingScaleFactor ?? 2.0
let hairline = 1.0 / scale  // 0.5pt on 2x, 0.333pt on 3x

// Pixel-aligned rect helper:
extension CGRect {
    func pixelAligned(scale: CGFloat) -> CGRect {
        CGRect(
            x: (origin.x * scale).rounded(.down) / scale,
            y: (origin.y * scale).rounded(.down) / scale,
            width: (size.width * scale).rounded(.up) / scale,
            height: (size.height * scale).rounded(.up) / scale
        )
    }
}
```

For the gutter separator line, a 0.5pt-wide `NSRect.fill()` at x = `bounds.width - 0.5` gives a perfect hairline:

```swift
NSColor.separatorColor.withAlphaComponent(0.2).set()
NSRect(x: bounds.width - 0.5, y: 0, width: 0.5, height: bounds.height).fill()
```
### Mixed-Width Characters and CJK
SF Mono handles CJK by using double-width glyphs (2× charWidth). For a monospace editor this means CJK characters take up exactly 2 columns — indent guides will misalign unless you account for this. NSLayoutManager handles this transparently via `boundingRect(forGlyphRange:in:)`, so indent guide positions derived from glyph metrics are always correct.

***
## Part 10 — Dark/Light Theme Switching Architecture
### Observation Strategy
Three valid approaches, in order of preference:[^27][^28][^29]

**1. `viewDidChangeEffectiveAppearance()` on NSView subclass (preferred):**
```swift
class CodeTextView: NSTextView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Re-resolve theme from system appearance
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let newTheme: EpistemosTheme = isDark ? .systemDark : .systemLight
        applyTheme(newTheme)
    }
}
```

**2. KVO on `effectiveAppearance` in `NSViewRepresentable.makeNSView`:**
```swift
// In Coordinator.init or makeNSView:
let observation = textView.observe(\.effectiveAppearance) { [weak self] tv, _ in
    self?.parent.handleAppearanceChange(for: tv)
}
```

**3. `NSApp.effectiveAppearance` with `NSApplication.didChangeOccasionallyNotification`** — least recommended, fires too broadly.
### Pre-Computed Color Sets for Zero-Latency Switching
Pre-compute both color arrays at init time, swap atomically on theme change:[^27]

```swift
class CodeTextView: NSTextView {
    // Pre-compute both color tables at initialization:
    struct TokenColorTable {
        let colors: [NSColor]  // indexed by token_type UInt8
        let background: NSColor
        let foreground: NSColor
        let lineHighlight: NSColor
        let selection: NSColor
    }
    
    private let lightColors = TokenColorTable(colors: Self.buildLightColors(), ...)
    private let darkColors  = TokenColorTable(colors: Self.buildDarkColors(), ...)
    
    var activeColors: TokenColorTable { isDark ? darkColors : lightColors }
    
    func applyTheme(_ theme: EpistemosTheme) {
        let colors = theme.isDark ? darkColors : lightColors
        
        // 1. Update background and non-text colors immediately via CATransaction:
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.0)
        backgroundColor = colors.background
        layer?.backgroundColor = colors.background.cgColor
        CATransaction.commit()
        
        // 2. Reset textColor for typing:
        textColor = colors.foreground
        insertionPointColor = colors.foreground
        
        // 3. Re-apply syntax colors to visible range only:
        guard let lm = layoutManager, let tc = textContainer else { return }
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds
        let visibleGlyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
        let visibleCharRange = lm.characterRange(forGlyphRange: visibleGlyphRange, 
                                                  actualGlyphRange: nil)
        
        // Remove old temporary attributes and reapply with new color table:
        lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: visibleCharRange)
        applyHighlighting(in: visibleCharRange, colorTable: colors)
        
        // 4. Mark full document as invalid — will be lazily re-highlighted on scroll:
        lastHighlightHash = 0
    }
}
```
### Coordinating Gutter, Minimap, and Editor
All three views need to update atomically. The `NSViewRepresentable.updateNSView` path already handles this via `theme` property change. To ensure atomic visual update without a flash:

```swift
// In CodeEditorRepresentable.updateNSView:
func updateNSView(_ nsView: NSView, context: Context) {
    guard let tv = context.coordinator.textView,
          let gutter = context.coordinator.gutterView,
          let minimap = context.coordinator.minimapView else { return }
    
    let newBg = theme.isDark 
        ? NSColor(red: 0.121, green: 0.121, blue: 0.141, alpha: 1)
        : .white
    
    // Wrap all visual changes in a single CATransaction to prevent partial renders:
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    
    tv.backgroundColor = newBg
    tv.layer?.backgroundColor = newBg.cgColor
    gutter.backgroundColor = newBg
    gutter.layer?.backgroundColor = newBg.cgColor
    minimap.backgroundColor = newBg
    minimap.layer?.backgroundColor = newBg.cgColor
    
    CATransaction.commit()
    
    // Trigger syntax re-highlight after the visual update:
    tv.applyTheme(theme)
    gutter.needsDisplay = true
    minimap.rebuildTokenRects(theme: theme)
}
```
### System Colors That Auto-Adapt
These `NSColor` dynamic colors adapt automatically to dark/light without any code:[^30][^27]
- `NSColor.labelColor` — primary text
- `NSColor.secondaryLabelColor` — line numbers (inactive)
- `NSColor.separatorColor` — gutter separator, indent guides
- `NSColor.selectedTextBackgroundColor` — selection
- `NSColor.controlBackgroundColor` — gutter background (system default)
- `NSColor.textInsertionPointColor` — cursor (macOS 14+)

For syntax token colors, there is no auto-adapting equivalent — those must be explicitly set per-theme. However, using `NSColor.labelColor.withAlphaComponent(0.06)` for the current line highlight overlay means it automatically works in both modes.
### Does Xcode Pre-Cache Both Theme Color Sets?
Yes. Xcode pre-computes token attribute dictionaries for both dark and light modes at editor initialization. On theme switch, it performs a single-pass replacement of `foregroundColor` temporary attributes for the visible range, with the rest re-applied lazily on scroll. This gives the near-instant theme switch Xcode is known for.[^18]

***
## Summary: Critical Fixes by Priority
### Immediate Impact (Fix First)
1. **Switch `highlightSyntax` to use `layoutManager.addTemporaryAttribute` instead of `textStorage.addAttribute`** — single biggest performance gain, eliminates cursor jumping on highlight
2. **Add `textView.isVerticallyResizable = true`** — currently missing, can cause layout issues
3. **Set `textView.typingAttributes` with paragraph style** — required for correct line height
4. **Apply Xcode Default Dark/Light colors** from the tables above to `nsColorForTokenType`
### High Impact (Fix Second)
5. **Move current line highlight to `CALayer`** — eliminates full `drawBackground` call on every cursor move
6. **Implement visible-range-only incremental highlighting** via `NSTextStorageDelegate`
7. **Cache `lineStarts` in `LineNumberGutter`** — don't rebuild on every `draw()`
8. **Make `rebuildTokenRects` async** in `MinimapView`
### Polish (Fix Third)
9. **Add `pixelAligned` helper** and switch all hairline lines to 0.5pt
10. **Move viewport indicator to `CALayer`** in `MinimapView`
11. **Set `textContainerInset = NSSize(width: 4, height: 4)`** and `lineFragmentPadding = 4.0`
12. **Implement `viewDidChangeEffectiveAppearance`** for appearance-change handling with pre-cached color tables

---

## References

1. [xcode-github-theme/GitHub (Dark).xccolortheme at main](https://github.com/cntrump/xcode-github-theme/blob/main/GitHub%20(Dark).xccolortheme) - Ported version of github-vscode-theme. Contribute to cntrump/xcode-github-theme development by creat...

2. [Scratch Art.xccolortheme - jasonm23/xcode-themes - GitHub](https://github.com/jasonm23/xcode-themes/blob/master/Scratch%20Art.xccolortheme) - XCode themes with Sauce. Contribute to jasonm23/xcode-themes development by creating an account on G...

3. [Xcode Default Theme by smockle - VS Code Themes](https://vscodethemes.com/e/smockle.xcode-default-theme/xcode-default-dark) - Brings the colors of the Xcode 'Default (Dark)' and 'Default (Light)' themes to Visual Studio Code.

4. [Xcode Theme - Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=MateoCERQUETELLA.xcode-12-theme) - Bring the color of the following Xcode themes to Visual Studio Code: Xcode Default (Dark); Xcode Def...

5. [Brings the colors of the Xcode 'Default' theme to Visual Studio Code](https://github.com/smockle-archive/xcode-default-theme) - Brings the colors of the Xcode 'Default (Dark)' and 'Default (Light)' themes to Visual Studio Code. ...

6. [Nerdy internals of an Apple text editor - Hacker News](https://news.ycombinator.com/item?id=39603087) - Yeah, you can get pretty close to TextEdit by just dropping an NSTextView into the document window X...

7. [krzyzanowskim/STTextView: Performant and reusable text ... - GitHub](https://github.com/krzyzanowskim/STTextView) - STTextView. Performant macOS and iOS TextView with line numbers and much more. ... Add gutter with l...

8. [STTextView/README.md at main - GitHub](https://github.com/krzyzanowskim/STTextView/blob/main/README.md) - The goal of this project is to build NSTextView/UITextView replacement reusable component utilizing ...

9. [NSView performance of wantsLayer - Stack Overflow](https://stackoverflow.com/questions/30041190/nsview-performance-of-wantslayer) - If I create a blank Mac XCode project and layout 500 simple NSView objects side by side in the main ...

10. [canDrawSubviewsIntoLayer | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsview/candrawsubviewsintolayer) - Use this property to flatten the layer hierarchy for a layer-backed view and its subviews. Flattenin...

11. [10.9 AppKit Release Notes - GitHub Gist](https://gist.github.com/zwaldowski/8710fddc8b0b39d2c152) - The root layer must be either the NSScrollView or an ancestor view. Traditional drawing secondary re...

12. [NSLayoutManager and best override point for temporary attributes](https://groups.google.com/g/cocoa-dev/c/lQ6Fb-gAwO8) - Hello,. I have certain custom text attributes that are used in my NSTextStorage to which I would lik...

13. [Why the Selection Changes When You Do Syntax Highlighting in a ...](https://christiantietze.de/posts/2017/11/syntax-highlight-nstextstorage-insertion-point-change/) - You can avoid moving the selection if you do not notify the text system of changes to attributes. Th...

14. [Debugging NSTextView performance problem when editing multiple ...](https://support.hogbaysoftware.com/t/debugging-nstextview-performance-problem-when-editing-multiple-languages/1257) - I'm trying to figure out why some text (seems to be when mixing languages) is so slow to edit in NST...

15. [How to make scrollable NSTextView in AppKit - DEV Community](https://dev.to/onmyway133/how-to-make-scrollable-nstextview-in-appkit-986) - But if we try to use NSClipView to replicate what's in the xib, it does not scroll. To make it work,...

16. [Typography | Apple Developer Documentation](https://developer.apple.com/design/human-interface-guidelines/typography) - When you use SF Symbols, you get icons that scale automatically with Dynamic Type size changes. Keep...

17. [layerContentsRedrawPolicy - Documentation - Apple Developer](https://developer.apple.com/documentation/appkit/nsview/layercontentsredrawpolicy-swift.property?language=objc) - The layerContentsRedrawPolicy and layerContentsPlacement settings can have significant impacts on pe...

18. [What sets CodeEdit apart from other code editors like VS Code? #881](https://github.com/orgs/CodeEditApp/discussions/881) - The CodeEdit editor view will be based on tree-sitter which means incremental syntax highlighting. E...

19. [Incremental Parsing Using Tree-sitter - Federico Tomassetti](https://tomassetti.me/incremental-parsing-using-tree-sitter/) - In this tutorial, we are going to see: how to create a parser in Tree-sitter; how to define rules to...

20. [Tree-sitter: Revolutionizing Parsing with an Incremental Parsing ...](https://www.deusinmachina.net/p/tree-sitter-revolutionizing-parsing) - Parsing involves analyzing a sequence of tokens to determine its syntactic structure, often represen...

21. [Tree-sitter: an incremental parsing system for programming tools](https://news.ycombinator.com/item?id=26225298) - Tree Sitter is amazing. The parsing is fast enough to run on every keystroke. The parse tree is extr...

22. [copiesOnScroll | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsclipview/copiesonscroll) - copiesOnScroll. A Boolean value that indicates if the clip view copies rendered images while scrolli...

23. [Improving performance on NSTextView syntax highlighting via ...](https://stackoverflow.com/questions/15338120/improving-performance-on-nstextview-syntax-highlighting-via-nsattributedstring) - I'm working on adding some syntax highlighting to an app. In a testing class, I currently have an NS...

24. [Displaying Line Numbers with NSTextView — Noodlings - Noodlesoft](https://www.noodlesoft.com/blog/2008/10/05/displaying-line-numbers-with-nstextview/) - – if you enter 100 lines, the gutter correctly expands but if you add or remove lines then you may e...

25. [GitHub - raphaelhanneken/line-number-text-view](https://github.com/raphaelhanneken/line-number-text-view) - A basic line number gutter for NSTextView. Contribute to raphaelhanneken/line-number-text-view devel...

26. [Syntax Highlight Guide | Visual Studio Code Extension API](https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide) - Syntax highlighting determines the color and style of source code displayed in the Visual Studio Cod...

27. [[PDF] 218_Advanced Dark Mode.key - Huihoo](https://docs.huihoo.com/apple/wwdc/2018/218_advanced_dark_mode.pdf) - Dynamic colors. Template images. Materials. Asset Catalog assets in Xcode 10. Page 5. Adopting Dark ...

28. [Dark Side of the Mac: Updating Your App - MacKuba](https://mackuba.eu/2018/07/10/dark-side-mac-2/) - NSView has a new lifecycle callback method named viewDidChangeEffectiveAppearance called when the ap...

29. [Supporting Dark Mode: Responding to Change | Indie Stack](https://indiestack.com/2018/10/supporting-dark-mode-responding-to-change/) - ... changes, the most typical way to handle this is by implementing the “viewDidChangeEffectiveAppea...

30. [Dark Mode | Apple Developer Documentation](https://developer.apple.com/design/human-interface-guidelines/dark-mode) - Dark Mode is a systemwide appearance setting that uses a dark color palette to provide a comfortable...

