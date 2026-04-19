import AppKit
import Foundation
import SwiftData
import os

// MARK: - Chat Coordinator
// Handles the full chat query lifecycle: user query → pipeline → streaming → persistence.
// Extracted from AppBootstrap+ChatOrchestration, +NotesContext, +Persistence.

@MainActor
final class ChatCoordinator {
    struct ChatReferenceResult: Identifiable, Sendable, Hashable {
        let attachment: ContextAttachment
        let preview: String?

        var id: String { attachment.id }
    }

    struct ReferenceSearchResults: Sendable {
        let notes: [NoteMentionChoice]
        let chats: [ChatReferenceResult]
        let vaultTitle: String?
        let vaultNoteCount: Int
        let isInventoryComplete: Bool
        let query: String
        let indexedMatchedNoteIDs: Set<String>
        let indexedNoteSnippetsByPageID: [String: String]
    }

    struct NotesContextResolution: Sendable {
        let context: String?
        let cleanedQuery: String
        let loadedNoteIds: Set<String>
        let loadedNoteTitles: [String]
    }

    private struct PreparedManifestSearchEntry: Sendable {
        let entry: VaultManifest.ManifestEntry
        let normalizedTitle: String
        let normalizedFolder: String
        let normalizedSnippet: String
        let normalizedTags: [String]
    }

    private struct CachedEmptyManifestSearchResults: Sendable {
        let signature: String
        let limit: Int
        let notes: [NoteMentionChoice]
    }

    struct AttachedContextResolution: Sendable {
        let context: String?
        let cleanedQuery: String
        let loadedNoteIds: Set<String>
        let loadedNoteTitles: [String]
    }

    nonisolated static let allNotesMentionToken = "All Notes"
    nonisolated static let maxFileAttachmentContextBytes = min(FileAttachmentBuilder.maxPreviewBytes, 131_072)
    nonisolated static let maxFileAttachmentContextCharacters = 12_000

    private unowned let bootstrap: AppBootstrap
    private let chatState: ChatState
    private let inferenceState: InferenceState
    private let vaultSync: VaultSyncService
    private let modelContainer: ModelContainer
    private let eventBus: EventBus
    private let llmService: LLMService
    private let notesUI: NotesUIState

    init(
        bootstrap: AppBootstrap,
        chatState: ChatState,
        inferenceState: InferenceState,
        vaultSync: VaultSyncService,
        modelContainer: ModelContainer,
        eventBus: EventBus,
        llmService: LLMService,
        notesUI: NotesUIState
    ) {
        self.bootstrap = bootstrap
        self.chatState = chatState
        self.inferenceState = inferenceState
        self.vaultSync = vaultSync
        self.modelContainer = modelContainer
        self.eventBus = eventBus
        self.llmService = llmService
        self.notesUI = notesUI
    }

