import Darwin
import Darwin.Mach
import Foundation
import os

#if canImport(MLX)
@preconcurrency import MLX
#endif
#if canImport(MLXLMCommon)
@preconcurrency import MLXLMCommon
#endif
#if canImport(MLXLLM)
import MLXLLM
#endif
#if canImport(MLXVLM)
import MLXVLM
#endif

nonisolated struct LocalMLXRequest: Sendable, Equatable {
    let modelID: String
    let modelDirectory: URL
    let prompt: String
    let systemPrompt: String?
    let maxTokens: Int
    let reasoningMode: LocalReasoningMode
    let steeringHintsJSON: String?
    let imageURLs: [URL]

    /// W9.29 — Thermal-aware token budget. Routes through
    /// `ThermalMonitor.currentTokenBudgetMultiplier()` (single source of truth
    /// for the scaling policy; lives at `Epistemos/State/ThermalMonitor.swift`)
    /// so `maxTokens` scales 100→85→50→25 % as the chip transitions
    /// nominal→fair→serious→critical. Returns nil to keep the existing
    /// (max-allowed) ceiling when maxTokens is zero / negative.
    var resolvedMaxTokens: Int? {
        guard maxTokens > 0 else { return nil }
        let maxAllowed = 12_000
        let thermalScale = ThermalMonitor.currentTokenBudgetMultiplier()
        let scaled = max(1, Int(Double(maxTokens) * thermalScale))
        return min(scaled, maxAllowed)
    }

    /// Per-model chat template context for thinking mode activation.
    /// Qwen 3.5/Qwopus: uses "enable_thinking" Jinja variable.
    /// Qwen 3.6 also supports preserved reasoning history through
    /// "preserve_thinking" when thinking mode is enabled.
    /// DeepSeek R1: thinking is always on via its template — no key needed.
    /// Gemma 4: thinking requires specific template setup not in MLX pipeline.
    var chatTemplateContext: [String: Bool]? {
        guard let model = LocalTextModelID(rawValue: modelID) else {
            return nil
        }
        // Qwen-family and Qwopus use the "enable_thinking" Jinja key.
        // IMPORTANT: we must send `enable_thinking: false` in Fast mode
        // for EVERY Qwen model (including ones without
        // `supportsThinkingMode`) because Qwen 3 / 3.5 / 3.6 default
        // templates emit `<think>…</think>` on every turn unless
        // explicitly told not to. The old guard that returned nil for
        // non-thinking-mode-capable models left Qwen 3 4B / Qwen 3
        // Coder / etc. unconditionally thinking even in Fast mode —
        // the user's "all models try to think even when set to Fast"
        // bug lives here.
        switch model {
        case .qwen35_0_8B4Bit, .qwen35_2B4Bit,
             .qwen35_4B4Bit, .qwen35_9B4Bit, .qwen35_27B4Bit, .qwen35_35BA3B4Bit,
             .qwen3_4B4Bit,
             .qwen3CoderNext4Bit, .qwen3Coder30BA3B4Bit,
             .qwen25Coder7B,
             .qwopus27Bv3, .qwopusMoE35BA3B:
            return ["enable_thinking": reasoningMode == .thinking]
        case .qwen36_35BA3B4Bit, .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit:
            return [
                "enable_thinking": reasoningMode == .thinking,
                "preserve_thinking": reasoningMode == .thinking,
            ]
        case .deepseekR1Distill7B:
            // DeepSeek R1 Distill: thinking is its primary mode, always active.
            // The model template handles <think> tags natively — no key needed.
            return nil
        default:
            // Other families: only gate thinking if the model actually
            // supports it; otherwise leave extras empty so we don't
            // send unknown Jinja keys that could break the template.
            guard model.supportsThinkingMode else { return nil }
            return ["enable_thinking": reasoningMode == .thinking]
        }
    }
}

nonisolated enum LocalMLXLoopMitigation {
    static func thinkingLoopFallback(for modelID: String) -> String {
        let name = LocalTextModelID(rawValue: modelID)?.displayName ?? modelID
        return "\(name) thinking mode was stopped because it entered a repetition loop before reaching a usable answer. Retry in Fast mode or use a larger local model for deeper reasoning."
    }

    static func isEnabled(for request: LocalMLXRequest) -> Bool {
        guard request.reasoningMode == .thinking else { return false }
        return LocalTextModelID(rawValue: request.modelID)?
            .requiresThinkingLoopGuard == true
    }

    static func appendFallbackIfNeeded(
        to rawOutput: String,
        for request: LocalMLXRequest
    ) -> String {
        guard isEnabled(for: request) else { return rawOutput }
        let visibleText = UserFacingModelOutput.finalVisibleText(from: rawOutput)
        let needsFallback =
            visibleText.isEmpty
            || hasUnclosedThinkingWithoutAnswer(in: rawOutput)
        guard needsFallback else { return rawOutput }
        return rawOutput + "\n\nFinal answer: " + thinkingLoopFallback(for: request.modelID)
    }

    private static func hasUnclosedThinkingWithoutAnswer(in rawOutput: String) -> Bool {
        guard ThinkingTagSyntax.openingMatch(in: rawOutput) != nil else { return false }
        guard ThinkingTagSyntax.closingMatch(in: rawOutput) == nil else { return false }
        guard ThinkingPreludeSyntax.answerMatch(in: rawOutput) == nil else { return false }
        guard ThinkingPreludeSyntax.answerBoundary(in: rawOutput) == nil else { return false }
        return true
    }
}

nonisolated struct LocalMLXLoopDetection: Sendable, Equatable {
    enum Reason: String, Sendable, Equatable {
        case repeatedChunk
        case repeatedSuffix
    }

    let reason: Reason
}

nonisolated struct LocalMLXLoopGuard: Sendable {
    private static let minimumChunkSignatureLength = 24
    private static let repeatedChunkThreshold = 5
    private static let minimumTrackedTailLength = 640
    private static let trackedTailLimit = 2_048
    private static let trackedSuffixWidth = 160
    private static let repeatedSuffixThreshold = 3
    private static let maxTrackedSuffixes = 48

    private let enabled: Bool
    private var lastChunkSignature: String?
    private var repeatedChunkCount = 0
    private var normalizedTail = ""
    private var suffixCounts: [String: Int] = [:]
    private var suffixOrder: [String] = []

    init(request: LocalMLXRequest) {
        enabled = LocalMLXLoopMitigation.isEnabled(for: request)
    }

    mutating func record(chunk: String) -> LocalMLXLoopDetection? {
        guard enabled else { return nil }

        let signature = Self.normalizedSignature(for: chunk)
        guard !signature.isEmpty else { return nil }

        normalizedTail += signature
        if normalizedTail.count > Self.trackedTailLimit {
            normalizedTail.removeFirst(normalizedTail.count - Self.trackedTailLimit)
        }

        if signature.count >= Self.minimumChunkSignatureLength {
            if signature == lastChunkSignature {
                repeatedChunkCount += 1
            } else {
                lastChunkSignature = signature
                repeatedChunkCount = 1
            }

            if repeatedChunkCount >= Self.repeatedChunkThreshold {
                return LocalMLXLoopDetection(reason: .repeatedChunk)
            }
        } else {
            lastChunkSignature = nil
            repeatedChunkCount = 0
        }

        guard normalizedTail.count >= Self.minimumTrackedTailLength else { return nil }
        let suffix = String(normalizedTail.suffix(Self.trackedSuffixWidth))
        guard suffix.count == Self.trackedSuffixWidth else { return nil }

        let suffixHits = trackSuffix(suffix)
        if suffixHits >= Self.repeatedSuffixThreshold {
            return LocalMLXLoopDetection(reason: .repeatedSuffix)
        }

        return nil
    }

    private mutating func trackSuffix(_ suffix: String) -> Int {
        let count = (suffixCounts[suffix] ?? 0) + 1
        suffixCounts[suffix] = count
        suffixOrder.append(suffix)

        if suffixOrder.count > Self.maxTrackedSuffixes {
            let evicted = suffixOrder.removeFirst()
            if let existing = suffixCounts[evicted] {
                if existing <= 1 {
                    suffixCounts.removeValue(forKey: evicted)
                } else {
                    suffixCounts[evicted] = existing - 1
                }
            }
        }

        return count
    }

    private static func normalizedSignature(for value: String) -> String {
        value
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

protocol LocalMLXRuntime: Sendable {
    func generate(request: LocalMLXRequest) async throws -> String
    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error>
    func profilingSnapshot() async -> LocalMLXRunProfile?
    func unload() async
}

nonisolated struct LocalMLXRuntimePolicy: Sendable, Equatable {
    let memoryPolicy: LocalMLXMemoryPolicy
    let idleMemoryPolicy: LocalMLXMemoryPolicy
    let idleUnloadDelay: Duration
    let idleUnloadMode: LocalMLXIdleUnloadMode
}

nonisolated enum LocalMLXIdleUnloadMode: Sendable, Equatable {
    case workingSetOnly
    case deep
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
    let artifactID: String?
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind
    let executionMode: BackendExecutionMode
    let coldLoad: Bool
    let lowPowerModeEnabled: Bool
    let appActive: Bool
    let thermalState: LocalRuntimeThermalState
    let loadDurationMS: Double
    let firstTokenLatencyMS: Double?
    let totalDurationMS: Double
    let outputTokenCount: Int
    let tokensPerSecond: Double?
    let outputCharacterCount: Int
    let chunkCount: Int
    let continuationCount: Int
    let stopReason: String
    let memoryLimitBytes: Int
    let cacheLimitBytes: Int
    let serialPhase: String
    let fallbackMode: String
    let availableMemoryBytes: UInt64
}

actor LocalMLXRequestGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    private var active = false
    private var waiters: [Waiter] = []

    func acquire() async {
        if !active {
            active = true
            return
        }

        let waiterID = UUID()
        let acquired = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: false)
                    return
                }
                waiters.append(Waiter(id: waiterID, continuation: continuation))
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: waiterID)
            }
        }

        guard acquired else { return }
        if Task.isCancelled {
            release()
        }
    }

    func release() {
        if waiters.isEmpty {
            active = false
            return
        }

        let next = waiters.removeFirst()
        next.continuation.resume(returning: true)
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(returning: false)
    }
}

