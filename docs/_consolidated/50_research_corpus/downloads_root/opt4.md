# Epistemos Code Editor — 120fps Optimization Playbook

## Executive Summary

Three parallel work streams will take Epistemos from its current throttled, stuttering state to Xcode-grade 120fps ProMotion fluidity: (1) **frame-by-frame profiling** with Instruments to find the true bottlenecks before touching code, (2) **replacing the `$text: Binding<String>` diff** with an `NSTextStorage`-based incremental delta pipeline to eliminate O(n) string comparisons on every keystroke, and (3) **moving all Tree-sitter parse work** onto dedicated background `Task`s with an isolated actor to keep the main thread free for drawing. Each stream is independent and can be done in parallel. A fourth cross-cutting fix — keeping the ProMotion display locked to 120fps via `CADisplayLink` keep-alive rendering — is required regardless of the other three, because macOS will silently downclock the display if no new frames are submitted.

***

## Stream 1 — Frame-by-Frame Profiling with Instruments

### Why profiling must come first

Every optimization session that skips profiling risks fixing the wrong thing. The three remaining bottlenecks in CodeEditSourceEditor v0.12 could be any combination of: Tree-sitter query execution on the main thread, CoreText line-shaping cache misses, minimap re-rendering on every scroll event, SwiftUI `EquatableView` re-evaluation of the full file string, or offscreen render passes caused by layer shadows without explicit `shadowPath`. Instruments will show exactly which of these dominates before any code changes are made.

### Setting up the Animation Hitches template

The **Animation Hitches** template is the right tool, not the bare Time Profiler alone. It combines the Render Loop trace, Core Animation commit phase, and Time Profiler into one recording. To set it up:[^1][^2]

1. `Product → Profile (⌘I)` in Xcode to build a Release-scheme profile build.
2. In the Instruments chooser select **Animation Hitches** (not "Time Profiler").
3. In the Recording Settings toolbar, change recording mode to **Immediate** (not Deferred) — Deferred mode has a known bug that prevents the hitches template from starting on some configurations.[^3]
4. Start recording, open a large Swift file (≥ 2000 lines) in Epistemos, type rapidly for 10 seconds, scroll for 10 seconds, stop recording.

### Reading the trace

The Render Loop timeline shows five phases per frame: Event → Commit → Render Prepare → Render Execute → Display. The key metric is **hitch time ratio** (milliseconds of hitch per second of interaction):[^1]

| Hitch time ratio | User experience |
|---|---|
| 0–5 ms/s | Good — essentially unnoticeable |
| 5–10 ms/s | Noticeable — should investigate |
| > 10 ms/s | Severe — must fix immediately |

Hitches in the **Commit phase** mean the app's main thread is doing too much work before handing the layer tree to the render server — this is where Tree-sitter on the main thread, full-file String comparison, and `highlightSyntax(theme:)` firing on every cursor move will appear. Hitches in the **Render Execute phase** (GPU side) point to offscreen render passes, unshadowed `CAShapeLayer` paths, or layer overdraw from the minimap.[^4][^5][^6]

### Specific call-tree symbols to look for

With Time Profiler running alongside Animation Hitches, filter the call tree by "Main Thread" only and look for:

- `TreeSitterClient.highlight(in:provider:mode:)` — if this appears synchronously on the main thread during keystrokes, it confirms parsing is blocking drawing.
- `NSString.isEqual:` or `Swift.String.==` — will show as O(n) work proportional to file size on every `updateNSView` call.
- `NSTextView.drawBackground(in:)` — if it appears on scroll, the Sonoma clipsToBounds bug is still active.[^7]
- `-[CALayer setNeedsDisplay]` cascading from the minimap — indicates the minimap is invalidating on every scroll frame.
- `CATransaction.commit` taking > 4ms — the budget per frame at 120fps is 8.33ms total; commit alone should take under 2ms.

### Eliminating the known background-thread hitches first

Before profiling, apply two zero-risk patches that are confirmed commit-hitch sources from prior research:

**Patch 1 — Clamp `drawBackground(in:)` to bounds** (Sonoma/Tahoe regression):
```swift
// CodeTextView.swift — in drawBackground(in:) override
override func drawBackground(in rect: NSRect) {
    // macOS 14+: clipsToBounds defaults false, rect may exceed bounds
    let clampedRect = bounds.intersection(rect)
    guard !clampedRect.isNull else { return }
    super.drawBackground(in: clampedRect)
    // draw indent guides using clampedRect only
}
```
This is the same fix applied in Scintilla Bug #2402, which had the identical invisible-text symptom.[^7]

