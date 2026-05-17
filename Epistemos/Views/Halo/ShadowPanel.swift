import AppKit
import SwiftUI

// MARK: - ShadowPanel
//
// Wave 8.5 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"UI" + §"Concurrency").
//
// AppKit panel that hosts the SwiftUI Halo content. Per the V1 decision:
//   - `.nonactivatingPanel` style mask so clicking the panel does NOT
//     steal main-window status from the editor — the editor keeps the
//     caret + key focus while the user interacts with the Halo.
//   - `becomesKeyOnlyIfNeeded = true` for inline edit affordances.
//   - `canBecomeMain = false` permanently.
//   - Hosts SwiftUI content via NSHostingView.
//
// Default size 360×480 matches the reference at
// `ambient/HaloController.swift` and the V1 budget that caps panel
// width at 480 px to keep ultraThinMaterial blur cost under 2 ms/frame.

/// Generic NSPanel container for the Halo's SwiftUI content.
@MainActor
public final class ShadowPanel<Content: View>: NSPanel {

    public init(
        rect: NSRect = NSRect(x: 0, y: 0, width: 360, height: 480),
        @ViewBuilder content: () -> Content
    ) {
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isFloatingPanel = true
        self.level = .floating
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.animationBehavior = .utilityWindow
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.contentView = NSHostingView(rootView: content())
    }

    /// Allow the panel to become key (so inline TextEditors inside it
    /// receive keyboard input) while NEVER becoming main (so the editor
    /// behind it keeps `keyWindow` status).
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}

// MARK: - ShadowPanelController
//
// Owns the lifecycle of the Halo panel + a window-key observer that dismisses
// it after focus leaves the panel. Per the V1 decision §"Concurrency":
// @MainActor — touches NSPanel / NSWindow state.

/// Controller that shows / hides the Halo's `ShadowPanel`. The panel
/// itself is created lazily on first `show(...)` and reused for the
/// lifetime of the controller.
@MainActor
public final class ShadowPanelController {

    private var panel: NSPanel?
    private var outsideClickObserver: NSObjectProtocol?
    private let onOutsideClick: @MainActor () -> Void

    /// UI/UX audit 2026-05-17 P2-3 (iter 4): persist the Halo panel's
    /// user-resized frame size across app relaunches. Previously the
    /// controller's per-session reuse only preserved size *within* a
    /// session; a fresh app launch reverted to the default 360×480.
    /// UserDefaults keys live under `epistemos.halo.panelSize.*` so a
    /// reset-everything sweep clears them via prefix grep.
    private enum FrameKeys {
        static let width = "epistemos.halo.panelSize.width"
        static let height = "epistemos.halo.panelSize.height"
    }

    /// Default panel size when no persisted size exists. Matches the
    /// V1 budget cap (≤ 480 px wide for ultraThinMaterial blur cost
    /// ≤ 2 ms/frame) and the original ShadowPanel.init default.
    private static let defaultPanelSize = NSSize(width: 360, height: 480)

    /// Read the persisted panel size from UserDefaults, falling back to
    /// the V1 default. Clamps to a sane min so a corrupted defaults
    /// store can't shrink the panel into invisibility.
    private static func persistedPanelSize(
        defaults: UserDefaults = .standard
    ) -> NSSize {
        let width = defaults.object(forKey: FrameKeys.width) as? Double ?? Double(defaultPanelSize.width)
        let height = defaults.object(forKey: FrameKeys.height) as? Double ?? Double(defaultPanelSize.height)
        let clampedWidth = max(240, min(1200, width))
        let clampedHeight = max(320, min(1200, height))
        return NSSize(width: clampedWidth, height: clampedHeight)
    }

    /// Write the panel's current size to UserDefaults. Called on hide()
    /// so the user's resize survives the next launch.
    private static func persistPanelSize(
        _ size: NSSize,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(Double(size.width), forKey: FrameKeys.width)
        defaults.set(Double(size.height), forKey: FrameKeys.height)
    }

    public init(onOutsideClick: @MainActor @escaping () -> Void) {
        self.onOutsideClick = onOutsideClick
    }

    /// Whether the panel is currently visible. Surfaced for tests +
    /// the developer panel.
    public var isVisible: Bool {
        panel?.isVisible == true
    }

    /// Show the panel, lazily creating it from the supplied view
    /// builder on first call. Subsequent calls reuse the same panel
    /// (so its position + size persist across opens).
    ///
    /// FALLBACK ENTRY: this overload centers the panel on the active
    /// screen, which violates the V1 doctrine constraint
    /// (`ambient_V1_DECISION.md` §UI: "anchored to the editor's
    /// trailing edge"). Production callers should use
    /// `show(anchorRect:content:)` below; this signature is retained
    /// for tests + cold-path fallbacks where no editor anchor is
    /// available.
    public func show<Content: View>(@ViewBuilder content: () -> Content) {
        if panel == nil {
            let size = Self.persistedPanelSize()
            let p = ShadowPanel(rect: NSRect(origin: .zero, size: size), content: content)
            p.center()
            panel = p
        }
        panel?.makeKeyAndOrderFront(nil)
        attachOutsideClickMonitor()
    }

