import Foundation
import os

/// Background polling service that turns iMessage into the primary
/// agent-user channel. Every `pollInterval` seconds it:
///
/// 1. Queries the Rust `imessage` tool for unread incoming messages
/// 2. For each message, looks up the sender in `imessage_contacts` via `resolve`
/// 3. If the contact is configured + `allowed` + `auto_reply`, and the message
///    is newer than `last_message`, spawns an agent session with:
///    - The contact's assigned model
///    - The contact's tool tier
///    - An `IMessageReplyDelegate` that posts the reply back via the
///      `imessage send` action
/// 4. Stamps `record_message` on the contact so the same message is never
///    processed twice.
///
/// The service is driven by the master toggle in `InferenceState.imessageDriverEnabled`.
/// When OFF, the polling task is cancelled and no incoming messages are
/// processed — this is the user's hard kill switch.
@MainActor
@Observable
final class IMessageDriverService {
    // MARK: - Observable state

    var isRunning: Bool = false
    var lastPollAt: Date?
    var lastError: String?
    var processedCount: Int = 0
    var pollIntervalSeconds: Int = 5

    // MARK: - Dependencies

    private let vaultPathProvider: @MainActor () -> String?
    private let localModelClientProvider: @MainActor () -> (any LocalConfigurableLLMClient)?
    private let constrainedDecodingProvider: @MainActor () -> ConstrainedDecodingService?
    private let logger = Logger(subsystem: "com.epistemos", category: "IMessageDriver")

    // MARK: - Task state

    private var pollTask: Task<Void, Never>?
    /// Per-contact dedup — maps handle → last processed message timestamp (unix).
    private var processedTimestamps: [String: Int64] = [:]

    // MARK: - Init

    init(
        vaultPathProvider: @escaping @MainActor () -> String?,
        localModelClientProvider: @escaping @MainActor () -> (any LocalConfigurableLLMClient)? = { nil },
        constrainedDecodingProvider: @escaping @MainActor () -> ConstrainedDecodingService? = { nil }
    ) {
        self.vaultPathProvider = vaultPathProvider
        self.localModelClientProvider = localModelClientProvider
        self.constrainedDecodingProvider = constrainedDecodingProvider
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        guard let _ = vaultPathProvider() else {
            lastError = "No vault configured — cannot start iMessage driver"
            return
        }
        isRunning = true
        lastError = nil
        let interval = pollIntervalSeconds
        pollTask = Task { [weak self] in
            await self?.pollLoop(intervalSeconds: interval)
        }
        logger.info("iMessage driver started (poll=\(interval)s)")
    }

    func stop() {
        guard isRunning else { return }
        pollTask?.cancel()
        pollTask = nil
        isRunning = false
        logger.info("iMessage driver stopped")
    }

    // MARK: - Poll loop

    private func pollLoop(intervalSeconds: Int) async {
        while !Task.isCancelled {
            guard isRunning else { break }
            await tickOnce()
            try? await Task.sleep(for: .seconds(intervalSeconds))
        }
    }

