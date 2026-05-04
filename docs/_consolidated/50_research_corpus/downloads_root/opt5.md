# Optimize Epistemos Code Editor to Xcode-Grade 120fps Performance

## Executive Summary

Achieving Xcode-grade fluidity in Epistemos requires addressing five compounding bottlenecks simultaneously: a broken `drawBackground` pipeline that repaints over glyphs on macOS Sonoma/Tahoe, an `updateNSView` that re-highlights on every cursor move, a `$text: Binding<String>` that diffs the entire file on each keystroke, a minimap that re-renders on every scroll event, and tree-sitter query execution happening synchronously on the main thread. The CodeEditSourceEditor v0.12 you're using has a significant upstream performance history — upgrading to v0.13.1+ alone gets you CodeEditTextView 0.11.0, which includes an **87% CPU reduction** during text layout editing. This report maps every known bottleneck to a concrete, ordered fix path — from trivial guards to architectural decisions — with the Zed Metal pipeline documented as the ceiling reference.[^1]

***

## Phase 0: Profile First (Required Before Any Optimization)

Before changing a single line, you must identify your actual bottlenecks. The correct tool chain is:

1. **Instruments → Time Profiler**: Set "Separate by Thread," "Invert Call Tree," "Hide System Libraries." Profile while typing 10 characters into a 500-line Swift file, and while scrolling 2000 lines.[^2][^3]
2. **Instruments → Hangs and Hitches**: This instrument specifically flags main-thread stalls that cause hitch frames — the visual stutters at 120fps targets.[^4]
3. **WWDC25 SwiftUI Instrument** (Xcode 26 + macOS 26 only): The new dedicated SwiftUI instrument shows long view body updates, long representable updates, and other SwiftUI-specific hitches with color-coded severity.[^5]

The expected worst offenders, ordered by their confirmed impact in production codebases, are: `updateNSView` re-highlighting, the `$text` binding O(n) diff, and main-thread tree-sitter query execution. All three are fixable in a single session. The minimap and Metal acceleration are subsequent phases.

***

## Phase 1: Fix the Catastrophic Regressions (One Session)

### 1.1 — Guard `updateNSView` Against Theme-Only Triggers

The current `updateNSView` re-highlights the entire document on **every SwiftUI state change** — including cursor position updates (`cursorLine`, `cursorCol`). Each call to `highlightSyntax(theme:)` triggers `beginEditing/endEditing` which invalidates the entire layout. At 120fps, cursor movement generates up to 120 layout invalidations per second.

```swift
// BROKEN — fires on every cursor move
func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.textView?.highlightSyntax(theme: theme)
}

// FIXED — only fires when theme actually changes
func updateNSView(_ nsView: NSView, context: Context) {
    guard context.coordinator.lastAppliedTheme != theme else { return }
    context.coordinator.lastAppliedTheme = theme
    context.coordinator.textView?.highlightSyntax(theme: theme)
}
// Add to Coordinator:
var lastAppliedTheme: EpistemosTheme?
```

This single guard converts the worst-case 120 layout invalidations/second into approximately 1 (only on theme switch).

### 1.2 — Bounds-Clamp `drawBackground(in:)` for macOS Sonoma/Tahoe

Starting macOS 14 Sonoma, `NSView.clipsToBounds` defaults to `false`. This means `drawBackground(in:)` receives a `rect` that extends beyond the view's `bounds`, causing `super.drawBackground(in:)` to paint the background color over glyphs — making text invisible. The identical bug was confirmed in the Scintilla editor project.

```swift
override func drawBackground(in rect: NSRect) {
    // macOS 14+ fix: clipsToBounds = false means rect can exceed bounds.
    // Clamp to prevent overpainting glyphs.
    let safeRect = bounds.intersection(rect)
    guard !safeRect.isNull else { return }
    super.drawBackground(in: safeRect)
    // All subsequent drawing (indent guides, line highlight) must use safeRect
}
```

### 1.3 — Upgrade to CodeEditSourceEditor v0.13.1+

CodeEditSourceEditor v0.13.1 bumps CodeEditTextView to version 0.11.0, which includes an **87% reduction in CPU time during text layout editing** — the most impactful single change available without architectural work. The upstream release chain is:[^1]

