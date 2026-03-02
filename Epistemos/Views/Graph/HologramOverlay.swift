import SwiftUI
import SwiftData
import AppKit

// MARK: - KeyableWindow
// Borderless windows return false from canBecomeKey by default,
// which prevents SwiftUI TextFields from accepting keyboard input.

private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - HologramOverlay
// Full-screen borderless NSWindow that renders the knowledge graph
// on top of a heavy frosted-glass blur. Triggered by a global hotkey.
//
// Architecture:
// - NSWindow: borderless, floating level, full-screen
// - Background: NSVisualEffectView with .hudWindow material
// - Content: MetalGraphView fills the entire screen
// - Controls: GraphFloatingControls pill bar at bottom
// - Search:   HologramSearchSidebar floating panel on the left
// - Animation: Scale + fade from center on show, reverse on hide

final class HologramOverlay {

    private var window: NSWindow?
    private var metalView: MetalGraphNSView?
    private var inspectorHostView: NSHostingView<AnyView>?
    private var escapeMonitor: Any?
    private var graphState: GraphState
    private var queryEngine: QueryEngine
    private var modelContainer: ModelContainer?
    private var physicsCoordinator: PhysicsCoordinator?
    private let inspectorState = NodeInspectorState()

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

    // Mini floating panel (chromeless glass float).
    private var miniPanel: NSWindow?
    /// Companion panel: holds the inspector alongside the mini graph when minimized.
    private var miniInspectorPanel: NSWindow?
    private(set) var isMinimized = false
    private var selectionObserverTask: Task<Void, Never>?
    private var minimizeObserver: Any?
    private var restoreObserver: Any?
    private var closeObserver: Any?

    init(graphState: GraphState, queryEngine: QueryEngine, modelContainer: ModelContainer?, physicsCoordinator: PhysicsCoordinator? = nil) {
        self.graphState = graphState
        self.queryEngine = queryEngine
        self.modelContainer = modelContainer
        self.physicsCoordinator = physicsCoordinator
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
        self.noteWindowFrame = noteWindow?.frame

        // Fast path: if engine is still alive from a soft-hide, just resume + show.
        if let window, let metalView {
            if let screen = NSScreen.main {
                window.setFrame(screen.frame, display: true)
            }
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(metalView)
            metalView.resumeEngine()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1.0
            }
            return
        }

        // Cold start: create everything from scratch.
        createWindow()

        guard let window else { return }

