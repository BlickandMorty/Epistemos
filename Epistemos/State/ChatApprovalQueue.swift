import CryptoKit
import Foundation
import Observation
import os

// MARK: - W9.8 — ChatApprovalQueue (sheet-based approval bridge)
//
// This bridge replaces the previous `NSAlert.beginSheetModal` path
// inside `ChatCoordinator.promptUserForToolApproval`. ChatCoordinator
// is a `@MainActor final class` (NOT `@Observable`), so it cannot
// itself drive a `.sheet(item:)` modifier. ChatApprovalQueue is the
// observation-friendly seam between the coordinator and SwiftUI:
//
//   1. ChatCoordinator builds a `ApprovalModalView.PendingApproval`
//      and calls `enqueue(...)` returning `await` on the result.
//   2. ChatApprovalQueue stores the pending approval, which causes
//      the SwiftUI parent's `.sheet(item: $queue.pendingApproval)`
//      modifier to present the modal.
//   3. The modal's `onResolve` callback calls back into
//      `ChatApprovalQueue.resolve(...)`, which resumes the
//      checked continuation the coordinator was awaiting.
//
// Auxiliary responsibilities (per `docs/plan/03_EXECUTION_MAP.md`
// §W9.8 definition of done):
//   - Append a JSONL audit row to
//     `<session>/approvals.jsonl` for every decision.
//   - Dedup-by-`args_json` hash within the session: a tool whose
//     (toolName, args_json) was already approved this session
//     short-circuits to the same approval without re-prompting.

/// Decision payload that ChatCoordinator awaits. `Resolution`
/// matches the `ToolApprovalPromptChoice` shape so the call site
/// only has to map four cases. Defined separately from the modal's
/// `Decision` so the queue can synthesize values for short-circuit
/// dedup paths (where the modal never renders).
nonisolated public enum ChatApprovalResolution: Sendable, Equatable {
    case allowOnce
    case alwaysAllow
    case applyLessInterruptions
    case deny

    public init(_ decision: ApprovalModalView.Decision) {
        switch decision {
        case .approveOnce:
            self = .allowOnce
        case .approveAlways:
            self = .alwaysAllow
        case .applyLessInterruptions:
            self = .applyLessInterruptions
        case .deny, .timedOut:
            self = .deny
        }
    }
}

/// Origin of an approval decision. Drives the `event_kind` column
/// in the JSONL audit log and lets reviewers distinguish a fresh
/// user click from a dedup short-circuit or a timeout auto-deny.
nonisolated public enum ChatApprovalEventKind: String, Sendable {
    case promptShown = "prompt_shown"
    case userResolved = "user_resolved"
    case dedupShortCircuit = "dedup_short_circuit"
    case timeoutDenied = "timeout_denied"
}

@MainActor @Observable
final class ChatApprovalQueue {
    /// SwiftUI binds against this for `.sheet(item:)`. Set to nil
    /// after `resolve(...)` to dismiss the modal.
    var pendingApproval: ApprovalModalView.PendingApproval?

    /// Set of `(toolName, args_json)` SHA-256 digests that have
    /// already been approved in the current session. Cleared by
    /// `resetSession(...)`. Per execution map §W9.8 DoD #2:
    /// "Approval/denial dedupes by args_json hash within session".
    private var approvedHashesBySession: [String: Set<String>] = [:]

    /// Active session ID. ChatCoordinator stamps this when a new
    /// session begins so dedup state is always scoped per session.
    private(set) var activeSessionId: String?

    /// Wired by AppBootstrap so the queue can resolve session
    /// folder paths through the same FFI helper ChatCoordinator
    /// uses for completion lineage.
    var sessionFolderPathResolver: (@MainActor (String) -> String?)?

    /// Default audit-log writer. Tests can swap this to a
    /// memory-backed implementation. `auditLogDirectoryOverride`
    /// short-circuits the resolver for unit tests too — when
    /// non-nil the queue writes JSONL straight to that directory
    /// regardless of what the resolver returns.
    var auditLogDirectoryOverride: URL?

    private var pendingContinuations: [String: CheckedContinuation<ChatApprovalResolution, Never>] = [:]
    private let auditLog: ChatApprovalAuditLog
    private let log = Logger(subsystem: "com.epistemos", category: "ChatApprovalQueue")

    init(auditLog: ChatApprovalAuditLog = ChatApprovalAuditLog()) {
        self.auditLog = auditLog
    }

    // MARK: - Lifecycle

    /// Reset the queue's per-session state. Called when a new
    /// chat session begins so a previously-approved write doesn't
    /// silently auto-allow a write in a different session.
    func resetSession(sessionId: String) {
        activeSessionId = sessionId
        approvedHashesBySession[sessionId] = []
    }

    // MARK: - Hash helpers

