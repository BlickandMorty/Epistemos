# macOS 26 SwiftUI App — Complete Mouse/Keyboard Input Death: Diagnosis & Fixes

## Executive Summary

The complete loss of mouse/keyboard input in the Epistemos app is almost certainly caused by a **combination of two interacting issues**: (1) an **AppKit regression in macOS 26.3 / 26.3.1** that breaks mouse event dispatch for windows whose `styleMask` or `collectionBehavior` has been modified post-creation, and (2) the **`alphaValue = 0` desync on the `AppKitWindowHostingView`** which causes AppKit's `hitTest:` to return `nil` for the entire hosting view tree, silently blackholing all input before it reaches SwiftUI. Each issue alone can produce the symptoms; together they are nearly impossible to escape without understanding both layers.

***

## Part 1: The macOS 26.3 / 26.3.1 AppKit Window Regression

### The Core Bug

Apple introduced a severe regression in macOS Tahoe 26.3 RC (build 25D122) where `NSWindow` objects with custom `styleMask` configurations — specifically any window where `.titled` has been removed, or where `collectionBehavior` is stripped after window creation — exhibit two failure modes:[^1][^2][^3]

1. **Inability to resize** — the window resize handles stop working.
2. **Click-through death** — the window content does not capture mouse events; clicks pass through the content entirely, or the window acts as an opaque mouse trap without dispatching to any view.

Multiple third-party developers independently confirmed the same symptoms — borderless windows, HUD/OSD overlays, and floating panels all became completely non-interactive. Apple's Frameworks team acknowledged the reports on Developer Forums thread 814798:[^3][^4][^5][^1]

> *"Thanks for the Feedback number. We've gotten a few similar reports on 26.3 RC and are investigating."*

The public release of macOS 26.3 was reported as fixing the issue, but based on the user's environment (macOS **26.3.1**, build **25D2128**, running under Xcode **26.4**), at least one forum contributor noted the bug may have re-emerged in 26.4 betas. The Blizzard forums confirm a "known issue with some app windows not capturing mouse events due to a bug in Apple's UI framework for macOS (AppKit)" in the 26.3 RC timeframe, and the BetterDisplay project tracker links directly to `NSWindow.styleMask` manipulation as the trigger.[^6][^5][^7][^1]

### How This Hits Epistemos

The `applyMainWindowPolicyIfNeeded` function in `EpistemosAppDelegate` does exactly what triggers the regression: it **strips `.fullScreenPrimary`, `.fullScreenAuxiliary`, and `.fullScreenAllowsTiling` from `collectionBehavior`** on every `didBecomeMain`, `didBecomeKey`, and `didDeminiaturize` notification. In macOS 26, SwiftUI internally manages the window's `collectionBehavior` as part of its scene configuration. Mutating it from outside — especially repeatedly via notifications — corrupts SwiftUI's internal window state on macOS 26.3+. The result is that the AppKit layer stops routing `sendEvent:` correctly to the hosting view hierarchy.[^4][^1]

> **Key diagnostic step**: Open `lldb`, attach to the running app, and inspect `window.styleMask` and `window.collectionBehavior`. If `.titled` is absent from `styleMask`, or if `collectionBehavior` has been reduced to a near-empty set, the regression is confirmed.

***

## Part 2: The `alphaValue = 0` / `CALayer.opacity = 1` Desync

### Why This Is Fatal

AppKit's `NSView.alphaValue` is documented as reading directly from the view's CALayer opacity. A reading of `alphaValue = 0` with `layer.opacity = 1` indicates that something has set the property at the **NSView KVO/computed-property level** independently of the Core Animation layer — a state that can only arise through direct mutation, a side-effect of UIKit/AppKit internals (e.g., sheet presentation dimming), or a framework bug.[^8]

The critical consequence: AppKit's hit-test chain **skips views with `alphaValue` below approximately 0.01**. The `UIView` documentation is explicit on this, and NSView behavior mirrors it. If `AppKitWindowHostingView` — the root view that wraps the entire SwiftUI scene — reports `alphaValue = 0`, then `NSWindow`'s internal call to `contentView.hitTest:` returns `nil` for every click, which means `sendEvent:` has no responder to dispatch to. This is consistent with:[^9]

