#if EPISTEMOS_APP_STORE
import Foundation
import os

#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

// MARK: - Gateway

/// The in-process stand-in for June's Hermes gateway (Plan 1-MAS §3): speaks
/// the JSON-RPC frame protocol the vendored UI already uses (verified against
/// src/lib/hermes-gateway.ts) and answers `prompt.submit` with a streamed
/// local-engine turn — Apple Foundation Models when available, embedded
/// llama.cpp GGUF otherwise. No server, no subprocess, no secrets in JS.
@MainActor
final class JuneAgentGateway {
    private static let log = Logger(subsystem: "com.epistemos", category: "JuneAgentGateway")

    let store = JuneSessionStore()
    private let promptForge = JunePromptForge()

    /// Pushes a raw JSON string at the page (wired to
    /// `__EPISTEMOS_TAURI_SHIM__.gatewayDeliver` by the surface view).
    var deliver: ((String) -> Void)?

    private let appleFM = AppleFMQuickChatBackend()
    // The shared app-lifetime instance — the loaded GGUF model must survive
    // tab churn (warm invariant, mas_model_retained_on_switch). A private
    // instance here would double-load the model.
    private let localGGUF = LocalGGUFQuickChatBackend.shared
    private let agentCoreRunner = GooseMASAgentCoreRunner()
    private let approvals = JuneAgentApprovalRegistry()
    /// Drives download-on-select from June's model picker: the catalog's GGUF
    /// models are shown even when not installed, and picking one downloads it.
    let downloads = QuickChatModelDownloadManager()
    private var runningTurns: [String: Task<Void, Never>] = [:]
    /// The session June is currently showing (set on resume/create/submit) so
    /// "read latest" speaks the reply the user is looking at, not merely the
    /// most-recently-messaged session. Exposed read-only so the native
    /// all-chats sheet can mark the open conversation.
    private(set) var currentSessionID: String?
    /// Generous for a single-user app (one active + a few background) yet a
    /// hard ceiling against a runaway/compromised page.
    private static let maxConcurrentTurns = 8
    /// Runaway-response ceiling (very generous for a chat reply): bounds memory
    /// if a local model loops or a cloud stream misbehaves.
    private static let maxResponseBytes = 512 * 1024
    /// Thinking is valuable replay evidence, but it is still model output and
    /// must stay bounded on 16 GB machines.
    private static let maxPersistedReasoningBytes = 64 * 1024
    private static let maxPersistedToolResults = 64
    private static let defaultModelKey = "epistemos.june.generationModel"
    private nonisolated static let observableCompositionTools: Set<String> = [
        "vault.search",
        "vault.read",
        "vault.write",
        "vault.list",
        "pdf.to_markdown",
        "knowledge.recall",
        "web.search",
        "web.fetch",
        "http_fetch",
        "think",
    ]


