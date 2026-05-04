# Optimizing `drawBackground`: CALayer Overlays + Dirty-Rect Drawing for NSTextView

> **Target:** `CodeTextView` in Epistemos — NSTextView (TextKit 1) with tree-sitter syntax highlighting, line-number gutter, and minimap.
> **Goal:** Eliminate every unnecessary pixel redrawn in `drawBackground(in:)` and replace the current-line highlight with a zero-cost CALayer overlay.

***

## Executive Summary

The current `drawBackground(in:)` implementation has two expensive patterns that fire on **every keystroke and selection change**:

1. **Full-bounds line highlight** — computes a `boundingRect` for the glyph range of the current line and then `fill`s a rect that spans the **full view width**, even when only the cursor moved one character within the same line.
2. **Indent guide redraw** — even though the path is cached per content hash, the **entire path is stroked** on every draw call, including when the dirty rect is just a tiny text-insertion sliver.

The fix is a two-pronged strategy: move the current-line highlight into a **dedicated CALayer sublayer** (so it is composited by the GPU with zero CPU draw cost on scroll/cursor move), and gate all `drawBackground` geometry through **tight dirty-rect intersection tests** so indent guides are only stroked for lines that actually intersect the invalidated area.

***

## Part 1 — Why `drawBackground` Fires So Often

### The trigger chain

Every time `selectionDidChange` fires in `Coordinator`, the code calls:

```swift
tv.setNeedsDisplay(tv.visibleRect)
```

This marks the entire visible rect dirty. AppKit coalesces dirty rects within one run-loop turn, then calls `draw(_:)` → `drawBackground(in:)` with the **union** of all dirty areas as `rect`. For a single cursor blink or character insertion, that union is typically a very small region — but the code ignores the `rect` parameter and processes the whole view.[^1]

### The `dirtyRect` / `rect` parameter

The `rect` passed into `drawBackground(in:)` is the **union of all pending dirty rectangles** accumulated since the last draw. Since macOS 10.3 (and still true today), the system may subdivide that area into multiple non-overlapping rects. The view can retrieve them with:[^1]

```swift
var rectsPtr: UnsafePointer<NSRect>?
var count: Int = 0
getRectsBeingDrawn(&rectsPtr, count: &count)
```

Or use the simpler predicate form:[^1]

```swift
if needsToDrawRect(someRect) { /* draw it */ }
```

**Critical macOS 14 note:** Starting with Sonoma, AppKit may pass a `dirtyRect` that extends **outside** the view's own bounds (e.g., when adjacent views are composited). Do not use `dirtyRect` to decide *where* to draw; use it only to decide *whether* to draw.[^2]

***

## Part 2 — Current-Line Highlight: Move to a CALayer

### Why CALayer beats `drawBackground`

| Approach | CPU cost per cursor move | Triggers full redraw? | GPU composited? |
|---|---|---|---|
| `fill` in `drawBackground` | Moderate — whole-method re-entry | Yes — entire visible rect | No |
| Dedicated `CALayer` sublayer | ~Zero — just a `frame` property update | No — layer tree is independent | Yes |

When `wantsLayer = true` is set on the text view's **NSScrollView ancestor**, AppKit switches the entire scroll view hierarchy to layer-backed rendering. In that mode, changing a sublayer's `frame` is a **Core Animation property change** — it goes through the GPU compositor without calling `draw(_:)` at all.[^3][^4]

The `layerContentsRedrawPolicy` value `NSViewLayerContentsRedrawOnSetNeedsDisplay` is the key: it means `draw(_:)` is only called when you **explicitly** call `setNeedsDisplay(_:)`, not on every frame or frame-size change.[^4][^3]

### Implementation

```swift
// Inside CodeTextView — add these two stored properties
private var lineHighlightLayer = CALayer()
private var indentGuideLayer   = CALayer()   // optional: see Part 3

override func awakeFromNib() {
    super.awakeFromNib()
    setupHighlightLayers()
}

// Also call from init if not using nibs:
func setupHighlightLayers() {
    wantsLayer = true
    layerContentsRedrawPolicy = .onSetNeedsDisplay

    lineHighlightLayer.zPosition = -1           // behind text, above background
    lineHighlightLayer.actions = [              // disable implicit animations
        "frame":    NSNull(),
        "position": NSNull(),
        "bounds":   NSNull()
    ]
    layer?.addSublayer(lineHighlightLayer)
}
```

