# Graph Overlay NSPanel Migration — Implementation Plan

> **For Kimi:** Follow this plan task-by-task. Each task has exact file paths, code, and verification steps. Do NOT skip tasks or combine them. Run tests after each phase.

**Goal:** Replace the fragile borderless-NSWindow graph overlay with a proper NSPanel child window. Fix Mission Control, fullscreen, and minimize behavior.

**Architecture:** NSPanel (`.nonactivatingPanel`) as a child window of the main app window. No Metal view reparenting — use show/hide instead. NSWindowController manages lifecycle.

**Tech Stack:** Swift, AppKit (NSPanel, NSWindowController), Metal (unchanged)

**Current files being replaced:**
- `Epistemos/Views/Graph/HologramOverlay.swift` (842 lines) — gutted and simplified
- `Epistemos/Views/Graph/HologramController.swift` (168 lines) — minor changes

**New files:**
- `Epistemos/Views/Graph/GraphOverlayPanel.swift` (~60 lines)

---

## What's Wrong Today

`HologramOverlay.swift` uses `KeyableWindow` (a borderless `NSWindow` subclass) with manual `.floating` level and `.canJoinAllSpaces` collection behavior. Problems:

1. **Mission Control:** The overlay floats above ALL spaces because `.canJoinAllSpaces` + `.stationary`. It doesn't follow the main window properly.
2. **Fullscreen:** When the main window enters fullscreen, the overlay stays behind or disappears. No `.willEnterFullScreenNotification` handling.
3. **Minimize reparenting:** `minimize()` removes the MetalGraphNSView from the full-screen window and adds it to a mini panel. `restore()` does the reverse. This causes Metal drawable size mismatches, brief flashes, and edge cases where the view gets lost (line 270-274: "Overlay window was lost — recreate everything").
4. **Z-order fragility:** Both the full-screen window and mini panel use `.floating` level. Multiple floating windows can fight for z-order.
5. **Key window stealing:** `KeyableWindow` returns `canBecomeKey = true` and `canBecomeMain = true` unconditionally. This can steal focus from note windows.

## What We're Building

