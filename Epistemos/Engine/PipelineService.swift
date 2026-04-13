import Foundation
import Synchronization
import os

private final class FinishOnce: Sendable {
    private let done = Mutex(false)

    nonisolated func tryFinish() -> Bool {
        done.withLock { done in
            guard !done else { return false }
            done = true
            return true
        }
    }
}

nonisolated enum PipelineError: LocalizedError {
    case noLLMService
    case analysisFailure(String)

    var errorDescription: String? {
        switch self {
        case .noLLMService: "No usable local model is available. Open Settings to install or select one."
        case .analysisFailure(let msg): msg
        }
    }
}

@MainActor
final class PipelineService {
    private let pipelineState: PipelineState
    private let llmService: any LLMClientProtocol
    private let triageService: TriageService
    private let inference: InferenceState
    private let eventBus: EventBus
    private let localModelClient: (any LocalConfigurableLLMClient)?
    private let constrainedDecoding: ConstrainedDecodingService?
    private let vaultPathProvider: @MainActor () -> String?
    private var pipelineTask: Task<Void, Never>?
    private var activeRunID: UUID?

    init(
        pipelineState: PipelineState,
        llmService: any LLMClientProtocol,
        triageService: TriageService,
        inference: InferenceState,
        eventBus: EventBus,
        localModelClient: (any LocalConfigurableLLMClient)? = nil,
        constrainedDecoding: ConstrainedDecodingService? = nil,
        vaultPathProvider: @escaping @MainActor () -> String? = { nil }
    ) {
        self.pipelineState = pipelineState
        self.llmService = llmService
        self.triageService = triageService
        self.inference = inference
        self.eventBus = eventBus
        self.localModelClient = localModelClient
        self.constrainedDecoding = constrainedDecoding
        self.vaultPathProvider = vaultPathProvider
    }