| CESE Version | Key Changes |
|---|---|
| v0.8.0 | "TreeSitter Performance And Stability" — major tree-sitter stability overhaul[^6] |
| v0.9.0 | TreeSitterClient Highlight Responsiveness (#267); Invalidate Correct Edited Range (#279)[^6] |
| v0.10.0 | Highlighter Provider Diffing (#291) — avoids full rehighlight when provider unchanged[^6] |
| v0.12.0 | New Minimap (#302); Smarter Default Highlight Provider Management (#310)[^6] |
| v0.13.1 | **CodeEditTextView 0.11.0 — 87% CPU reduction in layout**[^1][^6] |
| v0.14.2 (latest) | Further upstream improvements (July 2025)[^7] |

In your `Package.swift` or Xcode SPM panel, update the version constraint:
```swift
.package(url: "https://github.com/CodeEditApp/CodeEditSourceEditor", from: "0.13.1")
```

***

## Phase 2: Eliminate the `$text: Binding<String>` O(n) Bottleneck

### The Problem

SwiftUI's `Binding<String>` compares the full string on every keystroke to decide whether to trigger a re-render. For a 10,000-character file, every keystroke produces an O(n) string comparison. Worse, custom `Binding(get:set:)` closures — which SwiftUI cannot optimize because it can't infer equality — cause the view body to re-evaluate unconditionally on every change, even if the value didn't change.[^8]

### Fix: Share `NSTextStorage` Between the Model and the View

The correct pattern is to initialize the `NSTextView` (or CodeEditTextView's `TextView`) with a shared `NSTextStorage` that is also your document's backing store. The view then updates itself via `NSTextStorageDelegate`, never through a SwiftUI binding:

```swift
// Document model holds the textStorage as source of truth
final class DocumentModel: ObservableObject {
    let textStorage = NSTextStorage(string: "")
    // NSTextStorage is NOT Observable, so publish changes via delegate
}

// In NSViewRepresentable.makeNSView: hand off the shared storage
func makeNSView(context: Context) -> NSScrollView {
    let textView = textStorage // pass reference into textView initializer
    // For CodeEditTextView: textView.replaceCharacters uses NSRange, not full string replacement
}
```

Using `NSTextStorage.replaceCharacters(in:with:)` instead of replacing the entire string also fixes the cursor-jumping-to-end bug — the text view knows the exact changed range and adjusts the cursor correctly.[^9]

**Critical caveat**: If you subclass `NSTextStorage` in Swift, the `attributesAtIndex:effectiveRange:` call is **nearly 3x slower** than Objective-C due to Swift→ObjC bridging of the `NSDictionary` return value. Either:[^10][^11]
- Use stock `NSTextStorage` without subclassing, or
- Write the subclass in Objective-C (expose to Swift via a bridging header)

***

## Phase 3: Background Tree-Sitter Threading

### How `TreeSitterClient` Currently Works in CESE

`TreeSitterClient` (via [ChimeHQ/Neon](https://github.com/ChimeHQ/Neon)) is a hybrid sync/async interface. Small documents are processed synchronously on the main thread (targeting zero-flicker keystrokes). Large documents automatically push work to a background thread via the `RangeState` module — but only when correctly configured.[^12]

The key verification: in `TextViewController.swift`, the `TreeSitterClient.Configuration` must provide a `contentSnapshotProvider` that produces an immutable copy of the text for background processing:

```swift
let clientConfig = TreeSitterClient.Configuration(
    contentSnapshotProvider: { [weak textView] length in
        // Return an IMMUTABLE snapshot — this runs on a background thread
        // Do NOT return a live reference to the mutable textStorage
        return .init(string: textView?.string ?? "")
    },
    // ...
)
```

If `contentSnapshotProvider` returns a live mutable reference, background processing is unsafe and Neon falls back to main-thread synchronous execution.[^12]

### Incremental Parsing: Ensure `tree.edit()` Is Called

Tree-sitter is an **incremental** parser by design — it only re-parses affected nodes when given edit information. As of 2026, tree-sitter 0.19.0 can parse a 10,000-line C file in under 100ms on first parse, with incremental edits significantly faster.[^13][^14]

The CESE fix in v0.9.0 (#279 "Invalidate Correct Edited Range") addresses a prior bug where the full file was being re-highlighted on every keystroke. Verify your upgraded version calls `client.willChangeContent(in:)` and `client.didChangeContent(in:delta:)` with the correct edit range, not with the full-document range.[^6]

### Three-Phase Highlighting (Flicker-Free Architecture)

Neon's `ThreePhaseTextSystemStyler` provides flicker-free highlighting by layering sources:[^12]

1. **Phase 1 (sync, instant)**: Pattern-matching fallback (e.g., Lowlight or your Rust FFI tokenizer) — applied immediately on keystroke, zero latency.
2. **Phase 2 (async, low-latency)**: Tree-sitter — replaces Phase 1 tokens as results arrive.
3. **Phase 3 (async, high-latency)**: LSP semantic tokens — augments tree-sitter with type-aware coloring.

Connecting your existing `graph-engine/src/code_highlight.rs` Rust FFI as Phase 1 provides instant feedback on every keystroke with zero main-thread tree-sitter cost.

***

## Phase 4: Minimap Rendering Optimization

### What v0.12 Ships

The CESE v0.12 minimap (PR #302) renders syntax-highlighted token colors in the minimap via PR #308 ("Highlighter Highlights Text in Minimap"). The underlying `MinimapView` is a separate view that shares the same layout information as the main editor.[^6]

### CALayer Caching for Zero-CPU Scroll

The performance goal for the minimap is that **scrolling the main document must not cause the minimap to CPU-redraw**. The correct architecture:

```swift
class MinimapView: NSView {
    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.drawsAsynchronously = true
        return layer
    }

    override var layerContentsRedrawPolicy: NSView.LayerContentsRedrawPolicy {
        // Critical: only redraw on explicit setNeedsDisplay, NOT on geometry changes
        return .onSetNeedsDisplay
    }
}
```

With `.onSetNeedsDisplay`, the minimap's CALayer contents are composited by the GPU on every scroll frame without any CPU redraw. The minimap only invokes `setNeedsDisplay` when the document content actually changes (text edit), not when the viewport scrolls.[^15]

For the viewport indicator rectangle (the "current position" highlight in the minimap), use a separate `CALayer` that only updates its `position` property — Core Animation will interpolate the movement at the display's full refresh rate without any CPU involvement.

### Async Rendering for the Minimap Background

For very large files, pre-render the minimap to an offscreen `CGImage` on a background `DispatchQueue` and copy it to the layer's `contents`:

```swift
func renderMinimapAsync(for document: String, theme: EditorTheme) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let image = self?.renderMinimapImage(document: document, theme: theme)
        DispatchQueue.main.async {
            self?.layer?.contents = image
        }
    }
}
```

This completely removes minimap rendering from the main thread render loop.

***

## Phase 5: Metal Acceleration for the Gutter and Minimap (Advanced)

### The Zed Reference Architecture

Zed's GPUI pipeline achieves "GPU-bandwidth-bound" text rendering:[^16]

1. **Shaping**: CoreText converts characters → glyphs + positions. Results are cached per text-font pair. Only changed text is reshaped between frames.[^16]
2. **Rasterization**: CoreText rasterizes each glyph to an **alpha-only** bitmap (opacity channel only). 16 sub-pixel variants per glyph are stored for sub-pixel antialiasing accuracy.[^16]
3. **Atlas packing**: Rasterized glyphs are packed into a long-lived GPU texture atlas using the `etagere` bin-packing algorithm.[^17][^16]
4. **Draw**: A single instanced Metal draw call submits all glyphs: `{target_position, atlas_position, size, float4 color}`. The fragment shader multiplies the alpha with the color — syntax highlighting is just a `float4` per glyph instance, no extra texture copies.[^16]

The key insight: by storing only the alpha channel, every syntax color is free — you don't need a separate atlas entry per color. The CPU only touches glyphs whose text changed. Everything else is a GPU memory bandwidth operation.[^16]

### Feasibility for Epistemos

A full Metal text pipeline is 3–6 months of work. However, **partial Metal acceleration** for the gutter and minimap is achievable in 1–2 sessions:

**Gutter (line numbers)**: Line numbers change only when the document is edited or scrolled to new content. Render the gutter to a `CAMetalLayer` using a simple Metal shader that blits pre-rendered glyph bitmaps. The setup requires `wantsLayer = true` and overriding `makeBackingLayer()` to return `CAMetalLayer`:[^18][^19]

```swift
override func makeBackingLayer() -> CALayer {
    let metalLayer = CAMetalLayer()
    metalLayer.device = MTLCreateSystemDefaultDevice()
    metalLayer.pixelFormat = .bgra8Unorm
    metalLayer.framebufferOnly = true
    return metalLayer
}
```

**Minimap**: Render the minimap entirely via Metal using the same glyph atlas approach as Zed, but scoped to only the minimap surface. At 2pt font, most glyphs are 1–2 pixels wide — the entire atlas fits in a tiny texture.

### Why CoreText for Shaping (Not Pure Metal)

Both Zed and Nova (Panic's code editor) use CoreText exclusively for shaping and rasterization, delegating only compositing to the GPU. This ensures text appearance is identical to native macOS applications (same subpixel antialiasing, same ligature rendering, same font metrics). Bypassing CoreText for rasterization is the fastest path to text that looks "wrong" compared to Xcode.[^16]

***

## Phase 6: Profiling-Guided Validation

After each phase, re-run Instruments to confirm regressions are resolved. The following table maps each bottleneck to its expected Instruments symptom and the fix:

| Bottleneck | Instruments Symptom | Fix | Phase |
|---|---|---|---|
| `updateNSView` re-highlighting | `highlightSyntax` in every Time Profiler sample during cursor move | Guard with `lastAppliedTheme` check | 1.1 |
| `drawBackground` overpaint | Text invisible / flicker on Tahoe | Bounds-clamp `safeRect` | 1.2 |
| `$text` O(n) string diff | `String.==` in every keystroke sample | Shared `NSTextStorage` | 2 |
| Main-thread tree-sitter | `TSParser_parse` on main thread in large files | Verify `contentSnapshotProvider` returns immutable copy | 3 |
| Minimap CPU redraw on scroll | `MinimapView.draw` in every scroll frame | `.onSetNeedsDisplay` + async render | 4 |
| SwiftUI diffing overhead | `SwiftUI.ViewGraph.updateOutputs` in every sample | Replace `Binding<String>` with `NSTextStorage` coordination | 2 |

For 120fps validation, use the **Hangs and Hitches** instrument. Any hitch > 8.3ms drops a frame on a ProMotion display. After Phase 1–3, expect hitches to drop from ~16ms (60fps stutter) to ~3ms (well within 120fps budget) for files under 50,000 lines.[^20][^4]

***

## Architecture Decision Matrix

The following table summarizes the three realistic paths to Xcode-grade performance, ranked by effort vs. outcome:

| Path | Effort | 120fps Guarantee | Minimap Quality | Dependency Risk |
|---|---|---|---|---|
| **Fix existing CESE v0.13.1** (Phases 1–4) | 1–3 sessions | High (after fixes) | Good (CoreText minimap) | Low (upstream maintained) |
| **Switch to CodeEditorView (mchakravarty)** | 1 session | High (TextKit 2 viewport) | Excellent (MARK: headers) | Medium (pre-1.0) |
| **Custom EpistemosTextView** (CoreText direct) | 5–8 sessions | Guaranteed | Custom-built | None (you own it) |
| **Metal GPU pipeline** (Zed-style) | 3–6 months | Absolute ceiling | GPU-rendered | High (you own it) |

**Recommended path for Epistemos**: Execute Phases 1–3 immediately (1 session). These are non-architectural fixes that unlock the existing stack's full performance. Execute Phase 4 (minimap CALayer caching) in session 2. Re-profile after each phase. If tree-sitter still shows as the dominant bottleneck after Phase 3, consider the custom `EpistemosTextView` using CodeEditTextView's CoreText engine directly — it's already battle-tested and loads million-line files in milliseconds.[^21]

***

## Rust FFI Integration Opportunity

Your existing `graph-engine/src/code_highlight.rs` Rust FFI tree-sitter tokenizer can serve as **Neon Phase 1** (the synchronous fallback highlighter). Since it runs on a background thread via Rust FFI, it can provide instant syntax coloring on keystroke without blocking the main thread. Connect it via the `HybridSyncAsyncValueProvider` protocol in Neon's `RangeState` module:

```swift
let rustProvider = HybridSyncAsyncValueProvider<[Token]>(
    syncValue: { range in
        // Call your Rust FFI synchronously for small ranges (< 1000 chars)
        CodeSyntaxHighlighter.tokenize(range: range)
    },
    asyncValue: { range in
        // For large ranges, use async Rust FFI
        await CodeSyntaxHighlighter.tokenizeAsync(range: range)
    }
)
```

This creates a three-phase stack where Phase 1 uses your existing Rust tokenizer, Phase 2 uses CESE's tree-sitter, and Phase 3 is reserved for future LSP semantic tokens.[^12]

***

## ProMotion-Specific Recommendations

ProMotion displays refresh at up to 120Hz (8.33ms budget, effectively ~5ms for app work after system overhead). The system handles frame pacing automatically on macOS — there is no Info.plist key required for macOS ProMotion unlike iOS. The key requirements are:[^22][^20]

- **Main thread must be clear during scroll**: All tree-sitter parsing, all minimap rendering, and all text attribute application must happen off the main thread.
- **Use `CAAnimation.preferredFrameRateRange`** (not `preferredFramesPerSecond`) for any scroll-linked animations.[^23]
- **Don't set `shouldRasterize = true` on multiple sublayers**: Only set it on the parent container layer. Multiple rasterized sublayers compound GPU overhead.[^24]
- **`NSScrollView` clip view**: Ensure `contentView.wantsLayer = true` is set so the scroll view uses GPU compositing rather than CPU blitting.[^25]

The NSScrollView's scroll animation is handled by Core Animation and runs entirely on the render server — no app CPU involvement — as long as the main thread is not blocked during scroll. Achieving this is the complete goal of Phases 1–4.

---

## References

1. [Releases · CodeEditApp/CodeEditTextView - GitHub](https://github.com/CodeEditApp/CodeEditTextView/releases) - This release contains a huge performance improvement, about an 87% reduction in CPU time when text i...

2. [5 Simple Steps to Find Slow Code Using Xcode Time Profiler](https://swiftsenpai.com/xcode/using-time-profiler/) - It might feel overwhelming to use Xcode Time Profiler for the first time. Here're 5 simple steps to ...

3. [Xcode Instruments usage to improve app performance - SwiftLee](https://www.avanderlee.com/debugging/xcode-instruments-time-profiler/) - The Time Profiler can be used to dive into a certain flow, improve a piece of code, and validate rig...

4. [Demystify and eliminate hitches in the render phase - Tech Talks](https://developer.apple.com/videos/play/tech-talks/10857/) - Discover how to eliminate offscreen passes and leverage Xcode optimization opportunities in order to...

5. [Optimize SwiftUI performance with Instruments - WWDC25 - Videos](https://developer.apple.com/videos/play/wwdc2025/306/) - Discover the new SwiftUI instrument. We'll cover how SwiftUI updates views, how changes in your app'...

6. [Releases · CodeEditApp/CodeEditSourceEditor - GitHub](https://github.com/CodeEditApp/CodeEditSourceEditor/releases) - This release also bumps the required CodeEditTextView version, which comes with lots of good perform...

7. [CodeEditSourceEditor - Swift Package Index](https://swiftpackageindex.com/CodeEditApp/CodeEditSourceEditor) - An Xcode-inspired code editor view written in Swift powered by tree-sitter for CodeEdit. Features in...

8. [TIL: Avoid using Binding(get: set:) in SwiftUi as it causes the views to ...](https://www.reddit.com/r/SwiftUI/comments/1mollfi/til_avoid_using_bindingget_set_in_swiftui_as_it/) - TIL: Avoid using Binding(get: set:) in SwiftUi as it causes the views to be re-calculated as SwiftUI...

9. [Circular updates with @Observable and UIViewRepresentable](https://www.reddit.com/r/SwiftUI/comments/1amjy71/circular_updates_with_observable_and/) - NSTextStorage isn't observable, so you'll need to manually trigger the objectWillChange (it might al...

10. [Swift Subclass of NSTextStorage Is Slow Because of Swift Bridging](https://mjtsai.com/blog/2019/02/22/swift-subclass-of-nstextstorage-is-slow-because-of-swift-bridging/) - Calling -[NSTextStorage attributesAtIndex:effectiveRange:] is nearly 3 times as slow for TextStorage...

11. [Resolving Slow Performance of NSTextStorage - The Cope](https://www.thecope.net/2019/09/15/resolving-slow-performance.html) - The proper way to achieve this is by subclassing NSTextStorage of a UITextView. There's lot's of onl...

12. [GitHub - ChimeHQ/Neon: A Swift library for efficient, flexible content ...](https://github.com/ChimeHQ/Neon) - Tree-sitter uses separate compiled parsers for each language. There are a variety of ways to use tre...

13. [Incremental Parsing Using Tree-sitter - Federico Tomassetti](https://tomassetti.me/incremental-parsing-using-tree-sitter/) - Tree-sitter is an incremental parsing library, which means that it is designed to efficiently update...

14. [Incremental Parsing with Tree-sitter: Enhancing Code Analysis ...](https://dasroot.net/posts/2026/02/incremental-parsing-tree-sitter-code-analysis/) - Tree-sitter is designed as an incremental parsing system that efficiently maintains and updates synt...

15. [Setting Up Layer Objects - Apple Developer](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/SettingUpLayerObjects/SettingUpLayerObjects.html) - CATransformLayer. Used to render a true 3D layer hierarchy, rather than the flattened layer hierarch...

16. [Leveraging Rust and the GPU to render user interfaces at 120 FPS](https://zed.dev/blog/videogame) - A screenshot of a glyph atlas produced by Zed. Just like with text shaping, we let the operating sys...

17. [GPUI: Zed's 120fps GPU-Accelerated UI | Research - Kaelan.fyi](https://kaelan.fyi/research/gpui-zed-renderer/) - GPUI is Zed's in-house GPU-accelerated UI framework. It renders at 120fps using techniques borrowed ...

18. [How to use CAMetalLayer with an NSView? - Stack Overflow](https://stackoverflow.com/questions/59112245/how-to-use-cametallayer-with-an-nsview) - In AppKit, you make the view layer backed by setting the view's wantsLayer property. The app explici...

19. [Creating a custom Metal view | Apple Developer Documentation](https://developer.apple.com/documentation/Metal/creating-a-custom-metal-view) - This sample app demonstrates how to create a simple Metal view derived directly from an NSView or UI...

20. [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps) - To achieve the maximum 120Hz refresh rate, the main thread has to execute all layout computation and...

21. [GitHub - CodeEditApp/CodeEditTextView: A text editor specialized ...](https://github.com/CodeEditApp/CodeEditTextView) - A text editor specialized for displaying and editing code documents. Features include basic text edi...

22. [Optimize for variable refresh rate displays - WWDC21 - Videos](https://developer.apple.com/videos/play/wwdc2021/10147/) - Learn techniques for pacing full-screen game updates on Adaptive Sync displays in macOS, and find ou...

23. [Enabling high refresh rate : r/SwiftUI - Reddit](https://www.reddit.com/r/SwiftUI/comments/1hylt9f/enabling_high_refresh_rate/) - After profiling, I realized that SwiftUI is never going above 60 fps, even if i use a CADisplayLink ...

24. [Animation and Scrolling Performance Seriously Lagging Using ...](https://stackoverflow.com/questions/36378427/animation-and-scrolling-performance-seriously-lagging-using-cashapelayers-for-ma) - Any animations that I perform using UIView.animateWithDuration get EXTREMELY choppy, and the same go...

25. [Disable redrawing of CALayer contents when moved (iphone)](https://stackoverflow.com/questions/1360381/disable-redrawing-of-calayer-contents-when-moved-iphone) - The layers should not be redrawn, but they will be composited using the GPU. Try using the Sampler a...

