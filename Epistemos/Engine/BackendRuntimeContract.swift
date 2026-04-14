import Foundation

nonisolated enum BackendRuntimeKind: String, Codable, Sendable, CaseIterable {
    case gguf
    case mlx
    case remote
}

nonisolated enum BackendExecutionMode: String, Codable, Sendable, CaseIterable {
    case local
    case remote
    case hybrid
}

nonisolated enum BackendReasoningProfile: String, Codable, Sendable, CaseIterable {
    case standard
    case deep = "deep_graph"
    case adaptive
    case experimental
    case visualSidecar = "visual_sidecar"

    init(localReasoningMode: LocalReasoningMode) {
        switch localReasoningMode {
        case .fast:
            self = .standard
        case .thinking:
            self = .deep
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case Self.standard.rawValue:
            self = .standard
        case "deep", Self.deep.rawValue:
            self = .deep
        case Self.adaptive.rawValue:
            self = .adaptive
        case Self.experimental.rawValue:
            self = .experimental
        case Self.visualSidecar.rawValue:
            self = .visualSidecar
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported backend reasoning profile: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum BackendRuntimeOperation: String, Codable, Sendable, CaseIterable {
    case generate
    case embed
    case adapt
    case imageGenerate
}

nonisolated enum BackendRuntimeContractError: String, Error, Codable, Sendable, Equatable, LocalizedError {
    case modelNotFound = "model_not_found"
    case modelNotLoaded = "model_not_loaded"
    case unsupportedCapability = "unsupported_capability"
    case timeout
    case cancelled
    case policyDenied = "policy_denied"
    case runtimeUnavailable = "runtime_unavailable"
    case memoryPressure = "memory_pressure"
    case invalidTransition = "invalid_transition"
    case backendFailure = "backend_failure"
    case contractViolation = "contract_violation"

    var errorDescription: String? {
        rawValue
    }
}

nonisolated enum BackendGenerationEventKind: String, Codable, Sendable, Equatable {
    case started
    case token
    case status
    case toolStatus = "tool_status"
    case summary
    case completed
    case failed
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            true
        case .started, .token, .status, .toolStatus, .summary:
            false
        }
    }
}

// MARK: - Phase 2: Compute Steering Types

nonisolated enum BackendComputeProfile: String, Codable, Sendable, CaseIterable, Equatable {
    case standard
    case deepGraph = "deep_graph"
    case adaptive
    case experimental
    case visualSidecar = "visual_sidecar"
}

nonisolated enum BackendExpertBudgetClass: String, Codable, Sendable, CaseIterable, Equatable {
    case `default`
    case constrained
    case deep
}

nonisolated enum BackendKVPolicyKind: String, Codable, Sendable, CaseIterable, Equatable {
    case baseline
    case compressed
    case blocked
}

nonisolated struct BackendComputeBudget: Sendable, Equatable, Codable {
    let maxWallMS: UInt64?
    let maxTokens: UInt32?
    let maxIOBytes: UInt64?
    let maxAdaptSteps: UInt32?
    let maxAuxCalls: UInt32?

    var isUnbounded: Bool {
        maxWallMS == nil && maxTokens == nil && maxIOBytes == nil
            && maxAdaptSteps == nil && maxAuxCalls == nil
    }

    enum CodingKeys: String, CodingKey {
        case maxWallMS = "max_wall_ms"
        case maxTokens = "max_tokens"
        case maxIOBytes = "max_io_bytes"
        case maxAdaptSteps = "max_adapt_steps"
        case maxAuxCalls = "max_aux_calls"
    }
}

nonisolated struct BackendSteeringHints: Sendable, Equatable, Codable {
    let maskPlan: BackendSteeringMaskPlan?
    let kvPolicyHint: String?
    let depthBudget: BackendSteeringDepthBudget?
    let loraBlendCoefficients: [BackendSteeringLoRACoefficient]?

    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    enum CodingKeys: String, CodingKey {
        case maskPlan = "mask_plan"
        case kvPolicyHint = "kv_policy_hint"
        case depthBudget = "depth_budget"
        case loraBlendCoefficients = "lora_blend_coefficients"
    }
}

nonisolated struct BackendSteeringMaskPlan: Sendable, Equatable, Codable {
    let expertAllowlist: [String]
    let blockSize: UInt32
    let rationale: String?

    enum CodingKeys: String, CodingKey {
        case expertAllowlist = "expert_allowlist"
        case blockSize = "block_size"
        case rationale
    }
}

nonisolated struct BackendSteeringDepthBudget: Sendable, Equatable, Codable {
    let maxTurns: UInt32
    let maxReasoningSteps: UInt32
    let maxToolCalls: UInt32
    let maxOutputTokens: UInt32

    enum CodingKeys: String, CodingKey {
        case maxTurns = "max_turns"
        case maxReasoningSteps = "max_reasoning_steps"
        case maxToolCalls = "max_tool_calls"
        case maxOutputTokens = "max_output_tokens"
    }
}

nonisolated struct BackendSteeringLoRACoefficient: Sendable, Equatable, Codable {
    let adapterID: String
    let coefficient: Double

    enum CodingKeys: String, CodingKey {
        case adapterID = "adapter_id"
        case coefficient
    }
}

// MARK: - Runtime Policy

nonisolated struct BackendRuntimePolicy: Sendable, Equatable {
    let availableRuntimeKinds: Set<BackendRuntimeKind>
    let primaryGenerationRuntimeKind: BackendRuntimeKind
    let allowMLXGenerationFallback: Bool
    let allowedReasoningProfiles: Set<BackendReasoningProfile>
    let defaultReasoningProfile: BackendReasoningProfile

    init(
        availableRuntimeKinds: Set<BackendRuntimeKind>,
        primaryGenerationRuntimeKind: BackendRuntimeKind = .gguf,
        allowMLXGenerationFallback: Bool = true,
        allowedReasoningProfiles: Set<BackendReasoningProfile> = [.standard, .deep],
        defaultReasoningProfile: BackendReasoningProfile = .standard
    ) {
        self.availableRuntimeKinds = availableRuntimeKinds
        self.primaryGenerationRuntimeKind = primaryGenerationRuntimeKind
        self.allowMLXGenerationFallback = allowMLXGenerationFallback
        self.allowedReasoningProfiles = allowedReasoningProfiles
        self.defaultReasoningProfile = defaultReasoningProfile
    }
}

nonisolated struct BackendModelLoadRequest: Sendable, Equatable {
    let requestedRuntimeKind: BackendRuntimeKind?
    let executionMode: BackendExecutionMode
    let modelID: String
    let artifactID: String?
}

nonisolated struct BackendModelHandle: Sendable, Equatable, Identifiable {
    let id: String
    let runtimeKind: BackendRuntimeKind
    let executionMode: BackendExecutionMode
    let modelID: String
    let artifactID: String?
}

nonisolated struct BackendGenerationStreamOptions: Sendable, Equatable {
    let includeStatusEvents: Bool

    init(includeStatusEvents: Bool = true) {
        self.includeStatusEvents = includeStatusEvents
    }
}

nonisolated struct BackendRuntimeHandshakeRequest: Sendable, Equatable {
    let requestedRuntimeKind: BackendRuntimeKind?
    let executionMode: BackendExecutionMode
    let operation: BackendRuntimeOperation
    let reasoningProfile: BackendReasoningProfile?
    let executionPolicyRef: String?
}

nonisolated struct BackendRuntimeHandshake: Sendable, Equatable {
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind
    let requestedReasoningProfile: BackendReasoningProfile?
    let resolvedReasoningProfile: BackendReasoningProfile?
    let executionPolicyID: String?
    let capabilities: BackendRuntimeCapabilities
    let usedFallbackResolution: Bool
}

nonisolated struct BackendGenerationRequest: Sendable, Equatable {
    let requestID: String
    let requestedRuntimeKind: BackendRuntimeKind?
    let executionMode: BackendExecutionMode
    let modelID: String
    let artifactID: String?
    let modelHandleID: String?
    let prompt: String
    let systemPrompt: String?
    let maxOutputTokens: Int
    let temperature: Double
    let stopSequences: [String]
    let toolPolicyRef: String?
    let contextRef: String?
    let reasoningProfile: BackendReasoningProfile?
    let executionPolicyRef: String?
    let steeringHintsJSON: String?
    let priority: Int
    let timeoutMS: Int
    let streamOptions: BackendGenerationStreamOptions
}

nonisolated struct BackendGenerationLaunch: Sendable, Equatable {
    let requestID: String
    let streamHandle: String
    let modelHandle: BackendModelHandle
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind
    let requestedReasoningProfile: BackendReasoningProfile?
    let resolvedReasoningProfile: BackendReasoningProfile
    let executionPolicyID: String?
}

nonisolated struct BackendEmbeddingRequest: Sendable, Equatable {
    let requestedRuntimeKind: BackendRuntimeKind?
    let executionMode: BackendExecutionMode
    let modelID: String?
    let artifactID: String?
    let text: String
    let expectedDimension: Int?
}

nonisolated struct BackendEmbeddingResult: Sendable, Equatable {
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind
    let executionMode: BackendExecutionMode
    let modelID: String?
    let artifactID: String?
    let vector: [Float]
    let dimension: Int
}

nonisolated struct BackendGenerationSummary: Sendable, Equatable {
    let requestID: String
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind
    let requestedReasoningProfile: BackendReasoningProfile?
    let resolvedReasoningProfile: BackendReasoningProfile
    let executionMode: BackendExecutionMode
    let modelID: String
    let artifactID: String?
    let executionPolicyID: String?
    let fallbackMode: String
    let timeToFirstTokenMS: Double?
    let totalDurationMS: Double
    let tokensPerSecond: Double?
    let outputTokenCount: Int
    let outputCharacterCount: Int
    let memoryPressureState: String
    let executionPhase: String
    let maskingState: String
    let kvPolicyState: String
    let expertBudgetState: String
    let adaptationState: String
    let guardrailState: String
    let sidecarState: String
    let budgetOutcome: String
    let planTracePresent: Bool
    let cancelled: Bool
    let errorClass: BackendRuntimeContractError?
}

nonisolated struct BackendGenerationEvent: Sendable, Equatable {
    let kind: BackendGenerationEventKind
    let text: String?
    let status: String?
    let summary: BackendGenerationSummary?
    let errorClass: BackendRuntimeContractError?
    let errorMessage: String?

    static func started() -> Self {
        Self(kind: .started, text: nil, status: nil, summary: nil, errorClass: nil, errorMessage: nil)
    }

    static func token(_ text: String) -> Self {
        Self(kind: .token, text: text, status: nil, summary: nil, errorClass: nil, errorMessage: nil)
    }

    static func status(_ status: String) -> Self {
        Self(kind: .status, text: nil, status: status, summary: nil, errorClass: nil, errorMessage: nil)
    }

    static func summary(_ summary: BackendGenerationSummary) -> Self {
        Self(kind: .summary, text: nil, status: nil, summary: summary, errorClass: nil, errorMessage: nil)
    }

    static func completed(_ summary: BackendGenerationSummary) -> Self {
        Self(kind: .completed, text: nil, status: nil, summary: summary, errorClass: summary.errorClass, errorMessage: nil)
    }

    static func failed(
        errorClass: BackendRuntimeContractError,
        message: String,
        summary: BackendGenerationSummary?
    ) -> Self {
        Self(kind: .failed, text: nil, status: nil, summary: summary, errorClass: errorClass, errorMessage: message)
    }

    static func cancelled(_ summary: BackendGenerationSummary?) -> Self {
        Self(kind: .cancelled, text: nil, status: nil, summary: summary, errorClass: .cancelled, errorMessage: nil)
    }
}

nonisolated struct BackendRuntimeStatsTarget: Sendable, Equatable {
    let modelHandleID: String?
    let streamHandle: String?

    static func model(_ handleID: String) -> Self {
        Self(modelHandleID: handleID, streamHandle: nil)
    }

    static func stream(_ handleID: String) -> Self {
        Self(modelHandleID: nil, streamHandle: handleID)
    }
}

nonisolated struct BackendRuntimeStats: Sendable, Equatable {
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind?
    let requestedReasoningProfile: BackendReasoningProfile?
    let resolvedReasoningProfile: BackendReasoningProfile?
    let modelID: String?
    let artifactID: String?
    let executionPolicyID: String?
    let fallbackMode: String?
    let memoryPressureState: String?
    let executionPhase: String?
    let maskingState: String
    let kvPolicyState: String
    let expertBudgetState: String
    let adaptationState: String
    let guardrailState: String
    let sidecarState: String
    let budgetOutcome: String
    let planTracePresent: Bool
    let computeProfile: BackendComputeProfile?
    let expertBudgetClass: BackendExpertBudgetClass?
    let kvPolicyKind: BackendKVPolicyKind?
    let capabilities: BackendRuntimeCapabilities
    let cancelled: Bool
    let terminalEventEmitted: Bool
}

nonisolated struct BackendRuntimeCapabilities: Sendable, Equatable {
    let supportsGenerate: Bool
    let supportsEmbed: Bool
    let supportsAdapt: Bool
    let supportsImageGenerate: Bool
    let supportsStructuredMasking: Bool
    let supportsDynamicSparsity: Bool
    let supportsSpeculativeDecoding: Bool
    let supportsStreamingFromSSD: Bool
    let supportsKVPolicy: Bool
    let supportsExpertBudgeting: Bool
    let supportsSerialIOAudit: Bool
    let supportsToolCalls: Bool

    static func runtime(_ runtimeKind: BackendRuntimeKind) -> Self {
        switch runtimeKind {
        case .gguf:
            Self(
                supportsGenerate: true,
                supportsEmbed: false,
                supportsAdapt: false,
                supportsImageGenerate: false,
                supportsStructuredMasking: false,
                supportsDynamicSparsity: false,
                supportsSpeculativeDecoding: false,
                supportsStreamingFromSSD: true,
                supportsKVPolicy: false,
                supportsExpertBudgeting: false,
                supportsSerialIOAudit: true,
                supportsToolCalls: false
            )
        case .mlx:
            Self(
                supportsGenerate: true,
                supportsEmbed: true,
                supportsAdapt: false,
                supportsImageGenerate: false,
                supportsStructuredMasking: false,
                supportsDynamicSparsity: false,
                supportsSpeculativeDecoding: false,
                supportsStreamingFromSSD: true,
                supportsKVPolicy: false,
                supportsExpertBudgeting: false,
                supportsSerialIOAudit: true,
                supportsToolCalls: false
            )
        case .remote:
            Self(
                supportsGenerate: false,
                supportsEmbed: false,
                supportsAdapt: false,
                supportsImageGenerate: false,
                supportsStructuredMasking: false,
                supportsDynamicSparsity: false,
                supportsSpeculativeDecoding: false,
                supportsStreamingFromSSD: false,
                supportsKVPolicy: false,
                supportsExpertBudgeting: false,
                supportsSerialIOAudit: false,
                supportsToolCalls: false
            )
        }
    }
}

actor BackendRuntimeControlPlane {
    private let runtimeControlPlane: RuntimeControlPlane
    private var policy: BackendRuntimePolicy
    private var modelHandles: [String: BackendModelHandle] = [:]
    private let embeddingResolver: (@MainActor @Sendable (BackendEmbeddingRequest) -> [Float]?)?

    init(
        policy: BackendRuntimePolicy,
        embeddingResolver: (@MainActor @Sendable (BackendEmbeddingRequest) -> [Float]?)? = nil
    ) {
        self.policy = policy
        self.embeddingResolver = embeddingResolver
        let runtimeControlPlane = RuntimeControlPlane(
            availableRuntimeKinds: policy.orderedRuntimeKinds,
            primaryGenerationRuntimeKind: policy.primaryGenerationRuntimeKind.runtimeKind,
            allowMlxGenerationFallback: policy.allowMLXGenerationFallback
        )
        runtimeControlPlane.setPolicy(policy: policy.runtimePolicy)
        self.runtimeControlPlane = runtimeControlPlane
    }

    func setPolicy(_ policy: BackendRuntimePolicy) {
        self.policy = policy
        runtimeControlPlane.setPolicy(policy: policy.runtimePolicy)
    }

    func loadModel(request: BackendModelLoadRequest) throws -> BackendModelHandle {
        let handle = try mapRuntimeError {
            try runtimeControlPlane.loadModel(request: request.runtimeModelLoadRequest)
        }
        let backendHandle = BackendModelHandle(handle)
        modelHandles[backendHandle.id] = backendHandle
        return backendHandle
    }

    func unloadModel(handleID: String) throws {
        try mapRuntimeError {
            try runtimeControlPlane.unloadModel(handleId: handleID)
        }
        modelHandles.removeValue(forKey: handleID)
    }

    func generate(request: BackendGenerationRequest) throws -> BackendGenerationLaunch {
        let modelHandle: BackendModelHandle
        if let modelHandleID = request.modelHandleID {
            guard let existing = modelHandles[modelHandleID] else {
                throw BackendRuntimeContractError.modelNotLoaded
            }
            modelHandle = existing
        } else {
            modelHandle = try loadModel(
                request: BackendModelLoadRequest(
                    requestedRuntimeKind: request.requestedRuntimeKind,
                    executionMode: request.executionMode,
                    modelID: request.modelID,
                    artifactID: request.artifactID
                )
            )
        }

        let streamHandle = try mapRuntimeError {
            try runtimeControlPlane.generate(
                request: request.runtimeGenerationRequest(modelHandleID: modelHandle.id)
            )
        }
        let stats = try self.stats(target: .stream(streamHandle))

        return BackendGenerationLaunch(
            requestID: request.requestID,
            streamHandle: streamHandle,
            modelHandle: modelHandle,
            requestedRuntimeKind: request.requestedRuntimeKind,
            resolvedRuntimeKind: stats.resolvedRuntimeKind ?? modelHandle.runtimeKind,
            requestedReasoningProfile: request.reasoningProfile,
            resolvedReasoningProfile: stats.resolvedReasoningProfile
                ?? request.reasoningProfile
                ?? policy.defaultReasoningProfile,
            executionPolicyID: stats.executionPolicyID ?? request.executionPolicyRef
        )
    }

    func handshake(request: BackendRuntimeHandshakeRequest) throws -> BackendRuntimeHandshake {
        try mapRuntimeError {
            try BackendRuntimeHandshake(runtimeControlPlane.handshake(request: request.runtimeHandshakeRequest))
        }
    }

    func resolveGenerationRuntimeKind(
        requestedRuntimeKind: BackendRuntimeKind?
    ) throws -> BackendRuntimeKind {
        let handle = try mapRuntimeError {
            try runtimeControlPlane.loadModel(
                request: RuntimeModelLoadRequest(
                    requestedRuntimeKind: requestedRuntimeKind?.runtimeKind,
                    executionMode: .local,
                    modelId: "__runtime_resolution__",
                    artifactId: nil
                )
            )
        }
        defer {
            try? runtimeControlPlane.unloadModel(handleId: handle.handleId)
        }
        return BackendRuntimeKind(handle.runtimeKind)
    }

    func appendStarted(streamHandle: String) throws {
        try mapRuntimeError {
            try runtimeControlPlane.emitStarted(streamHandle: streamHandle)
        }
    }

    func appendStatus(streamHandle: String, status: String) throws {
        try mapRuntimeError {
            try runtimeControlPlane.emitStatus(streamHandle: streamHandle, status: status)
        }
    }

    func appendToken(streamHandle: String, text: String) throws {
        try mapRuntimeError {
            try runtimeControlPlane.emitToken(streamHandle: streamHandle, text: text)
        }
    }

    func appendSummary(streamHandle: String, summary: BackendGenerationSummary) throws {
        try mapRuntimeError {
            try runtimeControlPlane.emitSummary(
                streamHandle: streamHandle,
                summary: summary.runtimeGenerationSummary
            )
        }
    }

    func finishCompleted(streamHandle: String, summary: BackendGenerationSummary) throws {
        try mapRuntimeError {
            try runtimeControlPlane.finishCompleted(
                streamHandle: streamHandle,
                summary: summary.runtimeGenerationSummary
            )
        }
    }

    func finishFailed(
        streamHandle: String,
        errorClass: BackendRuntimeContractError,
        message: String,
        summary: BackendGenerationSummary? = nil
    ) throws {
        try mapRuntimeError {
            try runtimeControlPlane.finishFailed(
                streamHandle: streamHandle,
                errorClass: errorClass.runtimeContractError,
                errorMessage: message,
                summary: summary?.runtimeGenerationSummary
            )
        }
    }

    func finishCancelled(
        streamHandle: String,
        summary: BackendGenerationSummary? = nil
    ) throws {
        try mapRuntimeError {
            try runtimeControlPlane.finishCancelled(
                streamHandle: streamHandle,
                summary: summary?.runtimeGenerationSummary
            )
        }
    }

    func cancel(streamHandle: String) throws {
        try mapRuntimeError {
            try runtimeControlPlane.cancel(streamHandle: streamHandle)
        }
    }

    func pollEvent(streamHandle: String) throws -> BackendGenerationEvent? {
        try mapRuntimeError {
            try runtimeControlPlane.pollEvent(streamHandle: streamHandle)?.backendGenerationEvent
        }
    }

    func pollEvents(streamHandle: String, maxEvents: Int) throws -> [BackendGenerationEvent] {
        try mapRuntimeError {
            try runtimeControlPlane.pollEvents(
                streamHandle: streamHandle,
                maxEvents: UInt32(clamping: maxEvents)
            ).map { $0.backendGenerationEvent }
        }
    }

    func closeStream(streamHandle: String) {
        _ = runtimeControlPlane.closeStream(streamHandle: streamHandle)
    }

    func stats(target: BackendRuntimeStatsTarget) throws -> BackendRuntimeStats {
        try mapRuntimeError {
            try BackendRuntimeStats(runtimeControlPlane.stats(target: target.runtimeStatsTarget))
        }
    }

    func embed(request: BackendEmbeddingRequest) async throws -> BackendEmbeddingResult {
        let handshake = try self.handshake(
            request: BackendRuntimeHandshakeRequest(
                requestedRuntimeKind: request.requestedRuntimeKind,
                executionMode: request.executionMode,
                operation: .embed,
                reasoningProfile: nil,
                executionPolicyRef: nil
            )
        )
        guard handshake.capabilities.supportsEmbed, handshake.resolvedRuntimeKind == .mlx else {
            throw BackendRuntimeContractError.unsupportedCapability
        }
        guard let embeddingResolver else {
            throw BackendRuntimeContractError.unsupportedCapability
        }
        guard let vector = await embeddingResolver(request) else {
            throw BackendRuntimeContractError.backendFailure
        }

        return BackendEmbeddingResult(
            requestedRuntimeKind: request.requestedRuntimeKind,
            resolvedRuntimeKind: handshake.resolvedRuntimeKind,
            executionMode: request.executionMode,
            modelID: request.modelID,
            artifactID: request.artifactID,
            vector: vector,
            dimension: vector.count
        )
    }

    func embed() throws {
        try mapRuntimeError {
            try runtimeControlPlane.embed()
        }
    }

    func adapt() throws {
        try mapRuntimeError {
            try runtimeControlPlane.adapt()
        }
    }

    func imageGenerate() throws {
        try mapRuntimeError {
            try runtimeControlPlane.imageGenerate()
        }
    }
}

private extension BackendRuntimeControlPlane {
    func mapRuntimeError<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as RuntimeContractError {
            throw BackendRuntimeContractError(error)
        }
    }
}

