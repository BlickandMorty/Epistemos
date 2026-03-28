import Foundation
import os

#if canImport(MLX)
@preconcurrency import MLX
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif
#if canImport(MLXLLM)
import MLXLLM
#endif

nonisolated struct LocalMLXRequest: Sendable, Equatable {
    let modelID: String
    let modelDirectory: URL
    let prompt: String
    let systemPrompt: String?
    let maxTokens: Int
    let reasoningMode: LocalReasoningMode

    var resolvedMaxTokens: Int? {
        guard maxTokens > 0 else { return nil }
        let maxAllowed = 12_000
        return min(max(1, maxTokens), maxAllowed)
    }

    var chatTemplateContext: [String: Bool]? {
        guard let model = LocalTextModelID(rawValue: modelID),
              model.supportsThinkingMode else {
            return nil
        }
        return ["enable_thinking": reasoningMode == .thinking]
    }
}

protocol LocalMLXRuntime: Sendable {
    func generate(request: LocalMLXRequest) async throws -> String
    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error>
    func unload() async
}

nonisolated struct LocalMLXRuntimePolicy: Sendable, Equatable {
    let memoryPolicy: LocalMLXMemoryPolicy
    let idleUnloadDelay: Duration
}

nonisolated struct LocalMLXContentBudget: Sendable, Equatable {
    let totalBudget: Int
    let promptBudget: Int
    let systemBudget: Int
}

nonisolated struct LocalMLXMemoryPolicy: Sendable, Equatable {
    let memoryLimitBytes: Int
    let cacheLimitBytes: Int
}

nonisolated struct LocalMLXRunProfile: Sendable, Equatable {
    let modelID: String
    let coldLoad: Bool
    let lowPowerModeEnabled: Bool
    let appActive: Bool
    let thermalState: LocalRuntimeThermalState
    let loadDurationMS: Double
    let firstTokenLatencyMS: Double?
    let totalDurationMS: Double
    let outputCharacterCount: Int
    let chunkCount: Int
    let continuationCount: Int
    let stopReason: String
    let memoryLimitBytes: Int
    let cacheLimitBytes: Int
}

actor LocalMLXRequestGate {
    private var active = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !active {
            active = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            active = false
            return
        }

        let next = waiters.removeFirst()
        next.resume()
    }
}