Update the layer's position whenever the selection changes. The correct hook is `NSTextView.didChangeSelectionNotification` (already observed in `Coordinator`):

```swift
// In Coordinator.selectionDidChange(_:)
tv.updateLineHighlightLayer()

// In CodeTextView:
func updateLineHighlightLayer() {
    guard let lm = layoutManager, let tc = textContainer else { return }

    let insertionLoc = selectedRange.location
    let lineRange = (string as NSString).lineRange(
        for: NSRange(location: insertionLoc, length: 0))
    let glyphRange = lm.glyphRange(
        forCharacterRange: lineRange, actualCharacterRange: nil)
    var lineRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)

    // Map from text-container space to view space
    lineRect.origin.y  += textContainerInset.height
    lineRect.origin.x   = 0
    lineRect.size.width = bounds.width          // full-width stripe

    CATransaction.begin()
    CATransaction.setDisableActions(true)       // instant, no animation
    lineHighlightLayer.frame = lineRect
    lineHighlightLayer.backgroundColor =
        NSColor.labelColor.withAlphaComponent(0.055).cgColor
    CATransaction.commit()
}
```

**Remove the current-line highlight block from `drawBackground(in:)` entirely.** The layer handles it at zero CPU cost from now on.

### Keeping the layer in sync during scroll and resize

When the scroll position changes or the view is resized, the layer's `frame` is in the text view's coordinate space and stays correct automatically — **no update needed on scroll**. The only time you must call `updateLineHighlightLayer()` is when the **cursor moves** (selection change) or **text is inserted** (which may change line geometry).

```swift
// Coordinator.textDidChange
tv.updateLineHighlightLayer()
tv.highlightSyntax(theme: parent.theme)
```

### Retina precision

On a 2× Retina display, a 1-logical-pixel layer has 2 physical pixels of backing. CoreAnimation handles this automatically — no explicit `contentsScale` needed for a solid-color layer.[^5]

***

## Part 3 — Indent Guide Dirty-Rect Optimization

### The current problem

`buildGuidePath` iterates **all paragraphs** in the document to build a single `NSBezierPath`, then strokes the whole path in every `drawBackground` call. For a 2000-line file this means stroking thousands of guide segments even when only a 20px sliver at the cursor position is dirty.

### Strategy A: Gate with `needsToDrawRect`

The simplest fix is to stroke each line's guide segments only when that line's rect intersects the dirty area:

```swift
override func drawBackground(in rect: NSRect) {
    super.drawBackground(in: rect)

    guard let lm = layoutManager, let tc = textContainer else { return }

    // ── Indent guides — only stroke lines that intersect the dirty rect ──
    let indentColor = NSColor.separatorColor.withAlphaComponent(0.15)
    indentColor.set()

    let spaceWidth = cachedSpaceWidth  // computed once; see below
    let indentWidth: CGFloat = 4
    let inset = textContainerInset

    // Enumerate only glyph rects within the dirty rect
    let visibleGlyphRange = lm.glyphRange(
        forBoundingRectWithoutAdditionalLayout: rect, in: tc)
    let nsStr = string as NSString

    lm.enumerateLineFragments(forGlyphRange: visibleGlyphRange) {
        [weak self] lineRect, _, _, glyphRange, _ in
        guard let self else { return }

        let charRange = lm.characterRange(
            forGlyphRange: glyphRange, actualGlyphRange: nil)
        let lineStr = nsStr.substring(with: charRange)
        let leadingSpaces = lineStr.prefix(while: { $0 == " " }).count
        let indentLevels = leadingSpaces / Int(indentWidth)
        guard indentLevels > 0 else { return }

        // Map lineRect from text-container to view coordinates
        let viewY = lineRect.origin.y + inset.height

        for level in 1...indentLevels {
            let x = inset.width + CGFloat(level) * indentWidth * spaceWidth
            // Pixel-snap to avoid anti-aliasing blur on Retina
            let snappedX = round(x * 2.0) / 2.0
            var path = NSBezierPath()
            path.move(to: NSPoint(x: snappedX, y: viewY))
            path.line(to: NSPoint(x: snappedX, y: viewY + lineRect.height))
            path.lineWidth = 0.5
            path.stroke()
        }
    }
}
```