private extension BackendRuntimeKind {
    nonisolated init(_ runtimeKind: RuntimeKind) {
        switch runtimeKind {
        case .gguf:
            self = .gguf
        case .mlx:
            self = .mlx
        case .remote:
            self = .remote
        }
    }

    nonisolated var runtimeKind: RuntimeKind {
        switch self {
        case .gguf:
            .gguf
        case .mlx:
            .mlx
        case .remote:
            .remote
        }
    }
}

private extension BackendExecutionMode {
    nonisolated init(_ executionMode: ExecutionMode) {
        switch executionMode {
        case .local:
            self = .local
        case .remote:
            self = .remote
        case .hybrid:
            self = .hybrid
        }
    }

    nonisolated var executionMode: ExecutionMode {
        switch self {
        case .local:
            .local
        case .remote:
            .remote
        case .hybrid:
            .hybrid
        }
    }
}

private extension BackendReasoningProfile {
    nonisolated init(_ reasoningProfile: ReasoningProfile) {
        switch reasoningProfile {
        case .standard:
            self = .standard
        case .deep:
            self = .deep
        case .adaptive:
            self = .adaptive
        case .experimental:
            self = .experimental
        case .visualSidecar:
            self = .visualSidecar
        }
    }

    nonisolated var reasoningProfile: ReasoningProfile {
        switch self {
        case .standard:
            .standard
        case .deep:
            .deep
        case .adaptive:
            .adaptive
        case .experimental:
            .experimental
        case .visualSidecar:
            .visualSidecar
        }
    }
}

