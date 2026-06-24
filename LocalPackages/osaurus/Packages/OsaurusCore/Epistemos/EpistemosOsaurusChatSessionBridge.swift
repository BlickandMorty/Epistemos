//  EpistemosOsaurusChatSessionBridge.swift
//  OsaurusCore

import Foundation

public struct EpistemosOsaurusNativeSecretPromptRequest: Identifiable, Sendable {
    public let id: UUID
    public let key: String
    public let description: String
    public let instructions: String

    public init(id: UUID, key: String, description: String, instructions: String) {
        self.id = id
        self.key = key
        self.description = description
        self.instructions = instructions
    }
}

public enum EpistemosOsaurusNativeSecretPromptDecision: Sendable {
    case provided(String)
    case canceled
}

public typealias EpistemosOsaurusNativeSecretPromptPresenter =
    @MainActor @Sendable (EpistemosOsaurusNativeSecretPromptRequest) async -> EpistemosOsaurusNativeSecretPromptDecision

public struct EpistemosOsaurusNativeClarifyPromptRequest: Identifiable, Sendable {
    public let id: UUID
    public let question: String
    public let options: [String]
    public let allowMultiple: Bool

    public init(id: UUID, question: String, options: [String], allowMultiple: Bool) {
        self.id = id
        self.question = question
        self.options = options
        self.allowMultiple = allowMultiple
    }
}

public enum EpistemosOsaurusNativeClarifyPromptDecision: Sendable {
    case answered(String)
    case canceled
}

public typealias EpistemosOsaurusNativeClarifyPromptPresenter =
    @MainActor @Sendable (EpistemosOsaurusNativeClarifyPromptRequest) async -> EpistemosOsaurusNativeClarifyPromptDecision

public enum EpistemosOsaurusChatSessionBridgeError: Error, LocalizedError, Sendable {
    case sessionFailed(String)
    case promptCanceled(String)

    public var errorDescription: String? {
        switch self {
        case .sessionFailed(let message):
            return message
        case .promptCanceled(let prompt):
            return "Act paused for \(prompt), but the prompt was canceled."
        }
    }
}

public enum EpistemosOsaurusChatSessionEvent: Sendable, Equatable {
    case textDelta(String)
    case thinkingDelta(String)
    case toolStarted(id: String, name: String, inputJson: String)
    case toolCompleted(id: String, result: String, isError: Bool)
    /// Final-turn generation telemetry (owner 0.33a "prefill/stats"): TTFT, tokens/sec, token
    /// count — read off the completed assistant `ChatTurn`. Emitted once at finish so the
    /// Epistemos act surface can render the same "TTFT 7.36s · 39 tokens" stats Osaurus showed,
    /// natively — WITHOUT leaking the raw protocol text into the visible transcript.
    case generationStats(ttftSeconds: Double?, tokensPerSecond: Double?, tokenCount: Int?)
}

@MainActor
enum EpistemosOsaurusChatSessionPresenterStore {
    static var secretPromptPresenter: EpistemosOsaurusNativeSecretPromptPresenter?
    static var clarifyPromptPresenter: EpistemosOsaurusNativeClarifyPromptPresenter?
}

public enum EpistemosOsaurusChatSessionBridge {
    @MainActor
    public static func installNativeSecretPromptPresenter(
        _ presenter: EpistemosOsaurusNativeSecretPromptPresenter?
    ) {
        EpistemosOsaurusChatSessionPresenterStore.secretPromptPresenter = presenter
    }

    @MainActor
    public static func installNativeClarifyPromptPresenter(
        _ presenter: EpistemosOsaurusNativeClarifyPromptPresenter?
    ) {
        EpistemosOsaurusChatSessionPresenterStore.clarifyPromptPresenter = presenter
    }

