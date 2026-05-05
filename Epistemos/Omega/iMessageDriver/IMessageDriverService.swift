import Foundation
import os

nonisolated struct DriverChannelToolCall: Equatable, Sendable {
    let toolName: String
    let inputJson: String

    init(toolName: String, payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        self.toolName = toolName
        self.inputJson = String(data: data, encoding: .utf8) ?? "{}"
    }
}

nonisolated enum DriverChannelError: LocalizedError, Sendable, Equatable {
    case toolCallFailed(channelID: String, reason: String)
    case invalidResponse(channelID: String, reason: String)
    case unreadPollingUnsupported(channelID: String)

    var errorDescription: String? {
        switch self {
        case .toolCallFailed(let channelID, let reason):
            return "\(channelID) tool call failed: \(reason)"
        case .invalidResponse(let channelID, let reason):
            return "Invalid \(channelID) response: \(reason)"
        case .unreadPollingUnsupported(let channelID):
            return "\(channelID) does not support unread polling in Epistemos yet."
        }
    }
}

nonisolated struct DriverChannelToolExecutionResult: Equatable, Sendable {
    let success: Bool
    let outputJson: String
    let error: String?
}

typealias DriverChannelToolRunner = @Sendable (
    _ vaultPath: String,
    _ tier: String,
    _ toolName: String,
    _ inputJson: String
) async throws -> DriverChannelToolExecutionResult

nonisolated enum DriverChannelToolExecutor {
    static func execute(
        _ toolCall: DriverChannelToolCall,
        vaultPath: String,
        tier: String = "agent",
        channelID: String,
        toolRunner: DriverChannelToolRunner? = nil,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil
    ) async throws -> String {
        let runID = makeDriverChannelRunID(channelID: channelID)
        let toolCallID = "driver-channel-tool:1"
        let recorder = await resolvedAgentProvenanceRecorder(agentProvenanceRecorder)
        let metadata = driverChannelToolMetadata(channelID: channelID, tier: tier)
        let actor = AgentProvenanceActor.agent(
            id: "driver-channel-\(normalizedChannelID(channelID))",
            modelID: nil
        )
        await recordDriverChannelToolEvent(
            recorder: recorder,
            runID: runID,
            actor: actor,
            toolCallID: toolCallID,
            toolCall: toolCall,
            kind: .toolCallRequested,
            status: .requested,
            metadata: metadata
        )
        await recordDriverChannelToolEvent(
            recorder: recorder,
            runID: runID,
            actor: actor,
            toolCallID: toolCallID,
            toolCall: toolCall,
            kind: .toolCallStarted,
            status: .started,
            metadata: metadata
        )

        let startedAt = Date()
        let runner = toolRunner ?? executeDefaultToolCall
        var recordedFailure = false
        do {
            let result = try await runner(vaultPath, tier, toolCall.toolName, toolCall.inputJson)
            let durationMs = durationMilliseconds(since: startedAt)
            if result.success {
                await recordDriverChannelToolEvent(
                    recorder: recorder,
                    runID: runID,
                    actor: actor,
                    toolCallID: toolCallID,
                    toolCall: toolCall,
                    kind: .toolCallCompleted,
                    status: .completed,
                    resultJSON: boundedToolPayload(result.outputJson),
                    durationMs: durationMs,
                    metadata: metadata
                )
                return result.outputJson
            }

            let reason = result.error ?? "unknown"
            await recordDriverChannelToolEvent(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                toolCall: toolCall,
                kind: .toolCallFailed,
                status: .failed,
                resultJSON: boundedToolPayload(result.outputJson),
                durationMs: durationMs,
                errorMessage: boundedToolPayload(reason),
                metadata: metadata
            )
            recordedFailure = true
            throw DriverChannelError.toolCallFailed(
                channelID: channelID,
                reason: reason
            )
        } catch {
            if !recordedFailure {
                await recordDriverChannelToolEvent(
                    recorder: recorder,
                    runID: runID,
                    actor: actor,
                    toolCallID: toolCallID,
                    toolCall: toolCall,
                    kind: .toolCallFailed,
                    status: .failed,
                    durationMs: durationMilliseconds(since: startedAt),
                    errorMessage: boundedToolPayload(error.localizedDescription),
                    metadata: metadata
                )
            }
            throw error
        }
    }

    private static func executeDefaultToolCall(
        vaultPath: String,
        tier: String,
        toolName: String,
        inputJson: String
    ) async throws -> DriverChannelToolExecutionResult {
        #if canImport(agent_coreFFI)
        let result = try await executeToolCall(
            vaultPath: vaultPath,
            tier: tier,
            toolName: toolName,
            inputJson: inputJson
        )
        return DriverChannelToolExecutionResult(
            success: result.success,
            outputJson: result.outputJson,
            error: result.error
        )
        #else
        return DriverChannelToolExecutionResult(
            success: false,
            outputJson: "{}",
            error: "agent_core bindings unavailable"
        )
        #endif
    }

    private static func recordDriverChannelToolEvent(
        recorder: AgentToolProvenanceRecorder,
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        toolCall: DriverChannelToolCall,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) async {
        await MainActor.run {
            _ = recorder.recordToolEvent(
                runID: runID,
                traceID: nil,
                kind: kind,
                actor: actor,
                toolCallID: toolCallID,
                toolName: toolCall.toolName,
                argumentsJSON: toolCall.inputJson,
                resultJSON: resultJSON,
                durationMs: durationMs,
                approvalID: nil,
                status: status,
                errorMessage: errorMessage,
                metadata: metadata
            )
        }
    }

    private static func resolvedAgentProvenanceRecorder(
        _ recorder: AgentToolProvenanceRecorder?
    ) async -> AgentToolProvenanceRecorder {
        if let recorder {
            return recorder
        }
        return await MainActor.run {
            AgentToolProvenanceRecorder()
        }
    }

    private nonisolated static func makeDriverChannelRunID(channelID: String) -> String {
        let milliseconds = Date().timeIntervalSince1970 * 1_000
        let safeMilliseconds = milliseconds.isFinite ? Int64(milliseconds.rounded()) : 0
        let suffix = String(UUID().uuidString.prefix(8))
        return "driver-channel-\(normalizedChannelID(channelID))-\(safeMilliseconds)-\(suffix)"
    }

    private nonisolated static func normalizedChannelID(_ channelID: String) -> String {
        let trimmed = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown" : trimmed
    }

    private nonisolated static func driverChannelToolMetadata(
        channelID: String,
        tier: String
    ) -> [String: String] {
        [
            "source": "driver_channel_tool_executor",
            "surface": "driver_channel",
            "channel": normalizedChannelID(channelID),
            "tier": tier,
        ]
    }

    private nonisolated static func durationMilliseconds(since startedAt: Date) -> UInt64 {
        let milliseconds = Date().timeIntervalSince(startedAt) * 1_000
        guard milliseconds.isFinite, milliseconds > 0 else {
            return 0
        }
        return UInt64(milliseconds.rounded())
    }

    private nonisolated static func boundedToolPayload(_ value: String, limit: Int = 4_096) -> String {
        guard value.count > limit else {
            return value
        }
        return String(value.prefix(limit))
    }
}

