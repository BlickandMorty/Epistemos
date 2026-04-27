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
        /// Optional human-readable summary of the action (e.g. authority
        /// category + approval reason). When provided, rendered above the
        /// raw args JSON so the user sees the intent at a glance instead
        /// of squinting at the args payload.
        public let summary: String?
        /// Optional authority-category label rendered as a subtle pill so
        /// the user knows which permission group will be auto-allowed if
        /// they pick "Always Allow".
        public let authorityCategoryLabel: String?

        public init(
            id: String = UUID().uuidString,
            sessionId: String,
            toolName: String,
            argsJSON: String,
            deadline: Date,
            summary: String? = nil,
            authorityCategoryLabel: String? = nil
        ) {
            self.id = id
            self.sessionId = sessionId
            self.toolName = toolName
            self.argsJSON = argsJSON
            self.deadline = deadline
            self.summary = summary
            self.authorityCategoryLabel = authorityCategoryLabel
        }
    }

    public enum Decision: Sendable, Equatable {
        case approveOnce
        case approveAlways
        /// Apply the "Less Interruptions" preset to the authority store
        /// and approve this action (parity with the existing NSAlert path
        /// at `ChatCoordinator.promptUserForToolApproval`). The
        /// preset reduces re-prompts for normal categories so the user
        /// can move forward without flipping the per-category toggle by
        /// hand.
        case applyLessInterruptions
        case deny
        case timedOut
    }

    private let approval: PendingApproval
    private let onResolve: (Decision) -> Void

    @State private var now: Date = Date()
    @State private var didResolve = false
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let log = Logger(subsystem: "com.epistemos", category: "ApprovalModal")
    private let totalSeconds: TimeInterval

    public init(
        approval: PendingApproval,
        onResolve: @escaping (Decision) -> Void
    ) {
        self.approval = approval
        self.onResolve = onResolve
        // Snapshot the total countdown window once so the progress
        // ring's fraction stays stable as the deadline approaches.
        self.totalSeconds = max(1, approval.deadline.timeIntervalSinceNow)
    }

    public var body: some View {
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
                    if let label = approval.authorityCategoryLabel, !label.isEmpty {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Spacer()
                countdownRing
            }

            if let summary = approval.summary, !summary.isEmpty {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ScrollView {
                Text(approval.argsJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxHeight: 180)

            // 4-button layout matches the prior NSAlert parity:
            // Deny | Less Interruptions | Allow Once | Always Allow.
            HStack {
                Button("Deny") { resolve(.deny) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Less Interruptions") { resolve(.applyLessInterruptions) }
                    .help("Apply the Less Interruptions preset and allow this action.")
                Button("Allow Once") { resolve(.approveOnce) }
                Button("Always Allow") { resolve(.approveAlways) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 580)
        .onReceive(timer) { tick in
            now = tick
            if remaining <= 0 {
                resolve(.timedOut)
            }
        }
    }

    private var remaining: TimeInterval {
        max(0, approval.deadline.timeIntervalSince(now))
    }

    private var fractionRemaining: Double {
        min(1, max(0, remaining / totalSeconds))
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 3)
            Circle()
                .trim(from: 0, to: fractionRemaining)
                .stroke(remaining < 5 ? Color.red : Color.accentColor, style: .init(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: fractionRemaining)
            Text("\(Int(remaining))s")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(width: 36, height: 36)
    }

    private func resolve(_ decision: Decision) {
        // Guard against double-resolution: the timer can race the
        // user clicking a button right at the deadline. We must
        // never call onResolve more than once or the bridge layer
        // panics on a duplicate continuation resume.
        guard !didResolve else { return }
        didResolve = true
        log.info("approval resolved tool=\(approval.toolName, privacy: .public) decision=\(String(describing: decision), privacy: .public)")
        onResolve(decision)
    }
}

#if DEBUG
#Preview("Approval modal") {
    ApprovalModalView(
        approval: .init(
            sessionId: "s-123",
            toolName: "shell.execute",
            argsJSON: #"{"command":"rm -rf ~/Downloads/old-build"}"#,
            deadline: Date().addingTimeInterval(30)
        ),
        onResolve: { _ in }
    )
}
#endif
