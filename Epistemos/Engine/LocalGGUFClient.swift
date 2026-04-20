import Foundation

#if canImport(GGUFRuntimeBridge)
import GGUFRuntimeBridge
#endif

nonisolated struct LocalGGUFRuntimeAvailability: Sendable, Equatable {
    let runtimeKind: BackendRuntimeKind
    let modelURL: URL
    let resolvedModelID: String
}

nonisolated struct LocalGGUFRequest: Sendable, Equatable {
    let modelID: String
    let artifactID: String?
    let modelURL: URL
    let prompt: String
    let systemPrompt: String?
    let maxTokens: Int
    let reasoningMode: LocalReasoningMode
    let steeringHintsJSON: String?
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind
}

nonisolated struct LocalGGUFRunProfile: Sendable, Equatable {
    let modelID: String
    let artifactID: String?
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind
    let executionMode: BackendExecutionMode
    let modelURL: URL
    let resolvedModelID: String
    let firstTokenLatencyMS: Double?
    let totalDurationMS: Double
    let outputTokenCount: Int
    let tokensPerSecond: Double?
    let outputCharacterCount: Int
    let executionPhase: String
    let fallbackMode: String
    let availableMemoryBytes: UInt64
}

nonisolated enum LocalGGUFRuntimeError: LocalizedError, Equatable {
    case runtimeUnavailable
    case modelNotPrepared
    case backendUnavailable
    case fastModeUnsupported(modelID: String)

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "The local GGUF runtime is unavailable right now."
        case .modelNotPrepared:
            return "The selected GGUF model is not prepared on disk yet."
        case .backendUnavailable:
            return "The in-process GGUF backend is unavailable in this build."
        case .fastModeUnsupported(let modelID):
            return "Fast mode is unavailable for \(modelID) because this local model always emits thinking traces. Switch to Thinking or pick a different local model."
        }
    }
}

nonisolated protocol LocalGGUFRuntime: Sendable {
    func availability(
        requestedModelID: String,
        artifactID: String?,
        modelDirectory: URL?
    ) async throws -> LocalGGUFRuntimeAvailability
    func generate(request: LocalGGUFRequest) async throws -> String
    func stream(request: LocalGGUFRequest) async -> AsyncThrowingStream<String, Error>
    func profilingSnapshot() async -> LocalGGUFRunProfile?
}

nonisolated enum LocalGGUFModelLocator {
    static func resolveModelURL(
        modelDirectory: URL?,
        modelID: String,
        artifactID: String?,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let modelDirectory else { return nil }
        let standardizedRoot = modelDirectory.standardizedFileURL
        guard fileManager.fileExists(atPath: standardizedRoot.path) else { return nil }

        if standardizedRoot.pathExtension.caseInsensitiveCompare("gguf") == .orderedSame {
            return standardizedRoot
        }

        guard let enumerator = fileManager.enumerator(
            at: standardizedRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        let candidates = [
            artifactID,
            modelID,
            LocalTextModelID(rawValue: modelID)?.displayName,
            LocalTextModelID(rawValue: modelID)?.compactDisplayName,
            standardizedRoot.lastPathComponent,
        ]
        .compactMap { $0 }

        var rankedMatches: [(score: Int, url: URL)] = []
        for case let candidateURL as URL in enumerator {
            guard candidateURL.pathExtension.caseInsensitiveCompare("gguf") == .orderedSame else {
                continue
            }
            guard fileManager.fileExists(atPath: candidateURL.path) else {
                continue
            }

            let score = matchScore(for: candidateURL, candidates: candidates)
            rankedMatches.append((score, candidateURL.standardizedFileURL))
        }

        guard !rankedMatches.isEmpty else { return nil }
        return rankedMatches
            .sorted {
                if $0.score == $1.score {
                    return $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
                }
                return $0.score > $1.score
            }
            .first?
            .url
    }

    private static func matchScore(for url: URL, candidates: [String]) -> Int {
        let normalizedFilename = normalizedVariants(for: url.deletingPathExtension().lastPathComponent)
        guard !normalizedFilename.isEmpty else { return 0 }

        var score = 0
        for candidate in candidates {
            let variants = normalizedVariants(for: candidate)
            guard !variants.isEmpty else { continue }

            if !normalizedFilename.isDisjoint(with: variants) {
                score += 100
                continue
            }

            if variants.contains(where: { variant in
                normalizedFilename.contains(where: { $0.contains(variant) || variant.contains($0) })
            }) {
                score += 10
            }
        }

        return score
    }

    private static func normalizedVariants(for rawValue: String) -> Set<String> {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".gguf", with: "")
        guard !trimmed.isEmpty else { return [] }

        var values: Set<String> = [trimmed]
        values.insert(trimmed.replacingOccurrences(of: "/", with: "-"))
        values.insert(trimmed.replacingOccurrences(of: "/", with: "_"))
        values.insert(trimmed.replacingOccurrences(of: " ", with: "-"))
        values.insert(trimmed.replacingOccurrences(of: " ", with: "_"))
        values.insert(
            trimmed
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
        )
        if let tail = trimmed.split(separator: "/").last {
            values.insert(String(tail))
        }
        return values
    }
}