    /// Stable hash key combining the tool name and the canonical
    /// `args_json` string. CryptoKit `SHA256` is FIPS-blessed and
    /// already imported by `NoteFileStorage`, so no new dependency.
    static func dedupHash(toolName: String, argsJSON: String) -> String {
        let bytes = "\(toolName)\u{1F}\(argsJSON)".data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// True if the (toolName, args_json) pair was already approved
    /// in the current session. Tests can call this directly. The
    /// production path goes through `enqueue(...)`.
    func isAlreadyApproved(
        sessionId: String,
        toolName: String,
        argsJSON: String
    ) -> Bool {
        guard let digest = approvedHashesBySession[sessionId] else {
            return false
        }
        let hash = Self.dedupHash(toolName: toolName, argsJSON: argsJSON)
        return digest.contains(hash)
    }

    /// Mark a (toolName, args_json) pair approved in this session.
    /// Idempotent. Visible to tests.
    func markApproved(
        sessionId: String,
        toolName: String,
        argsJSON: String
    ) {
        let hash = Self.dedupHash(toolName: toolName, argsJSON: argsJSON)
        var current = approvedHashesBySession[sessionId] ?? []
        current.insert(hash)
        approvedHashesBySession[sessionId] = current
    }

    // MARK: - Enqueue / resolve

    /// Enqueue a pending approval and await the user's decision.
    /// Performs the dedup short-circuit + audit-log append before
    /// returning. Mirrors the prior `NSAlert` round-trip shape so
    /// the call site at `ChatCoordinator.promptUserForToolApproval`
    /// can stay a single `await`.
    func enqueue(
        sessionId: String,
        toolName: String,
        argsJSON: String,
        deadline: Date,
        summary: String?,
        authorityCategoryLabel: String?
    ) async -> ChatApprovalResolution {
        // Always make sure dedup state is scoped to this session
        // — if a caller forgot to `resetSession`, lazily seed it.
        if approvedHashesBySession[sessionId] == nil {
            approvedHashesBySession[sessionId] = []
        }
        activeSessionId = sessionId

        // Per execution map §W9.8 DoD #2 — short-circuit duplicate
        // approvals so retries on the same args_json don't re-prompt.
        if isAlreadyApproved(
            sessionId: sessionId,
            toolName: toolName,
            argsJSON: argsJSON
        ) {
            recordAuditEntry(
                sessionId: sessionId,
                toolName: toolName,
                argsJSON: argsJSON,
                resolution: .allowOnce,
                eventKind: .dedupShortCircuit,
                authorityCategoryLabel: authorityCategoryLabel
            )
            return .allowOnce
        }

        let approval = ApprovalModalView.PendingApproval(
            sessionId: sessionId,
            toolName: toolName,
            argsJSON: argsJSON,
            deadline: deadline,
            summary: summary,
            authorityCategoryLabel: authorityCategoryLabel
        )

        recordAuditEntry(
            sessionId: sessionId,
            toolName: toolName,
            argsJSON: argsJSON,
            resolution: nil,
            eventKind: .promptShown,
            authorityCategoryLabel: authorityCategoryLabel
        )

        return await withCheckedContinuation { continuation in
            pendingContinuations[approval.id] = continuation
            pendingApproval = approval
        }
    }

    /// Called by SwiftUI when the modal resolves. Public so the
    /// `.sheet(item:)` callback can wire `onResolve` directly into
    /// the queue without going back through ChatCoordinator.
    func resolve(_ approval: ApprovalModalView.PendingApproval, decision: ApprovalModalView.Decision) {
        let resolution = ChatApprovalResolution(decision)
        let eventKind: ChatApprovalEventKind = (decision == .timedOut)
            ? .timeoutDenied
            : .userResolved
        recordAuditEntry(
            sessionId: approval.sessionId,
            toolName: approval.toolName,
            argsJSON: approval.argsJSON,
            resolution: resolution,
            eventKind: eventKind,
            authorityCategoryLabel: approval.authorityCategoryLabel
        )

        // On approve, remember the args_json so subsequent
        // identical retries inside this session auto-allow.
        switch resolution {
        case .allowOnce, .alwaysAllow, .applyLessInterruptions:
            markApproved(
                sessionId: approval.sessionId,
                toolName: approval.toolName,
                argsJSON: approval.argsJSON
            )
        case .deny:
            break
        }

        // Dismiss the sheet first, then resume — clearing
        // `pendingApproval` while a continuation is still
        // pending would break SwiftUI binding invariants.
        if pendingApproval?.id == approval.id {
            pendingApproval = nil
        }
        guard let continuation = pendingContinuations.removeValue(forKey: approval.id) else {
            log.error("approval resolved with no awaiting continuation id=\(approval.id, privacy: .public)")
            return
        }
        continuation.resume(returning: resolution)
    }

    // MARK: - Audit log

    private func recordAuditEntry(
        sessionId: String,
        toolName: String,
        argsJSON: String,
        resolution: ChatApprovalResolution?,
        eventKind: ChatApprovalEventKind,
        authorityCategoryLabel: String?
    ) {
        let directory: URL?
        if let override = auditLogDirectoryOverride {
            directory = override
        } else if let resolver = sessionFolderPathResolver,
                  let path = resolver(sessionId) {
            directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            directory = nil
        }
        guard let directory else {
            // No vault attached yet, or session folder not yet
            // materialized. The dedup + sheet behavior still
            // works; the audit-row append simply no-ops with a log.
            log.info("approval audit no session folder; skipping JSONL append session=\(sessionId, privacy: .public) tool=\(toolName, privacy: .public) event=\(eventKind.rawValue, privacy: .public)")
            return
        }

        let entry = ChatApprovalAuditLog.Entry(
            timestamp: Date(),
            sessionId: sessionId,
            toolName: toolName,
            argsHash: Self.dedupHash(toolName: toolName, argsJSON: argsJSON),
            argsJSON: argsJSON,
            resolution: resolution?.rawValue,
            eventKind: eventKind.rawValue,
            authorityCategoryLabel: authorityCategoryLabel
        )
        do {
            try auditLog.append(entry: entry, sessionFolder: directory)
        } catch {
            log.error("approval audit append failed session=\(sessionId, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - JSONL audit log

extension ChatApprovalResolution {
    fileprivate var rawValue: String {
        switch self {
        case .allowOnce: return "allow_once"
        case .alwaysAllow: return "always_allow"
        case .applyLessInterruptions: return "apply_less_interruptions"
        case .deny: return "deny"
        }
    }
}

/// JSON-Lines audit-log helper for `<session>/approvals.jsonl`.
/// Each `append(...)` call serializes one `Entry` and appends a
/// newline. Concurrency: serialized through a private
/// dispatch queue so concurrent calls from any thread don't
/// interleave half-written lines (per §W9.8 DoD #4 — "Audit log
/// JSONL appendable from concurrent sessions without corruption").
public final class ChatApprovalAuditLog: @unchecked Sendable {
    public struct Entry: Codable, Sendable, Equatable {
        public let timestamp: Date
        public let sessionId: String
        public let toolName: String
        public let argsHash: String
        public let argsJSON: String
        public let resolution: String?
        public let eventKind: String
        public let authorityCategoryLabel: String?

        public init(
            timestamp: Date,
            sessionId: String,
            toolName: String,
            argsHash: String,
            argsJSON: String,
            resolution: String?,
            eventKind: String,
            authorityCategoryLabel: String?
        ) {
            self.timestamp = timestamp
            self.sessionId = sessionId
            self.toolName = toolName
            self.argsHash = argsHash
            self.argsJSON = argsJSON
            self.resolution = resolution
            self.eventKind = eventKind
            self.authorityCategoryLabel = authorityCategoryLabel
        }

        enum CodingKeys: String, CodingKey {
            case timestamp = "ts"
            case sessionId = "session_id"
            case toolName = "tool_name"
            case argsHash = "args_hash"
            case argsJSON = "args_json"
            case resolution
            case eventKind = "event_kind"
            case authorityCategoryLabel = "authority_category"
        }
    }

    public static let fileName = "approvals.jsonl"

    private let writeQueue = DispatchQueue(label: "com.epistemos.ChatApprovalAuditLog")
    private let encoder: JSONEncoder

    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func append(entry: Entry, sessionFolder: URL) throws {
        let payload = try encoder.encode(entry)
        // JSONL = JSON object + newline.
        var line = payload
        line.append(0x0A)
        try writeQueue.sync {
            try Self.appendData(line, sessionFolder: sessionFolder)
        }
    }

    public static func entries(in sessionFolder: URL) throws -> [Entry] {
        let url = sessionFolder.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var rows: [Entry] = []
        // Each non-empty line is a Codable Entry. Defensive in
        // case a line was truncated by an interrupted write — bad
        // lines are skipped, not crashed on.
        for raw in data.split(separator: 0x0A) {
            guard !raw.isEmpty else { continue }
            do {
                let entry = try decoder.decode(Entry.self, from: Data(raw))
                rows.append(entry)
            } catch {
                continue
            }
        }
        return rows
    }

    private static func appendData(_ data: Data, sessionFolder: URL) throws {
        try FileManager.default.createDirectory(
            at: sessionFolder,
            withIntermediateDirectories: true
        )
        let url = sessionFolder.appendingPathComponent(fileName, isDirectory: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            try data.write(to: url, options: .atomic)
            return
        }
        let handle = try FileHandle(forWritingTo: url)
        defer {
            do {
                try handle.close()
            } catch {
                // FileHandle.close throws are non-actionable here.
            }
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}
