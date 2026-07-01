import CryptoKit
import Observation
import SwiftUI
import OSLog

nonisolated enum ApprovalAuditDiagnostics {
    static let maxLogMessageCharacters = 240
    private static let maxDomainCharacters = 80

    static func externalLogMessage(_ operation: String, error: Error) -> String {
        let fallback = boundedLogMessage(operation, fallback: "approval audit failed")
        let nsError = error as NSError
        return boundedLogMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func boundedLogMessage(_ message: String, fallback: String = "approval audit failed") -> String {
        let bounded = String(message.prefix(maxLogMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxLogMessageCharacters else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(
            trimmed.startIndex,
            offsetBy: max(0, maxLogMessageCharacters - suffix.count)
        )
        return String(trimmed[..<end]) + suffix
    }

    private static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= maxDomainCharacters else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: maxDomainCharacters)
            return String(trimmed[..<end])
        }
        return trimmed
    }
}

// MARK: - W9.8 — ApprovalModalView (PausedForApproval surface)
//
// SwiftUI counterpart to the existing NSAlert-based
// agent tool-approval flow. Used when:
//   - The agent runtime fires `SessionState::PausedForApproval`
//     from the background (agent_core/src/session.rs:124) and the
//     foreground UI wants a non-blocking sheet instead of an alert.
//   - The Pro build's iMessage / shell escape flows need an
//     in-context approval that doesn't grab AppKit focus.
//
// Deadline countdown: agent_core writes `deadline_secs` (Unix epoch)
// into the PausedForApproval state; this view renders a live progress
// ring that auto-denies on expiry.
//
// Wiring (canonical):
//   - StreamingDelegate forwards the session-state event to the
//     parent view as a `PendingApproval` value
//   - The view is rendered as a `.sheet(item:)` modal
//   - On approve/deny/timeout the parent calls back into Rust via
//     `RustAgentBridge.resolveApproval(sessionId, decision)`

@MainActor
public struct ApprovalModalView: View {

    public struct PendingApproval: Identifiable, Hashable {
        public let id: String
        public let sessionId: String
        public let toolName: String
        public let argsJSON: String
        public let deadline: Date
        public let issuedAt: Date
        public let summary: String?
        public let authorityCategoryLabel: String?

        public init(
            id: String = UUID().uuidString,
            sessionId: String,
            toolName: String,
            argsJSON: String,
            deadline: Date,
            issuedAt: Date = Date(),
            summary: String? = nil,
            authorityCategoryLabel: String? = nil
        ) {
            self.id = id
            self.sessionId = sessionId
            self.toolName = toolName
            self.argsJSON = argsJSON
            self.deadline = deadline
            self.issuedAt = issuedAt
            self.summary = summary
            self.authorityCategoryLabel = authorityCategoryLabel
        }
    }

    public enum Decision: Sendable, Equatable {
        case approveOnce
        case approveAlways
        case applyLessInterruptions
        case deny
        case timedOut
    }

    private let approval: PendingApproval
    private let onResolve: (Decision) -> Void
    @State private var didResolve = false

    // No `Timer.publish().autoconnect()` here. Combine timers retain
    // their backing scheduler across view-struct re-creations and the
    // `.autoconnect()` keeps them ticking until every subscriber is
    // gone, which can lag behind a `.sheet(item:)` dismissal. A
    // `TimelineView(.periodic(...))` is the SwiftUI-native pattern: it
    // pauses when the view is offscreen / occluded and stops cold when
    // the modal is dismissed — no explicit invalidate needed.
    private let log = Logger(subsystem: "com.epistemos", category: "ApprovalModal")