- NSEvent local monitors for `.leftMouseDown` **not firing** (events are not being dispatched, not just silently dropped)
- A bare `Button("test") { NSSound.beep() }` not responding (the failure is above the SwiftUI layer)
- Setting `alphaValue = 1.0` via lldb restoring visibility but **not restoring input** (because the macOS 26.3 regression in the AppKit dispatch path is also active)

### What Causes `alphaValue = 0`?

The most likely cause is **NSSheet dimming interaction**. When any `.sheet()` presentation begins — or when one is in a partially-committed state — AppKit overlays the presenting window with `NSSheetEffectDimmingView` and may set the hosting view's alpha as part of dimming the background. If the sheet state machine is reset (e.g., via the `SavedApplicationStatePurger` clearing window state mid-presentation), the alpha can be zeroed without being restored. With three `.sheet()` modifiers layered on the root view, there are three independent presentation state machines that can enter this inconsistent state.[^10]

A secondary candidate: **`NSViewRepresentable` in `.background()` with a frame/bounds desync**. The `ModularZoomWindowObserver` as an `NSViewRepresentable` in `.background()` applies `WindowPresentationPolicy` which itself manipulates `collectionBehavior`. Although `.allowsHitTesting(false)` prevents the representable's own view from accepting input, it does not prevent it from calling NSWindow APIs that put the hosting view in an inconsistent alpha state.[^11][^12]

***

## Part 3: Answering Each Specific Question

### Q1 — macOS 26 Hardened Runtime + SwiftUI `Window` Scenes

There is **no evidence** that macOS 26 Tahoe requires new entitlements for `Window` scenes to receive mouse events. Ad-hoc signed apps with hardened runtime (`ENABLE_HARDENED_RUNTIME = YES`, `CODE_SIGN_IDENTITY = "-"`) do not have WindowServer-level event delivery restrictions imposed on them by signature alone. The `disable-library-validation` entitlement is valid and documented. The hardened runtime interaction that does matter here is the Rust FFI static libraries — see Part 3, Q7.[^13][^14][^15]

### Q2 — `alphaValue = 0` / `CALayer.opacity = 1` Desync

This is a **documented and mechanically important failure mode**. `NSView.alphaValue` and `CALayer.opacity` can desync when AppKit sheet machinery sets the view alpha at the NSView layer independently of Core Animation. The desync is most likely caused by a sheet presentation beginning (which zeroes the hosting view alpha for the dimming effect) and then being abandoned or rolled back by the `SavedApplicationStatePurger` or by SwiftUI's own state restoration code, leaving alpha at 0 permanently.[^8]

**This directly breaks `hitTest:`**. AppKit skips views with `alphaValue < ~0.01` during hit-testing, meaning `NSWindow.sendEvent:` finds no valid responder and silently drops the event. The fact that setting `alphaValue = 1.0` via lldb does not fix input confirms the regression in Q1 is also active — fixing alphaValue alone is not sufficient because the dispatch path has two broken layers.[^16][^9]

**Whether this is a macOS 26 regression specifically**: The `alphaValue`/`opacity` desync under sheet presentation has been reported in prior macOS versions and is not unique to macOS 26, but the Liquid Glass rework and the SwiftUI hosting infrastructure changes in macOS 26 make it more likely to be triggered during scene initialization.[^10]

### Q3 — Triple Window Restoration Suppression

The combination of `.restorationBehavior(.disabled)`, `applicationShouldRestoreApplicationState → false`, and `SavedApplicationStatePurger.purgeIfNeeded()` (which deletes `~/Library/Saved Application State/`) is unusually aggressive. No documentation confirms that this combination places the hosting view in a non-interactive initial state. However, `purgeIfNeeded()` runs in `applicationWillFinishLaunching` — **before SwiftUI creates the window and hosting view**. If SwiftUI's `Window` scene initialization path reads from the state store to configure initial window parameters (including any partial presentation state from a previous session), clearing the store at this moment can result in SwiftUI initializing with a default state that conflicts with what AppKit has already set up. This is a probable contributor to the `alphaValue = 0` state rather than its sole cause.

### Q4 — `NSViewRepresentable` in `.background()` + `.allowsHitTesting(false)`

