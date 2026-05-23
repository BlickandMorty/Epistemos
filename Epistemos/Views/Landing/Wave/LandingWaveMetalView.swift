import AppKit
import MetalKit
import OSLog
import QuartzCore
import SwiftUI

private let landingWaveLog = Logger(subsystem: "com.epistemos", category: "LandingWave")

/// SwiftUI wrapper around an `MTKView` hosting the landing liquid-wave renderer.
///
/// - Uses `paused = true` + manual `draw()` calls driven by a `CADisplayLink`
///   so the renderer only runs when the landing surface is visible AND the
///   window is front-most. This is the single most important performance
///   knob — without it the renderer would burn GPU 60× per second even when
///   the landing tab isn't focused.
/// - The view forwards click locations to a binding the host observes, so
///   SwiftUI state drives the emergence animation of the flat bar on top.
/// - `reduceMotion` collapses the renderer to a static transparent layer;
///   the host should not present the overlay at all in that mode.
struct LandingWaveMetalView: NSViewRepresentable {
    /// Whether the display-link tick is active. The host sets this to false
    /// when the overlay is dismissed or the window is occluded.
    var isActive: Bool
    /// Reduce-motion: when true, renderer stays idle. Host should skip drawing
    /// the overlay entirely; this flag is a safety net.
    var reduceMotion: Bool
    /// Click events pushed from the parent — each click becomes a fresh drop
    /// impulse. The parent bumps `trigger` on every click to force a new fire.
    var dropTrigger: Int
    /// Last click location in the view's local coordinate space (points).
    var clickLocation: CGPoint?
    /// Approximate cursor velocity (direction vector, unit-normalized) captured
    /// just before the click, for the anisotropic ripple bias.
    var cursorDirection: CGVector

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return MTKView()
        }
        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        // 2026-05-20: removed the hardcoded 60Hz cap on the initial
        // MTKView config. The CADisplayLink that actually drives the
        // wave is configured separately (see LandingWaveMetalView's
        // displayLink path) and respects LandingWavePerformancePolicy.
        // Leaving `preferredFramesPerSecond` at the default (0 = use
        // display's native refresh rate) lets ProMotion drive the
        // bootstrap render at 120Hz instead of clamping every wave
        // bootstrap to 60.
        view.preferredFramesPerSecond = 0
        view.layer?.isOpaque = false
        view.autoResizeDrawable = true

        let coordinator = context.coordinator
        coordinator.attach(view: view, device: device)
        view.delegate = coordinator
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let coordinator = context.coordinator
        coordinator.applyReduceMotion(reduceMotion)
        coordinator.setActive(isActive && !reduceMotion)
        if dropTrigger != coordinator.lastDropTrigger {
            coordinator.lastDropTrigger = dropTrigger
            if let location = clickLocation, !reduceMotion {
                // Cache the click; the coordinator tries to fire immediately
                // and otherwise re-attempts once the view has a non-zero size.
                coordinator.requestDrop(
                    at: location,
                    viewSize: nsView.bounds.size,
                    cursorDirection: cursorDirection
                )
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate {
        private weak var view: MTKView?
        private(set) var renderer: LandingWaveRenderer?
        private var displayLink: CADisplayLink?
        private var isRenderingFrame = false
        // Observer tokens are written once (on main) and read once (in
        // nonisolated deinit). The `nonisolated(unsafe)` marker is safe here
        // because there's no concurrent access pattern — registration happens
        // at coordinator attach time; removal happens at deinit. Any future
        // code that writes these from multiple isolation domains must revisit
        // this assumption.
        nonisolated(unsafe) private var powerObserver: NSObjectProtocol?
        nonisolated(unsafe) private var thermalObserver: NSObjectProtocol?
        var lastDropTrigger: Int = 0

        // Pending click cached until the view has a non-zero size. SwiftUI's
        // `updateNSView` can fire before the MTKView is laid out; without
        // this buffer the user's first click fires a drop the renderer
        // silently rejects (viewSize guard in `scheduleDrop`).
        private var pendingClickLocation: CGPoint?
        private var pendingCursorDirection: CGVector = .zero

        deinit {
            if let powerObserver {
                NotificationCenter.default.removeObserver(powerObserver)
            }
            if let thermalObserver {
                NotificationCenter.default.removeObserver(thermalObserver)
            }
        }

        func attach(view: MTKView, device: MTLDevice) {
            self.view = view
            let renderer = LandingWaveRenderer(device: device)
            self.renderer = renderer
            if renderer == nil {
                landingWaveLog.error(
                    "LandingWaveRenderer failed to init — check Metal library + PSO build"
                )
            }
            self.mtkView(view, drawableSizeWillChange: view.drawableSize)
            registerPowerAndThermalObservers()
        }

        func applyReduceMotion(_ reduced: Bool) {
            renderer?.reduceMotion = reduced
        }

        func setActive(_ active: Bool) {
            if active {
                startDisplayLinkIfNeeded()
            } else {
                stopDisplayLink()
            }
        }

        /// Try to fire the drop immediately if the view already has a valid
        /// size. Otherwise cache it until the drawable-size delegate callback
        /// tells us the view has been laid out.
        func requestDrop(at location: CGPoint, viewSize: CGSize, cursorDirection: CGVector) {
            if viewSize.width > 0, viewSize.height > 0 {
                landingWaveLog.debug(
                    "LandingWave drop fired immediately at \(location.debugDescription, privacy: .public) size=\(viewSize.debugDescription, privacy: .public)"
                )
                renderer?.scheduleDrop(
                    at: location,
                    viewSize: viewSize,
                    cursorDirection: cursorDirection
                )
                pendingClickLocation = nil
            } else {
                landingWaveLog.debug(
                    "LandingWave drop cached (view not sized yet)"
                )
                pendingClickLocation = location
                pendingCursorDirection = cursorDirection
            }
        }

        private func flushPendingDropIfReady(using view: MTKView) {
            guard let pending = pendingClickLocation else { return }
            let size = view.bounds.size
            guard size.width > 0, size.height > 0 else { return }
            landingWaveLog.debug(
                "LandingWave flushing cached drop at \(pending.debugDescription, privacy: .public)"
            )
            renderer?.scheduleDrop(
                at: pending,
                viewSize: size,
                cursorDirection: pendingCursorDirection
            )
            pendingClickLocation = nil
        }

        private func startDisplayLinkIfNeeded() {
            if displayLink != nil { return }
            guard let view else { return }
            let link: CADisplayLink
            if #available(macOS 14.0, *) {
                link = view.displayLink(target: self, selector: #selector(onDisplayLink))
            } else {
                return
            }
            link.preferredFrameRateRange = LandingWavePerformancePolicy.frameRateRange(
                for: LandingWavePerformancePolicy.currentTier()
            )
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        }

        private func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func onDisplayLink() {
            guard let view else { return }
            // Kicking draw() on the MTKView triggers our delegate callback.
            view.draw()
        }

        private func registerPowerAndThermalObservers() {
            let center = NotificationCenter.default
            powerObserver = center.addObserver(
                forName: Notification.Name.NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshFrameRateRange()
                }
            }
            thermalObserver = center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshFrameRateRange()
                }
            }
        }

        private func refreshFrameRateRange() {
            guard let displayLink else { return }
            displayLink.preferredFrameRateRange = LandingWavePerformancePolicy.frameRateRange(
                for: LandingWavePerformancePolicy.currentTier()
            )
        }

        // MARK: - MTKViewDelegate

        nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            Task { @MainActor in
                renderer?.resize(
                    to: view.bounds.size,
                    drawableScale: view.window?.backingScaleFactor ?? 2.0
                )
                flushPendingDropIfReady(using: view)
            }
        }

        nonisolated func draw(in view: MTKView) {
            guard Thread.isMainThread else { return }
            MainActor.assumeIsolated {
                renderFrame(in: view)
            }
        }

        private func renderFrame(in view: MTKView) {
            guard !isRenderingFrame else { return }
            guard view.drawableSize.width > 0, view.drawableSize.height > 0 else { return }
            isRenderingFrame = true
            defer { isRenderingFrame = false }

            // Late-arriving sizes: MTKView can present its first valid
            // drawable without a prior drawableSizeWillChange, so also
            // retry the cached click here.
            flushPendingDropIfReady(using: view)
            renderer?.render(in: view)
        }
    }
}
