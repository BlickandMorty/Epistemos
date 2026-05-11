import Foundation

@MainActor
final class LocalBackendLLMClient: RoutedLocalRuntimeClient {
    private let inference: InferenceState
    private let runtimeControlPlane: BackendRuntimeControlPlane
    private let mlxClient: any RoutedLocalRuntimeClient
    private let ggufClient: any RoutedLocalRuntimeClient
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder?
    private let refreshAvailableRuntimeKinds: @MainActor @Sendable (PreparedGenerationRuntimeConfiguration?, String?) async -> Set<BackendRuntimeKind>
    private var preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration?
    private var generateToolSequence: UInt64 = 0
    private var streamToolSequence: UInt64 = 0
    // RCA13 P1-022: cache the last refreshRuntimeAvailability result
    // keyed by modelID + a wall-clock stamp so back-to-back generate /
    // stream calls inside the same chat turn don't flip
    // inference.availableLocalGenerationRuntimeKinds repeatedly. Every
    // mutation of that field triggers a SwiftUI observer cascade
    // (the @Observable @MainActor InferenceState fires every property
    // setter), which spammed the chat composer's capability pill
    // re-render on every send. The cache is invalidated when the
    // prepared-runtime configuration changes (configurePreparedGenerationRuntime
    // clears it) or when the wall-clock TTL elapses.
    private struct AvailabilityCacheEntry {
        let modelID: String?
        let kinds: Set<BackendRuntimeKind>
        let timestamp: Date
    }
    private var lastAvailabilityCache: AvailabilityCacheEntry?
    private static let availabilityCacheTTL: TimeInterval = 5.0

    init(
        inference: InferenceState,
        runtimeControlPlane: BackendRuntimeControlPlane,
        mlxClient: any RoutedLocalRuntimeClient,
        ggufClient: any RoutedLocalRuntimeClient,
        refreshAvailableRuntimeKinds: @escaping @MainActor @Sendable (PreparedGenerationRuntimeConfiguration?, String?) async -> Set<BackendRuntimeKind>,
        preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration?,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil
    ) {
        self.inference = inference
        self.runtimeControlPlane = runtimeControlPlane
        self.mlxClient = mlxClient
        self.ggufClient = ggufClient
        self.agentProvenanceRecorder = agentProvenanceRecorder
        self.refreshAvailableRuntimeKinds = refreshAvailableRuntimeKinds
        self.preparedGenerationRuntimeConfiguration = preparedGenerationRuntimeConfiguration
    }

    func configurePreparedGenerationRuntime(_ configuration: PreparedGenerationRuntimeConfiguration?) {
        preparedGenerationRuntimeConfiguration = configuration
        // RCA13 P1-022: prepared-runtime config changes invalidate the
        // availability cache so the next generate/stream picks up the
        // new set instead of serving stale kinds.
        lastAvailabilityCache = nil
        inference.setPreparedLocalTextModelIDs(
            configuration?.interactiveLocalTextModelIDs(
                availableRuntimeKinds: inference.availableLocalGenerationRuntimeKinds
            ) ?? []
        )
    }