private extension BackendRuntimeOperation {
    nonisolated init(_ runtimeOperation: RuntimeOperation) {
        switch runtimeOperation {
        case .generate:
            self = .generate
        case .embed:
            self = .embed
        case .adapt:
            self = .adapt
        case .imageGenerate:
            self = .imageGenerate
        }
    }

    nonisolated var runtimeOperation: RuntimeOperation {
        switch self {
        case .generate:
            .generate
        case .embed:
            .embed
        case .adapt:
            .adapt
        case .imageGenerate:
            .imageGenerate
        }
    }
}

private extension BackendRuntimeContractError {
    nonisolated init(_ runtimeContractError: RuntimeContractError) {
        switch runtimeContractError {
        case .ModelNotFound(_):
            self = .modelNotFound
        case .ModelNotLoaded(_):
            self = .modelNotLoaded
        case .UnsupportedCapability(_):
            self = .unsupportedCapability
        case .Timeout(_):
            self = .timeout
        case .Cancelled(_):
            self = .cancelled
        case .PolicyDenied(_):
            self = .policyDenied
        case .RuntimeUnavailable(_):
            self = .runtimeUnavailable
        case .MemoryPressure(_):
            self = .memoryPressure
        case .InvalidTransition(_):
            self = .invalidTransition
        case .BackendFailure(_):
            self = .backendFailure
        case .ContractViolation(_):
            self = .contractViolation
        }
    }

