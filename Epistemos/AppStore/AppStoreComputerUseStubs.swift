#if EPISTEMOS_APP_STORE
import CoreGraphics
import Foundation

private let appStoreAutomationDenied = """
{"success":false,"error":"Native computer-use automation is unavailable in the App Store build."}
"""

nonisolated enum PermissionState: Sendable, Equatable, Hashable {
    case granted
    case denied
    case unknown
}

nonisolated struct PermissionStatus: Sendable, Equatable, Hashable {
    var accessibility: PermissionState
    var screenRecording: PermissionState
    var automation: PermissionState
}

nonisolated func checkPermissions() -> PermissionStatus {
    PermissionStatus(accessibility: .denied, screenRecording: .unknown, automation: .denied)
}

nonisolated func walkAxTreeJson(pid: Int64) -> String {
    #"{"pid":\#(pid),"is_sparse":true,"elements":[],"error":"Native computer-use automation is unavailable in the App Store build."}"#
}

@MainActor
final class ScreenCaptureService {
    private(set) var latestFrame: CGImage?
    private(set) var latestFrameTimestamp: ContinuousClock.Instant?
    var isStreaming: Bool { false }

    func startStream(bundleID: String? = nil, targetFPS: Int = 10, scale: Int = 1) async throws {}
    func stopStream() async {}
    func recoverStream(bundleID: String? = nil, targetFPS: Int = 10, scale: Int = 1) async {}
    func awaitFrame(maxWaitMs: Int = 200) async -> CGImage? { nil }
    func captureFrontmostWindow() async -> CGImage? { nil }
    func captureDisplay(_ display: Any? = nil) async -> CGImage? { nil }
    func captureApp(bundleID: String) async -> CGImage? { nil }
    func hasScreenRecordingPermission() async -> Bool { false }
}

@MainActor @Observable
final class Screen2AXFusion {
    private(set) var lastPerception: PerceptionResult?
    var visionOCREnrichmentEnabled: Bool { false }

    init(screenCapture: ScreenCaptureService) {}

    func perceive(appName: String) async -> PerceptionResult {
        let result = PerceptionResult(
            axTreeJson: "{}",
            interactiveCount: 0,
            method: .failed,
            latencyMs: 0,
            ocrTexts: []
        )
        lastPerception = result
        return result
    }

    func perceiveQuick(pid: Int32) -> PerceptionResult {
        PerceptionResult(
            axTreeJson: "{}",
            interactiveCount: 0,
            method: .failed,
            latencyMs: 0,
            ocrTexts: []
        )
    }

    static func filterToInteractive(_ json: String) -> String { json }
}

struct PerceptionResult: Sendable {
    let axTreeJson: String
    let interactiveCount: Int
    let method: PerceptionMethod
    let latencyMs: Double
    let ocrTexts: [OCRTextRegion]
}

enum PerceptionMethod: String, Sendable {
    case nativeAX = "NativeAX"
    case axPlusVisionOCR = "AX+VisionOCR"
    case screen2AXVLM = "Screen2AX-VLM"
    case failed = "Failed"
}

struct OCRTextRegion: Sendable {
    let text: String
    let confidence: Double
    let normalizedBounds: NormalizedRect
}

struct NormalizedRect: Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

@MainActor @Observable
final class VisualVerifyLoop {
    private(set) var lastResult: VerifyResult?
    var successRate: Double { 1.0 }

    init(screenCapture: ScreenCaptureService, deviceAgent: DeviceAgentService? = nil) {}

    func captureBeforeState(appBundleID: String? = nil) async -> VerifyToken? {
        nil
    }

    func verify(token: VerifyToken, expectedOutcome: String, appBundleID: String? = nil) async -> VerifyResult {
        let result = VerifyResult(
            confidence: 0,
            method: "AppStoreProfileDenied",
            latencyMs: 0,
            stateChanged: false
        )
        lastResult = result
        return result
    }

    static func semanticFeaturePrint(for image: CGImage) -> Data? { nil }
    static func semanticDistance(_ lhs: Data, _ rhs: Data) -> Float? { nil }
}

struct VerifyToken: Sendable {
    let axStateBefore: String
    let screenshotFingerprintBefore: UInt64?
    let semanticFingerprintBefore: Data?
    let capturedAt: Date
}

struct VerifyResult: Sendable {
    let confidence: Double
    let method: String
    let latencyMs: Double
    let stateChanged: Bool
    var passed: Bool { confidence >= 0.8 }
}

@MainActor
enum AXMutationDetector {
    struct Snapshot: Sendable {
        let interactiveCount: Int
        let topElementHash: UInt64
        let windowCount: Int
        let capturedAt: ContinuousClock.Instant
    }

    struct MutationResult: Sendable {
        let mutated: Bool
        let elementCountDelta: Int
        let newWindowDetected: Bool
        let latencyMs: Double
    }

    static func captureSnapshot(pid: Int32, using perception: Screen2AXFusion) -> Snapshot {
        Snapshot(interactiveCount: 0, topElementHash: 0, windowCount: 0, capturedAt: .now)
    }

    static func compare(before: Snapshot, after: Snapshot) -> MutationResult {
        MutationResult(mutated: false, elementCountDelta: 0, newWindowDetected: false, latencyMs: 0)
    }
}

@MainActor
final class ComputerUseBridge {
    static let shared = ComputerUseBridge()
    func execute(actionJSON: String) async -> String { appStoreAutomationDenied }
}

@MainActor
final class Phase4Bridge {
    static let shared = Phase4Bridge()
    func perceive(appName: String, depth: String) async -> String { appStoreAutomationDenied }
    func interact(actionJson: String) async -> String { appStoreAutomationDenied }
    func startScreenWatch(watchJson: String) async -> String { appStoreAutomationDenied }
}
#endif