    private func fetchAll<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> [T]? {
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.db.error(
                "ChatCoordinator: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> T? {
        fetchAll(descriptor, in: context, label: label)?.first
    }

    private static func fetchAll<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> [T]? {
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.db.error(
                "ChatCoordinator: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private static func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> T? {
        fetchAll(descriptor, in: context, label: label)?.first
    }

    // MARK: - Agent Command Center Submission

    /// Dedicated submission entry point for the Agent Command Center.
    ///
    /// Phase 5 authority boundary (PLAN_V2): Swift parses, the compiler resolves,
    /// the runtime executes. This method:
    ///   1. Assembles an `ACCCommandRequest` from explicit user choices.
    ///   2. Delegates to `CommandCenterRequestCompiler.compile(...)` which owns
    ///      @-mention resolution, runtime fallback, tool-permission resolution,
    ///      and route/policy decisions. Produces a `CompiledCommandCenterRequest`.
    ///   3. Seeds `accState.diagnostics` with the compiled request (so the
    ///      inspector can render requested-vs-resolved truth immediately).
    ///   4. Hands the compiled request to either the Rust agent path or the
    ///      standard pipeline, populating runtime counters from streaming events.
    ///
    /// Writes to `AgentChatState` (NOT main `ChatState`) and populates
    /// `accState.diagnostics` (NOT local AgentChatState fields).
    func handleCommandCenterSubmission(
        query: String,
        slashToken: ParsedSlashToken?,
        mentions: [ACCContextMention],
        toolRestrictions: Set<String>,
        brainOverride: ACCBrainSelection?,
        pipeline: PipelineService,
        agentChat: AgentChatState,
        accState: AgentCommandCenterState
    ) {
        bootstrap.queryTask?.cancel()

        let aiFresh = AppleIntelligenceService.shared.checkAvailability()
        inferenceState.appleIntelligenceAvailable = aiFresh.available
        inferenceState.appleIntelligenceUnavailableReason = aiFresh.reason

        agentChat.startStreaming()
        accState.diagnostics.resetForNewSubmission()
        accState.diagnostics.markCompiling()

        // Build the parsed request from explicit user choices.
        let request = ACCCommandRequest(
            query: query,
            slashToken: slashToken,
            mentions: mentions,
            enabledToolNames: toolRestrictions,
            brainOverride: brainOverride,
            operatingMode: accState.selectedOperatingMode,
            graphContext: accState.pendingGraphChatRequest
        )

        // Capture closures for the compiler's injected dependencies. These keep
        // the compiler free of ChatCoordinator / vaultSync coupling so the
        // eventual port to Rust FFI is localized.
        let vaultSync = bootstrap.vaultSync
        let findNotesByTitle: @Sendable (String) async -> [VaultManifest.ManifestEntry] = { title in
            await vaultSync.findNotesByTitle(title)
        }
        let fetchNoteBodies: @Sendable ([String]) async -> [VaultManifest.NoteBody] = { ids in
            await vaultSync.fetchNoteBodies(ids: ids)
        }
        let searchIndex: @Sendable (String) async -> [String] = { query in
            await vaultSync.searchIndex(query: query)
        }
        let availableBrainsClosure: @MainActor () -> [ACCBrainSelection] = { accState.availableBrains }
        let preferredAutoBrainClosure: @MainActor () -> ACCBrainSelection? = {
            self.currentCommandCenterAutoBrain()
        }
        // Rust owns the tool catalog per PLAN_V2 §3.1 / §4.1. Swift only
        // hands Rust the path to the active vault; Rust builds the
        // canonical `ToolRegistry` at the tier implied by the operating
        // mode inside the compile FFI and derives the catalog there. The
        // old Swift-supplied `availableTools` closure (which was a stale
        // mirror of `OmegaToolRegistry.all`, not the real Rust registry)
        // is retired.
        let vaultPathClosure: @MainActor () -> String = { [weak self] in
            self?.bootstrap.vaultSync.vaultURL?.path ?? ""
        }
        let compiler = CommandCenterRequestCompiler(
            dependencies: CommandCenterRequestCompiler.Dependencies(
                findNotesByTitle: findNotesByTitle,
                fetchNoteBodies: fetchNoteBodies,
                searchIndex: searchIndex,
                availableBrains: availableBrainsClosure,
                preferredAutoBrain: preferredAutoBrainClosure,
                vaultPath: vaultPathClosure
            )
        )

        let conversationHistory: String? = agentChat.messages.isEmpty
            ? nil
            : agentChat.messages.map(\.content).joined(separator: "\n")

        bootstrap.queryTask = Task {
            do {
                let compiled = await compiler.compile(
                    request: request,
                    conversationHistory: conversationHistory
                )

                // Seed the inspector with requested-vs-resolved truth BEFORE
                // any streaming events fire.
                accState.diagnostics.ingestCompiledRequest(compiled)
                agentChat.seedPlanDocument(self.commandCenterPlanDocumentSeed(from: compiled))

                let executionPlan = self.commandCenterExecutionPlan(from: compiled)
                let effectiveOperatingMode = compiled.resolvedExecutionPolicy.effectiveOperatingMode

                accState.diagnostics.markRunning()
                let mode = inferenceState.inferenceMode

                if effectiveOperatingMode == .agent {
                    switch compiled.resolvedRuntime.resolved {
                    case .local(let modelId, _):
                        try await self.runCommandCenterLocalAgentPath(
                            compiled: compiled,
                            localModelID: modelId,
                            conversationHistory: conversationHistory,
                            agentChat: agentChat,
                            accState: accState,
                            executionPlan: executionPlan
                        )
                    case .cloud(let provider, _):
                        try await self.runCommandCenterRustAgentPath(
                            compiled: compiled,
                            providerName: self.resolveRustProviderName(
                                explicitProviderRawValue: provider
                            ),
                            conversationHistory: conversationHistory,
                            agentChat: agentChat,
                            accState: accState,
                            executionPlan: executionPlan
                        )
                    case .appleIntelligence:
                        throw AgentRuntimeError(
                            message: "Apple Intelligence does not support Epistemos agent mode yet. Choose a local or cloud brain, or switch to Fast, Thinking, or Pro."
                        )
                    case .unavailable(let reason):
                        throw AgentRuntimeError(
                            message: "The selected agent brain is unavailable: \(reason)."
                        )
                    }
                } else {
                    // Standard pipeline for fast/thinking/pro — pass resolved
                    // notes context so @-mentions actually reach the model.
                    let stream = pipeline.run(
                        query: compiled.query,
                        mode: mode,
                        notesContext: compiled.notesContext,
                        conversationHistory: conversationHistory,
                        operatingMode: effectiveOperatingMode,
                        executionPlan: executionPlan,
                        toolApprovalHandler: { [weak self] request in
                            guard let self else { return false }
                            guard request.requiresHumanApproval else { return true }
                            return await self.promptForToolApproval(request)
                        }
                    )

                    for try await event in stream {
                        guard !Task.isCancelled else { break }
                        switch event {
                        case .textDelta(let text):
                            agentChat.appendStreamingText(text)
                        case .completed:
                            agentChat.completeProcessing(mode: mode)
                            if let response = agentChat.lastCompletedAssistantResponse {
                                agentChat.absorbAgentResponseIntoPlanDocument(response)
                            }
                            accState.diagnostics.markCompleted(
                                stopReason: "completed",
                                inputTokens: 0,
                                outputTokens: 0
                            )
                        case .error(let msg):
                            let message = UserFacingChatError.message(
                                from: AgentRuntimeError(message: msg)
                            )
                            agentChat.addErrorMessage(message)
                            accState.diagnostics.markFailed(
                                errorClass: .providerFailure,
                                message: message
                            )
                        }
                    }
                }

                // Mirror the final turn count back into agentChat for legacy readers.
                agentChat.agentTurnCount = accState.diagnostics.currentTurn

            } catch is CancellationError {
                agentChat.stopStreaming()
                accState.diagnostics.markCancelled()
            } catch {
                Log.pipeline.error("Command Center submission failed: \(error.localizedDescription)")
                let message = UserFacingChatError.message(from: error)
                agentChat.addErrorMessage(message)
                accState.diagnostics.markFailed(
                    errorClass: .unknown,
                    message: message
                )
            }
        }
    }

    // MARK: - Command Center Agent Path

    /// Execute a compiled Command Center request through the Rust agent loop.
    ///
    /// Every streaming event from the Rust delegate populates
    /// `accState.diagnostics` so the inspector mirrors authoritative runtime
    /// truth. `agentChat` still receives text deltas and tool-use records for
    /// transcript display.
    private func runCommandCenterRustAgentPath(
        compiled: CompiledCommandCenterRequest,
        providerName: String,
        conversationHistory: String?,
        agentChat: AgentChatState,
        accState: AgentCommandCenterState,
        executionPlan: OverseerComplexityRouter.ExecutionPlan
    ) async throws {
        let sessionId = UUID().uuidString
        var receivedAgentContent = false
        var terminalAgentError: AgentRuntimeError?
        var activeToolStarts: [String: (name: String, startedAt: Date)] = [:]

        // Build system prompt from compiled context + plan.
        var systemParts: [String] = []
        systemParts.append("You are Epistemos Agent. Be precise and actionable.")
        if let ctx = compiled.notesContext {
            systemParts.append("Context:\n\(ctx)")
        }
        if let history = conversationHistory {
            systemParts.append("Conversation history:\n\(history)")
        }
        systemParts.append(executionPlan.additionalSystemPrompt())

        let vaultPath = bootstrap.vaultSync.vaultURL?.path ?? ""
        let allowedTools = compiled.allowedToolNames
        // Phase 5 authority: pass the user's explicit per-tool allowlist all
        // the way into the Rust ToolRegistry. The coarse enable_bash /
        // enable_web_search flags remain for backward compatibility with
        // callers that don't populate allowedToolNames, but the explicit
        // allowlist is the authoritative gate on the agent runtime path.
        //
        // Terminal alias (spec note): ACC surfaces terminal tools as
        // `run_command` / `run_persistent`; enable_bash historically gated
        // the legacy `bash` tool. We set enable_bash to true whenever ANY
        // terminal-family tool is allowed so the Rust side doesn't silently
        // drop the registration, then the allowlist narrows it back down.
        let terminalToolNames: Set<String> = ["bash", "run_command", "run_persistent", "terminal"]
        let enableBash = !allowedTools.isDisjoint(with: terminalToolNames)
        let webToolNames: Set<String> = ["web_search", "web", "web_fetch"]
        let enableWebSearch = !allowedTools.isDisjoint(with: webToolNames)
        let toolConfig = ToolConfig(
            vaultPath: vaultPath,
            enableBash: enableBash,
            enableWebSearch: enableWebSearch,
            toolTier: "agent",
            allowedToolNames: Array(allowedTools).sorted()
        )

        let policy = compiled.resolvedExecutionPolicy
        let agentConfig = AgentConfigFFI(
            maxTurns: UInt32(max(1, policy.maxTurns)),
            maxOutputTokens: UInt32(max(1024, policy.maxOutputTokens)),
            contextThreshold: 32000,
            enableThinking: true,
            effort: accState.selectedNativeProviderEffort?.rustValue ?? "medium",
            systemPrompt: systemParts.joined(separator: "\n\n"),
            autoApproveReads: false,
            autoApproveWrites: false,
            promptMode: nil
        )

        var capturedDelegate: StreamingDelegate?
        let stream = AsyncStream<AgentStreamEvent>(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let delegate = StreamingDelegate(continuation: continuation)
            capturedDelegate = delegate
            continuation.onTermination = { @Sendable _ in
                cancelAgentSession(sessionId: sessionId)
            }
            Task.detached {
                do {
                    let _ = try await runAgentSession(
                        sessionId: sessionId,
                        objective: compiled.query,
                        providerName: providerName,
                        toolConfig: toolConfig,
                        agentConfig: agentConfig,
                        delegate: delegate
                    )
                    continuation.finish()
                } catch {
                    continuation.yield(.error(AgentRuntimeError(message: error.localizedDescription)))
                    continuation.finish()
                }
            }
        }

        let accSessionInterval = Log.agentStreaming.beginInterval("accAgentSession")
        for await event in stream {
            switch event {
            case .thinkingDelta:
                Log.agentStreaming.emitEvent("acc.thinkingDelta")

            case .textDelta(let text):
                Log.agentStreaming.emitEvent("acc.textDelta", "\(text.count) chars")
                receivedAgentContent = true
                agentChat.appendStreamingText(text)

            case .toolStarted(let id, let name, let inputJson):
                Log.agentStreaming.emitEvent("acc.toolStarted", "\(name)")
                receivedAgentContent = true
                agentChat.activeToolName = name
                agentChat.isAgentExecuting = true
                agentChat.recordToolUse(id: id, name: name, inputJson: inputJson)
                activeToolStarts[id] = (name, Date())
                accState.diagnostics.recordActiveTool(name: name)

            case .toolCompleted(let id, let result, let isError):
                Log.agentStreaming.emitEvent("acc.toolCompleted", "error=\(isError)")
                receivedAgentContent = true
                agentChat.activeToolName = nil
                agentChat.isAgentExecuting = false
                let startInfo = activeToolStarts.removeValue(forKey: id)
                let durationMs = startInfo.map {
                    UInt64(Date().timeIntervalSince($0.startedAt) * 1000)
                } ?? 0
                agentChat.recordToolResult(
                    toolUseId: id,
                    result: result,
                    isError: isError,
                    durationMs: durationMs
                )
                let record = ACCToolExecutionRecord(
                    id: id,
                    toolName: startInfo?.name ?? "unknown",
                    inputSummary: "",
                    resultSummary: String(result.prefix(200)),
                    durationMs: durationMs,
                    isError: isError
                )
                accState.diagnostics.recordToolExecution(record)
                accState.diagnostics.recordActiveTool(name: nil)

            case .permissionRequired(let request):
                receivedAgentContent = true
                let approved = !request.requiresHumanApproval
                capturedDelegate?.resolvePermission(permissionId: request.id, approved: approved)
                accState.diagnostics.recordPermissionDecision(
                    CommandCenterExecutionDiagnostics.PermissionDecisionRecord(
                        id: request.id,
                        toolName: request.toolName,
                        riskLevel: String(describing: request.riskLevel),
                        decision: approved ? .approvedAutoReadOnly : .deniedByPolicy,
                        at: Date()
                    )
                )

            case .complete(let stopReason, let inputTokens, let outputTokens, _):
                Log.agentStreaming.emitEvent("acc.complete", "\(stopReason)")
                receivedAgentContent = true
                accState.diagnostics.markCompleted(
                    stopReason: stopReason,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens
                )

            case .error(let error):
                Log.agentStreaming.emitEvent("acc.error")
                if receivedAgentContent {
                    let message = UserFacingChatError.message(
                        from: AgentRuntimeError(message: error.message)
                    )
                    agentChat.addErrorMessage(message)
                    accState.diagnostics.markFailed(
                        errorClass: .providerFailure,
                        message: message
                    )
                } else {
                    terminalAgentError = error
                }

            case .turnStarted(let turn, let messageCount):
                Log.agentStreaming.emitEvent("acc.turnStarted", "turn=\(turn)")
                receivedAgentContent = true
                agentChat.agentTurnCount = turn
                accState.diagnostics.recordTurnStarted(turn: turn, messageCount: messageCount)

            case .contextCompacting(let tokens):
                accState.diagnostics.recordContextCompacting(tokens: tokens)

            case .contextCompacted(let messageCount):
                accState.diagnostics.recordContextCompacted(messageCount: messageCount)

            case .subagentSpawned(let id, let role):
                accState.diagnostics.recordSubagentSpawned(id: id, role: role)

            case .toolInputStreaming:
                break
            }
        }
        Log.agentStreaming.endInterval("accAgentSession", accSessionInterval)

        if let err = terminalAgentError {
            throw err
        }
    }

    private func commandCenterExecutionPlan(
        from compiled: CompiledCommandCenterRequest
    ) -> OverseerComplexityRouter.ExecutionPlan {
        let resolvedRoute = OverseerExecutionRoute(
            rawValue: compiled.resolvedExecutionPolicy.route
        ) ?? {
            switch compiled.resolvedExecutionPolicy.effectiveOperatingMode {
            case .agent:
                return compiled.allowedToolNames.isEmpty ? .localOnly : .overseerLocalExecution
            case .pro:
                return .overseerLocalExecution
            case .fast, .thinking:
                return .localOnly
            }
        }()

        let toolPermissions: [OverseerToolPermission] = compiled.resolvedToolPermissions.compactMap { permission in
            guard permission.decision.isAllowed else { return nil }
            return OverseerToolPermission(
                toolName: permission.toolName,
                mode: permission.requiresConfirmation || permission.destructive ? .ask : .allow
            )
        }

        let plan = OverseerPlanV1(
            version: .v1,
            route: resolvedRoute,
            maskPlan: OverseerMaskPlan(
                expertAllowlist: compiled.resolvedExecutionPolicy.expertAllowlist.isEmpty
                    ? ["general"]
                    : compiled.resolvedExecutionPolicy.expertAllowlist,
                rationale: compiled.resolvedExecutionPolicy.summary
            ),
            loraBlendCoefficients: [],
            kvPolicyFlag: .preserveSharedBase,
            depthBudget: OverseerDepthBudget(
                maxTurns: max(1, compiled.resolvedExecutionPolicy.maxTurns),
                maxReasoningSteps: max(1, compiled.resolvedExecutionPolicy.maxReasoningSteps),
                maxToolCalls: max(0, compiled.resolvedExecutionPolicy.maxToolCalls),
                maxOutputTokens: max(1024, compiled.resolvedExecutionPolicy.maxOutputTokens)
            ),
            toolPermissions: toolPermissions,
            contextSummary: OverseerContextSummary(
                summary: compiled.resolvedExecutionPolicy.summary,
                entityIDs: compiled.resolvedNoteIds,
                sourceSessionID: nil
            )
        )

        let finalPlan = (try? plan.validated()) ?? plan.normalized()
        let toolSummary = finalPlan.toolPermissions.prefix(6)
            .map { "\($0.toolName)=\($0.mode.rawValue)" }
            .joined(separator: ",")
        Log.pipeline.info(
            "Overseer: route=\(resolvedRoute.rawValue, privacy: .public) mode=\(compiled.resolvedExecutionPolicy.effectiveOperatingMode.rawValue, privacy: .public) turns=\(finalPlan.depthBudget.maxTurns) tools=\(finalPlan.depthBudget.maxToolCalls) experts=\(finalPlan.maskPlan.expertAllowlist.joined(separator: ","), privacy: .public) toolPerms=[\(toolSummary, privacy: .public)]"
        )
        return OverseerComplexityRouter.ExecutionPlan(
            route: resolvedRoute,
            localOperatingMode: compiled.resolvedExecutionPolicy.effectiveOperatingMode,
            plan: finalPlan,
            summary: compiled.resolvedExecutionPolicy.summary
        )
    }

    private func runCommandCenterLocalAgentPath(
        compiled: CompiledCommandCenterRequest,
        localModelID: String,
        conversationHistory: String?,
        agentChat: AgentChatState,
        accState: AgentCommandCenterState,
        executionPlan: OverseerComplexityRouter.ExecutionPlan
    ) async throws {
        let vaultPath = bootstrap.vaultSync.vaultURL?.path ?? ""
        let tier: ChatToolTier = compiled.allowedToolNames.isEmpty ? .none : .agent
        let bridge = ToolTierBridge(
            vaultPath: vaultPath,
            tier: tier,
            allowedToolNames: compiled.allowedToolNames
        )
        let tools = bridge.loadTools()
        let baseToolExecutor = bridge.toolExecutor()
        let toolMetadataByName = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })

        let objective = [compiled.notesContext, conversationHistory, compiled.query]
            .compactMap { value in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: "\n\n")

        var systemInstructions: [String] = [
            "You are Epistemos Agent. Be precise and actionable.",
            executionPlan.additionalSystemPrompt(),
        ]
        if let slashToken = compiled.requestedSlashToken {
            systemInstructions.append(
                "Requested command: \(slashToken.displayName) (\(slashToken.identifier))."
            )
        }

        let reasoningMode: LocalReasoningMode = switch compiled.resolvedExecutionPolicy.effectiveOperatingMode {
        case .fast:
            .fast
        case .thinking, .pro, .agent:
            .thinking
        }

        let loop = LocalAgentLoop.liveLoop(
            using: bootstrap.localMLXClient,
            constrainedDecoding: bootstrap.constrainedDecoding,
            toolExecutor: { [self] name, argumentsJson in
                let callID = UUID().uuidString
                let startedAt = Date()
                let metadata = toolMetadataByName[name]

                await MainActor.run {
                    agentChat.activeToolName = name
                    agentChat.isAgentExecuting = true
                    agentChat.recordToolUse(id: callID, name: name, inputJson: argumentsJson)
                    accState.diagnostics.recordActiveTool(name: name)
                }

                let permissionRequest = AgentPermissionRequest(
                    id: callID,
                    toolName: name,
                    inputJson: argumentsJson,
                    riskLevel: Self.commandCenterToolRiskLevel(for: metadata),
                    description: "Agent requested \(name) during local agent execution."
                )

                if permissionRequest.requiresHumanApproval {
                    let approved = await self.promptForToolApproval(permissionRequest)
                    await MainActor.run {
                        accState.diagnostics.recordPermissionDecision(
                            CommandCenterExecutionDiagnostics.PermissionDecisionRecord(
                                id: callID,
                                toolName: name,
                                riskLevel: self.riskLabel(for: permissionRequest.riskLevel),
                                decision: approved ? .approvedByUser : .deniedByUser,
                                at: Date()
                            )
                        )
                    }
                    if !approved {
                        let deniedResult = LocalToolResult(
                            toolName: name,
                            resultJson: Self.commandCenterToolErrorJSON(
                                "Tool '\(name)' was denied by the user."
                            ),
                            isError: true
                        )
                        let durationMs = UInt64(Date().timeIntervalSince(startedAt) * 1000)
                        await MainActor.run {
                            agentChat.recordToolResult(
                                toolUseId: callID,
                                result: deniedResult.resultJson,
                                isError: deniedResult.isError,
                                durationMs: durationMs
                            )
                            agentChat.activeToolName = nil
                            agentChat.isAgentExecuting = false
                            accState.diagnostics.recordToolExecution(
                                ACCToolExecutionRecord(
                                    id: callID,
                                    toolName: name,
                                    inputSummary: String(argumentsJson.prefix(200)),
                                    resultSummary: "Denied by user",
                                    durationMs: durationMs,
                                    isError: true
                                )
                            )
                            accState.diagnostics.recordActiveTool(name: nil)
                        }
                        await MainActor.run {
                            self.bootstrap.mcpBridge.logExecution(
                                toolName: name,
                                argumentsJson: argumentsJson,
                                resultJson: deniedResult.resultJson,
                                durationMs: durationMs,
                                success: false
                            )
                        }
                        return deniedResult
                    }
                } else {
                    await MainActor.run {
                        accState.diagnostics.recordPermissionDecision(
                            CommandCenterExecutionDiagnostics.PermissionDecisionRecord(
                                id: callID,
                                toolName: name,
                                riskLevel: self.riskLabel(for: permissionRequest.riskLevel),
                                decision: .approvedAutoReadOnly,
                                at: Date()
                            )
                        )
                    }
                }

                let result = await baseToolExecutor(name, argumentsJson)
                let durationMs = UInt64(Date().timeIntervalSince(startedAt) * 1000)
                await MainActor.run {
                    agentChat.recordToolResult(
                        toolUseId: callID,
                        result: result.resultJson,
                        isError: result.isError,
                        durationMs: durationMs
                    )
                    agentChat.activeToolName = nil
                    agentChat.isAgentExecuting = false
                    accState.diagnostics.recordToolExecution(
                        ACCToolExecutionRecord(
                            id: callID,
                            toolName: name,
                            inputSummary: String(argumentsJson.prefix(200)),
                            resultSummary: String(result.resultJson.prefix(200)),
                            durationMs: durationMs,
                            isError: result.isError
                        )
                    )
                    accState.diagnostics.recordActiveTool(name: nil)
                }
                await MainActor.run {
                    self.bootstrap.mcpBridge.logExecution(
                        toolName: name,
                        argumentsJson: argumentsJson,
                        resultJson: result.resultJson,
                        durationMs: durationMs,
                        success: !result.isError
                    )
                }
                return result
            },
            modelID: localModelID,
            steeringHintsJSON: executionPlan.steeringHintsJSON,
            maxResponseTokens: max(1024, compiled.resolvedExecutionPolicy.maxOutputTokens),
            defaultReasoningMode: reasoningMode
        )

        accState.diagnostics.recordTurnStarted(
            turn: 1,
            messageCount: max(1, agentChat.messages.count)
        )

        let output = try await loop.run(
            objective: objective,
            tools: tools,
            maxTurns: max(1, compiled.resolvedExecutionPolicy.maxTurns),
            reasoningMode: reasoningMode,
            additionalSystemPrompt: systemInstructions.joined(separator: "\n\n"),
            onToken: { token in
                agentChat.appendStreamingText(token)
            }
        )

        accState.diagnostics.markCompleted(
            stopReason: output.isEmpty ? "completed_empty" : "completed",
            inputTokens: LocalAgentLoop.approximateTokenCount(of: objective),
            outputTokens: LocalAgentLoop.approximateTokenCount(of: output)
        )
        agentChat.completeProcessing(mode: inferenceState.inferenceMode)
        if let response = agentChat.lastCompletedAssistantResponse {
            agentChat.absorbAgentResponseIntoPlanDocument(response)
        }
    }