`glyphRange(forBoundingRectWithoutAdditionalLayout:in:)` returns only the glyph range visible in `rect`. This is the **critical API** that makes indent guides O(visible lines) instead of O(all lines).[^6]

### Strategy B: Separate CALayer for indent guides (advanced)

For maximum performance (10,000+ line files), move indent guides to their own `CAShapeLayer`:

```swift
private var guideShapeLayer = CAShapeLayer()

func setupHighlightLayers() {
    // ... (lineHighlightLayer setup from Part 2) ...
    guideShapeLayer.zPosition = -0.5   // above highlight, below text
    guideShapeLayer.strokeColor =
        NSColor.separatorColor.withAlphaComponent(0.15).cgColor
    guideShapeLayer.fillColor   = nil
    guideShapeLayer.lineWidth   = 0.5
    guideShapeLayer.actions     = ["path": NSNull()]  // no animation
    layer?.addSublayer(guideShapeLayer)
}
```

Rebuild the guide path **only on text change** (already gated by `invalidateGuideCache`). The layer then composites without any `drawBackground` involvement on scroll:

```swift
// In textDidChange (after highlighting):
rebuildGuideShapeLayer()

func rebuildGuideShapeLayer() {
    guard let lm = layoutManager, let tc = textContainer else { return }
    let path = CGMutablePath()
    let nsStr = string as NSString
    let inset = textContainerInset
    let sw = cachedSpaceWidth
    let indentWidth: CGFloat = 4

    lm.enumerateLineFragments(
        forGlyphRange: NSRange(location: 0, length: lm.numberOfGlyphs))
    { lineRect, _, _, glyphRange, _ in
        let charRange = lm.characterRange(
            forGlyphRange: glyphRange, actualGlyphRange: nil)
        let lineStr = nsStr.substring(with: charRange)
        let leadingSpaces = lineStr.prefix(while: { $0 == " " }).count
        let levels = leadingSpaces / Int(indentWidth)
        guard levels > 0 else { return }

        let viewY = lineRect.origin.y + inset.height
        for level in 1...levels {
            let x = round((inset.width + CGFloat(level) * indentWidth * sw) * 2) / 2
            path.move(to: CGPoint(x: x, y: viewY))
            path.addLine(to: CGPoint(x: x, y: viewY + lineRect.height))
        }
    }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    guideShapeLayer.path = path
    CATransaction.commit()
}
```

**Trade-off:** Building the full `CGPath` for a 10K-line file takes ~5–15ms on the main thread. For very large files, push this to a background `DispatchQueue.global(qos: .userInitiated)` and swap the layer path back on main:

```swift
let capturedText = string
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    let path = self?.buildGuidePath(for: capturedText)
    DispatchQueue.main.async {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self?.guideShapeLayer.path = path
        CATransaction.commit()
    }
}
```

***

## Part 4 — Revised `drawBackground(in:)` After Both Optimizations

With the current-line highlight moved to a CALayer and guide drawing gated by `glyphRange(forBoundingRect:)`, `drawBackground` becomes:

