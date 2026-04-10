import Foundation

nonisolated enum ConversationChannel: String, Codable, Sendable {
    case main
    case mini
    case agentic
}

nonisolated struct ConversationTurn: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var parentID: UUID?
    var timestamp: Date
    var role: MessageRole
    var content: String
    var model: String
    var tokens: Int?
    var toolCalls: [String]
    var vaultMutations: [String]
    var latencyMs: Double?

    init(
        id: UUID = UUID(),
        parentID: UUID? = nil,
        timestamp: Date = .now,
        role: MessageRole,
        content: String,
        model: String,
        tokens: Int? = nil,
        toolCalls: [String] = [],
        vaultMutations: [String] = [],
        latencyMs: Double? = nil
    ) {
        self.id = id
        self.parentID = parentID
        self.timestamp = timestamp
        self.role = role
        self.content = content
        self.model = model
        self.tokens = tokens
        self.toolCalls = toolCalls
        self.vaultMutations = vaultMutations
        self.latencyMs = latencyMs
    }
}

actor ConversationPersistence {
    typealias VaultSyncNotifier = @Sendable (URL) async -> Void
    typealias MemoryFlushHandler = @Sendable (UUID) async -> Void

    static let shared = ConversationPersistence(
        rootURL: {
            let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            return baseURL
                .appendingPathComponent("Epistemos", isDirectory: true)
                .appendingPathComponent("ConversationPersistence", isDirectory: true)
        }()
    )

    private struct SessionMetadata: Sendable {
        var channel: ConversationChannel
        var title: String
        /// Path to saved SSM state cache file, if this session uses an SSM model.
        var ssmStatePath: String?
    }

    private let rootURL: URL
    private let sessionsURL: URL
    private let chatsURL: URL
    private let fileManager: FileManager
    private let vaultSyncNotifier: VaultSyncNotifier?
    private let sessionEndMemoryFlush: MemoryFlushHandler?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var sessionMetadata: [UUID: SessionMetadata] = [:]

    /// Maps agent session IDs to their Rust-managed session folder paths.
    /// When set, transcript turns are also forwarded to the Rust session folder.
    private var agentSessionFolders: [UUID: String] = [:]

    /// Maps session IDs to their SSM state file paths for vault memory persistence.
    private var ssmStatePaths: [UUID: String] = [:]

    init(
        rootURL: URL,
        fileManager: FileManager = .default,
        vaultSyncNotifier: VaultSyncNotifier? = nil,
        sessionEndMemoryFlush: MemoryFlushHandler? = nil
    ) {
        self.rootURL = rootURL
        self.sessionsURL = rootURL.appendingPathComponent("sessions", isDirectory: true)
        self.chatsURL = rootURL.appendingPathComponent("chats", isDirectory: true)
        self.fileManager = fileManager
        self.vaultSyncNotifier = vaultSyncNotifier
        self.sessionEndMemoryFlush = sessionEndMemoryFlush

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func appendTurn(turn: ConversationTurn, sessionID: UUID) throws {
        try ensureDirectories()
        let sessionFileURL = self.sessionFileURL(for: sessionID)
        let payload = try encoder.encode(turn)
        if fileManager.fileExists(atPath: sessionFileURL.path) {
            let handle = try FileHandle(forWritingTo: sessionFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: payload)
            try handle.write(contentsOf: Data("\n".utf8))
        } else {
            var data = Data()
            data.append(payload)
            data.append(Data("\n".utf8))
            try data.write(to: sessionFileURL, options: .atomic)
        }

        updateMetadata(for: sessionID, with: turn)
    }

    @discardableResult
    func generateCompanionMarkdown(sessionID: UUID) async throws -> URL {
        let turns = try loadTurns(sessionID: sessionID)
        let metadata = resolvedMetadata(for: sessionID, turns: turns)
        let datePrefix = Self.fileDateFormatter.string(from: turns.first?.timestamp ?? .now)
        let fileName = "\(datePrefix)-\(Self.slug(from: metadata.title)).md"
        let channelURL = chatsURL.appendingPathComponent(metadata.channel.rawValue, isDirectory: true)
        try fileManager.createDirectory(at: channelURL, withIntermediateDirectories: true, attributes: nil)
        let companionURL = channelURL.appendingPathComponent(fileName, isDirectory: false)

        let markdown = renderMarkdown(sessionID: sessionID, metadata: metadata, turns: turns)
        try markdown.write(to: companionURL, atomically: true, encoding: .utf8)
        sessionMetadata[sessionID] = metadata
        await vaultSyncNotifier?(companionURL)
        return companionURL
    }

    @discardableResult
    func finishSession(sessionID: UUID) async throws -> URL {
        let companionURL = try await generateCompanionMarkdown(sessionID: sessionID)
        await sessionEndMemoryFlush?(sessionID)
        // Clean up agent folder tracking
        agentSessionFolders.removeValue(forKey: sessionID)
        return companionURL
    }

    // MARK: - Agent Session Folder Binding

    /// Register a Rust-managed session folder for an agent session.
    /// Subsequent `appendTurn` calls will also be forwarded to the Rust folder.
    func bindAgentSessionFolder(sessionID: UUID, folderPath: String) {
        agentSessionFolders[sessionID] = folderPath
    }

    /// Get the Rust session folder path for an agent session (if bound).
    func agentSessionFolderPath(sessionID: UUID) -> String? {
        agentSessionFolders[sessionID]
    }

    // MARK: - SSM State Persistence

    /// Bind an SSM state file path to a session for vault memory persistence.
    func bindSSMStatePath(sessionID: UUID, statePath: String) {
        ssmStatePaths[sessionID] = statePath
        if var meta = sessionMetadata[sessionID] {
            meta.ssmStatePath = statePath
            sessionMetadata[sessionID] = meta
        } else {
            sessionMetadata[sessionID] = SessionMetadata(
                channel: .main,
                title: "Conversation",
                ssmStatePath: statePath
            )
        }
    }

    /// Get the SSM state file path for a session (if saved).
    func ssmStatePath(sessionID: UUID) -> String? {
        ssmStatePaths[sessionID]
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: sessionsURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: chatsURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(
            at: chatsURL.appendingPathComponent(ConversationChannel.main.rawValue, isDirectory: true),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try fileManager.createDirectory(
            at: chatsURL.appendingPathComponent(ConversationChannel.mini.rawValue, isDirectory: true),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try fileManager.createDirectory(
            at: chatsURL.appendingPathComponent(ConversationChannel.agentic.rawValue, isDirectory: true),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func sessionFileURL(for sessionID: UUID) -> URL {
        sessionsURL.appendingPathComponent("\(sessionID.uuidString).jsonl", isDirectory: false)
    }

    private func loadTurns(sessionID: UUID) throws -> [ConversationTurn] {
        let sessionFileURL = self.sessionFileURL(for: sessionID)
        let contents = try String(contentsOf: sessionFileURL, encoding: .utf8)
        return try contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { line in
                try decoder.decode(ConversationTurn.self, from: Data(line.utf8))
            }
    }

    private func updateMetadata(for sessionID: UUID, with turn: ConversationTurn) {
        let existing = sessionMetadata[sessionID]
        let title = existing?.title.isEmpty == false
            ? existing?.title ?? ""
            : Self.title(from: turn.content)
        let channel = existing.map { higherPriorityChannel($0.channel, inferredChannel(for: turn)) } ?? inferredChannel(for: turn)
        sessionMetadata[sessionID] = SessionMetadata(
            channel: channel,
            title: title,
            ssmStatePath: existing?.ssmStatePath ?? ssmStatePaths[sessionID]
        )
    }

    private func inferMetadata(from turns: [ConversationTurn]) -> SessionMetadata {
        let title = turns
            .first(where: { $0.role == .user && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .map { Self.title(from: $0.content) }
            ?? "Conversation"
        let channel = turns.reduce(ConversationChannel.main) { partial, turn in
            higherPriorityChannel(partial, inferredChannel(for: turn))
        }
        return SessionMetadata(channel: channel, title: title, ssmStatePath: nil)
    }

    private func resolvedMetadata(for sessionID: UUID, turns: [ConversationTurn]) -> SessionMetadata {
        var metadata = sessionMetadata[sessionID] ?? inferMetadata(from: turns)
        if metadata.ssmStatePath == nil {
            metadata.ssmStatePath = ssmStatePaths[sessionID]
        }
        sessionMetadata[sessionID] = metadata
        return metadata
    }

    private func inferredChannel(for turn: ConversationTurn) -> ConversationChannel {
        let normalizedModel = turn.model.lowercased()
        if !turn.toolCalls.isEmpty || !turn.vaultMutations.isEmpty || normalizedModel.contains("agent") {
            return .agentic
        }
        if normalizedModel.contains("mini") {
            return .mini
        }
        return .main
    }

    private func renderMarkdown(
        sessionID: UUID,
        metadata: SessionMetadata,
        turns: [ConversationTurn]
    ) -> String {
        var sections: [String] = []
        sections.append("# \(metadata.title)")
        sections.append("")
        sections.append("- Session: \(sessionID.uuidString)")
        sections.append("- Channel: \(metadata.channel.rawValue)")
        sections.append("- Turns: \(turns.count)")
        if let ssmStatePath = metadata.ssmStatePath {
            sections.append("- SSM State: \(ssmStatePath)")
        }
        sections.append("")

        for turn in turns {
            sections.append("## \(turn.role.rawValue.capitalized)")
            sections.append("")
            sections.append(turn.content)
            sections.append("")
            sections.append("_Model: \(turn.model)_")
            if let tokens = turn.tokens {
                sections.append("_Tokens: \(tokens)_")
            }
            if let latencyMs = turn.latencyMs {
                sections.append("_Latency: \(Int(latencyMs.rounded())) ms_")
            }
            if !turn.toolCalls.isEmpty {
                sections.append("_Tool calls: \(turn.toolCalls.joined(separator: ", "))_")
            }
            if !turn.vaultMutations.isEmpty {
                sections.append("_Vault mutations: \(turn.vaultMutations.joined(separator: ", "))_")
            }
            sections.append("")
        }

        return sections.joined(separator: "\n")
    }

    private static func title(from content: String) -> String {
        let trimmed = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)
            ?? "Conversation"
        return String(trimmed.prefix(48)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func slug(from title: String) -> String {
        let slug = String(title
            .lowercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : "-"
            }
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-"))
        return slug.isEmpty ? "conversation" : slug
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private nonisolated func higherPriorityChannel(_ lhs: ConversationChannel, _ rhs: ConversationChannel) -> ConversationChannel {
    let rank: [ConversationChannel: Int] = [.main: 0, .mini: 1, .agentic: 2]
    return (rank[lhs] ?? 0) >= (rank[rhs] ?? 0) ? lhs : rhs
}