**Patch 2 — Guard `updateNSView` against redundant re-highlights**:
```swift
// CodeEditorRepresentable — updateNSView
func updateNSView(_ nsView: NSView, context: Context) {
    guard context.coordinator.lastAppliedTheme != theme else { return }
    context.coordinator.lastAppliedTheme = theme
    context.coordinator.textView?.highlightSyntax(theme: theme)
}
```
Without this guard, every cursor-position change (which updates `cursorLine`/`cursorCol` `@State`) triggers a full `beginEditing`/`endEditing` cycle on `NSTextStorage`, invalidating the layout manager for the entire document.[^7]

***

## Stream 2 — Replace `$text` Binding with `NSTextStorage` Incremental Updates

### The O(n) string diff problem

`SourceEditor` takes a `Binding<String>` and on every SwiftUI update cycle compares the new value with the stored one using Swift's `String.==` operator. Swift string equality performs Unicode canonical normalization before byte comparison — this is correct behavior (it handles composed/decomposed forms like `é` vs `e` + combining accent) but it means every single keystroke diffing a 50,000-character file walks all 50,000 characters. On a 120fps timeline with an 8.33ms budget, this alone can consume 3–5ms for a typical 1,000-line file.[^8]

The right fix is to **never produce a whole-file String from a keystroke**. Instead, propagate only the *delta* — the NSRange of the changed characters and the replacement string — directly to `NSTextStorage.replaceCharacters(in:with:)`.

### NSTextStorage incremental pipeline

`NSTextStorage` has exactly the API needed: `replaceCharacters(in range: NSRange, with str: String)` processes only the changed region, calls `edited(.editedCharacters, range:, changeInLength:)` to notify the layout manager, and the layout manager re-lays-out only the invalidated lines. The delegate method `textStorage(_:didProcessEditing:range:changeInLength:)` fires *after* the edit with the exact changed NSRange — this is the hook for telling Tree-sitter precisely what changed.[^9][^10]

