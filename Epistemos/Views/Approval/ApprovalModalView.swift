import Observation
import SwiftUI
import OSLog

// MARK: - W9.8 — ApprovalModalView (PausedForApproval surface)
//
// SwiftUI counterpart to the existing NSAlert-based
// `ChatCoordinator.promptUserForToolApproval(...)` flow. Used when:
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

    @ObservationIgnored private var continuation: CheckedContinuation<ChatApprovalResolution, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.epistemos", category: "ChatApprovalQueue")

    public init() {}

    public func enqueue(
        sessionId: String,
        toolName: String,
        argsJSON: String,
        deadline: Date,
        summary: String?,
        authorityCategoryLabel: String?
    ) async -> ChatApprovalResolution {
        if pendingApproval != nil {
            log.error("denying overlapping approval request tool=\(toolName, privacy: .public)")
            return .deny
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            pendingApproval = ApprovalModalView.PendingApproval(
                sessionId: sessionId,
                toolName: toolName,
                argsJSON: argsJSON,
                deadline: deadline,
                summary: summary,
                authorityCategoryLabel: authorityCategoryLabel
            )
        }
    }

    public func resolve(
        _ approval: ApprovalModalView.PendingApproval,
        decision: ApprovalModalView.Decision
    ) {
        guard pendingApproval?.id == approval.id, let continuation else { return }

        self.continuation = nil
        pendingApproval = nil
        continuation.resume(returning: resolution(for: decision))
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
