import Foundation

nonisolated enum DriverChannelCapability: String, CaseIterable, Sendable, Identifiable {
    case outboundMessaging
    case inboundPolling
    case threadHistory
    case auditTrail
    case search
    case relayPairing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outboundMessaging: "Outbound"
        case .inboundPolling: "Inbound"
        case .threadHistory: "Threads"
        case .auditTrail: "Audit"
        case .search: "Search"
        case .relayPairing: "Relay"
        }
    }
}

nonisolated struct DriverChannelThreadSummary: Equatable, Identifiable, Sendable {
    let conversationID: String
    let title: String
    let subtitle: String
    let lastActivityUnix: Int64
    let isArchived: Bool

    var id: String { conversationID }
}

nonisolated struct DriverChannelAuditEntry: Equatable, Identifiable, Sendable {
    let conversationID: String
    let messageID: String?
    let senderID: String
    let preview: String
    let unix: Int64
    let isFromMe: Bool

    var id: String {
        if let messageID, !messageID.isEmpty {
            return messageID
        }
        return "\(conversationID):\(senderID):\(unix)"
    }
}

nonisolated struct DriverChannelFallbackEvent: Equatable, Sendable {
    nonisolated enum Operation: String, Equatable, Sendable {
        case fetchUnread
        case send
        case listThreads
        case recentAudit
    }

    let channelID: String
    let operation: Operation
    let primaryDisplayName: String
    let fallbackDisplayName: String
    let errorDescription: String
    let occurredAt: Date
}

nonisolated protocol DriverChannelAdapting: DriverChannelReplying {
    var displayName: String { get }
    var capabilities: [DriverChannelCapability] { get }
    func listThreads(vaultPath: String, limit: Int) async throws -> [DriverChannelThreadSummary]
    func recentAuditEntries(vaultPath: String, limit: Int) async throws -> [DriverChannelAuditEntry]
}

extension DriverChannelAdapting {
    nonisolated var displayName: String { channelID.capitalized }

    nonisolated var capabilities: [DriverChannelCapability] {
        [.outboundMessaging]
    }

    nonisolated func listThreads(vaultPath: String, limit: Int) async throws -> [DriverChannelThreadSummary] {
        throw DriverChannelError.unreadPollingUnsupported(channelID: channelID)
    }

    nonisolated func recentAuditEntries(vaultPath: String, limit: Int) async throws -> [DriverChannelAuditEntry] {
        throw DriverChannelError.unreadPollingUnsupported(channelID: channelID)
    }
}

nonisolated func driverChannelStringValue(_ value: Any?) -> String? {
    switch value {
    case let string as String:
        return string
    case let number as NSNumber:
        return number.stringValue
    default:
        return nil
    }
}

