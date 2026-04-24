#if !EPISTEMOS_APP_STORE
import Foundation
import CoreGraphics
import os
import Vision

// MARK: - Visual Verify Loop

/// Captures before/after screen state around UI actions to verify success.
/// Uses DeviceAgentService (Brain 2) for fast comparison when available,
/// falls back to pixel-level diff when LLM verification is unavailable.
///
/// Target: lower-latency verification on a dedicated Brain 2 backend.
/// Current: the live runtime uses either Apple on-device language models or the
/// shared GPU path, depending on availability.
@MainActor @Observable
final class VisualVerifyLoop {
    typealias AXStateProvider = @MainActor @Sendable (_ appBundleID: String?) async -> String
    typealias ScreenshotFingerprintProvider = @MainActor @Sendable (_ appBundleID: String?) async -> UInt64?
    /// Produces an ANE-accelerated Vision feature print for the target window,
    /// serialized as the raw float vector `Data`. Returns nil when Vision is
    /// unavailable or the screenshot capture fails.
    typealias SemanticScreenshotProvider = @MainActor @Sendable (_ appBundleID: String?) async -> Data?
    typealias SemanticVerificationHandler = @MainActor @Sendable (
        _ beforeState: String,
        _ afterState: String,
        _ expectedOutcome: String
    ) async throws -> SemanticVerification

    struct SemanticVerification: Sendable {
        let confidence: Double
        let method: String
    }

    private let log = Logger(subsystem: "com.epistemos.omega", category: "VisualVerify")

    private let screenCapture: ScreenCaptureService
    private let deviceAgent: DeviceAgentService?
    private let axStateProvider: AXStateProvider
    private let screenshotFingerprintProvider: ScreenshotFingerprintProvider
    private let semanticScreenshotProvider: SemanticScreenshotProvider?
    private let semanticVerifier: SemanticVerificationHandler?

    /// Last verification result.
    private(set) var lastResult: VerifyResult?

    /// Rolling success rate (last 20 verifications).
    private var recentResults: [Bool] = []
    var successRate: Double {
        guard !recentResults.isEmpty else { return 1.0 }
        return Double(recentResults.filter { $0 }.count) / Double(recentResults.count)
    }

    init(screenCapture: ScreenCaptureService, deviceAgent: DeviceAgentService? = nil) {
        self.screenCapture = screenCapture
        self.deviceAgent = deviceAgent
        self.axStateProvider = { appBundleID in
            Self.captureAXState(appBundleID: appBundleID)
        }
        self.screenshotFingerprintProvider = { appBundleID in
            let image: CGImage?
            if let appBundleID {
                image = await screenCapture.captureApp(bundleID: appBundleID)
            } else {
                image = await screenCapture.captureFrontmostWindow()
            }
            guard let image else { return nil }
            return Self.screenshotFingerprint(for: image)
        }
        self.semanticScreenshotProvider = { appBundleID in
            let image: CGImage?
            if let appBundleID {
                image = await screenCapture.captureApp(bundleID: appBundleID)
            } else {
                image = await screenCapture.captureFrontmostWindow()
            }
            guard let image else { return nil }
            return Self.semanticFeaturePrint(for: image)
        }
        if let deviceAgent {
            self.semanticVerifier = { beforeState, afterState, expectedOutcome in
                let confidence = try await deviceAgent.verifyAction(
                    beforeState: beforeState,
                    afterState: afterState,
                    expectedOutcome: expectedOutcome
                )
                return SemanticVerification(
                    confidence: confidence,
                    method: deviceAgent.verificationMethodName
                )
            }
        } else {
            self.semanticVerifier = nil
        }
    }

    init(
        screenCapture: ScreenCaptureService,
        deviceAgent: DeviceAgentService? = nil,
        axStateProvider: @escaping AXStateProvider,
        screenshotFingerprintProvider: @escaping ScreenshotFingerprintProvider,
        semanticScreenshotProvider: SemanticScreenshotProvider? = nil,
        semanticVerifier: SemanticVerificationHandler?
    ) {
        self.screenCapture = screenCapture
        self.deviceAgent = deviceAgent
        self.axStateProvider = axStateProvider
        self.screenshotFingerprintProvider = screenshotFingerprintProvider
        self.semanticScreenshotProvider = semanticScreenshotProvider
        self.semanticVerifier = semanticVerifier
    }