nonisolated enum LocalMLXRuntimeTuning {
    static func runtimePolicy(
        snapshot: LocalHardwareCapabilitySnapshot,
        conditions: LocalRuntimeConditions
    ) -> LocalMLXRuntimePolicy {
        let memoryPolicy = memoryPolicy(
            snapshot: snapshot,
            conditions: conditions
        )
        var idleUnloadDelay: Duration
        switch snapshot.roundedMemoryGB {
        case ..<16:
            idleUnloadDelay = conditions.lowPowerModeEnabled ? .seconds(1) : .seconds(2)
        case ..<24:
            idleUnloadDelay = conditions.lowPowerModeEnabled ? .seconds(1) : .seconds(3)
        case ..<36:
            idleUnloadDelay = conditions.lowPowerModeEnabled ? .seconds(2) : .seconds(4)
        default:
            idleUnloadDelay = conditions.lowPowerModeEnabled ? .seconds(2) : .seconds(5)
        }

        if !conditions.appActive {
            idleUnloadDelay = .seconds(1)
        } else {
            switch conditions.thermalState {
            case .nominal:
                break
            case .fair:
                idleUnloadDelay = min(idleUnloadDelay, .seconds(2))
            case .serious, .critical:
                idleUnloadDelay = .seconds(1)
            }
        }
        return LocalMLXRuntimePolicy(memoryPolicy: memoryPolicy, idleUnloadDelay: idleUnloadDelay)
    }

    static func memoryPolicy(
        snapshot: LocalHardwareCapabilitySnapshot,
        conditions: LocalRuntimeConditions
    ) -> LocalMLXMemoryPolicy {
        let base: LocalMLXMemoryPolicy
        switch snapshot.roundedMemoryGB {
        case ..<12:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 2_300_000_000, cacheLimitBytes: 40_000_000)
        case ..<16:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 3_000_000_000, cacheLimitBytes: 52_000_000)
        case ..<24:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 4_000_000_000, cacheLimitBytes: 64_000_000)
        case ..<36:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 5_750_000_000, cacheLimitBytes: 96_000_000)
        case ..<64:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 8_000_000_000, cacheLimitBytes: 144_000_000)
        default:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 11_000_000_000, cacheLimitBytes: 224_000_000)
        }

        var memoryLimit = base.memoryLimitBytes
        var cacheLimit = base.cacheLimitBytes

        if conditions.lowPowerModeEnabled {
            memoryLimit = max(1_800_000_000, Int(Double(memoryLimit) * 0.82))
            cacheLimit = max(24_000_000, Int(Double(cacheLimit) * 0.65))
        }

        if !conditions.appActive {
            memoryLimit = max(1_600_000_000, Int(Double(memoryLimit) * 0.78))
            cacheLimit = max(18_000_000, Int(Double(cacheLimit) * 0.60))
        }

        switch conditions.thermalState {
        case .nominal:
            break
        case .fair:
            memoryLimit = max(1_600_000_000, Int(Double(memoryLimit) * 0.92))
            cacheLimit = max(18_000_000, Int(Double(cacheLimit) * 0.85))
        case .serious:
            memoryLimit = max(1_400_000_000, Int(Double(memoryLimit) * 0.74))
            cacheLimit = max(16_000_000, Int(Double(cacheLimit) * 0.55))
        case .critical:
            memoryLimit = max(1_200_000_000, Int(Double(memoryLimit) * 0.58))
            cacheLimit = max(12_000_000, Int(Double(cacheLimit) * 0.40))
        }

        return LocalMLXMemoryPolicy(memoryLimitBytes: memoryLimit, cacheLimitBytes: cacheLimit)
    }

    static func contentBudget(
        snapshot: LocalHardwareCapabilitySnapshot,
        conditions: LocalRuntimeConditions,
        reasoningMode: LocalReasoningMode
    ) -> LocalMLXContentBudget {
        let totalBudget = snapshot.recommendedLocalContentLength(
            for: conditions,
            reasoningMode: reasoningMode
        )

        let maxSystemBudget = snapshot.roundedMemoryGB < 24 ? 1_600 : 2_400
        let systemBudget = min(maxSystemBudget, max(1_200, totalBudget / 5))
        let promptBudget = max(2_000, totalBudget - systemBudget)

        return LocalMLXContentBudget(
            totalBudget: totalBudget,
            promptBudget: promptBudget,
            systemBudget: systemBudget
        )
    }
}

@MainActor
final class LocalMLXClient: LocalConfigurableLLMClient {
    private let runtime: any LocalMLXRuntime
    private let inference: InferenceState
    private let paths: LocalModelPaths
    private let prepareForRequest: @MainActor @Sendable () async -> Void