    nonisolated var runtimeContractError: RuntimeContractError {
        let message = rawValue
        return switch self {
        case .modelNotFound:
            RuntimeContractError.ModelNotFound(message: message)
        case .modelNotLoaded:
            RuntimeContractError.ModelNotLoaded(message: message)
        case .unsupportedCapability:
            RuntimeContractError.UnsupportedCapability(message: message)
        case .timeout:
            RuntimeContractError.Timeout(message: message)
        case .cancelled:
            RuntimeContractError.Cancelled(message: message)
        case .policyDenied:
            RuntimeContractError.PolicyDenied(message: message)
        case .runtimeUnavailable:
            RuntimeContractError.RuntimeUnavailable(message: message)
        case .memoryPressure:
            RuntimeContractError.MemoryPressure(message: message)
        case .invalidTransition:
            RuntimeContractError.InvalidTransition(message: message)
        case .backendFailure:
            RuntimeContractError.BackendFailure(message: message)
        case .contractViolation:
            RuntimeContractError.ContractViolation(message: message)
        }
    }
}

private extension BackendRuntimePolicy {
    nonisolated var orderedRuntimeKinds: [RuntimeKind] {
        BackendRuntimeKind.allCases
            .filter(availableRuntimeKinds.contains)
            .map(\.runtimeKind)
    }

