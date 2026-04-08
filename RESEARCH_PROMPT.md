# Research Prompt: Invisible Text in NSTextView-based Code Editor

**Platform:** macOS 26 (Swift 6 + Rust via FFI)  
**Framework:** AppKit, TextKit 1 (NSLayoutManager + NSTextStorage)  
**Build System:** Xcode 26, UniFFI for Rust/Swift bridge  
**Issue:** Text is invisible in code editor despite successful build and Apple Writing Tools detecting content

---

## Problem Summary

We have a hybrid Swift/Rust code editor for macOS 26. The editor:
- ✅ Compiles with zero errors
- ✅ `makeNSView` completes successfully (all 15 steps logged)
- ✅ Content loads (76KB Swift file, 8512 tokens from tree-sitter FFI)
- ✅ Apple Writing Tools can see and summarize the text
- ❌ **Text is visually invisible to the user**

The text view has:
- `drawsBackground = true`
- Explicit frame set `(0, 0, 800, 600)`
- High contrast colors (pure white on dark gray / black on white)
- `isRichText = true` for attributed string support
- `wantsLayer = true` on container

---

## Architecture

```
SwiftUI View (CodeEditorView)
    └─ NSViewRepresentable (CodeEditorRepresentable)
         └─ NSView container (wantsLayer = true)
              ├─ LineNumberGutter (NSView, 48pt left)
              ├─ NSScrollView
              │    └─ CodeTextView (NSTextView subclass)
              │         ├─ NSLayoutManager
              │         ├─ NSTextContainer  
              │         └─ NSTextStorage
              └─ MinimapView (NSView, 80pt right)

Rust FFI (graph-engine/src/code_highlight.rs)
    └─ Tree-sitter tokenization
         └─ Returns CodeToken array via markdown_parse_code_tokens()
```

---

## Key Implementation Details

### 1. NSTextView Configuration (makeNSView)

```swift
let textView = CodeTextView()  // NSTextView subclass
textView.isRichText = true
textView.drawsBackground = true

// HIGH CONTRAST DEBUG COLORS
let fgColor: NSColor = theme.isDark ? .white : .black
let bgColor: NSColor = theme.isDark ? NSColor(white: 0.1, alpha: 1) : .white

textView.textColor = fgColor
textView.backgroundColor = bgColor
textView.insertionPointColor = fgColor
textView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]

// Layout
textView.isHorizontallyResizable = true
textView.textContainer?.widthTracksTextView = false
textView.textContainer?.containerSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
textView.maxSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

// Container has red tint for visibility debugging
container.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.1).cgColor
```

### 2. Syntax Highlighting (Deferred)

```swift
// Called in DispatchQueue.main.async after makeNSView returns
func highlightSyntax(theme: EpistemosTheme) {
    let storage = textStorage ?? NSTextStorage()
    storage.beginEditing()
    
    // Base formatting
    storage.addAttribute(.font, value: font, range: fullRange)
    storage.addAttribute(.foregroundColor, value: textColor, range: fullRange)
    
    // Apply tokens from Rust FFI
    for token in tokens {
        let color = theme.nsColorForTokenType(token.token_type)  // @MainActor
        storage.addAttribute(.foregroundColor, value: color, range: tokenRange)
    }
    
    storage.endEditing()
}
```

### 3. CodeTextView Class Definition

```swift
class CodeTextView: NSTextView {
    var language: String = ""
    private var lastHighlightHash: Int = 0
    
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        // Draws current line highlight + indent guides
    }
}
```

### 4. ScrollView Setup

```swift
let scrollView = NSScrollView()
scrollView.hasVerticalScroller = true
scrollView.hasHorizontalScroller = true
scrollView.autohidesScrollers = true
scrollView.borderType = .noBorder
scrollView.drawsBackground = false
scrollView.documentView = textView
scrollView.layout()
```

---

## Observed Behavior

### Console Logs (All Successful):
```
[CodeEditor] === makeNSView START ===
[CodeEditor] Step 1: container created
[CodeEditor] Step 2: scrollView created
[CodeEditor] Step 3: textView created
[CodeEditor] Step 4: colors set - fg=<white>, bg=<black>  // High contrast!
[CodeEditor] Step 5: content set, length=76167
[CodeEditor] Step 6: documentView set, textView frame=(0.0, 0.0, 800.0, 600.0)
[CodeEditor] Step 7: gutter created
[CodeEditor] Step 8: subviews added
[CodeEditor] Step 9: minimap added
[CodeEditor] Step 10: constraints activated
[CodeEditor] Step 11: coordinator wired
[CodeEditor] Step 12: observers added
[CodeEditor] Step 13: deferred highlight starting
[CodeEditor] Step 15: about to return container
[CodeEditor] === makeNSView COMPLETE ===
[CodeEditor] Step 14: deferred highlight complete  // 8512 tokens applied
```

