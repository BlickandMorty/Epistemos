import SwiftUI
import SwiftData
import AppKit

enum GraphMiniPanelLayout {
    // Per user 2026-05-10: the single unified graph (mini ontology) opens
    // a "little larger" than the previous 620pt default. 900pt gives the
    // user real working room while keeping the floating-panel feel + the
    // perf characteristics that made the mini fluid in the first place.
    static let defaultSide: CGFloat = 900
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

    static func surfaceTintColor(for theme: EpistemosTheme) -> NSColor {
        // Shared graph glass glaze for full-size and mini surfaces. Sample the
        // selected semantic theme surface directly so warm/platinum/retro
        // palettes change the graph material without adding overlay layers.
        let fallback = theme.isDark ? NSColor.black : NSColor.white
        let base = theme.resolved.background.nsColor.usingColorSpace(.deviceRGB) ?? fallback
        return NSColor(
            red: base.redComponent,
            green: base.greenComponent,
            blue: base.blueComponent,
            alpha: theme.isDark ? 0.32 : 0.65
        )
    }

    static func overlayTintColor(for theme: EpistemosTheme) -> NSColor {
        surfaceTintColor(for: theme)
    }

    static func miniTintColor(for theme: EpistemosTheme) -> NSColor {
        surfaceTintColor(for: theme)
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

/// Wraps the SwiftUI content with the graph overlay theme + (optionally) the
/// app environment + SwiftData model container. Returning the concrete view
/// chain (no `AnyView` wrapper) preserves structural identity per doctrine
/// §6 #6.
fileprivate struct HologramOverlayHostedView<Content: View>: View {
    let content: Content
    let bootstrap: AppBootstrap?

    @ViewBuilder
    var body: some View {
        if let bootstrap {
            GraphOverlayThemeContainer(content: content)
                .withAppEnvironment(bootstrap)
                .modelContainer(bootstrap.modelContainer)
        } else {
            GraphOverlayThemeContainer(content: content)
        }
    }
}

fileprivate enum HologramOverlayHostedViewBuilder {
    /// Wraps `content` in a hosted-overlay environment and returns a typed
    /// `NSHostingView`. Returning the concrete `NSHostingView<HologramOverlayHostedView<Content>>`
    /// (vs. `NSHostingView<AnyView>`) keeps the SwiftUI content's structural
    /// identity intact per doctrine §6 #6 (no AnyView in render hot paths).
    /// Call sites store the result via the `NSView` base type so heterogeneous
    /// hosted views can coexist in the same fields without an AnyView entry
    /// point on the SwiftUI side.
    @MainActor
    static func host<Content: View>(
        _ content: Content,
        bootstrap: AppBootstrap? = AppBootstrap.shared
    ) -> NSHostingView<HologramOverlayHostedView<Content>> {
        let hostingView = NSHostingView(
            rootView: HologramOverlayHostedView(content: content, bootstrap: bootstrap)
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        return hostingView
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
//
// BLUR POLICY (2026-05-20 single-blur-per-window contract):
// ─────────────────────────────────────────────────────────
// Each NSWindow this file creates carries EXACTLY ONE
// NSVisualEffectView at the contentView level. Every SwiftUI
// chrome surface inside the window (folder navigator, note editor,
// inspector, search sidebar, floating controls, header strip,
// circle toggle buttons) renders as `theme.glassBg` tinted color
// + `theme.glassBorder` stroke — NO per-surface Material / .glassEffect
// / nested NSVisualEffectView. The window's single blur kernel
// shows through every tinted overlay.
//
// Why: CoreAnimation has a finite per-frame compositor budget
// (~8 ms at 120 Hz). Each NSVisualEffectView / Material is a
// separate blur kernel pass. Stacking 8 of them caps the effective
// compositor FPS at ~60 Hz even when MetalGraphView's CADisplayLink
// requests 120 Hz. Single-blur policy keeps the compositor at
// 120 Hz alongside Metal.
//
// The four windows / their single blur each:
//   1. Main graph window    →  `self.blurView` (line ~1810, set in show())
//   2. Mini cold-start panel →  `blur` in `createMiniPanel`     (separate NSPanel)
//   3. Mini inspector panel  →  `blur` in `createMiniInspectorPanel` (separate NSPanel)
//   4. Minimize-from-full    →  `miniBlur` added on minimize(); the
//                              full-screen blurView is hidden behind it
//                              while in mini mode (only one is visible at
//                              a time, so the contract still holds).
//
// See Epistemos/Views/Shared/UnifiedFrostedGlass.swift for the
// SwiftUI side of the same contract.

@MainActor
final class HologramOverlay {

    /// Identifier for the small expand-button host view added in mini mode
    /// (`addExpandButton`). Used by `restore()` to find and remove it when
    /// the panel transitions back to full-screen.
    private static let miniExpandButtonIdentifier = NSUserInterfaceItemIdentifier(
        "graphMiniExpandButton"
    )

    private var window: GraphOverlayPanel?
    private var metalView: MetalGraphNSView?
    /// AppKit-typed weak handle to the SwiftUI inspector hosting view.
    /// Concrete type is `NSHostingView<HologramOverlayHostedView<HologramNodeInspector>>`
    /// at construction; widened to `NSView?` here so the field can hold any
    /// hosted-overlay view shape without forcing an `AnyView` entry on the
    /// SwiftUI side (doctrine §6 #6).
    private var inspectorHostView: NSView?
    private var graphState: GraphState
    private var queryEngine: QueryEngine
    private var modelContainer: ModelContainer?
    private var physicsCoordinator: PhysicsCoordinator?
    private var dialogueChatState: DialogueChatState?
    private let inspectorState = NodeInspectorState()
    /// Pinned inspectors: persistent panels attached to specific nodes.
    /// Each gets its own NSHostingView (concrete type
    /// `NSHostingView<HologramOverlayHostedView<PinnedInspectorPanel>>`)
    /// positioned at node screen coords. Stored as `NSView` so the dict
    /// can hold heterogeneous hosted views without forcing an `AnyView`
    /// entry on the SwiftUI side (doctrine §6 #6).
    private var pinnedInspectorViews: [String: NSView] = [:]

    // Blur transition layers (stored for page mode animation).
    private var darkenLayer: NSView?
    private var blurView: NSVisualEffectView?

    /// macOS "Reduce Motion" toggle. Read at each animation site rather
    /// than cached, so the user can flip the setting and see it take
    /// effect on the next overlay open without restarting the app.
    private var reduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Animate a window's alphaValue, OR — under Reduce Motion — set it
    /// directly without entering NSAnimationContext / animator() at all,
    /// then fire `completion` synchronously. The companion `setWindowFrame`
    /// helper below has the same shape for setFrame animations. Both
    /// exist so Reduce Motion bypasses AppKit animation infrastructure
    /// entirely. NSPanel passes through these helpers unchanged because
    /// it inherits NSWindow.
    private func setWindowAlpha(
        _ window: NSWindow,
        to alpha: CGFloat,
        duration: TimeInterval,
        timing: CAMediaTimingFunctionName = .easeOut,
        completion: (@Sendable () -> Void)? = nil
    ) {
        if reduceMotionEnabled {
            window.alphaValue = alpha
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: timing)
            window.animator().alphaValue = alpha
        }, completionHandler: completion)
    }

    private func setWindowFrame(
        _ window: NSWindow,
        to frame: NSRect,
        duration: TimeInterval,
        timing: CAMediaTimingFunctionName = .easeInEaseOut,
        completion: (@Sendable () -> Void)? = nil
    ) {
        if reduceMotionEnabled {
            window.setFrame(frame, display: true)
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: timing)
            window.animator().setFrame(frame, display: true)
        }, completionHandler: completion)
    }

    // Note window frame for anchor positioning (page mode only).
    private var noteWindowFrame: NSRect?
    // Observation tokens for tracking note window movement.
    private var noteWindowMoveObserver: Any?
    private var noteWindowResizeObserver: Any?
    // KVO observation for system appearance (light/dark mode) changes.
    private var appearanceObserver: NSKeyValueObservation?
    // Draggable toolbar and sidebar hosting views. Concrete types are
    // `NSHostingView<HologramOverlayHostedView<...>>` at construction; widened
    // to `NSView?` here so heterogeneous hosted views fit one type without
    // pulling an `AnyView` into the SwiftUI side (doctrine §6 #6).
    private var controlsHostView: NSView?
    private var sidebarHostView: NSView?
    private var routeHostView: NSView?
    private var routeObserver: Any?
    private var controlsConstraints: [NSLayoutConstraint] = []
    private var sidebarConstraints: [NSLayoutConstraint] = []
    private var routeConstraints: [NSLayoutConstraint] = []

    // Mini floating panel (chromeless glass float).
    private var miniPanel: GraphOverlayPanel?
    /// Companion panel: holds the inspector alongside the mini graph when minimized.
    private var miniInspectorPanel: GraphOverlayPanel?
    private(set) var isMinimized = false
    /// When true the inspector shows INSIDE the graph panel (the
    /// `inspectorHostView`); when false it shows in the external
    /// `miniInspectorPanel`. Per user 2026-05-10: outside-by-default
    /// with a button to pop it in; embedded variant has a button to
    /// pop it back out.
    private(set) var inspectorEmbeddedInGraph = false
    /// Floating pop-out button shown at the embedded inspector's
    /// top-right corner. Sibling of `inspectorHostView` on the panel's
    /// contentView (NOT a child of the NSHostingView, which would
    /// hide the button under the SwiftUI compositing layer).
    private var inspectorEjectButton: NSView?
    private var selectionObserverTask: Task<Void, Never>?
    private var inspectorPositionTask: Task<Void, Never>?
    /// Dedicated timer for pinned panel position tracking. Runs at ~30fps
    /// independently of node selection so pinned panels follow their nodes
    /// even when nothing is selected. Started when overlay shows, stopped on hide.
    private var pinnedPanelTimer: Timer?
    private var lastForceAlive = false
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

    /// While the immersive overlay is effectively invisible, it must not intercept clicks/keyboard
    /// meant for the main window (e.g. workspace restore opens with alpha 0 before fade-in).
    private func syncImmersivePointerPassthrough(for window: NSWindow?) {
        guard let window else { return }
        window.ignoresMouseEvents = window.alphaValue < 0.02
    }

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

        // Per user 2026-05-10: the graph is always in mini ontology now.
        // The old `if isMinimized { restore(); return }` branch would have
        // re-entered full-screen mode, which no longer exists.

        // Fast path: if engine is still alive from a soft-hide, just resume + show.
        if let window, let metalView {
            restoreImmersiveChromeIfNeeded(window, metalView: metalView)
            prepareImmersiveOverlayWindow(window, screen: NSScreen.main)
            // 2026-05-19: re-apply the Shaped Graph experimental chrome
            // AFTER `prepareImmersiveOverlayWindow` — that call invokes
            // `GraphOverlayPanel.applyPresentation(.floatingPanel)` which
            // forces `hasShadow = true` (and so would overwrite our
            // experimental hasShadow=false). Running our chrome last keeps
            // experimental-mode invariants intact across every reopen.
            applyShapedExperimentalChrome(to: window)
            window.alphaValue = 0
            syncImmersivePointerPassthrough(for: window)
            window.orderFrontRegardless()
            metalView.resumeEngine()
            setWindowAlpha(window, to: 1.0, duration: 0.2) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, let window = self.window, let metalView = self.metalView else { return }
                    self.syncImmersivePointerPassthrough(for: window)
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(metalView)
                    // Title overlay on fast-path: supports everyOpen mode even when
                    // the engine is still warm from a soft-hide.
                    if self.graphState.graphTitleMode == .everyOpen,
                       let contentView = window.contentView {
                        let theme = GraphOverlayThemeStyle.resolvedTheme()
                        self.firstOpenTitleHost.install(in: contentView, isDark: theme.isDark)
                    }
                    self.startPinnedPanelTimer()
                }
            }
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
        syncImmersivePointerPassthrough(for: window)
        window.orderFrontRegardless()