nonisolated struct LocalGGUFEngine: Sendable {
    let generate: @Sendable (String, String?, Int) async throws -> String
    let stream: @Sendable (String, String?, Int) async -> AsyncThrowingStream<String, Error>
}

actor LocalGGUFInProcessRuntime: LocalGGUFRuntime {
    private struct EngineKey: Hashable {
        let modelURL: URL
        let reasoningMode: LocalReasoningMode
    }

    typealias EngineBuilder = @Sendable (URL, String, LocalReasoningMode) async throws -> LocalGGUFEngine

    private let engineBuilder: EngineBuilder
    private let serialController: LocalInferenceSerialController
    private var engines: [EngineKey: LocalGGUFEngine] = [:]
    private var lastRunProfile: LocalGGUFRunProfile?

    init(
        serialController: LocalInferenceSerialController = LocalInferenceSerialController(),
        engineBuilder: EngineBuilder? = nil
    ) {
        self.serialController = serialController
        self.engineBuilder = engineBuilder ?? Self.defaultEngineBuilder
    }

    func availability(
        requestedModelID: String,
        artifactID: String?,
        modelDirectory: URL?
    ) async throws -> LocalGGUFRuntimeAvailability {
        guard let modelURL = LocalGGUFModelLocator.resolveModelURL(
            modelDirectory: modelDirectory,
            modelID: requestedModelID,
            artifactID: artifactID
        ) else {
            throw LocalGGUFRuntimeError.modelNotPrepared
        }

        return LocalGGUFRuntimeAvailability(
            runtimeKind: .gguf,
            modelURL: modelURL,
            resolvedModelID: artifactID ?? modelURL.deletingPathExtension().lastPathComponent
        )
    }

    func generate(request: LocalGGUFRequest) async throws -> String {
        let start = ContinuousClock.now
        let resolvedModelID = request.artifactID ?? request.modelURL.deletingPathExtension().lastPathComponent
        let serialSnapshot = serialController.refreshAvailableMemory()
        let fallbackMode = serialSnapshot.fallbackMode.rawValue
        var output = ""

        try serialController.beginTurn()
        do {
            recordTurnBoundaryReadaheadIfNeeded()

            try serialController.beginSsdRead()
            let engine = try await engine(
                modelURL: request.modelURL,
                modelID: request.modelID,
                reasoningMode: request.reasoningMode
            )
            try serialController.finishSsdRead()

            try serialController.beginGpuCompute()
            output = try await engine.generate(
                request.prompt,
                request.systemPrompt,
                request.maxTokens
            )
            do {
                try serialController.finishGpuCompute()
            } catch {
                logSerialControllerCleanupFailure("finishGpuCompute", error: error)
            }
            do {
                try serialController.endTurn()
            } catch {
                logSerialControllerCleanupFailure("endTurn", error: error)
            }
            let finalSnapshot = serialController.refreshAvailableMemory()
            let profile = makeProfile(
                request: request,
                resolvedModelID: resolvedModelID,
                output: output,
                start: start,
                firstTokenLatencyMS: nil,
                executionPhase: "decode",
                fallbackMode: fallbackMode,
                availableMemoryBytes: finalSnapshot.availableMemoryBytes
            )
            lastRunProfile = profile
            return output
        } catch {
            finishSerialTurnAfterFailure()
            throw error
        }
    }

    func stream(request: LocalGGUFRequest) async -> AsyncThrowingStream<String, Error> {
        StreamingBufferPolicy.throwingStream { continuation in
            let task = Task {
                let start = ContinuousClock.now
                let resolvedModelID = request.artifactID ?? request.modelURL.deletingPathExtension().lastPathComponent
                let initialSnapshot = self.serialController.refreshAvailableMemory()
                let fallbackMode = initialSnapshot.fallbackMode.rawValue
                var output = ""
                var firstTokenLatencyMS: Double?

                do {
                    try self.serialController.beginTurn()
                    self.recordTurnBoundaryReadaheadIfNeeded()

                    try self.serialController.beginSsdRead()
                    let engine = try await self.engine(
                        modelURL: request.modelURL,
                        modelID: request.modelID,
                        reasoningMode: request.reasoningMode
                    )
                    try self.serialController.finishSsdRead()

                    try self.serialController.beginGpuCompute()
                    let source = await engine.stream(
                        request.prompt,
                        request.systemPrompt,
                        request.maxTokens
                    )
                    for try await chunk in source {
                        if firstTokenLatencyMS == nil {
                            let latency = start.duration(to: ContinuousClock.now)
                            firstTokenLatencyMS =
                                Double(latency.components.seconds) * 1_000
                                + Double(latency.components.attoseconds) / 1_000_000_000_000_000
                        }
                        output += chunk
                        continuation.yield(chunk)
                    }
                    do {
                        try self.serialController.finishGpuCompute()
                    } catch {
                        self.logSerialControllerCleanupFailure("finishGpuCompute", error: error)
                    }
                    do {
                        try self.serialController.endTurn()
                    } catch {
                        self.logSerialControllerCleanupFailure("endTurn", error: error)
                    }
                    let finalSnapshot = self.serialController.refreshAvailableMemory()
                    let profile = self.makeProfile(
                        request: request,
                        resolvedModelID: resolvedModelID,
                        output: output,
                        start: start,
                        firstTokenLatencyMS: firstTokenLatencyMS,
                        executionPhase: "decode",
                        fallbackMode: fallbackMode,
                        availableMemoryBytes: finalSnapshot.availableMemoryBytes
                    )
                    self.lastRunProfile = profile
                    continuation.finish()
                } catch {
                    self.finishSerialTurnAfterFailure()
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func profilingSnapshot() -> LocalGGUFRunProfile? {
        lastRunProfile
    }

    private func engine(
        modelURL: URL,
        modelID: String,
        reasoningMode: LocalReasoningMode
    ) async throws -> LocalGGUFEngine {
        let key = EngineKey(modelURL: modelURL.standardizedFileURL, reasoningMode: reasoningMode)
        if let existing = engines[key] {
            return existing
        }

        let created = try await engineBuilder(key.modelURL, modelID, reasoningMode)
        engines[key] = created
        return created
    }

    private func makeProfile(
        request: LocalGGUFRequest,
        resolvedModelID: String,
        output: String,
        start: ContinuousClock.Instant,
        firstTokenLatencyMS: Double?,
        executionPhase: String,
        fallbackMode: String,
        availableMemoryBytes: UInt64
    ) -> LocalGGUFRunProfile {
        let total = start.duration(to: ContinuousClock.now)
        let totalDurationMS =
            Double(total.components.seconds) * 1_000
            + Double(total.components.attoseconds) / 1_000_000_000_000_000
        let outputTokenCount = LocalGenerationMetrics.estimatedTokenCount(for: output)
        let tokensPerSecond = totalDurationMS > 0
            ? Double(outputTokenCount) / (totalDurationMS / 1_000)
            : nil

        return LocalGGUFRunProfile(
            modelID: request.modelID,
            artifactID: request.artifactID,
            requestedRuntimeKind: request.requestedRuntimeKind,
            resolvedRuntimeKind: request.resolvedRuntimeKind,
            executionMode: .local,
            modelURL: request.modelURL,
            resolvedModelID: resolvedModelID,
            firstTokenLatencyMS: firstTokenLatencyMS,
            totalDurationMS: totalDurationMS,
            outputTokenCount: outputTokenCount,
            tokensPerSecond: tokensPerSecond,
            outputCharacterCount: output.count,
            executionPhase: executionPhase,
            fallbackMode: fallbackMode,
            availableMemoryBytes: availableMemoryBytes
        )
    }

    private func logSerialControllerCleanupFailure(_ action: String, error: Error) {
        Log.engine.warning(
            "LocalGGUFInProcessRuntime: \(action, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    private func recordTurnBoundaryReadaheadIfNeeded() {
        guard serialController.snapshot().turnBoundaryReadaheadAllowed else { return }
        do {
            try serialController.recordTurnBoundaryReadahead()
        } catch {
            logSerialControllerCleanupFailure("recordTurnBoundaryReadahead", error: error)
        }
    }

    private func finishSerialTurnAfterFailure() {
        do {
            try serialController.finishGpuCompute()
        } catch {
            logSerialControllerCleanupFailure("finishGpuCompute", error: error)
        }
        do {
            try serialController.finishSsdRead()
        } catch {
            logSerialControllerCleanupFailure("finishSsdRead", error: error)
        }
        do {
            try serialController.endTurn()
        } catch {
            logSerialControllerCleanupFailure("endTurn", error: error)
        }
    }

    private nonisolated static func defaultEngineBuilder(
        modelURL: URL,
        modelID: String,
        reasoningMode: LocalReasoningMode
    ) async throws -> LocalGGUFEngine {
#if canImport(GGUFRuntimeBridge)
        let session = try await LocalGGUFSwiftSession(
            modelURL: modelURL,
            modelID: modelID,
            reasoningMode: reasoningMode
        )
        return LocalGGUFEngine(
            generate: { prompt, systemPrompt, maxTokens in
                try await session.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens
                )
            },
            stream: { prompt, systemPrompt, maxTokens in
                await session.stream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens
                )
            }
        )
#else
        _ = modelURL
        _ = modelID
        _ = reasoningMode
        throw LocalGGUFRuntimeError.backendUnavailable
#endif
    }
}

#if canImport(GGUFRuntimeBridge)
actor LocalGGUFSwiftSession {
    private let session: GGUFSessionBridge

    init(
        modelURL: URL,
        modelID: String,
        reasoningMode: LocalReasoningMode
    ) async throws {
        let session = try await GGUFSessionBridge(
            modelURL: modelURL,
            parameters: Self.parameter(
                modelID: modelID,
                reasoningMode: reasoningMode
            )
        )
        self.session = session
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        var output = ""
        let stream = await stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        )
        for try await chunk in stream {
            output += chunk
        }
        return output
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async -> AsyncThrowingStream<String, Error> {
        await session.stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        )
    }

    private nonisolated static func parameter(
        modelID: String,
        reasoningMode: LocalReasoningMode
    ) -> GGUFSessionParameters {
        let declaredContext = LocalTextModelID(rawValue: modelID)?.maxContextTokens ?? 8_192
        let context = max(4_096, min(declaredContext, 16_384))
        return GGUFSessionParameters(
            context: context,
            batch: 512,
            temperature: reasoningMode == .thinking ? 0.35 : 0.2,
            topK: 40,
            topP: reasoningMode == .thinking ? 0.95 : 0.9,
            typicalP: 1,
            penaltyLastN: 64,
            penaltyRepeat: 1.05
        )
    }
}
#endif

@MainActor
protocol RoutedLocalRuntimeClient: LocalConfigurableLLMClient {
    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        requestedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) async throws -> String

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        requestedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error>
}

extension RoutedLocalRuntimeClient {
    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID,
            requestedRuntimeKind: nil,
            steeringHintsJSON: steeringHintsJSON
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID,
            requestedRuntimeKind: nil,
            steeringHintsJSON: steeringHintsJSON
        )
    }
}