nonisolated struct ChannelRelayConfiguration: Hashable, Sendable {
    let endpoint: URL
    let credential: String
    let senderIdentity: String

    init?(metadata: ChannelPairingMetadata?) {
        guard let metadata else {
            return nil
        }
        let endpointString = metadata.relayEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpointString.isEmpty,
              let endpoint = URL(string: endpointString) else {
            return nil
        }
        self.endpoint = endpoint
        self.credential = metadata.relayCredential.trimmingCharacters(in: .whitespacesAndNewlines)
        self.senderIdentity = metadata.senderIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated fileprivate enum RelayChannelRoute: String {
    case unread
    case threads
    case audit
    case send

    var pathComponents: [String] {
        switch self {
        case .unread:
            ["messages", "unread"]
        case .threads:
            ["threads"]
        case .audit:
            ["audit"]
        case .send:
            ["messages"]
        }
    }
}

nonisolated fileprivate enum RelayChannelClient {
    static func execute(
        relay: ChannelRelayConfiguration,
        channelID: String,
        route: RelayChannelRoute,
        method: String,
        queryItems: [URLQueryItem] = [],
        payload: [String: Any]? = nil,
        urlSession: URLSession = .shared,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil
    ) async throws -> String {
        let normalizedChannel = normalizedChannelID(channelID)
        let runID = makeRelayChannelRunID(channelID: normalizedChannel)
        let toolCallID = "relay-channel-tool:1"
        let toolName = "driver_channel.remote_relay"
        let actor = AgentProvenanceActor.agent(
            id: "relay-channel-\(normalizedChannel)",
            modelID: nil
        )
        let metadata = relayChannelToolMetadata(
            channelID: normalizedChannel,
            route: route,
            method: method
        )
        let argumentsJSON = relayChannelArgumentsJSON(
            relay: relay,
            channelID: normalizedChannel,
            route: route,
            method: method,
            queryItems: queryItems,
            payload: payload
        )
        let recorder = await resolvedAgentProvenanceRecorder(agentProvenanceRecorder)

        await recordRelayChannelToolEvent(
            recorder: recorder,
            runID: runID,
            actor: actor,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: argumentsJSON,
            kind: .toolCallRequested,
            status: .requested,
            metadata: metadata
        )
        await recordRelayChannelToolEvent(
            recorder: recorder,
            runID: runID,
            actor: actor,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: argumentsJSON,
            kind: .toolCallStarted,
            status: .started,
            metadata: metadata
        )

        let startedAt = Date()
        do {
            let request = try makeRequest(
                relay: relay,
                channelID: channelID,
                route: route,
                method: method,
                queryItems: queryItems,
                payload: payload
            )
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DriverChannelError.invalidResponse(
                    channelID: channelID,
                    reason: "relay returned a non-HTTP response"
                )
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let responseText = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let reason: String
                if let responseText, !responseText.isEmpty {
                    reason = responseText
                } else {
                    reason = "unknown"
                }
                throw DriverChannelError.toolCallFailed(
                    channelID: channelID,
                    reason: "relay HTTP \(httpResponse.statusCode): \(reason)"
                )
            }
            let resultJSON = relayChannelResultJSON(
                statusCode: httpResponse.statusCode,
                responseByteCount: data.count
            )
            await recordRelayChannelToolEvent(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                toolName: toolName,
                argumentsJSON: argumentsJSON,
                kind: .toolCallCompleted,
                status: .completed,
                resultJSON: resultJSON,
                durationMs: durationMilliseconds(since: startedAt),
                metadata: metadata
            )
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch let error as DriverChannelError {
            await recordRelayChannelToolEvent(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                toolName: toolName,
                argumentsJSON: argumentsJSON,
                kind: .toolCallFailed,
                status: .failed,
                durationMs: durationMilliseconds(since: startedAt),
                errorMessage: relayChannelErrorMessage(error),
                metadata: metadata
            )
            throw error
        } catch {
            let wrappedError = DriverChannelError.toolCallFailed(
                channelID: channelID,
                reason: "relay request failed: \(error.localizedDescription)"
            )
            await recordRelayChannelToolEvent(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                toolName: toolName,
                argumentsJSON: argumentsJSON,
                kind: .toolCallFailed,
                status: .failed,
                durationMs: durationMilliseconds(since: startedAt),
                errorMessage: relayChannelErrorMessage(wrappedError),
                metadata: metadata
            )
            throw wrappedError
        }
    }

    private static func makeRequest(
        relay: ChannelRelayConfiguration,
        channelID: String,
        route: RelayChannelRoute,
        method: String,
        queryItems: [URLQueryItem],
        payload: [String: Any]?
    ) throws -> URLRequest {
        var url = relay.endpoint
        url.appendPathComponent("v1", isDirectory: true)
        url.appendPathComponent("channels", isDirectory: true)
        url.appendPathComponent(channelID, isDirectory: true)
        for (index, pathComponent) in route.pathComponents.enumerated() {
            url.appendPathComponent(
                pathComponent,
                isDirectory: index < route.pathComponents.count - 1
            )
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw DriverChannelError.invalidResponse(
                channelID: channelID,
                reason: "relay URL is malformed"
            )
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let finalURL = components.url else {
            throw DriverChannelError.invalidResponse(
                channelID: channelID,
                reason: "relay URL could not be resolved"
            )
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !relay.credential.isEmpty {
            request.setValue("Bearer \(relay.credential)", forHTTPHeaderField: "Authorization")
        }
        if !relay.senderIdentity.isEmpty {
            request.setValue(relay.senderIdentity, forHTTPHeaderField: "X-Epistemos-Sender")
        }
        if let payload {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        }
        return request
    }

    private static func recordRelayChannelToolEvent(
        recorder: AgentToolProvenanceRecorder,
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        toolName: String,
        argumentsJSON: String,
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
                toolName: toolName,
                argumentsJSON: argumentsJSON,
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

    private nonisolated static func relayChannelToolMetadata(
        channelID: String,
        route: RelayChannelRoute,
        method: String
    ) -> [String: String] {
        [
            "source": "relay_channel_client",
            "surface": "driver_channel_remote_relay",
            "channel": normalizedChannelID(channelID),
            "route": route.rawValue,
            "method": method,
        ]
    }

    private nonisolated static func relayChannelArgumentsJSON(
        relay: ChannelRelayConfiguration,
        channelID: String,
        route: RelayChannelRoute,
        method: String,
        queryItems: [URLQueryItem],
        payload: [String: Any]?
    ) -> String {
        let payloadByteCount = payload.flatMap { object in
            try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).count
        } ?? 0
        return stableJSONString([
            "channel": normalizedChannelID(channelID),
            "route": route.rawValue,
            "method": method,
            "query_count": queryItems.count,
            "has_payload": payload != nil,
            "payload_utf8_bytes": payloadByteCount,
            "has_credential": !relay.credential.isEmpty,
            "has_sender_identity": !relay.senderIdentity.isEmpty,
        ])
    }

    private nonisolated static func relayChannelResultJSON(
        statusCode: Int,
        responseByteCount: Int
    ) -> String {
        stableJSONString([
            "status_code": statusCode,
            "response_utf8_bytes": responseByteCount,
        ])
    }

    private nonisolated static func relayChannelErrorMessage(_ error: Error) -> String {
        if let driverError = error as? DriverChannelError {
            switch driverError {
            case .toolCallFailed(let channelID, let reason) where reason.hasPrefix("relay HTTP "):
                let status = reason.split(separator: ":", maxSplits: 1).first.map(String.init) ?? "relay HTTP failure"
                return "\(channelID) tool call failed: \(status)"
            default:
                break
            }
        }
        let description = error.localizedDescription
        guard description.count > 512 else {
            return description
        }
        return String(description.prefix(512))
    }

    private nonisolated static func stableJSONString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private nonisolated static func makeRelayChannelRunID(channelID: String) -> String {
        let milliseconds = Date().timeIntervalSince1970 * 1_000
        let safeMilliseconds = milliseconds.isFinite ? Int64(milliseconds.rounded()) : 0
        let suffix = String(UUID().uuidString.prefix(8))
        return "relay-channel-\(normalizedChannelID(channelID))-\(safeMilliseconds)-\(suffix)"
    }

    private nonisolated static func durationMilliseconds(since startedAt: Date) -> UInt64 {
        let milliseconds = Date().timeIntervalSince(startedAt) * 1_000
        guard milliseconds.isFinite, milliseconds > 0 else {
            return 0
        }
        return UInt64(milliseconds.rounded())
    }

    private nonisolated static func normalizedChannelID(_ channelID: String) -> String {
        let trimmed = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown" : trimmed
    }
}

nonisolated struct RemoteRelayChannelAdapter: DriverChannelAdapting {
    let channelID: String
    let displayName: String
    let relay: ChannelRelayConfiguration
    let deliveryMetadata: [String: String]
    let urlSession: URLSession
    let agentProvenanceRecorder: AgentToolProvenanceRecorder?

    init(
        channelID: String,
        displayName: String,
        relay: ChannelRelayConfiguration,
        deliveryMetadata: [String: String],
        urlSession: URLSession = .shared,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil
    ) {
        self.channelID = channelID
        self.displayName = displayName
        self.relay = relay
        self.deliveryMetadata = deliveryMetadata
        self.urlSession = urlSession
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    var capabilities: [DriverChannelCapability] {
        [.outboundMessaging, .inboundPolling, .threadHistory, .auditTrail, .relayPairing]
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        let outputJson = try await RelayChannelClient.execute(
            relay: relay,
            channelID: channelID,
            route: .unread,
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(max(1, limit)))],
            urlSession: urlSession,
            agentProvenanceRecorder: agentProvenanceRecorder
        )
        return Self.parseUnreadMessages(from: outputJson, channelID: channelID)
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        var payload: [String: Any] = [
            "message": message,
        ]
        let trimmedRecipient = recipientID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRecipient.isEmpty {
            payload["recipient_id"] = trimmedRecipient
        }
        if !relay.senderIdentity.isEmpty {
            payload["sender_identity"] = relay.senderIdentity
        }
        if !deliveryMetadata.isEmpty {
            payload["metadata"] = deliveryMetadata
        }
        _ = try await RelayChannelClient.execute(
            relay: relay,
            channelID: channelID,
            route: .send,
            method: "POST",
            payload: payload,
            urlSession: urlSession,
            agentProvenanceRecorder: agentProvenanceRecorder
        )
    }

    func listThreads(vaultPath: String, limit: Int) async throws -> [DriverChannelThreadSummary] {
        let outputJson = try await RelayChannelClient.execute(
            relay: relay,
            channelID: channelID,
            route: .threads,
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(max(1, limit)))],
            urlSession: urlSession,
            agentProvenanceRecorder: agentProvenanceRecorder
        )
        return Self.parseThreads(from: outputJson)
    }

    func recentAuditEntries(vaultPath: String, limit: Int) async throws -> [DriverChannelAuditEntry] {
        let outputJson = try await RelayChannelClient.execute(
            relay: relay,
            channelID: channelID,
            route: .audit,
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(max(1, limit)))],
            urlSession: urlSession,
            agentProvenanceRecorder: agentProvenanceRecorder
        )
        return Self.parseAuditEntries(from: outputJson)
    }

    static func parseUnreadMessages(from jsonString: String, channelID: String) -> [DriverChannelMessage] {
        messageRows(from: jsonString).compactMap { row in
            guard let senderID = driverChannelStringValue(row["sender_id"] ?? row["handle"] ?? row["from"]),
                  let text = driverChannelStringValue(row["text"] ?? row["body"]) else {
                return nil
            }
            let conversationID = driverChannelStringValue(
                row["conversation_id"] ?? row["chat_id"] ?? row["thread_id"]
            ) ?? senderID
            let messageID = driverChannelStringValue(row["message_id"] ?? row["id"])
            let unix = int64Value(row["unix"] ?? row["timestamp_unix"] ?? row["created_unix"])
            return DriverChannelMessage(
                channelID: channelID,
                messageID: messageID,
                conversationID: conversationID,
                senderID: senderID,
                text: text,
                unix: unix
            )
        }
    }

    static func parseThreads(from jsonString: String) -> [DriverChannelThreadSummary] {
        threadRows(from: jsonString).compactMap { row in
            guard let conversationID = driverChannelStringValue(
                row["conversation_id"] ?? row["chat_id"] ?? row["thread_id"]
            ) else {
                return nil
            }
            let subtitle = driverChannelStringValue(row["subtitle"] ?? row["identifier"] ?? row["participant"]) ?? ""
            let title = driverChannelStringValue(row["title"] ?? row["display_name"]) ?? (subtitle.isEmpty ? "Unnamed Thread" : subtitle)
            let archived = boolValue(row["archived"] ?? row["is_archived"])
            let unix = int64Value(row["last_activity_unix"] ?? row["unix"] ?? row["updated_unix"])
            return DriverChannelThreadSummary(
                conversationID: conversationID,
                title: title,
                subtitle: subtitle,
                lastActivityUnix: unix,
                isArchived: archived
            )
        }
    }

    static func parseAuditEntries(from jsonString: String) -> [DriverChannelAuditEntry] {
        messageRows(from: jsonString).compactMap { row in
            guard let senderID = driverChannelStringValue(row["sender_id"] ?? row["handle"] ?? row["from"]),
                  let conversationID = driverChannelStringValue(
                    row["conversation_id"] ?? row["chat_id"] ?? row["thread_id"]
                  ) else {
                return nil
            }
            let preview = driverChannelStringValue(row["text"] ?? row["body"])?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "(no text)"
            return DriverChannelAuditEntry(
                conversationID: conversationID,
                messageID: driverChannelStringValue(row["message_id"] ?? row["id"]),
                senderID: senderID,
                preview: preview,
                unix: int64Value(row["unix"] ?? row["timestamp_unix"] ?? row["created_unix"]),
                isFromMe: boolValue(row["from_me"] ?? row["is_from_me"])
            )
        }
    }

    private static func rootObject(from jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func messageRows(from jsonString: String) -> [[String: Any]] {
        let root = rootObject(from: jsonString) ?? [:]
        return root["messages"] as? [[String: Any]] ?? []
    }

    private static func threadRows(from jsonString: String) -> [[String: Any]] {
        let root = rootObject(from: jsonString) ?? [:]
        return root["threads"] as? [[String: Any]]
            ?? root["chats"] as? [[String: Any]]
            ?? []
    }

    private static func int64Value(_ value: Any?) -> Int64 {
        (value as? Int64)
            ?? (value as? Int).map(Int64.init)
            ?? (value as? NSNumber)?.int64Value
            ?? 0
    }

    private static func boolValue(_ value: Any?) -> Bool {
        (value as? Bool)
            ?? (value as? NSNumber)?.boolValue
            ?? false
    }
}