    nonisolated var orderedReasoningProfiles: [ReasoningProfile] {
        BackendReasoningProfile.allCases
            .filter(allowedReasoningProfiles.contains)
            .map(\.reasoningProfile)
    }

    nonisolated var runtimePolicy: RuntimePolicy {
        RuntimePolicy(
            availableRuntimeKinds: orderedRuntimeKinds,
            primaryGenerationRuntimeKind: primaryGenerationRuntimeKind.runtimeKind,
            allowMlxGenerationFallback: allowMLXGenerationFallback,
            allowedReasoningProfiles: orderedReasoningProfiles,
            defaultReasoningProfile: defaultReasoningProfile.reasoningProfile
        )
    }
}

private extension BackendModelLoadRequest {
    nonisolated var runtimeModelLoadRequest: RuntimeModelLoadRequest {
        RuntimeModelLoadRequest(
            requestedRuntimeKind: requestedRuntimeKind?.runtimeKind,
            executionMode: executionMode.executionMode,
            modelId: modelID,
            artifactId: artifactID
        )
    }
}

private extension BackendModelHandle {
    nonisolated init(_ runtimeModelHandle: RuntimeModelHandle) {
        self.init(
            id: runtimeModelHandle.handleId,
            runtimeKind: BackendRuntimeKind(runtimeModelHandle.runtimeKind),
            executionMode: BackendExecutionMode(runtimeModelHandle.executionMode),
            modelID: runtimeModelHandle.modelId,
            artifactID: runtimeModelHandle.artifactId
        )
    }
}