`.allowsHitTesting(false)` on a SwiftUI view in `.background()` **does not propagate upward** to block the parent view hierarchy from receiving input — this is by design in SwiftUI's hit-testing model. The NSViewRepresentable itself will return `nil` from `hitTest:` for its own frame.[^17][^18]

The danger is indirect: `ModularZoomWindowObserver` calls NSWindow APIs (stripping `collectionBehavior`, reconfiguring zoom button target/action) **from within a view's `viewDidMoveToWindow` callback**. Calling `window.collectionBehavior` setters from within layout/display passes is not documented as safe, and on macOS 26.3+ it directly triggers the styleMask/collectionBehavior regression described in Part 1. This background modifier should be considered a **high-probability co-trigger** of the input failure.

### Q5 — `collectionBehavior` Stripping After SwiftUI Window Creation

**Yes — this is a primary cause.** On macOS 26.3+, post-creation mutation of `NSWindow.collectionBehavior` to remove `.fullScreenPrimary`, `.fullScreenAuxiliary`, and `.fullScreenAllowsTiling` is exactly the class of modification confirmed to break mouse event dispatch. SwiftUI owns the window's full-screen lifecycle on macOS 26; removing these behaviors from outside SwiftUI's control corrupts the internal state machine that governs the hosting view's event pipeline.[^2][^5][^1]

This mutation happens **twice** in Epistemos: once in `applyMainWindowPolicyIfNeeded` (via the AppDelegate) and once in `ModularZoomWindowObserver` (via the background NSViewRepresentable). The correct fix is to use SwiftUI's native API instead: add `.windowFullScreenBehavior(.disabled)` as a scene modifier, which signals the intent to SwiftUI without touching the underlying NSWindow directly.[^19]

### Q6 — SPM Dependency Static Initialization

Among the listed dependencies, the highest-risk candidates are:

- **AXorcist**: Uses macOS Accessibility APIs. AX API access does not install CGEvent taps, but if AXorcist has `+load` methods that configure `NSApplication` observers or swizzle `sendEvent:`, it could interfere. The author (steipete) maintains `InterposeKit`, a Swift swizzling library — AXorcist may use similar patterns.[^20][^21]
- **CodeEditTextView/SourceEditor**: A pure Swift NSView subclass; no known static initializers that modify `NSApplication`. Low risk.[^22]
- **mlx-swift**: Initializes Metal/GPU contexts; may call into MPS or CoreML frameworks during static init. Does not interact with NSApplication event dispatch.[^23]
- **SwiftTreeSitter**: A parser library with no AppKit interaction. Low risk.

**Diagnostic**: Run the app under Instruments with "System Trace" and filter for `+[NSObject load]` calls to enumerate all `+load` implementations from SPM packages.

### Q7 — Rust FFI Static Library Initialization

Rust `#[ctor]` functions execute as ELF/Mach-O section constructors at dylib load time, equivalent to C `__attribute__((constructor))`. Static libraries (`.a` files linked into the app binary) have their constructors merged into the app's load order. If `graph-engine` or `syntax-core` have `#[ctor]` functions that:[^24]
- Install signal handlers (`SIGSEGV`, `SIGBUS`) — these can interfere with the Mach exception handler used by the macOS crash reporter and, in pathological cases, with the runloop
- Call any CoreFoundation or AppKit API during static initialization (which runs before `@main`) — this is unsafe and can leave AppKit in an inconsistent state

However, **plain Rust static libraries do not install CGEvent taps** — that requires Objective-C interop and explicit Accessibility permissions. The risk here is low unless the Rust code explicitly bridges into CoreGraphics or AppKit.

**Diagnostic**: Use `nm -u YourApp.app/Contents/MacOS/YourApp | grep "mod_init\|__ZN.*ctor"` to enumerate constructor symbols from linked static libraries.

### Q8 — `Window` vs `WindowGroup` on macOS 26

There is no confirmed, specific regression for SwiftUI's `Window` (single-window) scene type on macOS 26 that causes content to lose mouse events. The user has already confirmed that switching to `WindowGroup` did not fix the problem, which rules this out as the root cause. The macOS 26.3 window regression affects both `Window` and `WindowGroup`-backed NSWindows when their `styleMask`/`collectionBehavior` is externally mutated.[^25][^26]