    func refreshRuntimeAvailability(for modelID: String? = nil) async -> Set<BackendRuntimeKind> {
        // RCA13 P1-022: short-circuit the FFI + observer cascade when
        // a recent refresh for the same modelID is still valid.
        if let cached = lastAvailabilityCache,
           cached.modelID == modelID,
           Date().timeIntervalSince(cached.timestamp) < Self.availabilityCacheTTL {
            return cached.kinds
        }
        let kinds = await refreshAvailableRuntimeKinds(preparedGenerationRuntimeConfiguration, modelID)
        lastAvailabilityCache = AvailabilityCacheEntry(
            modelID: modelID,
            kinds: kinds,
            timestamp: Date()
        )
        inference.setAvailableLocalGenerationRuntimeKinds(kinds)
        inference.setPreparedLocalTextModelIDs(
            preparedGenerationRuntimeConfiguration?.interactiveLocalTextModelIDs(
                availableRuntimeKinds: kinds
            ) ?? []
        )
        await runtimeControlPlane.setPolicy(
            BackendRuntimePolicy(
                availableRuntimeKinds: kinds,
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        return kinds
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil,
            requestedRuntimeKind: nil,
            steeringHintsJSON: nil
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID,
            requestedRuntimeKind: nil,
            steeringHintsJSON: nil
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        requestedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) async throws -> String {
        let lifecycleStart = DispatchTime.now()
        var provenance: LocalBackendProvenanceContext?
        do {
            let preference = runtimePreference(for: modelID, requestedRuntimeKindOverride: requestedRuntimeKind)
            provenance = makeGenerateProvenanceContext(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: preference.requestedRuntimeKind,
                resolvedRuntimeKind: nil,
                steeringHintsJSON: steeringHintsJSON
            )
            if let provenance {
                recordGenerateAgentEvent(
                    provenance,
                    kind: .toolCallRequested,
                    status: .requested
                )
                recordGenerateAgentEvent(
                    provenance,
                    kind: .toolCallStarted,
                    status: .started
                )
            }
            _ = await refreshRuntimeAvailability(for: modelID)
            let resolvedRuntimeKind = try await runtimeControlPlane.resolveGenerationRuntimeKind(
                requestedRuntimeKind: preference.requestedRuntimeKind
            )
            if let currentProvenance = provenance {
                provenance = Self.localBackendProvenanceContext(
                    currentProvenance,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    requestedRuntimeKind: preference.requestedRuntimeKind,
                    resolvedRuntimeKind: resolvedRuntimeKind,
                    steeringHintsJSON: steeringHintsJSON
                )
            }
            if resolvedRuntimeKind == .mlx, preference.requestedRuntimeKind == .gguf, !preference.allowMLXFallback {
                throw LocalInferenceRoutingError.runtimeUnavailable
            }

            let output: String
            switch resolvedRuntimeKind {
            case .gguf:
                output = try await ggufClient.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID,
                    requestedRuntimeKind: preference.requestedRuntimeKind,
                    steeringHintsJSON: steeringHintsJSON
                )
            case .mlx:
                output = try await mlxClient.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID,
                    requestedRuntimeKind: preference.requestedRuntimeKind,
                    steeringHintsJSON: steeringHintsJSON
                )
            case .remote:
                throw LocalInferenceRoutingError.runtimeUnavailable
            }
            let elapsedMs = Self.localBackendDurationMilliseconds(since: lifecycleStart)
            if let provenance {
                recordGenerateAgentEvent(
                    provenance,
                    kind: .toolCallCompleted,
                    resultJSON: Self.localBackendGenerateResultJSON(
                        success: true,
                        elapsedMs: elapsedMs,
                        outputCharacterCount: output.count
                    ),
                    durationMs: elapsedMs,
                    status: .completed
                )
            }
            return output
        } catch is CancellationError {
            let elapsedMs = Self.localBackendDurationMilliseconds(since: lifecycleStart)
            if let provenance {
                var failedMetadata = provenance.metadata
                failedMetadata["failure_class"] = "cancelled"
                recordGenerateAgentEvent(
                    provenance,
                    kind: .toolCallFailed,
                    resultJSON: Self.localBackendGenerateResultJSON(
                        success: false,
                        elapsedMs: elapsedMs
                    ),
                    durationMs: elapsedMs,
                    status: .failed,
                    errorMessage: "cancelled",
                    metadata: failedMetadata
                )
            }
            throw CancellationError()
        } catch {
            let elapsedMs = Self.localBackendDurationMilliseconds(since: lifecycleStart)
            let failureClass = Self.mapLocalBackendError(error)
            if let provenance {
                var failedMetadata = provenance.metadata
                failedMetadata["failure_class"] = failureClass
                recordGenerateAgentEvent(
                    provenance,
                    kind: .toolCallFailed,
                    resultJSON: Self.localBackendGenerateResultJSON(
                        success: false,
                        elapsedMs: elapsedMs
                    ),
                    durationMs: elapsedMs,
                    status: .failed,
                    errorMessage: failureClass,
                    metadata: failedMetadata
                )
            }
            throw error
        }
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil,
            requestedRuntimeKind: nil,
            steeringHintsJSON: nil
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID,
            requestedRuntimeKind: nil,
            steeringHintsJSON: nil
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        requestedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream(
            bufferingPolicy: .bufferingNewest(StreamingBufferPolicy.textLimit)
        ) { continuation in
            let task = Task { @MainActor in
                let lifecycleStart = DispatchTime.now()
                var provenance: LocalBackendProvenanceContext?
                var chunkCount = 0
                var outputCharacterCount = 0
                do {
                    let preference = runtimePreference(for: modelID, requestedRuntimeKindOverride: requestedRuntimeKind)
                    provenance = makeStreamProvenanceContext(
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens,
                        reasoningMode: reasoningMode,
                        requestedRuntimeKind: preference.requestedRuntimeKind,
                        resolvedRuntimeKind: nil,
                        steeringHintsJSON: steeringHintsJSON
                    )
                    if let provenance {
                        recordStreamAgentEvent(
                            provenance,
                            kind: .toolCallRequested,
                            status: .requested
                        )
                        recordStreamAgentEvent(
                            provenance,
                            kind: .toolCallStarted,
                            status: .started
                        )
                    }
                    _ = await refreshRuntimeAvailability(for: modelID)
                    let resolvedRuntimeKind = try await runtimeControlPlane.resolveGenerationRuntimeKind(
                        requestedRuntimeKind: preference.requestedRuntimeKind
                    )
                    if let currentProvenance = provenance {
                        provenance = Self.localBackendProvenanceContext(
                            currentProvenance,
                            prompt: prompt,
                            systemPrompt: systemPrompt,
                            maxTokens: maxTokens,
                            reasoningMode: reasoningMode,
                            requestedRuntimeKind: preference.requestedRuntimeKind,
                            resolvedRuntimeKind: resolvedRuntimeKind,
                            steeringHintsJSON: steeringHintsJSON
                        )
                    }
                    if resolvedRuntimeKind == .mlx,
                       preference.requestedRuntimeKind == .gguf,
                       !preference.allowMLXFallback {
                        throw LocalInferenceRoutingError.runtimeUnavailable
                    }

                    let stream: AsyncThrowingStream<String, Error>
                    switch resolvedRuntimeKind {
                    case .gguf:
                        stream = ggufClient.stream(
                            prompt: prompt,
                            systemPrompt: systemPrompt,
                            maxTokens: maxTokens,
                            reasoningMode: reasoningMode,
                            modelID: modelID,
                            requestedRuntimeKind: preference.requestedRuntimeKind,
                            steeringHintsJSON: steeringHintsJSON
                        )
                    case .mlx:
                        stream = mlxClient.stream(
                            prompt: prompt,
                            systemPrompt: systemPrompt,
                            maxTokens: maxTokens,
                            reasoningMode: reasoningMode,
                            modelID: modelID,
                            requestedRuntimeKind: preference.requestedRuntimeKind,
                            steeringHintsJSON: steeringHintsJSON
                        )
                    case .remote:
                        throw LocalInferenceRoutingError.runtimeUnavailable
                    }

                    for try await token in stream {
                        chunkCount += 1
                        outputCharacterCount += token.count
                        continuation.yield(token)
                    }
                    let elapsedMs = Self.localBackendDurationMilliseconds(since: lifecycleStart)
                    if let provenance {
                        recordStreamAgentEvent(
                            provenance,
                            kind: .toolCallCompleted,
                            resultJSON: Self.localBackendStreamResultJSON(
                                success: true,
                                elapsedMs: elapsedMs,
                                chunkCount: chunkCount,
                                outputCharacterCount: outputCharacterCount
                            ),
                            durationMs: elapsedMs,
                            status: .completed
                        )
                    }
                    continuation.finish()
                } catch is CancellationError {
                    let elapsedMs = Self.localBackendDurationMilliseconds(since: lifecycleStart)
                    if let provenance {
                        var failedMetadata = provenance.metadata
                        failedMetadata["failure_class"] = "cancelled"
                        recordStreamAgentEvent(
                            provenance,
                            kind: .toolCallFailed,
                            resultJSON: Self.localBackendStreamResultJSON(
                                success: false,
                                elapsedMs: elapsedMs
                            ),
                            durationMs: elapsedMs,
                            status: .failed,
                            errorMessage: "cancelled",
                            metadata: failedMetadata
                        )
                    }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    let elapsedMs = Self.localBackendDurationMilliseconds(since: lifecycleStart)
                    let failureClass = Self.mapLocalBackendError(error)
                    if let provenance {
                        var failedMetadata = provenance.metadata
                        failedMetadata["failure_class"] = failureClass
                        recordStreamAgentEvent(
                            provenance,
                            kind: .toolCallFailed,
                            resultJSON: Self.localBackendStreamResultJSON(
                                success: false,
                                elapsedMs: elapsedMs
                            ),
                            durationMs: elapsedMs,
                            status: .failed,
                            errorMessage: failureClass,
                            metadata: failedMetadata
                        )
                    }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        let kinds = await refreshRuntimeAvailability(for: inference.effectiveLocalTextModelID)
        if kinds.contains(.gguf) {
            return await ggufClient.testConnection()
        }
        return await mlxClient.testConnection()
    }

    func configSnapshot() -> LLMSnapshot {
        let modelID = inference.effectiveLocalTextModelID ?? ""
        return LLMSnapshot(
            provider: .localProvider(runtimeKind: snapshotRuntimeKind(for: modelID)),
            model: modelID,
            reasoningMode: .fast
        )
    }

    private func snapshotRuntimeKind(for modelID: String) -> BackendRuntimeKind {
        if let preparedRuntimeKind = preparedGenerationRuntimeConfiguration?.resolvedRuntimeKind(for: modelID),
           preparedGenerationRuntimeConfiguration?.hasUsablePreparedRuntime(for: modelID) == true,
           inference.availableLocalGenerationRuntimeKinds.contains(preparedRuntimeKind) {
            return preparedRuntimeKind
        }

        if let localModel = LocalTextModelID(rawValue: modelID),
           inference.availableLocalGenerationRuntimeKinds.contains(localModel.runtimeKind) {
            return localModel.runtimeKind
        }

        return .mlx
    }

    private func runtimePreference(
        for modelID: String?,
        requestedRuntimeKindOverride: BackendRuntimeKind?
    ) -> (requestedRuntimeKind: BackendRuntimeKind?, allowMLXFallback: Bool) {
        if let requestedRuntimeKindOverride {
            return (requestedRuntimeKindOverride, requestedRuntimeKindOverride != .gguf)
        }

        let resolvedModelID = modelID ?? inference.effectiveLocalTextModelID
        if let resolvedModelID,
           let preparedRuntimeKind = preparedGenerationRuntimeConfiguration?.resolvedRuntimeKind(for: resolvedModelID),
           preparedGenerationRuntimeConfiguration?.hasUsablePreparedRuntime(for: resolvedModelID) == true {
            let allowMLXFallback =
                preparedRuntimeKind == .gguf
                ? LocalTextModelID(rawValue: resolvedModelID)?.runtimeKind != .gguf
                : true
            return (preparedRuntimeKind, allowMLXFallback)
        }

        guard let resolvedModelID,
              let localModel = LocalTextModelID(rawValue: resolvedModelID) else {
            return (nil, true)
        }

        switch localModel.runtimeKind {
        case .gguf:
            return (.gguf, false)
        case .mlx:
            return (.mlx, true)
        case .remote:
            return (nil, true)
        }
    }

    private enum LocalBackendProvenanceSurface {
        case generate
        case stream

        nonisolated var runIDPrefix: String {
            switch self {
            case .generate: return "local-backend-generate-"
            case .stream: return "local-backend-stream-"
            }
        }

        nonisolated var toolCallPrefix: String {
            switch self {
            case .generate: return "local-backend-generate"
            case .stream: return "local-backend-stream"
            }
        }

        nonisolated var toolName: String {
            switch self {
            case .generate: return "local_backend.generate"
            case .stream: return "local_backend.stream"
            }
        }

        nonisolated var metadataValue: String {
            switch self {
            case .generate: return "generate"
            case .stream: return "stream"
            }
        }
    }

    private struct LocalBackendProvenanceContext {
        let runID: String
        let toolCallID: String
        let toolName: String
        let actor: AgentProvenanceActor
        let argumentsJSON: String
        let metadata: [String: String]
    }

    private func makeGenerateProvenanceContext(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) -> LocalBackendProvenanceContext {
        makeProvenanceContext(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            requestedRuntimeKind: requestedRuntimeKind,
            resolvedRuntimeKind: resolvedRuntimeKind,
            steeringHintsJSON: steeringHintsJSON,
            surface: .generate
        )
    }

    private func makeStreamProvenanceContext(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) -> LocalBackendProvenanceContext {
        makeProvenanceContext(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            requestedRuntimeKind: requestedRuntimeKind,
            resolvedRuntimeKind: resolvedRuntimeKind,
            steeringHintsJSON: steeringHintsJSON,
            surface: .stream
        )
    }

    private func makeProvenanceContext(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?,
        surface: LocalBackendProvenanceSurface
    ) -> LocalBackendProvenanceContext {
        LocalBackendProvenanceContext(
            runID: "\(surface.runIDPrefix)\(UUID().uuidString.uppercased())",
            toolCallID: nextToolCallID(for: surface),
            toolName: surface.toolName,
            actor: .agent(id: "local-backend-llm-client", modelID: nil),
            argumentsJSON: Self.localBackendArgumentsJSON(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: requestedRuntimeKind,
                resolvedRuntimeKind: resolvedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON,
                surface: surface
            ),
            metadata: Self.localBackendMetadata(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: requestedRuntimeKind,
                resolvedRuntimeKind: resolvedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON,
                surface: surface
            )
        )
    }

    private nonisolated static func localBackendProvenanceContext(
        _ context: LocalBackendProvenanceContext,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) -> LocalBackendProvenanceContext {
        let surface = context.metadata["surface"] == LocalBackendProvenanceSurface.generate.metadataValue
            ? LocalBackendProvenanceSurface.generate
            : LocalBackendProvenanceSurface.stream
        return LocalBackendProvenanceContext(
            runID: context.runID,
            toolCallID: context.toolCallID,
            toolName: context.toolName,
            actor: context.actor,
            argumentsJSON: localBackendArgumentsJSON(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: requestedRuntimeKind,
                resolvedRuntimeKind: resolvedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON,
                surface: surface
            ),
            metadata: localBackendMetadata(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: requestedRuntimeKind,
                resolvedRuntimeKind: resolvedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON,
                surface: surface
            )
        )
    }

    private func nextToolCallID(for surface: LocalBackendProvenanceSurface) -> String {
        switch surface {
        case .generate:
            generateToolSequence += 1
            return "\(surface.toolCallPrefix):\(generateToolSequence)"
        case .stream:
            streamToolSequence += 1
            return "\(surface.toolCallPrefix):\(streamToolSequence)"
        }
    }

    private func recordGenerateAgentEvent(
        _ context: LocalBackendProvenanceContext,
        kind: AgentProvenanceEventKind,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]? = nil
    ) {
        recordLocalBackendAgentEvent(
            context,
            kind: kind,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private func recordStreamAgentEvent(
        _ context: LocalBackendProvenanceContext,
        kind: AgentProvenanceEventKind,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]? = nil
    ) {
        recordLocalBackendAgentEvent(
            context,
            kind: kind,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private func recordLocalBackendAgentEvent(
        _ context: LocalBackendProvenanceContext,
        kind: AgentProvenanceEventKind,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]? = nil
    ) {
        agentProvenanceRecorder?.recordToolEvent(
            runID: context.runID,
            traceID: nil,
            kind: kind,
            actor: context.actor,
            toolCallID: context.toolCallID,
            toolName: context.toolName,
            argumentsJSON: context.argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata ?? context.metadata
        )
    }

    private nonisolated static func localBackendArgumentsJSON(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?,
        surface: LocalBackendProvenanceSurface
    ) -> String {
        localBackendJSON([
            "max_tokens": max(0, maxTokens),
            "prompt_char_count": prompt.count,
            "provider": "local_backend",
            "reasoning_mode": reasoningMode.rawValue,
            "requested_runtime": requestedRuntimeKind?.rawValue ?? "none",
            "resolved_runtime": resolvedRuntimeKind?.rawValue ?? "pending",
            "steering_hints_present": hasSteeringHints(steeringHintsJSON),
            "surface": surface.metadataValue,
            "system_prompt_char_count": systemPrompt?.count ?? 0,
        ])
    }

    private nonisolated static func localBackendMetadata(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?,
        surface: LocalBackendProvenanceSurface
    ) -> [String: String] {
        [
            "max_tokens": "\(max(0, maxTokens))",
            "prompt_char_count": "\(prompt.count)",
            "provider": "local_backend",
            "reasoning_mode": reasoningMode.rawValue,
            "requested_runtime": requestedRuntimeKind?.rawValue ?? "none",
            "resolved_runtime": resolvedRuntimeKind?.rawValue ?? "pending",
            "source": "local_backend_llm_client",
            "steering_hints_present": "\(hasSteeringHints(steeringHintsJSON))",
            "surface": surface.metadataValue,
            "system_prompt_char_count": "\(systemPrompt?.count ?? 0)",
        ]
    }

    private nonisolated static func localBackendGenerateResultJSON(
        success: Bool,
        elapsedMs: UInt64,
        outputCharacterCount: Int? = nil
    ) -> String {
        localBackendResultJSON(
            success: success,
            elapsedMs: elapsedMs,
            chunkCount: nil,
            outputCharacterCount: outputCharacterCount
        )
    }

    private nonisolated static func localBackendStreamResultJSON(
        success: Bool,
        elapsedMs: UInt64,
        chunkCount: Int? = nil,
        outputCharacterCount: Int? = nil
    ) -> String {
        localBackendResultJSON(
            success: success,
            elapsedMs: elapsedMs,
            chunkCount: chunkCount,
            outputCharacterCount: outputCharacterCount
        )
    }

    private nonisolated static func localBackendResultJSON(
        success: Bool,
        elapsedMs: UInt64,
        chunkCount: Int?,
        outputCharacterCount: Int?
    ) -> String {
        var payload: [String: Any] = [
            "elapsed_ms": elapsedMs,
            "success": success,
        ]
        if let chunkCount {
            payload["chunk_count"] = chunkCount
        }
        if let outputCharacterCount {
            payload["output_char_count"] = outputCharacterCount
        }
        return localBackendJSON(payload)
    }

    private nonisolated static func localBackendJSON(_ payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private nonisolated static func hasSteeringHints(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private nonisolated static func localBackendDurationMilliseconds(since start: DispatchTime) -> UInt64 {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now >= start.uptimeNanoseconds else { return 0 }
        return (now - start.uptimeNanoseconds) / 1_000_000
    }

    private nonisolated static func mapLocalBackendError(_ error: Error) -> String {
        if error is CancellationError {
            return "cancelled"
        }
        if let routingError = error as? LocalInferenceRoutingError {
            switch routingError {
            case .modelRequired:
                return "model_required"
            case .runtimeUnavailable, .fastModeUnsupported:
                return "runtime_unavailable"
            case .modelLoaderUnavailable, .modelLoadStalled, .insufficientMemory:
                return "model_unavailable"
            }
        }
        return "backend_failure"
    }
}
