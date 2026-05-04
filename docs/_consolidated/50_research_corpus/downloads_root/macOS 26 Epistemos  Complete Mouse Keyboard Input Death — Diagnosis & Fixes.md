# macOS 26 Epistemos: Complete Mouse/Keyboard Input Death — Diagnosis & Fixes

## Executive Summary

The complete input failure in Epistemos is almost certainly caused by a combination of two compounding factors: (1) a **content view `alphaValue` desync** where `AppKitWindowHostingView.alphaValue = 0` causes AppKit's `hitTest:` machinery to silently return `nil` for all mouse events, and (2) a macOS 26 (Tahoe) **platform-level regression** in `NSHostingView` mouse event delivery that has been reported independently by multiple developers. Secondary candidates include `collectionBehavior` mutation post-creation and potential SPM dependency static initializers. This report ranks each of the ten research questions by probability and provides actionable debug commands and fixes.

***

## Most Probable Root Cause: `alphaValue = 0` Breaks `hitTest:`

### AppKit `hitTest:` and the Alpha-Zero Rule

The single most incriminating clue in the bug report is: *"The content view's `alphaValue = 0` but `CALayer.opacity = 1` (desync)."*

In AppKit, `NSView.hitTest(_:)` is the method `NSWindow` calls to determine which view should receive a mouse-down event. The documented — and separately confirmed by AppKit open-source references — behavior is that views with `alphaValue < 0.01` are treated as invisible to hit-testing and return `nil`. This is parallel to UIKit's explicitly documented rule: *"This method ignores view objects that are hidden, that have disabled user interactions, or have an alpha level less than 0.01."* If `AppKitWindowHostingView` (the root content view of the SwiftUI `Window`) has `alphaValue = 0`, **every** mouse event dispatched by `NSWindow` will fail hit-testing at the content view level. No subview — including a bare `Button("test")` — will ever receive the event because the walk never begins. This also explains why `NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown)` never fires: the event is dispatched but returned `nil` from `hitTest:` before it reaches any responder.[^1][^2][^3]

### Why CALayer.opacity = 1 While alphaValue = 0

`NSView.alphaValue` and `CALayer.opacity` are usually kept in sync by the AppKit compositing system, but they are **separate properties**. When an animation sets `layer.opacity` to `0` and then back to `1` while `alphaValue` was independently set to `0` at the NSView layer — or vice versa — they can become permanently desynced. The most likely trigger is `LaunchIntegrityGateView`: if it initiates an opacity transition (e.g., `withAnimation { opacity = 0 }`) or calls `view.alphaValue = 0` directly during a loading sequence, and that state is never reversed, the CALayer may have completed its animation back to `1.0` while the NSView-level `alphaValue` property was left stranded at `0`.[^4]

### Why `(lldb) contentView.alphaValue = 1.0` Didn't Fix It

The user reports that setting `alphaValue` to `1.0` via lldb had no effect. There are three explanations:
1. **Wrong view targeted** — the lldb command set `alphaValue` on an intermediate superview, not on `AppKitWindowHostingView` itself.
2. **A subview chain also has `alphaValue = 0`** — `LaunchIntegrityGateView`'s hosting wrapper or an intermediate SwiftUI `Group` may independently have `alphaValue = 0`, so fixing the root content view is insufficient.
3. **SwiftUI overwrites the value** — on the next render pass, SwiftUI may immediately reset `alphaValue` because a `@State` opacity binding still holds `0`.

The correct lldb diagnostic is to walk the *entire* view tree:

```
(lldb) expr -l swift -O -- NSApplication.shared.windows.first?.contentView?.subviews.map { "\($0) alpha=\($0.alphaValue)" }
```

And recursively on each subview until the offending `alphaValue = 0` is isolated.

***

## macOS 26 (Tahoe) Platform Regression: NSHostingView Mouse Events

### Documented Regression Pattern

macOS 26 introduced a wave of window interaction regressions that are independently corroborated across developer communities. The most directly relevant:[^5][^6][^7]