private extension BackendGenerationStreamOptions {
    nonisolated var runtimeGenerationStreamOptions: RuntimeGenerationStreamOptions {
        RuntimeGenerationStreamOptions(includeStatusEvents: includeStatusEvents)
    }
}

private extension BackendGenerationRequest {
    nonisolated func runtimeGenerationRequest(modelHandleID: String?) -> RuntimeGenerationRequest {
        RuntimeGenerationRequest(
            requestId: requestID,
            requestedRuntimeKind: requestedRuntimeKind?.runtimeKind,
            executionMode: executionMode.executionMode,
            modelId: modelID,
            artifactId: artifactID,
            modelHandleId: modelHandleID,
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxOutputTokens: UInt32(clamping: maxOutputTokens),
            temperature: temperature,
            stopSequences: stopSequences,
            toolPolicyRef: toolPolicyRef,
            contextRef: contextRef,
            reasoningProfile: reasoningProfile?.reasoningProfile,
            executionPolicyRef: executionPolicyRef,
            steeringHintsJson: steeringHintsJSON,
            priority: Int32(clamping: priority),
            timeoutMs: UInt32(clamping: timeoutMS),
            streamOptions: streamOptions.runtimeGenerationStreamOptions
        )
    }
}

private extension BackendRuntimeHandshakeRequest {
    nonisolated var runtimeHandshakeRequest: RuntimeHandshakeRequest {
        RuntimeHandshakeRequest(
            requestedRuntimeKind: requestedRuntimeKind?.runtimeKind,
            executionMode: executionMode.executionMode,
            operation: operation.runtimeOperation,
            reasoningProfile: reasoningProfile?.reasoningProfile,
            executionPolicyRef: executionPolicyRef
        )
    }
}