The subclass skeleton (adapted from Adam Preble's canonical Swift reference):[^11]

```swift
// EpistemosTextStorage.swift
final class EpistemosTextStorage: NSTextStorage {
    private let backingStore = NSMutableAttributedString()

    // Required primitives
    override var string: String { backingStore.string }

    override func attributes(at location: Int,
                             effectiveRange range: NSRangePointer?)
    -> [NSAttributedString.Key: Any] {
        backingStore.attributes(at: location, effectiveRange: range)
    }

    // The only method that mutates text — all edits flow through here
    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range,
               changeInLength: (str as NSString).length - range.length)
        endEditing()
        // Tree-sitter edit notification fires here via NSTextStorageDelegate
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?,
                                range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
}
```

> ⚠️ **Swift / Objective-C bridge pitfall**: `NSTextStorage.string` is bridged to Swift as `String`, but the contract requires returning the *backing NSMutableString directly* — not a copy. If you return `backingStore.string` (a Swift String copy), the layout manager receives a snapshot that goes stale. The correct pattern is to implement the Objective-C `string` getter to return `backingStore.mutableString` by swizzling or using `@objc var backingNSString: NSString` with `method_setImplementation`. Alternatively, write the subclass in Objective-C to avoid the bridging issue entirely — this is the approach used by TextStory's `TSYTextStorage`.[^12][^11]

### Wiring the delta into SourceEditor

`CodeEditSourceEditor`'s `TextViewController` already owns an `NSTextView` whose `textStorage` property can be replaced at init time via `layoutManager?.replaceTextStorage(_:)`. After replacement, all keystrokes flow through `EpistemosTextStorage.replaceCharacters(in:with:)` instead of the full-file swap. The SwiftUI `Binding<String>` can be kept for initial load and final save, but should be guarded with an O(1) NSString length pre-check before the full equality comparison:[^13]

```swift
// In TextViewCoordinator.textDidChange(_:)
func textDidChange(_ notification: Notification) {
    let newString = textView.string
    // O(1) length guard before O(n) equality
    guard (newString as NSString).length != (lastKnownString as NSString).length
        || newString != lastKnownString else { return }
    lastKnownString = newString
    textBinding.wrappedValue = newString
}
```

### Preserving cursor position

A common pitfall when calling `replaceCharacters(in:with:)` from outside `NSTextView`'s normal input path is that the cursor jumps to the end. The solution, per Christian Tietze's canonical analysis, is to *never apply styling inside `processEditing()`*. Call `highlightSyntax` from the `NSTextStorageDelegate.textStorage(_:didProcessEditing:range:changeInLength:)` callback instead, which fires after the layout pass, not during it.[^14]

***

## Stream 3 — Tree-sitter Parsing on Dedicated Background Tasks

### Current threading situation in CodeEditSourceEditor v0.12

`TreeSitterClient` (from ChimeHQ/Neon) is designed as a hybrid sync/async system[page:ChimeHQ/Neon]. For small edits it runs synchronously to achieve flicker-free highlighting on keystrokes. For large documents or large edits it switches to background processing. The key question is whether `CodeEditSourceEditor`'s `TextViewController` is actually invoking the async path — or whether it always calls the `.required` mode that forces synchronous completion regardless of document size.[^15]

If it calls `client.highlights(in:provider:mode: .required)`, all Tree-sitter work blocks the main thread. The correct mode for large documents is `.required` only for the visible viewport, with `.optional` (async, returns cached results if parse is in progress) for off-screen ranges.

### Swift 6 actor isolation pattern

In Swift 6, the correct pattern for compute-heavy background work is an isolated actor, not `Task.detached`:[^16][^17]

```swift
// TreeSitterParseActor.swift
actor TreeSitterParseActor {
    private let client: TreeSitterClient

    init(client: TreeSitterClient) {
        self.client = client
    }

    // This function always runs off the main actor
    func highlights(in range: NSRange,
                    provider: @escaping PredictateTextProvider)
    async throws -> [SyntaxHighlight] {
        // Tree-sitter parse happens here, off main thread
        return try client.highlights(in: range,
                                     provider: provider,
                                     mode: .optional) ?? []
    }

    func applyEdit(_ edit: InputEdit) {
        try? client.willChange(in: edit.range)
    }
}
```

The `actor` keyword guarantees serial execution of parse jobs (no data races on the C tree-sitter parser, which is not thread-safe) while freeing the main thread entirely. Callers `await` the result and apply highlight attributes back on `@MainActor`:

```swift
// In TextViewCoordinator, called from textStorage didProcessEditing
@MainActor
func rehighlightChangedRange(_ range: NSRange) {
    Task {
        // Moves off main thread into actor
        let highlights = try? await parseActor.highlights(
            in: visibleRange,
            provider: textView.string.predicateTextProvider
        )
        // Back on main thread to apply attributes
        guard let highlights else { return }
        applyHighlightAttributes(highlights, to: textStorage)
    }
}
```

> In Swift 6.2+, mark the function `@concurrent` to guarantee it runs on the global executor even if the caller is `@MainActor`. For earlier Swift 6.0/6.1, `nonisolated` on an `async` function achieves the same result — the function runs off the caller's actor.[^17][^16]

### Incremental parse: only re-parse the changed subtree

Tree-sitter's core value proposition is incremental parsing — given an `InputEdit` (startByte, oldEndByte, newEndByte, plus point equivalents), it re-parses only the nodes whose byte ranges overlap the edit. `TreeSitterClient.willChange(in range: NSRange)` is the entry point that computes and applies this edit to the stored parse tree. This must be called *before* `replaceCharacters(in:with:)` executes on `NSTextStorage` — the old byte offsets are needed to build the `InputEdit`. The correct call order in `EpistemosTextStorage` is:[^18]

```swift
override func replaceCharacters(in range: NSRange, with str: String) {
    // 1. Notify tree-sitter of the impending edit (uses OLD offsets)
    parseActor.applyEdit(InputEdit(range: range, replacement: str))
    // 2. Mutate backing store
    beginEditing()
    backingStore.replaceCharacters(in: range, with: str)
    edited(.editedCharacters, range: range,
           changeInLength: (str as NSString).length - range.length)
    endEditing()
    // 3. Re-highlight (now on background, uses NEW tree)
}
```

### Three-phase highlighting for zero flicker

Neon's `ThreePhaseRangeValidator` supports a three-pass approach to eliminate the "highlight flash" that happens while Tree-sitter parses asynchronously:[^15]

| Phase | Source | Latency | Quality |
|---|---|---|---|
| Fallback | Pattern-matching (e.g., Lowlight) | < 1ms, synchronous | OK |
| Primary | Tree-sitter async | 5–50ms | Good |
| Secondary | LSP semantic tokens | 100–500ms | Best |

On every keystroke, the fallback pass fires immediately (no flicker), then Tree-sitter replaces it when the async parse completes, then LSP augments it when the language server responds. The visible result is that highlighting is always present and never goes blank mid-edit.[^15]

***

## Stream 4 (Cross-Cutting) — ProMotion Display Keep-Alive

This is the most impactful single fix and must be applied regardless of the other three streams. macOS will **downclock a ProMotion display to 60fps or lower** if the app stops submitting new frames[page:zed.dev/blog/120fps]. Even if render time per frame is under 4ms (well within the 8.33ms budget), a perfectly fast renderer will still drop to 60fps during typing pauses.[^19]

Zed's solution: use `CADisplayLink` to submit keep-alive render frames for 1 second after the last input event. This prevents the display from downclocking while the user is actively editing, but allows it to downclock when the window is idle (saving battery).[^19]

```swift
// In the NSView or NSViewController hosting the text view
private var displayLink: CADisplayLink?
private var lastInputTime: TimeInterval = 0
private let keepAliveWindow: TimeInterval = 1.0  // seconds

func startDisplayLink() {
    let link = CADisplayLink(target: self,
                             selector: #selector(displayLinkFired))
    link.add(to: .main, forMode: .common)
    displayLink = link
}

@objc func displayLinkFired(_ link: CADisplayLink) {
    let now = link.timestamp
    if now - lastInputTime < keepAliveWindow {
        // Trigger a minimal redraw to keep the display at 120fps
        layer?.setNeedsDisplay()
    }
}

func userDidType() {
    lastInputTime = CACurrentMediaTime()
}
```

On M2+ Macs running in Metal **direct mode** (the default when not full-screen), use `wait_until_scheduled` rather than `wait_until_completed` when presenting Metal command buffers — `wait_until_completed` blocks the main thread for the full GPU scanout time in direct mode, not just until the buffer is queued. This was the root cause of Zed's M2 janky scrolling issue that only appeared on their 120fps machines.[^19]

| API | Behavior in composited mode | Behavior in direct mode |
|---|---|---|
| `waitUntilCompleted()` | Returns when pixels hit intermediate buffer (~fast) | Returns when pixels hit display framebuffer (~slow, blocks for scanout) |
| `waitUntilScheduled()` | Returns when GPU work is queued | Returns when GPU work is queued (~fast) |

Use triple-buffering for instance/vertex buffers — switching from `wait_until_completed` to `wait_until_scheduled` without triple-buffering creates a race condition where the GPU reads from a buffer the CPU is simultaneously writing.[^19]

***

## Minimap Rendering Optimization

The minimap is a separate rendering budget drain because it currently redraws on every scroll. The fix is to treat it as a **cached `CALayer` whose `contents` is a pre-rendered `CGImage`**, only regenerated on text edits, not on scroll events.

```swift
// MinimapLayer.swift
final class MinimapLayer: CALayer {
    private var cachedImage: CGImage?
    private var cachedContentVersion: Int = -1

    func updateIfNeeded(textStorage: NSTextStorage, version: Int) {
        guard version != cachedContentVersion else { return }
        cachedContentVersion = version
        // Render off main thread via async
        Task.detached(priority: .utility) { [weak self] in
            let image = self?.renderMinimap(textStorage)
            await MainActor.run {
                self?.contents = image
                self?.cachedImage = image
            }
        }
    }

    private func renderMinimap(_ storage: NSTextStorage) -> CGImage? {
        // Draw at 2pt font size using NSAttributedString.draw(in:)
        // to get actual character shapes (not pixel rects)
        let scale = minimapWidth / textViewWidth
        // ...
    }
}
```

This means scroll events touch zero CPU — the minimap is just a scaled `CALayer` composited by the GPU, identical to how Core Animation composites any image layer. Re-rendering is triggered only from `NSTextStorageDelegate.textStorage(_:didProcessEditing:range:changeInLength:)`, and only if the changed range is in the visible minimap section.[^5]

Mark the layer `isOpaque = true` and `backgroundColor = CGColor(...)` (no alpha) to eliminate the alpha-blending pass in the compositor, which is a free 5–15% compositing speedup for the minimap layer.[^5]

***

## Prioritized Fix Schedule

| Priority | Fix | Effort | Expected gain |
|---|---|---|---|
| 🔴 P0 | `drawBackground` bounds clamping (Sonoma fix) | 5 min | Fixes invisible text |
| 🔴 P0 | `updateNSView` theme-change guard | 10 min | Eliminates redundant re-highlights |
| 🔴 P0 | `CADisplayLink` keep-alive for ProMotion | 1 hour | Unlocks 120fps display |
| 🟠 P1 | Profile with Animation Hitches template | 2 hours | Identifies remaining bottlenecks |
| 🟠 P1 | `NSTextStorage` incremental delta pipeline | 4–6 hours | Eliminates O(n) keystroke cost |
| 🟡 P2 | Tree-sitter actor + background `Task` | 4–6 hours | Frees main thread during parse |
| 🟡 P2 | Minimap `CALayer` cached image | 2–3 hours | Eliminates scroll re-renders |
| 🟢 P3 | Three-phase highlighting (fallback + Tree-sitter + LSP) | 6–8 hours | Zero flicker on keystrokes |
| 🟢 P3 | `wait_until_scheduled` + triple-buffer (if using Metal) | 2–3 hours | Fixes M2 direct-mode jank |

---

## References

1. [Explore UI animation hitches and the render loop - Tech Talks - Videos](https://developer.apple.com/videos/play/tech-talks/10855/) - Explore how you can improve the performance of your app's user interface by identifying scrolling an...

2. [Improving app responsiveness | Apple Developer Documentation](https://developer.apple.com/documentation/xcode/improving-app-responsiveness) - Start Instruments, select your app and the Animation Hitches template, and click the Record button. ...

3. [Cannot run Animation Hitches Instrument. Is this a bug?](https://stackoverflow.com/questions/79201933/cannot-run-animation-hitches-instrument-is-this-a-bug) - This problem jumps out at you when using “Animation hitches” template because that template does not...

4. [Demystify and eliminate hitches in the render phase - Tech Talks](https://developer.apple.com/videos/play/tech-talks/10857/) - Discover how to eliminate offscreen passes and leverage Xcode optimization opportunities in order to...

5. [Improving Animation Performance - Apple Developer](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/ImprovingAnimationPerformance/ImprovingAnimationPerformance.html) - General Tips and Tricks · Use Opaque Layers Whenever Possible · Use Simpler Paths for CAShapeLayer O...

6. [Find and fix hitches in the commit phase - Tech Talks - Videos](https://developer.apple.com/videos/play/tech-talks/10856/) - Discover how to render smoother animations in your app by troubleshooting the commit phase of your r...

7. [CODE_EDITOR_ROOT_CAUSE-3.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/9fdae001-cfc5-4fc8-9013-368ab1e237b6/CODE_EDITOR_ROOT_CAUSE-3.md?AWSAccessKeyId=ASIA2F3EMEYEXKUUZ5JO&Signature=izfOWu%2Brh%2FfVHz64tv%2BV7h60Jrs%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEB0aCXVzLWVhc3QtMSJHMEUCIFVXmU4FJRHGtX%2FB2GXpgnh4MUTZ%2BAsSRaogfaGFI8QvAiEAu2ttJUFnxIO3c4b520SUb0eNqxIWFbafLBvb0wdAjMEq%2FAQI5v%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDP2Zh61xgNW7QZJakirQBJqZ5vR7zh2dBppYpviPziPvlWhuTId6OmPZfwdA3afkM10U5p3rKXhX7fJ8uYysAJFkaOn8SRIPp9dBudMmTcTsi4HbbmOSQEwLSGKlR6hZgC2EAKt8SK9vVzq0t76cNCxBMwJtcCMghTkxs8XKL8gyY1K%2BIybFRb7dTrqBT3TAz0xQIxXz1GuIPloCODU2qjlQYNkcD%2Bcu6Dmz49DDLCJC%2FPyGzABn0YdKS8%2Fpy0QGlIGMkGls%2FPEytFOGvNa0k%2BcO54foZDsbW9b%2FtbtPAcu8bFOf%2FvitQ3fH7gwFfs3RiFBei2nW1OTBSVbSAxdgBn4BIpztwsDgIteRpEG3dXSALEmdB3GjI7xBCPpiIlPA1afAr19uCxwVSEePfv3DZsb90Wfb9ujooqfPPkzy%2B4UU5fpxQJ7YNiyuL2404UbiYEe5urOaIlU7Lb1yMC0f1AtE0LiUSVCOqf6bre3eKpbUFcDICpYphB8Yv0LqwEiUgX30GrVOSi7lXwOishqom4ZZxKi%2Bcix854ACoRt%2BiuhDCGSL8xOSH7vaT75L160UAjKbB1Gh2QUX68evwJPoygYFxP3Rk8FfhXB5%2FMK2K0F5ZRtbhxcAE5F5CK2OYGep8H%2Bs55UazyKe%2BtCF3X9FymxdNAQDtpvXyAu5RvGjTsWlTellqpXUJDZq7uHqpJ6phjWq6EwRkcW4p0L5goJ6kwmUhsoOKwfZoEDEkvlpg%2BXzozlRnz3n3wXWfSr1VXDO7YoKV1NTtShtRrd%2FHYBKI2BNyzwJIKbwlcnXevADad4wq%2FfTzgY6mAGED3CBrWZXA8izdhAeza76uiXA40BmMakooPF9W2tyxmt72FKL3dGMokbAbEOKyijtd9qb6fJl%2BsjdP9Ru1GB5FPI3A5rVLqLrSe64tPqQ7C4rhwUgEX8Mg5XNXSLUUH8A4%2B45SUXzIvaiYyvpLtyFZvy%2FwA3ZwzaT7%2FCe%2FkNpBpXtSPfSw9UFYshmJeRAY5NqqzW%2FlxSd9g%3D%3D&Expires=1775569278) - --- TITLE Code Editor Invisible Text Root Cause Fix Path - Date 2026-04-07

8. [Swift performance while manipulating String](https://forums.swift.org/t/swift-performance-while-manipulating-string/40035) - String determines at construction time whether or not it is ASCII (which I assume almost all of thes...

9. [edited(_:range:changeInLength:) | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nstextstorage/edited(_:range:changeinlength:)?language=swift) - NSTextStorage invokes this method automatically each time it makes a change to its attributed string...

10. [textStorage(_:didProcessEditing:range:changeInLength:)](https://developer.apple.com/documentation/appkit/nstextstoragedelegate/textstorage(_:didprocessediting:range:changeinlength:)) - textStorage(_:didProcessEditing:range:changeInLength:) The method the framework calls when a text st...

11. [Base subclass of NSTextStorage in Swift - GitHub Gist](https://gist.github.com/preble/ab98fabda985b054126e) - Using an instance of NSTextStorage here instead seems to be much more performant, especially on larg...

12. [So how do you implement a NSTextStorage subclass in Swift?](https://forums.swift.org/t/so-how-do-you-implement-a-nstextstorage-subclass-in-swift/5141) - The string property of NSTextStorage is of type String, but the contract it must implement is that i...

13. [Releases · datlechin/TablePro - GitHub](https://github.com/datlechin/tablepro/releases) - 10+ SwiftUI rendering optimizations to prevent O ... SQL editor text binding sync now uses O(1) NSSt...

14. [Replacing NSAttributedString in NSTextStorage Moves NSTextView ...](https://stackoverflow.com/questions/57483865/replacing-nsattributedstring-in-nstextstorage-moves-nstextview-cursor) - It seems that when the string is rewritten, it doesn't preserve the cursor position, but this same c...

15. [Releases · ChimeHQ/Neon - GitHub](https://github.com/ChimeHQ/Neon/releases) - Make sure async methods are appropriately annotated MainActor; Migrate TreeSitterClient out into a d...

16. [swift - Difference between starting a detached task and calling a ...](https://stackoverflow.com/questions/74226295/difference-between-starting-a-detached-task-and-calling-a-nonisolated-func-in-ma) - The bar method creates a non-structured task, which, because it is a detached task, is not on the cu...

17. [Rewriting my app to SwiftUI & Swift 6 (+ default actor isolation ...](https://www.reddit.com/r/swift/comments/1opuidk/rewriting_my_app_to_swiftui_swift_6_default_actor/) - I am rewriting my existing app from UIKit to SwiftUI + Swift 6. I have issues how to do it efficient...

18. [Swift bindings for the tree-sitter parsing library - GitHub](https://github.com/viktorstrate/swift-tree-sitter) - Parsing text from a custom data source. If your text is stored in a custom data source, you can pars...

19. [Optimizing the Metal pipeline to maintain 120 FPS in GPUI - Reddit](https://www.reddit.com/r/programming/comments/1amp2ol/optimizing_the_metal_pipeline_to_maintain_120_fps/) - As soon as we neglect to draw a frame, its refresh rate drops. So we now render repeated frames for ...

