import Foundation
import Observation

nonisolated enum ApprovalPolicyListKind: String, Sendable {
    case allowlist
    case blocklist
}

nonisolated enum ApprovalHistoryOutcome: String, Sendable, Equatable {
    case approved
    case denied
    case unknown
}

nonisolated struct ApprovalPolicyPattern: Identifiable, Hashable, Sendable {
    let pattern: String

    var id: String { pattern }
}

nonisolated struct ApprovalPolicySnapshot: Equatable, Sendable {
    let allowlist: [ApprovalPolicyPattern]
    let blocklist: [ApprovalPolicyPattern]
    let lastModified: Date?

    static let empty = ApprovalPolicySnapshot(allowlist: [], blocklist: [], lastModified: nil)
}

nonisolated struct ApprovalHistoryEntry: Identifiable, Hashable, Sendable {
    let sessionFolderName: String
    let sessionFolderPath: String
    let toolName: String
    let inputSummary: String?
    let reason: String
    let outcome: ApprovalHistoryOutcome
    let timestamp: Date?

    var id: String {
        "\(sessionFolderPath):\(toolName):\(timestamp?.timeIntervalSince1970 ?? 0)"
    }
}

@MainActor @Observable
final class AgentApprovalPolicyStore {
    var snapshot: ApprovalPolicySnapshot = .empty
    var history: [ApprovalHistoryEntry] = []
    var lastError: String?

    func refresh(vaultPath: String) {
        do {
            snapshot = try Self.loadSnapshot(vaultPath: vaultPath)
            history = Self.loadHistory(vaultPath: vaultPath, limit: 12)
            lastError = nil
        } catch {
            snapshot = .empty
            history = []
            lastError = error.localizedDescription
        }
    }

    func add(pattern: String, to listKind: ApprovalPolicyListKind, vaultPath: String) throws {
        let normalizedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPattern.isEmpty else {
            return
        }

        var document = try Self.loadDocument(vaultPath: vaultPath)
        switch listKind {
        case .allowlist:
            document.allowlist.insert(normalizedPattern)
        case .blocklist:
            document.blocklist.insert(normalizedPattern)
        }
        document.lastModified = Int(Date().timeIntervalSince1970.rounded())
        try Self.writeDocument(document, vaultPath: vaultPath)
        refresh(vaultPath: vaultPath)
    }

    func remove(pattern: String, from listKind: ApprovalPolicyListKind, vaultPath: String) throws {
        var document = try Self.loadDocument(vaultPath: vaultPath)
        switch listKind {
        case .allowlist:
            document.allowlist.remove(pattern)
        case .blocklist:
            document.blocklist.remove(pattern)
        }
        document.lastModified = Int(Date().timeIntervalSince1970.rounded())
        try Self.writeDocument(document, vaultPath: vaultPath)
        refresh(vaultPath: vaultPath)
    }

    static func loadSnapshot(vaultPath: String) throws -> ApprovalPolicySnapshot {
        let document = try loadDocument(vaultPath: vaultPath)
        return ApprovalPolicySnapshot(
            allowlist: document.allowlist.sorted().map(ApprovalPolicyPattern.init(pattern:)),
            blocklist: document.blocklist.sorted().map(ApprovalPolicyPattern.init(pattern:)),
            lastModified: document.lastModified.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    static func loadHistory(vaultPath: String, limit: Int) -> [ApprovalHistoryEntry] {
        let sessionsRoot = URL(fileURLWithPath: vaultPath, isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var entries: [ApprovalHistoryEntry] = []
        for case let traceURL as URL in enumerator where traceURL.lastPathComponent == "trace.json" {
            let sessionFolderPath = traceURL.deletingLastPathComponent().path
            let sessionFolderName = traceURL.deletingLastPathComponent().lastPathComponent
            entries.append(contentsOf: parseHistoryEntries(
                traceURL: traceURL,
                sessionFolderName: sessionFolderName,
                sessionFolderPath: sessionFolderPath
            ))
        }

        return entries
            .sorted { lhs, rhs in
                (lhs.timestamp ?? .distantPast) > (rhs.timestamp ?? .distantPast)
            }
            .prefix(max(1, limit))
            .map { $0 }
    }

    private static func parseHistoryEntries(
        traceURL: URL,
        sessionFolderName: String,
        sessionFolderPath: String
    ) -> [ApprovalHistoryEntry] {
        guard let data = try? Data(contentsOf: traceURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        return root.compactMap { row in
            guard (row["kind"] as? String) == "approval" else {
                return nil
            }

            let toolName = (row["name"] as? String) ?? "unknown"
            let reason = (row["output_summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No explanation recorded."
            let inputSummary = row["input_summary"] as? String
            let timestamp = (row["timestamp"] as? String).flatMap(formatter.date)
            let outcome = ApprovalHistoryOutcome(rawValue: (row["outcome"] as? String) ?? "") ?? .unknown

            return ApprovalHistoryEntry(
                sessionFolderName: sessionFolderName,
                sessionFolderPath: sessionFolderPath,
                toolName: toolName,
                inputSummary: inputSummary,
                reason: reason,
                outcome: outcome,
                timestamp: timestamp
            )
        }
    }

    private static func loadDocument(vaultPath: String) throws -> ApprovalListsDocument {
        let url = approvalListURL(vaultPath: vaultPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ApprovalListsDocument()
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ApprovalListsDocument.self, from: data)
    }

    private static func writeDocument(_ document: ApprovalListsDocument, vaultPath: String) throws {
        let url = approvalListURL(vaultPath: vaultPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.approvalPolicyEncoder.encode(document.normalized())
        try data.write(to: url, options: .atomic)
    }

    private static func approvalListURL(vaultPath: String) -> URL {
        URL(fileURLWithPath: vaultPath, isDirectory: true)
            .appendingPathComponent(".epistemos", isDirectory: true)
            .appendingPathComponent("approval_lists.json")
    }
}

private struct ApprovalListsDocument: Codable {
    var allowlist: Set<String> = []
    var blocklist: Set<String> = []
    var lastModified: Int?

    enum CodingKeys: String, CodingKey {
        case allowlist
        case blocklist
        case lastModified = "last_modified"
    }

    func normalized() -> ApprovalListsDocument {
        ApprovalListsDocument(
            allowlist: Set(allowlist.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }),
            blocklist: Set(blocklist.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }),
            lastModified: lastModified
        )
    }
}

private extension JSONEncoder {
    static let approvalPolicyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
