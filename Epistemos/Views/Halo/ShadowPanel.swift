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
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        // BLUR POLICY (2026-05-20 single-blur-per-window contract):
        // ONE NSVisualEffectView at the panel's contentView level. The
        // SwiftUI content hosted inside renders as tinted overlay only —
        // no `.ultraThinMaterial` / `.glassEffect` / nested visual-effect.
        // Matches HologramOverlay's contract; keeps the CoreAnimation
        // compositor at a single blur kernel per frame for the Halo too.
        //
        // Wrap order (top → bottom in z-order):
        //   1. NSHostingView<Content>  — SwiftUI Halo content (tinted)
        //   2. NSVisualEffectView      — the ONE Halo blur
        //   3. NSPanel.contentView     — root container
        let container = NSView(frame: rect)
        container.wantsLayer = true
        container.layer?.cornerRadius = 22
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        let blur = NSVisualEffectView(frame: container.bounds)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .followsWindowActiveState
        blur.autoresizingMask = [.width, .height]
        container.addSubview(blur)

        let hosting = NSHostingView(rootView: content())
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = container.bounds
        container.addSubview(hosting)

        self.contentView = container
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
            let p = ShadowPanel(content: content)
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
            p = ShadowPanel(content: content)
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