private extension BackendGenerationSummary {
    nonisolated var runtimeGenerationSummary: RuntimeGenerationSummary {
        RuntimeGenerationSummary(
            requestId: requestID,
            requestedRuntimeKind: requestedRuntimeKind?.runtimeKind,
            resolvedRuntimeKind: resolvedRuntimeKind.runtimeKind,
            requestedReasoningProfile: requestedReasoningProfile?.reasoningProfile,
            resolvedReasoningProfile: resolvedReasoningProfile.reasoningProfile,
            executionMode: executionMode.executionMode,
            modelId: modelID,
            artifactId: artifactID,
            executionPolicyId: executionPolicyID,
            fallbackMode: fallbackMode,
            timeToFirstTokenMs: timeToFirstTokenMS,
            totalDurationMs: totalDurationMS,
            tokensPerSecond: tokensPerSecond,
            outputTokenCount: UInt32(clamping: outputTokenCount),
            outputCharacterCount: UInt32(clamping: outputCharacterCount),
            memoryPressureState: memoryPressureState,
            executionPhase: executionPhase,
            maskingState: maskingState,
            kvPolicyState: kvPolicyState,
            expertBudgetState: expertBudgetState,
            adaptationState: adaptationState,
            guardrailState: guardrailState,
            sidecarState: sidecarState,
            budgetOutcome: budgetOutcome,
            planTracePresent: planTracePresent,
            cancelled: cancelled,
            errorClass: errorClass?.runtimeContractError
        )
    }
}

private extension BackendGenerationEventKind {
    nonisolated init(_ generationEventKind: GenerationEventKind) {
        switch generationEventKind {
        case .started:
            self = .started
        case .token:
            self = .token
        case .status:
            self = .status
        case .toolStatus:
            self = .toolStatus
        case .summary:
            self = .summary
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        case .cancelled:
            self = .cancelled
        }
    }
}

private extension BackendGenerationEvent {
    nonisolated init(_ runtimeGenerationEvent: RuntimeGenerationEvent) {
        self.init(
            kind: BackendGenerationEventKind(runtimeGenerationEvent.kind),
            text: runtimeGenerationEvent.text,
            status: runtimeGenerationEvent.status,
            summary: runtimeGenerationEvent.summary.map(BackendGenerationSummary.init),
            errorClass: runtimeGenerationEvent.errorClass.map(BackendRuntimeContractError.init),
            errorMessage: runtimeGenerationEvent.errorMessage
        )
    }
}

private extension RuntimeGenerationEvent {
    nonisolated var backendGenerationEvent: BackendGenerationEvent {
        BackendGenerationEvent(self)
    }
}

private extension BackendRuntimeStatsTarget {
    nonisolated var runtimeStatsTarget: RuntimeStatsTarget {
        RuntimeStatsTarget(modelHandleId: modelHandleID, streamHandle: streamHandle)
    }
}

private extension BackendRuntimeCapabilities {
    nonisolated init(_ runtimeCapabilities: RuntimeCapabilities) {
        self.init(
            supportsGenerate: runtimeCapabilities.supportsGenerate,
            supportsEmbed: runtimeCapabilities.supportsEmbed,
            supportsAdapt: runtimeCapabilities.supportsAdapt,
            supportsImageGenerate: runtimeCapabilities.supportsImageGenerate,
            supportsStructuredMasking: runtimeCapabilities.supportsStructuredMasking,
            supportsDynamicSparsity: runtimeCapabilities.supportsDynamicSparsity,
            supportsSpeculativeDecoding: runtimeCapabilities.supportsSpeculativeDecoding,
            supportsStreamingFromSSD: runtimeCapabilities.supportsStreamingFromSsd,
            supportsKVPolicy: runtimeCapabilities.supportsKvPolicy,
            supportsExpertBudgeting: runtimeCapabilities.supportsExpertBudgeting,
            supportsSerialIOAudit: runtimeCapabilities.supportsSerialIoAudit,
            supportsToolCalls: runtimeCapabilities.supportsToolCalls
        )
    }
}

private extension BackendRuntimeHandshake {
    nonisolated init(_ runtimeHandshake: RuntimeHandshake) {
        self.init(
            requestedRuntimeKind: runtimeHandshake.requestedRuntimeKind.map(BackendRuntimeKind.init),
            resolvedRuntimeKind: BackendRuntimeKind(runtimeHandshake.resolvedRuntimeKind),
            requestedReasoningProfile: runtimeHandshake.requestedReasoningProfile.map(BackendReasoningProfile.init),
            resolvedReasoningProfile: runtimeHandshake.resolvedReasoningProfile.map(BackendReasoningProfile.init),
            executionPolicyID: runtimeHandshake.executionPolicyId,
            capabilities: BackendRuntimeCapabilities(runtimeHandshake.capabilities),
            usedFallbackResolution: runtimeHandshake.usedFallbackResolution
        )
    }
}

