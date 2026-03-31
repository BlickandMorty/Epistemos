import AppKit
import CoreImage
import Foundation
import ScreenCaptureKit

// MARK: - Agent Desktop Capture (VLM Desktop PiP Feed)

/// Captures the agent's desktop windows via ScreenCaptureKit.
///
/// Uses window-level filtering (not display-level) so capture works
/// regardless of which Space is active. The user can stay on their own
/// Space while the agent's screen is continuously captured for VLM perception.
///
/// Frame rate is kept low (2-5 FPS) since this feeds VLM perception,
/// not video streaming. Resolution is downscaled for efficiency.
@Observable
final class AgentDesktopCapture: NSObject, SCStreamOutput, @unchecked Sendable {

    // MARK: - Configuration

    /// Frame rate for VLM perception (not video streaming).
    let framesPerSecond: Int = 3

    /// Capture resolution (downscaled for VLM input efficiency).
    let captureWidth: Int = 1280
    let captureHeight: Int = 720

    // MARK: - State

    private(set) var isCapturing: Bool = false
    private(set) var latestFrame: CGImage?
    private(set) var frameCount: UInt64 = 0

    private var stream: SCStream?
    private let captureQueue = DispatchQueue(
        label: "com.epistemos.agent.desktop.capture",
        qos: .userInitiated
    )

    // MARK: - Capture Lifecycle

    /// Start capturing a specific window (the agent's primary window).
    func startCapture(window: SCWindow) async throws {
        guard !isCapturing else { return }

        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()
        config.width = captureWidth
        config.height = captureHeight
        config.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(framesPerSecond)
        )
        config.showsCursor = true       // Agent needs to see cursor position
        config.capturesAudio = false    // No audio needed for VLM
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 3          // Small buffer, we want latest frame

        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
        try await stream?.startCapture()
        isCapturing = true
    }

    /// Start capturing all windows of a specific app.
    func startCapture(forApp app: SCRunningApplication, excluding: [SCWindow] = []) async throws {
        guard !isCapturing else { return }

        let content = try await SCShareableContent.current
        let appWindows = content.windows.filter { win in
            win.owningApplication?.processID == app.processID
                && win.isOnScreen
                && !excluding.contains(where: { ex in ex.windowID == win.windowID })
        }

        guard let primaryWindow = appWindows.first else {
            throw AgentDesktopError.noWindowsFound
        }

        try await startCapture(window: primaryWindow)
    }

    /// Stop capturing.
    func stopCapture() async {
        guard isCapturing else { return }
        try? await stream?.stopCapture()
        stream = nil
        isCapturing = false
    }

    // MARK: - SCStreamOutput

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen,
              let imageBuffer = sampleBuffer.imageBuffer else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            DispatchQueue.main.async { [weak self] in
                self?.latestFrame = cgImage
                self?.frameCount += 1
            }
        }
    }

    // MARK: - Snapshot

    /// Get the current frame as JPEG Data for VLM input.
    func captureSnapshot() -> Data? {
        guard let cgImage = latestFrame else { return nil }
        let nsImage = NSImage(
            cgImage: cgImage,
            size: NSSize(width: captureWidth, height: captureHeight)
        )
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.80]
        )
    }

    /// Get the current frame as a CGImage (for Metal PiP rendering).
    func currentFrame() -> CGImage? {
        latestFrame
    }
}

// MARK: - Errors

enum AgentDesktopError: Error, LocalizedError {
    case noWindowsFound
    case captureUnavailable
    case spaceCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noWindowsFound:
            return "No visible windows found for the target app"
        case .captureUnavailable:
            return "Screen capture is not available (check permissions)"
        case .spaceCreationFailed(let detail):
            return "Failed to create agent Space: \(detail)"
        }
    }
}