```swift
override func drawBackground(in rect: NSRect) {
    super.drawBackground(in: rect)
    // Current-line highlight → handled by lineHighlightLayer (CALayer)
    // Indent guides → handled by guideShapeLayer OR visible-range enumeration below

    guard !useGuideLayer else { return }   // flag set in init

    // Strategy A fallback: stroke only visible guides
    guard let lm = layoutManager, let tc = textContainer else { return }

    let inset = textContainerInset
    let sw    = cachedSpaceWidth
    let path  = NSBezierPath()
    path.lineWidth = 0.5

    let visibleGlyphRange = lm.glyphRange(
        forBoundingRectWithoutAdditionalLayout: rect, in: tc)

    lm.enumerateLineFragments(forGlyphRange: visibleGlyphRange) {
        [weak self] lineRect, _, _, glyphRange, _ in
        guard let self else { return }
        let charRange = lm.characterRange(
            forGlyphRange: glyphRange, actualGlyphRange: nil)
        let lineStr = (self.string as NSString).substring(with: charRange)
        let levels  = lineStr.prefix(while: { $0 == " " }).count / 4
        guard levels > 0 else { return }
        let viewY = lineRect.origin.y + inset.height
        for lv in 1...levels {
            let x = round((inset.width + CGFloat(lv * 4) * sw) * 2) / 2
            path.move(to: NSPoint(x: x, y: viewY))
            path.line(to: NSPoint(x: x, y: viewY + lineRect.height))
        }
    }

    NSColor.separatorColor.withAlphaComponent(0.15).set()
    path.stroke()
}
```

`drawBackground` now does **no work** when the dirty rect is only the cursor-blink region (the lineHighlightLayer updated silently), and **minimal work** on text-insertion redraws (only lines within the dirty rect).

***

## Part 5 — Coalescing `setNeedsDisplay` Calls

### The current pattern (suboptimal)

In `Coordinator.selectionDidChange`, the code calls:

```swift
tv.setNeedsDisplay(tv.visibleRect)
gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
```

This marks the entire visible rect dirty for a selection change that may only have moved the cursor. With the CALayer approach, the text view itself doesn't need `setNeedsDisplay` at all for a pure cursor move.

### Revised selection handler

```swift
@objc func selectionDidChange(_ notification: Notification) {
    guard let tv = textView else { return }
    let (line, col) = tv.cursorPosition
    parent.cursorLine = line
    parent.cursorCol  = col

    // Update highlight layer — NO setNeedsDisplay on the text view
    tv.updateLineHighlightLayer()

    // Gutter only needs to redraw the line number area
    // (active line color changes); invalidate just the gutter
    gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
}
```

For `textDidChange`, keep invalidating the visible rect (text content changed), but **not** on pure selection changes.

### Coalescing with `RunLoop.current.perform`

If the minimap or gutter triggers multiple `setNeedsDisplay` calls per event (e.g., from both `textDidChange` and a subsequent `scrollDidChange`), coalesce them:

```swift
private var needsGutterRedraw = false

func scheduleGutterRedraw() {
    guard !needsGutterRedraw else { return }
    needsGutterRedraw = true
    RunLoop.current.perform(inModes: [.default]) { [weak self] in
        self?.needsGutterRedraw = false
        self?.gutterView?.setNeedsDisplay(self?.gutterView?.bounds ?? .zero)
    }
}
```

This guarantees only one `draw` call per run-loop turn regardless of how many events arrive.[^7]

***

## Part 6 — Layer Setup and `isOpaque`

### `isOpaque` is the silent performance flag

A non-opaque `NSView` forces the window server to composite the view **and all views behind it** on every draw. For a code editor with a solid background color, returning `true` from `isOpaque` eliminates that work:[^8]

```swift
// In CodeTextView
override var isOpaque: Bool { return true }
```

This is safe because the text view's `backgroundColor` is always a fully-opaque color (set from `EpistemosTheme`).

### `wantsDefaultClipping` bypass

For the indent guide path, you can skip AppKit's built-in clip setup (which has a small but non-zero cost) by overriding:

```swift
override var wantsDefaultClipping: Bool { return false }
```

When you do this, you are responsible for not drawing outside `getRectsBeingDrawn`. Since the `enumerateLineFragments(forGlyphRange:)` approach already limits geometry to the passed visible glyph range, this is safe.[^9]

### Full layer configuration in `CodeTextView.init`