    public init(
        approval: PendingApproval,
        onResolve: @escaping (Decision) -> Void
    ) {
        self.approval = approval
        self.onResolve = onResolve
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let now = context.date
            let remaining = max(0, approval.deadline.timeIntervalSince(now))
            let total = max(1, approval.deadline.timeIntervalSince(approval.issuedAt))
            let fraction = min(1, max(0, remaining / total))

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Approve agent action?")
                            .font(.headline)
                        Text(approval.toolName)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if let authorityCategoryLabel = approval.authorityCategoryLabel {
                        Text(authorityCategoryLabel)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                    Spacer()
                    countdownRing(remaining: remaining, fraction: fraction)
                }

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(approvalPayloads) { payload in
                            GenUIDispatcher.shared.render(payload)
                        }
                    }
                }
                .frame(maxHeight: 260)

                HStack {
                    Button("Deny") { resolve(.deny) }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Allow Once") { resolve(.approveOnce) }
                    Button("Less Interruptions") { resolve(.applyLessInterruptions) }
                    Button("Always Allow") { resolve(.approveAlways) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 480, idealWidth: 540)
            .task(id: remaining <= 0) {
                if remaining <= 0 {
                    resolve(.timedOut)
                }
            }
        }
    }

    private var approvalPayloads: [GenUIPayload] {
        let deadlineEpoch = approval.deadline.timeIntervalSince1970
        let deadlineValue = deadlineEpoch.isFinite ? "\(Int(deadlineEpoch))" : "unknown"
        var payloads = [
            GenUIPayload.keyValueTable(
                title: "Approval Request",
                [
                    ("Tool", approval.toolName),
                    ("Session", approval.sessionId),
                    ("Authority", approval.authorityCategoryLabel ?? "Uncategorized"),
                    ("Deadline", deadlineValue),
                ],
                id: "\(approval.id)-request",
                metadata: ["surface": "approval-modal"],
                createdAt: approval.issuedAt
            ),
        ]

        if let summary = approval.summary, !summary.isEmpty {
            payloads.append(
                GenUIPayload(
                    id: "\(approval.id)-summary",
                    schema: .markdown,
                    title: "Summary",
                    body: .raw(summary),
                    metadata: ["surface": "approval-modal"],
                    createdAt: approval.issuedAt
                )
            )
        }

        payloads.append(
            GenUIPayload(
                id: "\(approval.id)-arguments",
                schema: .json,
                title: "Arguments",
                body: .raw(approval.argsJSON),
                metadata: ["surface": "approval-modal"],
                createdAt: approval.issuedAt
            )
        )

        return payloads
    }

    private func countdownRing(remaining: TimeInterval, fraction: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(remaining < 5 ? Color.red : Color.accentColor, style: .init(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: fraction)
            Text("\(Int(remaining))s")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(width: 36, height: 36)
    }

    private func resolve(_ decision: Decision) {
        guard !didResolve else { return }
        didResolve = true
        guard ChatApprovalSovereignGate.requiresConfirmation(for: decision) else {
            finishResolve(decision)
            return
        }

        Task { @MainActor in
            let requirement = ChatApprovalSovereignGate.requirement(
                for: decision,
                toolName: approval.toolName
            )
            let reason = ChatApprovalSovereignGate.reason(
                for: decision,
                toolName: approval.toolName
            )
            let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
                requirement,
                reason: reason
            ) ?? .denied(.authenticationFailed)
            finishResolve(outcome == .allowed ? decision : .deny)
        }
    }

    private func finishResolve(_ decision: Decision) {
        log.info("approval resolved tool=\(approval.toolName, privacy: .public) decision=\(String(describing: decision), privacy: .public)")
        onResolve(decision)
    }
}

public enum ChatApprovalResolution: Sendable, Equatable {
    case allowOnce
    case alwaysAllow
    case applyLessInterruptions
    case deny
}

public enum ChatApprovalEventKind: String, Sendable {
    case promptShown = "prompt_shown"
    case userResolved = "user_resolved"
    case dedupShortCircuit = "dedup_short_circuit"
    case timeoutDenied = "timeout_denied"
    case overlappingDenied = "overlapping_denied"
}

enum ChatApprovalSovereignGate {
    static func requiresConfirmation(for decision: ApprovalModalView.Decision) -> Bool {
        switch decision {
        case .approveOnce, .applyLessInterruptions, .approveAlways:
            return true
        case .deny, .timedOut:
            return false
        }
    }

    static func requirement(
        for decision: ApprovalModalView.Decision,
        toolName: String
    ) -> SovereignGateRequirement {
        switch decision {
        case .approveOnce:
            .biometric(category: SovereignGateCategory(rawValue: "agent-tool-\(normalizedToolName(toolName))"))
        case .applyLessInterruptions, .approveAlways:
            .deviceOwnerAuthentication
        case .deny, .timedOut:
            .none
        }
    }

    static func reason(
        for decision: ApprovalModalView.Decision,
        toolName: String
    ) -> String {
        let toolName = normalizedToolName(toolName)
        switch decision {
        case .approveOnce:
            return "Approve \(toolName) for this agent action."
        case .applyLessInterruptions:
            return "Apply Less Interruptions for \(toolName). This changes future approval behavior."
        case .approveAlways:
            return "Always allow \(toolName). This changes future approval behavior."
        case .deny, .timedOut:
            return "No approval requested for \(toolName)."
        }
    }

    private static func normalizedToolName(_ toolName: String) -> String {
        let trimmed = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown-tool" : trimmed
    }
}

@MainActor @Observable
public final class ChatApprovalQueue {
    public var pendingApproval: ApprovalModalView.PendingApproval?
    @ObservationIgnored public var sessionFolderPathResolver: (@MainActor (String) -> String?)?
    @ObservationIgnored public var auditLogDirectoryOverride: URL?

    @ObservationIgnored private var pendingContinuations: [String: CheckedContinuation<ChatApprovalResolution, Never>] = [:]
    @ObservationIgnored private var approvedHashesBySession: [String: Set<String>] = [:]
    @ObservationIgnored private let auditLog: ChatApprovalAuditLog
    @ObservationIgnored private let log = Logger(subsystem: "com.epistemos", category: "ChatApprovalQueue")

