import Foundation

struct AgentSessionLineageMetadata: Equatable {
    let parentSessionID: String?
    let chatThreadID: String?
}

final class AgentSessionLineageStore {
    static let shared = AgentSessionLineageStore()

    private let userDefaults: UserDefaults
    private let storageKey = "agentSessionLineage.chatThreadParents"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func parentSessionID(forChatThread chatThreadID: String?) -> String? {
        guard let normalizedThreadID = normalized(chatThreadID) else {
            return nil
        }
        let mapping = loadMapping()
        return normalized(mapping[normalizedThreadID])
    }

    @discardableResult
    func recordCompletedSession(
        sessionID: String,
        chatThreadID: String?,
        sessionFolderPath: String
    ) throws -> AgentSessionLineageMetadata {
        let normalizedSessionID = normalized(sessionID) ?? sessionID
        let normalizedThreadID = normalized(chatThreadID)
        let parentSessionID = normalizedThreadID.flatMap { threadID in
            loadMapping()[threadID]
        }

        try Self.writeMetadata(
            sessionFolderPath: sessionFolderPath,
            parentSessionID: parentSessionID,
            chatThreadID: normalizedThreadID
        )

        if let normalizedThreadID {
            var mapping = loadMapping()
            mapping[normalizedThreadID] = normalizedSessionID
            userDefaults.set(mapping, forKey: storageKey)
        }

        return AgentSessionLineageMetadata(
            parentSessionID: parentSessionID,
            chatThreadID: normalizedThreadID
        )
    }

    static func writeMetadata(
        sessionFolderPath: String,
        parentSessionID: String?,
        chatThreadID: String?
    ) throws {
        let sessionURL = URL(fileURLWithPath: sessionFolderPath, isDirectory: true)
            .appendingPathComponent("session.json")
        let data = try Data(contentsOf: sessionURL)
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AgentSessionLineageStoreError.invalidSessionMetadata
        }

        if let parentSessionID = normalized(parentSessionID) {
            root["parent_session_id"] = parentSessionID
        } else {
            root.removeValue(forKey: "parent_session_id")
        }

        if let chatThreadID = normalized(chatThreadID) {
            root["chat_thread_id"] = chatThreadID
        } else {
            root.removeValue(forKey: "chat_thread_id")
        }

        let updatedData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try updatedData.write(to: sessionURL, options: .atomic)
    }

    private func loadMapping() -> [String: String] {
        (userDefaults.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
    }
}

enum AgentSessionLineageStoreError: Error {
    case invalidSessionMetadata
}

private func normalized(_ rawValue: String?) -> String? {
    guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
