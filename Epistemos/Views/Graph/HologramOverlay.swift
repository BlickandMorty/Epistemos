import SwiftUI
import SwiftData
import AppKit

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
    private var dialogueChatState: DialogueChatState?
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
    private var miniPanel: GraphOverlayPanel?
    /// Companion panel: holds the inspector alongside the mini graph when minimized.
    private var miniInspectorPanel: GraphOverlayPanel?
    private(set) var isMinimized = false
    private var selectionObserverTask: Task<Void, Never>?
    private var inspectorPositionTask: Task<Void, Never>?
    private var minimizeObserver: Any?
    private var restoreObserver: Any?
    private var closeObserver: Any?

    // Fullscreen transition observers
    private var fullscreenEnterObserver: Any?
    private var fullscreenExitObserver: Any?
    // Parent window miniaturize observers
    private var parentMiniaturizeObserver: Any?
    private var parentDeminiaturizeObserver: Any?

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
        miniBlur.identifier = NSUserInterfaceItemIdentifier("miniBlur") // Identifier for easy removal on restore
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

        // Alias the full-screen window as miniPanel so downstream code
        // (inspector, escape handler, first responder queries) works.
        self.miniPanel = window as? GraphOverlayPanel

        window.makeFirstResponder(metalView)
        observeNodeSelection()
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

        // Hide mini inspector if shown
        if let inspector = miniInspectorPanel {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                inspector.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.miniInspectorPanel?.orderOut(nil as NSWindow?)
                self?.miniInspectorPanel = nil
            })
        }
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
        graphView.dialogueChatState = dialogueChatState
        graphView.isOverlayMode = true
        graphView.setLightMode(!isDark)
        graphView.isMiniMode = true
        self.metalView = graphView

        let panel = createMiniPanel()
        self.miniPanel = panel

        // Attach as child of main app window for proper z-ordering.
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            mainWindow.addChildWindow(panel, ordered: .above)
        }

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

    private func createMiniPanel() -> GraphOverlayPanel {
        let panel = GraphOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 380))
        panel.minSize = NSSize(width: 320, height: 240)
        panel.maxSize = NSSize(width: 1200, height: 900)

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
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(isDark ? 0.55 : 0.05).cgColor
        tint.autoresizingMask = [.width, .height]
        content.addSubview(tint)

        // Soft shadow around the blur box.
        panel.hasShadow = true

        panel.contentView = content
        return panel
    }

    /// Create a companion inspector panel positioned to the right of the mini graph.
    private func createMiniInspectorPanel(relativeTo graphPanel: NSWindow) -> GraphOverlayPanel {
        let inspectorWidth: CGFloat = 380
        let inspectorHeight: CGFloat = 620

        let panel = GraphOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: inspectorWidth, height: inspectorHeight))
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

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let tint = NSView(frame: content.bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(isDark ? 0.55 : 0.05).cgColor
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

    // MARK: - Inspector Position Tracking

    private func startInspectorPositionTracking() {
        inspectorPositionTask?.cancel()
        inspectorPositionTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let s = self else { return }
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = s.graphState.selectedNodeScreenPoint
                        _ = s.inspectorState.inspectorMode
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled, let s = self else { return }
                s.repositionInspector()
            }
        }
    }

    private func repositionInspector() {
        guard let inspectorHostView,
              let contentView = window?.contentView ?? miniPanel?.contentView else { return }

        // In mini mode the companion miniInspectorPanel handles the inspector.
        if isMinimized {
            inspectorHostView.isHidden = true
            resizeMiniInspectorForMode()
            return
        }

        let bounds = contentView.bounds
        let isEditor = inspectorState.inspectorMode == .editor

        let topInset: CGFloat = 80  // keep clear of title bar / toolbar
        let bottomInset: CGFloat = 20

        if let pt = graphState.selectedNodeScreenPoint {
            let inspectorWidth: CGFloat = isEditor ? 620 : 380
            let inspectorHeight: CGFloat = min(isEditor ? 600 : 500, bounds.height - topInset - bottomInset)
            let gap: CGFloat = 24

            let nodeRight = pt.x + gap
            let fitsRight = nodeRight + inspectorWidth < bounds.width - 20
            let x = fitsRight ? nodeRight : pt.x - inspectorWidth - gap
            let y = max(bottomInset, min(bounds.height - inspectorHeight - topInset, pt.y - inspectorHeight * 0.4))

            let targetFrame = CGRect(x: x, y: y, width: inspectorWidth, height: inspectorHeight)
            inspectorHostView.frame = targetFrame
            inspectorHostView.isHidden = false
        } else {
            let inspectorWidth: CGFloat = isEditor ? 620 : 380
            let inspectorHeight: CGFloat = isEditor ? 600 : 500
            inspectorHostView.frame = CGRect(x: bounds.width - inspectorWidth - 40, y: bottomInset, width: inspectorWidth, height: inspectorHeight)
        }
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

    /// Resize the mini inspector panel when switching between profile/editor modes.
    private func resizeMiniInspectorForMode() {
        guard let panel = miniInspectorPanel, let miniPanel else { return }
        let isEditor = inspectorState.inspectorMode == .editor
        let newWidth: CGFloat = isEditor ? 620 : 380
        let newHeight: CGFloat = isEditor ? 620 : 620

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

    // MARK: - Fullscreen Handling

    private func observeFullscreenTransitions() {
        fullscreenEnterObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Hide overlay during fullscreen animation to prevent flash.
            self?.window?.orderOut(nil)
            self?.miniPanel?.orderOut(nil as NSWindow?)
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
                self.miniPanel?.orderFront(nil as NSWindow?)
            } else if self.window != nil {
                // Only re-show if it was previously visible (not hidden).
            }
        }

        // Re-attach and re-show after entering fullscreen
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
    }

    private func observeParentMiniaturize() {
        let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) })

        parentMiniaturizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willMiniaturizeNotification,
            object: mainWindow,
            queue: .main
        ) { [weak self] _ in
            // Hide overlay when parent minimizes to Dock.
            self?.window?.orderOut(nil)
            self?.miniPanel?.orderOut(nil as NSWindow?)
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
                self.miniPanel?.orderFront(nil as NSWindow?)
            } else if self.window != nil, self.isVisible {
                self.window?.orderFront(nil)
            }
        }
    }

    /// Re-sync blur, tint, and graph color palette to match current system appearance.
    private func syncTheme() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        blurView?.material = .fullScreenUI
        darkenLayer?.layer?.backgroundColor = (isDark
            ? NSColor.black.withAlphaComponent(0.75)
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
        // Remove fullscreen transition observers.
        if let obs = fullscreenEnterObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = fullscreenExitObserver { NotificationCenter.default.removeObserver(obs) }
        fullscreenEnterObserver = nil
        fullscreenExitObserver = nil
        // Remove parent miniaturize observers.
        if let obs = parentMiniaturizeObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = parentDeminiaturizeObserver { NotificationCenter.default.removeObserver(obs) }
        parentMiniaturizeObserver = nil
        parentDeminiaturizeObserver = nil
        // Cancel node selection observer.
        selectionObserverTask?.cancel()
        selectionObserverTask = nil
        inspectorPositionTask?.cancel()
        inspectorPositionTask = nil
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

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let window = GraphOverlayPanel(contentRect: screen.frame)
        window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        // Full-screen overlay doesn't need a shadow (blur background covers everything).
        window.hasShadow = false

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
            ? NSColor.black.withAlphaComponent(0.75)
            : NSColor.white.withAlphaComponent(0.55)
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

        // Node inspector panel (SwiftUI hosted, follows selected node).
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

        // Attach as child of main app window for proper z-ordering and fullscreen behavior.
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            mainWindow.addChildWindow(window, ordered: .above)
        }

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

        // Observe fullscreen transitions and parent window miniaturize.
        observeFullscreenTransitions()
        observeParentMiniaturize()
    }

}