    /// Capture the "before" state for a pending action.
    /// Returns an opaque token used to verify after the action executes.
    func captureBeforeState(appBundleID: String? = nil) async -> VerifyToken? {
        let start = ContinuousClock.now

        let axState = await axStateProvider(appBundleID)
        let screenshotFingerprintBefore = await screenshotFingerprintProvider(appBundleID)
        let semanticFingerprintBefore = await semanticScreenshotProvider?(appBundleID)

        let elapsed = start.duration(to: ContinuousClock.now)
        log.debug("Before state captured in \(elapsed.omegaMilliseconds)ms")

        return VerifyToken(
            axStateBefore: axState,
            screenshotFingerprintBefore: screenshotFingerprintBefore,
            semanticFingerprintBefore: semanticFingerprintBefore,
            capturedAt: Date()
        )
    }

    /// Verify that an action succeeded by comparing before/after state.
    /// Returns confidence score (0.0-1.0).
    func verify(
        token: VerifyToken,
        expectedOutcome: String,
        appBundleID: String? = nil
    ) async -> VerifyResult {
        let start = ContinuousClock.now

        let axStateAfter = await axStateProvider(appBundleID)

        var confidence: Double
        var method: String

        // Try LLM-based verification via Brain 2 (fast, semantic)
        if let semanticVerifier {
            do {
                let semanticResult = try await semanticVerifier(
                    token.axStateBefore,
                    axStateAfter,
                    expectedOutcome
                )
                confidence = semanticResult.confidence
                method = semanticResult.method
            } catch {
                log.warning("LLM verify failed, falling back to diff: \(error.localizedDescription)")
                confidence = diffBasedVerification(
                    before: token.axStateBefore,
                    after: axStateAfter
                )
                method = "AX-diff"
            }
        } else {
            // Fallback: structural diff of AX trees
            confidence = diffBasedVerification(
                before: token.axStateBefore,
                after: axStateAfter
            )
            method = "AX-diff"
        }

        if confidence < 0.8,
           let beforeFingerprint = token.screenshotFingerprintBefore,
           let afterFingerprint = await screenshotFingerprintProvider(appBundleID),
           beforeFingerprint != afterFingerprint {
            confidence = max(confidence, 0.6)
            method = method == "AX-diff" ? "AX+screenshot-diff" : "\(method)+screenshot-diff"
        }

        // Vision feature-print distance runs on ANE on Apple Silicon. A large
        // semantic distance between before/after confirms a meaningful UI
        // change even when AX diff is inconclusive; a near-zero distance
        // downgrades confidence when hashes differ only due to cursor blinks
        // or animation frames.
        if confidence < 0.85,
           let beforeSemantic = token.semanticFingerprintBefore,
           let provider = semanticScreenshotProvider,
           let afterSemantic = await provider(appBundleID),
           let distance = Self.semanticDistance(beforeSemantic, afterSemantic) {
            if distance >= 0.15 {
                confidence = max(confidence, 0.75)
                method = method.contains("semantic") ? method : "\(method)+semantic"
            } else if distance < 0.02, confidence > 0.4 {
                confidence = min(confidence, 0.4)
                method = "\(method)+semantic-noop"
            }
        }

        let elapsed = start.duration(to: ContinuousClock.now)

        let result = VerifyResult(
            confidence: confidence,
            method: method,
            latencyMs: elapsed.omegaMilliseconds,
            stateChanged: confidence > 0.3
        )

        lastResult = result
        recentResults.append(confidence >= 0.8)
        if recentResults.count > 20 { recentResults.removeFirst() }

        log.info("Verify: \(confidence, privacy: .public) via \(method, privacy: .public) in \(elapsed.omegaMilliseconds)ms")

        return result
    }

    // MARK: - Diff-Based Verification