@MainActor
final class LocalGGUFClient: RoutedLocalRuntimeClient {
    private let runtime: any LocalGGUFRuntime
    private let inference: InferenceState
    private let runtimeControlPlane: BackendRuntimeControlPlane
    private let prepareForRequest: @MainActor @Sendable () async -> Void
    private var preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration?
    private var onRunProfileUpdated: (@Sendable (LocalGGUFRunProfile) -> Void)?

    init(
        runtime: any LocalGGUFRuntime,
        inference: InferenceState,
        runtimeControlPlane: BackendRuntimeControlPlane,
        prepareForRequest: @escaping @MainActor @Sendable () async -> Void = {}
    ) {
        self.runtime = runtime
        self.inference = inference
        self.runtimeControlPlane = runtimeControlPlane
        self.prepareForRequest = prepareForRequest
    }

    func configurePreparedGenerationRuntime(_ configuration: PreparedGenerationRuntimeConfiguration?) {
        preparedGenerationRuntimeConfiguration = configuration
    }

    func setOnRunProfileUpdated(_ handler: @escaping @Sendable (LocalGGUFRunProfile) -> Void) {
        onRunProfileUpdated = handler
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
        let request = try resolvedRequest(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID,
            requestedRuntimeKind: requestedRuntimeKind,
            steeringHintsJSON: steeringHintsJSON
        )
        let contractRequest = backendGenerationRequest(for: request)

        await prepareForRequest()
        let launch = try await runtimeControlPlane.generate(request: contractRequest)
        guard launch.resolvedRuntimeKind == .gguf else {
            throw LocalInferenceRoutingError.runtimeUnavailable
        }

        try await runtimeControlPlane.appendStarted(streamHandle: launch.streamHandle)
        try await runtimeControlPlane.appendStatus(
            streamHandle: launch.streamHandle,
            status: "loading_model"
        )
        let output = try await runtime.generate(request: request)
        let summary = await backendSummary(
            from: request,
            launch: launch,
            output: output,
            cancelled: false,
            errorClass: nil
        )
        try await runtimeControlPlane.finishCompleted(
            streamHandle: launch.streamHandle,
            summary: summary
        )
        return output
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
        do {
            let request = try resolvedRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID,
                requestedRuntimeKind: requestedRuntimeKind,
                steeringHintsJSON: steeringHintsJSON
            )
            let contractRequest = backendGenerationRequest(for: request)

            return StreamingBufferPolicy.throwingStream { continuation in
                let task = Task {
                    await self.prepareForRequest()
                    var launch: BackendGenerationLaunch?
                    var output = ""
                    do {
                        let preparedLaunch = try await self.runtimeControlPlane.generate(request: contractRequest)
                        launch = preparedLaunch
                        guard preparedLaunch.resolvedRuntimeKind == .gguf else {
                            throw LocalInferenceRoutingError.runtimeUnavailable
                        }
                        try await self.runtimeControlPlane.appendStarted(streamHandle: preparedLaunch.streamHandle)
                        try await self.runtimeControlPlane.appendStatus(
                            streamHandle: preparedLaunch.streamHandle,
                            status: "loading_model"
                        )

                        let stream = await self.runtime.stream(request: request)
                        for try await chunk in stream {
                            output += chunk
                            try await self.runtimeControlPlane.appendToken(
                                streamHandle: preparedLaunch.streamHandle,
                                text: chunk
                            )
                            continuation.yield(chunk)
                        }

                        let summary = await self.backendSummary(
                            from: request,
                            launch: preparedLaunch,
                            output: output,
                            cancelled: false,
                            errorClass: nil
                        )
                        try await self.runtimeControlPlane.finishCompleted(
                            streamHandle: preparedLaunch.streamHandle,
                            summary: summary
                        )
                        continuation.finish()
                    } catch is CancellationError {
                        if let launch {
                            let summary = await self.backendSummary(
                                from: request,
                                launch: launch,
                                output: output,
                                cancelled: true,
                                errorClass: .cancelled
                            )
                            do {
                                try await self.runtimeControlPlane.finishCancelled(
                                    streamHandle: launch.streamHandle,
                                    summary: summary
                                )
                            } catch {
                                Log.engine.error(
                                    "LocalGGUFClient: failed to mark cancelled stream \(launch.streamHandle, privacy: .public): \(error.localizedDescription, privacy: .public)"
                                )
                            }
                        }
                        continuation.finish(throwing: CancellationError())
                    } catch {
                        if let launch {
                            let mapped = Self.mapBackendError(error)
                            let summary = await self.backendSummary(
                                from: request,
                                launch: launch,
                                output: output,
                                cancelled: false,
                                errorClass: mapped
                            )
                            do {
                                try await self.runtimeControlPlane.finishFailed(
                                    streamHandle: launch.streamHandle,
                                    errorClass: mapped,
                                    message: error.localizedDescription,
                                    summary: summary
                                )
                            } catch {
                                Log.engine.error(
                                    "LocalGGUFClient: failed to mark failed stream \(launch.streamHandle, privacy: .public): \(error.localizedDescription, privacy: .public)"
                                )
                            }
                        }
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        } catch {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        do {
            let modelID = inference.effectiveLocalTextModelID ?? LocalTextModelID.qwen35_35BA3B4Bit.rawValue
            let artifactID = resolvedArtifactID(for: modelID)
            let modelDirectory = resolvedModelDirectory(for: modelID)
            let availability = try await runtime.availability(
                requestedModelID: modelID,
                artifactID: artifactID,
                modelDirectory: modelDirectory
            )
            return ConnectionTestResult(
                success: true,
                message: "Local GGUF ready — \(availability.modelURL.lastPathComponent)"
            )
        } catch {
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    func configSnapshot() -> LLMSnapshot {
        let modelID = inference.effectiveLocalTextModelID
            ?? preferredModelIDForCurrentRuntime()
        return LLMSnapshot(
            provider: .localProvider(runtimeKind: .gguf),
            model: modelID,
            reasoningMode: .fast
        )
    }

    private func resolvedRequest(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        requestedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) throws -> LocalGGUFRequest {
        guard let resolvedModelID = modelID ?? inference.effectiveLocalTextModelID else {
            throw LocalInferenceRoutingError.modelRequired
        }
        if reasoningMode == .fast,
           let resolvedModel = LocalTextModelID(rawValue: resolvedModelID),
           resolvedModel.cannotDisableThinkingInFast {
            throw LocalGGUFRuntimeError.fastModeUnsupported(modelID: resolvedModelID)
        }

        let trimmed = LocalMLXClient.trimForLocalRuntime(
            prompt: prompt,
            systemPrompt: systemPrompt,
            hardware: inference.hardwareCapabilitySnapshot,
            reasoningMode: reasoningMode,
            conditions: inference.localRuntimeConditions
        )

        guard let modelURL = LocalGGUFModelLocator.resolveModelURL(
            modelDirectory: resolvedModelDirectory(for: resolvedModelID),
            modelID: resolvedModelID,
            artifactID: resolvedArtifactID(for: resolvedModelID)
        ) else {
            throw LocalGGUFRuntimeError.modelNotPrepared
        }

        return LocalGGUFRequest(
            modelID: resolvedModelID,
            artifactID: resolvedArtifactID(for: resolvedModelID),
            modelURL: modelURL,
            prompt: trimmed.prompt,
            systemPrompt: trimmed.systemPrompt,
            maxTokens: max(0, maxTokens),
            reasoningMode: reasoningMode,
            steeringHintsJSON: steeringHintsJSON,
            requestedRuntimeKind: requestedRuntimeKind,
            resolvedRuntimeKind: .gguf
        )
    }

    private func resolvedArtifactID(for modelID: String) -> String? {
        preparedGenerationRuntimeConfiguration?.resolvedArtifactID(for: modelID)
    }

    private func preferredModelIDForCurrentRuntime() -> String {
        guard let preferredModel = LocalTextModelID(rawValue: inference.preferredLocalTextModelID),
              preferredModel.runtimeKind == .gguf else {
            return ""
        }
        return preferredModel.rawValue
    }

    private func resolvedModelDirectory(for modelID: String) -> URL? {
        preparedGenerationRuntimeConfiguration?.resolvedModelDirectory(for: modelID)
    }

    private func backendGenerationRequest(for request: LocalGGUFRequest) -> BackendGenerationRequest {
        BackendGenerationRequest(
            requestID: UUID().uuidString,
            requestedRuntimeKind: request.requestedRuntimeKind,
            executionMode: .local,
            modelID: request.modelID,
            artifactID: request.artifactID,
            modelHandleID: nil,
            prompt: request.prompt,
            systemPrompt: request.systemPrompt,
            maxOutputTokens: request.maxTokens,
            temperature: request.reasoningMode == .thinking ? 0.35 : 0.2,
            stopSequences: [],
            toolPolicyRef: nil,
            contextRef: nil,
            reasoningProfile: BackendReasoningProfile(localReasoningMode: request.reasoningMode),
            executionPolicyRef: nil,
            steeringHintsJSON: request.steeringHintsJSON,
            priority: 0,
            timeoutMS: 60_000,
            streamOptions: BackendGenerationStreamOptions()
        )
    }

    private func backendSummary(
        from request: LocalGGUFRequest,
        launch: BackendGenerationLaunch,
        output: String,
        cancelled: Bool,
        errorClass: BackendRuntimeContractError?
    ) async -> BackendGenerationSummary {
        let profile = await runtime.profilingSnapshot()
        if let profile {
            onRunProfileUpdated?(profile)
        }
        let resolvedStats = try? await runtimeControlPlane.stats(target: .stream(launch.streamHandle))
        let outputTokenCount = profile?.outputTokenCount ?? LocalGenerationMetrics.estimatedTokenCount(for: output)
        let fallbackMode = profile?.fallbackMode ?? LocalInferenceSerialFallbackMode.resident.rawValue
        let memoryPressureState =
            fallbackMode == LocalInferenceSerialFallbackMode.ssdStreaming.rawValue
            ? "pressure"
            : "normal"
        return BackendGenerationSummary(
            requestID: launch.requestID,
            requestedRuntimeKind: launch.requestedRuntimeKind,
            resolvedRuntimeKind: launch.resolvedRuntimeKind,
            requestedReasoningProfile: launch.requestedReasoningProfile,
            resolvedReasoningProfile: resolvedStats?.resolvedReasoningProfile ?? launch.resolvedReasoningProfile,
            executionMode: .local,
            modelID: request.modelID,
            artifactID: request.artifactID,
            executionPolicyID: resolvedStats?.executionPolicyID ?? launch.executionPolicyID,
            fallbackMode: fallbackMode,
            timeToFirstTokenMS: profile?.firstTokenLatencyMS,
            totalDurationMS: profile?.totalDurationMS ?? 0,
            tokensPerSecond: profile?.tokensPerSecond,
            outputTokenCount: outputTokenCount,
            outputCharacterCount: profile?.outputCharacterCount ?? output.count,
            memoryPressureState: memoryPressureState,
            executionPhase: profile?.executionPhase ?? "decode",
            maskingState: resolvedStats?.maskingState ?? "dense",
            kvPolicyState: resolvedStats?.kvPolicyState ?? "baseline",
            expertBudgetState: resolvedStats?.expertBudgetState ?? "default",
            adaptationState: resolvedStats?.adaptationState ?? "disabled",
            guardrailState: resolvedStats?.guardrailState ?? "clear",
            sidecarState: resolvedStats?.sidecarState ?? "disabled",
            budgetOutcome: resolvedStats?.budgetOutcome ?? "within_budget",
            planTracePresent: resolvedStats?.planTracePresent ?? true,
            cancelled: cancelled,
            errorClass: errorClass
        )
    }

    private nonisolated static func mapBackendError(_ error: Error) -> BackendRuntimeContractError {
        if error is CancellationError {
            return .cancelled
        }
        if let contractError = error as? BackendRuntimeContractError {
            return contractError
        }
        if let routingError = error as? LocalInferenceRoutingError {
            switch routingError {
            case .modelRequired:
                return .modelNotLoaded
            case .runtimeUnavailable, .fastModeUnsupported:
                return .runtimeUnavailable
            case .modelLoaderUnavailable, .modelLoadStalled:
                return .modelNotLoaded
            }
        }
        if let ggufError = error as? LocalGGUFRuntimeError {
            switch ggufError {
            case .runtimeUnavailable:
                return .runtimeUnavailable
            case .modelNotPrepared:
                return .modelNotFound
            case .backendUnavailable:
                return .backendFailure
            case .fastModeUnsupported:
                return .runtimeUnavailable
            }
        }
        return .backendFailure
    }
}

nonisolated enum LocalGenerationMetrics {
    static func estimatedTokenCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let words = text.split(whereSeparator: \.isWhitespace).count
        let charEstimate = Int(ceil(Double(text.count) / 3.5))
        let wordEstimate = Int(ceil(Double(words) * 1.33))
        return max(charEstimate, wordEstimate)
    }
}