nonisolated struct DriverChannelMessage: Equatable, Sendable {
    let channelID: String
    let messageID: String?
    let conversationID: String
    let senderID: String
    let text: String
    let unix: Int64

    var dedupKey: String {
        if let messageID, !messageID.isEmpty {
            return "\(channelID):\(messageID)"
        }
        let conversationKey = conversationID.isEmpty ? "unknown-conversation" : conversationID
        let senderKey = senderID.isEmpty ? "unknown-sender" : senderID
        return "\(channelID):\(conversationKey):\(senderKey):\(unix)"
    }
}

nonisolated protocol DriverChannelReplying: Sendable {
    var channelID: String { get }
    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage]
    func send(message: String, to recipientID: String, vaultPath: String) async throws
}

nonisolated struct IMessageChannelAdapter: DriverChannelAdapting {
    let channelID = "imessage"
    let displayName = "iMessage"

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging, .inboundPolling, .threadHistory, .auditTrail, .search, .relayPairing]
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        let outputJson = try await DriverChannelToolExecutor.execute(
            try makeFetchUnreadToolCall(limit: limit),
            vaultPath: vaultPath,
            channelID: channelID
        )
        return Self.parseUnreadMessages(from: outputJson)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        _ = try await DriverChannelToolExecutor.execute(
            try makeSendToolCall(message: message, recipientID: recipientID),
            vaultPath: vaultPath,
            channelID: channelID
        )
    }

    func listThreads(vaultPath: String, limit: Int) async throws -> [DriverChannelThreadSummary] {
        let outputJson = try await DriverChannelToolExecutor.execute(
            try makeListChatsToolCall(limit: limit),
            vaultPath: vaultPath,
            channelID: channelID
        )
        return Self.parseThreads(from: outputJson)
    }

    func recentAuditEntries(vaultPath: String, limit: Int) async throws -> [DriverChannelAuditEntry] {
        let outputJson = try await DriverChannelToolExecutor.execute(
            try makeRecentAuditToolCall(limit: limit),
            vaultPath: vaultPath,
            channelID: channelID
        )
        return Self.parseAuditEntries(from: outputJson)
    }

    func makeFetchUnreadToolCall(limit: Int) throws -> DriverChannelToolCall {
        try DriverChannelToolCall(
            toolName: "imessage",
            payload: [
                "action": "unread",
                "limit": limit,
            ]
        )
    }

    func makeListChatsToolCall(limit: Int) throws -> DriverChannelToolCall {
        try DriverChannelToolCall(
            toolName: "imessage",
            payload: [
                "action": "list_chats",
                "limit": limit,
            ]
        )
    }

    func makeRecentAuditToolCall(limit: Int) throws -> DriverChannelToolCall {
        try DriverChannelToolCall(
            toolName: "imessage",
            payload: [
                "action": "recent",
                "limit": limit,
            ]
        )
    }

    func makeSendToolCall(message: String, recipientID: String) throws -> DriverChannelToolCall {
        try DriverChannelToolCall(
            toolName: "imessage",
            payload: [
                "action": "send",
                "to": recipientID,
                "message": message,
            ]
        )
    }

    static func parseUnreadMessages(from jsonString: String) -> [DriverChannelMessage] {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = root["messages"] as? [[String: Any]] else {
            return []
        }

        return messages.compactMap { dict in
            guard let senderID = driverChannelStringValue(dict["handle"]),
                  let text = driverChannelStringValue(dict["text"]) else {
                return nil
            }
            let messageID = driverChannelStringValue(dict["message_id"])
            let conversationID = driverChannelStringValue(dict["chat_id"]) ?? senderID
            let unix = (dict["unix"] as? Int64)
                ?? (dict["unix"] as? Int).map(Int64.init)
                ?? (dict["unix"] as? NSNumber)?.int64Value
                ?? 0

            return DriverChannelMessage(
                channelID: "imessage",
                messageID: messageID,
                conversationID: conversationID,
                senderID: senderID,
                text: text,
                unix: unix
            )
        }
    }

    static func parseThreads(from jsonString: String) -> [DriverChannelThreadSummary] {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chats = root["chats"] as? [[String: Any]] else {
            return []
        }

        return chats.compactMap { dict in
            guard let conversationID = driverChannelStringValue(dict["chat_id"]) else {
                return nil
            }
            let title = driverChannelStringValue(dict["display_name"])?.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = driverChannelStringValue(dict["identifier"]) ?? ""
            let resolvedTitle = (title?.isEmpty == false ? title : nil) ?? (subtitle.isEmpty ? "Unnamed Chat" : subtitle)
            let lastActivityUnix = (dict["last_activity_unix"] as? Int64)
                ?? (dict["last_activity_unix"] as? Int).map(Int64.init)
                ?? (dict["last_activity_unix"] as? NSNumber)?.int64Value
                ?? 0
            let archived = (dict["archived"] as? Bool)
                ?? ((dict["archived"] as? NSNumber)?.boolValue)
                ?? false

            return DriverChannelThreadSummary(
                conversationID: conversationID,
                title: resolvedTitle,
                subtitle: subtitle,
                lastActivityUnix: lastActivityUnix,
                isArchived: archived
            )
        }
    }

    static func parseAuditEntries(from jsonString: String) -> [DriverChannelAuditEntry] {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = root["messages"] as? [[String: Any]] else {
            return []
        }

        return messages.compactMap { dict in
            guard let senderID = driverChannelStringValue(dict["handle"]),
                  let conversationID = driverChannelStringValue(dict["chat_id"]) else {
                return nil
            }

            let preview = driverChannelStringValue(dict["text"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "(no text)"
            let unix = (dict["unix"] as? Int64)
                ?? (dict["unix"] as? Int).map(Int64.init)
                ?? (dict["unix"] as? NSNumber)?.int64Value
                ?? 0
            let messageID = driverChannelStringValue(dict["message_id"])
            let isFromMe = (dict["from_me"] as? Bool)
                ?? ((dict["from_me"] as? NSNumber)?.boolValue)
                ?? false

            return DriverChannelAuditEntry(
                conversationID: conversationID,
                messageID: messageID,
                senderID: senderID,
                preview: preview,
                unix: unix,
                isFromMe: isFromMe
            )
        }
    }

}

nonisolated fileprivate enum CommunicationChannelRecipientField: String, Sendable {
    case target
    case to
    case webhookURL = "webhook_url"
}

nonisolated struct CommunicationChannelAdapter: DriverChannelAdapting {
    let channelID: String
    private let platform: String
    private let recipientField: CommunicationChannelRecipientField?
    private let defaultRecipientID: String?
    private let staticPayload: [String: String]

    fileprivate init(
        channelID: String,
        platform: String,
        recipientField: CommunicationChannelRecipientField?,
        defaultRecipientID: String? = nil,
        staticPayload: [String: String] = [:]
    ) {
        self.channelID = channelID
        self.platform = platform
        self.recipientField = recipientField
        self.defaultRecipientID = defaultRecipientID
        self.staticPayload = staticPayload
    }

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging]
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        throw DriverChannelError.unreadPollingUnsupported(channelID: channelID)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        _ = try await DriverChannelToolExecutor.execute(
            try makeSendToolCall(message: message, recipientID: recipientID),
            vaultPath: vaultPath,
            channelID: channelID
        )
    }

    func makeSendToolCall(message: String, recipientID: String) throws -> DriverChannelToolCall {
        var payload: [String: Any] = [
            "platform": platform,
            "message": message,
        ]
        for (key, value) in staticPayload {
            payload[key] = value
        }
        if let recipientField,
           let resolvedRecipientID = resolvedRecipientID(explicitRecipientID: recipientID) {
            payload[recipientField.rawValue] = resolvedRecipientID
        }
        return try DriverChannelToolCall(toolName: "send_message", payload: payload)
    }

    private func resolvedRecipientID(explicitRecipientID: String) -> String? {
        let explicit = explicitRecipientID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty {
            return explicit
        }
        guard let defaultRecipientID else {
            return nil
        }
        let fallback = defaultRecipientID.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? nil : fallback
    }
}

