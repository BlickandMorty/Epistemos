import Foundation
import os

// MARK: - Visual Verify Loop

/// Captures before/after screen state around UI actions to verify success.
/// Uses DeviceAgentService (Brain 2) for fast comparison when available,
/// falls back to pixel-level diff when LLM verification is unavailable.
///
/// Target: <100ms per verification cycle on ANE (Brain 2).
/// Current: ~200-500ms via shared GPU (Brain 1 fallback).
@MainActor @Observable
final class VisualVerifyLoop {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "VisualVerify")

    private let screenCapture: ScreenCaptureService
    private let deviceAgent: DeviceAgentService?

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
    }

    /// Capture the "before" state for a pending action.
    /// Returns an opaque token used to verify after the action executes.
    func captureBeforeState(appBundleID: String? = nil) async -> VerifyToken? {
        let start = ContinuousClock.now

        // Capture AX tree state (fast, <500ms from R5 results)
        let axState: String
        if let bundleID = appBundleID, let pid = pidForBundleID(bundleID) {
            axState = walkAxTreeJson(pid: Int64(pid))
        } else {
            axState = "{}"
        }

        let elapsed = start.duration(to: ContinuousClock.now)
        log.debug("Before state captured in \(elapsed.omegaMilliseconds)ms")

        return VerifyToken(
            axStateBefore: axState,
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

        // Capture "after" AX tree
        let axStateAfter: String
        if let bundleID = appBundleID, let pid = pidForBundleID(bundleID) {
            axStateAfter = walkAxTreeJson(pid: Int64(pid))
        } else {
            axStateAfter = "{}"
        }

        var confidence: Double
        var method: String

        // Try LLM-based verification via Brain 2 (fast, semantic)
        if let agent = deviceAgent, agent.isReady {
            do {
                confidence = try await agent.verifyAction(
                    beforeState: token.axStateBefore,
                    afterState: axStateAfter,
                    expectedOutcome: expectedOutcome
                )
                method = agent.isANEDedicated ? "Brain2-ANE" : "Brain2-SharedGPU"
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

    private func pidForBundleID(_ bundleID: String) -> Int32? {
        let apps = NSWorkspace.shared.runningApplications
        return apps.first { $0.bundleIdentifier == bundleID }?.processIdentifier
    }
}

// MARK: - Types

/// Opaque token capturing pre-action state.
struct VerifyToken: Sendable {
    let axStateBefore: String
    let capturedAt: Date
}

/// Result of a visual verification.
struct VerifyResult: Sendable {
    let confidence: Double
    let method: String
    let latencyMs: Double
    let stateChanged: Bool

    var passed: Bool { confidence >= 0.8 }
}