    private func commandCenterPlanDocumentSeed(
        from compiled: CompiledCommandCenterRequest
    ) -> AgentPlanDocumentSeed {
        AgentPlanDocumentSeed(
            query: compiled.query,
            summary: compiled.resolvedExecutionPolicy.summary,
            operatingMode: compiled.resolvedExecutionPolicy.effectiveOperatingMode.displayName,
            route: commandCenterRouteLabel(compiled.resolvedExecutionPolicy.route),
            experts: compiled.resolvedExecutionPolicy.expertAllowlist,
            budgets: [
                AgentPlanDocumentBudget(label: "Turns", value: compiled.resolvedExecutionPolicy.maxTurns),
                AgentPlanDocumentBudget(label: "Tool calls", value: compiled.resolvedExecutionPolicy.maxToolCalls),
                AgentPlanDocumentBudget(label: "Reasoning steps", value: compiled.resolvedExecutionPolicy.maxReasoningSteps),
                AgentPlanDocumentBudget(label: "Output tokens", value: compiled.resolvedExecutionPolicy.maxOutputTokens),
            ]
        )
    }

    private func commandCenterRouteLabel(_ route: String) -> String {
        switch route {
        case "local_only":
            "Local Only"
        case "overseer_local_execution":
            "Overseer (Local)"
        case "managed_agent_session":
            "Managed Agent"
        default:
            route
        }
    }

    private func currentCommandCenterAutoBrain() -> ACCBrainSelection? {
        switch inferenceState.preferredChatModelSelection {
        case .localMLX(let requestedModelID):
            let effectiveModelID = inferenceState.effectiveLocalAgentTextModelID
                ?? inferenceState.effectiveLocalTextModelID
                ?? requestedModelID
            guard let model = LocalTextModelID(rawValue: effectiveModelID) else {
                return nil
            }
            return .local(
                modelId: model.rawValue,
                displayName: model.compactDisplayName,
                supportsThinking: model.supportsThinkingMode,
                supportsVision: model.supportsVision,
                supportsTools: model.supportsNativeToolCalling
            )
        case .appleIntelligence:
            return inferenceState.appleIntelligenceAvailable ? .appleIntelligence : nil
        case .cloud(let model):
            return .cloud(provider: model.provider)
        }
    }

    // MARK: - Query Lifecycle

    /// Process a user query through the direct local answer path, streaming tokens back to ChatState.
    func handleQuery(
        _ query: String,
        pipeline: PipelineService,
        chatState: ChatState,
        operatingMode: EpistemosOperatingMode
    ) {
        bootstrap.queryTask?.cancel()

        let aiFresh = AppleIntelligenceService.shared.checkAvailability()
        inferenceState.appleIntelligenceAvailable = aiFresh.available
        inferenceState.appleIntelligenceUnavailableReason = aiFresh.reason

        let isVaultBriefing = query == "[VAULT_BRIEFING]"
        chatState.isCurrentVaultBriefing = isVaultBriefing
        chatState.startStreaming()

        bootstrap.queryTask = Task {
            do {
                let mode = inferenceState.inferenceMode
                let hasVault = bootstrap.ambientManifest != nil
                Log.pipeline.info("handleQuery — hasVault=\(hasVault)")

                // Wire active session ID and vault root to MLX inference for SSM state scoping
                let sessionID = chatState.activeChatId ?? UUID().uuidString
                await bootstrap.localInferenceService.setActiveSessionID(sessionID)
                if let vaultURL = bootstrap.vaultSync.vaultURL {
                    await bootstrap.localInferenceService.setActiveVaultRoot(vaultURL)
                }

                // Sync context window size from active model
                chatState.maxContextTokens = inferenceState.chatSurfaceMaxContextTokens(
                    for: operatingMode
                )
                chatState.recalculateContextEstimate()

                let hasExplicitContext = Self.queryContainsExplicitContext(
                    query,
                    attachments: chatState.pendingContextAttachments
                )
                let notesContext: String?
                let resolvedQuery: String
                if hasVault, hasExplicitContext {
                    let (ctx, cleaned) = await self.buildContextAttachments(
                        query: query,
                        attachments: chatState.pendingContextAttachments,
                        chatState: chatState
                    )
                    notesContext = ctx
                    resolvedQuery = cleaned
                } else {
                    notesContext = nil
                    resolvedQuery = query
                    chatState.loadedNoteIds = []
                    chatState.loadedNoteTitles = []
                }

                let userAttachments = chatState.messages.last(where: { $0.role == .user })?.attachments ?? []
                let hasExplicitUserContext = hasExplicitContext || !userAttachments.isEmpty
                let supportsVision = inferenceState.chatSurfaceSupportsVision(
                    for: operatingMode
                )
                let fileAttachmentContext = Self.buildFileAttachmentContext(
                    from: userAttachments,
                    supportsVision: supportsVision
                )
                let requiredContextContract = hasExplicitUserContext
                    ? Self.buildRequiredAttachmentContractSection()
                    : nil

                // Extract image URLs for vision-capable models
                if supportsVision {
                    inferenceState.pendingImageURLs = userAttachments
                        .filter { $0.type == .image }
                        .compactMap { Self.resolvedFileAttachmentURL(from: $0.uri) }
                } else {
                    inferenceState.pendingImageURLs = []
                }

                // For vault briefing, override notesContext with full manifest (includes bodies)
                let effectiveNotesContext: String?
                let effectiveQuery: String
                if isVaultBriefing {
                    effectiveNotesContext = Self.mergedContextSections(
                        requiredContextContract,
                        chatState.vaultBriefingManifest?.asContext(),
                        notesContext,
                        fileAttachmentContext
                    )
                    chatState.vaultBriefingManifest = nil  // Consumed — free memory
                    effectiveQuery = "Analyze my vault and provide a briefing: find cross-note connections, recurring themes, contradictions, topic gaps, stale notes worth revisiting, and notes that could be merged or split. Be specific — reference notes by title."
                } else {
                    effectiveNotesContext = Self.mergedContextSections(
                        requiredContextContract,
                        notesContext,
                        fileAttachmentContext
                    )
                    effectiveQuery = resolvedQuery
                }

                // Always inject lightweight workspace context (open notes + recent edits).
                // For explicit session queries, inject deep context (full previews + chat history).
                let isSessionQuery = Self.queryRequestsSessionContext(effectiveQuery)
                let shouldInjectWorkspaceContext = isSessionQuery || !hasExplicitUserContext
                let workspaceContextSection: String?
                if shouldInjectWorkspaceContext {
                    let workspaceContext = Self.buildWorkspaceAwarenessContext(
                        bootstrap: bootstrap,
                        deepContext: isSessionQuery
                    )
                    workspaceContextSection = Self.wrapSupplementalContextSection(
                        title: "Workspace Awareness",
                        instruction: "Treat this as optional background. Use it only when it helps answer the request, and let explicit user attachments take priority.",
                        body: workspaceContext
                    )
                } else {
                    workspaceContextSection = nil
                }
                let effectiveNotesContextWithWorkspace: String?
                if let workspaceContextSection {
                    if let enc = effectiveNotesContext {
                        effectiveNotesContextWithWorkspace = enc + "\n\n" + workspaceContextSection
                    } else {
                        effectiveNotesContextWithWorkspace = workspaceContextSection
                    }
                } else {
                    effectiveNotesContextWithWorkspace = effectiveNotesContext
                }

                // Build conversation history for multi-turn context.
                // Budget: use at most 20% of the model's context window for history,
                // leaving room for system prompt, notes context, and response.
                let conversationHistory: String?
                let priorMessages = chatState.messages.dropLast()
                if !priorMessages.isEmpty && !isVaultBriefing {
                    let historyBudgetChars = chatState.maxContextTokens * 4 / 5  // ~20% of context (4 chars ≈ 1 token)
                    let maxMessagesForModel = min(20, max(4, chatState.maxContextTokens / 8_000))
                    let recent = priorMessages.suffix(maxMessagesForModel)
                    var lines: [String] = []
                    var charCount = 0
                    for msg in recent.reversed() {
                        let role: String = msg.role == .user ? "User" : "Assistant"
                        let maxChars = min(2000, historyBudgetChars / max(1, recent.count))
                        let content: String = msg.content.count > maxChars
                            ? String(msg.content.prefix(maxChars)) + "…"
                            : msg.content
                        let line = role + ": " + content
                        if charCount + line.count > historyBudgetChars { break }
                        charCount += line.count
                        lines.insert(line, at: 0)
                    }
                    conversationHistory = lines.isEmpty ? nil : lines.joined(separator: "\n\n")
                } else {
                    conversationHistory = nil
                }

                let pendingAssistantId = UUID().uuidString
                let capturedChatId = chatState.activeChatId
                let executionPlan = await buildOverseerExecutionPlan(
                    query: effectiveQuery,
                    contentLength: effectiveQuery.count
                        + (effectiveNotesContextWithWorkspace?.count ?? 0)
                        + (conversationHistory?.count ?? 0),
                    operatingMode: operatingMode,
                    hasExplicitContext: hasExplicitUserContext,
                    attachmentCount: userAttachments.count + chatState.pendingContextAttachments.count,
                    notesContext: effectiveNotesContextWithWorkspace,
                    conversationHistory: conversationHistory
                )

                // Record the Overseer decision for Settings → Overseer
                // transparency. Read-only audit trail, capped at the last
                // ten turns. Done on MainActor because OverseerAuditState
                // is @MainActor @Observable.
                if let executionPlan {
                    await MainActor.run {
                        AppBootstrap.shared?.overseerAuditState.record(
                            turnID: pendingAssistantId,
                            objective: query,
                            plan: executionPlan
                        )
                    }
                }

                // Route: managed-agent sessions escalate to Rust agent_core,
                // while local-only and overseer-local plans stay on the Swift
                // pipeline with an explicit local execution plan.
                var usedRustAgent = false
                if let executionPlan, mode == .api, operatingMode == .agent {
                    switch executionPlan.route {
                    case .managedAgentSession:
                        do {
                            try await self.runRustAgentPath(
                                query: effectiveQuery,
                                notesContext: effectiveNotesContextWithWorkspace,
                                conversationHistory: conversationHistory,
                                chatState: chatState,
                                chatId: capturedChatId,
                                originalQuery: query,
                                hasVault: hasVault,
                                pendingAssistantId: pendingAssistantId,
                                executionPlan: executionPlan
                            )
                            usedRustAgent = true
                        } catch {
                            Log.pipeline.warning("Managed agent path unavailable, falling back to local execution: \(error.localizedDescription)")
                        }
                    case .localOnly, .overseerLocalExecution:
                        break
                    }
                }

                if !usedRustAgent {
                    let stream = pipeline.run(
                        query: effectiveQuery,
                        mode: mode,
                        notesContext: effectiveNotesContextWithWorkspace,
                        conversationHistory: conversationHistory,
                        operatingMode: executionPlan?.localOperatingMode ?? operatingMode,
                        executionPlan: executionPlan,
                        toolEventHandler: { event in
                            switch event {
                            case .started(let id, let name, let inputJson):
                                chatState.activeToolName = name
                                chatState.isAgentExecuting = true
                                chatState.recordToolUse(id: id, name: name, inputJson: inputJson)

                            case .completed(
                                let id,
                                let name,
                                let inputJson,
                                let resultJson,
                                let isError,
                                let durationMs
                            ):
                                chatState.activeToolName = nil
                                chatState.isAgentExecuting = false
                                chatState.recordToolResult(
                                    toolUseId: id,
                                    result: resultJson,
                                    isError: isError
                                )
                                self.bootstrap.mcpBridge.logExecution(
                                    toolName: name,
                                    argumentsJson: inputJson,
                                    resultJson: resultJson,
                                    durationMs: durationMs,
                                    success: !isError
                                )
                            }
                        },
                        toolApprovalHandler: { [weak self] request in
                            guard let self else { return false }
                            guard request.requiresHumanApproval else { return true }
                            return await self.promptForToolApproval(request)
                        }
                    )

                    for try await event in stream {
                        switch event {
                        case .textDelta(let token):
                            chatState.appendStreamingText(token)

                        case .completed:
                            chatState.completeProcessing(
                                messageId: pendingAssistantId,
                                mode: mode
                            )
                            chatState.recalculateContextEstimate()

                            if let lastMsg = chatState.messages.last {
                                let processed = self.executeVaultActions(in: lastMsg.content)
                                if processed != lastMsg.content {
                                    chatState.updateLastMessageContent(processed)
                                }
                            }

                            eventBus.emit(.pipelineComplete)

                            if !chatState.isIncognito {
                                self.persistChatCompletion(
                                    chatId: capturedChatId,
                                    query: query,
                                    answer: chatState.messages.last?.content ?? "",
                                    mode: mode,
                                    assistantMessage: chatState.messages.last,
                                    isNotes: hasVault
                                )
                            }

                            if chatState.chatTitle == nil {
                                self.generateChatTitle(query: query, chatId: capturedChatId, chatState: chatState)
                            }

                        case .error(let msg):
                            chatState.addErrorMessage(
                                UserFacingChatError.message(
                                    from: AgentRuntimeError(message: msg)
                                )
                            )
                        }
                    }
                }
            } catch is CancellationError {
                _ = chatState.completeCancelledProcessing(mode: inferenceState.inferenceMode)
            } catch {
                chatState.addErrorMessage(UserFacingChatError.message(from: error))
            }
            inferenceState.pendingImageURLs = []
        }
    }