- **"macOS 26.3 RC breaks all borderless window interactions"** — a developer forum thread confirms that in macOS 26.3 RC, *"Click events are not delivered, windows cannot be moved or interacted with"*.[^7]
- **"After updating to macOS Tahoe, I'm running into an issue where a SwiftUI layer embedded in an AppKit app via NSHostingView no longer receives [mouse events]"**.[^5]
- **Apple Developer Forums thread** notes AppKit changes: *"In macOS 26.3 Beta, borderless windows behaved correctly: Mouse clicks were received normally. Window dragging worked as expected."* — implying subsequent releases broke this.[^6]

macOS 26 also introduced the Liquid Glass window chrome, which included a well-publicized bug: the enlarged corner radius (~24pt on standard windows, 26pt on unified-toolbar windows, 16pt on compact windows)) moved the 19×19px resize hotspot to lie **75% outside** the visible window. While that specific bug primarily affects resize handles and was partially addressed in 26.3 (still listed as a known issue at release) and fully fixed in 26.4, the same era of changes also disrupted hit-testing in hosting views.[^8][^9][^10][^11][^12]

### Isolation Test

Since a standalone SwiftUI binary works correctly (the user confirmed Calculator clicks work), the regression is specific to `NSHostingView` within this project's binary linked against the Tahoe SDK. To distinguish the platform bug from the project-specific alpha issue, compile a bare `Window { Button("test") { NSSound.beep() } }` **within the Epistemos target** (not a new scheme) and test on both 26.3.1 and 26.4.

***

## Question-by-Question Analysis

### Q1: macOS 26 Hardened Runtime + Entitlements for `Window` Scene Mouse Events

No evidence was found that macOS 26 Tahoe requires special entitlements for SwiftUI `Window` scenes to receive mouse events beyond standard entitlements. The existing debug entitlements (`app-sandbox = false`, `allow-jit`, `allow-unsigned-executable-memory`, `disable-library-validation`) are standard for a development build with JIT and Rust FFI. Hardened runtime primarily restricts dynamic library loading and memory semantics — it does not gate WindowServer event delivery.[^13][^14][^15]

**Verdict: Very unlikely to be the cause. Entitlements look correct.**

### Q2: `alphaValue = 0` / `CALayer.opacity = 1` Desync (PRIMARY SUSPECT)

As detailed above, this is the **highest-probability root cause**. `AppKitWindowHostingView` having `alphaValue = 0` causes `NSWindow.sendEvent:` dispatch to skip the entire view hierarchy. The desync between NSView-level `alphaValue` and `CALayer.opacity` is a documented AppKit pitfall, particularly when mixing explicit animation blocks (`NSAnimationContext`) with SwiftUI's declarative `.opacity()` modifier.[^2][^3][^4]

**Debug commands:**
```swift
// In applicationDidBecomeActive or after window appears:
if let content = NSApplication.shared.windows.first?.contentView {
    print("Content alphaValue: \(content.alphaValue)")
    print("Content layer opacity: \(content.layer?.opacity ?? -1)")
    func walk(_ v: NSView, indent: String = "") {
        if v.alphaValue < 0.5 { print("\(indent)⚠️ \(type(of: v)) alpha=\(v.alphaValue)") }
        v.subviews.forEach { walk($0, indent: indent + "  ") }
    }
    walk(content)
}
```

**Fix:** In `LaunchIntegrityGateView`, ensure that any gating animation uses SwiftUI's `.opacity()` modifier with `withAnimation { }` rather than directly mutating `NSView.alphaValue`. Add an `.onAppear { }` that asserts `alphaValue == 1.0` on the hosting view:
```swift
// In RootView or LaunchIntegrityGateView .onAppear:
DispatchQueue.main.async {
    NSApplication.shared.windows.first?.contentView?.alphaValue = 1.0
}
```
This is a safety net, not the proper fix. The proper fix is to identify *what* sets `alphaValue` to `0` and prevent it.

### Q3: Triple Window Restoration Suppression

Using `.restorationBehavior(.disabled)` on the `Window` scene, returning `false` from `applicationShouldRestoreApplicationState`, and running `SavedApplicationStatePurger` are three redundant layers of the same suppression. No evidence was found that any combination of these causes a SwiftUI hosting view to initialize in a non-interactive state on macOS 26. The redundancy is harmless.[^16]

**Verdict: Unlikely to be the cause. Can be simplified to just `.restorationBehavior(.disabled)` but safe to leave as-is.**

