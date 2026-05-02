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

/// Structured classification of chat-surface errors. The UI reads the
/// kind to decide what affordance to show — generic-message, retry-with-
/// countdown, deep-link to Settings, etc. — instead of pattern-matching
/// on a free-form String. Raw catch paths still accept `Error` and get
/// mapped through `UserFacingChatError.classify(_:)`.
nonisolated enum UserFacingChatErrorKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// 401 / bad API key / OAuth token invalid. UI should deep-link to
    /// Settings → AI so the user can re-authenticate without hunting.
    case authFailure
    /// 429 / rate limited. UI should suggest waiting and offer an
    /// escape hatch to switch models.
    case rateLimited
    /// Connectivity / DNS / VPN. UI can suggest checking network.
    case providerUnreachable
    /// Timeout. UI can suggest retry or switching to a faster model.
    case timedOut
    /// Context-window overflow. UI can suggest starting a new chat.
    case contextOverflow
    /// The model / runtime isn't installed or ready (local path only).
    /// UI deep-links to Settings → Models.
    case modelNotReady
    /// User hit Stop. UI treats as a silent "stopped" message, not red.
    case cancelled
    /// Anything else — treated as a generic "something went wrong".
    case generic
}

/// Converts infrastructure errors into copy suitable for the chat error
/// bubble. Users should never see an opaque stack-level message — the chat
/// surface is a user experience, not a log viewer.
nonisolated enum UserFacingChatError {
    static func classify(_ error: Error) -> UserFacingChatErrorKind {
        switch error {
        case PipelineError.noLLMService,
             LocalInferenceRoutingError.modelRequired,
             LocalInferenceRoutingError.runtimeUnavailable:
            return .modelNotReady
        case is CancellationError:
            return .cancelled
        default:
            break
        }

        let lower = (error as NSError).localizedDescription.lowercased()
        if lower.contains("unauthorized") || lower.contains("api key") || lower.contains("401") {
            return .authFailure
        }
        if lower.contains("rate limit") || lower.contains("429") || lower.contains("too many requests") {
            return .rateLimited
        }
        if lower.contains("network") || lower.contains("offline") || lower.contains("internet") || lower.contains("connection") {
            return .providerUnreachable
        }
        if lower.contains("timed out") || lower.contains("timeout") {
            return .timedOut
        }
        if lower.contains("context length") || lower.contains("too long") || (lower.contains("token") && lower.contains("limit")) {
            return .contextOverflow
        }
        return .generic
    }

    /// Default copy for each error kind — used by the String-returning
    /// `message(from:)` below and by views that want a fallback label.
    static func message(for kind: UserFacingChatErrorKind, fallback: String = "") -> String {
        switch kind {
        case .modelNotReady:
            return "No model is ready to answer yet. Open Settings → Models to install a local model, sign in to a cloud provider, or enable Apple Intelligence on macOS 26+."
        case .authFailure:
            return "The provider rejected your credentials. Open Settings → AI to re-authenticate."
        case .rateLimited:
            return "The provider is rate-limiting requests. Wait a moment and try again, or switch to a different model in the picker."
        case .providerUnreachable:
            return "Couldn't reach the provider. Check your internet connection and try again."
        case .timedOut:
            return "The request timed out. Try again, or pick a faster model."
        case .contextOverflow:
            return "This conversation is longer than the model can hold. Start a new chat or switch to a model with a larger context window."
        case .cancelled:
            return "Stopped."
        case .generic:
            return fallback.isEmpty ? "Something went wrong. Please try again." : fallback
        }
    }

    static func message(from error: Error) -> String {
        // PipelineError.analysisFailure carries its own message — preserve
        // it verbatim instead of replacing with a generic classification.
        if case let PipelineError.analysisFailure(msg) = error {
            return msg
        }
        let underlying = (error as NSError).localizedDescription
        let normalizedUnderlying = underlying.lowercased()
        if normalizedUnderlying == BackendRuntimeContractError.policyDenied.rawValue
            || normalizedUnderlying.contains("policy_denied")
            || normalizedUnderlying.contains("policy denied") {
            return "This turn was blocked because tools or restricted actions were not available here. Try Tools/Agent mode for tool use, or ask again in plain chat."
        }
        let kind = classify(error)
        if kind == .generic {
            return message(for: .generic, fallback: underlying)
        }
        return message(for: kind)
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
        executionPlan: OverseerComplexityRouter.ExecutionPlan? = nil,
        toolEventHandler: (@MainActor @Sendable (PipelineToolEvent) -> Void)? = nil,
        toolApprovalHandler: (@MainActor @Sendable (AgentPermissionRequest) async -> Bool)? = nil,
        modelInputCaptureHandler: (@MainActor @Sendable (CapturedModelInput) -> Void)? = nil
    ) -> AsyncThrowingStream<PipelineEvent, Error> {
        let _ = (mode, llmService, inference, eventBus)
        let runID = UUID()
        supersedeActiveRun(with: runID)

        let finisher = FinishOnce()

        return AsyncThrowingStream(
            bufferingPolicy: .bufferingNewest(StreamingBufferPolicy.textLimit)
        ) { (continuation: AsyncThrowingStream<PipelineEvent, Error>.Continuation) in
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

                    let effectiveChatSelection = inference.effectiveChatSurfaceSelection(
                        for: operatingMode
                    )

                    let useToolLoop = shouldUseToolLoop(
                        operatingMode: operatingMode,
                        executionPlan: executionPlan,
                        effectiveChatSelection: effectiveChatSelection
                    )
                    let isLocalModelSelected: Bool = {
                        if case .localMLX = effectiveChatSelection { return true }
                        return false
                    }()
                    var emittedVisibleText = ""

                    if useToolLoop,
                       isLocalModelSelected,
                       let localClient = localModelClient {
                        let vaultPath = resolvedManagedToolRuntimeVaultPath()
                        var streamedToolLoopText = ""
                        // Tool-enabled local path: LocalAgentLoop handles
                        // multi-turn tool execution via the Rust FFI.
                        let toolLoopOutput = try await runToolLoop(
                            runID: runID,
                            query: query,
                            notesContext: notesContext,
                            conversationHistory: conversationHistory,
                            operatingMode: operatingMode,
                            executionPlan: executionPlan,
                            vaultPath: vaultPath,
                            localClient: localClient,
                            toolEventHandler: toolEventHandler,
                            toolApprovalHandler: toolApprovalHandler,
                            modelInputCaptureHandler: modelInputCaptureHandler,
                            onToken: { token in
                                streamedToolLoopText += token
                                continuation.yield(.textDelta(token))
                            }
                        )
                        let reconciledToolLoopOutput = Self.reconcileToolLoopVisibleText(
                            streamedText: streamedToolLoopText,
                            finalOutput: toolLoopOutput
                        )
                        emittedVisibleText = reconciledToolLoopOutput.completedText
                        if let missingDelta = reconciledToolLoopOutput.missingDelta {
                            continuation.yield(.textDelta(missingDelta))
                        }
                    } else {
                        // Legacy direct-stream path (cloud models in non-agent
                        // mode, or when localClient / vault aren't available).
                        let directStream = generateDirectStream(
                            query: query,
                            notesContext: notesContext,
                            conversationHistory: conversationHistory,
                            operatingMode: operatingMode,
                            executionPlan: executionPlan,
                            modelInputCaptureHandler: modelInputCaptureHandler,
                            reasoningEventHandler: { delta in
                                continuation.yield(.thinkingDelta(delta))
                            }
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
                    continuation.yield(.error(UserFacingChatError.message(from: error)))
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
        executionPlan: OverseerComplexityRouter.ExecutionPlan?,
        effectiveChatSelection: ChatModelSelection
    ) -> Bool {
        guard case .localMLX = effectiveChatSelection else {
            return false
        }

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

        // Keep standard local chat simple and fast. Only the explicit
        // overseer/agent route should opt into the local tool loop.
        return false
    }

    private func resolvedManagedToolRuntimeVaultPath() -> String {
        FoundationSafety.managedToolRuntimeVaultDirectory(
            preferredVaultPath: vaultPathProvider()
        ).path
    }

    nonisolated static func reconcileToolLoopVisibleText(
        streamedText: String,
        finalOutput: String
    ) -> (completedText: String, missingDelta: String?) {
        let trimmedStreamedText = streamedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFinalOutput = finalOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedStreamedText.isEmpty {
            return (
                completedText: finalOutput,
                missingDelta: trimmedFinalOutput.isEmpty ? nil : finalOutput
            )
        }

        if trimmedFinalOutput.isEmpty {
            return (completedText: streamedText, missingDelta: nil)
        }

        return (completedText: finalOutput, missingDelta: nil)
    }

    /// Tool-enabled local-model path. Builds a tier-filtered tool registry
    /// via the Rust FFI, then drives a LocalAgentLoop with the incoming
    /// query. Tokens are forwarded to the caller via `onToken`.
    private func runToolLoop(
        runID: UUID,
        query: String,
        notesContext: String?,
        conversationHistory: String?,
        operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?,
        vaultPath: String,
        localClient: any LocalConfigurableLLMClient,
        toolEventHandler: (@MainActor @Sendable (PipelineToolEvent) -> Void)?,
        toolApprovalHandler: (@MainActor @Sendable (AgentPermissionRequest) async -> Bool)?,
        modelInputCaptureHandler: (@MainActor @Sendable (CapturedModelInput) -> Void)?,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let tier = Self.localToolTier(
            for: operatingMode,
            executionPlan: executionPlan
        )
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
                executionPlan: executionPlan,
                modelInputCaptureHandler: modelInputCaptureHandler
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
        let objective = Self.buildPromptEnvelope(
            query: query,
            notesContext: notesContext,
            conversationHistory: conversationHistory
        )
        let additionalSystemPrompt = executionPlan?.additionalSystemPrompt()

        let reasoningMode: LocalReasoningMode = switch operatingMode {
        case .thinking: .thinking
        case .pro:      .thinking
        default:        .fast
        }

        let modelID: String? = {
            if executionPlan?.forcesLocalExecution == true {
                return inference.effectiveLocalAgentTextModelID
            }
            if case .localMLX(let id) = inference.preferredChatModelSelection,
               let model = LocalTextModelID(rawValue: id),
               model.canRunLocalAgentLoop {
                return id
            }
            return inference.effectiveLocalAgentTextModelID
        }()
        let executorBridge = ToolTierBridge(
            vaultPath: vaultPath,
            tier: tier,
            allowedToolNames: Set(tools.map(\.name))
        )
        let toolMetadataByName = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        let loop = LocalAgentLoop.liveLoop(
            using: localClient,
            constrainedDecoding: constrainedDecoding,
            toolExecutor: observedToolExecutor(
                executorBridge.toolExecutor(),
                toolMetadataByName: toolMetadataByName,
                toolEventHandler: toolEventHandler,
                toolApprovalHandler: toolApprovalHandler,
                runID: runID.uuidString,
                actor: .agent(id: "pipeline-service", modelID: modelID)
            ),
            modelID: modelID,
            steeringHintsJSON: executionPlan?.steeringHintsJSON,
            defaultReasoningMode: reasoningMode
        )

        Log.pipeline.info(
            "🔧 Tool loop starting — tier=\(tier.rawValue) tools=\(tools.count) mode=\(String(describing: operatingMode))"
        )

        emitCapturedModelInput(
            systemPrompt: additionalSystemPrompt,
            userPrompt: objective,
            conversationHistory: conversationHistory,
            operatingMode: operatingMode,
            toolDefinitionsJSON: Self.encodedToolDefinitionsJSON(tools),
            handler: modelInputCaptureHandler
        )

        let result = try await loop.run(
            objective: objective,
            tools: tools,
            maxTurns: 6,
            reasoningMode: reasoningMode,
            additionalSystemPrompt: additionalSystemPrompt,
            reflexMode: true,
            onToken: { token in
                Task { @MainActor in
                    onToken(token)
                }
            }
        )
        return result
    }

    func observedToolExecutor(
        _ baseExecutor: @escaping LocalAgentToolExecutor,
        toolMetadataByName: [String: OmegaToolDefinition] = [:],
        toolEventHandler: (@MainActor @Sendable (PipelineToolEvent) -> Void)?,
        toolApprovalHandler: (@MainActor @Sendable (AgentPermissionRequest) async -> Bool)? = nil,
        runID: String? = nil,
        traceID: String? = nil,
        actor: AgentProvenanceActor = .system,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil
    ) -> LocalAgentToolExecutor {
        let toolProvenanceRecorder = agentProvenanceRecorder ?? AgentToolProvenanceRecorder()
        let normalizedRunID = runID?.trimmingCharacters(in: .whitespacesAndNewlines)

        return { name, argumentsJson in
            let callID = UUID().uuidString
            let startedAt = Date()
            let metadata = toolMetadataByName[name]
            let permissionRequest = AgentPermissionRequest(
                id: callID,
                toolName: name,
                inputJson: argumentsJson,
                riskLevel: Self.pipelineToolRiskLevel(for: metadata),
                description: "Local tool execution requested \(name)."
            )

            func recordAgentToolEvent(
                kind: AgentProvenanceEventKind,
                status: AgentToolEventStatus,
                resultJson: String? = nil,
                durationMs: UInt64? = nil,
                approvalID: String? = nil,
                errorMessage: String? = nil,
                metadata: [String: String] = [:]
            ) async {
                guard let normalizedRunID, !normalizedRunID.isEmpty else { return }
                await MainActor.run {
                    _ = toolProvenanceRecorder.recordToolEvent(
                        runID: normalizedRunID,
                        traceID: traceID,
                        kind: kind,
                        actor: actor,
                        toolCallID: callID,
                        toolName: name,
                        argumentsJSON: argumentsJson,
                        resultJSON: resultJson,
                        durationMs: durationMs,
                        approvalID: approvalID,
                        status: status,
                        errorMessage: errorMessage,
                        metadata: metadata
                    )
                }
            }

            await recordAgentToolEvent(
                kind: .toolCallRequested,
                status: .requested,
                approvalID: permissionRequest.id
            )

            await MainActor.run {
                toolEventHandler?(.started(id: callID, name: name, inputJson: argumentsJson))
            }

            if permissionRequest.requiresHumanApproval {
                let approved = await toolApprovalHandler?(permissionRequest) ?? false
                if !approved {
                    let deniedResult = LocalToolResult(
                        toolName: name,
                        resultJson: Self.toolErrorJSON("Tool '\(name)' was denied by the user."),
                        isError: true
                    )
                    let elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
                    let durationMs = UInt64(elapsedSeconds * 1000)
                    await recordAgentToolEvent(
                        kind: .toolCallDenied,
                        status: .denied,
                        resultJson: deniedResult.resultJson,
                        durationMs: durationMs,
                        approvalID: permissionRequest.id,
                        errorMessage: "Tool '\(name)' was denied by the user."
                    )

                    await MainActor.run {
                        toolEventHandler?(
                            .completed(
                                id: callID,
                                name: name,
                                inputJson: argumentsJson,
                                resultJson: deniedResult.resultJson,
                                isError: true,
                                durationMs: durationMs
                            )
                        )
                    }

                    return deniedResult
                }
            }

            await recordAgentToolEvent(
                kind: .toolCallApproved,
                status: .approved,
                approvalID: permissionRequest.id,
                metadata: [
                    "approval_required": permissionRequest.requiresHumanApproval ? "true" : "false",
                ]
            )
            await recordAgentToolEvent(
                kind: .toolCallStarted,
                status: .started
            )

            let result = await baseExecutor(name, argumentsJson)
            let elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
            let durationMs = UInt64(elapsedSeconds * 1000)
            await recordAgentToolEvent(
                kind: result.isError ? .toolCallFailed : .toolCallCompleted,
                status: result.isError ? .failed : .completed,
                resultJson: result.resultJson,
                durationMs: durationMs,
                errorMessage: result.isError ? String(result.resultJson.prefix(500)) : nil
            )

            await MainActor.run {
                toolEventHandler?(
                    .completed(
                        id: callID,
                        name: name,
                        inputJson: argumentsJson,
                        resultJson: result.resultJson,
                        isError: result.isError,
                        durationMs: durationMs
                    )
                )
            }

            return result
        }
    }

    nonisolated private static func pipelineToolRiskLevel(
        for tool: OmegaToolDefinition?
    ) -> AgentRuntimeRiskLevel {
        guard let tool else { return .readOnly }
        if tool.destructive {
            return .destructive
        }
        if tool.requiresConfirmation {
            return .modification
        }
        return .readOnly
    }

    nonisolated private static func toolErrorJSON(_ message: String) -> String {
        let payload: [String: Any] = [
            "error": message,
            "success": false,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ),
        let json = String(data: data, encoding: .utf8) else {
            return "{\"error\":\"\(message)\",\"success\":false}"
        }
        return json
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

    nonisolated static func buildPromptEnvelope(
        query: String,
        notesContext: String? = nil,
        conversationHistory: String? = nil
    ) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notesContext?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHistory = conversationHistory?.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasNotes = trimmedNotes?.isEmpty == false
        let hasHistory = trimmedHistory?.isEmpty == false
        guard hasNotes || hasHistory else {
            return trimmedQuery
        }

        var sections: [String] = []
        if let trimmedNotes, !trimmedNotes.isEmpty {
            sections.append(trimmedNotes)
        }
        if let trimmedHistory, !trimmedHistory.isEmpty {
            sections.append("Conversation history:\n\(trimmedHistory)")
        }
        sections.append("Current request:\n\(trimmedQuery)")
        return sections.joined(separator: "\n\n")
    }

    private func generateDirectStream(
        query: String,
        notesContext: String? = nil,
        conversationHistory: String? = nil,
        operatingMode: EpistemosOperatingMode = .fast,
        executionPlan: OverseerComplexityRouter.ExecutionPlan? = nil,
        modelInputCaptureHandler: (@MainActor @Sendable (CapturedModelInput) -> Void)? = nil,
        reasoningEventHandler: (@MainActor @Sendable (String) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        Log.pipeline.info("🔬 generateDirectStream — chatMode=PLAIN queryLen=\(query.count)")

        let finalPrompt = Self.buildPromptEnvelope(
            query: query,
            notesContext: notesContext,
            conversationHistory: conversationHistory
        )

        Log.pipeline.info(
            "🔬 systemPrompt length=0 chars | prompt length=\(finalPrompt.count) chars | hasHistory=\(conversationHistory != nil)"
        )

        // Prepend the capability manifest so non-agent turns (Fast /
        // Thinking mode, local and cloud) have the same identity +
        // app-routes + how-to-act brief the Rust-agent path builds.
        //
        // Tool-contract: this direct-stream path cannot execute app
        // tools (vault_read, fs_read, etc.) — only the Rust agent
        // path and LocalAgentLoop can. We filter app tools out of
        // the manifest (toolExecutionAvailable: false) and skip the
        // overseer-plan tool prompt so the model isn't lied to about
        // tool availability. Provider-native tools (web_search,
        // web_fetch, code_execution, google_search) still work
        // because LLMService wires them directly into the provider
        // request body.
        var systemParts: [String] = []
        if let manifest = buildCapabilityManifest(
            operatingMode: operatingMode,
            executionPlan: executionPlan,
            toolExecutionAvailable: false
        ), !manifest.isEmpty {
            systemParts.append(manifest)
        }
        let systemPrompt: String? = systemParts.isEmpty
            ? nil
            : systemParts.joined(separator: "\n\n")

        emitCapturedModelInput(
            systemPrompt: systemPrompt,
            userPrompt: finalPrompt,
            conversationHistory: conversationHistory,
            operatingMode: operatingMode,
            toolDefinitionsJSON: Self.encodedToolNameJSON(
                inference.capabilityToolNames(
                    for: operatingMode,
                    executionPlan: executionPlan
                )
            ),
            handler: modelInputCaptureHandler
        )

        let effectiveChatSelection = inference.effectiveChatSurfaceSelection(
            for: operatingMode
        )
        let shouldForceDirectLocalStream = executionPlan?.forcesLocalExecution == true
            && {
                switch inference.preferredChatModelSelection {
                case .cloud, .appleIntelligence:
                    return false
                case .localMLX:
                    if case .localMLX = effectiveChatSelection {
                        return true
                    }
                    return false
                }
            }()

        if shouldForceDirectLocalStream {
            return triageService.streamGeneralLocally(
                prompt: finalPrompt,
                systemPrompt: systemPrompt,
                operation: .chatResponse(query: query),
                contentLength: finalPrompt.count,
                operatingMode: operatingMode,
                localSurface: .miniChat,
                steeringHintsJSON: executionPlan?.steeringHintsJSON,
                reasoningSink: reasoningEventHandler
            )
        }

        return triageService.streamGeneral(
            prompt: finalPrompt,
            systemPrompt: systemPrompt,
            operation: .chatResponse(query: query),
            contentLength: finalPrompt.count,
            operatingMode: operatingMode,
            localSurface: .miniChat,
            steeringHintsJSON: executionPlan?.steeringHintsJSON,
            reasoningSink: reasoningEventHandler
        )
    }

    /// Compose a CapabilityManifestBuilder context from the current
    /// pipeline state + render it to markdown. Local paths get the
    /// compact variant (small-model-friendly); cloud gets the full
    /// manifest. Returns nil if we don't have enough info.
    ///
    /// `toolExecutionAvailable` is false for direct-stream callers
    /// (Fast / Thinking cloud, local non-agent) that can't execute
    /// app tools. When false, app-level tools are filtered out so
    /// the manifest only advertises provider-native tools the request
    /// actually supports (web_search, web_fetch, code_execution,
    /// google_search). This prevents the model from hallucinating
    /// tool calls for vault_read / fs_read / patch etc. that the
    /// runtime can't honor.
    private func buildCapabilityManifest(
        operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?,
        toolExecutionAvailable: Bool = true
    ) -> String? {
        let effectiveSelection = inference.effectiveChatSurfaceSelection(for: operatingMode)
        let providerLabel: String
        let modelLabel: String
        let isLocal: Bool
        switch effectiveSelection {
        case .cloud(let model):
            providerLabel = model.provider.rawValue
            modelLabel = model.vendorModelID
            isLocal = false
        case .localMLX(let modelID):
            providerLabel = "local"
            modelLabel = modelID
            isLocal = true
        case .appleIntelligence:
            providerLabel = "apple"
            modelLabel = "Apple Intelligence"
            isLocal = true
        }

        let allowedNames: [String] = {
            if toolExecutionAvailable {
                return inference.capabilityToolNames(
                    for: operatingMode,
                    executionPlan: executionPlan
                )
            }
            // Direct-stream path: only keep provider-native tools
            // the cloud request actually attaches. App tools would
            // just lie to the model.
            return inference.providerNativeCapabilityToolNameList(
                for: operatingMode
            )
        }()

        let vaultName = vaultPathProvider().flatMap {
            URL(fileURLWithPath: $0).lastPathComponent
        }

        let context = CapabilityManifestBuilder.Context(
            providerLabel: providerLabel,
            modelLabel: modelLabel,
            operatingMode: operatingMode,
            reasoningTier: inference.chatReasoningTier,
            enabledToolNames: allowedNames,
            disabledToolNames: [],
            vaultName: vaultName,
            vaultNoteCount: nil,
            skillNames: [],
            maxContextTokens: 128_000
        )
        let manifest = isLocal
            ? CapabilityManifestBuilder.renderCompact(context)
            : CapabilityManifestBuilder.render(context)
        CapabilityManifestBuilder.persist(manifest)
        return manifest
    }

    private func emitCapturedModelInput(
        systemPrompt: String?,
        userPrompt: String,
        conversationHistory: String?,
        operatingMode: EpistemosOperatingMode,
        toolDefinitionsJSON: String?,
        handler: (@MainActor @Sendable (CapturedModelInput) -> Void)?
    ) {
        guard let handler else { return }
        handler(
            CapturedModelInput(
                runtimeLabel: inference.effectiveModelLabel(for: operatingMode),
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                messageHistory: conversationHistory,
                toolDefinitionsJSON: toolDefinitionsJSON
            )
        )
    }

    static func localToolTier(
        for operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?
    ) -> ChatToolTier {
        let effectiveMode = executionPlan?.allowsToolExecution == true
            ? executionPlan?.localOperatingMode ?? operatingMode
            : operatingMode
        return ChatToolTier.from(operatingMode: effectiveMode)
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

    nonisolated private static func encodedToolDefinitionsJSON(
        _ tools: [OmegaToolDefinition]
    ) -> String? {
        let schemas = tools.map(\.planningSchema)
        guard !schemas.isEmpty else { return nil }
        return encodedJSON(schemas)
    }

    nonisolated private static func encodedToolNameJSON(
        _ toolNames: [String]
    ) -> String? {
        let payload = toolNames.map { ["name": $0] }
        guard !payload.isEmpty else { return nil }
        return encodedJSON(payload)
    }

    nonisolated private static func encodedJSON(
        _ payload: Any
    ) -> String? {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
              ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