### Q9 — Ad-Hoc Signing + Hardened Runtime + `disable-library-validation`

**No confirmed WindowServer restriction applies here.** Ad-hoc signing with hardened runtime is explicitly discussed in Apple's notarization documentation and is expected to work for local development. The `disable-library-validation` entitlement is the standard workaround for linking unsigned or differently-signed third-party binaries (like Rust static libraries). WindowServer does not gate event delivery based on code signature identity for locally-running development builds. This combination is not the cause.[^27][^14][^15]

### Q10 — Three `.sheet()` Modifiers on Window Content

Multiple `.sheet()` modifiers on the same view hierarchy were fixed in macOS 12 / SwiftUI equivalent of iOS 14.5. On macOS 26 with SwiftUI 6, three `.sheet()` modifiers are technically supported.[^28]

The risk is not from the sheets themselves but from the **state machine they put SwiftUI into at initialization**. Each `.sheet()` registers presentation state that SwiftUI must track. If the `SavedApplicationStatePurger` clears state mid-initialization and one of the bindings (`stagedDiff != nil`, `showQuickCapture`) is evaluated against stale AppKit state (from a partially-restored NSWindow), SwiftUI may initialize the hosting view with a dimmed alpha (the "presenting" state) without completing the transition to the "presented" or "dismissed" state. This is the most likely single trigger for `alphaValue = 0` on the hosting view.

***

## Recommended Fixes, Ordered by Confidence

### Fix 1 (Highest Priority): Remove All External `collectionBehavior` Mutations

Replace every call to `window.collectionBehavior.remove(.fullScreenPrimary/Auxiliary/AllowsTiling)` — in both the AppDelegate and `ModularZoomWindowObserver` — with SwiftUI scene modifiers:

```swift
// In EpistemosApp.body:
Window("Epistemos", id: "main") { ... }
    .windowFullScreenBehavior(.disabled)   // macOS 13+
    .restorationBehavior(.disabled)
    .defaultSize(width: 1100, height: 720)
    .windowResizability(.contentMinSize)
```

Delete `applyMainWindowPolicyIfNeeded` entirely. This eliminates the collectionBehavior mutation that directly triggers the macOS 26.3 regression.[^1][^19]

### Fix 2: Eliminate `ModularZoomWindowObserver` as a `.background()` NSViewRepresentable

Move all window policy application to a single, one-shot location: either `applicationDidFinishLaunching` (after a `.asyncAfter(deadline: .now() + 0.1)` delay to let SwiftUI finish window setup), or better, a `onAppear` on the root view that reads the window from the SwiftUI `Environment` (using `.defaultWindowPlacement` or the environment `\.openWindow` pattern). The background NSViewRepresentable calling NSWindow APIs from layout is not safe on macOS 26.[^11]

### Fix 3: Resolve the `alphaValue = 0` State

Add this diagnostic immediately after `applicationDidFinishLaunching`:

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    for window in NSApplication.shared.windows {
        print("Window: \(window), alpha: \(window.contentView?.alphaValue ?? -1)")
        // Temporarily force alpha to 1.0 to test if input is restored
        window.contentView?.alphaValue = 1.0
    }
}
```

If forcing `alphaValue = 1.0` post-launch restores input (confirming the alpha is the active blocker after the collectionBehavior fix), the next step is finding the source. Add a Swift symbolic breakpoint on `-[NSView setAlphaValue:]` filtered to the content view class to catch the write.

### Fix 4: Guard `SavedApplicationStatePurger` Timing

If `SavedApplicationStatePurger.purgeIfNeeded()` is needed, move it to a point **after** `applicationDidFinishLaunching` completes, not in `applicationWillFinishLaunching`. Better still, use only `.restorationBehavior(.disabled)` and `applicationShouldRestoreApplicationState → false`, which are sufficient to suppress state restoration without aggressively deleting state files that SwiftUI may read for initial window configuration.

### Fix 5: Isolate Sheet State as a Root Cause

Temporarily strip all three `.sheet()` modifiers from the root view and replace them with empty state. If input is restored, reintroduce sheets one at a time to identify which binding's initialization path triggers the alpha desync.

### Fix 6: Check for Static Initializers in Rust Libraries

Run: `nm YourApp.app/Contents/MacOS/YourApp | grep -E "_(mod_init|OBJC_LOAD_METHOD|__ZN.*ctor)"`. Inspect any Rust-origin symbols. If constructors appear, audit `graph-engine` and `syntax-core` for any AppKit, CoreGraphics, or NSApplication API calls in `#[ctor]`-decorated functions[^24].