    @MainActor
    public static func streamTurn(
        prompt: String,
        requestedModel: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        let eventStream = streamTurnEvents(
            prompt: prompt,
            requestedModel: requestedModel,
            maxTokens: maxTokens
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in eventStream {
                        if case .textDelta(let text) = event {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @MainActor
    public static func streamTurnEvents(
        prompt: String,
        requestedModel: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<EpistemosOsaurusChatSessionEvent, Error> {
        _ = maxTokens
        // 0.41 (owner "act needs ALL Osaurus capabilities"): respect the owner's tools toggle —
        // no longer force-disable. The apple.notes failures were driven by Osaurus's CONFIG agent
        // (Agent.defaultId), which we replaced with the owner's general agent (0.40c). Tools now
        // follow the owner's ChatConfiguration; the driver registers runnable tools before send.
        let chatCfg = ChatConfigurationStore.load()

        // 0.40c (owner "say hello → I can't assist"): Agent.defaultId is Osaurus's CONFIGURATION
        // agent whose system prompt is "you only configure Osaurus, refuse everything else" — so it
        // refused normal chat. Use the owner's ACTIVE agent (a general assistant like "Research
        // Assistant") instead, so act answers normally; never the config-only default.
        let actAgentId = AgentManager.shared.activeAgentId == Agent.defaultId
            ? (AgentManager.shared.agents.first(where: { $0.id != Agent.defaultId })?.id ?? Agent.defaultId)
            : AgentManager.shared.activeAgentId
        let session = ChatSession()
        session.agentId = actAgentId
        session.selectedModel = requestedModel ?? chatCfg.coreModelIdentifier
        session.suppressesPersistence = true
        session.onSessionChanged = {}

        return AsyncThrowingStream { continuation in
            let driver = EpistemosOsaurusHeadlessChatSessionDriver(
                session: session,
                prompt: prompt,
                continuation: continuation
            )
            let task = Task { @MainActor in
                await driver.run()
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { @MainActor in
                    driver.stop()
                }
            }
        }
    }
}

@MainActor
private final class EpistemosOsaurusHeadlessChatSessionDriver {
    private let session: ChatSession
    private let prompt: String
    private let continuation: AsyncThrowingStream<EpistemosOsaurusChatSessionEvent, Error>.Continuation
    private var activePromptID: ObjectIdentifier?
    private var lastVisibleAssistantText = ""
    private var lastAssistantThinkingText = ""
    private var emittedToolCallIDs: Set<String> = []
    private var emittedToolResultIDs: Set<String> = []
    private var producedVisibleText = false
    private var isFinished = false

    init(
        session: ChatSession,
        prompt: String,
        continuation: AsyncThrowingStream<EpistemosOsaurusChatSessionEvent, Error>.Continuation
    ) {
        self.session = session
        self.prompt = prompt
        self.continuation = continuation
    }

    func run() async {
        // 0.41: register the agent's runnable tools into ToolRegistry BEFORE the turn (the real
        // Osaurus app does this in prepareChatExecutionMode) so tools the model calls actually
        // execute instead of returning tool_not_found. Best-effort; honest if a tool can't run.
        await SandboxToolRegistrar.shared.registerTools(for: session.agentId ?? Agent.defaultId)
        session.send(prompt)

        while !Task.isCancelled && !isFinished {
            await serviceCurrentPromptIfNeeded()
            guard !isFinished else { return }
            emitAssistantSessionDeltas()

            // A run is "active" from the synchronous `beginRun` inside `send(...)`
            // until `finalizeRun` clears it — so `isRunActive` is true on the very
            // first tick after send. `isStreaming`, by contrast, only flips true
            // *asynchronously* once tokens begin; polling `!isStreaming` alone would
            // finish the turn before generation even started (the empty-stream race).
            // Gate completion on the run being finalized AND not streaming AND no
            // queued secret/clarify prompt pending.
            if !session.isRunActive && !session.isStreaming && session.promptQueue.current == nil {
                emitAssistantSessionDeltas()
                finish()
                return
            }

            try? await Task.sleep(nanoseconds: 33_000_000)
        }

        stop()
    }

    func stop() {
        guard !isFinished else { return }
        isFinished = true
        session.promptQueue.drainAll()
        if session.isStreaming {
            session.stop()
        }
        continuation.finish()
    }

    private func serviceCurrentPromptIfNeeded() async {
        guard let current = session.promptQueue.current,
              current.id != activePromptID
        else { return }

        activePromptID = current.id

        switch current {
        case .secret(let state):
            await serviceSecretPrompt(state)
        case .clarify(let state):
            await serviceClarifyPrompt(state)
        }

        if session.promptQueue.current?.id == current.id {
            session.promptQueue.advance()
        }
        activePromptID = nil
    }

    private func serviceSecretPrompt(_ state: SecretPromptState) async {
        guard let presenter = EpistemosOsaurusChatSessionPresenterStore.secretPromptPresenter else {
            state.cancel()
            finish(throwing: EpistemosOsaurusChatSessionBridgeError.promptCanceled("a secret"))
            return
        }

        let request = EpistemosOsaurusNativeSecretPromptRequest(
            id: UUID(),
            key: state.key,
            description: state.description,
            instructions: state.instructions
        )
        switch await presenter(request) {
        case .provided(let value):
            state.submit(value)
        case .canceled:
            state.cancel()
            finish(throwing: EpistemosOsaurusChatSessionBridgeError.promptCanceled(state.key))
        }
    }

    private func serviceClarifyPrompt(_ state: ClarifyPromptState) async {
        guard let presenter = EpistemosOsaurusChatSessionPresenterStore.clarifyPromptPresenter else {
            state.cancelByUser()
            finish(throwing: EpistemosOsaurusChatSessionBridgeError.promptCanceled("clarification"))
            return
        }

        let request = EpistemosOsaurusNativeClarifyPromptRequest(
            id: UUID(),
            question: state.question,
            options: state.options,
            allowMultiple: state.allowMultiple
        )
        switch await presenter(request) {
        case .answered(let answer):
            state.submit(answer)
        case .canceled:
            state.cancelByUser()
            finish(throwing: EpistemosOsaurusChatSessionBridgeError.promptCanceled("clarification"))
        }
    }

    private func emitAssistantSessionDeltas() {
        emitAssistantThinkingDelta()
        emitAssistantToolEvents()
        emitVisibleAssistantDelta()
    }

    private func emitAssistantThinkingDelta() {
        let thinkingText = session.turns
            .filter { $0.role == .assistant }
            .map(\.thinking)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        guard !thinkingText.isEmpty else { return }

        let delta: String
        if thinkingText.hasPrefix(lastAssistantThinkingText) {
            delta = String(thinkingText.dropFirst(lastAssistantThinkingText.count))
        } else {
            delta = thinkingText
        }

        guard !delta.isEmpty else { return }
        lastAssistantThinkingText = thinkingText
        continuation.yield(.thinkingDelta(delta))
    }

    private func emitAssistantToolEvents() {
        for turn in session.turns where turn.role == .assistant {
            guard let toolCalls = turn.toolCalls else { continue }

            for call in toolCalls {
                if emittedToolCallIDs.insert(call.id).inserted {
                    continuation.yield(
                        .toolStarted(
                            id: call.id,
                            name: call.function.name,
                            inputJson: call.function.arguments
                        )
                    )
                }

                if let result = turn.toolResults[call.id],
                   emittedToolResultIDs.insert(call.id).inserted {
                    continuation.yield(
                        .toolCompleted(
                            id: call.id,
                            result: result,
                            isError: Self.resultLooksLikeToolError(result)
                        )
                    )
                }
            }
        }
    }

    private func emitVisibleAssistantDelta() {
        let content = session.turns
            .filter { $0.role == .assistant }
            .map(\.visibleContent)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let completion = session.lastCompletionSummary ?? ""
        let visibleText = completion.isEmpty ? content : [content, completion].filter { !$0.isEmpty }.joined(separator: "\n\n")

        guard !visibleText.isEmpty else { return }

        let delta: String
        if visibleText.hasPrefix(lastVisibleAssistantText) {
            delta = String(visibleText.dropFirst(lastVisibleAssistantText.count))
        } else {
            delta = visibleText
        }

        guard !delta.isEmpty else { return }
        producedVisibleText = true
        lastVisibleAssistantText = visibleText
        continuation.yield(.textDelta(delta))
    }

    private nonisolated static func resultLooksLikeToolError(_ result: String) -> Bool {
        let lowercased = result.lowercased()
        return lowercased.contains("\"is_error\":true")
            || lowercased.contains("\"iserror\":true")
            || lowercased.contains("\"error\":true")
            || lowercased.hasPrefix("error:")
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        if !producedVisibleText,
           let error = session.lastStreamError,
           !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            continuation.finish(throwing: EpistemosOsaurusChatSessionBridgeError.sessionFailed(error))
            return
        }
        emitGenerationStats()
        continuation.finish()
    }

    /// 0.33a (owner "prefill/stats"): emit the completed assistant turn's TTFT / tokens-per-second /
    /// token-count once, from the SAME fields Osaurus renders ("TTFT 7.36s · 39 tokens"). Best-effort:
    /// only when the final assistant turn actually carries telemetry; never blocks the finish.
    private func emitGenerationStats() {
        guard let turn = session.turns.last(where: { $0.role == .assistant }) else { return }
        let ttft = turn.timeToFirstToken
        let tps = turn.generationTokensPerSecond
        let count = turn.generationTokenCount
        guard ttft != nil || tps != nil || (count ?? 0) > 0 else { return }
        continuation.yield(.generationStats(ttftSeconds: ttft, tokensPerSecond: tps, tokenCount: count))
    }

    private func finish(throwing error: Error) {
        guard !isFinished else { return }
        isFinished = true
        continuation.finish(throwing: error)
    }
}