    func handleFrame(_ raw: String) {
        guard raw.utf8.count <= 1_000_000 else {
            Self.log.warning("gateway frame over size bound; dropped")
            return
        }
        guard
            let data = raw.data(using: .utf8),
            let frame = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let method = frame["method"] as? String
        else {
            Self.log.warning("gateway frame failed validation; dropped")
            return
        }
        guard let rpcReplyID = JuneGatewayReplyID(rawValue: frame["id"]) else {
            Self.log.warning("gateway frame rejected invalid json-rpc id")
            return
        }
        let id = rpcReplyID.jsonValue
        let params = frame["params"] as? [String: Any] ?? [:]

        switch method {
        case "ping":
            reply(id: id, result: [String: Any]())
        case "session.create":
            let sessionID = UUID().uuidString
            let rawTitle = (params["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "New chat"
            let title = rawTitle == "New session" ? "New chat" : rawTitle
            var chosenModel: String?
            if let model = params["model"] as? String, selectableModelIDs().contains(model) {
                chosenModel = model
            }
            store.createSession(id: sessionID, title: title, model: chosenModel)
            currentSessionID = sessionID
            reply(id: id, result: ["session_id": sessionID])
        case "session.resume":
            guard let sessionID = params["session_id"] as? String else {
                replyError(id: id, code: -32602, message: "session_id required")
                return
            }
            currentSessionID = sessionID
            reply(id: id, result: ["session_id": sessionID])
        case "prompt.forge_preview":
            guard
                let text = params["text"] as? String,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                text.utf8.count <= 200_000
            else {
                replyError(id: id, code: -32602, message: "bounded text required")
                return
            }
            let requestedModel = (params["model"] as? String).flatMap(validModelID)
            let modelID = requestedModel ?? currentDefaultModelID()
            let activeVaultURL = AppBootstrap.shared?.vaultSync.isWatching == true
                ? AppBootstrap.shared?.vaultSync.vaultURL?.standardizedFileURL
                : nil
            let previewReplyID = rpcReplyID
            Task { [promptForge, weak self] in
                let payload = await Task.detached(priority: .userInitiated) {
                    promptForge.previewPayload(
                        originalText: text,
                        modelID: modelID,
                        activeVaultURL: activeVaultURL
                    )
                }.value
                self?.reply(id: previewReplyID.jsonValue, result: payload.dictionary)
            }
        case "prompt.submit":
            guard
                let sessionID = params["session_id"] as? String,
                let text = params["text"] as? String,
                !text.isEmpty, text.utf8.count <= 200_000
            else {
                replyError(id: id, code: -32602, message: "session_id and bounded text required")
                return
            }
            let requestedModel = (params["model"] as? String).flatMap(validModelID)
            guard runningTurns[sessionID] == nil else {
                // 4009 = "session busy", the code June's UI branches on.
                replyError(id: id, code: 4009, message: "session busy")
                return
            }
            // Defense-in-depth: bound total concurrent turns so a compromised
            // page can't exhaust memory/CPU by spawning unbounded engine Tasks
            // across many sessions (the per-session gate above only bounds one).
            guard runningTurns.count < Self.maxConcurrentTurns else {
                replyError(id: id, code: 4009, message: "too many active turns")
                return
            }
            reply(id: id, result: [String: Any]())
            startTurn(sessionID: sessionID, prompt: text, requestedModelID: requestedModel)
        case "session.interrupt":
            if let sessionID = params["session_id"] as? String {
                runningTurns[sessionID]?.cancel()
                runningTurns[sessionID] = nil
                approvals.denyPendingApprovals(sessionID: sessionID)
            }
            reply(id: id, result: [String: Any]())
        case "approval.respond":
            guard
                let sessionID = params["session_id"] as? String,
                let requestID = params["request_id"] as? String,
                let choice = params["choice"] as? String,
                JuneToolEventBounds.isBoundedToolProtocolID(requestID),
                choice.utf8.count <= JuneAgentApprovalRegistry.maxApprovalChoiceCharacters
            else {
                replyError(id: id, code: -32602, message: "session_id, request_id, and bounded choice required")
                return
            }
            guard let approved = Self.approvalDecision(from: choice) else {
                replyError(id: id, code: -32602, message: "unknown approval choice")
                return
            }
            guard approvals.popPendingApprovalID(sessionID: sessionID, requestID: requestID) else {
                replyError(id: id, code: 4040, message: "no pending approval")
                return
            }
            approvals.deliver(id: requestID, approved: approved)
            reply(id: id, result: ["accepted": true, "request_id": requestID])
        case "command.dispatch":
            guard
                let sessionID = params["session_id"] as? String,
                let command = params["command"] as? String
            else {
                replyError(id: id, code: -32602, message: "session_id and command required")
                return
            }
            guard let modelID = Self.modelID(fromModelCommand: command) else {
                reply(id: id, result: nil)
                return
            }
            guard setSessionModel(modelID, for: sessionID) else {
                replyError(id: id, code: -32602, message: "unknown model: \(modelID)")
                return
            }
            reply(id: id, result: ["accepted": true, "model": modelID])
        default:
            // Matches the proven Phase-0 spike behavior: unknown control-plane
            // methods resolve null (June's panels tolerate it); honest
            // per-method support arrives with later phases.
            Self.log.info("gateway rpc defaulted: \(method, privacy: .public)")
            reply(id: id, result: nil)
        }
    }

    private func startTurn(sessionID: String, prompt: String, requestedModelID: String? = nil) {
        currentSessionID = sessionID
        if let requestedModelID {
            _ = setSessionModel(requestedModelID, for: sessionID)
        }
        store.appendMessage(sessionID: sessionID, role: "user", content: prompt)
        // Keep the persisted title connected to the conversation (see
        // JuneSessionStore.autoTitleIfPlaceholder) — the native all-chats +
        // relaunch read the store, and June's own backfill never writes it.
        store.autoTitleIfPlaceholder(sessionID: sessionID, from: prompt)
        emit(type: "message.start", sessionID: sessionID, payload: [:])
        // Lane resolution from the persisted record (single source of truth —
        // written at session.create, survives relaunch), revalidated because a
        // lane can disappear (e.g. an uninstalled GGUF), else the default.
        let persisted = store.model(for: sessionID).flatMap {
            // Selectable (not just installed): a session pinned to a model that
            // is still downloading keeps it, and the turn surfaces the honest
            // download state rather than silently switching models.
            selectableModelIDs().contains($0) ? $0 : nil
        }
        let modelID = persisted ?? currentDefaultModelID()

        // Give the engine the conversation, not just the latest message — a
        // chat agent with no history is amnesiac. Bounded to the most recent
        // turns so a long thread can't overflow a local model's context (the
        // backend also guards via exceededContextWindow).
        let history = JuneAgentConversationContext.boundedHistory(store.loadMessages(sessionID: sessionID), for: modelID)

        let submittedAt = Date()
        let turn = Task { [weak self] in
            guard let self else { return }
            var full = ""
            var reasoning = ""
            var toolCalls: [PersistedToolCall] = []
            var toolResults: [PersistedToolResult] = []
            var answerPacketID: String?
            do {
                var completedByStream = false
                var stream = try self.makeStream(sessionID: sessionID, prompt: prompt, history: history, modelID: modelID)
                do {
                    eventLoop: for try await event in stream {
                        if Task.isCancelled { break }
                        switch event {
                        case .textDelta(let delta):
                            if full.isEmpty {
                                // Budget contract [agent_surface].first_token_ms_max.
                                JuneAgentPerfMetrics.shared.recordFirstToken(
                                    milliseconds: Date().timeIntervalSince(submittedAt) * 1000
                                )
                            }
                            full += delta
                            self.emit(type: "message.delta", sessionID: sessionID, payload: ["text": delta, "delta": delta])
                            // Runaway guard: a stuck local loop or a broken/hostile
                            // cloud stream can't grow the response without bound.
                            if full.utf8.count > Self.maxResponseBytes { break eventLoop }
                        case .thinkingDelta(let delta):
                            Self.appendBounded(delta, to: &reasoning, maxBytes: Self.maxPersistedReasoningBytes)
                            self.emit(type: "thinking.delta", sessionID: sessionID, payload: ["text": delta, "delta": delta])
                        case .toolStarted(let id, let name, let inputJson):
                            guard let toolID = JuneToolEventBounds.boundedToolProtocolID(id) else { break }
                            let toolName = JuneToolEventBounds.boundedToolMetadata(
                                name,
                                maxBytes: JuneToolEventBounds.maxToolNameBytes
                            )
                            guard !toolName.isEmpty else { break }
                            let boundedInput = JuneToolEventBounds.boundedToolPayload(inputJson)
                            if toolCalls.count < Self.maxPersistedToolResults,
                               !toolCalls.contains(where: { $0.id == toolID }) {
                                toolCalls.append(PersistedToolCall(
                                    id: toolID,
                                    toolCallID: toolID,
                                    name: toolName,
                                    toolName: toolName,
                                    arguments: boundedInput
                                ))
                            }
                            self.emit(
                                type: "tool.start", sessionID: sessionID,
                                payload: [
                                    "tool_call_id": toolID,
                                    "id": toolID,
                                    "tool_name": toolName,
                                    "name": toolName,
                                    "input_json": boundedInput,
                                ]
                            )
                        case .toolCompleted(let id, let name, let result, let isError):
                            guard let toolID = JuneToolEventBounds.boundedToolProtocolID(id) else { break }
                            let explicitToolName = JuneToolEventBounds.boundedToolMetadata(
                                name,
                                maxBytes: JuneToolEventBounds.maxToolNameBytes
                            )
                            let toolName = explicitToolName.isEmpty
                                ? (toolCalls.first { $0.id == toolID }?.name ?? "tool")
                                : explicitToolName
                            let boundedResult = JuneToolEventBounds.boundedToolPayload(result)
                            if toolResults.count < Self.maxPersistedToolResults {
                                toolResults.append(PersistedToolResult(
                                    id: toolID,
                                    name: toolName,
                                    content: isError ? "Error: \(boundedResult)" : boundedResult
                                ))
                            }
                            self.emit(
                                type: "tool.complete", sessionID: sessionID,
                                payload: [
                                    "tool_call_id": toolID,
                                    "id": toolID,
                                    "tool_name": toolName,
                                    "name": toolName,
                                    "result": boundedResult,
                                    "is_error": isError,
                                    "status": isError ? "error" : "ok",
                                ]
                            )
                        case .permissionRequired(let id, let toolName, let inputJson, let riskLevel):
                            let boundedToolName = JuneToolEventBounds.boundedToolMetadata(
                                toolName,
                                maxBytes: JuneToolEventBounds.maxToolNameBytes
                            )
                            let boundedRiskLevel = JuneToolEventBounds.boundedToolMetadata(
                                riskLevel,
                                maxBytes: JuneToolEventBounds.maxToolRiskLevelBytes
                            )
                            guard !boundedRiskLevel.isEmpty else {
                                self.approvals.deliver(id: id, approved: false)
                                break
                            }
                            guard self.approvals.recordPendingApproval(
                                id: id,
                                sessionID: sessionID,
                                toolName: boundedToolName
                            ) else { break }
                            self.emit(
                                type: "approval.request", sessionID: sessionID,
                                payload: [
                                    "request_id": id,
                                    "id": id,
                                    "tool_name": boundedToolName,
                                    "description": JuneToolEventBounds.approvalDescription(
                                        toolName: boundedToolName,
                                        riskLevel: boundedRiskLevel,
                                        inputJson: inputJson
                                    ),
                                    "command": boundedToolName,
                                    "risk_level": boundedRiskLevel,
                                    "input_json": JuneToolEventBounds.boundedToolPayload(inputJson),
                                    "allow_permanent": false,
                                ]
                            )
                        case .complete(let stopReason, let inputTokens, let outputTokens):
                            completedByStream = true
                            let packetID = await self.emitTurnAnswerPacket(
                                stopReason: stopReason,
                                inputTokens: inputTokens,
                                outputTokens: outputTokens,
                                modelID: modelID
                            )
                            answerPacketID = packetID
                            self.emit(
                                type: "message.complete", sessionID: sessionID,
                                payload: [
                                    "text": full,
                                    "status": Task.isCancelled ? "cancelled" : "ok",
                                    "stop_reason": stopReason,
                                    "input_tokens": inputTokens,
                                    "output_tokens": outputTokens,
                                    "answer_packet_id": packetID,
                                ]
                            )
                            break eventLoop
                        case .error(let message):
                            throw JuneGatewayError.modelPreparing(message)
                        }
                    }
                } catch let error as QuickChatError {
                    // Plan 1-MAS §2: an Apple FM guardrail trip falls back to the
                    // embedded GGUF lane instead of failing the turn — but only
                    // when nothing streamed yet and a local model is installed.
                    guard case .guardrailBlocked = error,
                          full.isEmpty,
                          self.localGGUF.unavailability() == nil else {
                        throw error
                    }
                    Self.log.info("Apple FM guardrail tripped; falling back to GGUF")
                    self.emit(
                        type: "status.update", sessionID: sessionID,
                        payload: ["text": "Switched to the on-device model for this reply."]
                    )
                    stream = Self.textEventStream(self.localGGUF.stream(
                        prompt: prompt,
                        instructions: JuneAgentConversationContext.localInstructions(withHistory: history, modelID: modelID),
                        maxNewTokens: JuneAgentConversationContext.localReplyBudgetTokens(for: modelID)
                    ))
                    fallbackLoop: for try await event in stream {
                        if Task.isCancelled { break }
                        switch event {
                        case .textDelta(let delta):
                            full += delta
                            self.emit(type: "message.delta", sessionID: sessionID, payload: ["text": delta, "delta": delta])
                            if full.utf8.count > Self.maxResponseBytes { break fallbackLoop }
                        case .thinkingDelta(let delta):
                            Self.appendBounded(delta, to: &reasoning, maxBytes: Self.maxPersistedReasoningBytes)
                            self.emit(type: "thinking.delta", sessionID: sessionID, payload: ["text": delta, "delta": delta])
                        default:
                            break
                        }
                    }
                }
                let status = Task.isCancelled ? "cancelled" : "ok"
                if !completedByStream {
                    if status == "ok" {
                        answerPacketID = await self.emitTurnAnswerPacket(
                            stopReason: "end_turn",
                            inputTokens: 0,
                            outputTokens: 0,
                            modelID: modelID
                        )
                    }
                    var payload: [String: Any] = ["text": full, "status": status]
                    if let answerPacketID {
                        payload["answer_packet_id"] = answerPacketID
                    }
                    self.emit(
                        type: "message.complete", sessionID: sessionID,
                        payload: payload
                    )
                }
                Self.observeCompositionIfEligible(
                    sessionID: sessionID,
                    prompt: prompt,
                    submittedAt: submittedAt,
                    toolNames: toolCalls.map(\.name),
                    succeeded: status == "ok"
                )
                let toolCallsJSON = Self.persistedToolCallsJSON(toolCalls)
                if !full.isEmpty || !reasoning.isEmpty || toolCallsJSON != nil {
                    self.store.appendMessage(
                        sessionID: sessionID,
                        role: "assistant",
                        content: full,
                        reasoning: reasoning.isEmpty ? nil : reasoning,
                        toolCalls: toolCallsJSON,
                        answerPacketID: answerPacketID
                    )
                    for result in toolResults {
                        self.store.appendMessage(
                            sessionID: sessionID,
                            role: "tool",
                            content: result.content,
                            toolCallID: result.id,
                            toolName: result.name
                        )
                    }
                }
            } catch {
                let described = JuneEngineErrorText.describe(error)
                Self.log.error("June turn failed: \(described, privacy: .public)")
                self.emit(
                    type: "message.complete", sessionID: sessionID,
                    payload: ["text": full.isEmpty ? "Error: \(described)" : full, "status": "error"]
                )
            }
            self.approvals.denyPendingApprovals(sessionID: sessionID)
            self.runningTurns[sessionID] = nil
        }
        runningTurns[sessionID] = turn
    }

    private func emitTurnAnswerPacket(
        stopReason: String,
        inputTokens: Int,
        outputTokens: Int,
        modelID: String
    ) async -> String {
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: stopReason,
            inputTokens: max(0, inputTokens),
            outputTokens: max(0, outputTokens),
            attentionMode: Self.answerPacketAttentionMode(forJuneModelID: modelID)
        )
        await AnswerPacketEmitter.shared.emit(packet)
        return packet.id
    }

    private static func answerPacketAttentionMode(forJuneModelID modelID: String) -> AttentionMode {
        if modelID == JuneModelID.cloud || CloudTextModelID(rawValue: modelID) != nil {
            return .dynamic
        }
        if modelID == JuneModelID.appleFM {
            return .dynamic
        }
        return .unavailable
    }

    private nonisolated static func observeCompositionIfEligible(
        sessionID: String,
        prompt: String,
        submittedAt: Date,
        toolNames: [String],
        succeeded: Bool
    ) {
        guard succeeded else { return }
        let sequence = boundedObservableCompositionTools(toolNames)
        guard sequence.count >= 2,
              let traceJSON = compositionTraceJSON(
                sessionID: sessionID,
                prompt: prompt,
                submittedAt: submittedAt,
                toolSequence: sequence
              ) else { return }

        #if canImport(agent_coreFFI)
        Task.detached(priority: .utility) {
            do {
                _ = try observeComposition(traceJson: traceJSON)
            } catch {
                Task { @MainActor in
                    Self.log.warning("skill composition observation failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        #endif
    }

    private nonisolated static func boundedObservableCompositionTools(_ names: [String]) -> [String] {
        var sequence: [String] = []
        sequence.reserveCapacity(min(names.count, 64))
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty,
                  name.count <= 128,
                  observableCompositionTools.contains(name),
                  !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                continue
            }
            sequence.append(name)
            if sequence.count == 64 { break }
        }
        return sequence
    }

    private nonisolated static func compositionTraceJSON(
        sessionID: String,
        prompt: String,
        submittedAt: Date,
        toolSequence: [String]
    ) -> String? {
        let elapsed = max(0, Date().timeIntervalSince(submittedAt) * 1000)
        let cappedDuration = min(elapsed, Double(UInt32.max)).rounded()
        let boundedGoal = inferredCompositionGoal(from: prompt)
        let object: [String: Any] = [
            "composition_id": "\(String(sessionID.prefix(64)))-\(UUID().uuidString)",
            "ts": ISO8601DateFormatter().string(from: Date()),
            "tool_sequence": toolSequence,
            "total_duration_ms": UInt32(cappedDuration),
            "inferred_goal": boundedGoal,
            "user_accepted": true,
        ]
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              data.count <= 64 * 1024 else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private nonisolated static func inferredCompositionGoal(from prompt: String) -> String {
        let collapsed = prompt
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .prefix(32)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(256))
    }

    private func makeAgentCoreCloudStream(
        sessionID: String,
        prompt: String,
        history: [JuneSessionStore.Message],
        modelID: String,
        cloudModel: CloudTextModelID?
    ) throws -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error> {
        let providerName = try agentCoreProviderName(modelID: modelID, cloudModel: cloudModel)
        let approvals = approvals
        return agentCoreRunner.streamGooseMASAgentCoreRun(
            sessionID: sessionID,
            prompt: prompt,
            systemPrompt: JuneAgentConversationContext.agentCloudInstructions(withHistory: history),
            maxTokens: 4096,
            providerName: providerName,
            vaultPath: JuneAgentCoreVaultScope.vaultPathForAgentCore(),
            permissionHandler: { request in
                approvals.awaitDecision(id: request.id)
            }
        )
    }

    /// Engine routing (Plan 1-MAS §2/§3): local lanes stream chat-only text
    /// deltas; cloud lanes stream the full in-process agent_core event feed.
    /// `history` is the bounded recent conversation (including the current
    /// user message); local lanes fold it into the system context because the
    /// QuickChat backends take a single prompt.
    private func makeStream(
        sessionID: String,
        prompt: String,
        history: [JuneSessionStore.Message],
        modelID: String
    ) throws -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error> {
        if let cloudModel = CloudTextModelID(rawValue: modelID) {
            return try makeAgentCoreCloudStream(
                sessionID: sessionID,
                prompt: prompt,
                history: history,
                modelID: modelID,
                cloudModel: cloudModel
            )
        }

        switch modelID {
        case JuneModelID.appleFM:
            return Self.textEventStream(
                appleFM.stream(
                    prompt: prompt,
                    instructions: JuneAgentConversationContext.localInstructions(withHistory: history, modelID: modelID)
                )
            )
        case JuneModelID.cloud:
            return try makeAgentCoreCloudStream(
                sessionID: sessionID,
                prompt: prompt,
                history: history,
                modelID: modelID,
                cloudModel: nil
            )
        default:
            let instructions = JuneAgentConversationContext.localInstructions(withHistory: history, modelID: modelID)
            // A specific GGUF model the user picked: run it when installed,
            // otherwise surface the honest download state (never a cryptic
            // engine error, never a silent fallback to a different model).
            if let entry = GGUFModelCatalog.entry(id: modelID) {
                if let ramProblem = GGUFModelCatalog.ramGate(for: entry) {
                    throw JuneGatewayError.modelPreparing("\(entry.displayName) can't run on this Mac. \(ramProblem.userCopy)")
                }
                localGGUF.setPreferredModel(modelID)
                switch downloads.state(for: entry) {
                case .installed:
                    return Self.textEventStream(
                        localGGUF.stream(
                            prompt: prompt,
                            instructions: instructions,
                            maxNewTokens: JuneAgentConversationContext.localReplyBudgetTokens(for: modelID)
                        )
                    )
                case .downloading(let p):
                    throw JuneGatewayError.modelPreparing("\(entry.displayName) is downloading (\(Int(p * 100))%). Try again in a moment.")
                case .verifying:
                    throw JuneGatewayError.modelPreparing("\(entry.displayName) is finishing its download. Try again in a moment.")
                case .failed(let why):
                    throw JuneGatewayError.modelPreparing("\(entry.displayName) couldn't be downloaded (\(why)). Re-select it to retry.")
                case .notInstalled:
                    downloads.beginDownload(entry)
                    throw JuneGatewayError.modelPreparing("Downloading \(entry.displayName) now — try again once it's ready.")
                }
            }
            // Legacy/unknown local id (e.g. the old single local-gguf lane):
            // best available on-device lane.
            if AppleFMQuickChatBackend.unavailability() == nil {
                return Self.textEventStream(appleFM.stream(prompt: prompt, instructions: instructions))
            }
            return Self.textEventStream(
                localGGUF.stream(
                    prompt: prompt,
                    instructions: instructions,
                    maxNewTokens: JuneAgentConversationContext.localReplyBudgetTokens(for: modelID)
                )
            )
        }
    }

    private static func textEventStream(
        _ stream: AsyncThrowingStream<String, Error>
    ) -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let task = Task {
                let thinkingRouter = ThinkTagStreamRouter()
                do {
                    for try await delta in stream {
                        let emit = thinkingRouter.ingest(delta)
                        if !emit.thinking.isEmpty {
                            continuation.yield(.thinkingDelta(emit.thinking))
                        }
                        if !emit.visible.isEmpty {
                            continuation.yield(.textDelta(emit.visible))
                        }
                    }
                    let remainder = thinkingRouter.flush()
                    if !remainder.thinking.isEmpty {
                        continuation.yield(.thinkingDelta(remainder.thinking))
                    }
                    if !remainder.visible.isEmpty {
                        continuation.yield(.textDelta(remainder.visible))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func agentCoreProviderName(modelID: String, cloudModel: CloudTextModelID?) throws -> String {
        if let cloudModel {
            guard cloudModel.provider.supportsAgentTier else {
                throw JuneGatewayError.modelPreparing(
                    "\(cloudModel.provider.displayName) is not enabled for Workspace agent tools in the App Store build yet. Pick OpenAI, Anthropic, or an on-device chat model."
                )
            }
            guard AppBootstrap.shared?.inferenceState.hasConfiguredCloudAccess(for: cloudModel.provider) == true else {
                throw JuneGatewayError.cloudNotConfigured
            }
            return Self.agentCoreSlug(selectedModel: cloudModel.rawValue, provider: cloudModel.provider)
        }

        guard modelID == JuneModelID.cloud,
              let inference = AppBootstrap.shared?.inferenceState else {
            throw JuneGatewayError.cloudNotConfigured
        }
        var candidates: [CloudModelProvider] = []
        if let active = inference.activeAIProvider.cloudProvider {
            candidates.append(active)
        }
        candidates.append(contentsOf: CloudModelProvider.preferredOrder)
        var seen: Set<CloudModelProvider> = []
        for provider in candidates where seen.insert(provider).inserted {
            guard provider.supportsAgentTier,
                  inference.hasConfiguredCloudAccess(for: provider) else { continue }
            let selected = inference.preferredCloudModel(for: provider)
            return Self.agentCoreSlug(selectedModel: selected.rawValue, provider: provider)
        }
        throw JuneGatewayError.cloudNotConfigured
    }

    private static func agentCoreSlug(selectedModel: String, provider: CloudModelProvider) -> String {
        GooseInProcessACPServer.agentCoreSlug(
            forSelectedModel: selectedModel,
            providerID: provider.rawValue
        ) ?? defaultAgentCoreProviderSlug(for: provider)
    }

    private static func defaultAgentCoreProviderSlug(for provider: CloudModelProvider) -> String {
        switch provider {
        case .openAI:
            return "openai"
        case .anthropic:
            return "claude_sonnet"
        case .google:
            return "gemini_pro"
        case .zai:
            return "zai"
        case .kimi:
            return "kimi"
        case .minimax:
            return "minimax"
        case .deepseek:
            return "deepseek"
        }
    }

    private static func appendBounded(_ delta: String, to text: inout String, maxBytes: Int) {
        guard !delta.isEmpty, maxBytes > 0, text.utf8.count < maxBytes else { return }
        var candidate = text + delta
        while candidate.utf8.count > maxBytes, !candidate.isEmpty {
            candidate.removeLast()
        }
        text = candidate
    }

    private static func persistedToolCallsJSON(_ calls: [PersistedToolCall]) -> String? {
        guard !calls.isEmpty,
              let data = try? JSONEncoder().encode(calls) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func approvalDecision(from choice: String) -> Bool? {
        let normalized = choice.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("allow") || normalized.contains("approve") || normalized == "yes" {
            return true
        }
        if normalized.contains("deny") || normalized.contains("reject") || normalized == "no" {
            return false
        }
        return nil
    }

    // MARK: - Model catalog (drives June's composer model chip)

    /// The most recent assistant reply (most-recently-active session's last
    /// assistant message) — drives June's native "read aloud" control. Read
    /// from the store so it survives across turns and reflects what June shows.
    func latestAssistantReply() -> String? {
        // Prefer the session June is currently showing; fall back to the
        // most-recently-active session so "read latest" still works right after
        // launch before any resume/submit has been seen.
        let sessionID = currentSessionID
            ?? store.allSessions().max(by: { $0.lastActive < $1.lastActive })?.id
        guard let sessionID else { return nil }
        return store.loadMessages(sessionID: sessionID).last { $0.role == "assistant" }?.content
    }

    /// Cancels an in-flight turn when a session is deleted (bridge delete path).
    func forgetSession(_ sessionID: String) {
        runningTurns[sessionID]?.cancel()
        runningTurns[sessionID] = nil
        approvals.denyPendingApprovals(sessionID: sessionID)
        // Deleting the shown session: drop the pointer so "read latest" falls
        // back to the most-recently-active session rather than a dead one.
        if currentSessionID == sessionID { currentSessionID = nil }
    }

    /// Runnable-now lanes, ordered by the product default: configured cloud
    /// agent lanes first, the generic configured-provider cloud lane, then local
    /// privacy/offline chat lanes.
    func availableModelIDs() -> [String] {
        var ids: [String] = []
        ids.append(contentsOf: JuneAgentModelCatalog.directCloudModelIDs(configuredOnly: true))
        ids.append(JuneModelID.cloud)
        if AppleFMQuickChatBackend.unavailability() == nil { ids.append(JuneModelID.appleFM) }
        if localGGUF.isAvailableInThisBuild {
            ids.append(contentsOf: GGUFModelCatalog.installedEntries().map(\.id))
        }
        return ids
    }

    /// Everything the picker offers — the runnable lanes PLUS the not-yet-
    /// installed GGUF models (picking one downloads it). Selecting a
    /// downloadable model must persist, so it becomes active once it lands.
    func selectableModelIDs() -> [String] {
        var ids: [String] = []
        ids.append(JuneModelID.cloud)
        ids.append(contentsOf: JuneAgentModelCatalog.directCloudModelIDs(configuredOnly: false))
        if AppleFMQuickChatBackend.unavailability() == nil { ids.append(JuneModelID.appleFM) }
        if localGGUF.isAvailableInThisBuild {
            ids.append(contentsOf: GGUFModelCatalog.entries.map(\.id))
        }
        return ids
    }

    func currentDefaultModelID() -> String {
        if let saved = UserDefaults.standard.string(forKey: Self.defaultModelKey),
           selectableModelIDs().contains(saved) {
            return saved
        }
        // Cloud is the primary experience. If a provider is configured, pick
        // its preferred model; otherwise choose the generic cloud lane so the
        // first send fails honestly with cloudNotConfigured instead of silently
        // downgrading to local chat.
        return preferredConfiguredCloudModelID() ?? JuneModelID.cloud
    }

    private func preferredConfiguredCloudModelID() -> String? {
        preferredConfiguredCloudModel()?.rawValue
    }

    private func preferredConfiguredCloudModel() -> CloudTextModelID? {
        guard let inference = AppBootstrap.shared?.inferenceState else { return nil }
        var candidates: [CloudModelProvider] = []
        if let active = inference.activeAIProvider.cloudProvider {
            candidates.append(active)
        }
        candidates.append(contentsOf: JuneAgentModelCatalog.directCloudProviders)
        var seen: Set<CloudModelProvider> = []
        for provider in candidates where seen.insert(provider).inserted {
            guard provider.supportsAgentTier,
                  inference.hasConfiguredCloudAccess(for: provider) else { continue }
            return inference.preferredCloudModel(for: provider)
        }
        return nil
    }

    @discardableResult
    func setDefaultModel(_ id: String) -> Bool {
        guard selectableModelIDs().contains(id) else { return false }
        UserDefaults.standard.set(id, forKey: Self.defaultModelKey)
        if let currentSessionID {
            _ = store.setModel(sessionID: currentSessionID, model: id)
        }
        prepareSelectedModel(id)
        return true
    }

    @discardableResult
    func setSessionModel(_ id: String, for sessionID: String) -> Bool {
        guard selectableModelIDs().contains(id) else { return false }
        currentSessionID = sessionID
        guard store.setModel(sessionID: sessionID, model: id) else { return false }
        prepareSelectedModel(id)
        return true
    }

    private func validModelID(_ id: String) -> String? {
        selectableModelIDs().contains(id) ? id : nil
    }

    private static func modelID(fromModelCommand command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/model") else { return nil }
        let rest = trimmed.dropFirst("/model".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = rest.split(separator: " ").first else { return nil }
        return String(first)
    }

    private func prepareSelectedModel(_ id: String) {
        // A GGUF pick steers the local lane and, if it isn't downloaded yet,
        // starts the download so the next turn can run it. The RAM gate is
        // checked here too, so an oversized row never starts moving bytes.
        if let entry = GGUFModelCatalog.entry(id: id) {
            localGGUF.setPreferredModel(id)
            guard GGUFModelCatalog.ramGate(for: entry) == nil else { return }
            if GGUFModelCatalog.installedURL(for: entry) == nil {
                downloads.beginDownload(entry)
            }
        }
        if let cloudModel = CloudTextModelID(rawValue: id) {
            AppBootstrap.shared?.inferenceState.setActiveAIProvider(
                AIProviderSelection(cloudProvider: cloudModel.provider)
            )
            AppBootstrap.shared?.inferenceState.setPreferredChatModelSelection(.cloud(cloudModel))
        }
    }

    func modelsPayload() -> [[String: Any]] {
        JuneAgentModelCatalog.modelsPayload(
            localGGUFAvailable: localGGUF.isAvailableInThisBuild,
            downloads: downloads,
            preferredConfiguredCloudModel: preferredConfiguredCloudModel()
        )
    }

    private func emit(type: String, sessionID: String, payload: [String: Any]) {
        let frame: [String: Any] = [
            "method": "event",
            "params": ["type": type, "session_id": sessionID, "payload": payload],
        ]
        push(frame)
    }

    private func reply(id: Any?, result: Any?) {
        var frame: [String: Any] = ["jsonrpc": "2.0"]
        frame["id"] = id ?? NSNull()
        frame["result"] = result ?? NSNull()
        push(frame)
    }

    private func replyError(id: Any?, code: Int, message: String) {
        var frame: [String: Any] = ["jsonrpc": "2.0"]
        frame["id"] = id ?? NSNull()
        frame["error"] = ["code": code, "message": message]
        push(frame)
    }

    private func push(_ frame: [String: Any]) {
        guard
            JSONSerialization.isValidJSONObject(frame),
            let data = try? JSONSerialization.data(withJSONObject: frame),
            let json = String(data: data, encoding: .utf8)
        else {
            Self.log.error("gateway frame not serializable")
            return
        }
        deliver?(json)
    }
}

#endif