nonisolated struct TelegramChannelAdapter: DriverChannelAdapting {
    private let adapter: CommunicationChannelAdapter
    var channelID: String { adapter.channelID }
    let displayName = "Telegram"

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging]
    }

    init(chatID: String? = nil) {
        self.adapter = CommunicationChannelAdapter(
            channelID: "telegram",
            platform: "telegram",
            recipientField: .target,
            defaultRecipientID: chatID
        )
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        try await adapter.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        try await adapter.send(message: message, to: recipientID, vaultPath: vaultPath)
    }

    func makeSendToolCall(message: String, recipientID: String) throws -> DriverChannelToolCall {
        try adapter.makeSendToolCall(message: message, recipientID: recipientID)
    }
}

nonisolated struct SlackChannelAdapter: DriverChannelAdapting {
    private let adapter: CommunicationChannelAdapter
    var channelID: String { adapter.channelID }
    let displayName = "Slack"

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging]
    }

    init(webhookURL: String? = nil) {
        self.adapter = CommunicationChannelAdapter(
            channelID: "slack",
            platform: "slack",
            recipientField: .webhookURL,
            defaultRecipientID: webhookURL
        )
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        try await adapter.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        try await adapter.send(message: message, to: recipientID, vaultPath: vaultPath)
    }

    func makeSendToolCall(message: String, recipientID: String) throws -> DriverChannelToolCall {
        try adapter.makeSendToolCall(message: message, recipientID: recipientID)
    }
}