    /// Fetch unread messages and dispatch each one. Exposed for manual
    /// "poll now" triggers from the settings UI.
    func tickOnce() async {
        guard let vaultPath = vaultPathProvider() else {
            lastError = "No vault path"
            return
        }
        lastPollAt = Date()

        #if canImport(agent_coreFFI)
        do {
            let unread = try await fetchUnread(vaultPath: vaultPath, limit: 20)
            for message in unread {
                await handleIncoming(message, vaultPath: vaultPath)
            }
            lastError = nil
        } catch {
            logger.error("poll tick failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
        #else
        lastError = "agent_core bindings unavailable"
        #endif
    }

    // MARK: - Incoming handler

    private struct IncomingMessage {
        let handle: String
        let text: String
        let unix: Int64
        let chatId: Int64
    }

    #if canImport(agent_coreFFI)
    private func fetchUnread(vaultPath: String, limit: Int) async throws -> [IncomingMessage] {
        let payload: [String: Any] = [
            "action": "unread",
            "limit": limit,
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"

        let result = try await executeToolCall(
            vaultPath: vaultPath,
            tier: "agent",
            toolName: "imessage",
            inputJson: jsonStr
        )
        guard result.success else {
            throw IMessageDriverError.toolCallFailed(result.error ?? "unknown")
        }
        return Self.parseMessages(from: result.outputJson)
    }

    private func resolveContact(handle: String, vaultPath: String) async throws -> ResolvedContact? {
        let payload: [String: Any] = [
            "action": "resolve",
            "handle": handle,
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"

        let result = try await executeToolCall(
            vaultPath: vaultPath,
            tier: "agent",
            toolName: "imessage_contacts",
            inputJson: jsonStr
        )
        guard result.success else { return nil }

        guard let data = result.outputJson.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let configured = root["configured"] as? Bool ?? false
        guard configured else { return nil }
        let contact = root["contact"] as? [String: Any] ?? [:]
        return ResolvedContact(
            handle: handle,
            displayName: contact["display_name"] as? String,
            model: contact["model"] as? String ?? "qwen-2b",
            toolTier: contact["tool_tier"] as? String ?? "chat_pro",
            promptMode: contact["prompt_mode"] as? String ?? "general",
            allowed: contact["allowed"] as? Bool ?? false,
            autoReply: contact["auto_reply"] as? Bool ?? false,
            autoApprove: contact["auto_approve"] as? Bool ?? false
        )
    }

    private func recordMessage(handle: String, vaultPath: String) async {
        let payload: [String: Any] = [
            "action": "record_message",
            "handle": handle,
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return
        }
        _ = try? await executeToolCall(
            vaultPath: vaultPath,
            tier: "agent",
            toolName: "imessage_contacts",
            inputJson: jsonStr
        )
    }
    #endif

    private struct ResolvedContact: Sendable {
        let handle: String
        let displayName: String?
        let model: String
        let toolTier: String
        let promptMode: String
        let allowed: Bool
        let autoReply: Bool
        let autoApprove: Bool
    }

    private func handleIncoming(_ message: IncomingMessage, vaultPath: String) async {
        // In-memory dedup using the message timestamp. Survives a single
        // session; persistent dedup lives in `imessage_contacts.last_message`.
        if let prior = processedTimestamps[message.handle], prior >= message.unix {
            return
        }

        #if canImport(agent_coreFFI)
        guard let contact = try? await resolveContact(handle: message.handle, vaultPath: vaultPath),
              contact.allowed,
              contact.autoReply else {
            // Unconfigured / not allowed / auto_reply off → stamp and skip.
            processedTimestamps[message.handle] = message.unix
            return
        }

        logger.info("Dispatching iMessage from \(message.handle, privacy: .public) to model \(contact.model, privacy: .public) tier=\(contact.toolTier, privacy: .public)")

        // Spawn the agent session.
        await runAgentForContact(
            contact: contact,
            message: message,
            vaultPath: vaultPath
        )

        // Stamp so we don't reprocess on the next tick.
        processedTimestamps[message.handle] = message.unix
        await recordMessage(handle: message.handle, vaultPath: vaultPath)
        processedCount += 1
        #endif
    }

    private func runAgentForContact(
        contact: ResolvedContact,
        message: IncomingMessage,
        vaultPath: String
    ) async {
        // Fan-out: a contact's model field can be a single name like
        // "qwen-2b" or a comma-separated list like "qwen-2b,claude-sonnet-4-6"
        // for "message a group of models". Each model gets its own agent
        // session and replies independently. We run them sequentially on
        // the main actor to avoid hammering the Rust runtime / shared MLX
        // backend with parallel sessions. When more than one model is
        // configured, each reply is prefixed with [model-name] so the user
        // can tell which one wrote which response.
        let modelNames = Self.parseModelList(contact.model)
        let usesGroup = modelNames.count > 1

        for modelName in modelNames {
            await runSingleModelForContact(
                modelName: modelName,
                contact: contact,
                message: message,
                vaultPath: vaultPath,
                usesGroup: usesGroup
            )
        }
    }

    /// Run one model against the incoming message. This is the unit of
    /// fan-out — each entry in `contact.model` (comma-separated) lands here.
    private func runSingleModelForContact(
        modelName: String,
        contact: ResolvedContact,
        message: IncomingMessage,
        vaultPath: String,
        usesGroup: Bool
    ) async {
        let trimmedModel = modelName.trimmingCharacters(in: .whitespaces)
        let replyPrefix = usesGroup ? "[\(trimmedModel)] " : nil

        // Local models go through LocalAgentLoop with tier-filtered tools.
        // Cloud models go through the Rust agent_core runAgentSession path.
        if let localModelID = Self.localTextModelID(forShortName: trimmedModel) {
            await runLocalAgentForContact(
                localModelID: localModelID,
                contact: contact,
                message: message,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix
            )
        } else {
            await runCloudAgentForContact(
                modelName: trimmedModel,
                contact: contact,
                message: message,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix
            )
        }
    }

    /// Cloud-model path: spawn a Rust agent_core session through `runAgentSession`.
    private func runCloudAgentForContact(
        modelName: String,
        contact: ResolvedContact,
        message: IncomingMessage,
        vaultPath: String,
        replyPrefix: String?
    ) async {
        let sessionId = UUID().uuidString
        let systemPrompt = Self.iMessageSystemPrompt(displayName: contact.displayName ?? contact.handle)

        let toolConfig = ToolConfig(
            vaultPath: vaultPath,
            enableBash: false,
            enableWebSearch: true,
            toolTier: contact.toolTier
        )
        let agentConfig = AgentConfigFFI(
            maxTurns: 8,
            maxOutputTokens: 2048,
            contextThreshold: 16_384,
            enableThinking: false,
            effort: "medium",
            systemPrompt: systemPrompt,
            autoApproveReads: true,
            autoApproveWrites: contact.autoApprove,
            promptMode: contact.promptMode
        )

        let providerName = Self.providerNameForCloudModel(modelName)
        let delegate = IMessageReplyDelegate(
            contactHandle: message.handle,
            vaultPath: vaultPath,
            autoApproveModifications: contact.autoApprove,
            replyPrefix: replyPrefix
        )

        #if canImport(agent_coreFFI)
        do {
            _ = try await runAgentSession(
                sessionId: sessionId,
                objective: message.text,
                providerName: providerName,
                toolConfig: toolConfig,
                agentConfig: agentConfig,
                delegate: delegate
            )
        } catch {
            logger.error("Cloud agent session failed for \(message.handle, privacy: .public) model=\(modelName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    /// Local-model path: drive a `LocalAgentLoop` with the contact's chosen
    /// tier of tools. The reply is built by accumulating tokens and then
    /// shipped through the same iMessage `send` action used by the cloud
    /// path. This is the on-device alternative to `runAgentSession`.
    private func runLocalAgentForContact(
        localModelID: LocalTextModelID,
        contact: ResolvedContact,
        message: IncomingMessage,
        vaultPath: String,
        replyPrefix: String?
    ) async {
        guard let modelClient = localModelClientProvider() else {
            logger.error("Local model client unavailable — falling back to cloud Sonnet for handle=\(message.handle, privacy: .public)")
            await runCloudAgentForContact(
                modelName: "claude-sonnet-4-6",
                contact: contact,
                message: message,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix
            )
            return
        }
        guard localModelID.canActAsAgent else {
            logger.warning("Local model \(localModelID.rawValue, privacy: .public) cannot act as agent — using direct generate fallback")
            await runDirectLocalGenerate(
                modelClient: modelClient,
                modelID: localModelID,
                contact: contact,
                message: message,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix
            )
            return
        }

        // Build the iMessage system prompt + tier-filtered tool list.
        let systemPrompt = Self.iMessageSystemPrompt(displayName: contact.displayName ?? contact.handle)
        let bridge = ToolTierBridge(
            vaultPath: vaultPath,
            tier: ChatToolTier(rawValue: contact.toolTier) ?? .chatPro
        )
        let tools = bridge.loadTools()
        let constrainedDecoding = constrainedDecodingProvider()

        let loop = LocalAgentLoop.liveLoop(
            using: modelClient,
            constrainedDecoding: constrainedDecoding,
            toolExecutor: bridge.toolExecutor(),
            modelID: localModelID.rawValue,
            defaultReasoningMode: .fast
        )

        // Token accumulator that strips meta tags / markdown for the SMS reply.
        let accumulator = LocalReplyAccumulator()

        do {
            let result = try await loop.run(
                objective: message.text,
                tools: tools,
                maxTurns: 6,
                reasoningMode: .fast,
                additionalSystemPrompt: systemPrompt,
                onToken: { token in
                    accumulator.append(token)
                }
            )
            let reply = result.isEmpty ? accumulator.finalText() : result
            await sendLocalReply(
                reply: reply,
                handle: message.handle,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix
            )
        } catch {
            logger.error("Local agent session failed for \(message.handle, privacy: .public) model=\(localModelID.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            await sendLocalReply(
                reply: "Sorry, I hit a local-model error: \(error.localizedDescription)",
                handle: message.handle,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix
            )
        }
    }

    /// Models that lack agentic loop support still get a direct one-shot
    /// generate. This keeps small / specialised models usable as iMessage
    /// pen-pals even if they can't drive tool calls.
    private func runDirectLocalGenerate(
        modelClient: any LocalConfigurableLLMClient,
        modelID: LocalTextModelID,
        contact: ResolvedContact,
        message: IncomingMessage,
        vaultPath: String,
        replyPrefix: String?
    ) async {
        let systemPrompt = Self.iMessageSystemPrompt(displayName: contact.displayName ?? contact.handle)
        do {
            let reply = try await modelClient.generate(
                prompt: message.text,
                systemPrompt: systemPrompt,
                maxTokens: 1024,
                reasoningMode: .fast,
                modelID: modelID.rawValue
            )
            await sendLocalReply(
                reply: reply,
                handle: message.handle,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix
            )
        } catch {
            logger.error("Direct local generate failed for \(message.handle, privacy: .public): \(error.localizedDescription, privacy: .public)")
            await sendLocalReply(
                reply: "Sorry, I hit a local-model error: \(error.localizedDescription)",
                handle: message.handle,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix
            )
        }
    }

    /// Send a local-model reply through the iMessage `send` tool. Mirrors
    /// the chunking + markdown stripping in `IMessageReplyDelegate`.
    private func sendLocalReply(
        reply: String,
        handle: String,
        vaultPath: String,
        replyPrefix: String?
    ) async {
        let cleaned = LocalReplyAccumulator.stripMarkdown(reply)
        let final: String
        if let prefix = replyPrefix, !prefix.isEmpty {
            final = prefix + cleaned
        } else {
            final = cleaned.isEmpty ? "(no response)" : cleaned
        }
        let chunks = LocalReplyAccumulator.chunk(final, maxLength: 3_500)

        #if canImport(agent_coreFFI)
        for chunk in chunks {
            let payload: [String: Any] = [
                "action": "send",
                "to": handle,
                "message": chunk,
            ]
            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
                  let jsonStr = String(data: jsonData, encoding: .utf8) else {
                continue
            }
            do {
                _ = try await executeToolCall(
                    vaultPath: vaultPath,
                    tier: "agent",
                    toolName: "imessage",
                    inputJson: jsonStr
                )
            } catch {
                logger.warning("imessage send chunk failed: \(error.localizedDescription, privacy: .public)")
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        #endif
    }

    private static func iMessageSystemPrompt(displayName: String) -> String {
        """
        You are Epistemos responding to an iMessage from \(displayName). \
        Keep replies concise and conversational — this is SMS/iMessage, not a long-form chat. \
        Prefer short paragraphs. Avoid markdown headings, bold, and bullet lists unless \
        absolutely necessary. If you need to research, use web_search or vault_recall before \
        replying. Do NOT send messages to anyone except the contact you are replying to.
        """
    }

    /// Split a model-list field into individual model names. Supports
    /// "qwen-2b", "qwen-2b,claude-sonnet-4-6", or whitespace separation.
    private static func parseModelList(_ field: String) -> [String] {
        field
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Map a friendly local-model short name (as picked in the iMessage
    /// settings UI) onto a `LocalTextModelID`. Returns `nil` for cloud models
    /// or unrecognised names. The mapping is intentionally generous so users
    /// can type either the short alias ("qwen-2b") or the full HuggingFace
    /// repo id ("mlx-community/Qwen3.5-2B-4bit") and both resolve.
    static func localTextModelID(forShortName name: String) -> LocalTextModelID? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let direct = LocalTextModelID(rawValue: trimmed) {
            return direct
        }
        let lower = trimmed.lowercased()
        switch lower {
        case "qwen-0.8b", "qwen-08b", "qwen-mini": return .qwen35_0_8B4Bit
        case "qwen-2b", "qwen2b", "qwen3.5-2b": return .qwen35_2B4Bit
        case "qwen-4b", "qwen4b", "qwen3.5-4b": return .qwen35_4B4Bit
        case "qwen-8b", "qwen-9b", "qwen3.5-9b": return .qwen35_9B4Bit
        case "qwen-27b", "qwen3.5-27b": return .qwen35_27B4Bit
        case "qwen-35b", "qwen-moe", "qwen3.5-35b-moe": return .qwen35_35BA3B4Bit
        case "gemma-2b", "gemma4-2b", "gemma-4-2b": return .gemma4_2B4Bit
        case "gemma-4b", "gemma4-4b", "gemma-4-4b": return .gemma4_4B4Bit
        case "gemma-27b", "gemma4-27b", "gemma-4-27b": return .gemma4_27BA4B4Bit
        case "qwopus", "qwopus-27b": return .qwopus27Bv3
        case "qwopus-moe", "qwopus-35b": return .qwopusMoE35BA3B
        case "deepseek-r1", "r1-7b", "deepseek-r1-7b": return .deepseekR1Distill7B
        case "qwen-coder", "coder-7b", "qwen2.5-coder": return .qwen25Coder7B
        case "smollm3", "smollm3-3b": return .smolLM3_3B4Bit
        case "devstral", "devstral-small": return .devstralSmall2505_4Bit
        case "mistral-small", "mistral-24b": return .mistralSmall31_24B4Bit
        case "lfm2.5-1b", "lfm-1b": return .lfm25_1BInstruct
        case "lfm2.5-thinking", "lfm-thinking": return .lfm25_1BThinking
        case "mamba2", "mamba-2b": return .mamba2_2B4Bit
        case "jamba", "jamba-3b": return .jamba3B
        case "hermes-3", "hermes3":
            // No first-class hermes alias yet — fall back to the closest
            // tool-capable Qwen so a contact configured for "hermes-3" still
            // gets a reasonable on-device model instead of crashing through
            // to claude_sonnet.
            return .qwen35_9B4Bit
        default:
            return nil
        }
    }

    /// Map a cloud model alias (from the contacts UI) onto the Rust provider
    /// string accepted by `instantiate_provider`. Only called when
    /// `localTextModelID(forShortName:)` returns nil.
    private static func providerNameForCloudModel(_ model: String) -> String {
        let lower = model.lowercased()
        if lower.contains("opus") { return "claude_opus" }
        if lower.contains("haiku") { return "claude_haiku" }
        if lower.contains("sonnet") || lower.contains("claude") { return "claude_sonnet" }
        if lower.contains("gpt-4o") || lower.contains("openai") { return "openai" }
        if lower.contains("gemini-2.5-pro") || lower.contains("gemini-pro") { return "gemini_pro" }
        if lower.contains("gemini") { return "gemini_flash" }
        if lower.contains("perplexity") || lower.contains("sonar") { return "perplexity" }
        return "claude_sonnet"
    }

    // MARK: - JSON parsing

    private static func parseMessages(from jsonString: String) -> [IncomingMessage] {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = root["messages"] as? [[String: Any]] else {
            return []
        }
        return messages.compactMap { dict in
            guard let handle = dict["handle"] as? String,
                  let text = dict["text"] as? String else {
                return nil
            }
            let unix = (dict["unix"] as? Int64) ?? (dict["unix"] as? Int).map(Int64.init) ?? 0
            let chatId = (dict["chat_id"] as? Int64) ?? (dict["chat_id"] as? Int).map(Int64.init) ?? 0
            return IncomingMessage(
                handle: handle,
                text: text,
                unix: unix,
                chatId: chatId
            )
        }
    }
}

nonisolated enum IMessageDriverError: LocalizedError, Sendable {
    case toolCallFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .toolCallFailed(let reason):
            return "iMessage tool call failed: \(reason)"
        case .invalidResponse(let reason):
            return "Invalid iMessage response: \(reason)"
        }
    }
}

/// Token accumulator + chunker shared between the local-agent path
/// (`IMessageDriverService.runLocalAgentForContact`) and the cloud reply
/// delegate (`IMessageReplyDelegate`). Threadsafe so it can be filled from
/// MLX background tokens and read on the main actor without locking the
/// caller.
nonisolated final class LocalReplyAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: String = ""

    func append(_ token: String) {
        lock.lock()
        buffer.append(token)
        lock.unlock()
    }

    func finalText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    /// Strip ChatML/Hermes meta tags and common markdown formatting so the
    /// reply reads cleanly when delivered as an iMessage. We deliberately
    /// keep this conservative — too much stripping mangles ASCII tables and
    /// inline code that the user actually wants.
    static func stripMarkdown(_ text: String) -> String {
        var result = text
        // Remove tool/think blocks the local model emitted before its final answer.
        if let rx = try? NSRegularExpression(
            pattern: #"(?s)<(scratch_pad|think|tool_call|tool_response)>.*?</\1>"#
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = rx.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        // Code fences (keep the inner content, drop the fences themselves).
        result = result.replacingOccurrences(
            of: #"```[a-zA-Z]*\n"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "```", with: "")
        // Headings, bold, italics
        result = result.replacingOccurrences(
            of: #"^#{1,6}\s+"#,
            with: "",
            options: [.regularExpression, .anchored]
        )
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        // List bullets → unicode bullets
        result = result.replacingOccurrences(
            of: #"^\s*[-*]\s+"#,
            with: "• ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Break a long reply into iMessage-safe chunks at paragraph boundaries.
    static func chunk(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }
        var chunks: [String] = []
        var current = ""
        for paragraph in text.components(separatedBy: "\n\n") {
            let candidate = current.isEmpty ? paragraph : current + "\n\n" + paragraph
            if candidate.count > maxLength, !current.isEmpty {
                chunks.append(current)
                current = paragraph
            } else {
                current = candidate
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        // If a single paragraph is still too long, hard-split it.
        return chunks.flatMap { chunk -> [String] in
            if chunk.count <= maxLength { return [chunk] }
            var sliced: [String] = []
            var remaining = Substring(chunk)
            while !remaining.isEmpty {
                let end = remaining.index(
                    remaining.startIndex,
                    offsetBy: min(maxLength, remaining.count)
                )
                sliced.append(String(remaining[remaining.startIndex..<end]))
                remaining = remaining[end...]
            }
            return sliced
        }
    }
}
