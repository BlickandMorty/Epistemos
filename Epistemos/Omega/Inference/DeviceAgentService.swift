import Accelerate
import CoreML
import Foundation
import NaturalLanguage
import os

// MARK: - Device Agent Service (Brain 2)

/// Brain 2: Fast device action model for UI interaction, AX tree parsing,
/// screenshot verification, and keyboard injection.
///
/// Current: Routes through either the Apple on-device language model or the
/// shared Qwen model on Metal GPU, depending on runtime availability.
/// Future (Ω15+): dedicated Brain 2 CoreML model on ANE for lower-latency visual verify.
///
/// Design: Abstracts the inference backend so switching from the live backends
/// to a future dedicated-ANE model requires only swapping the
/// `DeviceInferenceBackend` implementation.
@MainActor @Observable
final class DeviceAgentService {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "DeviceAgent")
    private let minimumResolutionConfidence = 0.8

    /// The active inference backend.
    private var backend: (any DeviceInferenceBackend)?

    /// Optional ANE-backed fast resolver. When available, intercepts
    /// `resolveUIAction` before the LLM backend and short-circuits with an
    /// embedding-similarity match when confidence is high enough. Runs on the
    /// Apple Neural Engine via NLContextualEmbedding / Core ML.
    private var contextualResolver: AppleContextualActionResolver?
    private var contextualResolverAttempted = false

    /// Hardware tier for capability checks.
    private let hardwareTier: HardwareTierManager

    /// Whether Brain 2 is ready for inference.
    var isReady: Bool { backend != nil || contextualResolver?.isReady == true }

    /// Whether Brain 2 is running on the Apple Neural Engine (either via a
    /// dedicated Core ML backend or via the Apple contextual resolver, both of
    /// which execute on ANE on Apple Silicon when assets are available).
    var isANEDedicated: Bool {
        if contextualResolver?.isReady == true { return true }
        return backend?.usesANE ?? false
    }

    /// Human-readable label for logs and verification traces.
    var verificationMethodName: String {
        if contextualResolver?.isReady == true {
            return "Brain2-ANE-Contextual"
        }
        guard let backend else { return "Brain2-Unavailable" }
        return "Brain2-\(backend.name)"
    }

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
        // ANE fast path: try the contextual resolver first. When it returns a
        // high-confidence match, we skip the LLM backend entirely — the
        // embedding similarity is deterministic and runs in single-digit ms
        // on the Neural Engine versus ~500ms for an LLM turn.
        if let resolver = contextualResolverIfAvailable(),
           let fastResult = resolver.resolve(axTreeJson: axTreeJson, intent: userIntent),
           fastResult.confidence >= minimumResolutionConfidence {
            lastLatencyMs = fastResult.latencyMs
            log.debug("UI resolve (ANE contextual): \(fastResult.latencyMs, privacy: .public)ms conf=\(fastResult.confidence, privacy: .public)")
            return fastResult
        }

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

        let result = parseActionResult(raw, backendName: backend.name)
        guard !result.selector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeviceAgentError.selectorNotFound("Model did not return a selector")
        }
        guard result.confidence >= minimumResolutionConfidence else {
            throw DeviceAgentError.lowConfidence(result.confidence)
        }
        return result
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

    /// Lazily enable the Apple Neural Engine contextual resolver. Constructing
    /// `NLContextualEmbedding` can load Apple language assets, so passive app
    /// launch leaves it cold. The first real device-action resolution may pay
    /// that setup cost; if assets are unavailable we remember that and fall
    /// through to the LLM backend for the session.
    private func contextualResolverIfAvailable() -> AppleContextualActionResolver? {
        if let contextualResolver {
            return contextualResolver.isReady ? contextualResolver : nil
        }
        guard !contextualResolverAttempted else { return nil }
        contextualResolverAttempted = true

        let resolver = AppleContextualActionResolver()
        guard resolver.isReady else {
            log.info("Contextual ANE resolver unavailable; using device-action backend")
            return nil
        }
        contextualResolver = resolver
        log.info("Contextual ANE resolver installed lazily")
        return resolver
    }

    // MARK: - Prompt Construction

    private static func buildResolvePrompt(axTree: String, intent: String) -> String {
        // Filter to interactive-only elements to prevent context blowout.
        // A raw AX tree from Safari can be 15,000+ lines; filtered is ~200.
        let filtered = Screen2AXFusion.filterToInteractive(axTree)
        return """
        AX Tree (interactive elements only):
        \(filtered.prefix(8000))

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

    private func parseActionResult(_ raw: String, backendName: String) -> DeviceActionResult {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return DeviceActionResult(
                selector: "",
                action: .axPress,
                confidence: 0.0,
                rawOutput: raw,
                backendName: backendName
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
            rawOutput: raw,
            backendName: backendName
        )
    }
}

// MARK: - Device Inference Backend Protocol

/// Abstraction over the inference backend for Brain 2.
/// Current: AppleOnDeviceBackend (FoundationModels) or SharedGPUBackend.
/// Future: dedicated ANE backend (CoreML .mlpackage on Neural Engine).
protocol DeviceInferenceBackend: Sendable {
    var name: String { get }
    var usesANE: Bool { get }
    func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String
}

/// Backend that uses Apple's on-device Foundation Models path when available.
/// This is a real separate runtime from the shared GPU Qwen path, but it is not
/// the same thing as a dedicated app-owned ANE/CoreML model.
@MainActor
final class AppleOnDeviceBackend: DeviceInferenceBackend {
    nonisolated let name = "AppleOnDevice"
    nonisolated let usesANE = false

    nonisolated func generate(prompt: String, systemPrompt: String, maxTokens _: Int) async throws -> String {
        try await withTimedMainActorBridge {
            try await AppleIntelligenceService.shared.generate(
                prompt: prompt,
                systemPrompt: systemPrompt
            )
        }
    }
}

/// Keeps passive launch local-first while preserving Apple Intelligence as a
/// request-time fallback. FoundationModels availability is intentionally not
/// queried while AppBootstrap is choosing the backend.
@MainActor
final class SharedGPUAppleFallbackBackend: DeviceInferenceBackend {
    nonisolated let name = "SharedGPU+AppleFallback"
    nonisolated let usesANE = false

    private let sharedGPUBackend: SharedGPUBackend

    init(sharedGPUBackend: SharedGPUBackend) {
        self.sharedGPUBackend = sharedGPUBackend
    }

    nonisolated func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String {
        do {
            return try await sharedGPUBackend.generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        } catch {
            let sharedError = error
            do {
                return try await withTimedMainActorBridge {
                    try await AppleIntelligenceService.shared.generate(
                        prompt: prompt,
                        systemPrompt: systemPrompt
                    )
                }
            } catch {
                throw sharedError
            }
        }
    }
}

/// Backend that shares the GPU model (Brain 1) for device actions.
/// Used when hardware doesn't support dual-model or dedicated ANE model isn't available.
@MainActor
final class SharedGPUBackend: DeviceInferenceBackend {
    nonisolated let name = "SharedGPU"
    nonisolated let usesANE = false
    private let triageService: TriageService
    private let localModelClient: (any LocalConfigurableLLMClient)?
    private let constrainedDecoding: ConstrainedDecodingService?
    private let activeModelID: @MainActor @Sendable () -> String?

    init(
        triageService: TriageService,
        localModelClient: (any LocalConfigurableLLMClient)? = nil,
        constrainedDecoding: ConstrainedDecodingService? = nil,
        activeModelID: @escaping @MainActor @Sendable () -> String? = { nil }
    ) {
        self.triageService = triageService
        self.localModelClient = localModelClient
        self.constrainedDecoding = constrainedDecoding
        self.activeModelID = activeModelID
    }

    nonisolated func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String {
        try await withTimedMainActorBridge { [weak self] in
            guard let self else {
                throw DeviceAgentError.backendNotReady
            }

            return try await self.generateOnMainActor(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        }
    }

    private func generateOnMainActor(
        prompt: String,
        systemPrompt: String,
        maxTokens: Int
    ) async throws -> String {
        if let agentLoop = makeLocalAgentLoopIfAvailable(maxTokens: maxTokens) {
            return try await agentLoop.run(
                objective: prompt,
                tools: [],
                maxTurns: 1,
                additionalSystemPrompt: systemPrompt,
                onToken: { _ in }
            )
        }

        return try await triageService.generateRawLocal(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        )
    }

    private func makeLocalAgentLoopIfAvailable(maxTokens: Int) -> LocalAgentLoop? {
        guard let localModelClient,
              let modelID = activeModelID(),
              let resolvedModel = LocalTextModelID(rawValue: modelID),
              resolvedModel.canActAsAgent else {
            return nil
        }

        return LocalAgentLoop(
            generator: LocalAgentLoop.mlxOneShotGenerator(using: localModelClient),
            structuredGenerator: constrainedDecoding.map { LocalAgentLoop.constrainedGenerator(using: $0) },
            toolExecutor: Self.unavailableToolExecutor,
            modelID: modelID,
            maxResponseTokens: maxTokens
        )
    }

    private static let unavailableToolExecutor: LocalAgentToolExecutor = { name, _ in
        LocalToolResult(
            toolName: name,
            resultJson: #"{"error":"No local tools are available for the device backend."}"#,
            isError: true
        )
    }
}

// MARK: - Types

struct DeviceActionResult: Sendable {
    let selector: String
    let action: DeviceActionType
    let confidence: Double
    let rawOutput: String
    let backendName: String
    let latencyMs: Double

    init(
        selector: String,
        action: DeviceActionType,
        confidence: Double,
        rawOutput: String,
        backendName: String,
        latencyMs: Double = 0
    ) {
        self.selector = selector
        self.action = action
        self.confidence = confidence
        self.rawOutput = rawOutput
        self.backendName = backendName
        self.latencyMs = latencyMs
    }

    var requiresEscalation: Bool {
        confidence < 0.8
    }
}

enum DeviceActionType: String, Sendable {
    case axPress = "AXPress"
    case cgClick = "CGClick"
    case keyInject = "KeyInject"
}

enum DeviceAgentError: Error, LocalizedError {
    case backendNotReady
    case backendUnavailable(String)
    case lowConfidence(Double)
    case selectorNotFound(String)

    var errorDescription: String? {
        switch self {
        case .backendNotReady: "Device agent backend not initialized"
        case .backendUnavailable(let message): message
        case .lowConfidence(let c): "Low confidence (\(String(format: "%.2f", c))) — requires user verification"
        case .selectorNotFound(let s): "UI element not found: \(s)"
        }
    }
}

// MARK: - Apple Contextual Action Resolver (Brain 2 ANE fast path)

/// Resolves a user intent against an AX tree using semantic embedding
/// similarity. Embeddings come from NLContextualEmbedding, which Apple
/// executes on the Neural Engine on Apple Silicon when assets are present.
///
/// This is not a generative model — it ranks interactive elements by how
/// well their visible labels match the user intent and returns the
/// top-ranked element as an AX selector. It is deterministic, offline, and
/// runs in single-digit milliseconds on ANE, which makes it a genuine
/// Brain 2 ANE path without requiring a custom `.mlpackage`.
@MainActor
final class AppleContextualActionResolver {
    private let embedding: AppleContextualEmbeddingLookup
    private let log = Logger(subsystem: "com.epistemos.omega", category: "ContextualResolver")

    init(language: NLLanguage = .english) {
        self.embedding = AppleContextualEmbeddingLookup(language: language)
    }

    /// Ready when NLContextualEmbedding assets are available on the device.
    var isReady: Bool { embedding.dimension > 0 }

    struct ElementCandidate {
        let selector: String
        let label: String
        let action: DeviceActionType
    }

    func resolve(axTreeJson: String, intent: String) -> DeviceActionResult? {
        guard isReady else { return nil }

        let start = ContinuousClock.now
        let candidates = Self.extractCandidates(from: axTreeJson)
        guard !candidates.isEmpty else { return nil }
        guard let intentVector = embedding.textVector(for: intent) else { return nil }
        let dimension = intentVector.count
        guard dimension > 0 else { return nil }
        let normalizedIntent = Self.l2Normalize(intentVector)

        var bestIndex: Int = -1
        var bestScore: Float = -.infinity
        for (index, candidate) in candidates.enumerated() {
            let label = Self.candidateText(candidate)
            guard !label.isEmpty,
                  let vector = embedding.textVector(for: label),
                  vector.count == dimension else {
                continue
            }
            let normalized = Self.l2Normalize(vector)
            let score = Self.dotProduct(normalizedIntent, normalized)
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        guard bestIndex >= 0 else { return nil }
        let elapsed = start.duration(to: ContinuousClock.now).omegaMilliseconds
        let winner = candidates[bestIndex]
        // Cosine scores are in [-1, 1]; shift to [0, 1] as confidence.
        let confidence = Double(max(-1, min(1, bestScore)) * 0.5 + 0.5)
        return DeviceActionResult(
            selector: winner.selector,
            action: winner.action,
            confidence: confidence,
            rawOutput: "",
            backendName: "ANE-Contextual",
            latencyMs: elapsed
        )
    }

    private static func extractCandidates(from json: String) -> [ElementCandidate] {
        let filtered = Screen2AXFusion.filterToInteractive(json)
        guard let data = filtered.data(using: .utf8),
              let tree = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = tree["elements"] as? [[String: Any]] else {
            return []
        }
        var result: [ElementCandidate] = []
        result.reserveCapacity(elements.count)
        for element in elements {
            guard element["is_interactive"] as? Bool == true else { continue }
            let role = element["role"] as? String ?? "AXUnknown"
            let title = (element["title"] as? String) ?? ""
            let description = (element["description"] as? String) ?? ""
            let value = (element["value"] as? String) ?? ""
            let label = [title, description, value].filter { !$0.isEmpty }.joined(separator: " ")
            guard !label.isEmpty else { continue }
            let selector = Self.buildSelector(role: role, title: title, description: description, value: value)
            let action: DeviceActionType = (role == "AXTextField" || role == "AXTextArea") ? .keyInject : .axPress
            result.append(ElementCandidate(selector: selector, label: label, action: action))
        }
        return result
    }

    private static func candidateText(_ candidate: ElementCandidate) -> String { candidate.label }

    private static func buildSelector(role: String, title: String, description: String, value: String) -> String {
        if !title.isEmpty {
            return "//\(role)[@AXTitle='\(Self.escape(title))']"
        }
        if !description.isEmpty {
            return "//\(role)[@AXDescription='\(Self.escape(description))']"
        }
        if !value.isEmpty {
            return "//\(role)[@AXValue='\(Self.escape(value))']"
        }
        return "//\(role)"
    }

    private static func escape(_ raw: String) -> String {
        raw.replacingOccurrences(of: "'", with: "\\'")
    }

    private static func l2Normalize(_ vector: [Float]) -> [Float] {
        var norm: Float = 0
        vDSP_svesq(vector, 1, &norm, vDSP_Length(vector.count))
        let magnitude = norm.squareRoot()
        guard magnitude > 0 else { return vector }
        var scaled = [Float](repeating: 0, count: vector.count)
        var scale = 1.0 / magnitude
        vDSP_vsmul(vector, 1, &scale, &scaled, 1, vDSP_Length(vector.count))
        return scaled
    }

    private static func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        var result: Float = 0
        vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(min(a.count, b.count)))
        return result
    }
}

// MARK: - Core ML Action Backend Loader

/// Loads a user-provided Core ML action model (`.mlmodelc` or `.mlpackage`) at
/// a known support-directory path and wraps it as a `DeviceInferenceBackend`
/// that executes on the Apple Neural Engine via `MLComputeUnits.cpuAndNeuralEngine`.
///
/// The slot is preserved but disabled for v1. A compiled model alone is not
/// enough to run a safe action backend; the app also needs concrete input/output
/// feature mapping, validation, and rollback behavior. Until that exists,
/// `loadIfAvailable` returns nil so DeviceAgentService keeps using its live
/// AppleOnDevice / SharedGPU backends.
@MainActor
enum CoreMLActionBackendLoader {
    static let actionModelFeatureMappingEnabled = false

    static func standardModelURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("brain2_action", isDirectory: true)
    }

    static func loadIfAvailable(url: URL = standardModelURL()) -> CoreMLActionBackend? {
        guard actionModelFeatureMappingEnabled else { return nil }

        let compiled = resolveCompiledModelURL(baseDir: url) ?? resolveCompiledModelURL(baseDir: url.deletingLastPathComponent())
        guard let compiled else { return nil }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        guard let model = try? MLModel(contentsOf: compiled, configuration: config) else {
            return nil
        }
        return CoreMLActionBackend(model: model, sourceURL: compiled)
    }

    private static func resolveCompiledModelURL(baseDir: URL) -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: baseDir.path) else { return nil }
        // Prefer pre-compiled `.mlmodelc` bundles; fall back to compiling a
        // `.mlpackage` on first use.
        if let entries = try? fileManager.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) {
            if let compiled = entries.first(where: { $0.pathExtension == "mlmodelc" }) {
                return compiled
            }
            if let package = entries.first(where: { $0.pathExtension == "mlpackage" }),
               let compiled = try? MLModel.compileModel(at: package) {
                return compiled
            }
        }
        return nil
    }
}

/// Deferred Core ML backend shell. Real inference wiring requires knowing the
/// model's input/output feature names, validation behavior, and rollback path.
/// If this backend is constructed directly before the loader gate is opened, it
/// fails honestly instead of returning fake action JSON.
@MainActor
final class CoreMLActionBackend: DeviceInferenceBackend {
    nonisolated let name = "CoreML-ANE"
    nonisolated let usesANE = true

    // SAFETY: MLModel is a Foundation ObjC class that is not Sendable by
    // default. We only invoke `prediction(from:)` from the MainActor bridge
    // below, so there are no concurrent mutations.
    nonisolated(unsafe) private let model: MLModel
    nonisolated private let sourceURL: URL

    init(model: MLModel, sourceURL: URL) {
        self.model = model
        self.sourceURL = sourceURL
    }

    nonisolated func generate(prompt _: String, systemPrompt _: String, maxTokens _: Int) async throws -> String {
        throw DeviceAgentError.backendUnavailable(
            "Core ML action backend is deferred until action-model feature mapping is implemented."
        )
    }
}