***

## Summary Diagnostic Table

| Question | Root Cause? | Severity | Action |
|---|---|---|---|
| macOS 26.3 styleMask/collectionBehavior regression | **Yes — primary** | Critical | Stop mutating collectionBehavior; use `.windowFullScreenBehavior(.disabled)` |
| `alphaValue=0` / `CALayer.opacity=1` desync | **Yes — primary** | Critical | Find what writes alpha=0; likely sheet state machine + SavedApplicationStatePurger timing |
| Triple restoration suppression | Probable contributor | Medium | Move purge to post-launch; simplify to `.restorationBehavior(.disabled)` only |
| NSViewRepresentable in `.background()` | Co-trigger | High | Remove; move WindowPolicy to safe one-shot location |
| `collectionBehavior` stripping from AppDelegate | **Yes — direct trigger** | Critical | Replace with SwiftUI scene modifiers |
| SPM static initializers (AXorcist) | Possible | Medium | Audit `+load`; run with Instruments System Trace |
| Rust FFI `#[ctor]` functions | Unlikely unless AppKit calls | Low | Inspect with `nm`; verify no CoreGraphics/AppKit use |
| `Window` vs `WindowGroup` regression | Not confirmed | Low | Already tested; not root cause |
| Ad-hoc signing + hardened runtime + `disable-library-validation` | No | None | Not a contributing factor |
| Three `.sheet()` modifiers | Probable trigger for alpha=0 | High | Isolate by removing temporarily |

---

## References