nonisolated struct FallbackDriverChannelAdapter: DriverChannelAdapting {
    private let primary: any DriverChannelAdapting
    private let fallback: any DriverChannelAdapting
    private let onFallback: (@Sendable (DriverChannelFallbackEvent) -> Void)?

    init(
        primary: any DriverChannelAdapting,
        fallback: any DriverChannelAdapting,
        onFallback: (@Sendable (DriverChannelFallbackEvent) -> Void)? = nil
    ) {
        self.primary = primary
        self.fallback = fallback
        self.onFallback = onFallback
    }

    var channelID: String { primary.channelID }
    var displayName: String { primary.displayName }

    var capabilities: [DriverChannelCapability] {
        var seen = Set<String>()
        return (primary.capabilities + fallback.capabilities).filter { capability in
            seen.insert(capability.rawValue).inserted
        }
    }

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        do {
            return try await primary.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
        } catch {
            reportFallback(operation: .fetchUnread, error: error)
            return try await fallback.fetchUnreadMessages(vaultPath: vaultPath, limit: limit)
        }
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        do {
            try await primary.send(message: message, to: recipientID, vaultPath: vaultPath)
        } catch {
            reportFallback(operation: .send, error: error)
            try await fallback.send(message: message, to: recipientID, vaultPath: vaultPath)
        }
    }

    func listThreads(vaultPath: String, limit: Int) async throws -> [DriverChannelThreadSummary] {
        do {
            return try await primary.listThreads(vaultPath: vaultPath, limit: limit)
        } catch {
            reportFallback(operation: .listThreads, error: error)
            return try await fallback.listThreads(vaultPath: vaultPath, limit: limit)
        }
    }

    func recentAuditEntries(vaultPath: String, limit: Int) async throws -> [DriverChannelAuditEntry] {
        do {
            return try await primary.recentAuditEntries(vaultPath: vaultPath, limit: limit)
        } catch {
            reportFallback(operation: .recentAudit, error: error)
            return try await fallback.recentAuditEntries(vaultPath: vaultPath, limit: limit)
        }
    }

    private func reportFallback(operation: DriverChannelFallbackEvent.Operation, error: Error) {
        onFallback?(
            DriverChannelFallbackEvent(
                channelID: primary.channelID,
                operation: operation,
                primaryDisplayName: primary.displayName,
                fallbackDisplayName: fallback.displayName,
                errorDescription: error.localizedDescription,
                occurredAt: Date()
            )
        )
    }
}
