import SwiftUI
import SwiftData
import AppKit

enum GraphMiniPanelLayout {
    static let defaultSide: CGFloat = 620
    static let screenPadding: CGFloat = 24

    static func frame(in visibleFrame: NSRect) -> NSRect {
        let availableSquare = max(240, min(visibleFrame.width, visibleFrame.height) - screenPadding * 2)
        let side = min(defaultSide, availableSquare)
        // Pin to the right edge of the screen so the left side stays clear
        // for the note editor window.
        let x = visibleFrame.maxX - side - screenPadding
        let y = min(
            max(visibleFrame.midY - side * 0.5, visibleFrame.minY + screenPadding),
            visibleFrame.maxY - side - screenPadding
        )
        return NSRect(x: x, y: y, width: side, height: side).integral
    }
}

enum GraphOverlayThemeStyle {
    static let miniTintIdentifier = NSUserInterfaceItemIdentifier("graphMiniTint")

    static func resolvedTheme(
        uiState: UIState? = AppBootstrap.shared?.uiState,
        explicitTheme: EpistemosTheme? = nil,
        fallbackIsDark: Bool? = nil
    ) -> EpistemosTheme {
        if let explicitTheme {
            return explicitTheme
        }
        if let theme = uiState?.graphOverlayTheme {
            return theme
        }
        let isDark = fallbackIsDark ?? SystemAppearanceState.isDark()
        return isDark ? .systemDark : .systemLight
    }

    static func windowAppearance(for theme: EpistemosTheme) -> NSAppearance? {
        NSAppearance(named: appearanceName(for: theme))
    }

    static func appearanceName(for theme: EpistemosTheme) -> NSAppearance.Name {
        theme.isDark ? .darkAqua : .aqua
    }

    static func blurMaterial(for theme: EpistemosTheme) -> NSVisualEffectView.Material {
        // .hudWindow is the true floating-glass material and adapts to theme.
        // .sheet (previously used in light mode) is a flat opaque slab — wrong for a glass float.
        .hudWindow
    }

    static func overlayTintColor(for theme: EpistemosTheme) -> NSColor {
        // Light glaze over the hudWindow blur. Kept minimal so the blur shows through
        // as true glass instead of being hidden behind an opaque tint.
        theme.isDark
            ? NSColor.black.withAlphaComponent(0.32)
            : NSColor.white.withAlphaComponent(0.72)
    }

    static func miniTintColor(for theme: EpistemosTheme) -> NSColor {
        // Mini panel is the "glass float" — tint is just a whisper of color so
        // the NSVisualEffectView blur defines the look.
        theme.isDark
            ? NSColor.black.withAlphaComponent(0.22)
            : NSColor.white.withAlphaComponent(0.65)
    }

    static func lightModeEnabled(for theme: EpistemosTheme) -> Bool {
        !theme.isDark
    }
}

nonisolated enum GraphOverlayHideAction: Equatable {
    case teardownImmediately
    case pauseThenTeardownAfterDelay
}

nonisolated enum GraphOverlayRetentionPolicy {
    static let hiddenTeardownDelay: Duration = .seconds(10)

    static func hideAction(isMinimized: Bool) -> GraphOverlayHideAction {
        isMinimized ? .teardownImmediately : .pauseThenTeardownAfterDelay
    }
}

private struct GraphOverlayThemeContainer<Content: View>: View {
    @Environment(UIState.self) private var ui
    let content: Content

    var body: some View {
        content.preferredColorScheme(ui.graphOverlayTheme.colorScheme)
    }
}

enum HologramOverlayHostedViewBuilder {
    @MainActor
    static func root<Content: View>(
        _ content: Content,
        bootstrap: AppBootstrap? = AppBootstrap.shared
    ) -> AnyView {
        guard let bootstrap else {
            return AnyView(content)
        }

        return AnyView(
            GraphOverlayThemeContainer(content: content)
                .withAppEnvironment(bootstrap)
                .modelContainer(bootstrap.modelContainer)
        )
    }
}

@MainActor
private final class ObservationChangeWaiter {
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasResumed = false

    func wait(observe: () -> Void) async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                self.hasResumed = false
                withObservationTracking {
                    observe()
                } onChange: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.resumeIfNeeded()
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resumeIfNeeded()
            }
        }
    }

    private func resumeIfNeeded() {
        guard !hasResumed else { return }
        hasResumed = true
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }
}

// MARK: - HologramOverlay
// Full-screen borderless NSWindow that renders the knowledge graph
// on top of a heavy frosted-glass blur. Triggered by a global hotkey.
//
// Architecture:
// - NSWindow: borderless, immersive topmost level, full-screen
// - Background: NSVisualEffectView with .hudWindow material
// - Content: MetalGraphView fills the entire screen
// - Controls: GraphFloatingControls pill bar at bottom
// - Search:   HologramSearchSidebar floating panel on the left
// - Animation: Scale + fade from center on show, reverse on hide

@MainActor
final class HologramOverlay {

    private var window: GraphOverlayPanel?
    private var metalView: MetalGraphNSView?
    private var inspectorHostView: NSHostingView<AnyView>?
    private var escapeMonitor: Any?
    private var graphState: GraphState
    private var queryEngine: QueryEngine
    private var modelContainer: ModelContainer?
    private var physicsCoordinator: PhysicsCoordinator?
    private var dialogueChatState: DialogueChatState?
    private let inspectorState = NodeInspectorState()
    /// Pinned inspectors: persistent panels attached to specific nodes.
    /// Each gets its own NSHostingView positioned at node screen coords.
    private var pinnedInspectorViews: [String: NSHostingView<AnyView>] = [:]

    // Blur transition layers (stored for page mode animation).
    private var darkenLayer: NSView?
    private var blurView: NSVisualEffectView?

    // Note window frame for anchor positioning (page mode only).
    private var noteWindowFrame: NSRect?
    // Observation tokens for tracking note window movement.
    private var noteWindowMoveObserver: Any?
    private var noteWindowResizeObserver: Any?
    // KVO observation for system appearance (light/dark mode) changes.
    private var appearanceObserver: NSKeyValueObservation?
    // Draggable toolbar and sidebar hosting views.
    private var controlsHostView: NSHostingView<AnyView>?
    private var sidebarHostView: NSHostingView<AnyView>?
    private var controlsConstraints: [NSLayoutConstraint] = []
    private var sidebarConstraints: [NSLayoutConstraint] = []