        // On the very first open, delay the fade-in so the engine has time to
        // create Metal pipelines, load graph data, and run the initial commit.
        // This hides the initialization freeze behind a smooth transition.
        // Subsequent opens reuse the cached engine and skip this delay.
        // Under Reduce Motion both the synthetic delay and the AppKit fade
        // are skipped — the window appears at full opacity immediately and
        // the same completion handler runs synchronously.
        let isFirstOpen = !hasShownBefore
        hasShownBefore = true
        let fadeDelay: TimeInterval = (reduceMotionEnabled || !isFirstOpen) ? 0.0 : 0.6
        let fadeDuration = isFirstOpen ? 0.5 : 0.3
        fadeInTask?.cancel()
        fadeInTask = Task { @MainActor [weak self, weak window] in
            if fadeDelay > 0 {
                try? await Task.sleep(for: .seconds(fadeDelay))
            }
            guard !Task.isCancelled, let window, let self else { return }
            self.setWindowAlpha(window, to: 1.0, duration: fadeDuration) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard let window = self.window else {
                        self.fadeInTask = nil
                        return
                    }
                    self.syncImmersivePointerPassthrough(for: window)
                    window.makeKeyAndOrderFront(nil)
                    if let metalView = self.metalView {
                        window.makeFirstResponder(metalView)
                    }
                    // Title overlay — show on first or every open depending on user setting.
                    if let contentView = window.contentView {
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
                    self.fadeInTask = nil
                }
            }
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
            setWindowAlpha(miniPanel, to: 0, duration: 0.2, timing: .easeIn) { [weak self] in
                MainActor.assumeIsolated {
                    self?.teardown()
                }
            }
        case .pauseThenTeardownAfterDelay:
            guard let window else { return }