    public init(auditLog: ChatApprovalAuditLog = ChatApprovalAuditLog()) {
        self.auditLog = auditLog
    }

    public func resetSession(sessionId: String) {
        approvedHashesBySession[sessionId] = []
    }

    public static func dedupHash(toolName: String, argsJSON: String) -> String {
        let bytes = "\(toolName)\u{1F}\(argsJSON)".data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func isAlreadyApproved(
        sessionId: String,
        toolName: String,
        argsJSON: String
    ) -> Bool {
        let hash = Self.dedupHash(toolName: toolName, argsJSON: argsJSON)
        return approvedHashesBySession[sessionId]?.contains(hash) == true
    }

    public func markApproved(
        sessionId: String,
        toolName: String,
        argsJSON: String
    ) {
        let hash = Self.dedupHash(toolName: toolName, argsJSON: argsJSON)
        var current = approvedHashesBySession[sessionId] ?? []
        current.insert(hash)
        approvedHashesBySession[sessionId] = current
    }

    public func enqueue(
        sessionId: String,
        toolName: String,
        argsJSON: String,
        deadline: Date,
        summary: String?,
        authorityCategoryLabel: String?
    ) async -> ChatApprovalResolution {
        if approvedHashesBySession[sessionId] == nil {
            approvedHashesBySession[sessionId] = []
        }
        if isAlreadyApproved(sessionId: sessionId, toolName: toolName, argsJSON: argsJSON) {
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

        if pendingApproval != nil {
            log.error("denying overlapping approval request tool=\(toolName, privacy: .public)")
            recordAuditEntry(
                sessionId: sessionId,
                toolName: toolName,
                argsJSON: argsJSON,
                resolution: .deny,
                eventKind: .overlappingDenied,
                authorityCategoryLabel: authorityCategoryLabel
            )
            return .deny
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

    public func resolve(
        _ approval: ApprovalModalView.PendingApproval,
        decision: ApprovalModalView.Decision
    ) {
        guard pendingApproval?.id == approval.id,
              let continuation = pendingContinuations.removeValue(forKey: approval.id)
        else { return }

        let resolution = resolution(for: decision)
        let eventKind: ChatApprovalEventKind = decision == .timedOut ? .timeoutDenied : .userResolved
        recordAuditEntry(
            sessionId: approval.sessionId,
            toolName: approval.toolName,
            argsJSON: approval.argsJSON,
            resolution: resolution,
            eventKind: eventKind,
            authorityCategoryLabel: approval.authorityCategoryLabel
        )
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
        pendingApproval = nil
        continuation.resume(returning: resolution)
    }

    private func resolution(for decision: ApprovalModalView.Decision) -> ChatApprovalResolution {
        switch decision {
        case .approveOnce:
            return .allowOnce
        case .approveAlways:
            return .alwaysAllow
        case .applyLessInterruptions:
            return .applyLessInterruptions
        case .deny, .timedOut:
            return .deny
        }
    }

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
        } else if let path = sessionFolderPathResolver?(sessionId) {
            directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            directory = nil
        }
        guard let directory else {
            log.info("approval audit skipped session=\(sessionId, privacy: .public) tool=\(toolName, privacy: .public) event=\(eventKind.rawValue, privacy: .public)")
            return
        }

        let entry = ChatApprovalAuditLog.Entry(
            timestamp: Date(),
            sessionId: sessionId,
            toolName: toolName,
            argsHash: Self.dedupHash(toolName: toolName, argsJSON: argsJSON),
            argsJSON: argsJSON,
            resolution: resolution?.auditRawValue,
            eventKind: eventKind.rawValue,
            authorityCategoryLabel: authorityCategoryLabel
        )
        do {
            try auditLog.append(entry: entry, sessionFolder: directory)
        } catch {
            let failure = ApprovalAuditDiagnostics.externalLogMessage(
                "approval audit append failed",
                error: error
            )
            log.error("\(failure, privacy: .public) session=\(sessionId, privacy: .public)")
        }
    }
}

private extension ChatApprovalResolution {
    var auditRawValue: String {
        switch self {
        case .allowOnce:
            return "allow_once"
        case .alwaysAllow:
            return "always_allow"
        case .applyLessInterruptions:
            return "apply_less_interruptions"
        case .deny:
            return "deny"
        }
    }
}

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
        for raw in data.split(separator: 0x0A) where !raw.isEmpty {
            if let entry = try? decoder.decode(Entry.self, from: Data(raw)) {
                rows.append(entry)
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
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}

#if DEBUG
#Preview("Approval modal") {
    ApprovalModalView(
        approval: .init(
            sessionId: "s-123",
            toolName: "shell.execute",
            argsJSON: #"{"command":"rm -rf ~/Downloads/old-build"}"#,
            deadline: Date().addingTimeInterval(30),
            summary: "Permission group: Shell\n\nThe agent requested a shell command.",
            authorityCategoryLabel: "Shell"
        ),
        onResolve: { _ in }
    )
}
#endif