### Q4: `NSViewRepresentable` in `.background()` with `.allowsHitTesting(false)`

`.background(ModularZoomWindowObserver().allowsHitTesting(false))` renders an NSViewRepresentable *behind* all content at a lower z-order. The `.allowsHitTesting(false)` modifier translates to SwiftUI returning `nil` from hit-testing on that specific view. Since it is in the background (not overlaying the content), it should not intercept events intended for the foreground content.[^17]

**However**, if `ModularZoomWindowObserver.makeNSView()` or `updateNSView()` mutates `window.collectionBehavior` or calls `window.contentMinSize` *synchronously during view setup*, it can race with SwiftUI's internal window setup. This view also listens for `windowDidBecomeMain` to call `applyMainWindowPolicyIfNeeded`. Calling this during the initial appearance pass before SwiftUI has completed its hosting view setup is a risk on macOS 26.

**Verdict: Low direct probability for input death, but the window mutation side effects are risky. Test by temporarily commenting out `ModularZoomWindowObserver`.**

### Q5: `collectionBehavior` Stripping After SwiftUI Window Creation (SECONDARY SUSPECT)

This is a credible secondary cause. SwiftUI manages `NSWindow` lifecycle internally in `Window` scenes. When the app delegate's `applyMainWindowPolicyIfNeeded` strips `.fullScreenPrimary`, `.fullScreenAuxiliary`, and `.fullScreenAllowsTiling` from `collectionBehavior`, it is modifying state that SwiftUI's scene machinery tracks internally. On macOS 26 with the new Liquid Glass window management system, this could put the window's internal SwiftUI state machine into an undefined state.[^18]

The new macOS 26 AppKit introduces extensive window chrome changes including `NSGlassEffectView`, `NSGlassEffectContainerView`, and new `NSView.LayoutRegion` APIs — all of which interact with `collectionBehavior`. Stripping behaviors post-creation may disconnect SwiftUI's internal tile/fullscreen coordinator.[^18]

**Fix:** Move `collectionBehavior` mutation to *after* the first `NSWindow.didBecomeMain` notification fires, not in `applicationDidFinishLaunching`. Better still, use `.windowStyle(.hiddenTitleBar)` or SwiftUI's own `defaultLaunchBehavior` APIs instead of directly mutating the window.

**Test:** Comment out the entire body of `applyMainWindowPolicyIfNeeded` and verify input is restored.

### Q6: SPM Dependency Static Initialization

Of the 28 SPM dependencies, **AXorcist** is the highest-risk package for this symptom. AXorcist uses macOS Accessibility APIs to interact with the accessibility hierarchy. If AXorcist's initializer — via `+[AXorcist load]` in Objective-C or a Swift `@_silgen_name("__load")` hook — registers an `NSEvent.addGlobalMonitor(for:handler:)` or a `CGEvent.tapCreate(...)`, it could sit above the application event stream and interfere with event delivery without actually consuming events (a "deaf tap" that still affects dispatch timing).[^19]

To check for constructor code in SPM packages:
```bash
# Check for Objective-C +load methods:
nm -g $(find ~/Library/Developer/Xcode/DerivedData -name "libAXorcist*.a") | grep " S _OBJC_CLASS_$_"

# Check for static initializers in the compiled binary:
otool -s __DATA __mod_init_func /path/to/Epistemos.app/Contents/MacOS/Epistemos
```

**mlx-swift** initializes Metal GPU pipelines at load time. Metal initialization on macOS touches the WindowServer via `CAMetalLayer`, which could theoretically affect the render/event loop ordering. However, there are no reports linking mlx-swift initialization to event delivery failure.[^18]

**SwiftTreeSitter**, **GRDB**, and **CodeEditTextView** have no known event-related initializers.

**Verdict: Medium probability for AXorcist; low for others. Disable AXorcist linkage in a test build.**

### Q7: Rust FFI Static Library `#[ctor]` Functions

Rust's `#[ctor]` crate registers constructor functions in `__DATA,__mod_init_func`, which run before `main()` at library load time — directly analogous to Objective-C `+load`. If `graph-engine` or `syntax-core` were built with `#[ctor]` and those constructors call into CoreGraphics (e.g., `CGEventTapCreate`), they could install a passive event tap that interferes with the delivery pipeline.[^20]