    // Mini floating panel (chromeless glass float).
    private var miniPanel: GraphOverlayPanel?
    /// Companion panel: holds the inspector alongside the mini graph when minimized.
    private var miniInspectorPanel: GraphOverlayPanel?
    private(set) var isMinimized = false
    private var selectionObserverTask: Task<Void, Never>?
    private var inspectorPositionTask: Task<Void, Never>?
    /// Dedicated timer for pinned panel position tracking. Runs at ~30fps
    /// independently of node selection so pinned panels follow their nodes
    /// even when nothing is selected. Started when overlay shows, stopped on hide.
    private var pinnedPanelTimer: Timer?
    private var inspectorRepositionTask: Task<Void, Never>?
    private var lastInspectorFrame: CGRect?
    private var lastQueuedInspectorAnchor: CGPoint?
    private var lastQueuedInspectorMode: NodeInspectorState.InspectorMode?
    private var minimizeObserver: Any?
    private var resetObserver: Any?
    private var restoreObserver: Any?
    private var closeObserver: Any?
    private var hiddenTeardownTask: Task<Void, Never>?

    // Fullscreen transition observers
    private var fullscreenEnterObserver: Any?
    private var fullscreenExitObserver: Any?
    private var fullscreenDidEnterObserver: Any?
    // Parent window miniaturize observers
    private var parentMiniaturizeObserver: Any?
    private var parentDeminiaturizeObserver: Any?
    /// True after the overlay has been shown at least once this session.
    /// The very first open uses a longer delay to hide engine initialization.
    private var hasShownBefore = false
    private var fadeInTask: Task<Void, Never>?
    private let firstOpenTitleHost = GraphFirstOpenTitleHost()

    init(graphState: GraphState, queryEngine: QueryEngine, modelContainer: ModelContainer?, physicsCoordinator: PhysicsCoordinator? = nil, dialogueChatState: DialogueChatState? = nil) {
        self.graphState = graphState
        self.queryEngine = queryEngine
        self.modelContainer = modelContainer
        self.physicsCoordinator = physicsCoordinator
        self.dialogueChatState = dialogueChatState
        observeMinimizeNotifications()
    }


    // MARK: - Show / Hide