private extension BackendRuntimeStats {
    nonisolated init(_ runtimeStats: RuntimeStats) {
        self.init(
            requestedRuntimeKind: runtimeStats.requestedRuntimeKind.map(BackendRuntimeKind.init),
            resolvedRuntimeKind: runtimeStats.resolvedRuntimeKind.map(BackendRuntimeKind.init),
            requestedReasoningProfile: runtimeStats.requestedReasoningProfile.map(BackendReasoningProfile.init),
            resolvedReasoningProfile: runtimeStats.resolvedReasoningProfile.map(BackendReasoningProfile.init),
            modelID: runtimeStats.modelId,
            artifactID: runtimeStats.artifactId,
            executionPolicyID: runtimeStats.executionPolicyId,
            fallbackMode: runtimeStats.fallbackMode,
            memoryPressureState: runtimeStats.memoryPressureState,
            executionPhase: runtimeStats.executionPhase,
            maskingState: runtimeStats.maskingState,
            kvPolicyState: runtimeStats.kvPolicyState,
            expertBudgetState: runtimeStats.expertBudgetState,
            adaptationState: runtimeStats.adaptationState,
            guardrailState: runtimeStats.guardrailState,
            sidecarState: runtimeStats.sidecarState,
            budgetOutcome: runtimeStats.budgetOutcome,
            planTracePresent: runtimeStats.planTracePresent,
            computeProfile: runtimeStats.computeProfile.map(BackendComputeProfile.init),
            expertBudgetClass: runtimeStats.expertBudgetClass.map(BackendExpertBudgetClass.init),
            kvPolicyKind: runtimeStats.kvPolicyKind.map(BackendKVPolicyKind.init),
            capabilities: BackendRuntimeCapabilities(runtimeStats.capabilities),
            cancelled: runtimeStats.cancelled,
            terminalEventEmitted: runtimeStats.terminalEventEmitted
        )
    }
}

private extension BackendGenerationSummary {
    nonisolated init(_ runtimeGenerationSummary: RuntimeGenerationSummary) {
        self.init(
            requestID: runtimeGenerationSummary.requestId,
            requestedRuntimeKind: runtimeGenerationSummary.requestedRuntimeKind.map(BackendRuntimeKind.init),
            resolvedRuntimeKind: BackendRuntimeKind(runtimeGenerationSummary.resolvedRuntimeKind),
            requestedReasoningProfile: runtimeGenerationSummary.requestedReasoningProfile.map(BackendReasoningProfile.init),
            resolvedReasoningProfile: BackendReasoningProfile(runtimeGenerationSummary.resolvedReasoningProfile),
            executionMode: BackendExecutionMode(runtimeGenerationSummary.executionMode),
            modelID: runtimeGenerationSummary.modelId,
            artifactID: runtimeGenerationSummary.artifactId,
            executionPolicyID: runtimeGenerationSummary.executionPolicyId,
            fallbackMode: runtimeGenerationSummary.fallbackMode,
            timeToFirstTokenMS: runtimeGenerationSummary.timeToFirstTokenMs,
            totalDurationMS: runtimeGenerationSummary.totalDurationMs,
            tokensPerSecond: runtimeGenerationSummary.tokensPerSecond,
            outputTokenCount: Int(runtimeGenerationSummary.outputTokenCount),
            outputCharacterCount: Int(runtimeGenerationSummary.outputCharacterCount),
            memoryPressureState: runtimeGenerationSummary.memoryPressureState,
            executionPhase: runtimeGenerationSummary.executionPhase,
            maskingState: runtimeGenerationSummary.maskingState,
            kvPolicyState: runtimeGenerationSummary.kvPolicyState,
            expertBudgetState: runtimeGenerationSummary.expertBudgetState,
            adaptationState: runtimeGenerationSummary.adaptationState,
            guardrailState: runtimeGenerationSummary.guardrailState,
            sidecarState: runtimeGenerationSummary.sidecarState,
            budgetOutcome: runtimeGenerationSummary.budgetOutcome,
            planTracePresent: runtimeGenerationSummary.planTracePresent,
            cancelled: runtimeGenerationSummary.cancelled,
            errorClass: runtimeGenerationSummary.errorClass.map(BackendRuntimeContractError.init)
        )
    }
}

// MARK: - Phase 2: Compute Steering FFI Bridging

private extension BackendComputeProfile {
    nonisolated init(_ computeProfile: ComputeProfile) {
        switch computeProfile {
        case .standard:
            self = .standard
        case .deepGraph:
            self = .deepGraph
        case .adaptive:
            self = .adaptive
        case .experimental:
            self = .experimental
        case .visualSidecar:
            self = .visualSidecar
        }
    }
}

private extension BackendExpertBudgetClass {
    nonisolated init(_ expertBudgetClass: ExpertBudgetClass) {
        switch expertBudgetClass {
        case .default:
            self = .default
        case .constrained:
            self = .constrained
        case .deep:
            self = .deep
        }
    }
}

private extension BackendKVPolicyKind {
    nonisolated init(_ kvPolicyKind: KvPolicyKind) {
        switch kvPolicyKind {
        case .baseline:
            self = .baseline
        case .compressed:
            self = .compressed
        case .blocked:
            self = .blocked
        }
    }
}