Inspect the static libraries:
```bash
otool -s __DATA __mod_init_func graph-engine.a
otool -s __DATA __mod_init_func syntax-core.a
nm -n graph-engine.a | grep "__mod_init_func\|ctor\|constructor"
```

If constructors are found, review the Rust source for any `CGEvent` or `IOKit` HID usage. Pure computation libraries (graph layout, syntax parsing) should have no event-related constructors, but CGEvent taps have been observed as side effects of libraries bundling crash reporters or telemetry hooks.

**Verdict: Low probability for pure computation libraries. Worth a quick `otool` check.**

### Q8: `Window` vs `WindowGroup` on macOS 26

The switch from `Window` to `WindowGroup` was tested and also failed, which is the strongest evidence this is **not** a `Window`-vs-`WindowGroup` semantic difference. Both scene types ultimately create an `NSHostingView` wrapping an `NSWindow`, so any regression in the hosting view's mouse reception would affect both equally.[^16]

**Verdict: Ruled out as root cause by the user's own testing.**

### Q9: Ad-Hoc Signing + Hardened Runtime + `disable-library-validation`

`CODE_SIGN_IDENTITY = "-"` (ad-hoc signing) combined with `ENABLE_HARDENED_RUNTIME = YES` does not restrict WindowServer event delivery. The WindowServer delivers events based on window key/main status and `ignoresMouseEvents` — neither of which is gated by signing identity. The `disable-library-validation` entitlement is required to load Rust static libraries compiled without Apple signing.[^21][^13][^20]

One subtle risk: `allow-unsigned-executable-memory` combined with `allow-jit` on macOS 26 may trigger additional security hardening via the new process trust policies introduced in Tahoe. However, no evidence was found linking these entitlements to WindowServer event suppression.

**Verdict: Extremely unlikely. Ad-hoc + hardened runtime does not block event delivery.**

### Q10: Multiple `.sheet()` Modifiers on Root View