        // Position on the active screen.
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }

        // Page mode: lighter blur (nodes "break out" of the overlay).
        let isPageMode: Bool = {
            if case .page = graphState.mode { return true }
            return false
        }()
        if isPageMode {
            darkenLayer?.alphaValue = 0.15
            blurView?.material = .hudWindow
        }

        // Track note window movement so nodes follow it in real time.
        if let noteWindow, isPageMode {
            observeNoteWindow(noteWindow)
        }

        // Entrance animation: fade in from zero opacity.
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        // Make Metal view first responder for keyboard zoom (Cmd+/-/0).
        if let metalView {
            window.makeFirstResponder(metalView)
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }
    }

    /// Observe note window move/resize to dynamically update the anchor rect.
    private func observeNoteWindow(_ noteWindow: NSWindow) {
        let updateBlock: (Notification) -> Void = { [weak self, weak noteWindow] _ in
            guard let self, let noteWindow, let metalView = self.metalView else { return }
            self.noteWindowFrame = noteWindow.frame
            metalView.setAnchorRect(noteWindow.frame)
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


    func hide() {
        if isMinimized {
            // Minimized: fade out the mini panel and do full teardown.
            guard let miniPanel else { teardown(); return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                miniPanel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.teardown()
            })
            return
        }

        guard let window else { return }

        // Soft hide: pause engine + hide window, keep engine alive for fast re-show.
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.metalView?.pauseEngine()
        })
    }

    /// Full teardown: destroy engine + Metal resources to free all memory.
    /// Call when the overlay is being permanently dismissed (e.g. app quit).
    func forceClose() {
        if let window {
            window.orderOut(nil)
        }
        teardown()
    }

    // MARK: - Minimize / Restore

    /// Shrink the full-screen overlay into a chromeless glass float.
    /// The MetalGraphNSView is reparented (not recreated) to keep the engine alive.
    func minimize() {
        guard let metalView, let window, !isMinimized else { return }

        // 1. Pause engine during reparent.
        metalView.pauseEngine()

        // 2. Remove metalView from overlay.
        metalView.removeFromSuperview()

        // 3. Create the mini panel.
        let panel = createMiniPanel()
        self.miniPanel = panel

        // 4. Add metalView to the mini panel's content.
        metalView.isMiniMode = true
        metalView.autoresizingMask = [.width, .height]
        metalView.frame = panel.contentView!.bounds
        panel.contentView!.addSubview(metalView)

        // 5. Add expand button overlay.
        addExpandButton(to: panel)

        // 6. Animate: overlay fades out, mini panel fades in.
        isMinimized = true
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(metalView)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
            panel.animator().alphaValue = 1.0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        }

        // 7. Observe node selection to lazily show/hide inspector.
        observeNodeSelection()

        // 8. Resume engine in the new context.
        metalView.layout()
        metalView.resumeEngine()
    }

    /// Restore the mini panel back to the full-screen overlay.
    func restore() {
        guard let metalView, let miniPanel, isMinimized else { return }

        // Cold-started in mini mode (e.g., via command palette) — no full-screen window exists.
        // Clean teardown, then ask HologramController to create everything fresh.
        if window == nil {
            teardown()
            HologramController.shared.show()
            return
        }

        // 1. Pause engine.
        metalView.pauseEngine()

        // 2. Remove metalView from mini panel.
        metalView.removeFromSuperview()

        // 3. Re-add metalView to the overlay window's content view.
        guard let contentView = window?.contentView else {
            // Overlay window was lost — recreate everything.
            metalView.resumeEngine()
            teardown()
            return
        }
        metalView.isMiniMode = false
        metalView.autoresizingMask = [.width, .height]
        metalView.frame = contentView.bounds
        // Insert behind the floating controls/sidebar/inspector.
        contentView.addSubview(metalView, positioned: .below, relativeTo: contentView.subviews.first { $0 is NSHostingView<AnyView> || $0 !== blurView && $0 !== darkenLayer })

        // 4. Animate: mini panel fades out, overlay fades in.
        isMinimized = false
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(metalView)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.window?.animator().alphaValue = 1.0
            miniPanel.animator().alphaValue = 0
            self.miniInspectorPanel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.miniPanel?.orderOut(nil)
            self?.miniPanel = nil
            self?.miniInspectorPanel?.orderOut(nil)
            self?.miniInspectorPanel = nil
        }

        // 5. Resume engine.
        metalView.layout()
        metalView.resumeEngine()
    }

    // MARK: - Show Mini (Cold Start)

    /// Show the graph directly in mini mode without creating a full-screen window.
    /// Used by the command palette to display the graph as a companion panel.
    func showMini() {
        // Already minimized and visible — nothing to do.
        if isMinimized, miniPanel?.isVisible == true { return }

        // Full-screen overlay visible — minimize it instead.
        if window?.isVisible == true {
            minimize()
            return
        }

        // Re-register observers if needed (teardown removes them).
        if minimizeObserver == nil { observeMinimizeNotifications() }

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Create MetalGraphNSView directly in mini mode (no full-screen window).
        let graphView = MetalGraphNSView(frame: NSRect(x: 0, y: 0, width: 500, height: 380))
        graphView.graphState = graphState
        graphView.physicsCoordinator = physicsCoordinator
        graphView.isOverlayMode = true
        graphView.setLightMode(!isDark)
        graphView.isMiniMode = true
        self.metalView = graphView

        let panel = createMiniPanel()
        self.miniPanel = panel

        graphView.autoresizingMask = [.width, .height]
        graphView.frame = panel.contentView!.bounds
        panel.contentView!.addSubview(graphView)

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
        DispatchQueue.main.async { [weak self] in
            guard let self, self.graphState.isLoaded else { return }
            graphView.setGraphMode(0) // global mode
            graphView.commitGraphData()
            graphView.lastGraphDataVersion = self.graphState.graphDataVersion
        }

        // Observe system appearance changes.
        if appearanceObserver == nil {
            appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
                DispatchQueue.main.async { self?.syncTheme() }
            }
        }

        // Observe node selection to lazily show/hide inspector.
        observeNodeSelection()
    }

    // MARK: - Mini Panel Creation

    private func createMiniPanel() -> NSWindow {
        let panel = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false          // We use a custom glow instead
        panel.isMovableByWindowBackground = false  // Metal view handles its own drag
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 320, height: 240)
        panel.maxSize = NSSize(width: 1200, height: 900)
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        // Position: bottom-right of main screen with padding.
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 520
            let y = screen.visibleFrame.minY + 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Frosted glass blur box with rounded corners.
        let content = NSView(frame: panel.contentView!.bounds)
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
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(isDark ? 0.2 : 0.05).cgColor
        tint.autoresizingMask = [.width, .height]
        content.addSubview(tint)

        // Soft shadow around the blur box.
        panel.hasShadow = true

        panel.contentView = content
        return panel
    }

    /// Create a companion inspector panel positioned to the right of the mini graph.
    private func createMiniInspectorPanel(relativeTo graphPanel: NSWindow) -> NSWindow {
        let inspectorWidth: CGFloat = 380
        let inspectorHeight: CGFloat = 620

        let panel = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: inspectorWidth, height: inspectorHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false

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

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let tint = NSView(frame: content.bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(isDark ? 0.2 : 0.05).cgColor
        tint.autoresizingMask = [.width, .height]
        content.addSubview(tint)

        panel.contentView = content

        // Host the inspector SwiftUI view.
        if let modelContainer {
            let inspectorView = NSHostingView(
                rootView: AnyView(
                    HologramNodeInspector(
                        inspectorState: inspectorState,
                        modelContext: modelContainer.mainContext
                    )
                    .environment(graphState)
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

    // MARK: - Lazy Inspector (Node Selection)

    private func observeNodeSelection() {
        selectionObserverTask?.cancel()
        selectionObserverTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let s = self else { return }
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = s.graphState.selectedNodeId
                    } onChange: {
                        continuation.resume()
                    }
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

    private func hideMiniInspector() {
        guard let panel = miniInspectorPanel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.miniInspectorPanel?.orderOut(nil)
            self?.miniInspectorPanel = nil
        })
    }

    // MARK: - Notification Observers

    private func observeMinimizeNotifications() {
        minimizeObserver = NotificationCenter.default.addObserver(
            forName: .graphMinimizeRequested, object: nil, queue: .main
        ) { [weak self] _ in
            self?.minimize()
        }
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .graphRestoreRequested, object: nil, queue: .main
        ) { [weak self] _ in
            self?.restore()
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: .graphCloseRequested, object: nil, queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    /// Re-sync blur, tint, and graph color palette to match current system appearance.
    private func syncTheme() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        blurView?.material = .fullScreenUI
        darkenLayer?.layer?.backgroundColor = (isDark
            ? NSColor.black.withAlphaComponent(0.45)
            : NSColor.white.withAlphaComponent(0.55)
        ).cgColor
        metalView?.setLightMode(!isDark)
        window?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    /// Destroy all views and the Rust engine to free GPU/CPU memory.
    /// Called after the fade-out animation completes.
    private func teardown() {
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
        if let obs = restoreObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = closeObserver { NotificationCenter.default.removeObserver(obs) }
        minimizeObserver = nil
        restoreObserver = nil
        closeObserver = nil
        // Cancel node selection observer.
        selectionObserverTask?.cancel()
        selectionObserverTask = nil
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
        miniPanel?.orderOut(nil)
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

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

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

        // Build the content: blur + Metal graph + floating controls + search sidebar.
        let contentView = NSView(frame: screen.frame)
        contentView.wantsLayer = true

        // Frosted glass background — adapts to system appearance.
        let blur = NSVisualEffectView(frame: screen.frame)
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        contentView.addSubview(blur)
        self.blurView = blur

        // Tint overlay for depth — white in light mode for a bright frosted look.
        let darken = NSView(frame: screen.frame)
        darken.wantsLayer = true
        darken.layer?.backgroundColor = (isDark
            ? NSColor.black.withAlphaComponent(0.45)
            : NSColor.white.withAlphaComponent(0.55)
        ).cgColor
        darken.autoresizingMask = [.width, .height]
        contentView.addSubview(darken)
        self.darkenLayer = darken

        // Metal graph view (fills entire window).
        let graphView = MetalGraphNSView(frame: screen.frame)
        graphView.graphState = graphState
        graphView.physicsCoordinator = physicsCoordinator
        graphView.isOverlayMode = true
        graphView.setLightMode(!isDark)
        graphView.autoresizingMask = [.width, .height]
        contentView.addSubview(graphView)

        // Floating controls (SwiftUI hosted at the bottom).
        let controlsView = NSHostingView(
            rootView: GraphFloatingControls()
                .environment(graphState)
        )
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controlsView)

        NSLayoutConstraint.activate([
            controlsView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            controlsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            controlsView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -80),
        ])

        // Search sidebar (SwiftUI hosted on the left).
        let sidebarView = NSHostingView(
            rootView: HologramSearchSidebar(
                searchText: .init(
                    get: { [weak graphView] in graphView?.searchQuery ?? "" },
                    set: { [weak graphView] in graphView?.searchQuery = $0 }
                ),
                onSearchChanged: { [weak graphView] query in
                    graphView?.searchHighlight(query)
                },
                onSelectNode: { [weak graphView, weak self] uuid in
                    graphView?.isolateNode(uuid)
                    self?.graphState.selectNode(uuid)
                }
            )
            .environment(graphState)
            .environment(queryEngine)
        )
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sidebarView)

        NSLayoutConstraint.activate([
            sidebarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sidebarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
        ])

        // Node inspector panel (SwiftUI hosted on the right).
        if let modelContainer {
            let inspectorView = NSHostingView(
                rootView: AnyView(
                    HologramNodeInspector(
                        inspectorState: inspectorState,
                        modelContext: modelContainer.mainContext
                    )
                    .environment(graphState)
                )
            )
            inspectorView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(inspectorView)

            // Offset from the right edge — account for the Dock if it's on the right.
            let dockInset = screen.frame.maxX - screen.visibleFrame.maxX
            let rightMargin = max(dockInset + 16, 32)
            NSLayoutConstraint.activate([
                inspectorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -rightMargin),
                inspectorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            ])

            self.inspectorHostView = inspectorView
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
                self.hide()
                return nil
            }

            // Cmd+W — standard macOS close shortcut.
            if event.keyCode == 13 {
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.capsLock, .numericPad, .function])
                if mods == .command {
                    self.hide()
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
            DispatchQueue.main.async {
                self?.syncTheme()
            }
        }
    }

}
