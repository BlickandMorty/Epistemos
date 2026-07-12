#if EPISTEMOS_APP_STORE
import Foundation
import os

#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

// MARK: - Gateway

/// The MAS in-process June gateway (Plan 1-MAS §3): speaks the JSON-RPC frame
/// protocol the vendored UI already uses and answers `prompt.submit` through
/// App Store-approved lanes: agent_core cloud for agent turns, Apple Foundation
/// Models and the selected in-process GGUF catalog for local chat. No server,
/// subprocess, downloaded executable runtime, or secrets in JS.
@MainActor
final class JuneAgentGateway {
    private static let log = Logger(subsystem: "com.epistemos", category: "JuneAgentGateway")

    let store = JuneSessionStore()

    /// Pushes a raw JSON string at the page (wired to
    /// `__EPISTEMOS_TAURI_SHIM__.gatewayDeliver` by the surface view).
    var deliver: ((String) -> Void)?

    private let appleFM = AppleFMQuickChatBackend()
    // Shared app-lifetime local runtime so the selected GGUF survives June view
    // churn and unloads only under the explicit memory-pressure path.
    private let localGGUF = LocalGGUFQuickChatBackend.shared
    private let agentCoreRunner = GooseMASAgentCoreRunner()
    private let approvals = JuneAgentApprovalRegistry()
    /// Owns explicit, checksum-verified model-data downloads into the sandbox.
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
    private nonisolated static let observableCompositionTools = JuneMASToolPolicy.allowedObservableCompositionToolNames


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
        Self.log.info("gateway rpc received: \(method, privacy: .public)")