    init(
        runtime: any LocalMLXRuntime,
        inference: InferenceState,
        paths: LocalModelPaths,
        prepareForRequest: @escaping @MainActor @Sendable () async -> Void = {}
    ) {
        self.runtime = runtime
        self.inference = inference
        self.paths = paths
        self.prepareForRequest = prepareForRequest
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String? = nil
    ) async throws -> String {
        let request = try resolvedRequest(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID
        )
        await prepareForRequest()
        return try await runtime.generate(request: request)
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        do {
            let request = try resolvedRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID
            )
            return AsyncThrowingStream { continuation in
                let task = Task {
                    await self.prepareForRequest()
                    let stream = await self.runtime.stream(request: request)
                    do {
                        for try await chunk in stream {
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        do {
            let output = try await generate(
                prompt: "Reply with exactly: OK",
                systemPrompt: nil,
                maxTokens: 16
            )
            return ConnectionTestResult(success: true, message: "Local MLX ready — \(output.prefix(40))")
        } catch {
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: inference.effectiveLocalTextModelID ?? "",
            reasoningMode: .fast
        )
    }

    private func resolvedRequest(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String? = nil
    ) throws -> LocalMLXRequest {
        guard let modelID = modelID ?? inference.effectiveLocalTextModelID,
              let descriptor = LocalModelCatalog.descriptor(for: modelID) else {
            throw LocalInferenceRoutingError.modelRequired
        }

        let modelDirectory = paths.activeDirectory(for: descriptor)
        guard FileManager.default.fileExists(atPath: modelDirectory.path) else {
            throw LocalInferenceRoutingError.modelRequired
        }

        let trimmed = Self.trimForLocalRuntime(
            prompt: prompt,
            systemPrompt: systemPrompt,
            hardware: inference.hardwareCapabilitySnapshot,
            reasoningMode: reasoningMode,
            conditions: inference.localRuntimeConditions
        )

        return LocalMLXRequest(
            modelID: modelID,
            modelDirectory: modelDirectory,
            prompt: trimmed.prompt,
            systemPrompt: trimmed.systemPrompt,
            maxTokens: max(0, maxTokens),
            reasoningMode: reasoningMode
        )
    }

    nonisolated static func trimForLocalRuntime(
        prompt: String,
        systemPrompt: String?,
        hardware: LocalHardwareCapabilitySnapshot,
        reasoningMode: LocalReasoningMode = .fast,
        conditions: LocalRuntimeConditions = .current()
    ) -> (prompt: String, systemPrompt: String?) {
        let budget = LocalMLXRuntimeTuning.contentBudget(
            snapshot: hardware,
            conditions: conditions,
            reasoningMode: reasoningMode
        )

        let trimmedPrompt: String
        if prompt.count > budget.promptBudget {
            let suffixBudget = min(2_000, budget.promptBudget / 2)
            let prefixBudget = max(0, budget.promptBudget - suffixBudget - 9)
            trimmedPrompt = String(prompt.prefix(prefixBudget)) + "\n\n[...]\n\n" + String(prompt.suffix(suffixBudget))
        } else {
            trimmedPrompt = prompt
        }

        let trimmedSystemPrompt = systemPrompt.map { current in
            current.count > budget.systemBudget ? String(current.prefix(budget.systemBudget)) : current
        }

        return (trimmedPrompt, trimmedSystemPrompt)
    }

    nonisolated static func formattedSystemPrompt(
        _ systemPrompt: String?,
        reasoningMode: LocalReasoningMode
    ) -> String? {
        _ = reasoningMode
        return systemPrompt
    }
}

#if canImport(MLX) && canImport(MLXLMCommon) && canImport(MLXLLM)
actor MLXInferenceService: LocalMLXRuntime {
    private let log = Logger(subsystem: "com.epistemos", category: "MLXInference")
    private let snapshot: LocalHardwareCapabilitySnapshot

    private(set) var container: ModelContainer?
    private var loadedModelID: String?
    private var scheduledUnloadTask: Task<Void, Never>?
    private var lastRunProfile: LocalMLXRunProfile?
    private var runtimeConditions: LocalRuntimeConditions
    private var activeRequestCount = 0
    private let requestGate = LocalMLXRequestGate()

    private struct GenerationExecutionSummary {
        let text: String
        let firstTokenLatencyMS: Double?
        let chunkCount: Int
        let outputCharacterCount: Int
        let continuationCount: Int
        let stopReason: GenerateStopReason
    }

    private struct GenerationPassResult {
        let text: String
        let firstTokenLatencyMS: Double?
        let chunkCount: Int
        let stopReason: GenerateStopReason
    }

    init(snapshot: LocalHardwareCapabilitySnapshot = .current) {
        self.snapshot = snapshot
        self.runtimeConditions = .current()
        let policy = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: runtimeConditions
        )
        Memory.memoryLimit = policy.memoryPolicy.memoryLimitBytes
        Memory.cacheLimit = policy.memoryPolicy.cacheLimitBytes
    }

    func generate(request: LocalMLXRequest) async throws -> String {
        await beginRequest()
        let start = ContinuousClock.now
        let policy = currentRuntimePolicy()
        do {
            let load = try await loadContainerIfNeeded(for: request, policy: policy)
            let parameters = generationParameters(for: request)
            let session = ChatSession(
                load.container,
                instructions: request.systemPrompt,
                generateParameters: parameters,
                additionalContext: additionalContext(for: request)
            )
            let response = try await executeRequest(
                request: request,
                session: session,
                requestStart: start,
                emit: nil
            )
            let profiledStopReason = Self.normalizedStopReason(
                response.stopReason,
                outputCharacterCount: response.outputCharacterCount,
                chunkCount: response.chunkCount
            )
            let totalDurationMS = start.duration(to: ContinuousClock.now).millisecondsValue
            lastRunProfile = LocalMLXRunProfile(
                modelID: request.modelID,
                coldLoad: load.coldLoad,
                lowPowerModeEnabled: runtimeConditions.lowPowerModeEnabled,
                appActive: runtimeConditions.appActive,
                thermalState: runtimeConditions.thermalState,
                loadDurationMS: load.loadDurationMS,
                firstTokenLatencyMS: response.firstTokenLatencyMS,
                totalDurationMS: totalDurationMS,
                outputCharacterCount: response.outputCharacterCount,
                chunkCount: response.chunkCount,
                continuationCount: response.continuationCount,
                stopReason: Self.stopReasonLabel(profiledStopReason),
                memoryLimitBytes: policy.memoryPolicy.memoryLimitBytes,
                cacheLimitBytes: policy.memoryPolicy.cacheLimitBytes
            )
            log.info(
                "Local generate model=\(request.modelID, privacy: .public) cold=\(load.coldLoad) loadMs=\(load.loadDurationMS, privacy: .public) totalMs=\(totalDurationMS, privacy: .public) stop=\(Self.stopReasonLabel(profiledStopReason), privacy: .public) continuations=\(response.continuationCount, privacy: .public) lowPower=\(self.runtimeConditions.lowPowerModeEnabled) appActive=\(self.runtimeConditions.appActive)"
            )
            await endRequest(policy: policy)
            return response.text
        } catch {
            await endRequest(policy: policy)
            throw error
        }
    }

    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error> {
        cancelScheduledUnload()
        return AsyncThrowingStream { continuation in
            let task = Task {
                let policy = await self.beginRequestAndResolvePolicy()
                do {
                    let start = ContinuousClock.now
                    let load = try await self.loadContainerIfNeeded(for: request, policy: policy)
                    let parameters = self.generationParameters(for: request)
                    let session = ChatSession(
                        load.container,
                        instructions: request.systemPrompt,
                        generateParameters: parameters,
                        additionalContext: self.additionalContext(for: request)
                    )
                    let response = try await self.executeRequest(
                        request: request,
                        session: session,
                        requestStart: start
                    ) { chunk in
                        continuation.yield(chunk)
                    }
                    let profiledStopReason = Self.normalizedStopReason(
                        response.stopReason,
                        outputCharacterCount: response.outputCharacterCount,
                        chunkCount: response.chunkCount
                    )
                    let totalDurationMS = start.duration(to: ContinuousClock.now).millisecondsValue
                    self.recordProfile(
                        LocalMLXRunProfile(
                            modelID: request.modelID,
                            coldLoad: load.coldLoad,
                            lowPowerModeEnabled: self.runtimeConditions.lowPowerModeEnabled,
                            appActive: self.runtimeConditions.appActive,
                            thermalState: self.runtimeConditions.thermalState,
                            loadDurationMS: load.loadDurationMS,
                            firstTokenLatencyMS: response.firstTokenLatencyMS,
                            totalDurationMS: totalDurationMS,
                            outputCharacterCount: response.outputCharacterCount,
                            chunkCount: response.chunkCount,
                            continuationCount: response.continuationCount,
                            stopReason: Self.stopReasonLabel(profiledStopReason),
                            memoryLimitBytes: policy.memoryPolicy.memoryLimitBytes,
                            cacheLimitBytes: policy.memoryPolicy.cacheLimitBytes
                        )
                    )
                    self.log.info(
                        "Local stream model=\(request.modelID, privacy: .public) cold=\(load.coldLoad) loadMs=\(load.loadDurationMS, privacy: .public) firstTokenMs=\(response.firstTokenLatencyMS ?? -1, privacy: .public) totalMs=\(totalDurationMS, privacy: .public) chunks=\(response.chunkCount, privacy: .public) stop=\(Self.stopReasonLabel(profiledStopReason), privacy: .public) continuations=\(response.continuationCount, privacy: .public) lowPower=\(self.runtimeConditions.lowPowerModeEnabled) appActive=\(self.runtimeConditions.appActive)"
                    )
                    await self.endRequest(policy: policy)
                    if Task.isCancelled {
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                    if response.stopReason == .cancelled,
                       !Self.shouldTreatCancelledStopAsCompletion(
                           outputCharacterCount: response.outputCharacterCount,
                           chunkCount: response.chunkCount
                       ) {
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                    continuation.finish()
                } catch is CancellationError {
                    await self.endRequest(policy: policy)
                    continuation.finish(throwing: CancellationError())
                } catch {
                    await self.endRequest(policy: policy)
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.enqueueIdleUnload() }
            }
        }
    }

    func unload() async {
        performUnload()
    }

    func updateRuntimeConditions(_ conditions: LocalRuntimeConditions) async {
        runtimeConditions = conditions
        let policy = currentRuntimePolicy()
        Memory.cacheLimit = policy.memoryPolicy.cacheLimitBytes
        Memory.memoryLimit = policy.memoryPolicy.memoryLimitBytes
        if activeRequestCount == 0,
           container != nil,
           (!conditions.appActive || conditions.thermalState == .critical) {
            performUnload()
        }
    }

    private func performUnload() {
        cancelScheduledUnload()
        container = nil
        loadedModelID = nil
        Memory.cacheLimit = 0
        Memory.clearCache()
        let policy = currentRuntimePolicy()
        Memory.cacheLimit = policy.memoryPolicy.cacheLimitBytes
        Memory.memoryLimit = policy.memoryPolicy.memoryLimitBytes
    }

    func profilingSnapshot() -> LocalMLXRunProfile? {
        lastRunProfile
    }

    private func loadContainerIfNeeded(
        for request: LocalMLXRequest,
        policy: LocalMLXRuntimePolicy
    ) async throws -> (container: ModelContainer, coldLoad: Bool, loadDurationMS: Double) {
        cancelScheduledUnload()
        if loadedModelID == request.modelID, let container {
            return (container, false, 0)
        }

        await unload()
        let start = ContinuousClock.now
        Memory.memoryLimit = policy.memoryPolicy.memoryLimitBytes
        Memory.cacheLimit = policy.memoryPolicy.cacheLimitBytes
        Memory.peakMemory = 0

        let configuration = ModelConfiguration(directory: request.modelDirectory)
        let container = try await LLMModelFactory.shared.loadContainer(configuration: configuration)
        loadedModelID = request.modelID
        self.container = container
        log.info("Loaded local MLX model \(request.modelID, privacy: .public)")
        return (container, true, start.duration(to: ContinuousClock.now).millisecondsValue)
    }

    private func cancelScheduledUnload() {
        scheduledUnloadTask?.cancel()
        scheduledUnloadTask = nil
    }

    private func scheduleIdleUnload() {
        cancelScheduledUnload()
        guard activeRequestCount == 0, container != nil else { return }
        let delay = currentRuntimePolicy().idleUnloadDelay
        scheduledUnloadTask = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self.unload()
        }
    }

    private func enqueueIdleUnload() async {
        scheduleIdleUnload()
    }

    private func beginRequest() async {
        await requestGate.acquire()
        cancelScheduledUnload()
        activeRequestCount += 1
    }

    private func beginRequestAndResolvePolicy() async -> LocalMLXRuntimePolicy {
        await beginRequest()
        return currentRuntimePolicy()
    }

    private func endRequest(policy: LocalMLXRuntimePolicy) async {
        activeRequestCount = max(0, activeRequestCount - 1)
        Memory.clearCache()
        Memory.cacheLimit = policy.memoryPolicy.cacheLimitBytes
        scheduleIdleUnload()
        await requestGate.release()
    }

    private func currentRuntimePolicy() -> LocalMLXRuntimePolicy {
        LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: runtimeConditions
        )
    }

    private func recordProfile(_ profile: LocalMLXRunProfile) {
        lastRunProfile = profile
    }

    private func executeRequest(
        request: LocalMLXRequest,
        session: ChatSession,
        requestStart: ContinuousClock.Instant,
        emit: ((String) -> Void)?
    ) async throws -> GenerationExecutionSummary {
        let pass = try await runPass(
            session: session,
            prompt: request.prompt,
            requestStart: requestStart,
            emitChunksImmediately: true,
            emit: emit
        )

        return GenerationExecutionSummary(
            text: pass.text,
            firstTokenLatencyMS: pass.firstTokenLatencyMS,
            chunkCount: pass.chunkCount,
            outputCharacterCount: pass.text.count,
            continuationCount: 0,
            stopReason: pass.stopReason
        )
    }

    private func runPass(
        session: ChatSession,
        prompt: String,
        requestStart: ContinuousClock.Instant,
        emitChunksImmediately: Bool,
        emit: ((String) -> Void)?
    ) async throws -> GenerationPassResult {
        var output = ""
        var firstTokenLatencyMS: Double?
        var chunkCount = 0
        var stopReason: GenerateStopReason = .cancelled

        for try await item in session.streamDetails(
            to: prompt,
            images: [],
            videos: []
        ) {
            if Task.isCancelled {
                throw CancellationError()
            }

            switch item {
            case .chunk(let chunk):
                guard !chunk.isEmpty else { continue }
                output += chunk
                chunkCount += 1
                if firstTokenLatencyMS == nil {
                    firstTokenLatencyMS = requestStart.duration(to: ContinuousClock.now).millisecondsValue
                }
                if emitChunksImmediately {
                    emit?(chunk)
                }

            case .info(let info):
                stopReason = info.stopReason

            case .toolCall:
                continue
            }
        }

        return GenerationPassResult(
            text: output,
            firstTokenLatencyMS: firstTokenLatencyMS,
            chunkCount: chunkCount,
            stopReason: stopReason
        )
    }

    private func generationParameters(for request: LocalMLXRequest) -> GenerateParameters {
        let maxKVSize: Int?
        switch LocalTextModelID(rawValue: request.modelID) {
        case .qwen35_0_8B4Bit?,
             .qwen35_2B4Bit?,
             .smolLM3_3B4Bit?:
            maxKVSize = 4_096
        case .qwen35_4B4Bit?:
            maxKVSize = 3_072
        case .qwen35_9B4Bit?,
             .devstralSmall2505_4Bit?,
             .mistralSmall31_24B4Bit?:
            maxKVSize = 2_048
        default:
            maxKVSize = 1_536
        }

        return GenerateParameters(
            maxTokens: request.resolvedMaxTokens,
            maxKVSize: maxKVSize,
            kvBits: 4,
            kvGroupSize: 64,
            quantizedKVStart: 0,
            temperature: 0.45,
            topP: 0.95,
            prefillStepSize: 256
        )
    }

    private func additionalContext(for request: LocalMLXRequest) -> [String: any Sendable]? {
        request.chatTemplateContext
    }

    nonisolated static func shouldTreatCancelledStopAsCompletion(
        outputCharacterCount: Int,
        chunkCount: Int
    ) -> Bool {
        outputCharacterCount > 0 && chunkCount > 0
    }

    nonisolated static func normalizedStopReason(
        _ stopReason: GenerateStopReason,
        outputCharacterCount: Int,
        chunkCount: Int
    ) -> GenerateStopReason {
        if stopReason == .cancelled,
           shouldTreatCancelledStopAsCompletion(
               outputCharacterCount: outputCharacterCount,
               chunkCount: chunkCount
           ) {
            return .stop
        }
        return stopReason
    }

    private nonisolated static func stopReasonLabel(_ stopReason: GenerateStopReason) -> String {
        switch stopReason {
        case .stop:
            "stop"
        case .length:
            "length"
        case .cancelled:
            "cancelled"
        }
    }
}
#else
actor MLXInferenceService: LocalMLXRuntime {
    private var lastRunProfile: LocalMLXRunProfile?

    init(snapshot: LocalHardwareCapabilitySnapshot = .current) {
        _ = snapshot
    }

    func generate(request: LocalMLXRequest) async throws -> String {
        _ = request
        throw LocalInferenceRoutingError.runtimeUnavailable
    }

    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error> {
        _ = request
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: LocalInferenceRoutingError.runtimeUnavailable)
        }
    }

    func unload() async {}

    func updateRuntimeConditions(_ conditions: LocalRuntimeConditions) async {
        _ = conditions
    }

    func profilingSnapshot() -> LocalMLXRunProfile? {
        lastRunProfile
    }
}
#endif

private extension Duration {
    nonisolated var millisecondsValue: Double {
        let components = components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