### Apple Writing Tools Behavior:
- ✅ Can select all text (⌘A shows blue selection)
- ✅ Writing Tools sees content and generates summaries
- ✅ "Show Original" works
- ❌ User cannot see text visually

---

## Files Involved (10 Key Files)

| File | Purpose | Key Aspects |
|------|---------|-------------|
| `Epistemos/Views/Notes/CodeEditorView.swift` | Main editor implementation | NSTextView setup, makeNSView, highlighting |
| `Epistemos/Theme/EpistemosTheme.swift` | Color theme system | XcodeCodeColors, nsColorForTokenType |
| `graph-engine/src/code_highlight.rs` | Rust tree-sitter tokenizer | TokenType enum, tokenize() function |
| `graph-engine-bridge/graph_engine.h` | FFI header | CodeToken struct, markdown_parse_code_tokens |
| `graph-engine/src/markdown.rs` | CodeToken definition | #[repr(C)] CodeToken { start, end, token_type } |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Workspace integration | noteEditorSurface(), CodeLanguage.detect() |
| `Epistemos/Views/Notes/MarkdownLayoutFragment.swift` | TextKit 2 integration (for prose) | CodeTokenBridge struct |
| `Epistemos/App/AppBootstrap.swift` | App initialization | Theme setup, appearance handling |
| `Epistemos/State/UIState.swift` | UI state management | Theme changes, dark mode |
| `build-rust.sh` | Rust build script | FFI library compilation |

---

## Specific Questions to Research

### 1. NSTextView Visibility Issues
- What causes NSTextView to have invisible text despite `textColor` and `backgroundColor` being set?
- Does `isRichText = true` require specific attribute configurations for visibility?
- Can `NSLayoutManager` or `NSTextContainer` misconfiguration cause invisible text?

### 2. Color Space / Rendering Issues
- Does using `NSColor(white:alpha:)` vs `NSColor(srgbRed:green:blue:alpha:)` affect visibility?
- Can color space mismatches (sRGB vs Generic Gray Gamma 2.2) cause invisible text?
- Does `usingColorSpace(.sRGB)` help or hurt?

### 3. Layer-Backed View Issues
- Does `wantsLayer = true` on parent container affect NSTextView rendering?
- Is there a z-ordering issue with CALayer sublayers?
- Does `layerContentsRedrawPolicy = .onSetNeedsDisplay` affect text visibility?

### 4. TextKit 1 Specific Issues
- Does `NSLayoutManager` need explicit invalidation for text to appear?
- Can `NSTextStorage` transactions (`beginEditing`/`endEditing`) cause invisible text if not balanced?
- Does `processEditing` need to be called explicitly?

### 5. macOS 26 / Swift 6 Specific
- Are there new macOS 26 security/sandbox restrictions affecting text rendering?
- Does Swift 6 strict concurrency affect AppKit view rendering?
- Are there known NSTextView regressions in macOS 26?

### 6. SwiftUI Integration Issues
- Does NSViewRepresentable have specific requirements for NSTextView?
- Can `updateNSView` being called early cause invisible text?
- Does `makeCoordinator` timing affect view setup?

### 7. FFI / Threading Issues
- Can Rust FFI calls on main thread block AppKit rendering?
- Does `withCString` or `UnsafeMutablePointer` usage affect memory in ways that corrupt rendering?
- Is there a race condition between Swift view setup and Rust tokenization?

---

## Diagnostic Commands to Run

```bash
# Check for color space issues
log stream --predicate 'process == "Epistemos"' --level debug | grep -E "(Color|color|fg|bg)"

# Check for view hierarchy issues
# In LLDB: po [[[NSApp keyWindow] contentView] recursiveDescription]

# Check for layer issues  
# In LLDB: po [textView wantsLayer]
# In LLDB: po [textView layer]
```

---

## References to Include in Search

- Apple Documentation: NSTextView, NSLayoutManager, NSTextStorage
- AppKit Release Notes for macOS 26
- Swift 6 Concurrency and AppKit compatibility
- Tree-sitter FFI best practices
- NSTextView drawBackground vs drawRect timing
- NSColor color spaces and display P3/sRGB issues

---

## Summary

**What's working:**
- Build succeeds
- View hierarchy created
- Content loaded (76KB, 8512 tokens)
- Colors set (high contrast white on black)
- Frame is valid (800x600)
- Apple Writing Tools can access text

**What's not working:**
- Text is visually invisible to user
- No rendering errors in console
- No crashes or exceptions

**Hypothesis:** This is a rendering-level issue related to:
1. Color space mismatch
2. Layer-backed view compositing  
3. NSTextView initialization timing
4. macOS 26 specific AppKit changes

Please provide specific debugging steps, known issues, or solutions for invisible NSTextView text in macOS 26 Swift 6 apps.