    /// Simple structural comparison: count elements that changed between before/after.
    /// High change rate + expected outcome keywords → high confidence.
    private func diffBasedVerification(before: String, after: String) -> Double {
        // If both are empty/invalid, can't determine
        guard before != after else { return 0.1 }

        let beforeElements = countElements(before)
        let afterElements = countElements(after)

        // State changed → something happened
        if beforeElements != afterElements {
            return 0.7
        }

        // Content changed (different JSON)
        if before.count != after.count {
            return 0.5
        }

        // Identical → action may have failed
        return 0.2
    }

    private func countElements(_ json: String) -> Int {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = obj["elements"] as? [Any] else {
            return 0
        }
        return elements.count
    }

    private static func captureAXState(appBundleID: String?) -> String {
        if let appBundleID, let pid = pidForBundleID(appBundleID) {
            // AXorcist-powered tree walk (replaces omega-ax walkAxTreeJson)
            return AXorcistBridge.shared.walkTree(pid: pid)
        }
        return "{}"
    }

    private static func pidForBundleID(_ bundleID: String) -> Int32? {
        let apps = NSWorkspace.shared.runningApplications
        return apps.first { $0.bundleIdentifier == bundleID }?.processIdentifier
    }

    /// Compute an ANE-accelerated Vision feature print for the given image.
    /// Returns the raw float vector serialized as `Data`, or nil when Vision
    /// cannot produce a feature print (unsupported format, empty image, etc).
    static func semanticFeaturePrint(for image: CGImage) -> Data? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first else { return nil }
        return observation.data
    }

    /// Normalized L2 distance between two feature-print float vectors.
    /// Returns nil when the buffers are incompatible.
    static func semanticDistance(_ lhs: Data, _ rhs: Data) -> Float? {
        guard !lhs.isEmpty, lhs.count == rhs.count, lhs.count % MemoryLayout<Float>.size == 0 else {
            return nil
        }
        let count = lhs.count / MemoryLayout<Float>.size
        guard count > 0 else { return nil }
        var sumSq: Float = 0
        lhs.withUnsafeBytes { (lptr: UnsafeRawBufferPointer) in
            rhs.withUnsafeBytes { (rptr: UnsafeRawBufferPointer) in
                guard let lbase = lptr.baseAddress?.assumingMemoryBound(to: Float.self),
                      let rbase = rptr.baseAddress?.assumingMemoryBound(to: Float.self) else {
                    return
                }
                for i in 0..<count {
                    let d = lbase[i] - rbase[i]
                    sumSq += d * d
                }
            }
        }
        return (sumSq / Float(count)).squareRoot()
    }

    private static func screenshotFingerprint(for image: CGImage) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        hash ^= UInt64(image.width)
        hash &*= 1_099_511_628_211
        hash ^= UInt64(image.height)
        hash &*= 1_099_511_628_211

        guard let data = image.dataProvider?.data else {
            return hash
        }

        let length = CFDataGetLength(data)
        guard length > 0,
              let bytes = CFDataGetBytePtr(data) else {
            return hash
        }

        let step = max(1, length / 1024)
        var index = 0
        while index < length {
            hash ^= UInt64(bytes[index])
            hash &*= 1_099_511_628_211
            index += step
        }
        return hash
    }
}

// MARK: - Types

/// Opaque token capturing pre-action state.
struct VerifyToken: Sendable {
    let axStateBefore: String
    let screenshotFingerprintBefore: UInt64?
    let semanticFingerprintBefore: Data?
    let capturedAt: Date

    init(
        axStateBefore: String,
        screenshotFingerprintBefore: UInt64?,
        semanticFingerprintBefore: Data? = nil,
        capturedAt: Date
    ) {
        self.axStateBefore = axStateBefore
        self.screenshotFingerprintBefore = screenshotFingerprintBefore
        self.semanticFingerprintBefore = semanticFingerprintBefore
        self.capturedAt = capturedAt
    }
}

/// Result of a visual verification.
struct VerifyResult: Sendable {
    let confidence: Double
    let method: String
    let latencyMs: Double
    let stateChanged: Bool

    var passed: Bool { confidence >= 0.8 }
}
#endif
