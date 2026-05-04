# Code Editor Debug Guide — For Kimi

> **Index status**: CANONICAL-RESEARCH — Debug guide for code editor syntax color invisibility — TextKit1 + NSTextView layout + potential causes/fixes.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



## Problem Statement

The code editor (`CodeEditorView.swift`) was upgraded with Xcode-grade colors and performance optimizations. After the upgrade:
1. **Text may be invisible** or not displaying syntax colors
2. **Editor may feel laggy** during scrolling
3. **Theme colors may not match** what was intended (Xcode Default Dark/Light)

The code compiles with zero errors and zero warnings. The issue is runtime behavior.

---

## Architecture Overview

```
NoteDetailWorkspaceView
  └─ noteEditorSurface(page:)
       ├─ CodeLanguage.detect(from: filePath) != nil → CodeEditorView (code files)
       └─ else → ProseEditorView (markdown/notes)

CodeEditorView (SwiftUI)
  └─ CodeEditorRepresentable (NSViewRepresentable)
       └─ NSView container
            ├─ LineNumberGutter (NSView, 48pt, left)
            ├─ NSScrollView → CodeTextView (NSTextView subclass, TextKit 1)
            └─ MinimapView (NSView, 80pt, right)
```

**CodeTextView** is an `NSTextView` subclass using **TextKit 1** (`NSLayoutManager` + `NSTextStorage`).

---

## What Was Changed

### File 1: `Epistemos/Theme/EpistemosTheme.swift`

**Added `XcodeCodeColors` struct** (~line 194) with exact Xcode Default Dark/Light colors extracted from `.xccolortheme` plists:

```
Dark:  bg=#1F1F24  fg=#DFDFE0  keywords=#FC5FA3  strings=#1FE906  functions=#CCFF9B
Light: bg=#FFFFFF  fg=#1C1C20  keywords=#AD3DA4  strings=#C41A16  functions=#2E6D8E
```

**Rewrote `nsColorForTokenType(_:)`** (~line 905) to dispatch through `xcodeColors` instead of the old semantic palette (emerald/amber/violet).

**`xcodeColors` is `@MainActor`** because `NSColor` isn't Sendable. This means it must be accessed from the main thread only.

### File 2: `Epistemos/Views/Notes/CodeEditorView.swift`

#### Highlighting Engine (CRITICAL CHANGE)
- **Before:** `textStorage.beginEditing()` → `addAttribute(.foregroundColor)` per token → `endEditing()`. This triggers `processEditing` → full layout invalidation on every keystroke.
- **After:** `layoutManager.addTemporaryAttribute(.foregroundColor)` per token. No `beginEditing/endEditing`. No layout invalidation. Temporary attributes are display-only.

The highlighting flow is now:
```
highlightSyntax(theme:)
  └─ retokenize()           ← calls Rust FFI, caches tokens as UTF-16 ranges
  └─ applyHighlighting(theme:, fullPass: true)  ← applies temp attrs to ALL tokens
```

On scroll:
```
scrollDidChange
  └─ applyHighlighting(theme:, fullPass: false)  ← applies temp attrs ONLY for visible range (additive, no clearing)
```

#### Current Line Highlight (MOVED TO CALayer)
- **Before:** Drawn in `drawBackground(in:)` via `NSBezierPath.fill()` — forces CPU redraw on every cursor move.
- **After:** Private `CALayer` sublayer (`currentLineLayer`). Only the layer's `frame` is updated on cursor move — GPU compositor handles the rest.

#### Other Changes
- `override var isOpaque: Bool { true }` — tells AppKit to skip compositing views behind
- `scrollView.wantsLayer = true` + `layerContentsRedrawPolicy = .onSetNeedsDisplay`
- `textContainerInset = NSSize(width: 0, height: 8)`
- `lineFragmentPadding = 4.0`
- `lineHeightMultiple = 1.1` in paragraph style
- `typingAttributes` set with font + foregroundColor + paragraphStyle
- 9 auto-features disabled (grammar, link detection, smart quotes, etc.)
- `applyBaseFormatting(theme:)` — sets font/foreground/paragraphStyle on textStorage ONCE

---

## Potential Root Causes of "No Text Visible"

### Cause 1: `applyBaseFormatting` Foreground Color Mismatch
`applyBaseFormatting` sets `storage.addAttribute(.foregroundColor, value: xc.editorForeground, ...)`. If the system appearance doesn't match `isDark`, the foreground could be dark-on-dark or light-on-light.

**Debug:** Add a temporary breakpoint or log in `applyBaseFormatting`. Check that `xc.editorForeground` is `#DFDFE0` (light gray) in dark mode, `#1C1C20` (near black) in light mode.

### Cause 2: Temporary Attributes Not Being Applied
`applyHighlighting(theme:, fullPass: true)` iterates `cachedTokens`. If `cachedTokens` is empty (FFI returned 0 tokens), no colors are applied.

**Debug:** Check that `retokenize()` actually populates `cachedTokens`. The FFI call is `markdown_parse_code_tokens(code, code_len, language, buffer, max_tokens)`. If the language string doesn't match a supported tree-sitter language, it returns 0 tokens.