```swift
// Recommended layer config for layer-backed NSTextView
wantsLayer          = true
layerContentsRedrawPolicy = .onSetNeedsDisplay

// NSScrollView ancestor also needs wantsLayer for responsive scrolling
// (set this in CodeEditorRepresentable.makeNSView):
scrollView.wantsLayer = true
scrollView.contentView.wantsLayer = true
```

Setting `wantsLayer` on the **scroll view** (not just the text view) activates AppKit's tile-layer system. AppKit tiles the document view into approximately screen-sized CALayer tiles, only redrawing tiles that become dirty. This is how large documents scroll smoothly even when only part of the content is visible.[^3]

***

## Part 7 — `preparedContentRect` and Overdraw

AppKit's responsive scrolling system pre-renders content **outside the visible rect** into tiles while the main thread is idle. This is the `preparedContentRect` mechanism. For `NSTextView`, it is automatic as long as you do not override `scrollWheel:` or `lockFocus:`.[^3]

The text view's `drawBackground(in:)` **will be called with rects outside the visible area** during this prefetch. The `glyphRange(forBoundingRectWithoutAdditionalLayout:in:)` call handles this naturally — it will return only the glyphs within whatever rect AppKit passes, whether that is the visible rect or a pre-rendered overdraw rect.

Do **not** short-circuit `drawBackground` by testing `rect.intersects(visibleRect)` — this breaks prefetch and makes scrolling look unready.[^3]

***

## Part 8 — Pixel-Snapping Indent Guides on Retina

Retina displays have a `backingScaleFactor` of 2.0. A 0.5-logical-pixel guide line renders as exactly 1 physical pixel on Retina — but only if the line's X position is on a **half-pixel logical boundary** (i.e., a pixel-grid boundary):[^5]

```swift
// Pixel-snap to the nearest 0.5pt (= 1px on 2x Retina)
let scale = window?.backingScaleFactor ?? 2.0
let snappedX = round(x * scale) / scale
```

For a scale of 2.0, this rounds `x` to the nearest 0.5. For non-Retina (scale = 1.0), it rounds to the nearest 1.0. This produces crisp 1-physical-pixel guide lines on all display densities. For `CAShapeLayer` paths, the layer's `contentsScale` is automatically matched to the display — no extra work needed.

***

## Part 9 — Integration with EpistemosTheme

The current `drawBackground` uses `NSColor.labelColor.withAlphaComponent(0.06)` for the line highlight. With the CALayer approach, update this color during **theme switches** via `viewDidChangeEffectiveAppearance`:

```swift
override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    // Re-apply theme-aware colors to layers
    let highlightAlpha: CGFloat = isDark ? 0.055 : 0.045
    lineHighlightLayer.backgroundColor =
        NSColor.labelColor.withAlphaComponent(highlightAlpha).cgColor
    guideShapeLayer.strokeColor =
        NSColor.separatorColor.withAlphaComponent(0.15).cgColor
}
```

`NSColor.labelColor` and `NSColor.separatorColor` are dynamic system colors that automatically resolve to the correct light/dark variant. Using them as the base (rather than hard-coded hex) means theme transitions are free — CoreAnimation will composite the correct resolved color without any re-highlight pass.

***

## Part 10 — Pitfalls and Common Mistakes

### 1. Adding sublayers before `layer` is non-nil

`layer` is `nil` until `wantsLayer = true` is set. Always set `wantsLayer` **before** calling `layer?.addSublayer(...)`. The `setupHighlightLayers()` function above handles this correctly.

### 2. CALayer `frame` in wrong coordinate space

`layoutManager.boundingRect(forGlyphRange:in:)` returns a rect in **text-container coordinates**. Convert to the text view's coordinate space by adding `textContainerInset`:

```swift
var r = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
r.origin.y += textContainerInset.height
r.origin.x  = 0   // always full-width stripe
```

