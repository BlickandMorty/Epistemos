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
    private var streamToolSequence: UInt64 = 0

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
        inference.setPreparedLocalTextModelIDs(
            configuration?.interactiveLocalTextModelIDs(
                availableRuntimeKinds: inference.availableLocalGenerationRuntimeKinds
            ) ?? []
        )
    }

    func refreshRuntimeAvailability(for modelID: String? = nil) async -> Set<BackendRuntimeKind> {
        let kinds = await refreshAvailableRuntimeKinds(preparedGenerationRuntimeConfiguration, modelID)
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
        let preference = runtimePreference(for: modelID, requestedRuntimeKindOverride: requestedRuntimeKind)
        _ = await refreshRuntimeAvailability(for: modelID)
        let resolvedRuntimeKind = try await runtimeControlPlane.resolveGenerationRuntimeKind(
            requestedRuntimeKind: preference.requestedRuntimeKind
        )
        if resolvedRuntimeKind == .mlx, preference.requestedRuntimeKind == .gguf, !preference.allowMLXFallback {
            throw LocalInferenceRoutingError.runtimeUnavailable
        }

        switch resolvedRuntimeKind {
        case .gguf:
            return try await ggufClient.generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID,
                requestedRuntimeKind: preference.requestedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON
            )
        case .mlx:
            return try await mlxClient.generate(
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
                var provenance: LocalBackendStreamProvenanceContext?
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
                        provenance = Self.localBackendStreamProvenanceContext(
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
                    let elapsedMs = Self.localBackendStreamDurationMilliseconds(since: lifecycleStart)
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
                    let elapsedMs = Self.localBackendStreamDurationMilliseconds(since: lifecycleStart)
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
                    let elapsedMs = Self.localBackendStreamDurationMilliseconds(since: lifecycleStart)
                    let failureClass = Self.mapLocalBackendStreamError(error)
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

    private struct LocalBackendStreamProvenanceContext {
        let runID: String
        let toolCallID: String
        let actor: AgentProvenanceActor
        let argumentsJSON: String
        let metadata: [String: String]
    }

    private func makeStreamProvenanceContext(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) -> LocalBackendStreamProvenanceContext {
        LocalBackendStreamProvenanceContext(
            runID: "local-backend-stream-\(UUID().uuidString.uppercased())",
            toolCallID: nextStreamToolCallID(),
            actor: .agent(id: "local-backend-llm-client", modelID: nil),
            argumentsJSON: Self.localBackendStreamArgumentsJSON(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: requestedRuntimeKind,
                resolvedRuntimeKind: resolvedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON
            ),
            metadata: Self.localBackendStreamMetadata(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: requestedRuntimeKind,
                resolvedRuntimeKind: resolvedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON
            )
        )
    }

    private nonisolated static func localBackendStreamProvenanceContext(
        _ context: LocalBackendStreamProvenanceContext,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) -> LocalBackendStreamProvenanceContext {
        LocalBackendStreamProvenanceContext(
            runID: context.runID,
            toolCallID: context.toolCallID,
            actor: context.actor,
            argumentsJSON: localBackendStreamArgumentsJSON(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: requestedRuntimeKind,
                resolvedRuntimeKind: resolvedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON
            ),
            metadata: localBackendStreamMetadata(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                requestedRuntimeKind: requestedRuntimeKind,
                resolvedRuntimeKind: resolvedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON
            )
        )
    }

    private func nextStreamToolCallID() -> String {
        streamToolSequence += 1
        return "local-backend-stream:\(streamToolSequence)"
    }

    private func recordStreamAgentEvent(
        _ context: LocalBackendStreamProvenanceContext,
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
            toolName: "local_backend.stream",
            argumentsJSON: context.argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata ?? context.metadata
        )
    }

    private nonisolated static func localBackendStreamArgumentsJSON(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) -> String {
        localBackendStreamJSON([
            "max_tokens": max(0, maxTokens),
            "prompt_char_count": prompt.count,
            "provider": "local_backend",
            "reasoning_mode": reasoningMode.rawValue,
            "requested_runtime": requestedRuntimeKind?.rawValue ?? "none",
            "resolved_runtime": resolvedRuntimeKind?.rawValue ?? "pending",
            "steering_hints_present": hasSteeringHints(steeringHintsJSON),
            "system_prompt_char_count": systemPrompt?.count ?? 0,
        ])
    }

    private nonisolated static func localBackendStreamMetadata(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        requestedRuntimeKind: BackendRuntimeKind?,
        resolvedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
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
            "surface": "stream",
            "system_prompt_char_count": "\(systemPrompt?.count ?? 0)",
        ]
    }

    private nonisolated static func localBackendStreamResultJSON(
        success: Bool,
        elapsedMs: UInt64,
        chunkCount: Int? = nil,
        outputCharacterCount: Int? = nil
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
        return localBackendStreamJSON(payload)
    }

    private nonisolated static func localBackendStreamJSON(_ payload: [String: Any]) -> String {
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

    private nonisolated static func localBackendStreamDurationMilliseconds(since start: DispatchTime) -> UInt64 {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now >= start.uptimeNanoseconds else { return 0 }
        return (now - start.uptimeNanoseconds) / 1_000_000
    }

    private nonisolated static func mapLocalBackendStreamError(_ error: Error) -> String {
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