**Supported languages in Rust:** swift, rust, python, javascript, typescript, tsx, json, html, css, bash, go, c, cpp

### Cause 3: `textView.textColor` Being Overwritten
`makeNSView` sets `textView.textColor = xc.editorForeground` at line ~196. Then `applyBaseFormatting` sets it again via `storage.addAttribute(.foregroundColor)`. If a subsequent AppKit layout pass resets textColor to the default, text could vanish.

**Debug:** Override `draw(_:)` on CodeTextView temporarily and check `textColor` and `textStorage?.foregroundColor` at draw time.

### Cause 4: `isOpaque = true` Without Proper Background Drawing
We set `override var isOpaque: Bool { true }`. This tells AppKit not to draw anything behind this view. If `drawsBackground` is false on the text view, the area would show garbage pixels.

**Check:** `textView.drawsBackground` defaults to `true` for NSTextView, but verify it's not being set to `false` somewhere.

### Cause 5: `@MainActor` on `xcodeColors` Causing Silent Failure
If `nsColorForTokenType` is called from a non-MainActor context, the `xcodeColors` access could behave unexpectedly. In Swift 6, this should produce a compiler error, but since the build passes, it should be fine. However, if there's a runtime actor hop, the colors might not be ready.

---

## Potential Root Causes of "Still Laggy"

### Cause 1: `scrollDidChange` Firing Too Often
The scroll notification handler calls `applyHighlighting(theme:, fullPass: false)` synchronously. This iterates ALL cached tokens (up to 16,384) on every scroll event. Even with the early-skip optimization, this is O(totalTokens) per scroll frame.

**Fix:** Add a threshold — only re-apply if the scroll position changed significantly since last application. Or debounce with `DispatchWorkItem`.

### Cause 2: `removeTemporaryAttribute` on Full Range During Text Changes
When the user types, `textDidChange` → `highlightSyntax` → `applyHighlighting(fullPass: true)` calls `lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)` which iterates the entire document.

**Fix:** Only clear the changed paragraph neighborhood, not the full document.

### Cause 3: `enumerateSubstrings` in `drawIndentGuides`
The indent guide drawing now enumerates paragraphs within the dirty rect on every draw call. For wide dirty rects this could iterate many lines.

---

## How to Verify the Fix

### Step 1: Check if Colors Are Working
Open a `.swift` file in the vault. You should see:
- **Background:** Dark charcoal (#1F1F24) or white
- **Keywords** (func, let, if, return): Hot pink (#FC5FA3) or magenta
- **Strings:** Bright green (#1FE906) or deep red
- **Comments:** Slate gray (#6C7986), italic
- **Functions:** Lime (#CCFF9B) or steel blue

If all text is ONE color (the foreground color), `applyHighlighting` isn't running or `cachedTokens` is empty.

### Step 2: Check if Tokens Are Being Generated
Add a temporary log in `retokenize()` after the FFI call:
```swift
#if DEBUG
NSLog("[CodeEditor] retokenize: language=\(language), code_len=\(text.utf8.count), tokens=\(cachedTokens.count)")
#endif
```

### Step 3: Check if Temporary Attributes Are Present
Add a temporary check in `applyHighlighting` after the loop:
```swift
#if DEBUG
let checkRange = NSRange(location: 0, length: min(100, nsLen))
let attrs = lm.temporaryAttributes(atCharacterIndex: 0, effectiveRange: nil)
NSLog("[CodeEditor] tempAttrs at index 0: \(attrs)")
#endif
```

### Step 4: Check Theme Resolution
```swift
#if DEBUG
let xc = theme.xcodeColors
NSLog("[CodeEditor] isDark=\(theme.isDark), bg=\(xc.editorBackground), fg=\(xc.editorForeground)")
#endif
```

---

## Files to Read

| File | What It Does |
|------|-------------|
| `Epistemos/Views/Notes/CodeEditorView.swift` | The entire code editor — CodeTextView subclass, gutter, minimap, highlighting |
| `Epistemos/Theme/EpistemosTheme.swift` | XcodeCodeColors struct (~line 194), nsColorForTokenType (~line 905), xcodeColors property (~line 272) |
| `graph-engine/src/code_highlight.rs` | Rust FFI — tree-sitter tokenization, CodeToken struct, supported languages |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Routes code files to CodeEditorView vs ProseEditorView (~line 963) |

## Key Methods to Trace

1. `CodeEditorRepresentable.makeNSView()` — creates everything, calls `applyBaseFormatting` then `highlightSyntax`
2. `CodeTextView.retokenize()` — calls Rust FFI, caches token positions
3. `CodeTextView.applyHighlighting(theme:, fullPass:)` — applies/clears temporary attributes
4. `CodeTextView.setupLayers(theme:)` — creates CALayer for current line highlight
5. `Coordinator.textDidChange` → `highlightSyntax` (full pass)
6. `Coordinator.scrollDidChange` → `applyHighlighting` (scroll pass, additive)
7. `Coordinator.selectionDidChange` → `updateCurrentLinePosition` (CALayer frame update)