        switch method {
        case "ping":
            reply(id: id, result: [String: Any]())
        case "session.create":
            let sessionID = UUID().uuidString
            let rawTitle = (params["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "New chat"
            let title = rawTitle == "New session" ? "New chat" : rawTitle
            var chosenModel: String?
            if let model = params["model"] as? String,
               !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let selected = explicitlyAdmittedModelID(model) else {
                    replyError(id: id, code: -32602, message: modelSelectionFailureMessage(model))
                    return
                }
                chosenModel = selected
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
            Self.log.notice("prompt.forge_preview rejected; per-message Prompt Forge disabled in MAS")
            replyError(
                id: id,
                code: 4101,
                message: "Per-message Prompt Forge is disabled in the App Store build. Send keeps your prompt unchanged."
            )
        case "prompt.submit":
            guard
                let sessionID = params["session_id"] as? String,
                let text = params["text"] as? String,
                !text.isEmpty, text.utf8.count <= 200_000
            else {
                replyError(id: id, code: -32602, message: "session_id and bounded text required")
                return
            }
            let requestedModel = (params["model"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let requestedModel, !requestedModel.isEmpty,
               !setSessionModel(requestedModel, for: sessionID) {
                replyError(
                    id: id,
                    code: -32602,
                    message: modelSelectionFailureMessage(requestedModel)
                )
                return
            }
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
            startTurn(sessionID: sessionID, prompt: text)
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
                replyError(id: id, code: -32602, message: modelSelectionFailureMessage(modelID))
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

    @discardableResult
    func submitEpdocAssist(
        prompt: String,
        context: JuneEpdocAssistContext
    ) -> JuneEpdocAssistSubmissionResult {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            return .unavailable("Ask June with a non-empty note request.")
        }

        let sessionID: String
        if let currentSessionID {
            sessionID = currentSessionID
        } else {
            sessionID = UUID().uuidString
            store.createSession(
                id: sessionID,
                title: "Epdoc: \(context.title)",
                model: currentDefaultModelID()
            )
            currentSessionID = sessionID
        }

        guard runningTurns[sessionID] == nil else {
            return .busy(sessionID: sessionID)
        }
        guard runningTurns.count < Self.maxConcurrentTurns else {
            return .unavailable("June has too many active turns.")
        }

        startTurn(
            sessionID: sessionID,
            prompt: context.promptPacket(userPrompt: trimmedPrompt)
        )
        return .submitted(sessionID: sessionID)
    }

    private func startTurn(sessionID: String, prompt: String) {
        currentSessionID = sessionID
        store.appendMessage(sessionID: sessionID, role: "user", content: prompt)
        // Keep the persisted title connected to the conversation (see
        // JuneSessionStore.autoTitleIfPlaceholder) — the native all-chats +
        // relaunch read the store, and June's own backfill never writes it.
        store.autoTitleIfPlaceholder(sessionID: sessionID, from: prompt)
        emit(type: "message.start", sessionID: sessionID, payload: [:])
        // A persisted session choice is exact product state, even when its
        // credential, consent, download, or RAM gate later changes. Preserve it
        // so the selected lane can report its real blocker instead of silently
        // switching this conversation to another model.
        let persisted = store.model(for: sessionID).flatMap { rawModelID in
            let trimmed = rawModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
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
            var fullByteCount = 0
            var reasoning = ""
            var reasoningByteCount = 0
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
                            let wasEmpty = full.isEmpty
                            let acceptedText = Self.appendBounded(
                                delta,
                                to: &full,
                                byteCount: &fullByteCount,
                                maxBytes: Self.maxResponseBytes
                            )
                            if wasEmpty, !acceptedText.isEmpty {
                                // Budget contract [agent_surface].first_token_ms_max.
                                JuneAgentPerfMetrics.shared.recordFirstToken(
                                    milliseconds: Date().timeIntervalSince(submittedAt) * 1000
                                )
                            }
                            if !acceptedText.isEmpty {
                                self.emit(
                                    type: "message.delta",
                                    sessionID: sessionID,
                                    payload: ["text": acceptedText, "delta": acceptedText]
                                )
                            }
                            // If the next scalar cannot fit, preserving output
                            // order means the bounded reply is complete.
                            if (!delta.isEmpty && acceptedText.isEmpty)
                                || fullByteCount >= Self.maxResponseBytes {
                                break eventLoop
                            }
                        case .thinkingDelta(let delta):
                            let acceptedReasoning = Self.appendBounded(
                                delta,
                                to: &reasoning,
                                byteCount: &reasoningByteCount,
                                maxBytes: Self.maxPersistedReasoningBytes
                            )
                            if !acceptedReasoning.isEmpty {
                                self.emit(
                                    type: "thinking.delta",
                                    sessionID: sessionID,
                                    payload: ["text": acceptedReasoning, "delta": acceptedReasoning]
                                )
                            }
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
                            if !Task.isCancelled {
                                try Self.requireVisibleAssistantReply(full, modelID: modelID)
                            }
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
                            let acceptedText = Self.appendBounded(
                                delta,
                                to: &full,
                                byteCount: &fullByteCount,
                                maxBytes: Self.maxResponseBytes
                            )
                            if !acceptedText.isEmpty {
                                self.emit(
                                    type: "message.delta",
                                    sessionID: sessionID,
                                    payload: ["text": acceptedText, "delta": acceptedText]
                                )
                            }
                            if (!delta.isEmpty && acceptedText.isEmpty)
                                || fullByteCount >= Self.maxResponseBytes {
                                break fallbackLoop
                            }
                        case .thinkingDelta(let delta):
                            let acceptedReasoning = Self.appendBounded(
                                delta,
                                to: &reasoning,
                                byteCount: &reasoningByteCount,
                                maxBytes: Self.maxPersistedReasoningBytes
                            )
                            if !acceptedReasoning.isEmpty {
                                self.emit(
                                    type: "thinking.delta",
                                    sessionID: sessionID,
                                    payload: ["text": acceptedReasoning, "delta": acceptedReasoning]
                                )
                            }
                        default:
                            break
                        }
                    }
                }
                let status = Task.isCancelled ? "cancelled" : "ok"
                if !completedByStream {
                    if status == "ok" {
                        try Self.requireVisibleAssistantReply(full, modelID: modelID)
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
                let errorText = full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Error: \(described)"
                    : "\(full)\n\nError: \(described)"
                Self.log.error("June turn failed: \(described, privacy: .public)")
                self.store.appendMessage(
                    sessionID: sessionID,
                    role: "assistant",
                    content: errorText
                )
                self.emit(
                    type: "message.complete", sessionID: sessionID,
                    payload: ["text": errorText, "status": "error"]
                )
            }
            self.approvals.denyPendingApprovals(sessionID: sessionID)
            self.runningTurns[sessionID] = nil
        }
        runningTurns[sessionID] = turn
    }

    private static func requireVisibleAssistantReply(_ text: String, modelID: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw JuneGatewayError.modelPreparing(emptySuccessfulTurnMessage(modelID: modelID))
        }
    }

    private static func emptySuccessfulTurnMessage(modelID: String) -> String {
        "June did not receive any reply text from the selected MAS model (\(modelID)). Check Settings > June Models for cloud access, or choose Apple Intelligence or an installed local GGUF model in June, then try again."
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
                  JuneMASToolPolicy.isAllowedAgentToolName(name),
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

    /// Engine routing (Plan 1-MAS §2/§3): available local lanes stream
    /// chat-only text deltas; cloud lanes stream the full in-process
    /// agent_core event feed.
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
            // A specific selected GGUF model. Runtime linkage is in-process;
            // only checksum-verified model data is downloaded into the sandbox.
            if let entry = GGUFModelCatalog.entry(id: modelID) {
                let instructions = JuneAgentConversationContext.localInstructions(withHistory: history, modelID: modelID)
                guard localGGUF.isAvailableInThisBuild else {
                    throw JuneGatewayError.modelPreparing("\(entry.displayName) isn't available in this build. Use Cloud Agent or Apple Intelligence.")
                }
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
            let boundedID = String(modelID.prefix(120))
            throw JuneGatewayError.modelPreparing(
                "The selected model (\(boundedID)) is not connected to MAS June. Choose a June model in Settings."
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
                            guard Self.yieldLocalEvent(
                                .thinkingDelta(emit.thinking),
                                to: continuation
                            ) else { return }
                        }
                        if !emit.visible.isEmpty {
                            guard Self.yieldLocalEvent(
                                .textDelta(emit.visible),
                                to: continuation
                            ) else { return }
                        }
                    }
                    let remainder = thinkingRouter.flush()
                    if !remainder.thinking.isEmpty {
                        guard Self.yieldLocalEvent(
                            .thinkingDelta(remainder.thinking),
                            to: continuation
                        ) else { return }
                    }
                    if !remainder.visible.isEmpty {
                        guard Self.yieldLocalEvent(
                            .textDelta(remainder.visible),
                            to: continuation
                        ) else { return }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func yieldLocalEvent(
        _ event: GooseMASAgentCoreRunEvent,
        to continuation: AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error>.Continuation
    ) -> Bool {
        switch continuation.yield(event) {
        case .enqueued:
            return true
        case .dropped:
            continuation.finish(throwing: JuneGatewayError.modelPreparing(
                "June could not keep up with the bounded local-model output stream. The partial answer was stopped; try again."
            ))
            return false
        case .terminated:
            return false
        @unknown default:
            continuation.finish(throwing: JuneGatewayError.modelPreparing(
                "June could not keep up with the bounded local-model output stream. The partial answer was stopped; try again."
            ))
            return false
        }
    }

    private func agentCoreProviderName(modelID: String, cloudModel: CloudTextModelID?) throws -> String {
        if let cloudModel {
            guard cloudModel.provider.supportsAgentTier,
                  CloudTextModelID.juneAgentModels(for: cloudModel.provider).contains(cloudModel) else {
                throw JuneGatewayError.modelPreparing(
                    "\(cloudModel.displayName) is not connected to MAS June. Pick a model shown in June or MAS Settings."
                )
            }
            guard AppBootstrap.shared?.inferenceState.hasConfiguredCloudAccess(for: cloudModel.provider) == true else {
                throw JuneGatewayError.cloudNotConfigured
            }
            try requireCloudDataConsent(for: cloudModel.provider)
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
            try requireCloudDataConsent(for: provider)
            return Self.agentCoreSlug(selectedModel: selected.rawValue, provider: provider)
        }
        throw JuneGatewayError.cloudNotConfigured
    }

    private func requireCloudDataConsent(for provider: CloudModelProvider) throws {
        guard CloudModelProvider.juneAgentProviders.contains(provider) else {
            throw JuneGatewayError.modelPreparing(
                "\(provider.displayName) is not connected to MAS June."
            )
        }
        guard AgentCloudConsentStore.shared.hasConsent(for: provider) else {
            let descriptor = AgentCloudProviderDescriptor.descriptor(for: provider)
            throw JuneGatewayError.cloudConsentRequired(
                provider: descriptor.displayName,
                destination: descriptor.dataDestination
            )
        }
    }

    private static func agentCoreSlug(selectedModel: String, provider: CloudModelProvider) -> String {
        GooseMASAgentCoreProviderSlug.resolve(
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

    private static func appendBounded(
        _ delta: String,
        to text: inout String,
        byteCount: inout Int,
        maxBytes: Int
    ) -> String {
        guard !delta.isEmpty, maxBytes > 0, byteCount < maxBytes else { return "" }
        let remainingBytes = maxBytes - byteCount
        var accepted = ""
        var acceptedByteCount = 0
        var exhaustedBudget = false
        for scalar in delta.unicodeScalars {
            let scalarByteCount = utf8ByteCount(for: scalar)
            guard scalarByteCount <= remainingBytes - acceptedByteCount else {
                exhaustedBudget = true
                break
            }
            accepted.unicodeScalars.append(scalar)
            acceptedByteCount += scalarByteCount
        }
        guard acceptedByteCount > 0 else {
            if exhaustedBudget { byteCount = maxBytes }
            return ""
        }
        text.append(accepted)
        byteCount = exhaustedBudget ? maxBytes : byteCount + acceptedByteCount
        return accepted
    }

    private static func utf8ByteCount(for scalar: Unicode.Scalar) -> Int {
        switch scalar.value {
        case 0...0x7F: 1
        case 0x80...0x7FF: 2
        case 0x800...0xFFFF: 3
        default: 4
        }
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

    /// MAS-owned "read visible agent surface" text. The primary behavior still
    /// speaks the latest assistant reply, but the empty/new-session surface must
    /// not silently no-op: the owner-visible command should always explain what
    /// is on the active June surface.
    func visibleAgentSurfaceReadAloudText() -> String? {
        if let reply = latestAssistantReply()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reply.isEmpty {
            return reply
        }

        let sessionID = currentSessionID
            ?? store.allSessions().max(by: { $0.lastActive < $1.lastActive })?.id
        if let sessionID {
            let messages = store.loadMessages(sessionID: sessionID)
            if let latestVisibleMessage = messages.last(where: { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                let rolePrefix = latestVisibleMessage.role == "user" ? "Latest user message: " : ""
                return rolePrefix + latestVisibleMessage.content
            }
        }

        return "June is open. Start a session or select an existing assistant reply to read it aloud."
    }

    func latestEpdocAssistNoteSuggestion(
        sessionID: String,
        context: JuneEpdocAssistContext
    ) -> JuneEpdocAssistSuggestionStageResult {
        guard runningTurns[sessionID] == nil else {
            return .busy(sessionID: sessionID)
        }
        guard let reply = store.loadMessages(sessionID: sessionID).last(where: { $0.role == "assistant" })?.content else {
            return .unavailable("June has not replied in this Epdoc session yet.")
        }
        return JuneEpdocAssistNoteSuggestionParser.parseLatestReply(
            reply,
            sessionID: sessionID,
            context: context
        )
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

    /// A lost June renderer cannot consume any more native event frames. Stop
    /// every scoped turn and approval before the bundled page is reloaded; the
    /// native session store retains the resulting cancelled/error truth for
    /// the recovered UI to reload.
    func cancelAllTurnsForSurfaceRecovery() {
        let sessionIDs = Array(runningTurns.keys)
        for sessionID in sessionIDs {
            runningTurns[sessionID]?.cancel()
            approvals.denyPendingApprovals(sessionID: sessionID)
        }
        runningTurns.removeAll(keepingCapacity: true)
        Self.log.error("June renderer recovery cancelled \(sessionIDs.count, privacy: .public) in-flight turn(s)")
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
        ids.append(contentsOf: JuneAgentModelCatalog.directCloudModelIDs(configuredOnly: true))
        if AppleFMQuickChatBackend.unavailability() == nil { ids.append(JuneModelID.appleFM) }
        if localGGUF.isAvailableInThisBuild {
            ids.append(contentsOf: GGUFModelCatalog.entries.map(\.id))
        }
        return ids
    }

    func currentDefaultModelID() -> String {
        if let saved = UserDefaults.standard.string(forKey: Self.defaultModelKey) {
            if let repaired = repairedDefaultModelID(saved) {
                if repaired != saved {
                    Self.log.notice(
                        "June default model repaired staleSaved=\(saved, privacy: .public) repaired=\(repaired, privacy: .public)"
                    )
                    UserDefaults.standard.set(repaired, forKey: Self.defaultModelKey)
                }
                return repaired
            }
            Self.log.notice("June default model removed unavailableSaved=\(saved, privacy: .public)")
            UserDefaults.standard.removeObject(forKey: Self.defaultModelKey)
        }
        // Product default: use a configured cloud agent when present; otherwise
        // prefer Apple Intelligence if it is available on this Mac. Only fall
        // back to the generic cloud lane when no runnable local lane exists, so
        // clean App Store installs either produce an answer or surface one clear
        // configuration/availability reason instead of appearing inert. This
        // startup path still never synchronously reads Keychain.
        return preferredCachedConfiguredCloudModelID() ?? preferredLocalDefaultModelID() ?? JuneModelID.cloud
    }

    private func repairedDefaultModelID(_ id: String) -> String? {
        guard selectableModelIDs().contains(id) || CloudTextModelID(rawValue: id) != nil else {
            return nil
        }
        if id == JuneModelID.cloud { return JuneModelID.cloud }
        if id == JuneModelID.appleFM {
            return AppleFMQuickChatBackend.unavailability() == nil ? id : nil
        }
        if let cloudModel = CloudTextModelID(rawValue: id) {
            guard cloudModel.provider.supportsAgentTier,
                  CloudTextModelID.juneAgentModels(for: cloudModel.provider).contains(cloudModel),
                  AppBootstrap.shared?.inferenceState.hasCachedCloudAccess(for: cloudModel.provider) == true else {
                return preferredCachedConfiguredCloudModelID() ?? preferredLocalDefaultModelID() ?? JuneModelID.cloud
            }
            return cloudModel.rawValue
        }
        if let entry = GGUFModelCatalog.entry(id: id) {
            guard localGGUF.isAvailableInThisBuild,
                  GGUFModelCatalog.ramGate(for: entry) == nil else {
                return nil
            }
            return id
        }
        return nil
    }

    private func explicitlyAdmittedModelID(_ id: String) -> String? {
        guard selectableModelIDs().contains(id) else { return nil }
        if id == JuneModelID.cloud { return id }
        if id == JuneModelID.appleFM {
            return AppleFMQuickChatBackend.unavailability() == nil ? id : nil
        }
        if let cloudModel = CloudTextModelID(rawValue: id) {
            guard cloudModel.provider.supportsAgentTier,
                  CloudTextModelID.juneAgentModels(for: cloudModel.provider).contains(cloudModel),
                  AppBootstrap.shared?.inferenceState.hasCachedCloudAccess(for: cloudModel.provider) == true else {
                return nil
            }
            return id
        }
        if let entry = GGUFModelCatalog.entry(id: id) {
            guard localGGUF.isAvailableInThisBuild,
                  GGUFModelCatalog.ramGate(for: entry) == nil else {
                return nil
            }
            return id
        }
        return nil
    }

    func modelSelectionFailureMessage(_ id: String) -> String {
        if let entry = GGUFModelCatalog.entry(id: id) {
            guard localGGUF.isAvailableInThisBuild else {
                return "\(entry.displayName) is connected to June, but this build has no local GGUF runtime."
            }
            if let ramProblem = GGUFModelCatalog.ramGate(for: entry) {
                return "\(entry.displayName) is connected to June, but it can't run on this Mac. \(ramProblem.userCopy)"
            }
        }
        if let cloudModel = CloudTextModelID(rawValue: id) {
            return "Configure \(cloudModel.provider.displayName) in Settings before selecting \(cloudModel.displayName) in June."
        }
        return "That text model is not connected to MAS June."
    }

    private func preferredCachedConfiguredCloudModelID() -> String? {
        preferredCachedConfiguredCloudModel()?.rawValue
    }

    private func preferredLocalDefaultModelID() -> String? {
        AppleFMQuickChatBackend.unavailability() == nil ? JuneModelID.appleFM : nil
    }

    private func preferredCachedConfiguredCloudModel() -> CloudTextModelID? {
        guard let inference = AppBootstrap.shared?.inferenceState else { return nil }
        var candidates: [CloudModelProvider] = []
        if let active = inference.activeAIProvider.cloudProvider {
            candidates.append(active)
        }
        candidates.append(contentsOf: JuneAgentModelCatalog.directCloudProviders)
        var seen: Set<CloudModelProvider> = []
        for provider in candidates where seen.insert(provider).inserted {
            guard provider.supportsAgentTier,
                  inference.hasCachedCloudAccess(for: provider) else { continue }
            return inference.preferredCloudModel(for: provider)
        }
        return nil
    }

    private func cachedConfiguredCloudProviders() -> Set<CloudModelProvider> {
        guard let inference = AppBootstrap.shared?.inferenceState else { return [] }
        return Set(
            JuneAgentModelCatalog.directCloudProviders.filter {
                inference.hasCachedCloudAccess(for: $0)
            }
        )
    }

    @discardableResult
    func setDefaultModel(_ id: String) -> Bool {
        guard let selected = explicitlyAdmittedModelID(id) else {
            Self.log.notice("June rejected non-runnable default model id=\(id, privacy: .public)")
            return false
        }
        UserDefaults.standard.set(selected, forKey: Self.defaultModelKey)
        if let currentSessionID {
            _ = store.setModel(sessionID: currentSessionID, model: selected)
        }
        prepareSelectedModel(selected)
        return true
    }

    @discardableResult
    func setSessionModel(_ id: String, for sessionID: String) -> Bool {
        guard let selected = explicitlyAdmittedModelID(id) else {
            Self.log.notice("June rejected non-runnable session model id=\(id, privacy: .public)")
            return false
        }
        currentSessionID = sessionID
        guard store.setModel(sessionID: sessionID, model: selected) else { return false }
        prepareSelectedModel(selected)
        return true
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
        // A GGUF pick steers the in-process local lane and starts only its
        // checksum-verified model-data download when needed.
        if let entry = GGUFModelCatalog.entry(id: id) {
            guard localGGUF.isAvailableInThisBuild else { return }
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
            preferredConfiguredCloudModel: preferredCachedConfiguredCloudModel(),
            cachedConfiguredCloudProviders: cachedConfiguredCloudProviders()
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
        Self.log.info("gateway rpc reply sent")
        push(frame)
    }

    private func replyError(id: Any?, code: Int, message: String) {
        var frame: [String: Any] = ["jsonrpc": "2.0"]
        frame["id"] = id ?? NSNull()
        frame["error"] = ["code": code, "message": message]
        Self.log.info("gateway rpc error reply sent: \(code, privacy: .public)")
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