    var isVisible: Bool {
        (window?.isVisible == true) || isMinimized
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show(noteWindow: NSWindow? = nil) {
        cancelScheduledTeardown()
        self.noteWindowFrame = noteWindow?.frame

        if isMinimized {
            restore()
            return
        }

        // Fast path: if engine is still alive from a soft-hide, just resume + show.
        if let window, let metalView {
            restoreImmersiveChromeIfNeeded(window, metalView: metalView)
            prepareImmersiveOverlayWindow(window, screen: NSScreen.main)
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            window.makeFirstResponder(metalView)
            metalView.resumeEngine()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1.0
            }
            // Title overlay on fast-path: supports everyOpen mode even when
            // the engine is still warm from a soft-hide.
            if graphState.graphTitleMode == .everyOpen,
               let contentView = window.contentView {
                let theme = GraphOverlayThemeStyle.resolvedTheme()
                firstOpenTitleHost.install(in: contentView, isDark: theme.isDark)
            }
            // Restart pinned panel timer — it was stopped on hide/teardown.
            startPinnedPanelTimer()
            return
        }

        // Cold start: create everything from scratch.
        createWindow()

        guard let window else { return }

        prepareImmersiveOverlayWindow(window, screen: NSScreen.main)

        // Page mode: lighter blur (nodes "break out" of the overlay).
        let isPageMode: Bool = {
            if case .page = graphState.mode { return true }
            return false
        }()
        if isPageMode {
            let theme = GraphOverlayThemeStyle.resolvedTheme()
            darkenLayer?.alphaValue = theme.isDark ? 0.22 : 0.10
            blurView?.material = GraphOverlayThemeStyle.blurMaterial(for: theme)
        }

        // Track note window movement so nodes follow it in real time.
        if let noteWindow, isPageMode {
            observeNoteWindow(noteWindow)
        }

        // Entrance animation: fade in from zero opacity.
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Make Metal view first responder for keyboard zoom (Cmd+/-/0).
        if let metalView {
            window.makeFirstResponder(metalView)
        }

        // On the very first open, delay the fade-in so the engine has time to
        // create Metal pipelines, load graph data, and run the initial commit.
        // This hides the initialization freeze behind a smooth transition.
        // Subsequent opens reuse the cached engine and skip this delay.
        let isFirstOpen = !hasShownBefore
        hasShownBefore = true
        let fadeDelay: TimeInterval = isFirstOpen ? 0.6 : 0.0

        let fadeDuration = isFirstOpen ? 0.5 : 0.3
        fadeInTask?.cancel()
        fadeInTask = Task { @MainActor [weak self, weak window] in
            if fadeDelay > 0 {
                try? await Task.sleep(for: .seconds(fadeDelay))
            }
            guard !Task.isCancelled, let window else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = fadeDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1.0
            }, completionHandler: {})
            // Title overlay — show on first or every open depending on user setting.
            if let self, let contentView = window.contentView {
                let shouldShow: Bool = {
                    switch self.graphState.graphTitleMode {
                    case .off: return false
                    case .firstOpen: return isFirstOpen
                    case .everyOpen: return true
                    }
                }()
                if shouldShow {
                    let theme = GraphOverlayThemeStyle.resolvedTheme()
                    self.firstOpenTitleHost.install(in: contentView, isDark: theme.isDark)
                }
            }
            self?.fadeInTask = nil
        }
    }

    /// Observe note window move/resize to dynamically update the anchor rect.
    private func observeNoteWindow(_ noteWindow: NSWindow) {
        let updateBlock: @Sendable (Notification) -> Void = { [weak self, weak noteWindow] _ in
            MainActor.assumeIsolated {
                guard let self, let noteWindow, let metalView = self.metalView else { return }
                self.noteWindowFrame = noteWindow.frame
                metalView.setAnchorRect(noteWindow.frame)
            }
        }
        noteWindowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: noteWindow,
            queue: .main,
            using: updateBlock
        )
        noteWindowResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: noteWindow,
            queue: .main,
            using: updateBlock
        )
    }

    private func cancelScheduledTeardown() {
        hiddenTeardownTask?.cancel()
        hiddenTeardownTask = nil
    }

    private func scheduleHiddenTeardown() {
        cancelScheduledTeardown()
        hiddenTeardownTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: GraphOverlayRetentionPolicy.hiddenTeardownDelay)
                guard let self else { return }
                guard !self.isMinimized, self.window?.isVisible != true else { return }
                self.teardown()
            } catch is CancellationError {
                return
            } catch {
                Log.graph.error(
                    "Scheduled graph overlay teardown failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func hide() {
        fadeInTask?.cancel()
        fadeInTask = nil
        switch GraphOverlayRetentionPolicy.hideAction(isMinimized: isMinimized) {
        case .teardownImmediately:
            // Minimized: fade out the mini panel and do full teardown.
            guard let miniPanel else { teardown(); return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                miniPanel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.teardown()
                }
            })
        case .pauseThenTeardownAfterDelay:
            guard let window else { return }

            // Soft hide: pause engine + hide window, keep engine alive briefly for fast re-show.
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    window.orderOut(nil)
                    self?.metalView?.pauseEngine()
                    self?.scheduleHiddenTeardown()
                }
            })
        }
    }

    /// Full teardown: destroy engine + Metal resources to free all memory.
    /// Call when the overlay is being permanently dismissed (e.g. app quit).
    func forceClose() {
        cancelScheduledTeardown()
        if let window {
            window.orderOut(nil)
        }
        teardown()
    }

    // MARK: - Minimize / Restore

    /// Shrink the full-screen overlay into a chromeless glass float.
    /// The same window transforms to mini mode — no Metal view reparenting.
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
        window.applyPresentation(.floatingPanel)
        metalView.isMiniMode = true

        // 4. Animate frame change to mini size in bottom-right.
        let miniFrame: NSRect
        if let screen = NSScreen.main {
            miniFrame = GraphMiniPanelLayout.frame(in: screen.visibleFrame)
        } else {
            miniFrame = NSRect(x: 100, y: 100, width: GraphMiniPanelLayout.defaultSide, height: GraphMiniPanelLayout.defaultSide)
        }

        // Add frosted glass background for mini mode.
        guard let contentView = window.contentView else { return }
        let miniBlur = NSVisualEffectView(frame: contentView.bounds)
        miniBlur.material = GraphOverlayThemeStyle.blurMaterial(
            for: GraphOverlayThemeStyle.resolvedTheme()
        )
        miniBlur.blendingMode = .behindWindow
        miniBlur.state = .active
        miniBlur.autoresizingMask = [.width, .height]
        miniBlur.identifier = NSUserInterfaceItemIdentifier("miniBlur") // Identifier for easy removal on restore
        contentView.addSubview(miniBlur, positioned: .below, relativeTo: metalView)

        // Round corners for mini mode.
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 16
        contentView.layer?.masksToBounds = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(miniFrame, display: true)
        }

        addExpandButton(to: window)

        // Re-attach as child.
        attachFloatingPanelToMainWindow(window)

        // Alias the full-screen window as miniPanel so downstream code
        // (inspector, escape handler, first responder queries) works.
        self.miniPanel = window

        window.makeFirstResponder(metalView)
        observeNodeSelection()
        startPinnedPanelTimer()
    }

    /// Restore the mini panel back to the full-screen overlay.
    /// The same window transforms to full-screen — no Metal view reparenting.
    func restore() {
        guard let metalView, let window, isMinimized else { return }

        // Cold-started in mini mode (e.g., via command palette) — no full-screen window exists.
        // Clean teardown, then ask HologramController to create everything fresh.
        if self.window == nil {
            teardown()
            HologramController.shared.show()
            return
        }

        isMinimized = false
        metalView.isMiniMode = false
        miniPanel = nil  // Clear alias set by minimize()

        // 1. Remove child relationship.
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }

        // 2. Remove mini-mode additions (blur with tag 999, expand button).
        window.contentView?.subviews
            .filter { $0.identifier == NSUserInterfaceItemIdentifier("miniBlur") || ($0 is NSHostingView<AnyView> && $0.frame.width < 100) }
            .forEach { $0.removeFromSuperview() }

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
        window.applyPresentation(.immersiveOverlay)
        guard let screen = NSScreen.main else { return }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(screen.frame, display: true)
        }

        window.orderFrontRegardless()
        window.makeFirstResponder(metalView)

        // Hide mini inspector if shown
        if let inspector = miniInspectorPanel {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                inspector.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.miniInspectorPanel?.orderOut(nil as NSWindow?)
                    self?.miniInspectorPanel = nil
                }
            })
        }
    }

    // MARK: - Show Mini (Cold Start)

    /// Show the graph directly in mini mode without creating a full-screen window.
    /// Used by the command palette to display the graph as a companion panel.
    func showMini() {
        cancelScheduledTeardown()
        // Already minimized and visible — nothing to do.
        if isMinimized, miniPanel?.isVisible == true { return }

        // Full-screen overlay visible — minimize it instead.
        if window?.isVisible == true {
            minimize()
            return
        }

        if window != nil || metalView != nil {
            teardown()
        }

        // Re-register observers if needed (teardown removes them).
        if minimizeObserver == nil { observeMinimizeNotifications() }

        let theme = GraphOverlayThemeStyle.resolvedTheme()

        // Create MetalGraphNSView directly in mini mode (no full-screen window).
        let graphView = MetalGraphNSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: GraphMiniPanelLayout.defaultSide,
                height: GraphMiniPanelLayout.defaultSide
            )
        )
        graphView.graphState = graphState
        graphView.physicsCoordinator = physicsCoordinator
        graphView.dialogueChatState = dialogueChatState
        graphView.isOverlayMode = true
        graphView.setLightMode(GraphOverlayThemeStyle.lightModeEnabled(for: theme))
        graphView.isMiniMode = true
        self.metalView = graphView

        let panel = createMiniPanel()
        self.miniPanel = panel

        // Attach as child of main app window for proper z-ordering.
        attachFloatingPanelToMainWindow(panel)

        guard let panelContentView = panel.contentView else { return }
        graphView.autoresizingMask = [.width, .height]
        graphView.frame = panelContentView.bounds
        panelContentView.addSubview(graphView)

        addExpandButton(to: panel)

        isMinimized = true

        // Fade in — orderFront (not makeKey) so the command palette keeps focus.
        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }

        // Commit graph data after the panel is laid out.
        Task { @MainActor [weak self] in
            guard let self, self.graphState.isLoaded else { return }
            graphView.setGraphMode(0) // global mode
            graphView.commitGraphData()
            graphView.lastGraphDataVersion = self.graphState.graphDataVersion
        }

        // Observe system appearance changes.
        if appearanceObserver == nil {
            appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.syncTheme()
                }
            }
        }

        // Observe node selection to lazily show/hide inspector.
        observeNodeSelection()
        startPinnedPanelTimer()
    }

    // MARK: - Mini Panel Creation

    private func createMiniPanel() -> GraphOverlayPanel {
        let panel = GraphOverlayPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: GraphMiniPanelLayout.defaultSide,
                height: GraphMiniPanelLayout.defaultSide
            )
        )
        panel.applyPresentation(.floatingPanel)
        panel.minSize = NSSize(width: 320, height: 320)
        panel.maxSize = NSSize(width: 1200, height: 900)

        // Position: centered with a slight right bias.
        if let screen = NSScreen.main {
            panel.setFrame(GraphMiniPanelLayout.frame(in: screen.visibleFrame), display: true)
        }

        // Frosted glass blur box with rounded corners.
        guard let panelContentView = panel.contentView else { return panel }
        let content = NSView(frame: panelContentView.bounds)
        content.wantsLayer = true
        content.layer?.cornerRadius = 16
        content.layer?.masksToBounds = true

        // Blur background — adapts to system light/dark mode.
        let blur = NSVisualEffectView(frame: content.bounds)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        content.addSubview(blur)

        // Subtle tint overlay for depth.
        let tint = NSView(frame: content.bounds)
        tint.wantsLayer = true
        tint.identifier = GraphOverlayThemeStyle.miniTintIdentifier
        tint.layer?.backgroundColor = GraphOverlayThemeStyle.miniTintColor(
            for: GraphOverlayThemeStyle.resolvedTheme()
        ).cgColor
        tint.autoresizingMask = [.width, .height]
        content.addSubview(tint)

        // Soft shadow around the blur box.
        panel.hasShadow = true

        panel.contentView = content
        return panel
    }

    /// Create a companion inspector panel positioned to the right of the mini graph.
    private func createMiniInspectorPanel(relativeTo graphPanel: NSWindow) -> GraphOverlayPanel {
        let dimensions = miniInspectorDimensions(for: inspectorState.inspectorMode)
        let inspectorWidth = dimensions.width
        let inspectorHeight = dimensions.height

        let panel = GraphOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: inspectorWidth, height: inspectorHeight))
        panel.applyPresentation(.floatingPanel)
        panel.styleMask = [.nonactivatingPanel, .borderless]  // Inspector is not resizable

        // Position: to the left of the mini graph panel with a small gap.
        if let screen = NSScreen.main {
            let graphFrame = graphPanel.frame
            let x = graphFrame.minX - inspectorWidth - 12
            let y = graphFrame.maxY - inspectorHeight
            // Clamp to screen bounds.
            let clampedX = max(screen.visibleFrame.minX + 8, x)
            let clampedY = max(screen.visibleFrame.minY + 8, y)
            panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
        } else {
            let graphFrame = graphPanel.frame
            panel.setFrameOrigin(NSPoint(x: graphFrame.minX - inspectorWidth - 12, y: graphFrame.origin.y))
        }

        // Frosted glass background with rounded corners (matches mini graph panel styling).
        let content = NSView(frame: NSRect(origin: .zero, size: NSSize(width: inspectorWidth, height: inspectorHeight)))
        content.wantsLayer = true
        content.layer?.cornerRadius = 16
        content.layer?.masksToBounds = true

        let blur = NSVisualEffectView(frame: content.bounds)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        content.addSubview(blur)

        let tint = NSView(frame: content.bounds)
        tint.wantsLayer = true
        tint.identifier = GraphOverlayThemeStyle.miniTintIdentifier
        tint.layer?.backgroundColor = GraphOverlayThemeStyle.miniTintColor(
            for: GraphOverlayThemeStyle.resolvedTheme()
        ).cgColor
        tint.autoresizingMask = [.width, .height]
        content.addSubview(tint)

        panel.contentView = content

        // Host the inspector SwiftUI view.
        if let modelContainer {
            let inspectorView = NSHostingView(
                rootView: HologramOverlayHostedViewBuilder.root(
                    HologramNodeInspector(
                        inspectorState: inspectorState,
                        modelContext: modelContainer.mainContext
                    )
                )
            )
            inspectorView.autoresizingMask = [.width, .height]
            inspectorView.frame = content.bounds
            content.addSubview(inspectorView)
        }

        return panel
    }

    /// Add a small expand button in the top-right corner of the mini panel.
    private func addExpandButton(to panel: NSWindow) {
        guard let content = panel.contentView else { return }
        let buttonView = NSHostingView(
            rootView: Button {
                NotificationCenter.default.post(name: .graphRestoreRequested, object: nil)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Restore to full size")
        )
        buttonView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttonView)
        NSLayoutConstraint.activate([
            buttonView.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            buttonView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
        ])
    }

    // MARK: - Inspector Position Tracking

    @MainActor
    private func waitForObservedChange(_ observe: () -> Void) async {
        let waiter = ObservationChangeWaiter()
        await waiter.wait(observe: observe)
    }

    private func startInspectorPositionTracking() {
        inspectorPositionTask?.cancel()
        inspectorRepositionTask?.cancel()
        inspectorPositionTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let s = self else { return }
                await s.waitForObservedChange {
                    _ = s.graphState.selectedNodeScreenPoint
                    _ = s.inspectorState.inspectorMode
                }
                guard !Task.isCancelled, let s = self else { return }
                s.scheduleInspectorReposition()
            }
        }
    }

    private func scheduleInspectorReposition() {
        let currentAnchor = graphState.selectedNodeScreenPoint
        let currentMode = inspectorState.inspectorMode
        if !shouldQueueInspectorReposition(anchor: currentAnchor, mode: currentMode) {
            return
        }

        lastQueuedInspectorAnchor = currentAnchor
        lastQueuedInspectorMode = currentMode
        // Reposition immediately — no sleep, no task. The observation loop
        // already fires at screen-point change frequency (every rendered frame).
        repositionInspector()
        // Update pinned inspector positions at the same cadence.
        updatePinnedInspectorPositions()
    }

    private func inspectorDimensions(
        for mode: NodeInspectorState.InspectorMode
    ) -> CGSize {
        switch mode {
        case .profile:
            CGSize(width: 380, height: 500)
        case .editor:
            CGSize(width: 620, height: 600)
        }
    }

    private func miniInspectorDimensions(
        for mode: NodeInspectorState.InspectorMode
    ) -> CGSize {
        switch mode {
        case .profile:
            CGSize(width: 380, height: 620)
        case .editor:
            CGSize(width: 620, height: 620)
        }
    }

    private func shouldQueueInspectorReposition(
        anchor: CGPoint?,
        mode: NodeInspectorState.InspectorMode
    ) -> Bool {
        guard lastQueuedInspectorMode == mode else { return true }

        switch (lastQueuedInspectorAnchor, anchor) {
        case (nil, nil):
            return false
        case let (lhs?, rhs?):
            return abs(lhs.x - rhs.x) >= 1.0 || abs(lhs.y - rhs.y) >= 1.0
        default:
            return true
        }
    }

    private func repositionInspector() {
        guard let inspectorHostView,
              let contentView = window?.contentView ?? miniPanel?.contentView else { return }

        // In mini mode the companion miniInspectorPanel handles the inspector.
        if isMinimized {
            inspectorHostView.isHidden = true
            lastInspectorFrame = nil
            resizeMiniInspectorForMode()
            return
        }

        let bounds = contentView.bounds
        let dimensions = inspectorDimensions(for: inspectorState.inspectorMode)

        let topInset: CGFloat = 80
        let bottomInset: CGFloat = 20

        // Default inspector always sits in the top-right corner.
        // Pinned inspectors (managed separately) follow their nodes.
        // User 2026-04-04: "by default it should not be pinned to a node."
        let inspectorWidth = dimensions.width
        let inspectorHeight = min(dimensions.height, bounds.height - topInset - bottomInset)
        let targetFrame = CGRect(
            x: bounds.width - inspectorWidth - 40,
            y: bounds.height - inspectorHeight - topInset,
            width: inspectorWidth,
            height: inspectorHeight
        )
        guard shouldApplyInspectorFrame(targetFrame) else {
            inspectorHostView.isHidden = (graphState.selectedNodeId == nil)
            return
        }
        inspectorHostView.frame = targetFrame
        lastInspectorFrame = targetFrame
        inspectorHostView.isHidden = (graphState.selectedNodeId == nil)
    }

    private func shouldApplyInspectorFrame(_ targetFrame: CGRect) -> Bool {
        guard let existing = lastInspectorFrame else { return true }
        return abs(existing.origin.x - targetFrame.origin.x) >= 0.5
            || abs(existing.origin.y - targetFrame.origin.y) >= 0.5
            || abs(existing.size.width - targetFrame.size.width) >= 0.5
            || abs(existing.size.height - targetFrame.size.height) >= 0.5
    }

    // MARK: - Pinned Inspectors

    /// Pin the currently selected node's inspector. Creates a persistent
    /// panel that survives deselection and follows the node on screen.
    func pinCurrentNode() {
        guard let nodeId = graphState.selectedNodeId,
              let node = graphState.store.nodes[nodeId],
              let modelContext = modelContainer?.mainContext else { return }
        let mgr = PinnedInspectorManager.shared
        let pinned = mgr.pin(node: node, store: graphState.store, modelContext: modelContext)
        spawnPinnedInspectorView(for: pinned)
    }

    /// Unpin a specific inspector and remove its view.
    func unpinInspector(id: String) {
        PinnedInspectorManager.shared.unpin(inspectorId: id)
        if let view = pinnedInspectorViews.removeValue(forKey: id) {
            view.removeFromSuperview()
        }
    }

    private func spawnPinnedInspectorView(for pinned: PinnedInspector) {
        guard let contentView = window?.contentView else { return }
        // Don't double-add
        guard pinnedInspectorViews[pinned.id] == nil else { return }

        let view = NSHostingView(
            rootView: HologramOverlayHostedViewBuilder.root(
                PinnedInspectorPanel(
                    inspector: pinned,
                    onClose: { [weak self] in self?.unpinInspector(id: pinned.id) }
                )
            )
        )
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        let size = CGSize(width: 280, height: 340)
        view.frame = CGRect(origin: .zero, size: size)
        contentView.addSubview(view)
        pinnedInspectorViews[pinned.id] = view
    }

    /// Update all pinned inspector positions based on their node's screen
    /// coordinates. Called from the render-loop observation task.
    func updatePinnedInspectorPositions() {
        guard let contentView = window?.contentView,
              let engineHandle = graphState.engineHandle else { return }
        let mgr = PinnedInspectorManager.shared
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let bounds = contentView.bounds

        for pinned in mgr.pinnedInspectors {
            guard let view = pinnedInspectorViews[pinned.id] else {
                spawnPinnedInspectorView(for: pinned)
                continue
            }
            var posBuf: [Float] = [0, 0]
            let found = pinned.nodeId.withCString { ptr in
                graph_engine_node_screen_pos(engineHandle, ptr, &posBuf)
            }
            if found != 0 {
                let pt = CGPoint(
                    x: CGFloat(posBuf[0]) / scale,
                    y: bounds.height - CGFloat(posBuf[1]) / scale
                )
                let gap: CGFloat = 20
                let size = view.frame.size
                let x = min(pt.x + gap, bounds.width - size.width - 10)
                let y = max(10, min(pt.y - size.height * 0.3, bounds.height - size.height - 10))
                view.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
                view.isHidden = false
            } else {
                view.isHidden = true
            }
        }

        let activeIds = Set(mgr.pinnedInspectors.map(\.id))
        for (id, view) in pinnedInspectorViews where !activeIds.contains(id) {
            view.removeFromSuperview()
            pinnedInspectorViews.removeValue(forKey: id)
        }
    }

    private func startPinnedPanelTimer() {
        pinnedPanelTimer?.invalidate()
        // Use RunLoop-scheduled timer (fires on main thread directly,
        // no Task hop). Runs at 30fps to keep pinned panels tracking
        // their nodes even when the graph is at rest and the render
        // loop has gone idle.
        pinnedPanelTimer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            // Timer fires on main thread — safe to access UI.
            MainActor.assumeIsolated {
                self?.updatePinnedInspectorPositions()
            }
        }
        RunLoop.main.add(pinnedPanelTimer!, forMode: .common)
    }

    private func stopPinnedPanelTimer() {
        pinnedPanelTimer?.invalidate()
        pinnedPanelTimer = nil
    }

    // MARK: - Lazy Inspector (Node Selection)

    private func observeNodeSelection() {
        selectionObserverTask?.cancel()
        selectionObserverTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let s = self else { return }
                await s.waitForObservedChange {
                    _ = s.graphState.selectedNodeId
                }
                guard !Task.isCancelled, let s = self else { return }
                if s.graphState.selectedNodeId != nil && s.isMinimized {
                    s.showMiniInspector()
                } else if s.graphState.selectedNodeId == nil {
                    s.hideMiniInspector()
                }
            }
        }
    }

    private func showMiniInspector() {
        guard miniInspectorPanel == nil, let miniPanel else { return }
        let panel = createMiniInspectorPanel(relativeTo: miniPanel)
        self.miniInspectorPanel = panel
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }
    }

    /// Resize the mini inspector panel when switching between profile/editor modes.
    private func resizeMiniInspectorForMode() {
        guard let panel = miniInspectorPanel, let miniPanel else { return }
        let dimensions = miniInspectorDimensions(for: inspectorState.inspectorMode)
        let newWidth = dimensions.width
        let newHeight = dimensions.height

        let graphFrame = miniPanel.frame
        let x = graphFrame.minX - newWidth - 12
        let y = graphFrame.maxY - newHeight

        let screen = NSScreen.main?.visibleFrame ?? NSRect.zero
        let clampedX = max(screen.minX + 8, x)
        let clampedY = max(screen.minY + 8, y)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(
                NSRect(x: clampedX, y: clampedY, width: newWidth, height: newHeight),
                display: true
            )
        }
    }

    private func hideMiniInspector() {
        guard let panel = miniInspectorPanel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.miniInspectorPanel?.orderOut(nil)
                self?.miniInspectorPanel = nil
            }
        })
    }

    // MARK: - Notification Observers

    private func observeMinimizeNotifications() {
        minimizeObserver = NotificationCenter.default.addObserver(
            forName: .graphMinimizeRequested, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.minimize()
            }
        }
        resetObserver = NotificationCenter.default.addObserver(
            forName: .graphResetRequested, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.graphState.beginGraphResetCycle()
                self?.metalView?.zoomToFit()
            }
        }
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .graphRestoreRequested, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.restore()
            }
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: .graphCloseRequested, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard self != nil else { return }
                HologramController.shared.hide()
            }
        }
    }

    // MARK: - Fullscreen Handling

    private func observeFullscreenTransitions() {
        fullscreenEnterObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Hide overlay during fullscreen animation to prevent flash.
                self?.window?.orderOut(nil)
                self?.miniPanel?.orderOut(nil as NSWindow?)
                self?.miniInspectorPanel?.orderOut(nil)
            }
        }

        fullscreenExitObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Re-show if the overlay was visible before fullscreen.
                if self.isMinimized {
                    self.miniPanel?.orderFront(nil as NSWindow?)
                } else if self.window != nil {
                    // Only re-show if it was previously visible (not hidden).
                }
            }
        }

        // Re-attach and re-show after entering fullscreen
        fullscreenDidEnterObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let fullscreenWindow = notification.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self, self.isVisible else { return }
                if let fsWindow = fullscreenWindow {
                    if let w = self.window, !self.isMinimized {
                        self.prepareImmersiveOverlayWindow(w, screen: fsWindow.screen)
                        w.orderFrontRegardless()
                    }
                    if let mp = self.miniPanel, self.isMinimized {
                        fsWindow.addChildWindow(mp, ordered: .above)
                        mp.orderFront(nil)
                    }
                }
            }
        }
    }

    private func observeParentMiniaturize() {
        let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) })

        parentMiniaturizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willMiniaturizeNotification,
            object: mainWindow,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Hide overlay when parent minimizes to Dock.
                self?.window?.orderOut(nil)
                self?.miniPanel?.orderOut(nil as NSWindow?)
                self?.miniInspectorPanel?.orderOut(nil)
            }
        }

        parentDeminiaturizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didDeminiaturizeNotification,
            object: mainWindow,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Re-show overlay after parent restores from Dock.
                if self.isMinimized {
                    self.miniPanel?.orderFront(nil as NSWindow?)
                } else if self.window != nil, self.isVisible {
                    self.window?.orderFrontRegardless()
                }
            }
        }
    }

    func syncTheme(uiState: UIState? = AppBootstrap.shared?.uiState, theme explicitTheme: EpistemosTheme? = nil) {
        let theme = GraphOverlayThemeStyle.resolvedTheme(
            uiState: uiState,
            explicitTheme: explicitTheme
        )
        blurView?.material = GraphOverlayThemeStyle.blurMaterial(for: theme)
        darkenLayer?.layer?.backgroundColor = GraphOverlayThemeStyle.overlayTintColor(
            for: theme
        ).cgColor
        metalView?.setLightMode(GraphOverlayThemeStyle.lightModeEnabled(for: theme))
        let appearance = GraphOverlayThemeStyle.windowAppearance(for: theme)
        window?.appearance = appearance
        miniPanel?.appearance = appearance
        miniInspectorPanel?.appearance = appearance
        updateMiniPanelTint(miniPanel, theme: theme)
        updateMiniPanelTint(miniInspectorPanel, theme: theme)
    }

    // MARK: - Draggable Panels

    /// Drag origin for the controls toolbar.
    private var controlsDragOrigin: CGPoint = .zero
    /// Drag origin for the sidebar.
    private var sidebarDragOrigin: CGPoint = .zero

    @objc private func handleControlsDrag(_ gesture: NSPanGestureRecognizer) {
        guard let view = gesture.view, let superview = view.superview else { return }
        switch gesture.state {
        case .began:
            // Switch from constraints to frame-based positioning on first drag.
            NSLayoutConstraint.deactivate(controlsConstraints)
            view.translatesAutoresizingMaskIntoConstraints = true
            controlsDragOrigin = view.frame.origin
        case .changed:
            let translation = gesture.translation(in: superview)
            view.frame.origin = CGPoint(
                x: controlsDragOrigin.x + translation.x,
                y: controlsDragOrigin.y + translation.y
            )
        case .ended, .cancelled:
            controlsDragOrigin = view.frame.origin
        default: break
        }
    }

    @objc private func handleSidebarDrag(_ gesture: NSPanGestureRecognizer) {
        guard let view = gesture.view, let superview = view.superview else { return }
        switch gesture.state {
        case .began:
            NSLayoutConstraint.deactivate(sidebarConstraints)
            view.translatesAutoresizingMaskIntoConstraints = true
            sidebarDragOrigin = view.frame.origin
        case .changed:
            let translation = gesture.translation(in: superview)
            view.frame.origin = CGPoint(
                x: sidebarDragOrigin.x + translation.x,
                y: sidebarDragOrigin.y + translation.y
            )
        case .ended, .cancelled:
            sidebarDragOrigin = view.frame.origin
        default: break
        }
    }

    /// Destroy all views and the Rust engine to free GPU/CPU memory.
    /// Called after the fade-out animation completes.
    private func teardown() {
        cancelScheduledTeardown()
        // Remove escape key monitor.
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        // Remove note window observers.
        if let obs = noteWindowMoveObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = noteWindowResizeObserver { NotificationCenter.default.removeObserver(obs) }
        noteWindowMoveObserver = nil
        noteWindowResizeObserver = nil
        // Remove minimize/restore/close observers.
        if let obs = minimizeObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = resetObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = restoreObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = closeObserver { NotificationCenter.default.removeObserver(obs) }
        minimizeObserver = nil
        resetObserver = nil
        restoreObserver = nil
        closeObserver = nil
        // Remove fullscreen transition observers.
        if let obs = fullscreenEnterObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = fullscreenExitObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = fullscreenDidEnterObserver { NotificationCenter.default.removeObserver(obs) }
        fullscreenEnterObserver = nil
        fullscreenExitObserver = nil
        fullscreenDidEnterObserver = nil
        // Remove parent miniaturize observers.
        if let obs = parentMiniaturizeObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = parentDeminiaturizeObserver { NotificationCenter.default.removeObserver(obs) }
        parentMiniaturizeObserver = nil
        parentDeminiaturizeObserver = nil
        // Cancel fade-in task.
        fadeInTask?.cancel()
        fadeInTask = nil
        // Cancel node selection observer.
        selectionObserverTask?.cancel()
        selectionObserverTask = nil
        inspectorPositionTask?.cancel()
        inspectorPositionTask = nil
        inspectorRepositionTask?.cancel()
        inspectorRepositionTask = nil
        stopPinnedPanelTimer()
        // Invalidate appearance KVO observer.
        appearanceObserver?.invalidate()
        appearanceObserver = nil
        // Nil inspector (SwiftUI hosting view).
        inspectorHostView = nil
        // Nil blur layer refs.
        darkenLayer = nil
        blurView = nil
        noteWindowFrame = nil
        // Close and nil mini panel + inspector companion.
        miniPanel?.orderOut(nil as NSWindow?)
        miniPanel = nil
        miniInspectorPanel?.orderOut(nil)
        miniInspectorPanel = nil
        isMinimized = false
        // Nil Metal view — triggers MetalGraphNSView.deinit → graph_engine_destroy.
        metalView = nil
        // Destroy the window and all its subviews.
        window?.contentView = nil
        window = nil
        // Clear inspector state so it's fresh on next open.
        inspectorState.clearSelection()
        inspectorState.clearCache()
    }

    // MARK: - Window Creation

    private func createWindow() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        // Re-register minimize/restore observers (teardown removes them).
        if minimizeObserver == nil {
            observeMinimizeNotifications()
        }

        let uiState = AppBootstrap.shared?.uiState
        let theme = GraphOverlayThemeStyle.resolvedTheme(uiState: uiState)

        let window = GraphOverlayPanel(contentRect: screen.frame)
        window.applyPresentation(.immersiveOverlay)
        window.appearance = GraphOverlayThemeStyle.windowAppearance(for: theme)

        // Build the content: blur + Metal graph + floating controls + search sidebar.
        let contentView = NSView(frame: screen.frame)
        contentView.wantsLayer = true

        // Frosted glass background — adapts to system appearance.
        let blur = NSVisualEffectView(frame: screen.frame)
        blur.material = GraphOverlayThemeStyle.blurMaterial(for: theme)
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        contentView.addSubview(blur)
        self.blurView = blur

        // Tint overlay for depth — white in light mode for a bright frosted look.
        let darken = NSView(frame: screen.frame)
        darken.wantsLayer = true
        darken.layer?.backgroundColor = GraphOverlayThemeStyle.overlayTintColor(
            for: theme
        ).cgColor
        darken.autoresizingMask = [.width, .height]
        contentView.addSubview(darken)
        self.darkenLayer = darken

        // Metal graph view (fills entire window).
        let graphView = MetalGraphNSView(frame: screen.frame)
        graphView.graphState = graphState
        graphView.physicsCoordinator = physicsCoordinator
        graphView.dialogueChatState = dialogueChatState
        graphView.isOverlayMode = true
        graphView.setLightMode(GraphOverlayThemeStyle.lightModeEnabled(for: theme))
        graphView.autoresizingMask = [.width, .height]
        contentView.addSubview(graphView)

        // Floating controls (SwiftUI hosted — draggable).
        let controlsView = NSHostingView(
            rootView: HologramOverlayHostedViewBuilder.root(
                GraphFloatingControls()
            )
        )
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controlsView)
        self.controlsHostView = controlsView

        let ctrlConstraints = [
            controlsView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            controlsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -56),
            controlsView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -80),
        ]
        NSLayoutConstraint.activate(ctrlConstraints)
        self.controlsConstraints = ctrlConstraints

        let ctrlDrag = NSPanGestureRecognizer(target: self, action: #selector(handleControlsDrag(_:)))
        controlsView.addGestureRecognizer(ctrlDrag)

        // Search sidebar (SwiftUI hosted — draggable).
        let sidebarRoot = HologramSearchSidebar(
            inspectorState: inspectorState,
            modelContext: modelContainer?.mainContext
        ) { [weak graphView, weak self] uuid in
            graphView?.isolateNode(uuid)
            self?.graphState.selectNode(uuid)
        }
        let sidebarView = NSHostingView(
            rootView: HologramOverlayHostedViewBuilder.root(sidebarRoot)
        )
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sidebarView)
        self.sidebarHostView = sidebarView

        let sbConstraints = [
            sidebarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sidebarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
        ]
        NSLayoutConstraint.activate(sbConstraints)
        self.sidebarConstraints = sbConstraints

        // Node inspector panel (SwiftUI hosted, follows selected node).
        if let modelContainer {
            let inspectorView = NSHostingView(
                rootView: HologramOverlayHostedViewBuilder.root(
                    HologramNodeInspector(
                        inspectorState: inspectorState,
                        modelContext: modelContainer.mainContext
                    )
                )
            )
            // Use frame-based positioning (updated by inspectorPositionTask).
            inspectorView.frame = CGRect(x: screen.frame.width - 420, y: 60, width: 380, height: 500)
            inspectorView.autoresizesSubviews = true
            contentView.addSubview(inspectorView)
            self.inspectorHostView = inspectorView
            startInspectorPositionTracking()
        }

        window.contentView = contentView

        // Keyboard dismissal: Escape (with text field guard) + Cmd+W.
        self.escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }

            // Escape — guard: don't consume if a text field is focused.
            if event.keyCode == 53 {
                let keyWindow = self.isMinimized ? self.miniPanel : self.window
                if let responder = keyWindow?.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return event  // Let text field handle Escape (blur/cancel).
                }
                HologramController.shared.hide()
                return nil
            }

            // Cmd+W — standard macOS close shortcut.
            if event.keyCode == 13 {
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.capsLock, .numericPad, .function])
                if mods == .command {
                    HologramController.shared.hide()
                    return nil
                }
            }

            return event
        }

        self.window = window
        self.metalView = graphView

        window.makeFirstResponder(graphView)

        // Commit graph data after window is set up.
        DispatchQueue.main.async {
            guard self.graphState.isLoaded else { return }

            let isPageMode: Bool = {
                if case .page = self.graphState.mode { return true }
                return false
            }()
            graphView.setGraphMode(isPageMode ? 1 : 0)
            graphView.commitGraphData()

            // Sync version so render loop doesn't double-commit.
            graphView.lastGraphDataVersion = self.graphState.graphDataVersion

            if isPageMode {
                if let frame = self.noteWindowFrame {
                    graphView.setAnchorRect(frame)
                }
                graphView.zoomInClose()
            }
        }

        // Observe system appearance changes so the graph reacts to light/dark mode switches.
        self.appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.syncTheme()
            }
        }

        // Observe fullscreen transitions and parent window miniaturize.
        observeFullscreenTransitions()
        observeParentMiniaturize()
    }

    private func restoreImmersiveChromeIfNeeded(
        _ window: GraphOverlayPanel,
        metalView: MetalGraphNSView
    ) {
        isMinimized = false
        miniPanel = nil
        metalView.isMiniMode = false

        window.contentView?.subviews
            .filter { $0.identifier == NSUserInterfaceItemIdentifier("miniBlur") }
            .forEach { $0.removeFromSuperview() }

        blurView?.isHidden = false
        darkenLayer?.isHidden = false
        for subview in window.contentView?.subviews ?? [] {
            subview.isHidden = false
        }

        window.contentView?.layer?.cornerRadius = 0
        window.contentView?.layer?.masksToBounds = false
        window.applyPresentation(.immersiveOverlay)
    }

    private func prepareImmersiveOverlayWindow(_ window: GraphOverlayPanel, screen: NSScreen?) {
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }
        window.applyPresentation(.immersiveOverlay)
        if let screen {
            window.setFrame(screen.frame, display: true)
        }
    }

    private func attachFloatingPanelToMainWindow(_ panel: GraphOverlayPanel) {
        panel.applyPresentation(.floatingPanel)
        if let parent = panel.parent {
            parent.removeChildWindow(panel)
        }
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            mainWindow.addChildWindow(panel, ordered: .above)
        }
    }

    private func updateMiniPanelTint(_ panel: NSWindow?, theme: EpistemosTheme) {
        guard let tintView = findSubview(
            in: panel?.contentView,
            identifier: GraphOverlayThemeStyle.miniTintIdentifier
        ) else { return }
        tintView.layer?.backgroundColor = GraphOverlayThemeStyle.miniTintColor(for: theme).cgColor
    }

    private func findSubview(
        in root: NSView?,
        identifier: NSUserInterfaceItemIdentifier
    ) -> NSView? {
        guard let root else { return nil }
        if root.identifier == identifier {
            return root
        }
        for subview in root.subviews {
            if let match = findSubview(in: subview, identifier: identifier) {
                return match
            }
        }
        return nil
    }

}
