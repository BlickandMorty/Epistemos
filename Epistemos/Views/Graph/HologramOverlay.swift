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
    private var minimizeObserver: Any?
    private var restoreObserver: Any?
    private var closeObserver: Any?

    init(graphState: GraphState, queryEngine: QueryEngine, modelContainer: ModelContainer?) {
        self.graphState = graphState
        self.queryEngine = queryEngine
        self.modelContainer = modelContainer
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

        // 6. Create companion inspector panel next to the mini graph.
        let inspectorPanel = createMiniInspectorPanel(relativeTo: panel)
        self.miniInspectorPanel = inspectorPanel

        // 7. Animate: overlay fades out, mini panel fades in.
        isMinimized = true
        panel.alphaValue = 0
        inspectorPanel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        inspectorPanel.orderFront(nil)
        panel.makeFirstResponder(metalView)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
            panel.animator().alphaValue = 1.0
            inspectorPanel.animator().alphaValue = 1.0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        }

        // 8. Resume engine in the new context.
        metalView.layout()
        metalView.resumeEngine()
    }

    /// Restore the mini panel back to the full-screen overlay.
    func restore() {
        guard let metalView, let miniPanel, isMinimized else { return }

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
        panel.appearance = NSAppearance(named: .darkAqua)
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

        // Blur background — always dark to match graph rendering.
        let blur = NSVisualEffectView(frame: content.bounds)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        blur.autoresizingMask = [.width, .height]
        content.addSubview(blur)

        // Subtle dark tint overlay for depth.
        let tint = NSView(frame: content.bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        tint.autoresizingMask = [.width, .height]
        content.addSubview(tint)

        // Soft shadow around the blur box.
        panel.hasShadow = true

        panel.contentView = content
        return panel
    }

    /// Create a companion inspector panel positioned to the right of the mini graph.
    private func createMiniInspectorPanel(relativeTo graphPanel: NSWindow) -> NSWindow {
        let panel = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 380),
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
        panel.appearance = NSAppearance(named: .darkAqua)

        // Position: same as full-screen mode — top-right of screen with dock margin.
        // This matches the inspector position users see in full-screen graph mode.
        if let screen = NSScreen.main {
            let dockInset = screen.frame.maxX - screen.visibleFrame.maxX
            let rightMargin = max(dockInset + 16, 32)
            let inspectorWidth: CGFloat = 380
            let inspectorHeight: CGFloat = min(graphPanel.frame.height, screen.visibleFrame.height - 120)
            let x = screen.visibleFrame.maxX - inspectorWidth - rightMargin
            let y = screen.visibleFrame.maxY - inspectorHeight - 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.setContentSize(NSSize(width: inspectorWidth, height: inspectorHeight))
        } else {
            let graphFrame = graphPanel.frame
            panel.setFrameOrigin(NSPoint(x: graphFrame.maxX + 12, y: graphFrame.origin.y))
            panel.setContentSize(NSSize(width: 380, height: graphFrame.height))
        }

        // Host the inspector SwiftUI view
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
            inspectorView.frame = panel.contentView!.bounds
            panel.contentView!.addSubview(inspectorView)
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

    /// Re-sync blur and tint layers. Graph always renders in dark mode.
    private func syncTheme() {
        blurView?.material = .fullScreenUI
        blurView?.appearance = NSAppearance(named: .darkAqua)
        darkenLayer?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
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
        // Invalidate appearance KVO observer.
        appearanceObserver?.invalidate()
        appearanceObserver = nil
        // Nil inspector (SwiftUI hosting view).
        inspectorHostView = nil
        // Nil blur layer refs.
        darkenLayer = nil
        blurView = nil
        noteWindowFrame = nil
        // Close and nil mini panel.
        miniPanel?.orderOut(nil)
        miniPanel = nil
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
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        // Build the content: blur + Metal graph + floating controls + search sidebar.
        let contentView = NSView(frame: screen.frame)
        contentView.wantsLayer = true

        // Frosted glass background — always dark to match the graph's dark-only rendering.
        let blur = NSVisualEffectView(frame: screen.frame)
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        blur.autoresizingMask = [.width, .height]
        contentView.addSubview(blur)
        self.blurView = blur

        // Dark tint overlay for depth.
        let darken = NSView(frame: screen.frame)
        darken.wantsLayer = true
        darken.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        darken.autoresizingMask = [.width, .height]
        contentView.addSubview(darken)
        self.darkenLayer = darken

        // Metal graph view (fills entire window).
        let graphView = MetalGraphNSView(frame: screen.frame)
        graphView.graphState = graphState
        graphView.isOverlayMode = true
        graphView.applyOverlayMode()
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