    // MARK: - Rust Agent Core Path (Goose-Style Autonomous Loop)

    /// Routes cloud queries through the Rust agent_core for full autonomous tool execution.
    /// The Rust loop handles: provider routing, tool calling, context compaction, security scanning.
    private func runRustAgentPath(
        query: String,
        notesContext: String?,
        conversationHistory: String?,
        chatState: ChatState,
        chatId: String?,
        originalQuery: String,
        hasVault: Bool,
        pendingAssistantId: String,
        executionPlan: OverseerComplexityRouter.ExecutionPlan
    ) async throws {
        let sessionId = UUID().uuidString
        let parentSessionID = AgentSessionLineageStore.shared.parentSessionID(forChatThread: chatId)
        var receivedAgentContent = false
        var terminalAgentError: AgentRuntimeError?

        // Build system prompt with context
        var systemParts: [String] = []
        systemParts.append("You are Epistemos, an intelligent knowledge assistant. Be concise and actionable.")
        if let ctx = notesContext {
            systemParts.append("Context from the user's vault:\n\(ctx)")
        }
        if let history = conversationHistory {
            systemParts.append("Conversation history:\n\(history)")
        }
        systemParts.append(executionPlan.additionalSystemPrompt())

        // Resolve provider name from current inference configuration
        let providerName = resolveRustProviderName()

        let vaultPath = bootstrap.vaultSync.vaultURL?.path ?? ""
        let toolConfig = ToolConfig(
            vaultPath: vaultPath,
            enableBash: true,
            enableWebSearch: true,
            toolTier: "agent",
            // Main chat path has no per-tool UI — tier is the only gate.
            allowedToolNames: nil
        )

        let agentConfig = AgentConfigFFI(
            maxTurns: 25,
            maxOutputTokens: 16384,
            contextThreshold: UInt32(chatState.maxContextTokens),
            enableThinking: true,
            effort: "medium",
            systemPrompt: systemParts.joined(separator: "\n\n"),
            autoApproveReads: false,
            autoApproveWrites: false,
            promptMode: nil  // auto-detect from objective keywords
        )

        // Create async stream via StreamingDelegate — capture delegate for approval resolution
        var capturedDelegate: StreamingDelegate?
        let stream = AsyncStream<AgentStreamEvent>(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let delegate = StreamingDelegate(continuation: continuation)
            capturedDelegate = delegate
            continuation.onTermination = { @Sendable _ in
                cancelAgentSession(sessionId: sessionId)
            }

            Task.detached {
                do {
                    let result = try await runAgentSession(
                        sessionId: sessionId,
                        objective: query,
                        providerName: providerName,
                        toolConfig: toolConfig,
                        agentConfig: agentConfig,
                        delegate: delegate
                    )
                    EventStore.shared?.saveSessionMetrics(
                        sessionId: sessionId,
                        metrics: result.trajectoryMetrics
                    )
                } catch {
                    continuation.yield(.error(AgentRuntimeError(message: error.localizedDescription)))
                    continuation.finish()
                }
            }
        }

        // Process the agent stream
        for await event in stream {
            switch event {
            case .thinkingDelta(let thought):
                // Route live thinking into chat.streamingThinking so the
                // ThinkingPopoverView can render in-flight reasoning.
                chatState.appendStreamingThinking(thought)

            case .textDelta(let text):
                receivedAgentContent = true
                chatState.appendStreamingText(text)

            case .toolStarted(let id, let name, let inputJson):
                receivedAgentContent = true
                chatState.activeToolName = name
                chatState.isAgentExecuting = true
                chatState.recordToolUse(id: id, name: name, inputJson: inputJson)

            case .toolCompleted(let id, let result, let isError):
                receivedAgentContent = true
                chatState.activeToolName = nil
                chatState.isAgentExecuting = false
                chatState.recordToolResult(toolUseId: id, result: result, isError: isError)

            case .permissionRequired(let request):
                receivedAgentContent = true
                let approved: Bool
                if request.requiresHumanApproval {
                    chatState.appendStreamingText(
                        "\n> **Approval required:** \(request.toolName) (\(request.approvalReason))\n"
                    )
                    approved = await promptForToolApproval(request)
                    if !approved {
                        chatState.appendStreamingText("\n> **Denied:** \(request.toolName)\n")
                    }
                } else {
                    approved = true
                }
                capturedDelegate?.resolvePermission(permissionId: request.id, approved: approved)

            case .complete(_, let inputTokens, let outputTokens, _):
                receivedAgentContent = true
                chatState.completeProcessing(
                    messageId: pendingAssistantId,
                    mode: .api
                )

                if let lastMsg = chatState.messages.last {
                    let processed = self.executeVaultActions(in: lastMsg.content)
                    if processed != lastMsg.content {
                        chatState.updateLastMessageContent(processed)
                    }
                }

                eventBus.emit(.pipelineComplete)
                Log.pipeline.info("Agent session complete: \(inputTokens)in/\(outputTokens)out")

                // Phase 4: Generate session knowledge graph in background
                if let folderPath = sessionFolderPath(sessionId: sessionId) {
                    do {
                        try AgentSessionLineageStore.shared.recordCompletedSession(
                            sessionID: sessionId,
                            chatThreadID: chatId,
                            sessionFolderPath: folderPath
                        )
                    } catch {
                        Log.pipeline.error(
                            "Failed to persist agent session lineage: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                    Task.detached(priority: .utility) {
                        let lifecycle = VaultLifecycleService(vaultPath: vaultPath)
                        await lifecycle.generateGraphForSession(sessionFolderPath: folderPath)
                    }
                }

                if !chatState.isIncognito {
                    self.persistChatCompletion(
                        chatId: chatId,
                        query: originalQuery,
                        answer: chatState.messages.last?.content ?? "",
                        mode: .api,
                        assistantMessage: chatState.messages.last,
                        isNotes: hasVault
                    )
                }

                if chatState.chatTitle == nil {
                    self.generateChatTitle(query: originalQuery, chatId: chatId, chatState: chatState)
                }

            case .error(let error):
                if receivedAgentContent {
                    chatState.addErrorMessage(
                        UserFacingChatError.message(from: AgentRuntimeError(message: error.message))
                    )
                } else {
                    terminalAgentError = error
                }

            case .turnStarted(let turn, _):
                receivedAgentContent = true
                chatState.agentTurnCount = turn

                // Periodic memory nudge: every 15 turns, prompt the agent
                // to reflect on what's worth persisting to memory
                if turn > 0 && turn % 15 == 0 {
                    chatState.appendStreamingText(
                        "\n> *[System: Reflect on this session — is there anything worth adding to persistent memory? Use the memory tool if so.]*\n"
                    )
                }

            case .contextCompacting:
                receivedAgentContent = true
                chatState.appendStreamingText("\n> *Compacting context...*\n")

            case .toolInputStreaming, .subagentSpawned, .contextCompacted:
                break
            }
        }

        if let terminalAgentError {
            if let folderPath = sessionFolderPath(sessionId: sessionId) {
                do {
                    try AgentSessionLineageStore.writeMetadata(
                        sessionFolderPath: folderPath,
                        parentSessionID: parentSessionID,
                        chatThreadID: chatId
                    )
                } catch {
                    Log.pipeline.error(
                        "Failed to persist failed-session lineage: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
            throw terminalAgentError
        }
    }

    /// Maps the current cloud provider selection to a Rust provider name string.
    private func resolveRustProviderName() -> String {
        resolveRustProviderName(for: inferenceState.activeAIProvider)
    }

    private func resolveRustProviderName(explicitProviderRawValue: String) -> String {
        if let provider = CloudModelProvider(rawValue: explicitProviderRawValue) {
            return resolveRustProviderName(for: AIProviderSelection(cloudProvider: provider))
        }

        switch explicitProviderRawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "claude", "claude_sonnet", "anthropic":
            return "claude_sonnet"
        case "claude_opus":
            return "claude_opus"
        case "claude_haiku":
            return "claude_haiku"
        case "openai", "openai_gpt4o":
            return "openai_gpt4o"
        case "gemini", "gemini_flash", "google":
            return "gemini_flash"
        case "gemini_pro":
            return "gemini_pro"
        case "zai", "glm":
            return "zai"
        case "kimi", "kimi_coding":
            return "kimi_coding"
        case "minimax":
            return "minimax"
        case "deepseek":
            return "deepseek"
        default:
            return resolveRustProviderName()
        }
    }

    private func resolveRustProviderName(for provider: AIProviderSelection) -> String {
        switch provider {
        case .anthropic:  return "claude_sonnet"
        case .openAI:     return "openai_gpt4o"
        case .google:     return "gemini_flash"
        case .zai:        return "zai"
        case .kimi:       return "kimi_coding"
        case .minimax:    return "minimax"
        case .deepseek:   return "deepseek"
        case .localOnly:  return "ollama"
        }
    }

    nonisolated private static func commandCenterToolRiskLevel(
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

    nonisolated private static func commandCenterToolErrorJSON(_ message: String) -> String {
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

    private func buildOverseerExecutionPlan(
        query: String,
        contentLength: Int,
        operatingMode: EpistemosOperatingMode,
        hasExplicitContext: Bool,
        attachmentCount: Int,
        notesContext: String?,
        conversationHistory: String?
    ) async -> OverseerComplexityRouter.ExecutionPlan? {
        guard operatingMode == .agent else { return nil }
        let planner = ModelRefinedPlanner(inference: inferenceState)
        return await planner.planForMainChat(
            query: query,
            contentLength: contentLength,
            operatingMode: operatingMode,
            hasExplicitContext: hasExplicitContext,
            attachmentCount: attachmentCount,
            notesContext: notesContext,
            conversationHistory: conversationHistory
        )
    }

    private func promptForToolApproval(_ request: AgentPermissionRequest) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = request.permissionCategory == .destructive ? .critical : .warning
        alert.messageText = "Allow \(request.toolName)?"
        let targetSummary = request.approvalTargetSummary.map { "Target:\n\($0)\n\n" } ?? ""
        alert.informativeText = """
        The cloud agent requested \(request.approvalReason).

        \(targetSummary)Request:
        \(String(request.inputJson.prefix(500)))
        """
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            return await withCheckedContinuation { continuation in
                alert.beginSheetModal(for: window) { response in
                    continuation.resume(returning: response == .alertFirstButtonReturn)
                }
            }
        }

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func riskLabel(for riskLevel: AgentRuntimeRiskLevel) -> String {
        switch riskLevel {
        case .readOnly:
            return "read-only"
        case .modification:
            return "modification"
        case .destructive:
            return "destructive"
        }
    }

    // MARK: - Chat Title Generation

    private var titleGenerationTask: Task<Void, Never>?
    private var titleGenerationTaskToken = UUID()

    func generateChatTitle(query: String, chatId: String?, chatState: ChatState) {
        titleGenerationTask?.cancel()
        let taskToken = UUID()
        titleGenerationTaskToken = taskToken
        titleGenerationTask = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    guard let self, self.titleGenerationTaskToken == taskToken else {
                        return
                    }
                    self.titleGenerationTask = nil
                }
            }

            guard let self else { return }

            let prompt = """
            Generate a very short title (2-6 words) for a chat conversation that starts with this query. \
            Return ONLY the title, no quotes, no punctuation at the end, no explanation. \
            Examples: "Quantum entanglement basics", "Fix SwiftUI layout bug", "Essay on stoicism", \
            "React vs Vue comparison", "Morning routine ideas"

            Query: \(query)
            """

            do {
                let title = try await llmService.generate(
                    prompt: prompt,
                    systemPrompt: nil,
                    maxTokens: 30
                )
                let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
                guard !cleaned.isEmpty else { return }

                let originalChatTitle = chatState.chatTitle
                chatState.chatTitle = cleaned

                if let chatId {
                    let context = modelContainer.mainContext
                    let predicate = #Predicate<SDChat> { $0.id == chatId }
                    let descriptor = FetchDescriptor<SDChat>(predicate: predicate)
                    if let sdChat = fetchFirst(
                        descriptor,
                        in: context,
                        label: "chat title target \(chatId)"
                    ) {
                        let originalSavedTitle = sdChat.title
                        sdChat.title = cleaned
                        do {
                            try context.save()
                        } catch {
                            chatState.chatTitle = originalChatTitle
                            sdChat.title = originalSavedTitle
                            Log.pipeline.error("Failed to save chat title: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            } catch {
                Log.pipeline.debug("Chat title generation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Vault Context

    static func resolveNotesContext(
        query: String,
        manifest: VaultManifest?,
        includeAllNotesContext: Bool = false,
        allowImplicitReferencedNoteLookup: Bool = true,
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        fetchNoteBodies: @escaping @Sendable ([String]) async -> [VaultManifest.NoteBody],
        searchNoteIDs: @escaping @Sendable (String) async -> [String]
    ) async -> NotesContextResolution {
        guard let manifest else {
            return NotesContextResolution(
                context: nil,
                cleanedQuery: query,
                loadedNoteIds: [],
                loadedNoteTitles: []
            )
        }

        var cleanedQuery = query
        var referencedNotes: [VaultManifest.NoteBody] = []
        var matchedVaultNotes: [VaultManifest.NoteBody] = []
        var nextLoadedNoteIds: Set<String> = []
        var nextLoadedTitles: [String] = []
        var includeManifest = includeAllNotesContext

        let mentionPattern = #"@\[([^\]]+)\]"#
        do {
            let regex = try NSRegularExpression(pattern: mentionPattern)
            let nsQuery = query as NSString
            let matches = regex.matches(in: query, range: NSRange(location: 0, length: nsQuery.length))

            var titlesToResolve: [String] = []
            for match in matches.reversed() {
                guard let titleRange = Range(match.range(at: 1), in: query) else { continue }
                let title = String(query[titleRange])
                titlesToResolve.append(title)
                if let fullRange = Range(match.range, in: cleanedQuery) {
                    let replacement = title.caseInsensitiveCompare(Self.allNotesMentionToken) == .orderedSame ? "" : title
                    cleanedQuery.replaceSubrange(fullRange, with: replacement)
                }
            }

            if !titlesToResolve.isEmpty {
                for title in titlesToResolve {
                    if title.caseInsensitiveCompare(Self.allNotesMentionToken) == .orderedSame {
                        includeManifest = true
                        continue
                    }
                    let found = await findNotesByTitle(title)
                    let ids = uniquePreservingOrder(found.map(\.pageId))
                    if !ids.isEmpty {
                        let bodies = await fetchNoteBodies(ids)
                        appendLoadedNotes(
                            bodies,
                            to: &referencedNotes,
                            loadedIDs: &nextLoadedNoteIds,
                            loadedTitles: &nextLoadedTitles
                        )
                    }
                }
            }
        } catch {
            Log.pipeline.error(
                "ChatCoordinator: failed to compile explicit context mention regex: \(error.localizedDescription, privacy: .public)"
            )
        }

        if referencedNotes.isEmpty,
           let referencedTitle = explicitNoteReferenceTitle(in: cleanedQuery) {
            let ids = uniquePreservingOrder((await findNotesByTitle(referencedTitle)).map(\.pageId))
            if !ids.isEmpty {
                let bodies = await fetchNoteBodies(ids)
                appendLoadedNotes(
                    bodies,
                    to: &referencedNotes,
                    loadedIDs: &nextLoadedNoteIds,
                    loadedTitles: &nextLoadedTitles
                )
            }
        }

        if allowImplicitReferencedNoteLookup,
           referencedNotes.isEmpty,
           queryLikelyTargetsExistingNote(cleanedQuery) {
            let ids = await autoMatchedReferencedNoteIDs(
                for: cleanedQuery,
                manifest: manifest,
                findNotesByTitle: findNotesByTitle,
                searchNoteIDs: searchNoteIDs
            )
            if !ids.isEmpty {
                let bodies = await fetchNoteBodies(ids)
                appendLoadedNotes(
                    bodies,
                    to: &referencedNotes,
                    loadedIDs: &nextLoadedNoteIds,
                    loadedTitles: &nextLoadedTitles
                )
            }
        }

        if includeManifest {
            let matchedIDs = await matchedVaultNoteIDs(
                for: cleanedQuery,
                manifest: manifest,
                searchNoteIDs: searchNoteIDs
            )
            if !matchedIDs.isEmpty {
                let bodies = await fetchNoteBodies(matchedIDs)
                appendLoadedNotes(
                    bodies,
                    to: &matchedVaultNotes,
                    loadedIDs: &nextLoadedNoteIds,
                    loadedTitles: &nextLoadedTitles
                )
            }
        }

        let pack = VaultContextPack(
            manifest: manifest,
            includeManifest: includeManifest,
            referencedNotes: referencedNotes,
            matchedVaultNotes: matchedVaultNotes,
            cleanedQuery: cleanedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return NotesContextResolution(
            context: pack.renderedContext(),
            cleanedQuery: pack.cleanedQuery,
            loadedNoteIds: nextLoadedNoteIds,
            loadedNoteTitles: nextLoadedTitles
        )
    }

    static func searchReferenceResults(
        filter: String,
        manifest: VaultManifest?,
        chats: [SDChat],
        threads: [ChatThread],
        limitPerSection: Int = 6,
        indexedNoteIDs: [String] = [],
        indexedNoteSnippets: [String: String] = [:]
    ) -> ReferenceSearchResults {
        let normalizedFilter = normalizedSearchField(
            filter.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let uniqueIndexedNoteIDs = uniquePreservingOrder(indexedNoteIDs)
        let noteResultLimit = normalizedFilter.isEmpty ? max(limitPerSection, 10) : limitPerSection

        let noteChoices: [NoteMentionChoice] = {
            guard let manifest else { return [] }
            if normalizedFilter.isEmpty {
                return cachedEmptyManifestResults(
                    for: manifest,
                    limit: noteResultLimit
                )
            }

            var results: [NoteMentionChoice] = []
            if shouldOfferAllNotesChoice(for: normalizedFilter) {
                results.append(.allNotes)
            }
            let terms = searchTerms(from: normalizedFilter)
            let preparedEntries = preparedManifestSearchEntries(for: manifest)
            let referenceDate = Date()
            let indexedBoosts = indexedNoteBoosts(
                pageIDs: uniqueIndexedNoteIDs,
                limit: limitPerSection * 2
            )
            let matched = preparedEntries
                .compactMap { entry -> (entry: VaultManifest.ManifestEntry, score: Int)? in
                    let score = noteSearchScore(
                        for: entry,
                        terms: terms,
                        referenceDate: referenceDate
                    ) + (indexedBoosts[entry.entry.pageId] ?? 0)
                    return score > 0 ? (entry.entry, score) : nil
                }
                .sorted {
                    if $0.score != $1.score { return $0.score > $1.score }
                    if $0.entry.updatedAt != $1.entry.updatedAt {
                        return $0.entry.updatedAt > $1.entry.updatedAt
                    }
                    return $0.entry.title.localizedCaseInsensitiveCompare($1.entry.title) == .orderedAscending
                }
            results.append(contentsOf: matched.prefix(noteResultLimit).map { .entry($0.entry) })
            return results
        }()

        let recentChats = chats
            .filter { !($0.messages ?? []).isEmpty }
            .map { chat in
            let preview = chat.sortedMessages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                result: ChatReferenceResult(
                    attachment: ContextAttachment(
                        kind: .chat,
                        targetId: chat.id,
                        title: chat.title,
                        subtitle: "Main chat"
                    ),
                    preview: preview
                ),
                sortDate: chat.updatedAt
            )
        }

        let transientThreads = threads
            .filter { !$0.messages.isEmpty }
            .map { thread in
                (
                    result: ChatReferenceResult(
                        attachment: ContextAttachment(
                            kind: .chat,
                            targetId: thread.id,
                            title: thread.label,
                            subtitle: "Mini chat"
                        ),
                        preview: thread.messages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    ),
                    sortDate: thread.messages.last?.createdAt ?? thread.createdAt
                )
            }

        var seenChatIDs = Set<String>()
        let filteredChats = (recentChats + transientThreads).filter { item in
            seenChatIDs.insert(item.result.id).inserted
        }.filter { item in
            if normalizedFilter.isEmpty { return true }
            let haystack = [item.result.attachment.title, item.result.attachment.subtitle, item.result.preview]
                .compactMap { $0?.lowercased() }
                .joined(separator: "\n")
            return haystack.contains(normalizedFilter)
        }.sorted { lhs, rhs in
            if lhs.sortDate != rhs.sortDate {
                return lhs.sortDate > rhs.sortDate
            }
            return lhs.result.attachment.title.localizedCaseInsensitiveCompare(rhs.result.attachment.title)
                == .orderedAscending
        }

        return ReferenceSearchResults(
            notes: noteChoices,
            chats: Array(filteredChats.prefix(limitPerSection).map(\.result)),
            vaultTitle: manifest?.vaultTitle,
            vaultNoteCount: manifest?.totalNoteCount ?? 0,
            isInventoryComplete: manifest?.isInventoryComplete ?? false,
            query: normalizedFilter,
            indexedMatchedNoteIDs: Set(uniqueIndexedNoteIDs),
            indexedNoteSnippetsByPageID: indexedNoteSnippets
        )
    }

    private nonisolated static func shouldOfferAllNotesChoice(for normalizedFilter: String) -> Bool {
        normalizedFilter.isEmpty
            || "all notes".contains(normalizedFilter)
            || "all".contains(normalizedFilter)
            || "vault".contains(normalizedFilter)
            || "everything".contains(normalizedFilter)
    }

    private nonisolated static func searchTerms(from normalizedFilter: String) -> [String] {
        normalizedFilter
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private nonisolated static func indexedNoteBoosts(pageIDs: [String], limit: Int) -> [String: Int] {
        var boosts: [String: Int] = [:]
        for (offset, pageID) in uniquePreservingOrder(pageIDs).prefix(limit).enumerated() {
            boosts[pageID] = max(18, 74 - (offset * 8))
        }
        return boosts
    }

    nonisolated private static let _searchCacheLock = NSLock()
    nonisolated(unsafe) private static var _cachedSearchManifestSignature: String?
    nonisolated(unsafe) private static var _cachedSearchPreparedEntries: [PreparedManifestSearchEntry]?
    nonisolated(unsafe) private static var _cachedEmptyManifestResults: CachedEmptyManifestSearchResults?

    private nonisolated static func preparedManifestSearchEntries(
        for manifest: VaultManifest
    ) -> [PreparedManifestSearchEntry] {
        _searchCacheLock.lock()
        defer { _searchCacheLock.unlock() }

        let signature = manifestSearchSignature(for: manifest)

        if let cached = _cachedSearchPreparedEntries, _cachedSearchManifestSignature == signature {
            return cached
        }

        let prepared = manifest.entries.map { entry in
            PreparedManifestSearchEntry(
                entry: entry,
                normalizedTitle: normalizedSearchField(entry.title),
                normalizedFolder: entry.folderName.map(normalizedSearchField) ?? "",
                normalizedSnippet: normalizedSearchField(entry.snippet),
                normalizedTags: entry.tags.map(normalizedSearchField)
            )
        }

        _cachedSearchManifestSignature = signature
        _cachedSearchPreparedEntries = prepared
        return prepared
    }

    private nonisolated static func cachedEmptyManifestResults(
        for manifest: VaultManifest,
        limit: Int
    ) -> [NoteMentionChoice] {
        _searchCacheLock.lock()
        defer { _searchCacheLock.unlock() }

        let signature = manifestSearchSignature(for: manifest)
        if let cached = _cachedEmptyManifestResults,
           cached.signature == signature,
           cached.limit == limit {
            return cached.notes
        }

        var results: [NoteMentionChoice] = [.allNotes]
        results.reserveCapacity(limit + 1)
        let recentEntries = manifest.entries
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .prefix(limit)
        results.append(contentsOf: recentEntries.map(NoteMentionChoice.entry))

        _cachedEmptyManifestResults = CachedEmptyManifestSearchResults(
            signature: signature,
            limit: limit,
            notes: results
        )
        return results
    }

    private nonisolated static func manifestSearchSignature(for manifest: VaultManifest) -> String {
        let entries = manifest.entries
        return [
            String(entries.count),
            String(manifest.generatedAt.timeIntervalSince1970),
            entries.first?.pageId ?? "",
            String(entries.first?.updatedAt.timeIntervalSince1970 ?? 0),
        ].joined(separator: "|")
    }

    private nonisolated static func noteSearchScore(
        for entry: PreparedManifestSearchEntry,
        terms: [String],
        referenceDate: Date
    ) -> Int {
        guard !terms.isEmpty else { return 0 }

        var score = 0
        for term in terms {
            var matchedCurrentTerm = false

            if entry.normalizedTitle == term {
                score += 160
                matchedCurrentTerm = true
            } else if entry.normalizedTitle.hasPrefix(term) {
                score += 120
                matchedCurrentTerm = true
            } else if entry.normalizedTitle.contains(term) {
                score += 80
                matchedCurrentTerm = true
            }

            if entry.normalizedFolder.hasPrefix(term) {
                score += 32
                matchedCurrentTerm = true
            } else if entry.normalizedFolder.contains(term) {
                score += 24
                matchedCurrentTerm = true
            }

            var matchedTag = false
            for tag in entry.normalizedTags {
                if tag == term {
                    score += 48
                    matchedCurrentTerm = true
                    matchedTag = true
                    break
                }
                if tag.hasPrefix(term) {
                    score += 38
                    matchedCurrentTerm = true
                    matchedTag = true
                    break
                }
                if tag.contains(term) {
                    score += 26
                    matchedCurrentTerm = true
                    matchedTag = true
                    break
                }
            }

            if !matchedTag {
                if entry.normalizedSnippet.hasPrefix(term) {
                    score += 22
                    matchedCurrentTerm = true
                } else if entry.normalizedSnippet.contains(term) {
                    score += 16
                    matchedCurrentTerm = true
                }
            }

            if !matchedCurrentTerm {
                return 0
            }
        }

        let ageInDays = max(0, referenceDate.timeIntervalSince(entry.entry.updatedAt) / 86_400)
        score += max(0, 14 - Int(min(ageInDays, 14)))
        return score
    }

    private nonisolated static func normalizedSearchField(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    func buildContextAttachments(
        query: String,
        attachments: [ContextAttachment],
        chatState: ChatState
    ) async -> (String?, String) {
        let resolution = await Self.resolveAttachedContext(
            query: query,
            attachments: attachments,
            manifest: bootstrap.ambientManifest,
            includeAllNotesContext: false,
            findNotesByTitle: { [vaultSync] title in
                await vaultSync.findNotesByTitle(title)
            },
            fetchNoteBodies: { [vaultSync] ids in
                await vaultSync.fetchNoteBodies(ids: ids)
            },
            searchNoteIDs: { [vaultSync] query in
                await vaultSync.searchIndex(query: query)
            },
            fetchChatMessages: { [bootstrap, modelContainer] chatID in
                await MainActor.run {
                    if let thread = bootstrap.threadState.chatThreads.first(where: { $0.id == chatID }) {
                        return thread.messages
                    }
                    let context = modelContainer.mainContext
                    let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatID })
                    guard let chat = self.fetchFirst(
                        descriptor,
                        in: context,
                        label: "attached chat context \(chatID)"
                    ) else { return [] }
                    return chat.sortedMessages.map { message in
                        AssistantMessage(
                            role: message.role == "user" ? .user : .assistant,
                            content: message.content,
                            createdAt: message.createdAt
                        )
                    }
                }
            }
        )
        chatState.loadedNoteIds = resolution.loadedNoteIds
        chatState.loadedNoteTitles = resolution.loadedNoteTitles
        return (resolution.context, resolution.cleanedQuery)
    }

    static func resolveAttachedContext(
        query: String,
        attachments: [ContextAttachment],
        manifest: VaultManifest?,
        includeAllNotesContext: Bool = false,
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        fetchNoteBodies: @escaping @Sendable ([String]) async -> [VaultManifest.NoteBody],
        searchNoteIDs: @escaping @Sendable (String) async -> [String],
        fetchChatMessages: @escaping @Sendable (String) async -> [AssistantMessage]
    ) async -> AttachedContextResolution {
        let hasAttachedNotes = attachments.contains { $0.kind == .note }
        let requestedNoteContext = queryContainsExplicitNoteContext(query)
            || attachments.contains(where: { $0.kind == .allNotes })
        let noteResolution = await resolveNotesContext(
            query: query,
            manifest: manifest,
            includeAllNotesContext: includeAllNotesContext
                || attachments.contains(where: { $0.kind == .allNotes }),
            allowImplicitReferencedNoteLookup: !hasAttachedNotes,
            findNotesByTitle: findNotesByTitle,
            fetchNoteBodies: fetchNoteBodies,
            searchNoteIDs: searchNoteIDs
        )

        let attachedNoteContext = await buildAttachedNoteContext(
            for: attachments.filter { $0.kind == .note },
            excluding: noteResolution.loadedNoteIds,
            findNotesByTitle: findNotesByTitle,
            fetchNoteBodies: fetchNoteBodies
        )
        let chatContext = await buildChatContextPack(
            for: attachments.filter { $0.kind == .chat },
            fetchChatMessages: fetchChatMessages
        )
        var parts: [String] = []
        if let attachedNoteContext = attachedNoteContext.context, !attachedNoteContext.isEmpty {
            parts.append(attachedNoteContext)
        }
        if let context = noteResolution.context, !context.isEmpty {
            let wrappedContext = requestedNoteContext
                ? wrapRequiredContextSection(
                    title: "Requested Note Context",
                    instruction: "The user explicitly referenced these notes for the current request. Use them whenever they are relevant and prefer them over unsupported assumptions.",
                    body: context
                )
                : wrapSupplementalContextSection(
                    title: "Additional Note Context",
                    instruction: "This note material was auto-matched from the vault to help answer the query. Use it only when it is relevant; explicit attachments above take priority.",
                    body: context
                )
            if let wrappedContext {
                parts.append(wrappedContext)
            }
        }
        if let chatContext, !chatContext.isEmpty {
            parts.append(chatContext)
        }
        let combinedLoadedNoteIDs = noteResolution.loadedNoteIds.union(attachedNoteContext.loadedNoteIds)
        var combinedLoadedTitles = noteResolution.loadedNoteTitles
        for title in attachedNoteContext.loadedNoteTitles where !combinedLoadedTitles.contains(title) {
            combinedLoadedTitles.append(title)
        }
        return AttachedContextResolution(
            context: parts.isEmpty ? nil : parts.joined(separator: "\n\n"),
            cleanedQuery: noteResolution.cleanedQuery,
            loadedNoteIds: combinedLoadedNoteIDs,
            loadedNoteTitles: combinedLoadedTitles
        )
    }

    private nonisolated static func uniquePreservingOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []
        results.reserveCapacity(ids.count)
        for id in ids where seen.insert(id).inserted {
            results.append(id)
        }
        return results
    }

    private nonisolated static func explicitNoteReferenceTitle(in query: String) -> String? {
        let patterns = [
            #/(?i)\b(?:go\s+to|open|find|use|read|show|look\s+for|check)\s+(?:my\s+)?note\s+(.+?)(?=\s+(?:and|then|please|summarize|rewrite|analyze|compare|review|explain|tell|show|use)\b|[?.!,]|$)/#,
            #/(?i)\b(?:my\s+)?note\s+(.+?)(?=\s+(?:and|then|please|summarize|rewrite|analyze|compare|review|explain|tell|show|use)\b|[?.!,]|$)/#,
        ]

        for pattern in patterns {
            if let match = query.firstMatch(of: pattern) {
                let title = String(match.output.1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
                    .lowercased()
                if !title.isEmpty {
                    return title
                }
            }
        }
        return nil
    }

    private nonisolated static func queryLikelyTargetsExistingNote(_ query: String) -> Bool {
        let normalized = normalizedSearchField(query)
        guard !normalized.isEmpty else { return false }
        let cues = [
            "note", "essay", "draft", "wrote", "written", "mentioned", "mentioning",
            "summarize it", "summarize that", "find", "look for", "show me", "open",
            "a few weeks ago", "few weeks ago", "last week", "yesterday", "earlier",
        ]
        return cues.contains { normalized.contains($0) }
    }

    private nonisolated static func noteLookupSearchPhrases(from query: String) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var phrases = [trimmedQuery]
        let patterns = [
            #/(?i)\b(?:essay|note|draft)\s+(?:on|about)\s+(.+?)(?=\s+(?:a\s+few|few|last|yesterday|today|this|please|summarize|rewrite|analyze|compare|review|explain|show|find|open|where)\b|[?.!,]|$)/#,
            #/(?i)\b(?:mentioned|mentioning)\s+(.+?)(?=\s+(?:a\s+few|few|last|yesterday|today|this|please|summarize|rewrite|analyze|compare|review|explain|show|find|open)\b|[?.!,]|$)/#,
            #/(?i)\b(?:called|titled)\s+(.+?)(?=\s+(?:a\s+few|few|last|yesterday|today|this|please|summarize|rewrite|analyze|compare|review|explain|show|find|open)\b|[?.!,]|$)/#,
        ]

        for pattern in patterns {
            if let match = trimmedQuery.firstMatch(of: pattern) {
                let phrase = String(match.output.1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
                if !phrase.isEmpty {
                    phrases.append(phrase)
                }
            }
        }

        if let explicitTitle = explicitNoteReferenceTitle(in: trimmedQuery) {
            phrases.append(explicitTitle)
        }

        return uniquePreservingOrder(phrases)
    }

    private nonisolated static func autoMatchedReferencedNoteIDs(
        for query: String,
        manifest: VaultManifest,
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        searchNoteIDs: @escaping @Sendable (String) async -> [String]
    ) async -> [String] {
        let phrases = noteLookupSearchPhrases(from: query)
        guard !phrases.isEmpty else { return [] }

        var scoresByPageID: [String: Int] = [:]
        let normalizedQuery = normalizedSearchField(query)
        let referenceDate = Date()
        let preparedEntries = preparedManifestSearchEntries(for: manifest)
        let entriesByPageID = Dictionary(
            uniqueKeysWithValues: preparedEntries.map { ($0.entry.pageId, $0.entry) }
        )

        for (phraseIndex, phrase) in phrases.enumerated() {
            let normalizedPhrase = normalizedSearchField(phrase)
            let terms = searchTerms(from: normalizedPhrase)
            guard !terms.isEmpty else { continue }

            let titleMatches = await findNotesByTitle(phrase)
            for (offset, entry) in titleMatches.prefix(8).enumerated() {
                let boost = max(48, 120 - (offset * 12) - (phraseIndex * 8))
                scoresByPageID[entry.pageId] = max(scoresByPageID[entry.pageId] ?? 0, boost)
            }

            let indexedIDs = uniquePreservingOrder(await searchNoteIDs(phrase))
            let indexedBoosts = indexedNoteBoosts(pageIDs: indexedIDs, limit: 12)
            for entry in preparedEntries {
                let score = noteSearchScore(
                    for: entry,
                    terms: terms,
                    referenceDate: referenceDate
                ) + (indexedBoosts[entry.entry.pageId] ?? 0) + temporalHintBoost(
                    updatedAt: entry.entry.updatedAt,
                    normalizedQuery: normalizedQuery,
                    referenceDate: referenceDate
                )
                guard score > 0 else { continue }
                scoresByPageID[entry.entry.pageId] = max(
                    scoresByPageID[entry.entry.pageId] ?? 0,
                    score
                )
            }
        }

        let ranked = scoresByPageID.sorted { lhsPair, rhsPair in
            if lhsPair.value != rhsPair.value { return lhsPair.value > rhsPair.value }
            let lhsEntry = entriesByPageID[lhsPair.key]
            let rhsEntry = entriesByPageID[rhsPair.key]
            return (lhsEntry?.updatedAt ?? .distantPast) > (rhsEntry?.updatedAt ?? .distantPast)
        }
        guard let top = ranked.first, top.value >= 90 else { return [] }
        if let second = ranked.dropFirst().first, top.value < second.value + 18 {
            return []
        }
        return [top.key]
    }

    private nonisolated static func temporalHintBoost(
        updatedAt: Date,
        normalizedQuery: String,
        referenceDate: Date
    ) -> Int {
        if normalizedQuery.contains("few weeks ago") || normalizedQuery.contains("a few weeks ago") {
            let ageInDays = Int(referenceDate.timeIntervalSince(updatedAt) / 86_400)
            return (10...45).contains(ageInDays) ? 18 : 0
        }
        if normalizedQuery.contains("last week") {
            let ageInDays = Int(referenceDate.timeIntervalSince(updatedAt) / 86_400)
            return (5...14).contains(ageInDays) ? 16 : 0
        }
        if normalizedQuery.contains("yesterday") {
            let ageInDays = Int(referenceDate.timeIntervalSince(updatedAt) / 86_400)
            return ageInDays == 1 ? 16 : 0
        }
        if normalizedQuery.contains("today") {
            let ageInDays = Int(referenceDate.timeIntervalSince(updatedAt) / 86_400)
            return ageInDays == 0 ? 16 : 0
        }
        return 0
    }

    private nonisolated static func appendLoadedNotes(
        _ bodies: [VaultManifest.NoteBody],
        to destination: inout [VaultManifest.NoteBody],
        loadedIDs: inout Set<String>,
        loadedTitles: inout [String]
    ) {
        for body in bodies {
            guard loadedIDs.insert(body.pageId).inserted else { continue }
            destination.append(body)
            if !loadedTitles.contains(body.title) {
                loadedTitles.append(body.title)
            }
        }
    }

    private nonisolated static func matchedVaultNoteIDs(
        for query: String,
        manifest: VaultManifest,
        searchNoteIDs: @escaping @Sendable (String) async -> [String],
        limit: Int = 4
    ) async -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let ranked = uniquePreservingOrder(await searchNoteIDs(trimmedQuery))
            if !ranked.isEmpty {
                return Array(ranked.prefix(limit))
            }
        }

        return manifest.entries
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .prefix(limit)
            .map(\.pageId)
    }

    private static func buildAttachedNoteContext(
        for attachments: [ContextAttachment],
        excluding excludedIDs: Set<String>,
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        fetchNoteBodies: @escaping @Sendable ([String]) async -> [VaultManifest.NoteBody]
    ) async -> NotesContextResolution {
        guard !attachments.isEmpty else {
            return NotesContextResolution(
                context: nil,
                cleanedQuery: "",
                loadedNoteIds: [],
                loadedNoteTitles: []
            )
        }

        let directIDs = uniquePreservingOrder(attachments.map(\.targetId))
        let directBodies = await fetchNoteBodies(directIDs)
        var bodiesByID = Dictionary(uniqueKeysWithValues: directBodies.map { ($0.pageId, $0) })

        for attachment in attachments where bodiesByID[attachment.targetId] == nil {
            let fallbackIDs = uniquePreservingOrder(
                (await findNotesByTitle(attachment.title)).map(\.pageId)
            )
            guard !fallbackIDs.isEmpty else { continue }
            let fallbackBodies = await fetchNoteBodies(fallbackIDs)
            for body in fallbackBodies where bodiesByID[body.pageId] == nil {
                bodiesByID[body.pageId] = body
            }
        }

        var seenIDs = excludedIDs
        var sections: [String] = []
        var loadedIDs = Set<String>()
        var loadedTitles: [String] = []

        for attachment in attachments {
            guard let body = bodiesByID[attachment.targetId] else { continue }
            guard seenIDs.insert(body.pageId).inserted else { continue }
            sections.append(
                """
                ### Attached Note: \(body.title)
                Reason: The user explicitly attached this note to the current request.
                Priority: Required context. Use it when relevant and cite the note title.
                Content:
                \(body.body)
                """
            )
            loadedIDs.insert(body.pageId)
            if !loadedTitles.contains(body.title) {
                loadedTitles.append(body.title)
            }
        }

        return NotesContextResolution(
            context: wrapRequiredContextSection(
                title: "Required Attached Notes",
                instruction: "These notes were explicitly attached by the user for this request. Use their contents whenever they are relevant. Use these notes before recall/search tools. Only broaden beyond them if the user asks or the attached notes are clearly insufficient.",
                body: sections.joined(separator: "\n\n")
            ),
            cleanedQuery: "",
            loadedNoteIds: loadedIDs,
            loadedNoteTitles: loadedTitles
        )
    }

    static func buildChatContextPack(
        for attachments: [ContextAttachment],
        fetchChatMessages: @escaping @Sendable (String) async -> [AssistantMessage]
    ) async -> String? {
        guard !attachments.isEmpty else { return nil }

        var sections: [String] = []
        sections.reserveCapacity(attachments.count)

        for attachment in attachments {
            let messages = await fetchChatMessages(attachment.targetId)
            let transcript = messages.suffix(8).map { message in
                let role = message.role == .user ? "User" : "Assistant"
                let content = message.content.count > 800
                    ? String(message.content.prefix(800)) + "…"
                    : message.content
                return "\(role): \(content)"
            }
            guard !transcript.isEmpty else { continue }
            sections.append(
                """
                Attached chat context: \(attachment.title)
                Reason: The user explicitly attached this conversation to the current request.
                Priority: Required context. Use it when relevant and reference the chat title.
                Transcript:
                \(transcript.joined(separator: "\n\n"))
                """
            )
        }

        return wrapRequiredContextSection(
            title: "Required Attached Chats",
            instruction: "These chats were explicitly attached by the user for this request. Use them whenever they are relevant. Use these chats before recall/search tools. Only broaden beyond them if the user asks or the attached chats are clearly insufficient.",
            body: sections.joined(separator: "\n\n")
        )
    }

    static func queryContainsExplicitNoteContext(_ query: String) -> Bool {
        query.contains("@[")
            || explicitNoteReferenceTitle(in: query) != nil
            || queryLikelyTargetsExistingNote(query)
    }

    static func queryContainsExplicitContext(_ query: String, attachments: [ContextAttachment]) -> Bool {
        queryContainsExplicitNoteContext(query) || !attachments.isEmpty
    }

    // MARK: - Workspace Awareness Context

    /// Determines if the user query is asking about session/chat history/summaries.
    static func queryRequestsSessionContext(_ query: String) -> Bool {
        let lower = query.lowercased()
        let triggers = [
            "what have i been", "what was i", "what did i", "what am i working",
            "summarize my", "summary of", "session summary", "today's summary",
            "chats today", "all my chats", "chat history", "chat summary",
            "what happened", "recap", "catch me up", "bring me up to speed",
            "what did we discuss", "what did we talk", "my activity", "my session",
            "my work today", "my progress", "end of day", "daily summary",
        ]
        return triggers.contains(where: { lower.contains($0) })
    }

    static func buildWorkspaceAwarenessContext(bootstrap: AppBootstrap, deepContext: Bool = false) -> String {
        var parts: [String] = []
        let context = bootstrap.modelContainer.mainContext

        // Latest AI workspace summary
        // Note: Uses direct fetch + filter to avoid #Predicate macro expansion scope issue.
        let allWorkspaces = fetchAll(
            FetchDescriptor<SDWorkspace>(),
            in: context,
            label: "workspace awareness workspaces"
        ) ?? []
        if let workspace = allWorkspaces.first(where: { $0.isAutoSave }) {
            if let summary = sanitizedWorkspaceContextValue(workspace.summary) {
                parts.append("[Workspace Summary] \(summary)")
            }

            let userNote = workspace.userNote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !userNote.isEmpty {
                parts.append("[User Session Note] \(userNote)")
            }
        }

        // Open note titles + previews
        let openPageIds = NoteWindowManager.shared.orderedPageIds()
        if !openPageIds.isEmpty {
            var noteLines: [String] = []
            for pageId in openPageIds.prefix(8) {
                let targetId = pageId
                let desc = FetchDescriptor<SDPage>(
                    predicate: #Predicate<SDPage> { $0.id == targetId }
                )
                guard let page = fetchFirst(
                    desc,
                    in: context,
                    label: "workspace awareness page \(targetId)"
                ) else { continue }
                let title = page.title.isEmpty ? "Untitled" : page.title
                if deepContext {
                    let body = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
                    let preview = String(body.prefix(300))
                    noteLines.append("- \(title): \(preview)")
                } else {
                    noteLines.append("- \(title)")
                }
            }
            parts.append("[Currently Open Notes]\n\(noteLines.joined(separator: "\n"))")
        }

        // Recent activity from tracker
        let tracker = bootstrap.activityTracker
        let recentEvents = tracker.recentEvents(since: Date().addingTimeInterval(-3600)) // last hour
        if !recentEvents.isEmpty {
            var activityLines: [String] = []
            var editedNotes: Set<String> = []
            var chatMsgCount = 0
            for event in recentEvents {
                switch event.kind {
                case .noteEdited(_, let title, let changed, let total):
                    if editedNotes.insert(title).inserted {
                        activityLines.append("- Edited \"\(title)\" (\(changed)/\(total) paragraphs)")
                    }
                case .chatMessageSent(_, let snippet):
                    chatMsgCount += 1
                    if deepContext && chatMsgCount <= 5 {
                        activityLines.append("- Chat: \"\(snippet)\"")
                    }
                case .noteOpened(_, let title):
                    if deepContext { activityLines.append("- Opened \"\(title)\"") }
                case .noteClosed(_, let title):
                    if deepContext { activityLines.append("- Closed \"\(title)\"") }
                }
            }
            if chatMsgCount > 0 && !deepContext {
                activityLines.append("- \(chatMsgCount) chat message\(chatMsgCount == 1 ? "" : "s") this hour")
            }
            if !activityLines.isEmpty {
                parts.append("[Recent Activity]\n\(activityLines.joined(separator: "\n"))")
            }
        }

        // Session duration
        if let startedAt = tracker.trackingStartedAt {
            let minutes = Int(Date().timeIntervalSince(startedAt) / 60)
            if minutes > 0 {
                parts.append("[Session Duration] \(minutes) minutes")
            }
        }

        if deepContext {
            // Global activity profile (7-day engagement patterns)
            let profile = tracker.globalActivityProfile()
            if profile.totalEdits7d > 0 || profile.totalVisits7d > 0 {
                parts.append("[Activity Profile] \(profile.formatForPrompt())")
            }

            // Recent meaning anchors — O(n) linear scan with fixed-size heap for top 5
            let store = bootstrap.graphState.store
            var anchorHeap: [GraphNodeRecord] = []
            anchorHeap.reserveCapacity(6)
            for node in store.nodes.values where node.type == .idea && node.metadata.originChatId != nil {
                anchorHeap.append(node)
                if anchorHeap.count > 5 {
                    if let minIdx = anchorHeap.indices.min(by: { anchorHeap[$0].createdAt < anchorHeap[$1].createdAt }) {
                        anchorHeap.remove(at: minIdx)
                    }
                }
            }
            let recentAnchors = anchorHeap.sorted { $0.createdAt > $1.createdAt }
            if !recentAnchors.isEmpty {
                let anchorLines = recentAnchors.map { node in
                    let summary = node.metadata.abstract ?? ""
                    let theme = node.metadata.clusterTheme ?? ""
                    return "- \(node.label): \(summary)\(theme.isEmpty ? "" : " [\(theme)]")"
                }
                parts.append("[Recent Insights]\n\(anchorLines.joined(separator: "\n"))")
            }

            if !openPageIds.isEmpty {
                let store = bootstrap.graphState.store
                var edges: [String] = []
                for pageId in openPageIds.prefix(4) {
                    guard let node = store.node(bySourceId: pageId, type: .note) else { continue }
                    guard let neighborIds = store.adjacency[node.id] else { continue }
                    for neighborId in neighborIds.prefix(3) {
                        guard let neighbor = store.nodes[neighborId] else { continue }
                        edges.append("[\(node.label)] -> [\(neighbor.label)]")
                    }
                }
                if !edges.isEmpty {
                    parts.append("[Knowledge Connections]\n\(edges.joined(separator: "\n"))")
                }
            }

            let todayStart = Calendar.current.startOfDay(for: Date())
            let chatDesc = FetchDescriptor<SDChat>(
                predicate: #Predicate<SDChat> { $0.updatedAt >= todayStart },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            if let chats = fetchAll(chatDesc, in: context, label: "workspace awareness recent chats") {
                var chatSummaries: [String] = []
                for chat in chats.prefix(10) {
                    let msgs = chat.sortedMessages
                    let snippets = msgs.suffix(4).map { msg in
                        let role = msg.role == "user" ? "You" : "AI"
                        return "\(role): \(String(msg.content.prefix(150)))"
                    }
                    if !snippets.isEmpty {
                        let title = chat.title.isEmpty ? "Untitled Chat" : chat.title
                        chatSummaries.append("Chat \"\(title)\":\n\(snippets.joined(separator: "\n"))")
                    }
                }
                if !chatSummaries.isEmpty {
                    parts.append("[Today's Conversations]\n\(chatSummaries.joined(separator: "\n\n"))")
                }
            }

            let miniChatCount = MiniChatWindowController.shared.openChatIds.count
            if miniChatCount > 0 {
                parts.append("[Open Mini Chats] \(miniChatCount)")
            }

            if HologramController.shared.isVisible {
                let nodeCount = bootstrap.graphState.store.nodes.count
                parts.append("[Knowledge Graph] Open with \(nodeCount) nodes")
            }

            if !recentAnchors.isEmpty {
                let themes = Set(recentAnchors.compactMap { $0.metadata.clusterTheme }).prefix(3)
                if !themes.isEmpty {
                    parts.append("[Proactive Hint] The user has been exploring these themes recently: \(themes.joined(separator: ", ")). Look for connections between their current question and these themes. Adapt your communication style to be concise and direct — the user works intensively and prefers actionable insights over lengthy explanations.")
                }
            }
        }

        return parts.joined(separator: "\n\n")
    }

    private nonisolated static func sanitizedWorkspaceContextValue(_ raw: String) -> String? {
        let cleaned = UserFacingModelOutput.finalVisibleText(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return cleaned
    }

    nonisolated static func buildFileAttachmentContext(
        from attachments: [FileAttachment],
        supportsVision: Bool = false
    ) -> String? {
        let sections = attachments.compactMap { fileAttachmentSection(for: $0, supportsVision: supportsVision) }
        return wrapRequiredContextSection(
            title: "Required File Attachments",
            instruction: "These files were explicitly attached by the user to this message. Use them whenever they are relevant. Treat them as the primary subject of the request unless the user clearly says otherwise. Refer to them by name instead of treating them as optional background. Use the attached file before recall/search tools. Only broaden beyond it if the user asks or the attached file is clearly insufficient.",
            body: sections.joined(separator: "\n\n")
        )
    }

    private nonisolated static func buildRequiredAttachmentContractSection() -> String? {
        wrapRequiredContextSection(
            title: "Required Context Contract",
            instruction: "The user intentionally attached or referenced files, notes, or chats for this request. Use that material directly, and do not ask them to provide it again unless something is missing or unreadable.",
            body: """
            Treat them as the primary subject of the request unless the user clearly says otherwise.
            If the attached notes, files, or chats already cover the request, use them before recall/search/memory tools.
            Only broaden beyond the attached context when the user asks for a wider search or the attached material is clearly insufficient.
            If anything is missing or unreadable, name the specific missing item instead of pretending no context was provided.
            """
        )
    }

    private nonisolated static func mergedContextSections(_ sections: String?...) -> String? {
        let nonEmptySections = sections.compactMap { section -> String? in
            guard let trimmed = section?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }
        guard !nonEmptySections.isEmpty else { return nil }
        return nonEmptySections.joined(separator: "\n\n")
    }

    private nonisolated static func wrapRequiredContextSection(
        title: String,
        instruction: String,
        body: String
    ) -> String? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return nil }
        return """
        ## \(title)
        Status: Required context explicitly attached or requested by the user.
        Instruction: \(instruction)

        \(trimmedBody)
        """
    }

    private nonisolated static func wrapSupplementalContextSection(
        title: String,
        instruction: String,
        body: String
    ) -> String? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return nil }
        return """
        ## \(title)
        Status: Supplemental background context.
        Instruction: \(instruction)

        \(trimmedBody)
        """
    }

    private nonisolated static func fileAttachmentSection(
        for attachment: FileAttachment,
        supportsVision: Bool
    ) -> String? {
        switch attachment.type {
        case .text, .csv:
            guard let text = loadedTextAttachmentBody(for: attachment) else { return nil }
            return """
            Attached file: \(attachment.name)
            Reason: The user explicitly attached this file to the current request.
            Priority: Required context. Use it when relevant and cite the file name.
            Content:
            \(text)
            """
        case .pdf:
            // For PDFs, attempt to extract text content via the preview (already extracted at attach time).
            guard let preview = attachment.preview?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !preview.isEmpty else {
                return """
                Attached file: \(attachment.name)
                Reason: The user explicitly attached this PDF to the current request.
                Priority: Required context.
                Extraction status: PDF text could not be extracted automatically. If the answer depends on unseen PDF contents, say so instead of guessing.
                """
            }
            return """
            Attached file: \(attachment.name)
            Reason: The user explicitly attached this PDF to the current request.
            Priority: Required context. Use the extracted text when relevant and cite the file name.
            Content:
            \(preview)
            """
        case .image:
            if supportsVision {
                return """
                Attached file: \(attachment.name)
                Reason: The user explicitly attached this image to the current request.
                Priority: Required context.
                Image handling: This model can inspect images directly. Use the visual contents when they are relevant to the answer.
                """
            }
            return """
            Attached file: \(attachment.name)
            Reason: The user explicitly attached this image to the current request.
            Priority: Required context.
            Image handling: This model cannot inspect images directly. Do not invent visual details; acknowledge the limitation if the image matters.
            """
        case .other:
            // Attempt text extraction as a best effort.
            if let text = loadedTextAttachmentBody(for: attachment) {
                return """
                Attached file: \(attachment.name)
                Reason: The user explicitly attached this file to the current request.
                Priority: Required context. Use the recovered text when relevant and cite the file name.
                Content:
                \(text)
                """
            }
            return nil
        }
    }

    private nonisolated static func loadedTextAttachmentBody(for attachment: FileAttachment) -> String? {
        if let fileURL = resolvedFileAttachmentURL(from: attachment.uri),
           let text = readTextAttachment(at: fileURL) {
            return text
        }

        guard let preview = attachment.preview?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !preview.isEmpty else {
            return nil
        }
        return preview
    }

    private nonisolated static func resolvedFileAttachmentURL(from uri: String) -> URL? {
        if let url = URL(string: uri), url.isFileURL {
            return url
        }

        if uri.hasPrefix("/") {
            return URL(fileURLWithPath: uri)
        }

        if let decodedPath = uri.removingPercentEncoding, decodedPath.hasPrefix("/") {
            return URL(fileURLWithPath: decodedPath)
        }

        return nil
    }


    private nonisolated static func readTextAttachment(at url: URL) -> String? {
        let gainedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if gainedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            Log.pipeline.error("Failed to open file handle for attachment at \(url.path): \(error.localizedDescription)")
            return nil
        }
        defer {
            do {
                try handle.close()
            } catch {
                Log.pipeline.warning("Failed to close file handle for \(url.path): \(error.localizedDescription)")
            }
        }

        let data: Data
        do {
            guard let readData = try handle.read(upToCount: maxFileAttachmentContextBytes) else {
                Log.pipeline.warning("Read returned nil for attachment at \(url.path)")
                return nil
            }
            data = readData
        } catch {
            Log.pipeline.error("Failed to read attachment data at \(url.path): \(error.localizedDescription)")
            return nil
        }

        guard !data.isEmpty else { return nil }
        guard let decoded = FoundationSafety.decodedText(from: data) else {
            Log.pipeline.warning("Failed to decode text from attachment at \(url.path) (\(data.count) bytes)")
            return nil
        }

        let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count > maxFileAttachmentContextCharacters else { return trimmed }
        return String(trimmed.prefix(maxFileAttachmentContextCharacters)) + "\n...(truncated)"
    }

    // MARK: - Vault Action Execution

    static func sanitizeVaultActionMarkers(in response: String) -> (cleaned: String, blockedActions: [String]) {
        var cleaned = response
        var blockedActions: [String] = []

        while let range = cleaned.range(of: #"\[ACTION:TAG\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(cleaned[range])
            let raw = marker
                .replacingOccurrences(of: "[ACTION:TAG ", with: "")
                .replacingOccurrences(of: "]", with: "")
            let tags = raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0.count < 30 }
            if !tags.isEmpty {
                blockedActions.append("Approval required before adding tags [\(tags.joined(separator: ", "))].")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        while let range = cleaned.range(of: #"\[ACTION:MOVE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(cleaned[range])
            let folderName = marker
                .replacingOccurrences(of: "[ACTION:MOVE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !folderName.isEmpty {
                blockedActions.append("Approval required before moving this note to \(folderName).")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        while let range = cleaned.range(of: #"\[ACTION:CREATE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(cleaned[range])
            let title = marker
                .replacingOccurrences(of: "[ACTION:CREATE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                blockedActions.append("Approval required before creating note: \(title).")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        if !blockedActions.isEmpty {
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (cleaned, blockedActions)
    }

    func executeVaultActions(in response: String) -> String {
        let sanitized = Self.sanitizeVaultActionMarkers(in: response)
        guard !sanitized.blockedActions.isEmpty else {
            return sanitized.cleaned
        }

        if sanitized.cleaned.isEmpty {
            return sanitized.blockedActions.joined(separator: "\n")
        }

        return sanitized.cleaned + "\n\n---\n" + sanitized.blockedActions.joined(separator: "\n")
    }

    // MARK: - Chat Persistence

    func persistChatCompletion(
        chatId: String?,
        query: String,
        answer: String,
        mode: InferenceMode,
        assistantMessage: ChatMessage?,
        isNotes: Bool = false
    ) {
        guard let chatId else { return }
        let context = modelContainer.mainContext

        let chat: SDChat
        let wasExisting: Bool
        let predicate = #Predicate<SDChat> { $0.id == chatId }
        let descriptor = FetchDescriptor<SDChat>(predicate: predicate)

        if let existing = fetchFirst(descriptor, in: context, label: "chat persistence") {
            chat = existing
            wasExisting = true
        } else {
            let firstWords = String(query.prefix(50))
            chat = SDChat(title: firstWords, chatType: "chat")
            chat.id = chatId
            context.insert(chat)
            wasExisting = false
        }

        let originalChatType = chat.chatType
        let originalLinkedPageId = chat.linkedPageId
        let originalUpdatedAt = chat.updatedAt
        let originalMessages = chat.messages ?? []

        chat.updatedAt = .now
        if isNotes { chat.chatType = "notes" }

        let sourceUserMessage = persistedUserMessage(
            chatId: chatId,
            query: query,
            assistantMessage: assistantMessage
        )
        let userMsg = SDMessage(role: "user", content: query)
        if let sourceUserMessage {
            userMsg.id = sourceUserMessage.id
            userMsg.createdAt = sourceUserMessage.createdAt
            userMsg.isError = sourceUserMessage.isError
            userMsg.isVaultBriefing = sourceUserMessage.isVaultBriefing
        }
        userMsg.updatePresentationSnapshot(
            attachments: sourceUserMessage?.attachments ?? [],
            loadedNoteTitles: sourceUserMessage?.loadedNoteTitles,
            contextAttachments: sourceUserMessage?.contextAttachments
        )
        userMsg.chat = chat
        context.insert(userMsg)

        let assistantMsg = SDMessage(role: "assistant", content: answer)
        if let assistantMessage {
            assistantMsg.id = assistantMessage.id
            assistantMsg.createdAt = assistantMessage.createdAt
            assistantMsg.isError = assistantMessage.isError
            assistantMsg.isVaultBriefing = assistantMessage.isVaultBriefing
        }
        assistantMsg.updatePresentationSnapshot(
            attachments: assistantMessage?.attachments ?? [],
            loadedNoteTitles: assistantMessage?.loadedNoteTitles,
            contextAttachments: assistantMessage?.contextAttachments
        )
        assistantMsg.inferenceMode = mode.rawValue
        // Persist extracted artifacts (JSON, YAML, code blocks, etc.)
        if let assistantMessage, !assistantMessage.artifacts.isEmpty {
            assistantMsg.setArtifacts(assistantMessage.artifacts)
        }
        if let assistantMessage {
            assistantMsg.setContentBlocks(assistantMessage.contentBlocks)
        }
        assistantMsg.chat = chat
        context.insert(assistantMsg)
        let newMessages = [userMsg, assistantMsg]

        // Cross-system note association: scan for [[wikilinks]] in the query
        if chat.linkedPageId == nil {
            if let linkedId = detectLinkedPageId(in: query, context: context) {
                chat.linkedPageId = linkedId
            }
        }

        do {
            try context.save()
            Log.db.info("Persisted chat \(chatId, privacy: .public): user + assistant messages")

            // Generate meaning anchor if chat has enough exchanges
            let messageCount = chat.messages?.count ?? 0
            if messageCount >= 3, let anchorService = AppBootstrap.shared?.meaningAnchorService {
                Task { await anchorService.generateAnchor(for: chatId) }
            }
        } catch {
            chat.chatType = originalChatType
            chat.linkedPageId = originalLinkedPageId
            chat.updatedAt = originalUpdatedAt
            for message in newMessages {
                context.delete(message)
            }
            if wasExisting {
                chat.messages = originalMessages
            } else {
                context.delete(chat)
            }
            Log.db.error("Failed to persist chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistedUserMessage(
        chatId: String,
        query: String,
        assistantMessage: ChatMessage?
    ) -> ChatMessage? {
        let currentMessages = chatState.messages
        guard !currentMessages.isEmpty else { return nil }

        if let assistantMessage,
           let assistantIndex = currentMessages.lastIndex(where: { $0.id == assistantMessage.id }) {
            return currentMessages[..<assistantIndex].last {
                $0.chatId == chatId && $0.role == .user
            }
        }

        return currentMessages.last {
            $0.chatId == chatId && $0.role == .user && $0.content == query
        } ?? currentMessages.last {
            $0.chatId == chatId && $0.role == .user
        }
    }

    static func gradeFromConfidence(_ confidence: Double) -> EvidenceGrade {
        switch confidence {
        case 0.85...: .a
        case 0.70..<0.85: .b
        case 0.50..<0.70: .c
        case 0.30..<0.50: .d
        default: .f
        }
    }

    // MARK: - Cross-System Note Association

    /// Scan text for [[wikilinks]] or "Note: <title>" references and match against existing pages.
    /// Returns the pageId of the first matched note, or nil.
    private func detectLinkedPageId(in text: String, context: ModelContext) -> String? {
        var candidates: [String] = []

        // Extract [[wikilink]] targets
        let wikiPattern = /\[\[([^\]]+)\]\]/
        for match in text.matches(of: wikiPattern) {
            candidates.append(String(match.1).trimmingCharacters(in: .whitespaces))
        }

        // Extract "Note: <title>" prefix (from command palette context injection)
        let notePattern = /Note: (.+?)(?:\n|$)/
        if let match = text.firstMatch(of: notePattern) {
            candidates.append(String(match.1).trimmingCharacters(in: .whitespaces))
        }

        guard !candidates.isEmpty else { return nil }

        for candidate in candidates {
            let lower = candidate.lowercased()
            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate { $0.title.localizedStandardContains(lower) }
            )
            // localizedStandardContains is case/diacritic-insensitive but may over-match;
            // filter to exact case-insensitive equality.
            if let page = fetchAll(
                descriptor,
                in: context,
                label: "linked page detection"
            )?.first(where: {
                $0.title.lowercased() == lower
            }) {
                return page.id
            }
        }
        return nil
    }
}
