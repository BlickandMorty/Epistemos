import Foundation

@MainActor
final class LocalBackendLLMClient: RoutedLocalRuntimeClient {
    private let inference: InferenceState
    private let runtimeControlPlane: BackendRuntimeControlPlane
    private let mlxClient: any RoutedLocalRuntimeClient
    private let ggufClient: any RoutedLocalRuntimeClient
    private let refreshAvailableRuntimeKinds: @MainActor @Sendable (PreparedGenerationRuntimeConfiguration?, String?) async -> Set<BackendRuntimeKind>
    private var preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration?

    init(
        inference: InferenceState,
        runtimeControlPlane: BackendRuntimeControlPlane,
        mlxClient: any RoutedLocalRuntimeClient,
        ggufClient: any RoutedLocalRuntimeClient,
        refreshAvailableRuntimeKinds: @escaping @MainActor @Sendable (PreparedGenerationRuntimeConfiguration?, String?) async -> Set<BackendRuntimeKind>,
        preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration?
    ) {
        self.inference = inference
        self.runtimeControlPlane = runtimeControlPlane
        self.mlxClient = mlxClient
        self.ggufClient = ggufClient
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
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let preference = runtimePreference(for: modelID, requestedRuntimeKindOverride: requestedRuntimeKind)
                    _ = await refreshRuntimeAvailability(for: modelID)
                    let resolvedRuntimeKind = try await runtimeControlPlane.resolveGenerationRuntimeKind(
                        requestedRuntimeKind: preference.requestedRuntimeKind
                    )
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
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
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
           let preparedRuntimeKind = preparedGenerationRuntimeConfiguration?.resolvedRuntimeKind(for: resolvedModelID) {
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
}