    /// Show the panel anchored to the editor's trailing edge — V1
    /// doctrine canonical entry point per `ambient_V1_DECISION.md`
    /// §UI. `anchorRect` is the editor's bounding rect in **screen
    /// coordinates** (use `NSTextView.firstRect(forCharacterRange:)`
    /// or `view.window?.convertToScreen(view.bounds)` to obtain).
    ///
    /// Positioning rules (`Self.panelOrigin(forAnchorRect:...)`):
    ///   1. Default — place panel just right of the anchor, top-aligned.
    ///   2. If the panel would overflow the screen's trailing edge,
    ///      flip to the leading side of the anchor.
    ///   3. If the panel would overflow vertically, clamp to the
    ///      visible frame.
    ///
    /// On subsequent shows the panel reuses its existing instance and
    /// re-anchors via `setFrameOrigin(...)` — the size persists across
    /// opens so a user-resized panel stays user-sized.
    public func show<Content: View>(
        anchorRect: NSRect,
        @ViewBuilder content: () -> Content
    ) {
        let p: ShadowPanel<Content>
        if let existing = panel as? ShadowPanel<Content> {
            p = existing
        } else {
            let size = Self.persistedPanelSize()
            p = ShadowPanel(rect: NSRect(origin: .zero, size: size), content: content)
            panel = p
        }
        let screenFrame =
            NSScreen.screens.first(where: { $0.frame.intersects(anchorRect) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let origin = Self.panelOrigin(
            forAnchorRect: anchorRect,
            panelSize: p.frame.size,
            in: screenFrame
        )
        p.setFrameOrigin(origin)
        p.makeKeyAndOrderFront(nil)
        attachOutsideClickMonitor()
    }

    /// Compute the canonical panel origin for a given anchor rect,
    /// panel size, and visible screen frame. Pure function — extracted
    /// so the positioning rules are testable without spinning up an
    /// NSPanel. macOS coordinate space: origin at lower-left, y grows
    /// upward.
    ///
    /// Rule order:
    ///   1. Try trailing-edge: `x = anchor.maxX + horizontalGap`,
    ///      `y = anchor.maxY - panelSize.height` (top-aligned).
    ///   2. If the trailing side overflows the screen's `maxX`, place
    ///      the panel on the leading side instead:
    ///      `x = anchor.minX - panelSize.width - horizontalGap`.
    ///   3. Clamp the result horizontally + vertically into the
    ///      `screen` frame so the panel is always fully visible.
    public static func panelOrigin(
        forAnchorRect anchor: NSRect,
        panelSize: NSSize,
        in screen: NSRect,
        horizontalGap: CGFloat = 8
    ) -> NSPoint {
        // Step 1: trailing-edge preference.
        var x = anchor.maxX + horizontalGap
        var y = anchor.maxY - panelSize.height

        // Step 2: flip to leading edge if trailing overflows.
        if x + panelSize.width > screen.maxX {
            x = anchor.minX - panelSize.width - horizontalGap
        }

        // Step 3: horizontal clamp (after the flip; if neither side
        // fits we err toward the screen's right edge so the leading
        // characters of the panel are visible).
        if x < screen.minX {
            x = screen.minX
        } else if x + panelSize.width > screen.maxX {
            x = screen.maxX - panelSize.width
        }

        // Step 4: vertical clamp.
        if y + panelSize.height > screen.maxY {
            y = screen.maxY - panelSize.height
        }
        if y < screen.minY {
            y = screen.minY
        }

        return NSPoint(x: x, y: y)
    }

    /// Hide the panel and detach the outside-click monitor.
    public func hide() {
        if let frame = panel?.frame {
            Self.persistPanelSize(frame.size)
        }
        panel?.orderOut(nil)
        detachOutsideClickObserver()
    }

    /// Tear down the panel entirely (used at app shutdown / window close).
    public func dismiss() {
        hide()
        panel = nil
    }

    deinit {
        // The observer is explicitly detached on hide/dismiss. If process
        // teardown wins the race, NotificationCenter tears down with it.
    }

    // MARK: - Outside click observer

    private func attachOutsideClickMonitor() {
        detachOutsideClickObserver()
        guard let activePanel = panel else { return }
        outsideClickObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: activePanel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.panel?.isVisible == true else { return }
                self.onOutsideClick()
            }
        }
    }

    private func detachOutsideClickObserver() {
        if let observer = outsideClickObserver {
            NotificationCenter.default.removeObserver(observer)
            outsideClickObserver = nil
        }
    }
}