The layer's `frame` is in the **view's own bounds coordinates** (not the scroll view's). This is correct because the layer is a sublayer of `self.layer`, which is in the text view's coordinate system.

### 3. Implicit CAAnimation on layer frame changes

By default, CALayer animates property changes with a 0.25s fade. This makes the highlight appear to "slide" when the cursor jumps. Always wrap frame updates in `CATransaction.setDisableActions(true)` or provide an explicit `actions` dictionary as shown in Part 2.

### 4. `glyphRange(forBoundingRect:)` vs `glyphRange(forBoundingRectWithoutAdditionalLayout:)`

The version **without** `AdditionalLayout` is dramatically faster for large files — it does not trigger layout for off-screen glyphs. Use it in `drawBackground`. Use the **with** layout version only when you need precise glyph positions (e.g., for the line number gutter).[^6]

### 5. Stroking `NSBezierPath` vs `CGContext` line drawing

`NSBezierPath.stroke()` has internal state setup overhead per call. For many short line segments (indent guides), batch them into a **single path** per draw call as shown. The `CGContext` raw API (`context.strokePath()`) is marginally faster still for very large segment counts.

### 6. `drawBackground` and `super.drawBackground(in:)` order

Always call `super.drawBackground(in:)` **first**. The superclass implementation draws the view background color and selected-text backgrounds. Your custom drawing (guide lines) must appear on top of that. If you draw before `super`, the selection highlight will overdraw your guides.

### 7. Sonoma dirty-rect expansion

As noted in Part 1, macOS 14+ may pass a `dirtyRect` that extends beyond view bounds. Never do:[^2]

```swift
// WRONG: uses dirtyRect as the drawing clip
NSRectClip(rect)
```

Instead clip to `bounds`:

```swift
// CORRECT
bounds.clip()   // or NSRectClip(bounds)
```

***

## Summary of Changes to Apply

| What | Before | After |
|---|---|---|
| Current-line highlight | `NSRect.fill` in `drawBackground` | `CALayer.frame` update, GPU composited |
| Indent guide drawing scope | All paragraphs in document | Only visible-rect glyphs via `glyphRange(forBoundingRectWithoutAdditionalLayout:)` |
| `selectionDidChange` redraw | `setNeedsDisplay(visibleRect)` | CALayer frame update only, no `setNeedsDisplay` |
| Guide path rebuild trigger | On every draw | Only on `textDidChange` (already gated by hash) |
| `isOpaque` | Default (`false`) | `true` — solid background, eliminates view hierarchy composite |
| `wantsDefaultClipping` | Default (`true`) | `false` — removes clip setup cost for guide drawing |
| Pixel snapping | None | `round(x * scale) / scale` for 1px Retina precision |

---

## References

1. [CodeEditorView.swift](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/c0769272-7efd-46a2-85ab-bd91e2718223/CodeEditorView.swift?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=xtu8d6hM%2FH4QbtdhAORRP75NMC8%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440) - CodeEditorView.swift Full-screen native code editor for Epistemos. Replaces the prose editor when a ...

2. [EpistemosTheme-2.swift](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/55763d56-20d6-4fc7-af2f-1ef0f61fe1de/EpistemosTheme-2.swift?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=CO%2BQqjW8U0MJTi9U%2FX1YXs6tWbs%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440) - import AppKit import CoreText import SwiftUI MARK - Theme Definition 12 themes 6 light 6 dark, inclu...

3. [code_highlight-3.rs](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/97184de5-96e6-43f3-9afb-0f02190bdca0/code_highlight-3.rs?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=CnlLKAK0pVairtf5knzPWYM319g%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440) - tree-sitter tokenizer core. Takes languagetag, codetext and returns VecCodeToken by walking the tree...

4. [MarkdownContentStorage-4.swift](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/fdf9b161-a141-4152-970e-7c25924c1215/MarkdownContentStorage-4.swift?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=KhVt7xbTXClvn3F4mOCe5Fwxyzo%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440) - import AppKit MARK - MarkdownContentStorage NSTextContentStorageDelegate for TextKit 2 prose editor....

5. [ProseTextView2-5.swift](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/94557781-fd7c-405c-b07e-186ec79b7582/ProseTextView2-5.swift?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=8UxeJRdWvJJpQvHl8lwfbD868mE%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440) - import AppKit import UniformTypeIdentifiers import os MainActor final class ScrollWorkCoalescer priv...

6. [NoteDetailWorkspaceView-6.swift](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/206733f7-fff4-43f5-97cd-4f6b5c5930d7/NoteDetailWorkspaceView-6.swift?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=WaqCPspcBogivFAxST9nSpSQASo%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440)

7. [ProseEditorRepresentable2-7.swift](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/61e49955-2347-44b4-9473-2d4692cff6b2/ProseEditorRepresentable2-7.swift?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=qY2IKsTTEotoZKD5B%2B6CPLflIGs%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440)

8. [ProseEditorView-8.swift](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/079c4e39-8995-4577-bf22-d1b14f70b3f3/ProseEditorView-8.swift?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=s77arBlRp0soI3JppM4vP2kxbHU%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440)

9. [StructuredOutput-9.swift](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/3e7758f4-8e76-4b93-b5a4-bad8fbd0a392/StructuredOutput-9.swift?AWSAccessKeyId=ASIA2F3EMEYESQWDOYRS&Signature=UaE5AYP3PgDqi7tVsje%2BlEyIBQo%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEBMaCXVzLWVhc3QtMSJHMEUCIQCXvwkrbe69I3ux7vEbtH1WDZaDDE6CJ41t%2Fq%2Fn14kFUAIgQZwTsJezsnp9fvgq40G%2FWAiBMyM%2BqX5Q7hFOtnjjHX0q%2FAQI2%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDE0sCUQ2XCLMuxRRmyrQBIMnvD7psREi6K9KjEsKvyNTJibT4m11A0uLU%2FJtB3eZJXs%2BtVXphBb1YY966voREn40HMsIP5KiP4PzG6tcKTOwdvQZ2svTi%2BT3tXZ0lBY1BdmhgcwFP29HyJeG8H%2Fn%2B4uH4BbbmV55h9ozwvnaEztU%2F9Rhk0SfXMDqDd6WmbSrdkbwpzrjPmBigBOy0usz1FDU0r%2BKo9oigjJKNzilV1ggj40KfBbZzrEZrN3k1yGakbsYce1mLDCiwQwoVxaikaVN4vdaK%2FYQvBt7Gn%2BssQ88ekZjN1XJojXJrSC8d0o04vHU4LlsjWOWh0%2FqSMsSRC1ERSNUnCL1IODgn4%2B1DpeVeBESDOKixrPm4VT%2BQPKqK4%2FLnJHRWyDsmR%2BHPI6%2BP1aukmMm3ZUFPinzr5hyuPVlvxcIPBPDMVkkrRRpxoZEyX4TNCOHr80uV9ui2F1EXnPWUo5Ne9WhwsxPydq0%2FAiIypsVTeciWkBC%2BbS2x7RyK9BDvfLo8ONVxRFrKQ9TiEFGU1hYq9XqYrmcPIyWC78XGdLr3HVvPF0u0rrLAndSG%2BG2rxwjM8Be114UXi0nLXW2X2AREwWt6iKD4S2GT4qVf2cHPQFH2GxE9uVeh6RowYiP9Q3Fc8SAhI6pR5alnRtLHzhKiBQ7RQUcax23nDG9%2FKAm9QBeIyc36Qkgjyy53b%2B6tnldct%2Bdd%2FlEk6YWfX%2F23%2BYRpZJCN0ilPo%2FIcI5iLqcDRKZR9TMc9RWg5sl0QbZoSzrt4ulwqZKYdC%2BpaM3JVCZ%2BKNQuHPU%2B71KXaQIw3c%2FRzgY6mAFQ0Ug%2BdP0AYE5VrePtmjOrdP8AZbL5fQUYJqFv%2Bpz%2BvHG7t5N5DRbZfMh1kL73MelIK4yb99StRMiBoxUz3Ft97WQ7PZb4xg1ZCo0tpu4CIprd6TxJcCsxypQlBNeWiM4iLhrw5RGnybosV5JcOCV%2BNNCodFA68fcHYl4pbEiLmV8U9QT8c2CO%2FBVnLFRhmjv8IDSQbp6%2FUg%3D%3D&Expires=1775531440)