nonisolated struct DiscordChannelAdapter: DriverChannelAdapting {
    private let adapter: CommunicationChannelAdapter
    var channelID: String { adapter.channelID }
    let displayName = "Discord"

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging]
    }

    init(webhookURL: String? = nil) {
        self.adapter = CommunicationChannelAdapter(
            channelID: "discord",
            platform: "discord",
            recipientField: .webhookURL,
            defaultRecipientID: webhookURL
        )
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        try await adapter.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        try await adapter.send(message: message, to: recipientID, vaultPath: vaultPath)
    }

    func makeSendToolCall(message: String, recipientID: String) throws -> DriverChannelToolCall {
        try adapter.makeSendToolCall(message: message, recipientID: recipientID)
    }
}

nonisolated struct WhatsAppChannelAdapter: DriverChannelAdapting {
    private let adapter: CommunicationChannelAdapter
    var channelID: String { adapter.channelID }
    let displayName = "WhatsApp"

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging]
    }

    init(phoneNumber: String? = nil) {
        self.adapter = CommunicationChannelAdapter(
            channelID: "whatsapp",
            platform: "whatsapp",
            recipientField: .target,
            defaultRecipientID: phoneNumber
        )
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        try await adapter.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        try await adapter.send(message: message, to: recipientID, vaultPath: vaultPath)
    }

    func makeSendToolCall(message: String, recipientID: String) throws -> DriverChannelToolCall {
        try adapter.makeSendToolCall(message: message, recipientID: recipientID)
    }
}

nonisolated struct SignalChannelAdapter: DriverChannelAdapting {
    private let adapter: CommunicationChannelAdapter
    var channelID: String { adapter.channelID }
    let displayName = "Signal"

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging]
    }

    init(recipient: String? = nil) {
        self.adapter = CommunicationChannelAdapter(
            channelID: "signal",
            platform: "signal",
            recipientField: .target,
            defaultRecipientID: recipient
        )
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        try await adapter.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        try await adapter.send(message: message, to: recipientID, vaultPath: vaultPath)
    }

    func makeSendToolCall(message: String, recipientID: String) throws -> DriverChannelToolCall {
        try adapter.makeSendToolCall(message: message, recipientID: recipientID)
    }
}

nonisolated struct EmailChannelAdapter: DriverChannelAdapting {
    private let adapter: CommunicationChannelAdapter
    var channelID: String { adapter.channelID }
    let displayName = "Email"

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging]
    }

    init(subject: String = "Epistemos Reply", recipientEmail: String? = nil) {
        self.adapter = CommunicationChannelAdapter(
            channelID: "email",
            platform: "email",
            recipientField: .to,
            defaultRecipientID: recipientEmail,
            staticPayload: ["subject": subject]
        )
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        try await adapter.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        try await adapter.send(message: message, to: recipientID, vaultPath: vaultPath)
    }

    func makeSendToolCall(message: String, recipientID: String) throws -> DriverChannelToolCall {
        try adapter.makeSendToolCall(message: message, recipientID: recipientID)
    }
}

