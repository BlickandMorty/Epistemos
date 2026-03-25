import Foundation
import os

// MARK: - Device Agent Service (Brain 2)

/// Brain 2: Fast device action model for UI interaction, AX tree parsing,
/// screenshot verification, and keyboard injection.
///
/// Current: Routes through the shared Qwen model on Metal GPU (single-brain fallback).
/// Future (Ω15+): Epistemos-Nano 1B on ANE via CoreML for <100ms visual verify.
///
/// Design: Abstracts the inference backend so switching from shared-GPU to dedicated-ANE
/// requires only swapping the `DeviceInferenceBackend` implementation.
@MainActor @Observable
final class DeviceAgentService {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "DeviceAgent")

    /// The active inference backend.
    private var backend: (any DeviceInferenceBackend)?

    /// Hardware tier for capability checks.
    private let hardwareTier: HardwareTierManager

    /// Whether Brain 2 is ready for inference.
    var isReady: Bool { backend != nil }

    /// Whether Brain 2 is running on dedicated ANE (vs shared GPU).
    var isANEDedicated: Bool { backend?.usesANE ?? false }

    /// Last inference latency in milliseconds.
    private(set) var lastLatencyMs: Double = 0

    init(hardwareTier: HardwareTierManager) {
        self.hardwareTier = hardwareTier
    }

    /// Set the inference backend (called during setup or when switching brains).
    func setBackend(_ backend: any DeviceInferenceBackend) {
        self.backend = backend
        log.info("Device agent backend set: \(backend.name, privacy: .public), ANE: \(backend.usesANE)")
    }

    /// Parse an AX tree and identify the target element for an action.
    /// Returns structured JSON: {"selector": "...", "confidence": 0.95, "action": "click"}
    func resolveUIAction(
        axTreeJson: String,
        userIntent: String
    ) async throws -> DeviceActionResult {
        guard let backend else {
            throw DeviceAgentError.backendNotReady
        }

        let prompt = Self.buildResolvePrompt(axTree: axTreeJson, intent: userIntent)
        let system = "You are a precise UI action resolver. Output ONLY valid JSON. No explanation."

        let start = ContinuousClock.now
        let raw = try await backend.generate(
            prompt: prompt,
            systemPrompt: system,
            maxTokens: 256
        )
        let elapsed = start.duration(to: ContinuousClock.now)
        lastLatencyMs = elapsed.omegaMilliseconds

        log.debug("UI resolve: \(elapsed.omegaMilliseconds, privacy: .public)ms")

        return parseActionResult(raw)
    }

    /// Verify a UI action succeeded by comparing before/after screen state.
    /// Returns confidence score (0.0-1.0) that the action completed correctly.
    func verifyAction(
        beforeState: String,
        afterState: String,
        expectedOutcome: String
    ) async throws -> Double {
        guard let backend else {
            throw DeviceAgentError.backendNotReady
        }

        let prompt = Self.buildVerifyPrompt(
            before: beforeState,
            after: afterState,
            expected: expectedOutcome
        )
        let system = "Output ONLY a JSON object: {\"success\": true/false, \"confidence\": 0.0-1.0, \"reason\": \"...\"}."

        let raw = try await backend.generate(
            prompt: prompt,
            systemPrompt: system,
            maxTokens: 128
        )

        // Parse confidence from response
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let confidence = json["confidence"] as? Double,
              confidence.isFinite else {
            return 0.5 // Uncertain fallback
        }
        return min(1.0, max(0.0, confidence))
    }

    // MARK: - Prompt Construction

    private static func buildResolvePrompt(axTree: String, intent: String) -> String {
        """
        AX Tree (JSON):
        \(axTree.prefix(4000))

        User intent: \(intent)

        Identify the UI element to interact with. Respond with ONLY:
        {"selector": "//AXApplication[@AXTitle='AppName']//AXButton[@AXTitle='Name']", "action": "AXPress|CGClick|KeyInject", "confidence": 0.0-1.0}

        Rules:
        - Use CSS-style AX selectors, NEVER numeric indices.
        - Prefer AXPress for buttons, CGClick for non-standard elements.
        - KeyInject for text input fields.
        - If multiple matches, pick the most specific selector.
        - If unsure, set confidence < 0.8.
        """
    }

    private static func buildVerifyPrompt(before: String, after: String, expected: String) -> String {
        """
        Before state:
        \(before.prefix(2000))

        After state:
        \(after.prefix(2000))

        Expected outcome: \(expected)

        Did the action succeed? Respond with ONLY:
        {"success": true/false, "confidence": 0.0-1.0, "reason": "brief explanation"}
        """
    }

    // MARK: - Result Parsing

    private func parseActionResult(_ raw: String) -> DeviceActionResult {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return DeviceActionResult(
                selector: "",
                action: .axPress,
                confidence: 0.0,
                rawOutput: raw
            )
        }

        let selector = json["selector"] as? String ?? ""
        let actionStr = json["action"] as? String ?? "AXPress"
        let confidence = (json["confidence"] as? Double) ?? 0.5

        let action: DeviceActionType
        switch actionStr {
        case "CGClick": action = .cgClick
        case "KeyInject": action = .keyInject
        default: action = .axPress
        }

        return DeviceActionResult(
            selector: selector,
            action: action,
            confidence: confidence.isFinite ? min(1.0, max(0.0, confidence)) : 0.0,
            rawOutput: raw
        )
    }
}

// MARK: - Device Inference Backend Protocol

/// Abstraction over the inference backend for Brain 2.
/// Current: SharedGPUBackend (uses existing TriageService).
/// Future: ANEBackend (CoreML .mlpackage on Neural Engine).
protocol DeviceInferenceBackend: Sendable {
    var name: String { get }
    var usesANE: Bool { get }
    func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String
}

/// Backend that shares the GPU model (Brain 1) for device actions.
/// Used when hardware doesn't support dual-model or dedicated ANE model isn't available.
@MainActor
final class SharedGPUBackend: DeviceInferenceBackend {
    nonisolated let name = "SharedGPU"
    nonisolated let usesANE = false
    private let triageService: TriageService

    init(triageService: TriageService) {
        self.triageService = triageService
    }

    nonisolated func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor [triageService] in
                do {
                    let result = try await triageService.generateRawLocal(
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Types

struct DeviceActionResult: Sendable {
    let selector: String
    let action: DeviceActionType
    let confidence: Double
    let rawOutput: String
}

enum DeviceActionType: String, Sendable {
    case axPress = "AXPress"
    case cgClick = "CGClick"
    case keyInject = "KeyInject"
}

enum DeviceAgentError: Error, LocalizedError {
    case backendNotReady
    case lowConfidence(Double)
    case selectorNotFound(String)

    var errorDescription: String? {
        switch self {
        case .backendNotReady: "Device agent backend not initialized"
        case .lowConfidence(let c): "Low confidence (\(String(format: "%.2f", c))) — requires user verification"
        case .selectorNotFound(let s): "UI element not found: \(s)"
        }
    }
}