nonisolated enum LocalMLXRuntimeTuning {
    static func runtimePolicy(
        snapshot: LocalHardwareCapabilitySnapshot,
        conditions: LocalRuntimeConditions,
        idleMemoryMode: IdleMemoryMode = .keepWarm
    ) -> LocalMLXRuntimePolicy {
        let memoryPolicy = memoryPolicy(
            snapshot: snapshot,
            conditions: conditions
        )
        let idleMemoryPolicy = idleResidentMemoryPolicy(
            activeMemoryPolicy: memoryPolicy,
            snapshot: snapshot,
            conditions: conditions
        )
        // Idle unload delay: how long after the last inference request
        // we hold the model in memory speculating that another request
        // is imminent. Holding for too long burns 2-4 GB of resident
        // memory on the user's machine; unloading too eagerly forces
        // a cold reload (~2 s) on the next chat turn.
        //
        // Aggressive 2026-04 tuning (per perf sprint): the prior
        // 6-30 s ceiling was too generous on the dominant 16-24 GB
        // Apple Silicon laptop tier. Cutting roughly in half keeps
        // the back-to-back-turn warm-cache pattern (under 4 s) but
        // returns multi-GB to the OS when the user pauses to think
        // or switches back to writing.
        var idleUnloadDelay: Duration
        var idleUnloadMode: LocalMLXIdleUnloadMode = .workingSetOnly
        switch snapshot.roundedMemoryGB {
        case ..<16:
            idleUnloadDelay = conditions.lowPowerModeEnabled ? .seconds(2) : .seconds(4)
        case ..<24:
            idleUnloadDelay = conditions.lowPowerModeEnabled ? .seconds(3) : .seconds(6)
        case ..<36:
            idleUnloadDelay = conditions.lowPowerModeEnabled ? .seconds(5) : .seconds(10)
        default:
            idleUnloadDelay = conditions.lowPowerModeEnabled ? .seconds(7) : .seconds(15)
        }

        if !conditions.appActive {
            idleUnloadDelay = min(idleUnloadDelay, .seconds(3))
        } else {
            switch conditions.thermalState {
            case .nominal:
                break
            case .fair:
                idleUnloadDelay = min(idleUnloadDelay, .seconds(5))
            case .serious:
                idleUnloadDelay = min(idleUnloadDelay, .seconds(2))
            case .critical:
                idleUnloadDelay = .seconds(1)
            }
        }
        if idleMemoryMode == .lowMemory, conditions.thermalState != .critical {
            idleUnloadDelay = .seconds(30)
            idleUnloadMode = .deep
        } else if conditions.thermalState == .critical {
            idleUnloadMode = .deep
        }
        return LocalMLXRuntimePolicy(
            memoryPolicy: memoryPolicy,
            idleMemoryPolicy: idleMemoryPolicy,
            idleUnloadDelay: idleUnloadDelay,
            idleUnloadMode: idleUnloadMode
        )
    }

    /// Hard ceiling on Metal intermediate tensor cache (4GB).
    /// Prevents unbounded cache growth during long Qwen 27B sessions
    /// that would otherwise thrash NVMe via unified memory page-out.
    private static let metalCacheCeiling = 4 * 1024 * 1024 * 1024 // 4 GiB

    static func memoryPolicy(
        snapshot: LocalHardwareCapabilitySnapshot,
        conditions: LocalRuntimeConditions
    ) -> LocalMLXMemoryPolicy {
        // Cache limits sized to hold intermediate tensor working set for the model tier,
        // capped at metalCacheCeiling. Previous 40-224MB values caused constant alloc/free
        // churn during 27B inference — matmul intermediates were evicted and reallocated
        // every op, eventually pushing the footprint into NVMe page-out.
        let base: LocalMLXMemoryPolicy
        switch snapshot.roundedMemoryGB {
        case ..<12:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 2_300_000_000, cacheLimitBytes: 256_000_000)
        case ..<16:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 3_000_000_000, cacheLimitBytes: 512_000_000)
        case ..<24:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 4_000_000_000, cacheLimitBytes: 1_024_000_000)
        case ..<36:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 5_750_000_000, cacheLimitBytes: 2_048_000_000)
        case ..<64:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 8_000_000_000, cacheLimitBytes: 3_072_000_000)
        default:
            base = LocalMLXMemoryPolicy(memoryLimitBytes: 11_000_000_000, cacheLimitBytes: 4_096_000_000)
        }

        var memoryLimit = base.memoryLimitBytes
        var cacheLimit = base.cacheLimitBytes

        if conditions.lowPowerModeEnabled {
            memoryLimit = max(1_800_000_000, Int(Double(memoryLimit) * 0.82))
            cacheLimit = max(128_000_000, Int(Double(cacheLimit) * 0.65))
        }

        if !conditions.appActive {
            memoryLimit = max(1_600_000_000, Int(Double(memoryLimit) * 0.78))
            cacheLimit = max(96_000_000, Int(Double(cacheLimit) * 0.60))
        }

        switch conditions.thermalState {
        case .nominal:
            break
        case .fair:
            memoryLimit = max(1_600_000_000, Int(Double(memoryLimit) * 0.92))
            cacheLimit = max(96_000_000, Int(Double(cacheLimit) * 0.85))
        case .serious:
            memoryLimit = max(1_400_000_000, Int(Double(memoryLimit) * 0.74))
            cacheLimit = max(64_000_000, Int(Double(cacheLimit) * 0.55))
        case .critical:
            memoryLimit = max(1_200_000_000, Int(Double(memoryLimit) * 0.58))
            cacheLimit = max(48_000_000, Int(Double(cacheLimit) * 0.40))
        }

        // Enforce hard ceiling: never exceed 4GB regardless of hardware tier.
        cacheLimit = min(cacheLimit, metalCacheCeiling)

        return LocalMLXMemoryPolicy(memoryLimitBytes: memoryLimit, cacheLimitBytes: cacheLimit)
    }

    static func idleResidentMemoryPolicy(
        activeMemoryPolicy: LocalMLXMemoryPolicy,
        snapshot: LocalHardwareCapabilitySnapshot,
        conditions: LocalRuntimeConditions
    ) -> LocalMLXMemoryPolicy {
        var memoryLimit = max(900_000_000, Int(Double(activeMemoryPolicy.memoryLimitBytes) * 0.52))
        var cacheLimit = max(32_000_000, Int(Double(activeMemoryPolicy.cacheLimitBytes) * 0.10))

        let cacheCeiling: Int
        switch snapshot.roundedMemoryGB {
        case ..<12:
            cacheCeiling = 48_000_000
        case ..<16:
            cacheCeiling = 64_000_000
        case ..<24:
            cacheCeiling = 128_000_000
        case ..<36:
            cacheCeiling = 160_000_000
        case ..<64:
            cacheCeiling = 192_000_000
        default:
            cacheCeiling = 256_000_000
        }
        cacheLimit = min(cacheLimit, cacheCeiling)

        if !conditions.appActive {
            memoryLimit = max(768_000_000, Int(Double(memoryLimit) * 0.85))
            cacheLimit = max(16_000_000, Int(Double(cacheLimit) * 0.50))
        }

        switch conditions.thermalState {
        case .nominal:
            break
        case .fair:
            memoryLimit = max(768_000_000, Int(Double(memoryLimit) * 0.92))
            cacheLimit = max(24_000_000, Int(Double(cacheLimit) * 0.85))
        case .serious:
            memoryLimit = max(700_000_000, Int(Double(memoryLimit) * 0.74))
            cacheLimit = max(16_000_000, Int(Double(cacheLimit) * 0.60))
        case .critical:
            memoryLimit = max(600_000_000, Int(Double(memoryLimit) * 0.58))
            cacheLimit = max(16_000_000, Int(Double(cacheLimit) * 0.40))
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
final class LocalMLXClient: RoutedLocalRuntimeClient {
    private let runtime: any LocalMLXRuntime
    private let inference: InferenceState
    private let paths: LocalModelPaths
    private let runtimeControlPlane: BackendRuntimeControlPlane
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder?
    private let prepareForRequest: @MainActor @Sendable () async -> Void
    private var preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration?
    private var generateToolSequence: UInt64 = 0
    private var streamToolSequence: UInt64 = 0

    init(
        runtime: any LocalMLXRuntime,
        inference: InferenceState,
        paths: LocalModelPaths,
        runtimeControlPlane: BackendRuntimeControlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(availableRuntimeKinds: [.mlx])
        ),
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil,
        prepareForRequest: @escaping @MainActor @Sendable () async -> Void = {}
    ) {
        self.runtime = runtime
        self.inference = inference
        self.paths = paths
        self.runtimeControlPlane = runtimeControlPlane
        self.agentProvenanceRecorder = agentProvenanceRecorder
        self.prepareForRequest = prepareForRequest
    }

    func configurePreparedGenerationRuntime(_ configuration: PreparedGenerationRuntimeConfiguration?) {
        preparedGenerationRuntimeConfiguration = configuration
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            requestedRuntimeKind: nil,
            steeringHintsJSON: nil
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String? = nil
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
        modelID: String? = nil,
        requestedRuntimeKind: BackendRuntimeKind?,
        steeringHintsJSON: String?
    ) async throws -> String {
        let request = try resolvedRequest(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID,
            steeringHintsJSON: steeringHintsJSON
        )
        let contractRequest = backendGenerationRequest(
            for: request,
            requestedRuntimeKind: requestedRuntimeKind
        )
        let provenance = makeGenerateProvenanceContext(
            for: request,
            requestedRuntimeKind: requestedRuntimeKind
        )
        let lifecycleStart = DispatchTime.now()
        var launch: BackendGenerationLaunch?

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

        do {
            await prepareForRequest()
            let preparedLaunch = try await runtimeControlPlane.generate(request: contractRequest)
            launch = preparedLaunch
            guard preparedLaunch.resolvedRuntimeKind == .mlx else {
                throw LocalInferenceRoutingError.runtimeUnavailable
            }

            try await runtimeControlPlane.appendStarted(streamHandle: preparedLaunch.streamHandle)
            try await runtimeControlPlane.appendStatus(
                streamHandle: preparedLaunch.streamHandle,
                status: "loading_model"
            )
            let output = try await runtime.generate(request: request)
            try await runtimeControlPlane.appendToken(streamHandle: preparedLaunch.streamHandle, text: output)
            let summary = await backendSummary(
                from: request,
                launch: preparedLaunch,
                output: output,
                cancelled: false,
                errorClass: nil
            )
            try await runtimeControlPlane.finishCompleted(
                streamHandle: preparedLaunch.streamHandle,
                summary: summary
            )
            let elapsedMs = Self.localMLXDurationMilliseconds(since: lifecycleStart)
            recordGenerateAgentEvent(
                provenance,
                kind: .toolCallCompleted,
                resultJSON: Self.localMLXGenerateResultJSON(
                    success: true,
                    elapsedMs: elapsedMs,
                    outputCharacterCount: output.count
                ),
                durationMs: elapsedMs,
                status: .completed
            )
            return output
        } catch is CancellationError {
            let elapsedMs = Self.localMLXDurationMilliseconds(since: lifecycleStart)
            var failedMetadata = provenance.metadata
            failedMetadata["failure_class"] = BackendRuntimeContractError.cancelled.rawValue
            recordGenerateAgentEvent(
                provenance,
                kind: .toolCallFailed,
                resultJSON: Self.localMLXGenerateResultJSON(
                    success: false,
                    elapsedMs: elapsedMs
                ),
                durationMs: elapsedMs,
                status: .failed,
                errorMessage: BackendRuntimeContractError.cancelled.rawValue,
                metadata: failedMetadata
            )
            if let launch {
                let summary = await backendSummary(
                    from: request,
                    launch: launch,
                    output: nil,
                    cancelled: true,
                    errorClass: .cancelled
                )
                do {
                    try await runtimeControlPlane.finishCancelled(
                        streamHandle: launch.streamHandle,
                        summary: summary
                    )
                } catch {
                    Log.engine.error(
                        "MLXInferenceService: failed to mark cancelled stream \(launch.streamHandle, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
            throw CancellationError()
        } catch {
            let elapsedMs = Self.localMLXDurationMilliseconds(since: lifecycleStart)
            let failureClass = Self.mapBackendError(error)
            var failedMetadata = provenance.metadata
            failedMetadata["failure_class"] = failureClass.rawValue
            recordGenerateAgentEvent(
                provenance,
                kind: .toolCallFailed,
                resultJSON: Self.localMLXGenerateResultJSON(
                    success: false,
                    elapsedMs: elapsedMs
                ),
                durationMs: elapsedMs,
                status: .failed,
                errorMessage: failureClass.rawValue,
                metadata: failedMetadata
            )
            if let launch {
                let summary = await backendSummary(
                    from: request,
                    launch: launch,
                    output: nil,
                    cancelled: false,
                    errorClass: failureClass
                )
                do {
                    try await runtimeControlPlane.finishFailed(
                        streamHandle: launch.streamHandle,
                        errorClass: failureClass,
                        message: failureClass.rawValue,
                        summary: summary
                    )
                } catch {
                    Log.engine.error(
                        "MLXInferenceService: failed to mark failed stream \(launch.streamHandle, privacy: .public)"
                    )
                }
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
            requestedRuntimeKind: nil,
            steeringHintsJSON: nil
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String? = nil
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
        modelID: String? = nil,
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
                steeringHintsJSON: steeringHintsJSON
            )
            let contractRequest = backendGenerationRequest(
                for: request,
                requestedRuntimeKind: requestedRuntimeKind
            )
            let provenance = makeStreamProvenanceContext(
                for: request,
                requestedRuntimeKind: requestedRuntimeKind
            )
            return StreamingBufferPolicy.throwingStream { continuation in
                let task = Task.detached(priority: .userInitiated) {
                    let lifecycleStart = DispatchTime.now()
                    var launch: BackendGenerationLaunch?
                    var output = ""
                    var chunkCount = 0
                    await self.recordStreamAgentEvent(
                        provenance,
                        kind: .toolCallRequested,
                        status: .requested
                    )
                    await self.recordStreamAgentEvent(
                        provenance,
                        kind: .toolCallStarted,
                        status: .started
                    )
                    do {
                        await self.prepareForRequest()
                        let preparedLaunch = try await self.runtimeControlPlane.generate(request: contractRequest)
                        launch = preparedLaunch
                        guard preparedLaunch.resolvedRuntimeKind == .mlx else {
                            throw LocalInferenceRoutingError.runtimeUnavailable
                        }
                        try await self.runtimeControlPlane.appendStarted(streamHandle: preparedLaunch.streamHandle)
                        try await self.runtimeControlPlane.appendStatus(
                            streamHandle: preparedLaunch.streamHandle,
                            status: "loading_model"
                        )
                        let stream = await self.runtime.stream(request: request)
                        for try await chunk in stream {
                            chunkCount += 1
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
                        let elapsedMs = Self.localMLXDurationMilliseconds(since: lifecycleStart)
                        await self.recordStreamAgentEvent(
                            provenance,
                            kind: .toolCallCompleted,
                            resultJSON: Self.localMLXStreamResultJSON(
                                success: true,
                                elapsedMs: elapsedMs,
                                outputCharacterCount: output.count,
                                chunkCount: chunkCount
                            ),
                            durationMs: elapsedMs,
                            status: .completed
                        )
                        continuation.finish()
                    } catch is CancellationError {
                        let elapsedMs = Self.localMLXDurationMilliseconds(since: lifecycleStart)
                        var failedMetadata = provenance.metadata
                        failedMetadata["failure_class"] = BackendRuntimeContractError.cancelled.rawValue
                        await self.recordStreamAgentEvent(
                            provenance,
                            kind: .toolCallFailed,
                            resultJSON: Self.localMLXStreamResultJSON(
                                success: false,
                                elapsedMs: elapsedMs,
                                outputCharacterCount: output.count,
                                chunkCount: chunkCount
                            ),
                            durationMs: elapsedMs,
                            status: .failed,
                            errorMessage: BackendRuntimeContractError.cancelled.rawValue,
                            metadata: failedMetadata
                        )
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
                                    "MLXInferenceService: failed to mark cancelled stream \(launch.streamHandle, privacy: .public): \(error.localizedDescription, privacy: .public)"
                                )
                            }
                        }
                        continuation.finish(throwing: CancellationError())
                    } catch {
                        let elapsedMs = Self.localMLXDurationMilliseconds(since: lifecycleStart)
                        let mapped = Self.mapBackendError(error)
                        var failedMetadata = provenance.metadata
                        failedMetadata["failure_class"] = mapped.rawValue
                        await self.recordStreamAgentEvent(
                            provenance,
                            kind: .toolCallFailed,
                            resultJSON: Self.localMLXStreamResultJSON(
                                success: false,
                                elapsedMs: elapsedMs,
                                outputCharacterCount: output.count,
                                chunkCount: chunkCount
                            ),
                            durationMs: elapsedMs,
                            status: .failed,
                            errorMessage: mapped.rawValue,
                            metadata: failedMetadata
                        )
                        if let launch {
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
                                    message: mapped.rawValue,
                                    summary: summary
                                )
                            } catch {
                                Log.engine.error(
                                    "MLXInferenceService: failed to mark failed stream \(launch.streamHandle, privacy: .public)"
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
            provider: .localProvider(runtimeKind: .mlx),
            model: inference.effectiveLocalTextModelID ?? "",
            reasoningMode: .fast
        )
    }

    private func resolvedRequest(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String? = nil,
        steeringHintsJSON: String? = nil,
        imageURLs: [URL] = []
    ) throws -> LocalMLXRequest {
        guard let modelID = modelID ?? inference.effectiveLocalTextModelID,
              let resolvedModel = LocalTextModelID(rawValue: modelID) else {
            throw LocalInferenceRoutingError.modelRequired
        }
        guard resolvedModel.runtimeKind == .mlx else {
            throw LocalInferenceRoutingError.runtimeUnavailable
        }
        if reasoningMode == .fast, resolvedModel.cannotDisableThinkingInFast {
            throw LocalInferenceRoutingError.fastModeUnsupported(modelID: modelID)
        }
        guard let descriptor = LocalModelCatalog.descriptor(for: modelID) else {
            throw LocalInferenceRoutingError.modelRequired
        }

        guard let modelDirectory = resolvedModelDirectory(for: descriptor, modelID: modelID) else {
            throw LocalInferenceRoutingError.modelRequired
        }

        let trimmed = Self.trimForLocalRuntime(
            prompt: prompt,
            systemPrompt: systemPrompt,
            hardware: inference.hardwareCapabilitySnapshot,
            reasoningMode: reasoningMode,
            conditions: inference.localRuntimeConditions
        )

        // Use explicitly passed imageURLs, or fall back to ambient pending images
        let resolvedImages: [URL]
        if !imageURLs.isEmpty {
            resolvedImages = imageURLs
        } else if let model = LocalTextModelID(rawValue: modelID), model.supportsVision {
            resolvedImages = inference.pendingImageURLs
        } else {
            resolvedImages = []
        }

        return LocalMLXRequest(
            modelID: modelID,
            modelDirectory: modelDirectory,
            prompt: trimmed.prompt,
            systemPrompt: trimmed.systemPrompt,
            maxTokens: max(0, maxTokens),
            reasoningMode: reasoningMode,
            steeringHintsJSON: steeringHintsJSON,
            imageURLs: resolvedImages
        )
    }

    private func resolvedModelDirectory(
        for descriptor: LocalModelDescriptor,
        modelID: String
    ) -> URL? {
        if let preparedDirectory = preparedGenerationRuntimeConfiguration?.resolvedModelDirectory(for: modelID),
           FileManager.default.fileExists(atPath: preparedDirectory.path) {
            return preparedDirectory
        }

        let installedDirectory = paths.activeDirectory(for: descriptor)
        if FileManager.default.fileExists(atPath: installedDirectory.path) {
            return installedDirectory
        }

        return paths.usableHubSnapshotDirectory(for: descriptor)
    }

    private func resolvedArtifactID(for modelID: String) -> String? {
        preparedGenerationRuntimeConfiguration?.resolvedArtifactID(for: modelID)
    }

    private func backendGenerationRequest(
        for request: LocalMLXRequest,
        requestedRuntimeKind: BackendRuntimeKind?
    ) -> BackendGenerationRequest {
        BackendGenerationRequest(
            requestID: UUID().uuidString,
            requestedRuntimeKind: requestedRuntimeKind,
            executionMode: .local,
            modelID: request.modelID,
            artifactID: resolvedArtifactID(for: request.modelID),
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
            timeoutMS: BackendRuntimeTimeouts.localGenerationMS,
            streamOptions: BackendGenerationStreamOptions()
        )
    }

    private enum LocalMLXProvenanceSurface {
        case generate
        case stream

        nonisolated var runIDPrefix: String {
            switch self {
            case .generate: return "local-mlx-generate-"
            case .stream: return "local-mlx-stream-"
            }
        }

        nonisolated var toolCallPrefix: String {
            switch self {
            case .generate: return "local-mlx-generate"
            case .stream: return "local-mlx-stream"
            }
        }

        nonisolated var toolName: String {
            switch self {
            case .generate: return "local_generate.mlx"
            case .stream: return "local_stream.mlx"
            }
        }

        nonisolated var metadataValue: String {
            switch self {
            case .generate: return "generate"
            case .stream: return "stream"
            }
        }
    }

    private struct LocalMLXProvenanceContext: Sendable {
        let runID: String
        let toolCallID: String
        let toolName: String
        let actor: AgentProvenanceActor
        let argumentsJSON: String
        let metadata: [String: String]
    }

    private func makeGenerateProvenanceContext(
        for request: LocalMLXRequest,
        requestedRuntimeKind: BackendRuntimeKind?
    ) -> LocalMLXProvenanceContext {
        makeProvenanceContext(
            for: request,
            requestedRuntimeKind: requestedRuntimeKind,
            surface: .generate
        )
    }

    private func makeStreamProvenanceContext(
        for request: LocalMLXRequest,
        requestedRuntimeKind: BackendRuntimeKind?
    ) -> LocalMLXProvenanceContext {
        makeProvenanceContext(
            for: request,
            requestedRuntimeKind: requestedRuntimeKind,
            surface: .stream
        )
    }

    private func makeProvenanceContext(
        for request: LocalMLXRequest,
        requestedRuntimeKind: BackendRuntimeKind?,
        surface: LocalMLXProvenanceSurface
    ) -> LocalMLXProvenanceContext {
        LocalMLXProvenanceContext(
            runID: "\(surface.runIDPrefix)\(UUID().uuidString.uppercased())",
            toolCallID: nextToolCallID(for: surface),
            toolName: surface.toolName,
            actor: .agent(id: "local-mlx-client", modelID: nil),
            argumentsJSON: Self.localMLXArgumentsJSON(
                for: request,
                requestedRuntimeKind: requestedRuntimeKind,
                surface: surface
            ),
            metadata: Self.localMLXMetadata(
                for: request,
                requestedRuntimeKind: requestedRuntimeKind,
                surface: surface
            )
        )
    }

    private func nextToolCallID(for surface: LocalMLXProvenanceSurface) -> String {
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
        _ context: LocalMLXProvenanceContext,
        kind: AgentProvenanceEventKind,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]? = nil
    ) {
        recordLocalMLXAgentEvent(
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
        _ context: LocalMLXProvenanceContext,
        kind: AgentProvenanceEventKind,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]? = nil
    ) {
        recordLocalMLXAgentEvent(
            context,
            kind: kind,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private func recordLocalMLXAgentEvent(
        _ context: LocalMLXProvenanceContext,
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

    private nonisolated static func localMLXArgumentsJSON(
        for request: LocalMLXRequest,
        requestedRuntimeKind: BackendRuntimeKind?,
        surface: LocalMLXProvenanceSurface
    ) -> String {
        localMLXJSON([
            "max_tokens": request.maxTokens,
            "prompt_char_count": request.prompt.count,
            "provider": "local_mlx",
            "reasoning_mode": request.reasoningMode.rawValue,
            "requested_runtime": requestedRuntimeKind?.rawValue ?? "none",
            "resolved_runtime": BackendRuntimeKind.mlx.rawValue,
            "steering_hints_present": hasSteeringHints(request.steeringHintsJSON),
            "surface": surface.metadataValue,
            "system_prompt_char_count": request.systemPrompt?.count ?? 0,
        ])
    }

    private nonisolated static func localMLXMetadata(
        for request: LocalMLXRequest,
        requestedRuntimeKind: BackendRuntimeKind?,
        surface: LocalMLXProvenanceSurface
    ) -> [String: String] {
        [
            "max_tokens": "\(request.maxTokens)",
            "prompt_char_count": "\(request.prompt.count)",
            "provider": "local_mlx",
            "reasoning_mode": request.reasoningMode.rawValue,
            "requested_runtime": requestedRuntimeKind?.rawValue ?? "none",
            "resolved_runtime": BackendRuntimeKind.mlx.rawValue,
            "source": "local_mlx_client",
            "steering_hints_present": "\(hasSteeringHints(request.steeringHintsJSON))",
            "surface": surface.metadataValue,
            "system_prompt_char_count": "\(request.systemPrompt?.count ?? 0)",
        ]
    }

    private nonisolated static func localMLXGenerateResultJSON(
        success: Bool,
        elapsedMs: UInt64,
        outputCharacterCount: Int? = nil
    ) -> String {
        localMLXResultJSON(
            success: success,
            elapsedMs: elapsedMs,
            outputCharacterCount: outputCharacterCount,
            chunkCount: nil
        )
    }

    private nonisolated static func localMLXStreamResultJSON(
        success: Bool,
        elapsedMs: UInt64,
        outputCharacterCount: Int,
        chunkCount: Int
    ) -> String {
        localMLXResultJSON(
            success: success,
            elapsedMs: elapsedMs,
            outputCharacterCount: outputCharacterCount,
            chunkCount: chunkCount
        )
    }

    private nonisolated static func localMLXResultJSON(
        success: Bool,
        elapsedMs: UInt64,
        outputCharacterCount: Int?,
        chunkCount: Int?
    ) -> String {
        var payload: [String: Any] = [
            "elapsed_ms": elapsedMs,
            "success": success,
        ]
        if let outputCharacterCount {
            payload["output_char_count"] = outputCharacterCount
        }
        if let chunkCount {
            payload["chunk_count"] = chunkCount
        }
        return localMLXJSON(payload)
    }

    private nonisolated static func localMLXJSON(_ payload: [String: Any]) -> String {
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

    private nonisolated static func localMLXDurationMilliseconds(since start: DispatchTime) -> UInt64 {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now >= start.uptimeNanoseconds else { return 0 }
        let elapsedNanoseconds = now - start.uptimeNanoseconds
        return elapsedNanoseconds / 1_000_000
    }

    private func backendSummary(
        from request: LocalMLXRequest,
        launch: BackendGenerationLaunch,
        output: String?,
        cancelled: Bool,
        errorClass: BackendRuntimeContractError?
    ) async -> BackendGenerationSummary {
        let profile = await runtime.profilingSnapshot()
        let resolvedStats = try? await runtimeControlPlane.stats(target: .stream(launch.streamHandle))
        let resolvedOutput = output ?? ""
        let outputTokenCount = profile?.outputTokenCount ?? Self.estimatedTokenCount(for: resolvedOutput)
        let totalDurationMS = profile?.totalDurationMS ?? 0
        let tokensPerSecond =
            profile?.tokensPerSecond
            ?? (totalDurationMS > 0 && outputTokenCount > 0
                ? Double(outputTokenCount) / (totalDurationMS / 1_000)
                : nil)
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
            artifactID: resolvedArtifactID(for: request.modelID),
            executionPolicyID: resolvedStats?.executionPolicyID ?? launch.executionPolicyID,
            fallbackMode: fallbackMode,
            timeToFirstTokenMS: profile?.firstTokenLatencyMS,
            totalDurationMS: totalDurationMS,
            tokensPerSecond: tokensPerSecond,
            outputTokenCount: outputTokenCount,
            outputCharacterCount: profile?.outputCharacterCount ?? resolvedOutput.count,
            memoryPressureState: memoryPressureState,
            executionPhase: profile?.serialPhase ?? "unknown",
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
            case .modelLoaderUnavailable, .modelLoadStalled, .insufficientMemory:
                return .modelNotLoaded
            }
        }
        return .backendFailure
    }

    private nonisolated static func estimatedTokenCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let words = text.split(whereSeparator: \.isWhitespace).count
        let charEstimate = Int(ceil(Double(text.count) / 3.5))
        let wordEstimate = Int(ceil(Double(words) * 1.33))
        return max(charEstimate, wordEstimate)
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
    private let serialController: LocalInferenceSerialController
    private var metalRuntimeManager: MetalRuntimeManager?
    private(set) var container: ModelContainer?
    private var loadedModelID: String?
    private var scheduledUnloadTask: Task<Void, Never>?
    private var lastRunProfile: LocalMLXRunProfile?
    private var runtimeConditions: LocalRuntimeConditions
    private var activeRequestCount = 0
    private let requestGate = LocalMLXRequestGate()
    private var preparedCustomSSMRuntimeKey: String?
    private var lastSerialSnapshot: LocalInferenceSerialSnapshot?
    /// Dispatch source that fires when macOS reports unified-memory pressure.
    /// We install it lazily on first use so the service can be constructed
    /// cheaply during bootstrap without touching dispatch state.
    private nonisolated(unsafe) var memoryPressureSource: DispatchSourceMemoryPressure?
    private var memoryPressureListenerInstalled = false

    /// SSM state persistence service — set by AppBootstrap after initialization.
    private var ssmStateService: SSMStateService?

    /// Active session ID for state scoping — set by ChatCoordinator before generation.
    var activeSessionID: String?

    /// Active vault root URL for staleness detection during SSM state resume.
    var activeVaultRoot: URL?

    /// Callback invoked when an SSM state file is saved, so callers
    /// (e.g. ChatCoordinator) can bind the path to ConversationPersistence.
    var onSSMStateSaved: (@Sendable (_ sessionID: String, _ statePath: String) -> Void)?
    var onRunProfileUpdated: (@Sendable (LocalMLXRunProfile) -> Void)?

    func setSsmStateService(_ service: SSMStateService) {
        self.ssmStateService = service
    }

    func setActiveSessionID(_ sessionID: String) {
        self.activeSessionID = sessionID
    }

    func setActiveVaultRoot(_ url: URL) {
        self.activeVaultRoot = url
    }

    func setOnSSMStateSaved(_ handler: @escaping @Sendable (_ sessionID: String, _ statePath: String) -> Void) {
        self.onSSMStateSaved = handler
    }

    func setOnRunProfileUpdated(_ handler: @escaping @Sendable (LocalMLXRunProfile) -> Void) {
        self.onRunProfileUpdated = handler
    }

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

    private enum MetalRuntimeUnloadMode {
        case workingSetOnly
        case deep
    }

    init(snapshot: LocalHardwareCapabilitySnapshot = .current) {
        self.snapshot = snapshot
        self.serialController = LocalInferenceSerialController()
        self.runtimeConditions = .current()
        let policy = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: runtimeConditions
        )
        Memory.memoryLimit = policy.idleMemoryPolicy.memoryLimitBytes
        Memory.cacheLimit = policy.idleMemoryPolicy.cacheLimitBytes
    }

    /// Install a `DispatchSourceMemoryPressure` listener the first time we're
    /// asked. On `.warning` we evict cached artifacts (MLX.GPU cache, peak
    /// counters); on `.critical` we also drop the loaded model container. That
    /// turns the Mac's "memory is about to be reclaimed aggressively" signal
    /// into a graceful unload instead of a surprise jetsam kill.
    private func installMemoryPressureListenerIfNeeded() {
        guard !memoryPressureListenerInstalled else { return }
        memoryPressureListenerInstalled = true

        let queue = DispatchQueue.global(qos: .utility)
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            // Flatten to Sendable primitives on the dispatch queue before
            // hopping into the actor — passing the OptionSet across the
            // boundary trips Swift 6 sending-risk diagnostics.
            let event = source.data
            let isCritical = event.contains(.critical)
            let isWarning = event.contains(.warning)
            Task { [weak self] in
                guard let self else { return }
                await self.handleMemoryPressureEvent(isWarning: isWarning, isCritical: isCritical)
            }
        }
        source.resume()
        self.memoryPressureSource = source
        log.info("MLXInferenceService: memory-pressure listener installed")
    }

    private func handleMemoryPressureEvent(isWarning: Bool, isCritical: Bool) {
        if isCritical {
            log.warning("MLXInferenceService: memory pressure CRITICAL — unloading active model")
            Memory.peakMemory = 0
            Task { [weak self] in
                await self?.performUnload(metalRuntimeUnloadMode: .deep)
            }
        } else if isWarning {
            log.warning("MLXInferenceService: memory pressure WARNING - clearing caches + KV")
            Memory.peakMemory = 0
            // Drop the persistent SSM ChatSession on warning. The model
            // container stays loaded; only the KV cache + per-session
            // state is released. ChatSession exposes no public
            // `clearKVCache()`, so dropping the whole session is the
            // canonical way: next `respond(...)` reconstructs against
            // the warm container in ~50 ms (vs. ~2 s for a full
            // model reload). Saves 256-512 MB on top of the
            // intermediate-tensor cache shrink below.
            //
            // We don't drop on .normal (recovery); keeping the warm
            // session avoids churning rebuild on transient spikes.
            persistentSSMSession = nil
            persistentSSMSessionID = nil
            applyActiveMemoryPolicy(currentRuntimePolicy())
        }
    }

    func generate(request: LocalMLXRequest) async throws -> String {
        // Wave 2.1 canonical perf signpost (subsystem io.epistemos.core / inference).
        // Wraps the local MLX generate path. Per dpp §1.1 Task 0.1.
        // Routed through Sig.interval (sync) wrapping the actor-isolated body
        // via a noop closure call to avoid Sendable-closure crossing for the
        // actor-isolated locals used inside generate.
        let inferenceSignpostID = Sig.inference.makeSignpostID()
        let inferenceSignpostState = Sig.inference.beginInterval(
            "generate", id: inferenceSignpostID
        )
        defer { Sig.inference.endInterval("generate", inferenceSignpostState) }
        await beginRequest()
        let start = ContinuousClock.now
        let policy = currentRuntimePolicy()
        do {
            try beginSerialTurn()
            defer { endSerialTurnIfNeeded() }
            let load = try await loadContainerIfNeeded(for: request, policy: policy)
            let parameters = generationParameters(for: request)

            // For SSM models, reuse the ChatSession to preserve recurrent state
            // across turns. For non-SSM models, create a fresh session each time.
            let isSSM = LocalTextModelID(rawValue: request.modelID)?.isSSM == true
            let session: ChatSession
            if isSSM,
               let existing = persistentSSMSession,
               persistentSSMModelID == request.modelID,
               persistentSSMSessionID == activeSessionID {
                session = existing
                session.generateParameters = parameters
            } else {
                session = ChatSession(
                    load.container,
                    instructions: request.systemPrompt,
                    generateParameters: parameters,
                    additionalContext: additionalContext(for: request)
                )
                if isSSM {
                    persistentSSMSession = session
                    persistentSSMModelID = request.modelID
                    persistentSSMSessionID = activeSessionID

                    // Attempt to resume from a previously saved SSM state.
                    // On success the session's KVCache is pre-populated,
                    // avoiding conversation replay on the next generate call.
                    if let stateService = ssmStateService,
                       let sessionID = activeSessionID {
                        let resumed = await resumeSSMState(
                            stateService: stateService,
                            session: session,
                            modelID: request.modelID,
                            sessionID: sessionID
                        )
                        if resumed {
                            log.info("SSM session resumed with cached state for \(request.modelID, privacy: .public)")
                        }
                    }
                }
            }

            let response = try await executeGpuBoundRequest(
                request: request,
                session: session,
                requestStart: start,
                emit: nil
            )
            let serialSnapshot = currentSerialSnapshot()
            let profiledStopReason = Self.normalizedStopReason(
                response.stopReason,
                outputCharacterCount: response.outputCharacterCount,
                chunkCount: response.chunkCount
            )
            let totalDurationMS = start.duration(to: ContinuousClock.now).millisecondsValue
            lastRunProfile = LocalMLXRunProfile(
                modelID: request.modelID,
                artifactID: nil,
                requestedRuntimeKind: nil,
                resolvedRuntimeKind: .mlx,
                executionMode: .local,
                coldLoad: load.coldLoad,
                lowPowerModeEnabled: runtimeConditions.lowPowerModeEnabled,
                appActive: runtimeConditions.appActive,
                thermalState: runtimeConditions.thermalState,
                loadDurationMS: load.loadDurationMS,
                firstTokenLatencyMS: response.firstTokenLatencyMS,
                totalDurationMS: totalDurationMS,
                outputTokenCount: Self.estimatedTokenCount(for: response.text),
                tokensPerSecond: Self.tokensPerSecond(
                    output: response.text,
                    totalDurationMS: totalDurationMS
                ),
                outputCharacterCount: response.outputCharacterCount,
                chunkCount: response.chunkCount,
                continuationCount: response.continuationCount,
                stopReason: Self.stopReasonLabel(profiledStopReason),
                memoryLimitBytes: policy.memoryPolicy.memoryLimitBytes,
                cacheLimitBytes: adjustedCacheLimitBytes(for: policy.memoryPolicy.cacheLimitBytes),
                serialPhase: serialSnapshot.phase,
                fallbackMode: serialSnapshot.fallbackMode.rawValue,
                availableMemoryBytes: serialSnapshot.availableMemoryBytes
            )
            log.info(
                "Local generate model=\(request.modelID, privacy: .public) cold=\(load.coldLoad) loadMs=\(load.loadDurationMS, privacy: .public) totalMs=\(totalDurationMS, privacy: .public) stop=\(Self.stopReasonLabel(profiledStopReason), privacy: .public) continuations=\(response.continuationCount, privacy: .public) lowPower=\(self.runtimeConditions.lowPowerModeEnabled) appActive=\(self.runtimeConditions.appActive)"
            )

            // SSM State Persistence: after successful generation with an SSM model,
            // extract the populated cache and persist it to disk.
            if let stateService = ssmStateService,
               let sessionID = activeSessionID,
               LocalTextModelID(rawValue: request.modelID)?.isSSM == true {
                await notifySSMStateService(
                    stateService: stateService,
                    session: session,
                    modelID: request.modelID,
                    sessionID: sessionID
                )
            }

            await endRequest(policy: policy)
            return response.text
        } catch {
            await endRequest(policy: policy)
            throw error
        }
    }

    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error> {
        cancelScheduledUnload()
        return StreamingBufferPolicy.throwingStream { continuation in
            let task = Task {
                let policy = await self.beginRequestAndResolvePolicy()
                var emittedText = ""
                do {
                    try self.beginSerialTurn()
                    defer { self.endSerialTurnIfNeeded() }
                    let start = ContinuousClock.now
                    let load = try await self.loadContainerIfNeeded(for: request, policy: policy)
                    let parameters = self.generationParameters(for: request)
                    let isSSM = LocalTextModelID(rawValue: request.modelID)?.isSSM == true
                    let session: ChatSession
                    if isSSM,
                       let existing = self.persistentSSMSession,
                       self.persistentSSMModelID == request.modelID,
                       self.persistentSSMSessionID == self.activeSessionID {
                        session = existing
                        session.generateParameters = parameters
                    } else {
                        session = ChatSession(
                            load.container,
                            instructions: request.systemPrompt,
                            generateParameters: parameters,
                            additionalContext: self.additionalContext(for: request)
                        )
                        if isSSM {
                            self.persistentSSMSession = session
                            self.persistentSSMModelID = request.modelID
                            self.persistentSSMSessionID = self.activeSessionID

                            if let stateService = self.ssmStateService,
                               let sessionID = self.activeSessionID {
                                let resumed = await self.resumeSSMState(
                                    stateService: stateService,
                                    session: session,
                                    modelID: request.modelID,
                                    sessionID: sessionID
                                )
                                if resumed {
                                    self.log.info(
                                        "SSM stream resumed with cached state for \(request.modelID, privacy: .public)"
                                    )
                                }
                            }
                        }
                    }
                    let response = try await self.executeGpuBoundRequest(
                        request: request,
                        session: session,
                        requestStart: start,
                        emit: { chunk in
                            emittedText += chunk
                            continuation.yield(chunk)
                        }
                    )
                    let serialSnapshot = self.currentSerialSnapshot()
                    let profiledStopReason = Self.normalizedStopReason(
                        response.stopReason,
                        outputCharacterCount: response.outputCharacterCount,
                        chunkCount: response.chunkCount
                    )
                    let totalDurationMS = start.duration(to: ContinuousClock.now).millisecondsValue
                    self.recordProfile(
                        LocalMLXRunProfile(
                            modelID: request.modelID,
                            artifactID: nil,
                            requestedRuntimeKind: nil,
                            resolvedRuntimeKind: .mlx,
                            executionMode: .local,
                            coldLoad: load.coldLoad,
                            lowPowerModeEnabled: self.runtimeConditions.lowPowerModeEnabled,
                            appActive: self.runtimeConditions.appActive,
                            thermalState: self.runtimeConditions.thermalState,
                            loadDurationMS: load.loadDurationMS,
                            firstTokenLatencyMS: response.firstTokenLatencyMS,
                            totalDurationMS: totalDurationMS,
                            outputTokenCount: Self.estimatedTokenCount(for: response.text),
                            tokensPerSecond: Self.tokensPerSecond(
                                output: response.text,
                                totalDurationMS: totalDurationMS
                            ),
                            outputCharacterCount: response.outputCharacterCount,
                            chunkCount: response.chunkCount,
                            continuationCount: response.continuationCount,
                            stopReason: Self.stopReasonLabel(profiledStopReason),
                            memoryLimitBytes: policy.memoryPolicy.memoryLimitBytes,
                            cacheLimitBytes: self.adjustedCacheLimitBytes(for: policy.memoryPolicy.cacheLimitBytes),
                            serialPhase: serialSnapshot.phase,
                            fallbackMode: serialSnapshot.fallbackMode.rawValue,
                            availableMemoryBytes: serialSnapshot.availableMemoryBytes
                        )
                    )
                    self.log.info(
                        "Local stream model=\(request.modelID, privacy: .public) cold=\(load.coldLoad) loadMs=\(load.loadDurationMS, privacy: .public) firstTokenMs=\(response.firstTokenLatencyMS ?? -1, privacy: .public) totalMs=\(totalDurationMS, privacy: .public) chunks=\(response.chunkCount, privacy: .public) stop=\(Self.stopReasonLabel(profiledStopReason), privacy: .public) continuations=\(response.continuationCount, privacy: .public) lowPower=\(self.runtimeConditions.lowPowerModeEnabled) appActive=\(self.runtimeConditions.appActive)"
                    )
                    if let stateService = self.ssmStateService,
                       let sessionID = self.activeSessionID,
                       isSSM {
                        await self.notifySSMStateService(
                            stateService: stateService,
                            session: session,
                            modelID: request.modelID,
                            sessionID: sessionID
                        )
                    }
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
                    if let trailingDelta = Self.trailingPostprocessedDelta(
                        finalText: response.text,
                        alreadyEmitted: emittedText
                    ) {
                        continuation.yield(trailingDelta)
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
        await performUnload(metalRuntimeUnloadMode: .deep)
    }

    func updateRuntimeConditions(_ conditions: LocalRuntimeConditions) async {
        runtimeConditions = conditions
        let policy = currentRuntimePolicy()
        if activeRequestCount > 0 {
            applyActiveMemoryPolicy(policy)
        } else {
            applyIdleMemoryPolicy(policy)
        }
        guard activeRequestCount == 0, container != nil else { return }
        if conditions.thermalState == .critical {
            await performUnload(metalRuntimeUnloadMode: .deep)
        } else if conditions.appActive {
            cancelScheduledUnload()
        } else {
            scheduleIdleUnload()
        }
    }

    private func performUnload(metalRuntimeUnloadMode: MetalRuntimeUnloadMode) async {
        cancelScheduledUnload()
        container = nil
        loadedModelID = nil
        persistentSSMSession = nil
        persistentSSMModelID = nil
        persistentSSMSessionID = nil
        let runtimeManager = metalRuntimeManager
        metalRuntimeManager = nil
        preparedCustomSSMRuntimeKey = nil
        // Idle unload keeps compiled Metal pipelines and only releases
        // state buffers/heap, preserving repeat-chat fluidity. Explicit
        // unload and critical pressure go deeper: `deepUnload()` drops
        // cached MTLComputePipelineState refs plus the in-memory
        // MTLBinaryArchive image. The disk archive survives for warm
        // recompilation on the next custom-SSM inference.
        await MainActor.run {
            switch metalRuntimeUnloadMode {
            case .workingSetOnly:
                runtimeManager?.releaseWorkingSet()
            case .deep:
                runtimeManager?.deepUnload()
            }
        }
        Memory.cacheLimit = 0
        Memory.clearCache()
        let policy = currentRuntimePolicy()
        applyIdleMemoryPolicy(policy)
    }

    func profilingSnapshot() -> LocalMLXRunProfile? {
        lastRunProfile
    }

    private nonisolated static func tokensPerSecond(
        output: String,
        totalDurationMS: Double
    ) -> Double? {
        guard totalDurationMS > 0 else { return nil }
        let estimatedTokens = estimatedTokenCount(for: output)
        guard estimatedTokens > 0 else { return nil }
        return Double(estimatedTokens) / (totalDurationMS / 1_000)
    }

    private nonisolated static func estimatedTokenCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let words = text.split(whereSeparator: \.isWhitespace).count
        let charEstimate = Int(ceil(Double(text.count) / 3.5))
        let wordEstimate = Int(ceil(Double(words) * 1.33))
        return max(charEstimate, wordEstimate)
    }

    private func loadContainerIfNeeded(
        for request: LocalMLXRequest,
        policy: LocalMLXRuntimePolicy
    ) async throws -> (container: ModelContainer, coldLoad: Bool, loadDurationMS: Double) {
        cancelScheduledUnload()
        applyActiveMemoryPolicy(policy)
        if loadedModelID == request.modelID, let container {
            await prepareCustomSSMRuntimeIfNeeded(for: request.modelID)
            return (container, false, 0)
        }

        // Defensive guard: Gemma 4 weights install but the Swift MLX
        // loader isn't ported yet (see LocalTextModelID.isAwaitingSwiftRuntimeLoader
        // + docs/MASTER_MODEL_STACK_PLAN.md §3.a). The picker filter
        // (Batch T) + the startup migration already try to keep users
        // off Gemma 4, but if ANY path still resolves to a gemma4 ID
        // we want a friendly error instead of the opaque
        // "Unsupported model type: gemma4" the user has been seeing.
        if let modelID = LocalTextModelID(rawValue: request.modelID),
           modelID.isAwaitingSwiftRuntimeLoader {
            throw LocalInferenceRoutingError.modelLoaderUnavailable(modelID: request.modelID)
        }

        try recordTurnBoundaryReadaheadIfNeeded()
        try beginSsdReadIfNeeded()
        defer { finishSsdReadIfNeeded() }

        await unload()
        // Memory pre-flight: fail fast rather than swap-thrash. After `unload()`
        // we've already released any prior model, so the available-memory probe
        // reflects the real headroom the new weights will compete with. We only
        // refuse when the OS tells us it has materially less memory than the
        // model's documented minimum — a 2 GB fudge factor covers KV cache +
        // tokenizer overhead and avoids false positives on a just-woken Mac.
        try Self.preflightAvailableMemory(for: request.modelID)
        let start = ContinuousClock.now
        applyActiveMemoryPolicy(policy)
        Memory.peakMemory = 0

        let configuration = ModelConfiguration(directory: request.modelDirectory)
        let coldLoadTimeout = Self.coldLoadTimeoutSeconds(for: request.modelID)

        // Use VLMModelFactory for vision models (Gemma 4, Gemma 3, Llama 4 Scout),
        // LLMModelFactory for text-only models (Qwen, DeepSeek, Mistral, etc.)
        let isVisionModel = LocalTextModelID(rawValue: request.modelID)?.supportsVision ?? false
        let container: ModelContainer
        do {
            #if canImport(MLXVLM)
            if isVisionModel {
                container = try await withTimeout(seconds: coldLoadTimeout) {
                    try await VLMModelFactory.shared.loadContainer(configuration: configuration)
                }
                log.info("Loaded local VLM model \(request.modelID, privacy: .public)")
            } else {
                container = try await withTimeout(seconds: coldLoadTimeout) {
                    try await LLMModelFactory.shared.loadContainer(configuration: configuration)
                }
                log.info("Loaded local LLM model \(request.modelID, privacy: .public)")
            }
            #else
            container = try await withTimeout(seconds: coldLoadTimeout) {
                try await LLMModelFactory.shared.loadContainer(configuration: configuration)
            }
            log.info("Loaded local LLM model \(request.modelID, privacy: .public) (VLM unavailable)")
            #endif
        } catch is TimeoutError {
            throw LocalInferenceRoutingError.modelLoadStalled(modelID: request.modelID)
        }
        loadedModelID = request.modelID
        self.container = container
        await prepareCustomSSMRuntimeIfNeeded(for: request.modelID)
        return (container, true, start.duration(to: ContinuousClock.now).millisecondsValue)
    }

    private nonisolated static func coldLoadTimeoutSeconds(for modelID: String) -> Double {
        switch LocalTextModelID(rawValue: modelID) {
        case .qwen25Coder7B:
            return 90.0
        default:
            return 120.0
        }
    }

    /// Memory pre-flight for local model loads. Returns silently when there's
    /// enough headroom (or when we can't resolve a required budget). Throws
    /// `LocalInferenceRoutingError.insufficientMemory` when the OS reports
    /// materially less available memory than the model documents as its
    /// interactive-chat minimum. Refusing up-front beats the historical alternative of
    /// "attempt the load, drag the Mac into SSD swap, get SIGKILL'd on
    /// jetsam" — which is exactly what the user reported on the Qwen
    /// Coder 30B path.
    ///
    /// `os_proc_available_memory()` is iOS-only; on macOS we query the Mach
    /// host for VM statistics and sum free + inactive + purgeable pages,
    /// which is the conventional "memory available to new allocations"
    /// reading on Apple Silicon unified memory.
    private nonisolated static func preflightAvailableMemory(for modelID: String) throws {
        guard let model = LocalTextModelID(rawValue: modelID) else { return }
        let requiredGB = model.minimumRecommendedInteractiveMemoryGB
        guard requiredGB > 0 else { return }

        guard let availableBytes = approximateAvailableUnifiedMemoryBytes() else { return }
        let bytesPerGB: UInt64 = 1_073_741_824 // 1024 * 1024 * 1024
        let availableGB = Int(availableBytes / bytesPerGB)
        // `availableBytes` already sums free + inactive + purgeable pages —
        // macOS will reclaim inactive/purgeable under pressure, so the OS
        // effectively has another few GB on top of that when it needs it.
        // The per-model `minimumRecommendedInteractiveMemoryGB` values also
        // quote a conservative ceiling rather than the realistic working set
        // (a 4-bit 4B model's true footprint is ~4-5 GB, not the 8 GB it
        // lists). Giving the user a 6 GB benefit-of-the-doubt lets small
        // models (Qwen 3 4B, Bonsai 4B/8B) load on a typical 16 GB Mac
        // that's doing real work, and still refuses oversized models
        // (DeepSeek R1 7B needs 16 GB → still refuses below ~10 GB free;
        // anything 24 GB+ refuses well before swap death).
        let headroomGB = 6
        guard availableGB + headroomGB < requiredGB else { return }

        throw LocalInferenceRoutingError.insufficientMemory(
            modelID: modelID,
            requiredGB: requiredGB,
            availableGB: availableGB
        )
    }

    /// Query the Mach host for VM statistics and return free + inactive +
    /// purgeable bytes — the conventional "memory available to new
    /// allocations" reading. Returns `nil` on unexpected kernel errors so
    /// callers can fall through gracefully instead of refusing loads.
    private nonisolated static func approximateAvailableUnifiedMemoryBytes() -> UInt64? {
        let count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        var stats = vm_statistics64_data_t()
        var mutableCount = count
        let kerr = withUnsafeMutablePointer(to: &stats) { statsPtr -> kern_return_t in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &mutableCount)
            }
        }
        guard kerr == KERN_SUCCESS else { return nil }
        // `vm_kernel_page_size` is a `var` exported from Darwin; under Swift 6
        // strict concurrency it's flagged as shared mutable state. Using
        // `getpagesize()` gives us the same value from a concurrency-safe C
        // call without forcing an `@preconcurrency` import.
        let pageSize = UInt64(getpagesize())
        let free = UInt64(stats.free_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize
        return free + inactive + purgeable
    }

    private enum CustomSSMRuntimeWarmupError: LocalizedError {
        case metalUnavailable

        var errorDescription: String? {
            switch self {
            case .metalUnavailable:
                "Metal runtime unavailable on this device."
            }
        }
    }

    private func prepareCustomSSMRuntimeIfNeeded(for modelID: String) async {
        guard let model = LocalTextModelID(rawValue: modelID),
              let profile = model.ssmRuntimeProfile,
              profile.warmsCustomMetalRuntime else {
            preparedCustomSSMRuntimeKey = nil
            return
        }

        let runtimeKey =
            modelID
            + ":\(profile.layers)"
            + ":\(profile.heads)"
            + ":\(profile.stateDimension)"
            + ":\(profile.headDimension)"
            + ":\(profile.chunkLength)"
            + ":\(profile.tileSize)"
        guard preparedCustomSSMRuntimeKey != runtimeKey else { return }

        do {
            let existingRuntime = metalRuntimeManager
            let preparedRuntime = try await MainActor.run { () throws -> MetalRuntimeManager in
                let runtime = existingRuntime ?? MetalRuntimeManager()
                guard let runtime else {
                    throw CustomSSMRuntimeWarmupError.metalUnavailable
                }

                try runtime.ensureKernelsReady()
                runtime.allocateStateBuffers(
                    layers: profile.layers,
                    stateDim: profile.stateDimension,
                    headDim: profile.headDimension,
                    heads: profile.heads
                )
                runtime.allocateInferenceHeap(
                    sizeBytes: profile.recommendedHeapSizeBytes
                )
                return runtime
            }
            metalRuntimeManager = preparedRuntime
            preparedCustomSSMRuntimeKey = runtimeKey
            log.info(
                "Prepared custom SSM runtime for \(modelID, privacy: .public) chunk=\(profile.chunkLength, privacy: .public) heap=\(profile.recommendedHeapSizeBytes, privacy: .public)"
            )
        } catch {
            preparedCustomSSMRuntimeKey = nil
            log.error(
                "Custom SSM runtime warmup skipped for \(modelID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func cancelScheduledUnload() {
        scheduledUnloadTask?.cancel()
        scheduledUnloadTask = nil
    }

    private func scheduleIdleUnload() {
        cancelScheduledUnload()
        guard activeRequestCount == 0, container != nil else { return }
        let policy = currentRuntimePolicy()
        let delay = policy.idleUnloadDelay
        let metalRuntimeUnloadMode = metalRuntimeUnloadMode(for: policy)
        scheduledUnloadTask = Task { [delay, metalRuntimeUnloadMode] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self.performUnload(metalRuntimeUnloadMode: metalRuntimeUnloadMode)
        }
    }

    private func metalRuntimeUnloadMode(for policy: LocalMLXRuntimePolicy) -> MetalRuntimeUnloadMode {
        switch policy.idleUnloadMode {
        case .workingSetOnly:
            return .workingSetOnly
        case .deep:
            return .deep
        }
    }

    private func enqueueIdleUnload() async {
        scheduleIdleUnload()
    }

    private func beginRequest() async {
        await requestGate.acquire()
        cancelScheduledUnload()
        activeRequestCount += 1
        installMemoryPressureListenerIfNeeded()
    }

    private func beginRequestAndResolvePolicy() async -> LocalMLXRuntimePolicy {
        await beginRequest()
        return currentRuntimePolicy()
    }

    private func endRequest(policy: LocalMLXRuntimePolicy) async {
        activeRequestCount = max(0, activeRequestCount - 1)
        Memory.clearCache()
        applyIdleMemoryPolicy(policy)
        scheduleIdleUnload()
        await requestGate.release()
    }

    private func applyActiveMemoryPolicy(_ policy: LocalMLXRuntimePolicy) {
        Memory.memoryLimit = policy.memoryPolicy.memoryLimitBytes
        Memory.cacheLimit = adjustedCacheLimitBytes(for: policy.memoryPolicy.cacheLimitBytes)
    }

    private func applyIdleMemoryPolicy(_ policy: LocalMLXRuntimePolicy) {
        Memory.memoryLimit = policy.idleMemoryPolicy.memoryLimitBytes
        Memory.cacheLimit = adjustedCacheLimitBytes(for: policy.idleMemoryPolicy.cacheLimitBytes)
    }

    private func currentRuntimePolicy() -> LocalMLXRuntimePolicy {
        LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: runtimeConditions,
            idleMemoryMode: PerformanceSettingsReader.idleMemoryMode
        )
    }

    private func recordProfile(_ profile: LocalMLXRunProfile) {
        lastRunProfile = profile
        onRunProfileUpdated?(profile)
    }

    private func beginSerialTurn() throws {
        lastSerialSnapshot = serialController.refreshAvailableMemory()
        try serialController.beginTurn()
        lastSerialSnapshot = serialController.snapshot()
    }

    private func endSerialTurnIfNeeded() {
        do {
            try serialController.endTurn()
        } catch {
            log.debug("Serial inference endTurn ignored: \(error.localizedDescription, privacy: .public)")
        }
        lastSerialSnapshot = serialController.snapshot()
    }

    private func recordTurnBoundaryReadaheadIfNeeded() throws {
        do {
            try serialController.recordTurnBoundaryReadahead()
            lastSerialSnapshot = serialController.snapshot()
        } catch let error as LocalInferenceSerialControllerError where error == .invalidTransition || error == .noTurnOpen {
            throw error
        } catch {
            log.debug("Serial inference readahead skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func beginSsdReadIfNeeded() throws {
        try serialController.beginSsdRead()
        lastSerialSnapshot = serialController.snapshot()
    }

    private func finishSsdReadIfNeeded() {
        do {
            try serialController.finishSsdRead()
        } catch {
            log.error("Serial inference finishSsdRead failed: \(error.localizedDescription, privacy: .public)")
        }
        lastSerialSnapshot = serialController.snapshot()
    }

    private func adjustedCacheLimitBytes(for suggestedBytes: Int) -> Int {
        serialController.adjustedCacheLimitBytes(suggestedBytes: suggestedBytes)
    }

    private func currentSerialSnapshot() -> LocalInferenceSerialSnapshot {
        let snapshot = serialController.snapshot()
        lastSerialSnapshot = snapshot
        return snapshot
    }

    private func executeGpuBoundRequest(
        request: LocalMLXRequest,
        session: ChatSession,
        requestStart: ContinuousClock.Instant,
        emit: ((String) -> Void)?
    ) async throws -> GenerationExecutionSummary {
        try serialController.beginGpuCompute()
        lastSerialSnapshot = serialController.snapshot()
        defer {
            do {
                try serialController.finishGpuCompute()
            } catch {
                log.error("Serial inference finishGpuCompute failed: \(error.localizedDescription, privacy: .public)")
            }
            lastSerialSnapshot = serialController.snapshot()
        }

        return try await executeRequest(
            request: request,
            session: session,
            requestStart: requestStart,
            emit: emit
        )
    }

    private func executeRequest(
        request: LocalMLXRequest,
        session: ChatSession,
        requestStart: ContinuousClock.Instant,
        emit: ((String) -> Void)?
    ) async throws -> GenerationExecutionSummary {
        let pass = try await runPass(
            request: request,
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
        request: LocalMLXRequest,
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
        var loopGuard = LocalMLXLoopGuard(request: request)

        let mlxImages = request.imageURLs.map { UserInput.Image.url($0) }

        generationLoop: for try await item in session.streamDetails(
            to: prompt,
            images: mlxImages,
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
                if let detection = loopGuard.record(chunk: chunk) {
                    output = LocalMLXLoopMitigation.appendFallbackIfNeeded(to: output, for: request)
                    stopReason = .stop
                    log.warning(
                        "Local stream loop guard stopped model=\(request.modelID, privacy: .public) reason=\(detection.reason.rawValue, privacy: .public)"
                    )
                    break generationLoop
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

        output = LocalMLXLoopMitigation.appendFallbackIfNeeded(to: output, for: request)

        return GenerationPassResult(
            text: output,
            firstTokenLatencyMS: firstTokenLatencyMS,
            chunkCount: chunkCount,
            stopReason: stopReason
        )
    }

    private func generationParameters(for request: LocalMLXRequest) -> GenerateParameters {
        // Per-model optimal parameters from LocalTextModelID capabilities.
        // Each model has been tuned based on architecture research:
        // - Qwopus: temp=0.6, top-k=20 (Act-Then-Refine paper)
        // - DeepSeek R1: temp=0.5 (deterministic reasoning)
        // - Qwen Coder: temp=0.3 (correct code generation)
        // - Small models: higher temp to avoid repetition
        let model = LocalTextModelID(rawValue: request.modelID)

        let kvSize = model?.optimalKVCacheSize ?? 1_536
        let estimatedContextTokens = Self.estimatedKVContextTokens(for: request)
        let useKIVI = KIVIPreferences.shouldUseKIVI(forContextTokens: estimatedContextTokens)
        let kvScheme: MLXLMCommon.KVQuantScheme = useKIVI ? .kivi : .affine

        // Use thinking temperature when in thinking mode, fast temperature otherwise
        let temp: Float
        if request.reasoningMode == .thinking,
           let thinkingTemp = model?.thinkingTemperature {
            temp = thinkingTemp
        } else {
            temp = model?.optimalTemperature ?? 0.7
        }
        let topP = model?.optimalTopP ?? 0.95

        return GenerateParameters(
            maxTokens: request.resolvedMaxTokens,
            maxKVSize: useKIVI ? nil : kvSize,
            kvBits: useKIVI ? 2 : 4,
            kvGroupSize: useKIVI ? 32 : 64,
            quantizedKVStart: 0,
            kvScheme: kvScheme,
            temperature: temp,
            topP: topP,
            prefillStepSize: 256
        )
    }

    nonisolated private static func estimatedKVContextTokens(for request: LocalMLXRequest) -> Int {
        let systemBytes = request.systemPrompt?.utf8.count ?? 0
        let promptBytes = request.prompt.utf8.count
        return max(1, (systemBytes + promptBytes) / 4)
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

    nonisolated static func trailingPostprocessedDelta(
        finalText: String,
        alreadyEmitted: String
    ) -> String? {
        guard !finalText.isEmpty else { return nil }
        guard !alreadyEmitted.isEmpty else { return finalText }
        guard finalText.hasPrefix(alreadyEmitted) else { return nil }
        let deltaStart = finalText.index(finalText.startIndex, offsetBy: alreadyEmitted.count)
        let delta = String(finalText[deltaStart...])
        return delta.isEmpty ? nil : delta
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

    // MARK: - SSM State Persistence

    /// Cached ChatSession for SSM models — kept alive between turns so the
    /// recurrent state persists without re-processing the conversation.
    private var persistentSSMSession: ChatSession?
    private var persistentSSMModelID: String?
    private var persistentSSMSessionID: String?

    /// After SSM model generation, extract the populated KVCache and persist to disk.
    /// Uses the ChatSession.extractKVCache() accessor (local mlx-swift-lm patch).
    private func notifySSMStateService(
        stateService: SSMStateService,
        session: ChatSession,
        modelID: String,
        sessionID: String
    ) async {
        guard let cache = await session.extractKVCache() else {
            log.warning("SSM state save skipped — no KVCache available for session=\(sessionID, privacy: .public)")
            return
        }
        if let savedURL = await MainActor.run(body: {
            stateService.saveMLXCache(cache: cache, modelId: modelID, sessionId: sessionID)
        }) {
            log.info("SSM state persisted: \(savedURL.lastPathComponent, privacy: .public)")
            onSSMStateSaved?(sessionID, savedURL.path)
        }
    }

    /// Attempt to load a previously saved SSM state into the ChatSession.
    /// If successful, the session can generate without replaying conversation history.
    /// Checks vault staleness: if notes were modified after the snapshot, the state is
    /// discarded to prevent stale context from polluting generation.
    ///
    /// - Returns: true if state was restored, false otherwise
    private func resumeSSMState(
        stateService: SSMStateService,
        session: ChatSession,
        modelID: String,
        sessionID: String
    ) async -> Bool {
        guard let stateURL = await MainActor.run(body: {
            stateService.findLatestState(modelId: modelID, sessionId: sessionID)
        }) else {
            return false
        }

        // Staleness check: if vault notes changed after the state was saved,
        // the hidden state no longer reflects the current vault content.
        if let vaultRoot = activeVaultRoot,
           await MainActor.run(body: {
               stateService.isStateStale(stateURL: stateURL, vaultRoot: vaultRoot)
           }) {
            log.info("SSM state stale (vault modified) — skipping resume for session=\(sessionID, privacy: .public)")
            return false
        }

        guard let (cache, _) = await MainActor.run(body: {
            stateService.loadMLXCache(from: stateURL)
        }) else {
            log.warning("SSM state load failed from \(stateURL.lastPathComponent, privacy: .public)")
            return false
        }
        let injected = await session.injectKVCache(cache)
        guard injected else {
            log.warning(
                "SSM state load skipped from \(stateURL.lastPathComponent, privacy: .public) because cache shape did not match the active model"
            )
            return false
        }
        log.info(
            "SSM state resumed from \(stateURL.lastPathComponent, privacy: .public) for session=\(sessionID, privacy: .public)"
        )
        return true
    }
}
#else
actor MLXInferenceService: LocalMLXRuntime {
    private var lastRunProfile: LocalMLXRunProfile?
    var onRunProfileUpdated: (@Sendable (LocalMLXRunProfile) -> Void)?

    init(snapshot: LocalHardwareCapabilitySnapshot = .current) {
        _ = snapshot
    }

    func generate(request: LocalMLXRequest) async throws -> String {
        _ = request
        throw LocalInferenceRoutingError.runtimeUnavailable
    }

    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error> {
        _ = request
        return StreamingBufferPolicy.throwingStream { continuation in
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

    func setOnRunProfileUpdated(_ handler: @escaping @Sendable (LocalMLXRunProfile) -> Void) {
        self.onRunProfileUpdated = handler
    }
}
#endif

private extension Duration {
    nonisolated var millisecondsValue: Double {
        let components = components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
