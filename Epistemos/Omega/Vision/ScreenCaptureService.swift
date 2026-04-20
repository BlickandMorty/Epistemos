import Foundation
import AppKit
import ScreenCaptureKit
import os

// MARK: - Screen Capture Service

/// Captures screenshots via ScreenCaptureKit (macOS 13+).
/// Requires Screen Recording permission (TCC prompt on first use).
///
/// Two capture modes:
/// 1. One-shot: `captureFrontmostWindow()`, `captureApp()` — single frame
/// 2. Streaming: `startStream()` / `latestFrame` — continuous pipeline with
///    buffer dropping for <200ms latency target
@MainActor
final class ScreenCaptureService {

    private let log = Logger(subsystem: "com.epistemos.omega", category: "ScreenCapture")

    /// Wrapper for SCShareableContent that centralizes the call.
    /// SCShareableContent is an async API that suspends the calling actor,
    /// so it doesn't block the main thread. The real hang risk is from
    /// synchronous TCC calls (fixed in TCCPermissionState).
    private func fetchShareableContent(
        excludeDesktop: Bool = false,
        onScreenOnly: Bool = true
    ) async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(excludeDesktop, onScreenWindowsOnly: onScreenOnly)
    }

    private func logCaptureFailure(_ operation: String, error: Error) {
        log.warning("\(operation, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Streaming Pipeline

    /// Active stream (nil when not streaming).
    private var activeStream: SCStream?

    /// Delegate that receives frames and feeds the AsyncStream.
    private var streamDelegate: ScreenStreamDelegate?

    /// Latest captured frame. Updated continuously during streaming.
    /// Uses buffer dropping — only the most recent frame is kept.
    private(set) var latestFrame: CGImage?

    /// Timestamp of the latest frame.
    private(set) var latestFrameTimestamp: ContinuousClock.Instant?

    /// Whether a streaming session is active.
    var isStreaming: Bool { activeStream != nil }

    /// Start continuous frame capture for an app or the full display.
    /// Drops all but the newest frame to maintain <200ms latency.
    func startStream(
        bundleID: String? = nil,
        targetFPS: Int = 10,
        scale: Int = 1
    ) async throws {
        guard activeStream == nil else { return }

        // Block streaming in eco/low-power mode — screen capture is a heavy battery drain.
        guard !PowerGuard.shared.shouldDisableBackground else {
            log.info("Stream blocked — eco/low-power mode active")
            return
        }

        let content = try await fetchShareableContent(excludeDesktop: false, onScreenOnly: true)

        let filter: SCContentFilter
        if let bundleID,
           let window = content.windows.first(where: {
               $0.owningApplication?.bundleIdentifier == bundleID && $0.isOnScreen
           }) {
            filter = SCContentFilter(desktopIndependentWindow: window)
        } else if let display = content.displays.first {
            filter = SCContentFilter(display: display, excludingWindows: [])
        } else {
            throw ScreenCaptureError.noDisplay
        }

        let config = SCStreamConfiguration()
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
        config.queueDepth = 3
        config.showsCursor = false

        // Use 1x scale for speed, 2x for Retina quality
        if let display = content.displays.first {
            config.width = Int(display.width) * scale
            config.height = Int(display.height) * scale
        }

        let delegate = ScreenStreamDelegate { [weak self] frame in
            // Buffer dropping: dispatch to main actor, always replace with latest
            DispatchQueue.main.async {
                self?.latestFrame = frame
                self?.latestFrameTimestamp = .now
            }
        }
        self.streamDelegate = delegate

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        try await stream.startCapture()

        self.activeStream = stream
        log.info("Stream started: \(targetFPS)fps, scale=\(scale)x")
    }

    /// Stop the continuous frame capture stream.
    func stopStream() async {
        guard let stream = activeStream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            log.warning("Stream stop error: \(error.localizedDescription)")
        }
        activeStream = nil
        streamDelegate = nil
        log.info("Stream stopped")
    }

    /// Restart ScreenCaptureKit's backing daemon (replayd) and re-establish the stream.
    /// Call this when capture returns nil frames or ScreenCaptureKit throws after a
    /// cdhash mismatch / sandbox denial (replayd deny file-read-data).
    func recoverStream(
        bundleID: String? = nil,
        targetFPS: Int = 10,
        scale: Int = 1
    ) async {
        log.warning("Attempting replayd recovery — tearing down stream and restarting")
        await stopStream()

        // Kick the replayd daemon so it picks up the app's current cdhash.
        // This is a no-op if the daemon isn't running (it'll start fresh).
        let uid = getuid()
        await restartReplayd(for: uid)

        // Brief cooldown for the daemon to re-initialize
        try? await Task.sleep(for: .milliseconds(500))

        do {
            try await startStream(bundleID: bundleID, targetFPS: targetFPS, scale: scale)
            log.info("Stream recovered successfully after replayd restart")
        } catch {
            log.error("Stream recovery failed: \(error.localizedDescription)")
        }
    }

    private nonisolated func restartReplayd(for uid: uid_t) async {
        await Task.detached(priority: .utility) {
            let kickTask = Process.init()
            kickTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            kickTask.arguments = ["kickstart", "-k", "gui/\(uid)/com.apple.replayd"]
            do {
                try kickTask.run()
                kickTask.waitUntilExit()
            } catch {
                let logger = Logger(subsystem: "com.epistemos.omega", category: "ScreenCapture")
                logger.error("Failed to restart replayd: \(error.localizedDescription)")
            }
        }.value
    }

    /// Get the latest frame, waiting up to maxWaitMs if no frame is available yet.
    func awaitFrame(maxWaitMs: Int = 200) async -> CGImage? {
        if let frame = latestFrame { return frame }

        // Brief poll for first frame arrival
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(maxWaitMs))
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            if let frame = latestFrame { return frame }
        }
        return nil
    }

    /// Capture the frontmost window as a CGImage via ScreenCaptureKit.
    func captureFrontmostWindow() async -> CGImage? {
        do {
            let content = try await fetchShareableContent(excludeDesktop: false, onScreenOnly: true)

            // Find the frontmost on-screen window (excluding desktop and menubar)
            guard let window = content.windows
                .filter({ $0.isOnScreen && $0.frame.width > 100 && $0.frame.height > 100 })
                .sorted(by: { $0.windowLayer < $1.windowLayer })
                .first
            else {
                return nil
            }

            return try await captureWindow(window)
        } catch {
            logCaptureFailure("captureFrontmostWindow", error: error)
            return nil
        }
    }

    /// Capture a specific window by its SCWindow reference.
    func captureWindow(_ window: SCWindow) async throws -> CGImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2 // Retina
        config.height = Int(window.frame.height) * 2
        config.scalesToFit = false
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    /// Capture a specific display (full screen).
    func captureDisplay(_ display: SCDisplay? = nil) async -> CGImage? {
        do {
            let content = try await fetchShareableContent(excludeDesktop: false, onScreenOnly: true)

            guard let targetDisplay = display ?? content.displays.first else {
                return nil
            }

            let filter = SCContentFilter(
                display: targetDisplay,
                excludingWindows: []
            )
            let config = SCStreamConfiguration()
            config.width = Int(targetDisplay.width) * 2
            config.height = Int(targetDisplay.height) * 2
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            logCaptureFailure("captureDisplay", error: error)
            return nil
        }
    }

    /// Capture a specific app's windows by bundle ID.
    func captureApp(bundleID: String) async -> CGImage? {
        do {
            let content = try await fetchShareableContent(excludeDesktop: false, onScreenOnly: true)

            guard content.applications.contains(where: { $0.bundleIdentifier == bundleID }),
                  let window = content.windows.first(where: {
                      $0.owningApplication?.bundleIdentifier == bundleID && $0.isOnScreen
                  }) else {
                return nil
            }

            return try await captureWindow(window)
        } catch {
            logCaptureFailure("captureApp", error: error)
            return nil
        }
    }

    /// Check if Screen Recording permission is available.
    func hasScreenRecordingPermission() async -> Bool {
        do {
            _ = try await fetchShareableContent(excludeDesktop: true, onScreenOnly: true)
            return true
        } catch {
            logCaptureFailure("hasScreenRecordingPermission", error: error)
            return false
        }
    }
}

// MARK: - Stream Delegate

/// Receives SCStream output frames and forwards the latest via callback.
/// Uses buffer dropping: only the newest frame matters for <200ms latency.
private final class ScreenStreamDelegate: NSObject, SCStreamOutput, @unchecked Sendable {
    private let onFrame: @Sendable (CGImage) -> Void

    /// Reuse a single CIContext across all frames. CIContext creation is expensive
    /// (~2ms) and was being allocated per-frame, adding unnecessary latency.
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    init(onFrame: @escaping @Sendable (CGImage) -> Void) {
        self.onFrame = onFrame
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let rect = CGRect(
            x: 0, y: 0,
            width: CVPixelBufferGetWidth(imageBuffer),
            height: CVPixelBufferGetHeight(imageBuffer)
        )
        guard let cgImage = ciContext.createCGImage(ciImage, from: rect) else { return }

        onFrame(cgImage)
    }
}

// MARK: - Errors

enum ScreenCaptureError: Error, LocalizedError {
    case noDisplay
    case noWindow
    case captureFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display available for capture"
        case .noWindow: return "No matching window found"
        case .captureFailed: return "Screen capture failed"
        case .timeout: return "Screen capture timed out (replayd may be unresponsive)"
        }
    }
}