    func run(
        query: String,
        mode: InferenceMode,
        notesContext: String? = nil,
        conversationHistory: String? = nil,
        operatingMode: EpistemosOperatingMode = .fast,
        executionPlan: OverseerComplexityRouter.ExecutionPlan? = nil
    ) -> AsyncThrowingStream<PipelineEvent, Error> {
        let _ = (mode, llmService, inference, eventBus)
        let runID = UUID()
        supersedeActiveRun(with: runID)

        let finisher = FinishOnce()

        return AsyncThrowingStream { (continuation: AsyncThrowingStream<PipelineEvent, Error>.Continuation) in
            let mainTask = Task { @MainActor [weak self] in
                guard let self else {
                    if finisher.tryFinish() { continuation.finish() }
                    return
                }
                guard activeRunID == runID, !Task.isCancelled else {
                    if finisher.tryFinish() { continuation.finish() }
                    return
                }

                do {
                    pipelineState.startProcessing()

                    let useToolLoop = shouldUseToolLoop(
                        operatingMode: operatingMode,
                        executionPlan: executionPlan
                    )
                    let isLocalModelSelected: Bool = {
                        if executionPlan?.forcesLocalExecution == true { return true }
                        if case .localMLX = inference.preferredChatModelSelection { return true }
                        return false
                    }()
                    var emittedVisibleText = ""

                    if useToolLoop,
                       isLocalModelSelected,
                       let localClient = localModelClient,
                       let vaultPath = vaultPathProvider(),
                       !vaultPath.isEmpty {
                        // Tool-enabled local path: LocalAgentLoop handles
                        // multi-turn tool execution via the Rust FFI.
                        emittedVisibleText = try await runToolLoop(
                            query: query,
                            notesContext: notesContext,
                            conversationHistory: conversationHistory,
                            operatingMode: operatingMode,
                            executionPlan: executionPlan,
                            vaultPath: vaultPath,
                            localClient: localClient,
                            onToken: { token in
                                continuation.yield(.textDelta(token))
                            }
                        )
                    } else {
                        // Legacy direct-stream path (cloud models in non-agent
                        // mode, or when localClient / vault aren't available).
                        let directStream = generateDirectStream(
                            query: query,
                            notesContext: notesContext,
                            conversationHistory: conversationHistory,
                            operatingMode: operatingMode,
                            executionPlan: executionPlan
                        )
                        for try await token in directStream {
                            emittedVisibleText += token
                            continuation.yield(.textDelta(token))
                        }
                    }

                    guard !Task.isCancelled else {
                        completeActiveRunIfNeeded(runID)
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    continuation.yield(
                        .completed(
                            DualMessage(
                                rawAnalysis: emittedVisibleText,
                                uncertaintyTags: [],
                                modelVsDataFlags: []
                            ),
                            nil
                        )
                    )
                    completeActiveRunIfNeeded(runID)
                    if finisher.tryFinish() { continuation.finish() }
                } catch is CancellationError {
                    completeActiveRunIfNeeded(runID)
                    if finisher.tryFinish() { continuation.finish() }
                } catch {
                    failActiveRunIfNeeded(runID, error: error.localizedDescription)
                    continuation.yield(.error(error.localizedDescription))
                    if finisher.tryFinish() { continuation.finish() }
                }
            }

            pipelineTask = mainTask
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.cancelActiveRunIfNeeded(runID)
                }
            }
        }
    }

    /// Decide whether the current turn should route through `LocalAgentLoop`
    /// with tier-filtered tools. Fast / Thinking / Pro all qualify when a
    /// local model client is wired. Agent mode goes through the Rust
    /// agent loop instead (handled by ChatCoordinator, not here).
    private func shouldUseToolLoop(
        operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?
    ) -> Bool {
        if let executionPlan {
            switch executionPlan.route {
            case .managedAgentSession:
                return false
            case .localOnly:
                return false
            case .overseerLocalExecution:
                return executionPlan.allowsToolExecution
            }
        }

        switch operatingMode {
        case .fast, .thinking, .pro:
            return true
        case .agent:
            return false
        }
    }

    /// Tool-enabled local-model path. Builds a tier-filtered tool registry
    /// via the Rust FFI, then drives a LocalAgentLoop with the incoming
    /// query. Tokens are forwarded to the caller via `onToken`.
    private func runToolLoop(
        query: String,
        notesContext: String?,
        conversationHistory: String?,
        operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?,
        vaultPath: String,
        localClient: any LocalConfigurableLLMClient,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let tier = ChatToolTier.from(operatingMode: operatingMode)
        let bridge = ToolTierBridge(vaultPath: vaultPath, tier: tier)
        let tools = filteredTools(
            bridge.loadTools(),
            using: executionPlan
        )

        // If no tools loaded (bindings missing, empty registry), fall back
        // to the legacy stream so we don't break builds that haven't linked
        // the Rust FFI yet.
        if tools.isEmpty {
            Log.pipeline.warning("No tools available for tier \(tier.rawValue) — falling back to direct stream")
            var accumulated = ""
            let stream = generateDirectStream(
                query: query,
                notesContext: notesContext,
                conversationHistory: conversationHistory,
                operatingMode: operatingMode,
                executionPlan: executionPlan
            )
            for try await token in stream {
                accumulated += token
                onToken(token)
            }
            return accumulated
        }

        // Build the objective: include notes context and history inline so
        // the loop sees a single self-contained prompt. LocalAgentLoop
        // manages its own turn history internally once the loop starts.
        var objectiveParts: [String] = []
        if let notesContext, !notesContext.isEmpty {
            objectiveParts.append(notesContext)
        }
        if let conversationHistory, !conversationHistory.isEmpty {
            objectiveParts.append(conversationHistory)
        }
        objectiveParts.append(query)
        let objective = objectiveParts.joined(separator: "\n\n")

        let reasoningMode: LocalReasoningMode = switch operatingMode {
        case .thinking: .thinking
        case .pro:      .thinking
        default:        .fast
        }

        let modelID: String? = {
            if executionPlan?.forcesLocalExecution == true {
                return inference.effectiveLocalTextModelID
            }
            if case .localMLX(let id) = inference.preferredChatModelSelection {
                return id
            }
            return inference.effectiveLocalTextModelID
        }()
        let loop = LocalAgentLoop.liveLoop(
            using: localClient,
            constrainedDecoding: constrainedDecoding,
            toolExecutor: bridge.toolExecutor(),
            modelID: modelID,
            defaultReasoningMode: reasoningMode
        )

        Log.pipeline.info(
            "🔧 Tool loop starting — tier=\(tier.rawValue) tools=\(tools.count) mode=\(String(describing: operatingMode))"
        )

        let additional = executionPlan?.additionalSystemPrompt()
        let result = try await loop.run(
            objective: objective,
            tools: tools,
            maxTurns: 6,
            reasoningMode: reasoningMode,
            additionalSystemPrompt: additional,
            onToken: { token in
                Task { @MainActor in
                    onToken(token)
                }
            }
        )
        return result
    }

    func cancelActiveRun() {
        guard activeRunID != nil else { return }
        pipelineTask?.cancel()
        pipelineTask = nil
        activeRunID = nil
        pipelineState.completeProcessing()
    }

    private func supersedeActiveRun(with runID: UUID) {
        pipelineTask?.cancel()
        pipelineTask = nil
        activeRunID = runID
    }

    private func cancelActiveRunIfNeeded(_ runID: UUID) {
        guard activeRunID == runID else { return }
        pipelineTask?.cancel()
        pipelineTask = nil
        activeRunID = nil
    }

    private func completeActiveRunIfNeeded(_ runID: UUID) {
        guard activeRunID == runID else { return }
        pipelineState.completeProcessing()
        pipelineTask = nil
        activeRunID = nil
    }

    private func failActiveRunIfNeeded(_ runID: UUID, error: String) {
        guard activeRunID == runID else { return }
        pipelineState.setError(error)
        pipelineState.completeProcessing()
        pipelineTask = nil
        activeRunID = nil
    }

    private func generateDirectStream(
        query: String,
        notesContext: String? = nil,
        conversationHistory: String? = nil,
        operatingMode: EpistemosOperatingMode = .fast,
        executionPlan: OverseerComplexityRouter.ExecutionPlan? = nil
    ) -> AsyncThrowingStream<String, Error> {
        Log.pipeline.info("🔬 generateDirectStream — chatMode=PLAIN queryLen=\(query.count)")

        var promptParts: [String] = []
        if let notesContext, !notesContext.isEmpty {
            promptParts.append(notesContext)
        }
        if let conversationHistory, !conversationHistory.isEmpty {
            promptParts.append(conversationHistory)
            promptParts.append("User: \(query)")
        } else {
            promptParts.append(query)
        }
        let finalPrompt = promptParts.joined(separator: "\n\n")

        Log.pipeline.info(
            "🔬 systemPrompt length=0 chars | prompt length=\(finalPrompt.count) chars | hasHistory=\(conversationHistory != nil)"
        )

        let systemPrompt = executionPlan?.additionalSystemPrompt()

        if executionPlan?.forcesLocalExecution == true {
            return triageService.streamGeneralLocally(
                prompt: finalPrompt,
                systemPrompt: systemPrompt,
                operation: .chatResponse(query: query),
                contentLength: finalPrompt.count,
                operatingMode: operatingMode,
                localSurface: .miniChat
            )
        }

        return triageService.streamGeneral(
            prompt: finalPrompt,
            systemPrompt: systemPrompt,
            operation: .chatResponse(query: query),
            contentLength: finalPrompt.count,
            operatingMode: operatingMode,
            localSurface: .miniChat
        )
    }

    private func filteredTools(
        _ tools: [OmegaToolDefinition],
        using executionPlan: OverseerComplexityRouter.ExecutionPlan?
    ) -> [OmegaToolDefinition] {
        guard let executionPlan else { return tools }
        let allowed = executionPlan.allowedToolNames
        guard !allowed.isEmpty else { return [] }
        return tools.filter { allowed.contains($0.name) }
    }
}