nonisolated enum DriverChannelReplyTransport {
    static let maxCharsPerMessage = 3_500

    static func sendChunkedReply(
        _ reply: String,
        to recipientID: String,
        vaultPath: String,
        replyPrefix: String? = nil,
        over channel: any DriverChannelReplying,
        onSendError: (@Sendable (_ chunkIndex: Int, _ chunkCount: Int, _ errorDescription: String) async -> Void)? = nil
    ) async {
        let cleaned = LocalReplyAccumulator.stripMarkdown(reply)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let finalBody = cleaned.isEmpty ? "(no response)" : cleaned
        let finalReply: String
        if let replyPrefix, !replyPrefix.isEmpty {
            finalReply = replyPrefix + finalBody
        } else {
            finalReply = finalBody
        }

        let chunks = LocalReplyAccumulator.chunk(finalReply, maxLength: maxCharsPerMessage)
        for (index, chunk) in chunks.enumerated() {
            do {
                try await channel.send(message: chunk, to: recipientID, vaultPath: vaultPath)
            } catch {
                if let onSendError {
                    await onSendError(index + 1, chunks.count, error.localizedDescription)
                }
            }
            guard index < chunks.count - 1 else { continue }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }
}

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
    nonisolated static let defaultContactModel = "qwen-4b"
    nonisolated static let fallbackGroupedModelExample = "qwen-4b,claude-sonnet-4-6"
    nonisolated static let perContactHourlyReplyLimit = 60

    // MARK: - Observable state

    var isRunning: Bool = false
    var lastPollAt: Date?
    var lastError: String?
    var processedCount: Int = 0
    var pollIntervalSeconds: Int = 5

    // MARK: - Dependencies

    private let vaultPathProvider: @MainActor () -> String?
    private let currentChannelConfigurationProvider: @MainActor () -> ChannelConfiguration?
    private let localModelClientProvider: @MainActor () -> (any LocalConfigurableLLMClient)?
    private let constrainedDecodingProvider: @MainActor () -> ConstrainedDecodingService?
    private let channelAdapterProvider: @MainActor () -> (any DriverChannelReplying)
    private let logger = Logger(subsystem: "com.epistemos", category: "IMessageDriver")

    // MARK: - Task state

    private var pollTask: Task<Void, Never>?
    private var processedMessageKeys: Set<String> = []
    private var replyTimestampsByContactKey: [String: [Date]] = [:]

    // MARK: - Init

    init(
        vaultPathProvider: @escaping @MainActor () -> String?,
        currentChannelConfigurationProvider: @escaping @MainActor () -> ChannelConfiguration? = { nil },
        channelAdapterProvider: @escaping @MainActor () -> (any DriverChannelReplying) = { IMessageChannelAdapter() },
        localModelClientProvider: @escaping @MainActor () -> (any LocalConfigurableLLMClient)? = { nil },
        constrainedDecodingProvider: @escaping @MainActor () -> ConstrainedDecodingService? = { nil }
    ) {
        self.vaultPathProvider = vaultPathProvider
        self.currentChannelConfigurationProvider = currentChannelConfigurationProvider
        self.channelAdapterProvider = channelAdapterProvider
        self.localModelClientProvider = localModelClientProvider
        self.constrainedDecodingProvider = constrainedDecodingProvider
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        guard let _ = vaultPathProvider() else {
            lastError = "No vault configured — cannot start background driver"
            return
        }
        isRunning = true
        lastError = nil
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
        logger.info("Channel driver started (poll=\(self.pollIntervalSeconds)s)")
    }

    func stop() {
        guard isRunning else { return }
        pollTask?.cancel()
        pollTask = nil
        isRunning = false
        logger.info("Channel driver stopped")
    }

    // MARK: - Poll loop

    private func pollLoop() async {
        while !Task.isCancelled {
            guard isRunning else { break }
            await tickOnce()
            let intervalSeconds = max(1, pollIntervalSeconds)
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
            let replyChannel = channelAdapterProvider()
            let unread = try await fetchUnread(
                vaultPath: vaultPath,
                limit: 20,
                over: replyChannel
            )
            for message in unread {
                await handleIncoming(
                    message,
                    vaultPath: vaultPath,
                    replyChannel: replyChannel
                )
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

    private func fetchUnread(
        vaultPath: String,
        limit: Int,
        over replyChannel: any DriverChannelReplying
    ) async throws -> [DriverChannelMessage] {
        try await replyChannel.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
    }

    private func resolveContact(
        handle: String,
        vaultPath: String,
        channelID: String
    ) async throws -> ResolvedContact? {
        let payload = contactRoutingPayload(
            action: "resolve",
            handle: handle,
            channelID: channelID
        )
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"

        let result = try await executeToolCall(
            vaultPath: vaultPath,
            tier: "agent",
            toolName: contactRoutingToolName(for: channelID),
            inputJson: jsonStr
        )
        guard result.success else {
            return resolveDefaultChannelRoute(handle: handle, channelID: channelID)
        }

        guard let data = result.outputJson.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return resolveDefaultChannelRoute(handle: handle, channelID: channelID)
        }
        let configured = root["configured"] as? Bool ?? false
        guard configured else { return resolveDefaultChannelRoute(handle: handle, channelID: channelID) }
        let contact = root["contact"] as? [String: Any] ?? [:]
        return ResolvedContact(
            handle: handle,
            displayName: contact["display_name"] as? String,
            model: contact["model"] as? String ?? Self.defaultContactModel,
            toolTier: contact["tool_tier"] as? String ?? "chat_pro",
            promptMode: contact["prompt_mode"] as? String ?? "general",
            allowed: contact["allowed"] as? Bool ?? false,
            autoReply: contact["auto_reply"] as? Bool ?? false,
            autoApprove: contact["auto_approve"] as? Bool ?? false
        )
    }

    private func contactRoutingToolName(for channelID: String) -> String {
        channelID == ChannelIdentity.imessage.rawValue ? "imessage_contacts" : "channel_contacts"
    }

    private func contactRoutingPayload(
        action: String,
        handle: String,
        channelID: String
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "action": action,
            "handle": handle,
        ]
        if channelID != ChannelIdentity.imessage.rawValue {
            payload["channel_id"] = channelID
        }
        return payload
    }

    private func resolveDefaultChannelRoute(handle: String, channelID: String) -> ResolvedContact? {
        guard let configuration = currentChannelConfigurationProvider(),
              configuration.id.rawValue == channelID,
              configuration.isEnabled else {
            return nil
        }
        let preferredModel = configuration.routingPolicy.preferredModel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let toolTier = configuration.routingPolicy.toolTier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let promptMode = configuration.routingPolicy.promptMode
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ResolvedContact(
            handle: handle,
            displayName: handle,
            model: preferredModel.isEmpty ? Self.defaultContactModel : preferredModel,
            toolTier: toolTier.isEmpty ? "chat_pro" : toolTier,
            promptMode: promptMode.isEmpty ? "general" : promptMode,
            allowed: true,
            autoReply: true,
            autoApprove: configuration.routingPolicy.autoApproveWrites
        )
    }

    private func recordMessage(
        handle: String,
        vaultPath: String,
        channelID: String
    ) async {
        let payload = contactRoutingPayload(
            action: "record_message",
            handle: handle,
            channelID: channelID
        )
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return
        }
        _ = try? await executeToolCall(
            vaultPath: vaultPath,
            tier: "agent",
            toolName: contactRoutingToolName(for: channelID),
            inputJson: jsonStr
        )
    }

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

    enum LocalModelDispatchPlan: Equatable {
        case unavailable
        case directGenerate
        case agentLoop
    }

    private func handleIncoming(
        _ message: DriverChannelMessage,
        vaultPath: String,
        replyChannel: any DriverChannelReplying
    ) async {
        let dedupKey = message.dedupKey
        if processedMessageKeys.contains(dedupKey) {
            return
        }
        defer { processedMessageKeys.insert(dedupKey) }

        #if canImport(agent_coreFFI)
        guard let contact = try? await resolveContact(
            handle: message.senderID,
            vaultPath: vaultPath,
            channelID: replyChannel.channelID
        ),
              contact.allowed,
              contact.autoReply else {
            return
        }

        let rateLimitKey = Self.replyRateLimitKey(
            handle: message.senderID,
            channelID: replyChannel.channelID
        )
        if shouldThrottleAutoReply(for: rateLimitKey) {
            logger.warning(
                "Auto-reply throttled for \(replyChannel.channelID, privacy: .public):\(message.senderID, privacy: .public) after \(Self.perContactHourlyReplyLimit) sends in the last hour"
            )
            return
        }

        logger.info("Dispatching \(replyChannel.channelID, privacy: .public) from \(message.senderID, privacy: .public) to model \(contact.model, privacy: .public) tier=\(contact.toolTier, privacy: .public)")

        // RRF Fusion Phase 4 wiring site §7 — iMessage channel reply
        // context. The agent session this dispatch spawns will pull
        // vault context for prompt-building via the agent_core tools
        // registered in `agent_core/src/tools/registry.rs`. Phase 4
        // wiring site §4 (the Rust vault-search tool, see
        // `docs/RRF_FUSION_PROMPT.md` Phase 4 item 4) and site §6
        // (AgentRuntime context retrieval, already routed through
        // `VaultSyncService.searchIndex(query:)` which is flag-aware
        // as of Phase 4) collectively cover the reply path. No
        // additional iMessage-specific wiring is needed here — this
        // breadcrumb exists so future Phase-K work knows the path is
        // already lit through the shared agent-tool retrieval layer.

        // Spawn the agent session.
        await runAgentForContact(
            contact: contact,
            message: message,
            vaultPath: vaultPath,
            replyChannel: replyChannel
        )

        // Stamp so we don't reprocess on the next tick.
        await recordMessage(
            handle: message.senderID,
            vaultPath: vaultPath,
            channelID: replyChannel.channelID
        )
        recordAutoReplySent(for: rateLimitKey)
        processedCount += 1
        #endif
    }

    private func runAgentForContact(
        contact: ResolvedContact,
        message: DriverChannelMessage,
        vaultPath: String,
        replyChannel: any DriverChannelReplying
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
                usesGroup: usesGroup,
                replyChannel: replyChannel
            )
        }
    }

    /// Run one model against the incoming message. This is the unit of
    /// fan-out — each entry in `contact.model` (comma-separated) lands here.
    private func runSingleModelForContact(
        modelName: String,
        contact: ResolvedContact,
        message: DriverChannelMessage,
        vaultPath: String,
        usesGroup: Bool,
        replyChannel: any DriverChannelReplying
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
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
            )
        } else {
            await runCloudAgentForContact(
                modelName: trimmedModel,
                contact: contact,
                message: message,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
            )
        }
    }

    /// Cloud-model path: spawn a Rust agent_core session through `runAgentSession`.
    private func runCloudAgentForContact(
        modelName: String,
        contact: ResolvedContact,
        message: DriverChannelMessage,
        vaultPath: String,
        replyPrefix: String?,
        replyChannel: any DriverChannelReplying
    ) async {
        let sessionId = UUID().uuidString
        let systemPrompt = Self.iMessageSystemPrompt(displayName: contact.displayName ?? contact.handle)

        let toolConfig = ToolConfig(
            vaultPath: vaultPath,
            enableBash: false,
            enableWebSearch: true,
            toolTier: contact.toolTier,
            // iMessage driver has no per-tool UI — tier is the only gate.
            allowedToolNames: nil
        )
        let agentConfig = AgentConfigFFI(
            maxTurns: 8,
            maxOutputTokens: 2048,
            contextThreshold: 16_384,
            enableThinking: false,
            effort: "medium",
            systemPrompt: systemPrompt,
            autoApproveReads: false,
            autoApproveWrites: contact.autoApprove,
            promptMode: contact.promptMode,
            maxCostUsd: nil
        )

        let providerName = Self.providerNameForCloudModel(modelName)
        let delegate = IMessageReplyDelegate(
            contactHandle: message.senderID,
            vaultPath: vaultPath,
            replyChannel: replyChannel,
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
            logger.error("Cloud agent session failed for \(message.senderID, privacy: .public) model=\(modelName, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
        message: DriverChannelMessage,
        vaultPath: String,
        replyPrefix: String?,
        replyChannel: any DriverChannelReplying
    ) async {
        let modelClient = localModelClientProvider()
        switch Self.localDispatchPlan(for: localModelID, hasLocalClient: modelClient != nil) {
        case .unavailable:
            logger.error("Local model client unavailable for handle=\(message.senderID, privacy: .public) model=\(localModelID.rawValue, privacy: .public)")
            await sendLocalReply(
                reply: Self.localModelUnavailableReply(for: localModelID),
                handle: message.senderID,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
            )

        case .directGenerate:
            guard let modelClient else {
                logger.error("Local dispatch plan resolved to directGenerate without an active local client for handle=\(message.senderID, privacy: .public)")
                await sendLocalReply(
                    reply: Self.localModelUnavailableReply(for: localModelID),
                    handle: message.senderID,
                    vaultPath: vaultPath,
                    replyPrefix: replyPrefix,
                    replyChannel: replyChannel
                )
                return
            }
            logger.warning("Local model \(localModelID.rawValue, privacy: .public) cannot act as agent — using direct generate fallback")
            await runDirectLocalGenerate(
                modelClient: modelClient,
                modelID: localModelID,
                contact: contact,
                message: message,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
            )

        case .agentLoop:
            guard let modelClient else {
                logger.error("Local dispatch plan resolved to agentLoop without an active local client for handle=\(message.senderID, privacy: .public)")
                await sendLocalReply(
                    reply: Self.localModelUnavailableReply(for: localModelID),
                    handle: message.senderID,
                    vaultPath: vaultPath,
                    replyPrefix: replyPrefix,
                    replyChannel: replyChannel
                )
                return
            }
            await runLocalAgentLoopForContact(
                modelClient: modelClient,
                modelID: localModelID,
                contact: contact,
                message: message,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
            )
        }
    }

    private func runLocalAgentLoopForContact(
        modelClient: any LocalConfigurableLLMClient,
        modelID: LocalTextModelID,
        contact: ResolvedContact,
        message: DriverChannelMessage,
        vaultPath: String,
        replyPrefix: String?,
        replyChannel: any DriverChannelReplying
    ) async {
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
            modelID: modelID.rawValue,
            defaultReasoningMode: .fast
        )

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
                handle: message.senderID,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
            )
        } catch {
            logger.error("Local agent session failed for \(message.senderID, privacy: .public) model=\(modelID.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            await sendLocalReply(
                reply: "Sorry, I hit a local-model error: \(error.localizedDescription)",
                handle: message.senderID,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
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
        message: DriverChannelMessage,
        vaultPath: String,
        replyPrefix: String?,
        replyChannel: any DriverChannelReplying
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
                handle: message.senderID,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
            )
        } catch {
            logger.error("Direct local generate failed for \(message.senderID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            await sendLocalReply(
                reply: "Sorry, I hit a local-model error: \(error.localizedDescription)",
                handle: message.senderID,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                replyChannel: replyChannel
            )
        }
    }

    /// Send a local-model reply through the iMessage `send` tool. Mirrors
    /// the chunking + markdown stripping in `IMessageReplyDelegate`.
    private func sendLocalReply(
        reply: String,
        handle: String,
        vaultPath: String,
        replyPrefix: String?,
        replyChannel: any DriverChannelReplying
    ) async {
        let channelID = replyChannel.channelID
        await DriverChannelReplyTransport.sendChunkedReply(
            reply,
            to: handle,
            vaultPath: vaultPath,
            replyPrefix: replyPrefix,
            over: replyChannel,
            onSendError: { chunkIndex, chunkCount, errorDescription in
                await MainActor.run {
                    Logger(subsystem: "com.epistemos", category: "IMessageDriver")
                        .warning("\(channelID, privacy: .public) send chunk \(chunkIndex)/\(chunkCount) failed: \(errorDescription, privacy: .public)")
                }
            }
        )
    }

    private static func iMessageSystemPrompt(displayName: String) -> String {
        """
        You are Epistemos responding to a direct message from \(displayName). \
        Keep replies concise and conversational unless they explicitly ask for depth. \
        Prefer short paragraphs. Avoid markdown headings, bold, and bullet lists unless \
        absolutely necessary. If you need to research, use web_search or vault_recall before \
        replying. Do NOT send messages to anyone except the contact you are replying to.
        """
    }

    /// Split a model-list field into individual model names. Supports
    /// "qwen-4b", "qwen-4b,claude-sonnet-4-6", or newline / semicolon separation.
    private static func parseModelList(_ field: String) -> [String] {
        field
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    nonisolated static func suggestedModelOptions(
        installedLocalModelIDs: Set<String>,
        configuredCloudProviders: [CloudModelProvider]
    ) -> [String] {
        var options: [String] = []
        var seen = Set<String>()

        func append(_ option: String) {
            guard !option.isEmpty, seen.insert(option).inserted else { return }
            options.append(option)
        }

        let installedLocals = LocalTextModelID.allCases.filter { installedLocalModelIDs.contains($0.rawValue) }
        for modelID in installedLocals {
            append(canonicalAlias(for: modelID))
        }
        if options.isEmpty {
            append(defaultContactModel)
        }

        for provider in configuredCloudProviders {
            append(defaultCloudAlias(for: provider))
        }

        append(groupedModelExample(
            installedLocalModelIDs: installedLocalModelIDs,
            configuredCloudProviders: configuredCloudProviders
        ))

        return options
    }

    nonisolated static func groupedModelExample(
        installedLocalModelIDs: Set<String>,
        configuredCloudProviders: [CloudModelProvider]
    ) -> String {
        let installedLocals = LocalTextModelID.allCases.filter { installedLocalModelIDs.contains($0.rawValue) }
        let localAlias = installedLocals
            .first(where: { $0.canActAsAgent })
            .map { canonicalAlias(for: $0) }
            ?? defaultContactModel
        let cloudAlias = configuredCloudProviders
            .map { defaultCloudAlias(for: $0) }
            .first
            ?? "claude-sonnet-4-6"
        return "\(localAlias),\(cloudAlias)"
    }

    nonisolated static func localDispatchPlan(
        for localModelID: LocalTextModelID,
        hasLocalClient: Bool
    ) -> LocalModelDispatchPlan {
        guard hasLocalClient else { return .unavailable }
        if localModelID == .qwen35_2B4Bit {
            return .agentLoop
        }
        return localModelID.canActAsAgent ? .agentLoop : .directGenerate
    }

    nonisolated static func localModelUnavailableReply(for localModelID: LocalTextModelID) -> String {
        "Sorry, I can't reply right now because the local model \(localModelID.rawValue) isn't available on this Mac."
    }

    /// Map a friendly local-model short name (as picked in the iMessage
    /// settings UI) onto a `LocalTextModelID`. Returns `nil` for cloud models
    /// or unrecognised names. The mapping is intentionally generous so users
    /// can type either the short alias ("qwen-2b") or the full HuggingFace
    /// repo id ("mlx-community/Qwen3.5-2B-4bit") and both resolve.
    nonisolated static func localTextModelID(forShortName name: String) -> LocalTextModelID? {
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
        case "qwen3.6-35b", "qwen-3.6-35b", "qwen36-35b", "qwen3.6-a3b": return .qwen36_35BA3B4Bit
        case "gemma-2b", "gemma4-2b", "gemma-4-2b": return .gemma4_2B4Bit
        case "gemma-4b", "gemma4-4b", "gemma-4-4b": return .gemma4_4B4Bit
        case "gemma-26b", "gemma-26b-a4b", "gemma4-26b", "gemma-4-26b", "gemma-27b", "gemma4-27b", "gemma-4-27b": return .gemma4_27BA4B4Bit
        case "qwopus", "qwopus-27b": return .qwopus27Bv3
        case "qwopus-moe", "qwopus-35b": return .qwopusMoE35BA3B
        case "deepseek-r1", "r1-7b", "deepseek-r1-7b": return .deepseekR1Distill7B
        case "qwen-coder", "coder-7b", "qwen2.5-coder": return .qwen25Coder7B
        case "bonsai-4b", "ternary-bonsai-4b", "bonsai4b": return .bonsai4B2Bit
        case "bonsai-8b", "ternary-bonsai-8b", "bonsai8b": return .bonsai8B2Bit
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

    nonisolated static func prunedReplyTimestamps(
        _ timestamps: [Date],
        now: Date
    ) -> [Date] {
        let cutoff = now.addingTimeInterval(-3600)
        return timestamps.filter { $0 >= cutoff }
    }

    nonisolated static func isReplyRateLimited(
        existingReplyTimestamps: [Date],
        now: Date
    ) -> Bool {
        prunedReplyTimestamps(existingReplyTimestamps, now: now).count >= perContactHourlyReplyLimit
    }

    private static func replyRateLimitKey(handle: String, channelID: String) -> String {
        "\(channelID):\(handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private func shouldThrottleAutoReply(for key: String, now: Date = Date()) -> Bool {
        let pruned = Self.prunedReplyTimestamps(replyTimestampsByContactKey[key] ?? [], now: now)
        replyTimestampsByContactKey[key] = pruned
        return pruned.count >= Self.perContactHourlyReplyLimit
    }

    private func recordAutoReplySent(for key: String, at now: Date = Date()) {
        var timestamps = Self.prunedReplyTimestamps(replyTimestampsByContactKey[key] ?? [], now: now)
        timestamps.append(now)
        replyTimestampsByContactKey[key] = timestamps
    }

    nonisolated private static func canonicalAlias(for modelID: LocalTextModelID) -> String {
        switch modelID {
        case .qwen35_0_8B4Bit: "qwen-0.8b"
        case .qwen35_2B4Bit: "qwen-2b"
        case .qwen35_4B4Bit: "qwen-4b"
        case .qwen35_9B4Bit: "qwen-9b"
        case .qwen35_27B4Bit: "qwen-27b"
        case .qwen35_35BA3B4Bit: "qwen-35b"
        case .qwen36_35BA3B4Bit: "qwen3.6-35b"
        case .gemma4_2B4Bit: "gemma-2b"
        case .gemma4_4B4Bit: "gemma-4b"
        case .gemma4_27BA4B4Bit, .gemma4_31BJANG: "gemma-26b-a4b"
        case .qwopus27Bv3: "qwopus-27b"
        case .qwopusMoE35BA3B: "qwopus-35b"
        case .deepseekR1Distill7B: "deepseek-r1"
        case .qwen25Coder7B: "qwen-coder"
        case .bonsai4B2Bit: "bonsai-4b"
        case .bonsai8B2Bit: "bonsai-8b"
        case .smolLM3_3B4Bit: "smollm3-3b"
        case .devstralSmall2505_4Bit: "devstral"
        case .mistralSmall31_24B4Bit: "mistral-small"
        case .lfm25_1BInstruct: "lfm2.5-1b"
        case .lfm25_1BThinking: "lfm2.5-thinking"
        case .mamba2_2B4Bit: "mamba2"
        case .jamba3B: "jamba"
        default:
            modelID.displayName
        }
    }

    nonisolated private static func defaultCloudAlias(for provider: CloudModelProvider) -> String {
        switch provider {
        case .anthropic: "claude-sonnet-4-6"
        case .openAI: "gpt-4o"
        case .google: "gemini-pro"
        case .zai: "glm-4.5"
        case .kimi: "kimi-k2"
        case .minimax: "minimax-m1"
        case .deepseek: "deepseek-chat"
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
