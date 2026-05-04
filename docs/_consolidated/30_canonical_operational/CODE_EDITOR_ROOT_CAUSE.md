# Code Editor Invisible Text — Root Cause & Fix Path

> **Index status**: CANONICAL-OPERATIONAL — Code editor root-cause analysis; companion to CODE_EDITOR_DEBUG.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## For: Kimi (implementation agent)
## Date: 2026-04-07

---

## Root Cause: `drawBackground(in:)` Override + macOS Sonoma/Tahoe `clipsToBounds` Change

**The exact same bug was found and fixed in the Scintilla text editor project** ([Scintilla Bug #2402](https://sourceforge.net/p/scintilla/bugs/2402/)).

### What Changed in macOS 14 Sonoma (and continues in Tahoe)

Starting with macOS 14 Sonoma, `NSView.clipsToBounds` **defaults to `false`**. This means `drawRect:` / `drawBackground(in:)` can receive a `rect` parameter that is **larger than the view's bounds** — it can extend into neighboring views. When `super.drawBackground(in: rect)` is called with this oversized rect, it paints the background color OVER the text glyphs, making them invisible.

### Why This Affects CodeTextView

`CodeTextView` overrides `drawBackground(in:)` to draw indent guides and (previously) the current line highlight. The `rect` parameter on Sonoma/Tahoe can be larger than `bounds`, causing `super.drawBackground(in: rect)` to overpaint.

### The Scintilla Fix (Proven Working)

```objc
- (void)drawRect:(NSRect)rect {
    // Sonoma fix: clamp rect to bounds
    if (!NSContainsRect(self.bounds, rect)) {
        rect = self.bounds;
    }
    [super drawRect:rect];
}
```

### Apply to CodeTextView

In `CodeTextView.drawBackground(in:)`, add bounds clamping at the top:

```swift
override func drawBackground(in rect: NSRect) {
    // macOS 14+ fix: clipsToBounds defaults to false, so rect can extend
    // beyond our bounds. Clamp it to prevent overpainting text glyphs.
    let clampedRect = bounds.intersection(rect)
    guard !clampedRect.isNull else { return }
    super.drawBackground(in: clampedRect)

    // ... indent guides drawn within clampedRect ...
}
```

**This is the PRIMARY fix.** Apply it first, then test.

---

## Secondary Issue: `updateNSView` Re-Highlights on Every SwiftUI State Change

Current code at line ~353:
```swift
func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.textView?.highlightSyntax(theme: theme)
}
```

This fires on EVERY cursor move (because `cursorLine`/`cursorCol` are `@State` bindings that change on selection). Each call does `beginEditing/endEditing` which invalidates layout. Fix:

```swift
func updateNSView(_ nsView: NSView, context: Context) {
    guard context.coordinator.lastAppliedTheme != theme else { return }
    context.coordinator.lastAppliedTheme = theme
    context.coordinator.textView?.highlightSyntax(theme: theme)
}
```

Add `var lastAppliedTheme: EpistemosTheme?` to Coordinator.

---

## Minimap Quality

The current minimap renders token rects as tiny colored pixels. To match Xcode quality (like the screenshot), consider using [CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor) as reference — their minimap renders actual scaled-down text using Core Graphics, not pixel rects.

For a quick improvement: render the minimap using `NSAttributedString.draw(in:)` at a tiny font size (2-3pt) instead of `CGRect.fill()`. This gives actual character shapes instead of colored blocks.

---

## Alternative Approaches if drawBackground Fix Doesn't Work

### Option A: Use CodeEditSourceEditor (SPM Package)
[CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor) is an open-source Swift code editor with tree-sitter, SwiftUI integration, minimap, and line numbers. It solves all the rendering issues because it uses TextKit 2 with custom viewport-based rendering that bypasses the `drawBackground` pipeline entirely.

Add via SPM: `https://github.com/CodeEditApp/CodeEditSourceEditor`

### Option B: Use STTextView
[STTextView](https://github.com/krzyzanowskim/STTextView) is a complete NSTextView replacement using TextKit 2. It doesn't have the `drawBackground` issue because it renders entirely through `NSTextLayoutManager` + `CALayer` composition.

### Option C: Remove `drawBackground` Override Entirely
If the indent guides are causing the issue, remove the `drawBackground(in:)` override entirely to test. Indent guides can be added later as a separate `CAShapeLayer` overlay instead.

---

## Exact Steps to Fix (Ordered)

### Step 1: Add Bounds Clamping to drawBackground
In `CodeTextView`:
```swift
override func drawBackground(in rect: NSRect) {
    let safeRect = bounds.intersection(rect)
    guard !safeRect.isNull else { return }
    super.drawBackground(in: safeRect)
    // ... rest of drawing code uses safeRect ...
}
```

### Step 2: Guard updateNSView
```swift
func updateNSView(_ nsView: NSView, context: Context) {
    guard context.coordinator.lastAppliedTheme != theme else { return }
    context.coordinator.lastAppliedTheme = theme
    // ... re-highlight ...
}
```

### Step 3: Test
Build and run. Open a `.swift` file from the vault. Text should be visible.

### Step 4: If Still Invisible
Remove `drawBackground(in:)` override entirely. If text appears, the issue is confirmed to be in the drawBackground pipeline. Re-add drawing with the clamped rect.

### Step 5: If STILL Invisible
The issue is deeper — switch to CodeEditSourceEditor or STTextView as the text rendering component.

---

## Current State of CodeEditorView.swift

**WARNING:** The file has been modified multiple times. The current state has a MINIMAL test version that returns just an `NSScrollView` with no gutter or minimap, with `isRichText = false`. This needs to be reverted to the full version with the bounds-clamping fix applied.

The last known working full version (with Tahoe fixes from Kimi) should be restored from git, then the bounds-clamping fix should be applied on top.

```bash
# Restore to Kimi's last working version, then apply the fix
git checkout HEAD -- Epistemos/Views/Notes/CodeEditorView.swift
# Then apply the drawBackground bounds-clamping fix
```

---

## Research Sources

- [Scintilla Bug #2402 — Text invisible on Sonoma with Xcode 15](https://sourceforge.net/p/scintilla/bugs/2402/) — **exact same bug, exact fix**
- [Apple Forums — NSTextView invisible in app](https://developer.apple.com/forums/thread/738995) — same symptom
- [Apple Forums — NSTextView subclass not displaying in Sonoma](https://developer.apple.com/forums/thread/739492) — same symptom
- [Apple Forums — NSTextView Contents Disappear](https://developer.apple.com/forums/thread/767825) — related
- [CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor) — working open-source code editor
- [STTextView](https://github.com/krzyzanowskim/STTextView) — TextKit 2 NSTextView replacement
- [CodeEditorView](https://github.com/mchakravarty/CodeEditorView) — SwiftUI code editor with minimap