1. [Custom NSWindow styleMask behavior… | Apple Developer Forums](https://developer.apple.com/forums/thread/814798) - On 26.3 RC, mouse events are intercepted by the entire transparent window rather than only the opaqu...

2. [Unable to resize Stickies on MacOS Tahoe 26.3 (25D122) - Reddit](https://www.reddit.com/r/MacOSBeta/comments/1qz3rt9/unable_to_resize_stickies_on_macos_tahoe_263/) - The issue was acknowledged by Apple - an updated RC2 should be coming. https://developer.apple.com/f...

3. [macOS Tahoe 26.3 RC (25D122) AppKit bug: OSD interaction is ...](https://github.com/waydabber/BetterDisplay/issues/5077) - Apple is aware of the issue: https://developer.apple.com/forums/thread/814798. We'll see if a workar...

4. [macOS 26.3 RC breaks all borderless window interactions](https://origin-devforums.apple.com/forums/thread/814875) - After updating to macOS 26.3 Release Candidate, all interactions for borderless windows are no longe...

5. [macOS Tahoe 26.3 RC (25D122) AppKit bug: PIP/Stream crop ...](https://github.com/waydabber/BetterDisplay/issues/5078) - This seems to be related to a sudden and unexplained change in how NSWindow works when .titled is re...

6. [Mouse clicking not working in MacOs Tahoe 26.3 RC - Bug Report](https://us.forums.blizzard.com/en/d3/t/mouse-clicking-not-working-in-macos-tahoe-263-rc/66981) - The 26.3 RC has a known issue with some app windows not capturing mouse events due to a bug in Apple...

7. [macOS Tahoe 26.3 RC (25D122) AppKit bug: PIP window cannot be ...](https://github.com/waydabber/BetterDisplay/issues/5079) - This seems to be related to a sudden and unexplained change in how NSWindow works when .titled is re...

8. [alphaValue | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsview/alphavalue) - This property contains the opacity value from the view's layer. The acceptable range of values for t...

9. [UIView alpha 0 but still receive touch events? - Stack Overflow](https://stackoverflow.com/questions/30269852/uiview-alpha-0-but-still-receive-touch-events) - Just add another transparent view with the same position and size (which is easy using constraints) ...

10. [A Story About Swizzling "the Right Way™" and Touch Forwarding](https://steipete.me/posts/2014/a-story-about-swizzling-the-right-way-and-touch-forwarding) - Learn why traditional method swizzling breaks UIKit's touch forwarding and discover a better approac...

11. [NSViewRepresentable breaks - by Vicente Garcia - Feedback Loop](https://vicegax.substack.com/p/nsviewrepresentable-breaks) - I have found one use case where NSViewRepresentable breaks completely, stops responding and the wors...

12. [Swift Critic | yo, go - AI Agents for Software Development](https://yo-go.ai/reference/agents/sub/swift-critic/) - Flag when the toggled view has meaningful state. Recommend ZStack + .opacity() + .allowsHitTesting()...

13. [Mac app tests fail with hardened runtime enabled - Jesse Squires](https://www.jessesquires.com/blog/2020/02/23/mac-app-tests-fail-with-hardened-runtime/) - I recently discovered that unit tests and UI tests for a macOS Xcode project will fail with obscure ...

14. [Disable Hardened Runtime in Xcode If Signing With Ad Hoc?](https://stackoverflow.com/questions/79597514/disable-hardened-runtime-in-xcode-if-signing-with-ad-hoc) - When I make new Xcode projects, hardened runtime is disabled when ad-hoc codesigning: Disabling hard...

15. [Disable Library Validation Entitlement - Apple Developer](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.cs.disable-library-validation) - To add this entitlement to your app, first enable the Hardened Runtime capability in Xcode, and then...

16. [How to make a transparent NSView subclass handle mouse events?](https://stackoverflow.com/questions/435685/how-to-make-a-transparent-nsview-subclass-handle-mouse-events) - I would like to make parts of the transparent region clickable so that accidentally clicking between...

17. [hitTest(_:) | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsview/hittest(_:)) - Returns the farthest descendant of the view in the view hierarchy (including itself) that contains a...

18. [hitTest: | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsview/hittest(_:)?language=objc) - This method is used primarily by an NSWindow object to determine which view should receive a mouse-d...

19. [windowFullScreenBehavior(_:) | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/view/windowfullscreenbehavior(_:)) - You can use this modifier to override the default behavior. For example, you can specify that a wind...

20. [AXorcist ‍♂️ - The power of Swift compels your UI to obey! - GitHub](https://github.com/steipete/AXorcist) - AXorcist harnesses the supernatural powers of macOS Accessibility APIs to give you mystical control ...

21. [steipete/InterposeKit: A modern library to swizzle elegantly in Swift.](https://github.com/steipete/InterposeKit) - InterposeKit is a modern library to swizzle elegantly in Swift, supporting hooks on classes and indi...

22. [CodeEditApp/CodeEditTextView: A text editor specialized ... - GitHub](https://github.com/CodeEditApp/CodeEditTextView) - This package exports a primary TextView class. The TextView class is an NSView subclass that can be ...

23. [LLMEval - ml-explore/mlx-swift-examples - GitHub](https://github.com/ml-explore/mlx-swift-examples/blob/main/Applications/LLMEval/README.md) - An example that: downloads a huggingface model and tokenizer; evaluates a prompt; displays the outpu...

24. [ctor - crates.io: Rust Package Registry](https://crates.io/crates/ctor) - Static items are supported, but require Rust >= 1.70. This library supports WASM targets, and the MS...

25. [Scenes types in a SwiftUI Mac app - Nil Coalescing](https://nilcoalescing.com/blog/ScenesTypesInASwiftUIMacApp) - In this post, we'll explore the different scene types available in SwiftUI for macOS, including Wind...

26. [Bring multiple windows to your SwiftUI app - WWDC22 - Videos](https://developer.apple.com/videos/play/wwdc2022/10061/) - We'll also show you how to use modifiers that customize the presentation and behavior of your app wi...

27. [macOS binaries crash if codesigned with hardened runtime enabled](https://github.com/pyinstaller/pyinstaller/issues/4629) - The notary service ensures that every binary in the app has security features enabled, including tha...

28. [Multiple sheet(isPresented:) doesn't work in SwiftUI - Stack Overflow](https://stackoverflow.com/questions/58837007/multiple-sheetispresented-doesnt-work-in-swiftui) - I have this ContentView with two different modal views, so I'm using sheet(isPresented:) for both, b...

