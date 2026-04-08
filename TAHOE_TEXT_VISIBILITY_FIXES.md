# macOS 26 Tahoe Text Visibility Fixes for CodeEditorView

## Problem Summary
Text was logically present (Apple Writing Tools could see it, Select All worked) but visually invisible in the CodeEditorView. This is a macOS 26-specific rendering issue at the intersection of TextKit 1, layer-backed views, and the Liquid Glass compositor.

## Root Causes Identified

1. **clipsToBounds Default Change (macOS 14+)**  
   `clipsToBounds` now defaults to `false`, causing background layers to overpaint text.

2. **Non-Contiguous Layout**  
   `allowsNonContiguousLayout = true` (default) causes the layout manager to skip glyph generation for "invisible" ranges, but the heuristic fails in layer-backed SwiftUI-hosted views.

3. **Layer Timing (wantsLayer)**  
   Setting `wantsLayer = true` before frame assignment causes CALayer to initialize with zero dimensions, permanently suppressing glyph cache.

4. **Color Space Mismatches**  
   Generic Gray colors (from `.white`, `.black`) don't blend correctly with the HDR-enabled Tahoe compositor.

5. **Layout Invalidation**  
   SwiftUI transactions suppress AppKit display updates; explicit layout forcing required.

## Fixes Applied

### 1. Clipping Bounds (TAHOE-001)
```swift
// In makeNSView:
scrollView.clipsToBounds = true  // Prevent dirtyRect bleeding
textView.clipsToBounds = true    // Prevent background overpaint
```

### 2. Disable Non-Contiguous Layout (TAHOE-002)
```swift
// Force full layout pass for reliable glyph generation
textView.layoutManager?.allowsNonContiguousLayout = false
```

### 3. Layer Timing Fix (TAHOE-003)
```swift
// BEFORE (problematic):
let container = NSView()
container.wantsLayer = true  // Layer initializes with zero frame

// AFTER (fixed):
let container = NSView()
// ... configure all subviews ...
container.wantsLayer = true  // Enable layer AFTER frame is valid

// For textView specifically:
textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
textView.wantsLayer = true  // AFTER frame assignment
```

### 4. Color Space Normalization (TAHOE-004)
```swift
// Convert to sRGB to prevent Tahoe compositor misinterpretation
let fgColor = (theme.isDark ? NSColor.white : NSColor.black).usingColorSpace(.sRGB)!
let bgColor = (theme.isDark 
    ? NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1) 
    : NSColor.white).usingColorSpace(.sRGB)!
```

### 5. Explicit Layout Forcing (TAHOE-005)
```swift
// After syntax highlighting:
textView.highlightSyntax(theme: theme)
let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
textView.layoutManager?.ensureLayout(forCharacterRange: fullRange)
textView.setNeedsDisplay(textView.bounds)
```

### 6. Typing Attributes Order (PREVIOUS FIX - Retained)
```swift
// Must set typingAttributes BEFORE string assignment
textView.typingAttributes = [
    .font: codeFont,
    .foregroundColor: fgColor,  // Critical: must include foregroundColor
    .paragraphStyle: paraStyle
]
textView.string = content  // AFTER typingAttributes
```

### 7. Adaptive Color Mapping (PREVIOUS FIX - Retained)
```swift
// Prevent system from inverting colors in dark mode
textView.usesAdaptiveColorMappingForDarkAppearance = false
```

## Diagnostic Commands (LLDB)
```bash
# Check layer state
po [textView layer]
po [textView frame]
po [textView layoutManager]

# Check color space
po [textView textColor]
po [textView backgroundColor]

# Force layout
expression textView.layoutManager?.ensureLayout(forCharacterRange: NSRange(location: 0, length: textView.string.utf16.count))
```

## Verification Checklist
- [ ] Text visible on initial load
- [ ] Selection highlights visible
- [ ] Cursor/insertion point visible
- [ ] Syntax highlighting applied
- [ ] Line numbers rendered
- [ ] Minimap rendered
- [ ] No background overpaint
- [ ] Writing Tools can still access text

## References
- macOS 26 Tahoe Layer-Backed View Changes
- AppKit Release Notes: clipsToBounds default behavior
- TextKit 1 vs TextKit 2 Layout Manager Differences
- Liquid Glass Compositor Color Space Requirements