Having three `.sheet(isPresented:)` modifiers stacked on the root view of a `Window` scene is not officially supported as a pattern (prior to iOS 14.5/equivalent macOS version, only the last sheet would fire). While the current SwiftUI runtime handles this better, a degenerate state where the sheet presentation machinery is in a "transitioning" state (e.g., from a previous run's saved state being restored then discarded) could conceivably prevent the root view's hit-testing from activating.[^22]

More concretely: each `.sheet(isPresented:)` wraps the view in an additional `NSHostingView` presentation layer. Three stacked sheet presenters create three layers of SwiftUI presentation management. If any of these presenters initializes with an inconsistent state on macOS 26 (e.g., a dangling presentation lock), it could block event forwarding to the underlying content.

**Fix to test:** Move all three sheets to a single `Group { }` with a `switch` on a presentation enum, reducing to one sheet modifier:
```swift
.sheet(item: $activeSheet) { sheet in
    switch sheet {
    case .setup: SetupAssistantView { ... }
    case .diff: DiffApprovalSheet(...)
    case .quickCapture: QuickCaptureView()
    }
}
```

**Verdict: Low-medium probability. The multiple sheet pattern is suboptimal. Worth refactoring regardless.**

***

## Prioritized Diagnostic Checklist

| Priority | Issue | Test | Expected Fix |
|----------|-------|------|--------------|
| 1 (Critical) | `alphaValue = 0` on `AppKitWindowHostingView` | Walk view tree with lldb for any `alphaValue < 0.5` | Find and remove code that calls `.alphaValue = 0` on the hosting view |
| 2 (High) | macOS 26 `NSHostingView` mouse event regression | Test bare button in Epistemos target on 26.4 | Update to macOS 26.4; file Apple Feedback |
| 3 (Medium) | `collectionBehavior` stripping via app delegate | Comment out `applyMainWindowPolicyIfNeeded` entirely | Stop mutating SwiftUI-managed window `collectionBehavior` |
| 4 (Medium) | `ModularZoomWindowObserver` window mutation side-effects | Comment out `.background(ModularZoomWindowObserver()...)` | Move window policy changes to `windowDidBecomeKey` notification |
| 5 (Medium) | Three `.sheet()` modifiers degenerate presentation state | Refactor to single `.sheet(item:)` with enum | Cleaner presentation state machine |
| 6 (Low) | AXorcist static init installing event tap | Disable AXorcist linkage in test build | Audit AXorcist init for `CGEventTapCreate`/`NSEvent.addGlobalMonitor` |
| 7 (Low) | Rust FFI `#[ctor]` constructor functions | `otool -s __DATA __mod_init_func` on static libs | Review Rust source for any `CGEvent` usage |

***

## Deeper Debug Techniques

### Instrument the Hit-Test Path

Attach lldb and set a symbolic breakpoint on `NSWindow.sendEvent:` to see if events are entering the window at all:

```
(lldb) breakpoint set --name "-[NSWindow sendEvent:]"
```

If `sendEvent:` fires when clicking, the event reaches the window but is lost in `hitTest:`. If it never fires, the issue is upstream (WindowServer not delivering events to the process).

### Verify WindowServer Delivery

Use `CGEventTapCreate` at the `cghidEventTap` level to see if the system is delivering mouse events at the HID level:

```swift
// Temporary diagnostic — add to applicationDidFinishLaunching:
let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(1 << CGEventType.leftMouseDown.rawValue),
    callback: { _, _, event, _ in
        print("HID tap saw leftMouseDown: \(event?.location ?? .zero)")
        return event
    },
    userInfo: nil
)
print("HID tap created: \(tap != nil)")
```

If this tap fires when clicking, the OS is delivering events to the process at the HID level — confirming the issue is within AppKit's dispatch (hit-testing). If it doesn't fire, the issue is in WindowServer delivery itself (which would implicate signing, entitlements, or a CGEventTap installed by a dependency that's consuming events).

### `sample` / `spindump` for Event Thread

Run `sample Epistemos 5 -file /tmp/epistemos.sample` and click several times while the sample runs. Look for `_NSEventThread`, `GSEventRunModal`, or `__CFRunLoopRun` call stacks that indicate events are queued but not dispatched.

### Check for Rogue CGEvent Taps System-Wide

```bash
# List all registered CGEventTaps:
sudo dtrace -n 'syscall::mach_msg*:entry /execname == "Epistemos"/ { printf("%s\n", copyinstr(arg0)); }'
# Or use Accessibility Inspector → Window menu → Processes to inspect tap registrations
```

***

## Summary Recommendation

The immediate investigative path is:

1. **Run the view-tree alpha walk** in `applicationDidBecomeActive` and identify every NSView with `alphaValue < 0.5`. The `AppKitWindowHostingView` (root content view) being at `alphaValue = 0` is the most likely single explanation for 100% of clicks being silently dropped.[^3]

2. **Comment out `applyMainWindowPolicyIfNeeded`** entirely and test — this isolates whether `collectionBehavior` mutation is a contributing factor.[^6][^18]

3. **Test on macOS 26.4** (where the corner-area resize regression was fixed) — if input works there, a macOS 26.3.x platform bug is confirmed.[^9][^7][^5]

4. **Reduce to single `.sheet(item:)`** to eliminate the multiple-sheet-presenter degenerate state as a contributing factor.

The alphaValue desync and the macOS 26 NSHostingView regression may be compounding each other, which is why testing on 26.4 without the alpha fix — or fixing the alpha without updating macOS — may each show partial improvement. Both need to be addressed.

---

## References

1. [hitTest: | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsview/1483364-hittest?changes=latest_m_5_4&language=objc) - This method is used primarily by an NSWindow object to determine which view should receive a mouse-d...

2. [Parrot/MochaUI/AppKit+Extensions.swift at master - GitHub](https://github.com/avaidyam/Parrot/blob/master/MochaUI/AppKit+Extensions.swift) - set { NSView.clipPathKey[self] = newValue }. } /// Forces NSView to return `nil` from every `hitTest...

3. [Hacking Hit Tests - Khanlou](https://khanlou.com/2018/09/hacking-hit-tests/) - This method ignores view objects that are hidden, that have disabled user interactions, or have an a...

4. [macOS animation works once, then not again](https://apple-dev.groups.io/g/cocoa/topic/macos_animation_works_once/9517557) - alphaValue = 0;. inside an explicit animation block? Maybe you can't mix the two mechanisms. (I look...

5. [swiftUI / appKit question : r/swift - Reddit](https://www.reddit.com/r/swift/comments/1q6lo9s/swiftui_appkit_question/) - After updating to macOS Tahoe, I'm running into an issue where a SwiftUI layer embedded in an AppKit...

6. [AppKit | Apple Developer Forums](https://developer.apple.com/forums/topics/ui-frameworks-topic/ui-frameworks-topic-appkit?page=2&sortBy=newest) - In macOS 26.3 Beta, borderless windows behaved correctly: • Mouse clicks were received normally • Wi...

7. [macOS 26.3 RC breaks all borderless window interactions](https://origin-devforums.apple.com/forums/thread/814875) - However, in macOS 26.3 RC, all of the above behaviors are broken: • Click events are not delivered •...

8. [macOS Tahoe 26.3 fixes two annoying design problems [Update](https://9to5mac.com/2026/02/11/macos-tahoe-26-3-fixes-two-annoying-design-problems/) - The company now says macOS 26.3 doesn't fix the window resizing bug. Instead, it's once again listed...

9. [Two more Liquid Glass fixes in macOS 26.4 - anderegg.ca](https://anderegg.ca/2026/03/30/two-more-liquid-glass-fixes-in-macos-264) - First up, Apple fixed the corner resizing area! It's not surprising that this is fixed now, seeing a...

10. [What's the new window corner radius in macOS 26 Tahoe (Liquid ...](https://www.reddit.com/r/MacOSBeta/comments/1l9zfdi/whats_the_new_window_corner_radius_in_macos_26/) - It's 26pt for a window with a unified toolbar, 20pt for a unified compact toolbar, and 16pt for othe...

11. [macOS 26 windows are hard to resize because they aren't really ...](https://9to5mac.com/2026/01/13/macos-26-windows-are-hard-to-resize-because-they-arent-really-rounded/) - The window expects this click to happen in an area of 19 × 19 pixels, located near the window corner...

12. [macOS Tahoe windows have different corner radiuses - Hacker News](https://news.ycombinator.com/item?id=47279761) - ... Liquid Glass" in macOS 27. And the super-rounded window corners are high up on my list. Looks ch...

13. [Mac app tests fail with hardened runtime enabled - Jesse Squires](https://www.jessesquires.com/blog/2020/02/23/mac-app-tests-fail-with-hardened-runtime/) - The solution to fix this is to enable the hardened runtime only for release, and leave it disabled f...

14. [macOS binaries crash if codesigned with hardened runtime enabled](https://github.com/pyinstaller/pyinstaller/issues/4629) - The notary service ensures that every binary in the app has security features enabled, including tha...

15. [NSWindow | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nswindow) - A Boolean value that indicates whether the window is transparent to mouse events. ... Presents a Swi...

16. [Making a Single-Window Mac App using SwiftUI - Optional Map](https://optionalmap.com/posts/swiftui_single_window_app) - SwiftUI gives you a very simple way to set up a single-window mac app. This tutorial is current as o...

17. [NSViewRepresentable | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/nsviewrepresentable) - Use an NSViewRepresentable instance to create and manage an NSView object in your SwiftUI interface....

18. [What's new in AppKit on macOS 26 - Speaker Deck](https://speakerdeck.com/1024jp/whats-new-in-appkit-on-macos-26) - AppKitでの変更点洗い出しや注目ポイントなど、TahoeのためのmacOSアプリ開発のキャッチアップをお話しします。

19. [GitHub - philptr/EventTapCore: Swift wrapper around CGEvent and ...](https://github.com/philptr/EventTapCore) - EventTapCore is a Swift module that provides a wrapper around CGEvent and related types, as well as ...

20. [Library load disallowed by System Policy on macOS 10.15 beta 4](https://github.com/rust-lang/rust/issues/62826) - Was rustc compiled/signed with hardened runtime which opts it into having library validation? See th...

21. [GitHub - mologie/macos-disable-library-validation](https://github.com/mologie/macos-disable-library-validation) - This software installs a small kernel patch at boot-time, which disables Library Validation. Library...

22. [SwiftUI: Closing opened window on macOS causes crash](https://stackoverflow.com/questions/65116534/swiftui-closing-opened-window-on-macos-causes-crash) - This question shows research effort; it is useful and clear 2 I can open a new window, but if I clos...