One `NSPanel` subclass that:
- Is a **child window** of the main app window (moves with it, z-orders above it)
- Uses `.nonactivatingPanel` style (doesn't steal focus from the main window)
- Handles fullscreen transitions (orderOut before, orderFront after)
- Has TWO display modes: **full-screen overlay** and **mini float** — controlled by frame changes, NOT by reparenting the Metal view
- The MetalGraphNSView is created once and lives in the panel forever

---

## Phase 1: Create NSPanel Subclass

### Task 1: Create `GraphOverlayPanel.swift`

**Files:**
- Create: `Epistemos/Views/Graph/GraphOverlayPanel.swift`

**Code:**

```swift
import AppKit

/// NSPanel subclass for the graph overlay.
/// Uses .nonactivatingPanel to avoid stealing focus from the main window.
/// Set as a child window of the main app window for proper z-ordering,
/// Mission Control behavior, and fullscreen transitions.
final class GraphOverlayPanel: NSPanel {

    /// In mini mode, the panel should accept key for graph interactions.
    /// In full-screen overlay mode, it should also accept key (for search, Esc dismiss).
    override var canBecomeKey: Bool { true }

    /// Never become main — the main window should always stay main.
    override var canBecomeMain: Bool { false }

    /// Accept first mouse so clicks in the panel work without first activating it.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        level = .floating
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        // The Secret Sauce — this single property fixes 80% of "weirdness":
        // .moveToActiveSpace  — follows user between Spaces
        // .fullScreenAuxiliary — stays visible in fullscreen
        // .ignoresCycle        — excluded from ⌘~ window cycling
        // .stationary          — don't auto-move on Exposé/Mission Control
        collectionBehavior = [
            .moveToActiveSpace,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        // Prevent the panel from appearing in the Window menu or Exposé.
        isExcludedFromWindowsMenu = true
    }

    required init?(coder: NSCoder) { fatalError() }
}
```

**Verify:** Build compiles. `xcodebuild -scheme "Epistemos" -destination "platform=macOS" build`

---

## Phase 2: Migrate Full-Screen Overlay Window

### Task 2: Replace `KeyableWindow` with `GraphOverlayPanel` in `createWindow()`

**Files:**
- Modify: `Epistemos/Views/Graph/HologramOverlay.swift`

**What to change:**

1. Delete the `KeyableWindow` class at the top of the file (lines 9-12). It's no longer needed.

2. In `createWindow()` (line 660), replace:
```swift
let window = KeyableWindow(
    contentRect: screen.frame,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.level = .floating
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.isReleasedWhenClosed = false
window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
window.ignoresMouseEvents = false
window.acceptsMouseMovedEvents = true
```

With:
```swift
let window = GraphOverlayPanel(contentRect: screen.frame)
window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
// Full-screen overlay doesn't need a shadow (blur background covers everything).
window.hasShadow = false
```

3. After `self.window = window` (line 807), add the child window relationship:
```swift
// Attach as child of main app window for proper z-ordering and fullscreen behavior.
if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
    mainWindow.addChildWindow(window, ordered: .above)
}
```

**Verify:** Build compiles. Launch app, press Cmd+G. The overlay should appear. Press Cmd+G again to dismiss.

---

### Task 3: Replace `KeyableWindow` with `GraphOverlayPanel` in `createMiniPanel()`

**Files:**
- Modify: `Epistemos/Views/Graph/HologramOverlay.swift`

**What to change in `createMiniPanel()` (line 376):**

Replace:
```swift
let panel = KeyableWindow(
    contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
    styleMask: [.borderless, .resizable],
    backing: .buffered,
    defer: false
)
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
panel.isMovableByWindowBackground = false
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
panel.isReleasedWhenClosed = false
panel.minSize = NSSize(width: 320, height: 240)
panel.maxSize = NSSize(width: 1200, height: 900)
panel.ignoresMouseEvents = false
panel.acceptsMouseMovedEvents = true
```

With:
```swift
let panel = GraphOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 380))
panel.minSize = NSSize(width: 320, height: 240)
panel.maxSize = NSSize(width: 1200, height: 900)
```

Also replace the `KeyableWindow` usage in `createMiniInspectorPanel()` (line 436) the same way:
```swift
let panel = GraphOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: inspectorWidth, height: inspectorHeight))
panel.styleMask = [.nonactivatingPanel, .borderless]  // Inspector is not resizable
```

After creating each mini panel, attach it as a child window too:
```swift
if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
    mainWindow.addChildWindow(panel, ordered: .above)
}
```

**Verify:** Build. Cmd+G to open overlay, minimize button to mini mode. Mini panel should appear. Expand button to restore.

---

## Phase 3: Add Fullscreen Transition Handling

### Task 4: Handle fullscreen enter/exit

**Files:**
- Modify: `Epistemos/Views/Graph/HologramOverlay.swift`

**What to add:** New private method + observers in `createWindow()`.

Add this method to `HologramOverlay`:
```swift
// MARK: - Fullscreen Handling

private var fullscreenEnterObserver: Any?
private var fullscreenExitObserver: Any?

private func observeFullscreenTransitions() {
    fullscreenEnterObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.willEnterFullScreenNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        // Hide overlay during fullscreen animation to prevent flash.
        self?.window?.orderOut(nil)
        self?.miniPanel?.orderOut(nil)
        self?.miniInspectorPanel?.orderOut(nil)
    }

    fullscreenExitObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didExitFullScreenNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        guard let self else { return }
        // Re-show if the overlay was visible before fullscreen.
        if self.isMinimized {
            self.miniPanel?.orderFront(nil)
        } else if self.window != nil {
            // Only re-show if it was previously visible (not hidden).
        }
    }
}
```

Also add a `didEnterFullScreen` observer to re-show:
```swift
    // In observeFullscreenTransitions(), add:
    NotificationCenter.default.addObserver(
        forName: NSWindow.didEnterFullScreenNotification,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let self, self.isVisible else { return }
        // Re-attach as child of the now-fullscreen window.
        if let fsWindow = notification.object as? NSWindow {
            if let w = self.window, !self.isMinimized {
                fsWindow.addChildWindow(w, ordered: .above)
                w.orderFront(nil)
            }
            if let mp = self.miniPanel, self.isMinimized {
                fsWindow.addChildWindow(mp, ordered: .above)
                mp.orderFront(nil)
            }
        }
    }
```

Also observe the **parent window** miniaturize/deminiaturize so the overlay hides when the main app minimizes to Dock:

```swift
private var parentMiniaturizeObserver: Any?
private var parentDeminiaturizeObserver: Any?

private func observeParentMiniaturize() {
    let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) })

    parentMiniaturizeObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.willMiniaturizeNotification,
        object: mainWindow,
        queue: .main
    ) { [weak self] _ in
        // Hide overlay when parent minimizes to Dock.
        self?.window?.orderOut(nil)
        self?.miniPanel?.orderOut(nil)
        self?.miniInspectorPanel?.orderOut(nil)
    }

    parentDeminiaturizeObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didDeminiaturizeNotification,
        object: mainWindow,
        queue: .main
    ) { [weak self] _ in
        guard let self else { return }
        // Re-show overlay after parent restores from Dock.
        if self.isMinimized {
            self.miniPanel?.orderFront(nil)
        } else if self.window != nil, self.isVisible {
            self.window?.orderFront(nil)
        }
    }
}
```

Call both `observeFullscreenTransitions()` and `observeParentMiniaturize()` at the end of `createWindow()`.

In `teardown()`, add cleanup:
```swift
if let obs = fullscreenEnterObserver { NotificationCenter.default.removeObserver(obs) }
if let obs = fullscreenExitObserver { NotificationCenter.default.removeObserver(obs) }
if let obs = parentMiniaturizeObserver { NotificationCenter.default.removeObserver(obs) }
if let obs = parentDeminiaturizeObserver { NotificationCenter.default.removeObserver(obs) }
fullscreenEnterObserver = nil
fullscreenExitObserver = nil
parentMiniaturizeObserver = nil
parentDeminiaturizeObserver = nil
```

**Verify:** Build. Then test all three lifecycle events:
1. **Fullscreen:** Open overlay (Cmd+G). Enter fullscreen (Ctrl+Cmd+F or green button). The overlay should disappear during transition, reappear after. Exit fullscreen — overlay should reappear.
2. **Parent minimize:** Open overlay. Minimize the main window (Cmd+M). The overlay should hide. Click Dock icon to restore — overlay should reappear.
3. **Parent minimize in mini mode:** Open overlay, minimize to mini float. Minimize the main window. Mini float should hide. Restore — mini float reappears.

---

## Phase 4: Remove `.stationary` Collection Behavior

### Task 5: Verify Mission Control behavior

**What changed:** The old code used `.canJoinAllSpaces` + `.stationary` with manual `.floating` level. The new `GraphOverlayPanel` uses `[.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle, .stationary]`. Key differences:
- `.moveToActiveSpace` replaces `.canJoinAllSpaces` — follows user between spaces rather than appearing on ALL spaces
- `.ignoresCycle` — excluded from ⌘~ window cycling (the panel shouldn't be in the tab order)
- `.stationary` is kept — prevents Mission Control from moving the overlay independently

**Verify manually:**
1. Open the graph overlay (Cmd+G)
2. Trigger Mission Control (Ctrl+Up or three-finger swipe up)
3. The overlay should move WITH the main window as a group, not float independently
4. Switch spaces — the overlay should follow (`.moveToActiveSpace`)
5. Press ⌘~ — the overlay should NOT appear in the window cycle (`.ignoresCycle`)

---

## Phase 5: Fix Metal View Reparenting (The Big One)

### Task 6: Eliminate Metal view reparenting in minimize/restore

**Files:**
- Modify: `Epistemos/Views/Graph/HologramOverlay.swift`

**The current problem:** `minimize()` calls `metalView.removeFromSuperview()` then adds it to the mini panel. `restore()` does the reverse. This causes:
- Metal drawable size mismatches (brief render artifacts)
- Race conditions if the engine is ticking during reparent
- Edge case at line 270-274 where the overlay window is "lost"

**The fix:** Keep the MetalGraphNSView in the full-screen panel always. For mini mode, just resize the panel and change its style. No reparenting.

**Rewrite `minimize()`:**
```swift
func minimize() {
    guard let metalView, let window, !isMinimized else { return }

    isMinimized = true

    // 1. Remove child window relationship (re-add with mini frame).
    if let parent = window.parent {
        parent.removeChildWindow(window)
    }

    // 2. Hide blur/darken/controls (they're subviews of window.contentView).
    blurView?.isHidden = true
    darkenLayer?.isHidden = true
    // Hide all subviews except metalView.
    for subview in window.contentView?.subviews ?? [] {
        if subview !== metalView {
            subview.isHidden = true
        }
    }

    // 3. Configure window for mini mode.
    window.styleMask = [.nonactivatingPanel, .borderless, .resizable]
    window.hasShadow = true
    window.level = .floating
    metalView.isMiniMode = true

    // 4. Animate frame change to mini size in bottom-right.
    let miniFrame: NSRect
    if let screen = NSScreen.main {
        let x = screen.visibleFrame.maxX - 520
        let y = screen.visibleFrame.minY + 20
        miniFrame = NSRect(x: x, y: y, width: 500, height: 380)
    } else {
        miniFrame = NSRect(x: 100, y: 100, width: 500, height: 380)
    }

    // Add frosted glass background for mini mode.
    let miniBlur = NSVisualEffectView(frame: window.contentView!.bounds)
    miniBlur.material = .hudWindow
    miniBlur.blendingMode = .behindWindow
    miniBlur.state = .active
    miniBlur.autoresizingMask = [.width, .height]
    miniBlur.tag = 999 // Tag for easy removal on restore
    window.contentView!.addSubview(miniBlur, positioned: .below, relativeTo: metalView)

    // Round corners for mini mode.
    window.contentView!.wantsLayer = true
    window.contentView!.layer?.cornerRadius = 16
    window.contentView!.layer?.masksToBounds = true

    NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.3
        ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        window.animator().setFrame(miniFrame, display: true)
    }

    addExpandButton(to: window)

    // Re-attach as child.
    if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is GraphOverlayPanel) }) {
        mainWindow.addChildWindow(window, ordered: .above)
    }

    observeNodeSelection()
}
```

**Rewrite `restore()`:**
```swift
func restore() {
    guard let metalView, let window, isMinimized else { return }

    isMinimized = false
    metalView.isMiniMode = false

    // 1. Remove child relationship.
    if let parent = window.parent {
        parent.removeChildWindow(window)
    }

    // 2. Remove mini-mode additions (blur with tag 999, expand button).
    window.contentView?.subviews
        .filter { $0.tag == 999 || $0 is NSHostingView<AnyView> }
        .forEach { $0.removeFromSuperview() }
    // Note: be careful not to remove the inspector hosting view.
    // The expand button hosting view is small and identifiable.

    // 3. Un-hide full-screen subviews.
    blurView?.isHidden = false
    darkenLayer?.isHidden = false
    for subview in window.contentView?.subviews ?? [] {
        subview.isHidden = false
    }

    // 4. Remove corner radius.
    window.contentView?.layer?.cornerRadius = 0
    window.contentView?.layer?.masksToBounds = false

    // 5. Animate frame change to full screen.
    window.hasShadow = false
    guard let screen = NSScreen.main else { return }

    NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.3
        ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        window.animator().setFrame(screen.frame, display: true)
    }

    window.makeFirstResponder(metalView)

    // Re-attach as child.
    if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is GraphOverlayPanel) }) {
        mainWindow.addChildWindow(window, ordered: .above)
    }
}
```

**Important:** This eliminates `self.miniPanel` entirely for the minimize/restore flow. The same `self.window` panel transitions between full-screen and mini sizes. The `miniPanel` property and `createMiniPanel()` are still needed for `showMini()` (cold start in mini mode from command palette), but minimize/restore no longer create/destroy separate windows.

**Verify:** Build. Open overlay (Cmd+G). Click minimize. The window should smoothly shrink to bottom-right with rounded corners and blur. Click expand. It should smoothly grow back to full screen. The Metal view should render continuously without flicker during both transitions.

---

## Phase 6: Delete Dead Code

### Task 7: Clean up

**Files:**
- Modify: `Epistemos/Views/Graph/HologramOverlay.swift`

1. Delete the `KeyableWindow` class (if not already deleted in Task 2).

2. The `miniPanel` property is now only used for `showMini()` (cold start). Update `showMini()` to use `GraphOverlayPanel` instead of `KeyableWindow`.

3. In `teardown()`, the `miniPanel` cleanup is still needed for `showMini()` flow. Keep it.

4. Remove the `.stationary` collection behavior from any remaining code.

**Verify:** Full test pass:
```bash
cd graph-engine && cargo test
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

---

## Phase 7: Manual Testing Checklist

Run through ALL of these scenarios after implementation:

- [ ] **Cmd+G toggle:** Opens overlay, Cmd+G again closes it
- [ ] **Escape dismiss:** Overlay closes on Escape (unless a text field is focused)
- [ ] **Cmd+W dismiss:** Overlay closes on Cmd+W
- [ ] **Minimize → Restore:** Shrinks to bottom-right, expands back. No flicker.
- [ ] **Mini mode graph interaction:** Can drag nodes, hover, click in mini mode
- [ ] **Mission Control:** Overlay follows main window during Mission Control
- [ ] **Space switching:** Overlay appears only on the space with the main window
- [ ] **Fullscreen enter:** Overlay hides during transition, reappears after
- [ ] **Fullscreen exit:** Overlay reappears after exiting fullscreen
- [ ] **Parent minimize:** Minimize main window (Cmd+M) — overlay hides. Restore — overlay reappears.
- [ ] **Multiple displays:** Move main window to second display, Cmd+G opens overlay on that display
- [ ] **Note window tracking:** In page mode, overlay tracks note window movement
- [ ] **Command palette mini:** showMini() from command palette works
- [ ] **Light/dark mode:** Overlay respects system appearance changes
- [ ] **Memory:** Open/close overlay 10 times, check for leaks (Instruments or Activity Monitor)
- [ ] **Key window:** Clicking in the overlay panel does NOT steal main window status. Verify by checking `NSApp.mainWindow` after clicking the overlay.

---

## Gotchas

1. **`becomesKeyOnlyIfNeeded`** — NSPanel has this property. Set it to `true` if you find the panel is stealing key window status on every click. But it might break text field focus in the search sidebar. Test both ways.

2. **`addChildWindow` timing** — The main window must exist and be visible when you call `addChildWindow`. If the overlay is created before the main window (race at app launch), defer the child attachment.

3. **Metal drawable scale** — When moving between displays with different scales (Retina vs non-Retina), the Metal layer's `contentsScale` needs updating. `MetalGraphNSView` should already handle this via `viewDidChangeBackingProperties()`. Verify by dragging the mini panel between displays.

4. **`orderOut` vs `close`** — Always use `orderOut(nil)` to hide, never `close()`. `close()` can trigger `isReleasedWhenClosed` behavior and permanently destroy the window.

5. **The mini inspector panel** (`miniInspectorPanel`) is a separate window shown alongside the mini graph. It needs the same `GraphOverlayPanel` treatment and child window attachment. Don't forget it.

6. **`showMini()` creates MetalGraphNSView from scratch** — This is the cold-start path from the command palette. It doesn't go through `createWindow()`. Make sure it also uses `GraphOverlayPanel` and attaches as a child window.

7. **`.ignoresCycle`** — This excludes the panel from ⌘~ window cycling. Without it, users cycling through windows will land on the overlay panel, which feels broken. Always include this in `collectionBehavior`.

8. **Parent minimize vs overlay minimize** — These are different events. The *parent* minimizing to Dock (Cmd+M) should hide the overlay via `orderOut`. The *overlay* minimizing to mini float is an internal state change (frame resize). Don't confuse the two code paths.