            // Soft hide: pause engine + hide window, keep engine alive briefly for fast re-show.
            window.ignoresMouseEvents = true
            setWindowAlpha(window, to: 0, duration: 0.2, timing: .easeIn) { [weak self] in
                MainActor.assumeIsolated {
                    window.orderOut(nil)
                    self?.metalView?.pauseEngine()
                    self?.scheduleHiddenTeardown()
                }
            }
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
        // BLUR POLICY: this is the mini-mode blur for the main graph window.
        // The full-screen `self.blurView` (created in show()) was already
        // hidden at line ~600 above, so the window still carries EXACTLY
        // ONE visible blur. On `restore()` this `miniBlur` is removed and
        // `self.blurView.isHidden = false` restores the original.
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

        let miniTint = NSView(frame: contentView.bounds)
        miniTint.wantsLayer = true
        miniTint.identifier = GraphOverlayThemeStyle.miniTintIdentifier
        miniTint.layer?.backgroundColor = GraphOverlayThemeStyle.miniTintColor(
            for: GraphOverlayThemeStyle.resolvedTheme()
        ).cgColor
        miniTint.autoresizingMask = [.width, .height]
        contentView.addSubview(miniTint, positioned: .below, relativeTo: metalView)

        // Round corners for mini mode. 22pt matches MiniChat's continuous
        // curve — mini-float reads as a peer of the chat panel. Fullscreen
        // scales up to 28pt (set in the un-mini path) for the macOS 26
        // liquid-glass immersive feel.
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 22
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true

        setWindowFrame(window, to: miniFrame, duration: 0.3)

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
    ///
    /// Per user 2026-05-10: the unified graph is always in mini ontology;
    /// there is no full-screen mode to restore to. This function is kept
    /// as a no-op for any legacy callers (the expand button infrastructure
    /// has been removed but the symbol may still be referenced). Returns
    /// immediately without changing state.
    func restore() {
        guard false else { return }
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

        // 2. Remove mini-mode additions (mini blur, mini tint, expand button).
        // The previous `$0 is NSHostingView<AnyView>` runtime check was a
        // no-op (the expand button was never typed `<AnyView>`); the
        // identifier-based match below is exact and aligns with doctrine §6 #6
        // (no AnyView in render hot paths).
        window.contentView?.subviews
            .filter {
                $0.identifier == NSUserInterfaceItemIdentifier("miniBlur")
                    || $0.identifier == GraphOverlayThemeStyle.miniTintIdentifier
                    || $0.identifier == Self.miniExpandButtonIdentifier
            }
            .forEach { $0.removeFromSuperview() }

        // 3. Un-hide full-screen subviews.
        blurView?.isHidden = false
        darkenLayer?.isHidden = false
        for subview in window.contentView?.subviews ?? [] {
            subview.isHidden = false
        }

        // Re-apply route-aware chrome state: the blanket un-hide above would
        // otherwise show the sidebar / inspector on top of the note or folder
        // route page, because subviews are inserted above the route host view.
        syncGraphWorkspaceChromeVisibility(isCanvas: graphState.currentRoute.isCanvas)

        // 4. macOS 26 liquid-glass corner radius. 28pt continuous matches
        //    the Tahoe immersive-window curve (more curvy than MiniChat's
        //    22pt, not aggressive like visionOS's 46pt). `visibleFrame`
        //    inset below leaves room above the menubar + above the dock
        //    so the rounded corners actually show instead of being
        //    clipped by the screen edge.
        window.contentView?.layer?.cornerRadius = 28
        window.contentView?.layer?.cornerCurve = .continuous
        window.contentView?.layer?.masksToBounds = true

        // 5. Animate frame change to full screen.
        window.applyPresentation(.immersiveOverlay)
        guard let screen = NSScreen.main else { return }

        setWindowFrame(window, to: screen.visibleFrame, duration: 0.3)

        window.orderFrontRegardless()
        window.makeFirstResponder(metalView)

        // Hide mini inspector if shown
        if let inspector = miniInspectorPanel {
            setWindowAlpha(inspector, to: 0, duration: 0.2) { [weak self] in
                MainActor.assumeIsolated {
                    self?.miniInspectorPanel?.orderOut(nil as NSWindow?)
                    self?.miniInspectorPanel = nil
                }
            }
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

        setWindowAlpha(panel, to: 1.0, duration: 0.25)

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
        content.layer?.cornerRadius = 22
        content.layer?.cornerCurve = .continuous
        content.layer?.masksToBounds = true

        // Blur background — adapts to system light/dark mode.
        // BLUR POLICY: this is the SINGLE blur for the mini cold-start
        // panel (a separate NSPanel — not the main graph window). All
        // SwiftUI chrome rendered into this panel is tinted overlay only.
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
        installKeyDismissalHandler(on: panel)
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

        // BLUR POLICY: this is the SINGLE blur for the mini inspector
        // panel (a separate NSPanel — not the main graph window). The
        // inspector's SwiftUI content renders as tinted overlay only.
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
            let inspectorView = HologramOverlayHostedViewBuilder.host(
                HologramNodeInspector(
                    inspectorState: inspectorState,
                    modelContext: modelContainer.mainContext
                )
            )
            inspectorView.autoresizingMask = [.width, .height]
            inspectorView.frame = content.bounds
            content.addSubview(inspectorView)
        }

        // Pop-in toggle: floats over the top-right corner of the external
        // inspector. Clicking embeds the inspector inside the graph panel
        // and dismisses this floating panel. The embedded variant carries
        // a sibling "pop-out" button that reverses the toggle.
        addInspectorToggleButton(to: content, symbol: "arrow.down.right.and.arrow.up.left", help: "Embed inspector in graph")

        return panel
    }

    /// Shared pop-in / pop-out button factory. Anchors a small circular
    /// icon button to the top-right of `content`. Tap triggers
    /// `toggleInspectorEmbedded()` so the same affordance flips both
    /// directions (external→embedded on the mini inspector panel,
    /// embedded→external on the in-window inspectorHostView).
    private func addInspectorToggleButton(to content: NSView, symbol: String, help: String) {
        let buttonView = makeInspectorToggleButton(symbol: symbol, help: help)
        buttonView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttonView)
        NSLayoutConstraint.activate([
            buttonView.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            buttonView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
        ])
    }

    /// Builds the toggle button view without auto-attaching it. Use this
    /// when the button needs to be placed as a sibling overlay (the
    /// embedded inspector's pop-out button — its parent is the panel's
    /// contentView, not the NSHostingView around the SwiftUI inspector).
    private func makeInspectorToggleButton(symbol: String, help: String) -> NSView {
        let buttonView = NSHostingView(
            rootView: Button {
                MainActor.assumeIsolated {
                    HologramController.shared.toggleInspectorEmbedded()
                }
            } label: {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.75))
                    .frame(width: 26, height: 26)
                    // 2026-05-20: zero-copy chrome. This 26pt dot sits on
                    // top of the graph window's single NSVisualEffectView
                    // blur — a per-button `.ultraThinMaterial` would stack
                    // a redundant blur kernel. Color.primary.opacity reads
                    // light-on-dark / dark-on-light automatically and
                    // costs one tinted-quad draw.
                    .background(
                        Circle().fill(Color.primary.opacity(0.10))
                    )
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help(help)
        )
        buttonView.identifier = NSUserInterfaceItemIdentifier("epistemos.inspectorToggle")
        return buttonView
    }

    /// Mirror the eject button's frame + isHidden to track the
    /// embedded inspectorHostView. Called every time the inspector's
    /// frame or visibility changes.
    private func syncInspectorEjectButtonLayout() {
        guard let inspectorEjectButton, let inspectorHostView else { return }
        // Hide the button whenever the inspector is hidden OR when the
        // inspector is in the external (not-embedded) state. The button
        // is meaningful only as a pop-OUT affordance on the embedded
        // variant.
        let shouldShow = inspectorEmbeddedInGraph && !inspectorHostView.isHidden
        inspectorEjectButton.isHidden = !shouldShow
        // Pin to the inspector's top-right corner, 10pt inset.
        let inspectorFrame = inspectorHostView.frame
        let size: CGFloat = 26
        let inset: CGFloat = 10
        inspectorEjectButton.frame = CGRect(
            x: inspectorFrame.maxX - inset - size,
            y: inspectorFrame.maxY - inset - size,
            width: size,
            height: size
        )
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
                    // 2026-05-20: zero-copy chrome — see makeInspectorToggleButton.
                    .background(
                        Circle().fill(Color.primary.opacity(0.10))
                    )
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Restore to full size")
        )
        buttonView.translatesAutoresizingMaskIntoConstraints = false
        // Identifier lets `restore()` find and remove this button (and only
        // this button) when transitioning back to full-screen. Replaces the
        // fragile-and-broken `$0 is NSHostingView<AnyView>` runtime check.
        buttonView.identifier = Self.miniExpandButtonIdentifier
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
        defer { syncInspectorEjectButtonLayout() }

        // In mini mode the companion miniInspectorPanel handles the
        // inspector — UNLESS the user has popped the inspector INTO the
        // graph via toggleInspectorEmbedded(). When embedded we want the
        // in-window inspectorHostView to be the active surface.
        if isMinimized && !inspectorEmbeddedInGraph {
            inspectorHostView.isHidden = true
            lastInspectorFrame = nil
            resizeMiniInspectorForMode()
            return
        }

        guard graphState.currentRoute.isCanvas else {
            inspectorHostView.isHidden = true
            lastInspectorFrame = nil
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

        // RCA finalization 2026-05-13: feed the resolved overlay
        // theme to the pinned-inspector card so Classic (ChonkyPixels +
        // ALL CAPS) flows through. Other themes get their canonical
        // panel font.
        let overlayTheme = GraphOverlayThemeStyle.resolvedTheme()
        let view = HologramOverlayHostedViewBuilder.host(
            PinnedInspectorPanel(
                inspector: pinned,
                theme: overlayTheme,
                onClose: { [weak self] in self?.unpinInspector(id: pinned.id) }
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
        guard graphState.currentRoute.isCanvas else {
            for view in pinnedInspectorViews.values {
                view.isHidden = true
            }
            return
        }

        guard let contentView = window?.contentView,
              let engineHandle = graphState.engineHandle else { return }
        let mgr = PinnedInspectorManager.shared

        let hasPinned = !mgr.pinnedInspectors.isEmpty
        if hasPinned != lastForceAlive {
            lastForceAlive = hasPinned
            graph_engine_set_force_alive(engineHandle, hasPinned ? 1 : 0)
        }

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
        if let pinnedPanelTimer {
            RunLoop.main.add(pinnedPanelTimer, forMode: .common)
        }
    }

    private func stopPinnedPanelTimer() {
        pinnedPanelTimer?.invalidate()
        pinnedPanelTimer = nil
        if lastForceAlive, let engineHandle = graphState.engineHandle {
            graph_engine_set_force_alive(engineHandle, 0)
            lastForceAlive = false
        }
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
                let hasSelection = s.graphState.selectedNodeId != nil
                if hasSelection {
                    if s.inspectorEmbeddedInGraph {
                        // Embedded variant: show inspectorHostView inside
                        // the graph panel, don't open the external panel.
                        s.inspectorHostView?.isHidden = false
                        s.scheduleInspectorReposition()
                    } else if s.isMinimized {
                        s.showMiniInspector()
                    }
                } else {
                    s.inspectorHostView?.isHidden = true
                    s.hideMiniInspector()
                }
                s.syncInspectorEjectButtonLayout()
            }
        }
    }

    /// Toggle whether the inspector lives inside the graph panel
    /// (`inspectorHostView`) or in the external `miniInspectorPanel`.
    /// Per user 2026-05-10: external is the default; the pop-in button
    /// on the external panel and the pop-out button on the embedded
    /// variant both call this.
    func toggleInspectorEmbedded() {
        inspectorEmbeddedInGraph.toggle()
        let hasSelection = graphState.selectedNodeId != nil
        if inspectorEmbeddedInGraph {
            // Embed: tear down external, reveal in-window.
            hideMiniInspector()
            inspectorHostView?.isHidden = !hasSelection
            if hasSelection {
                scheduleInspectorReposition()
            }
        } else {
            // Eject: hide in-window, bring up external.
            inspectorHostView?.isHidden = true
            if hasSelection, isMinimized {
                showMiniInspector()
            }
        }
        syncInspectorEjectButtonLayout()
    }

    private func showMiniInspector() {
        guard miniInspectorPanel == nil, let miniPanel else { return }
        let panel = createMiniInspectorPanel(relativeTo: miniPanel)
        self.miniInspectorPanel = panel
        panel.alphaValue = 0
        panel.orderFront(nil)
        setWindowAlpha(panel, to: 1.0, duration: 0.25)
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

        setWindowFrame(
            panel,
            to: NSRect(x: clampedX, y: clampedY, width: newWidth, height: newHeight),
            duration: 0.25
        )
    }

    private func hideMiniInspector() {
        guard let panel = miniInspectorPanel else { return }
        setWindowAlpha(panel, to: 0, duration: 0.2, timing: .easeIn) { [weak self] in
            MainActor.assumeIsolated {
                self?.miniInspectorPanel?.orderOut(nil)
                self?.miniInspectorPanel = nil
            }
        }
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

    private func syncGraphWorkspaceChromeVisibility(isCanvas: Bool) {
        routeHostView?.isHidden = isCanvas
        controlsHostView?.isHidden = !isCanvas
        sidebarHostView?.isHidden = !isCanvas

        // User-authorized UI change 2026-05-14, REFINED 2026-05-15
        // (RCA-GRAPH-NOTE-BLUR-001):
        //
        // The intent is: when navigating from canvas to a note/folder
        // route, hide the graph NODES (Metal-rendered content) and
        // graph controls, but KEEP the blur wallpaper + darken layer
        // visible underneath the note panel. The blur + darken
        // together form the "graph ontology" wallpaper aesthetic; the
        // note editor is supposed to INHERIT that blur, not get a
        // plain background.
        //
        // History of this site:
        //   - 2026-05-13 and earlier: nothing on this path. Result:
        //     graph nodes bled through the note panel.
        //   - 2026-05-14 (commit 8e371de91): metalView + blurView +
        //     darkenLayer ALL hidden on !isCanvas. Result: graph
        //     nodes correctly hidden BUT the blur wallpaper that
        //     was supposed to back the note panel disappeared too —
        //     user-reported "compeltly got rid of the blur background
        //     i just wanted the graph node stuff to not be there".
        //   - 2026-05-15 (this commit): only metalView is hidden on
        //     !isCanvas. blurView + darkenLayer stay visible so the
        //     note panel inherits the graph's blur ontology.
        //
        // The Metal engine itself is paused/resumed below — when the
        // graph route returns, the engine resumes and starts producing
        // frames again. While paused, the last frame would be visible
        // if metalView were not hidden; hiding metalView is what
        // actually keeps the graph nodes off the screen.
        //
        // Renderer / camera / layout / edges / physics / hologram
        // overlay visuals are UNTOUCHED — this is purely an animated
        // alpha+isHidden transition on the Metal NSView host.
        //
        // 2026-05-20 smooth-transition fix: previously this was a hard
        // `metalView.isHidden = !isCanvas` flip — graph nodes vanished
        // instantly when going to a note. Now nodes fade out over 250ms
        // (or instantly under Reduce Motion) so the canvas dissolves into
        // the existing blur wallpaper instead of snapping away.
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let transitionDuration: TimeInterval = reduceMotion ? 0 : 0.25

        if isCanvas {
            // Returning to canvas — start hidden+transparent, then fade nodes in.
            if let metalView {
                metalView.alphaValue = 0.0
                metalView.isHidden = false
                // Resume engine so frames are flowing before alpha goes positive.
                metalView.resumeEngine()
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = transitionDuration
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    metalView.animator().alphaValue = 1.0
                })
            }
            repositionInspector()
            updatePinnedInspectorPositions()
            graphState.startOverlayPhysicsCycle()
            return
        }

        // Leaving canvas (note / folder route) — fade nodes out, then hide.
        if let metalView, !metalView.isHidden {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = transitionDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                metalView.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.metalView?.isHidden = true
                    // Reset alpha so the next canvas return starts from a
                    // known state — the canvas-return path above sets it
                    // back to 0 explicitly before fading in to 1.
                }
            })
        } else {
            metalView?.isHidden = true
        }

        UtilityWindowManager.shared.hide(.notes)
        inspectorHostView?.isHidden = true
        lastInspectorFrame = nil
        for view in pinnedInspectorViews.values {
            view.isHidden = true
        }
        graphState.cancelOverlayPhysicsCycle()

        // Fully pause the Metal render loop while the user is on a note or
        // folder route. Without this the CVDisplayLink keeps ticking and
        // even if renderNeeded=false the background thread wakes the main
        // queue at display-refresh rate, stealing cycles from the TextKit 2
        // prose editor and causing visible stutter while typing / scrolling
        // inside the graph-native note page.
        metalView?.pauseEngine()
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
        // Remove graph workspace route observer.
        if let obs = routeObserver { NotificationCenter.default.removeObserver(obs) }
        routeObserver = nil
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

        // Per user 2026-05-10: fuse the full-screen and mini graphs into ONE
        // graph (the mini ontology). The window opens as a floating panel
        // (resizable, borderless, .floating level) at the new larger
        // GraphMiniPanelLayout.defaultSide — never as the `.screenSaver`-
        // level immersive full-screen overlay that was laggy on retina.
        let initialFrame = GraphMiniPanelLayout.frame(in: screen.visibleFrame)
        let window = GraphOverlayPanel(contentRect: initialFrame)
        window.applyPresentation(.floatingPanel)
        window.appearance = GraphOverlayThemeStyle.windowAppearance(for: theme)

        // Build the content: Metal graph + floating controls + search sidebar.
        // No full-screen blur — the floating-panel chrome carries the glass
        // feel via miniBlur + miniTint added below.
        let contentView = NSView(frame: initialFrame)
        contentView.wantsLayer = true
        // 2026-05-20: macOS 26 liquid-glass corner radius. 28pt continuous
        // ALWAYS (regardless of experimental). 28pt matches the Tahoe
        // immersive-window curve (was 16pt, which left a visible
        // square-edged ring where the rectangular toolbar/sidebar
        // chrome met the window's mild round). `.continuous` cornerCurve
        // gives a smooth round all the way to the chrome edges.
        //
        // Shaped Graph (experimental, 2026-05-19): the toggle ONLY removes
        // the blur + darken layers (handled by applyShapedExperimentalChrome).
        // It does NOT remove the rounded corners — per the authoritative
        // comment in applyShapedExperimentalChrome ("Content view rounded
        // corners — always rounded, regardless of experimental"). The
        // prior `isExperimental ? 0 : 28` here was stale code that got
        // overwritten anyway on the very next call to applyShapedExperimentalChrome.
        contentView.layer?.cornerRadius = 28
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
        // ALWAYS clear the contentView's layer background — even with
        // masksToBounds=true the layer's own background color leaks into
        // the antialiased pixels at the corner, producing a thin sharp
        // ring around the rounded curve. Clear background = clean curve.
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.isOpaque = false

        // Frosted glass background — adapts to system appearance.
        // Bounded to contentView (panel-sized) instead of full screen.
        // `.followsWindowActiveState` pauses the blur kernel when window
        // unfocused. Panel-sized blur is ~10-20× cheaper than the previous
        // full-screen blur, so the cinematic graph renders fluidly.
        //
        // BLUR POLICY: THIS is the main graph window's single blur. All
        // SwiftUI chrome inside this window (folder navigator, note,
        // inspector, search sidebar, floating controls, header strip)
        // renders as `theme.glassBg` tinted overlay on top — no nested
        // Material / .glassEffect / NSVisualEffectView. See file header
        // comment + Epistemos/Views/Shared/UnifiedFrostedGlass.swift.
        let blur = NSVisualEffectView(frame: contentView.bounds)
        blur.material = GraphOverlayThemeStyle.blurMaterial(for: theme)
        blur.blendingMode = .behindWindow
        blur.state = .followsWindowActiveState
        blur.autoresizingMask = [.width, .height]
        contentView.addSubview(blur)
        self.blurView = blur

        // Tint overlay for depth — white in light mode for a bright frosted look.
        let darken = NSView(frame: contentView.bounds)
        darken.wantsLayer = true
        darken.layer?.backgroundColor = GraphOverlayThemeStyle.overlayTintColor(
            for: theme
        ).cgColor
        darken.autoresizingMask = [.width, .height]
        contentView.addSubview(darken)
        self.darkenLayer = darken

        // Shaped Graph (experimental, 2026-05-19): apply the initial chrome
        // state based on the current toggle. Re-applied on every reopen by
        // `applyShapedExperimentalChrome(to:)` so a toggle change between
        // close + reopen always takes effect.
        applyShapedExperimentalChrome(to: window)

        // Metal graph view (fills the panel). isMiniMode = true so it
        // skips the pixel-budget cap and uses the proven-fluid mini render
        // path (same setting that made the old "minimized" graph snappy).
        let graphView = MetalGraphNSView(frame: contentView.bounds)
        graphView.graphState = graphState
        graphView.physicsCoordinator = physicsCoordinator
        graphView.dialogueChatState = dialogueChatState
        graphView.isOverlayMode = true
        graphView.isMiniMode = true
        graphView.setLightMode(GraphOverlayThemeStyle.lightModeEnabled(for: theme))
        graphView.autoresizingMask = [.width, .height]
        contentView.addSubview(graphView)

        // Shaped Graph (experimental, 2026-05-19) — the shape-blur overlay
        // was removed per user direction. They prefer the nodes-only view
        // with no theme/blur on top. The toggle still controls the HUD
        // chrome clearing (above) so the window background goes away when
        // experimental mode is on, leaving just the Metal nodes against the
        // desktop. The ShapedGraphBoundaryView file is kept dormant in case
        // we revisit the shape overlay.

        // Graph Workspace Route overlay (SwiftUI hosted — full screen or pass-through).
        //
        // The route host view sits above the Metal canvas and draws the note /
        // folder pages when the user deep-links into a node. While the route
        // is `.canvas`, the host is hidden entirely so mouse events flow to
        // `MetalGraphNSView` unchanged. A Notification.Name observer flips
        // `isHidden` whenever `GraphState.currentRoute` changes.
        let routeView = HologramOverlayHostedViewBuilder.host(GraphWorkspaceContainer())
        routeView.translatesAutoresizingMaskIntoConstraints = false
        routeView.isHidden = graphState.currentRoute.isCanvas
        contentView.addSubview(routeView, positioned: .above, relativeTo: graphView)
        self.routeHostView = routeView

        let rtConstraints = [
            routeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            routeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            routeView.topAnchor.constraint(equalTo: contentView.topAnchor),
            routeView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(rtConstraints)
        self.routeConstraints = rtConstraints

        routeObserver = NotificationCenter.default.addObserver(
            forName: .graphRouteDidChange,
            object: graphState,
            queue: .main
        ) { [weak self] _ in
            // NotificationCenter delivery is on `.main` so the @Sendable
            // closure body runs on the main thread. Hop into the main actor
            // explicitly so Swift 6 strict concurrency lets us touch the
            // MainActor-isolated `graphState` / `routeHostView`.
            MainActor.assumeIsolated {
                guard let self else { return }
                let isCanvas = self.graphState.currentRoute.isCanvas
                self.syncGraphWorkspaceChromeVisibility(isCanvas: isCanvas)
                if let window = self.window {
                    self.applyShapedExperimentalChrome(to: window)
                }
            }
        }

        // Floating controls (SwiftUI hosted — draggable).
        let controlsView = HologramOverlayHostedViewBuilder.host(GraphFloatingControls())
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

        // FPS HUD (2026-05-20) — small live readout in bottom-right.
        // Visibility is driven by the SwiftUI body reading
        // `graphState.graphFPSHUDEnabled`; the SwiftUI side returns
        // an EmptyView when off, so we always mount the host but
        // it's invisible until the user toggles it on in Settings.
        let fpsHUDView = HologramOverlayHostedViewBuilder.host(
            GraphFPSHUDHostView()
        )
        fpsHUDView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fpsHUDView)
        NSLayoutConstraint.activate([
            fpsHUDView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            fpsHUDView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])

        // Search sidebar (SwiftUI hosted — draggable).
        let sidebarRoot = HologramSearchSidebar(
            inspectorState: inspectorState,
            modelContext: modelContainer?.mainContext
        ) { [weak graphView, weak self] uuid in
            graphView?.isolateNode(uuid)
            self?.graphState.selectNode(uuid)
        }
        let sidebarView = HologramOverlayHostedViewBuilder.host(sidebarRoot)
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
            let inspectorView = HologramOverlayHostedViewBuilder.host(
                HologramNodeInspector(
                    inspectorState: inspectorState,
                    modelContext: modelContainer.mainContext
                )
            )
            // Use frame-based positioning (updated by inspectorPositionTask).
            // Per user 2026-05-10: inspector is HIDDEN by default in the
            // unified graph; the external miniInspectorPanel is the default
            // visible surface. The in-window inspectorHostView remains as
            // the "embedded" opt-in variant — toggled via a button on the
            // external panel (TODO: wire pop-in/pop-out toggle).
            inspectorView.frame = CGRect(
                x: max(0, contentView.bounds.width - 420),
                y: 60,
                width: 380,
                height: 500
            )
            inspectorView.autoresizesSubviews = true
            inspectorView.isHidden = true
            inspectorView.wantsLayer = true
            contentView.addSubview(inspectorView)
            self.inspectorHostView = inspectorView
            // Pop-out toggle floats at the embedded inspector's top-right.
            // It's a SIBLING on the contentView (not a child of the
            // NSHostingView) so the SwiftUI compositing layer can't hide
            // it. Its frame + isHidden track inspectorView via
            // `syncInspectorEjectButtonLayout()`.
            let ejectButton = makeInspectorToggleButton(
                symbol: "arrow.up.left.and.arrow.down.right",
                help: "Pop inspector out of graph"
            )
            ejectButton.isHidden = true
            contentView.addSubview(ejectButton)
            self.inspectorEjectButton = ejectButton
            syncInspectorEjectButtonLayout()
            startInspectorPositionTracking()
        }

        syncGraphWorkspaceChromeVisibility(isCanvas: graphState.currentRoute.isCanvas)

        window.contentView = contentView

        installKeyDismissalHandler(on: window)

        self.window = window
        self.metalView = graphView

        // Per user 2026-05-10: the unified graph (mini ontology) wires the
        // same observers + parent-window attachment + pinned-panel timer
        // that the old `minimize()` path used to set up. The external
        // mini inspector panel is now the default node-selection inspector.
        // `isMinimized = true` keeps every existing "is the graph in mini
        // mode" check truthy — minimize/restore is no longer a user-facing
        // state machine; the graph IS the mini.
        isMinimized = true
        attachFloatingPanelToMainWindow(window)
        self.miniPanel = window
        observeNodeSelection()
        startPinnedPanelTimer()

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

    private func installKeyDismissalHandler(on panel: GraphOverlayPanel) {
        panel.keyEventHandler = { [weak self] event in
            guard let self, self.isVisible else { return false }

            // Escape — guard: don't consume if a text field is focused.
            if event.keyCode == 53 {
                let keyWindow = self.isMinimized ? self.miniPanel : self.window
                if let responder = keyWindow?.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return false
                }
                HologramController.shared.hide()
                return true
            }

            // Cmd+W — standard macOS close shortcut.
            if event.keyCode == 13 {
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.capsLock, .numericPad, .function])
                if mods == .command {
                    HologramController.shared.hide()
                    return true
                }
            }

            return false
        }
    }

    /// Re-applies the Shaped Graph (experimental) chrome state every time
    /// the overlay reopens or the route changes. Pure idempotent: safe to
    /// call on every `show()` and from the route observer.
    ///
    /// 2026-05-19 user direction (round 2): only the CANVAS route gets the
    /// fully-transparent treatment; when the user opens a note or a folder
    /// the HUD blur must reappear behind the panel so the text reads
    /// against a themed backdrop instead of the bare desktop. So the
    /// "hide chrome" predicate is `experimental && currentRoute == .canvas`,
    /// not just `experimental`.
    private func applyShapedExperimentalChrome(to window: NSWindow) {
        let isExperimental = AppBootstrap.shared?.uiState.shapedGraphExperimental == true

        let hideChrome = isExperimental && graphState.currentRoute.isCanvas

        // 2026-05-20 (bugfix): the window MUST stay transparent ALWAYS.
        // The prior `hideChrome ? .clear : NSColor.windowBackgroundColor`
        // logic painted a solid gray windowBackgroundColor RECTANGLE
        // behind the rounded contentView mask in every common case (any
        // non-experimental session, OR experimental on note/folder route).
        // Result: gray pixels filled the corners OUTSIDE the rounded
        // mask → visible sharp rectangular "pointy box outline" around
        // the curve. The contentView's masksToBounds=true only clips its
        // OWN content; it doesn't stop the window from painting opaque
        // background pixels in the corner gaps.
        //
        // GraphOverlayPanel.init already sets these to clear/false; we
        // just need to NOT clobber that here. The rounded silhouette is
        // defined entirely by the contentView's masked content.
        window.backgroundColor = .clear
        window.isOpaque = false

        // Drop the NSWindow shadow when experimental is on. The shadow is
        // the source of the "bubble" halo the user reported — it renders
        // around the panel frame even when the panel itself is invisible,
        // and is brighter on light desktops + when the window is key.
        window.hasShadow = !hideChrome

        // Content view rounded corners — always rounded, regardless of
        // experimental. Per user direction (2026-05-20), 28pt continuous
        // matches the macOS 26 immersive panel curve (was 22pt; bumped
        // for consistency with the initial show() + restore() paths and
        // to kill the visible "square corner" where rectangular chrome
        // meets a too-mild round). In experimental mode the layer
        // background is transparent so the desktop shows through inside
        // the rounded shape.
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 28
            contentView.layer?.cornerCurve = .continuous
            contentView.layer?.masksToBounds = true
            // Always-clear layer background to kill antialiased corner
            // ring artifacts (see initial show() path).
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            contentView.layer?.isOpaque = false
        }

        // HUD blur + tint visibility — same predicate as window chrome.
        blurView?.isHidden = hideChrome
        darkenLayer?.isHidden = hideChrome
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

        // Route-aware chrome restore (see restore() above).
        syncGraphWorkspaceChromeVisibility(isCanvas: graphState.currentRoute.isCanvas)

        // 2026-05-20: prior code set cornerRadius=0 + masksToBounds=false +
        // applyPresentation(.immersiveOverlay) here. Both were stale —
        // per user 2026-05-10 the graph is mini-ontology floating-panel
        // ALWAYS (no immersive mode). The cornerRadius=0 transition was
        // the source of the "rectangle bleeding through editor on note
        // route" the user reported 2026-05-20: this function runs on
        // every show(), briefly square-ifies the window before
        // `applyShapedExperimentalChrome` rounds it back, producing a
        // visible square edge flash + leaving the ProseEditor's
        // background rectangle visible at the corners while the radius
        // is 0. Keep the rounded corners + floating-panel presentation
        // consistent across every code path.
        window.contentView?.layer?.cornerRadius = 28
        window.contentView?.layer?.cornerCurve = .continuous
        window.contentView?.layer?.masksToBounds = true
        // Do NOT call applyPresentation(.immersiveOverlay) — it's a
        // deprecated path (per `prepareImmersiveOverlayWindow` comment
        // line 2201). prepareImmersiveOverlayWindow() runs next and
        // applies the correct .floatingPanel presentation.
    }

    /// Per user 2026-05-10: the single unified graph (mini ontology) always
    /// presents as a `.floatingPanel` at the GraphMiniPanelLayout size.
    /// This function used to switch the window into `.immersiveOverlay`
    /// + full-screen frame, which is what caused the `.screenSaver`-level
    /// compositor lag. Now both cold-start and warm-reopen paths produce
    /// the same floating-panel configuration.
    private func prepareImmersiveOverlayWindow(_ window: GraphOverlayPanel, screen: NSScreen?) {
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }
        window.applyPresentation(.floatingPanel)
        if let screen,
           !window.isVisible || window.frame.size == screen.frame.size {
            // Only re-frame to the mini layout when the window hasn't
            // been user-resized. The user can drag-resize the panel to
            // whatever size they want; we shouldn't snap it back on
            // every show().
            window.setFrame(GraphMiniPanelLayout.frame(in: screen.visibleFrame), display: true)
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
