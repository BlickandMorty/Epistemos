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

        public init(
            id: String = UUID().uuidString,
            sessionId: String,
            toolName: String,
            argsJSON: String,
            deadline: Date
        ) {
            self.id = id
            self.sessionId = sessionId
            self.toolName = toolName
            self.argsJSON = argsJSON
            self.deadline = deadline
        }
    }

    public enum Decision: Sendable {
        case approveOnce
        case approveAlways
        case deny
        case timedOut
    }

    private let approval: PendingApproval
    private let onResolve: (Decision) -> Void

    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let log = Logger(subsystem: "com.epistemos", category: "ApprovalModal")

    public init(
        approval: PendingApproval,
        onResolve: @escaping (Decision) -> Void
    ) {
        self.approval = approval
        self.onResolve = onResolve
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
                }
                Spacer()
                countdownRing
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

            HStack {
                Button("Deny") { resolve(.deny) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Allow Once") { resolve(.approveOnce) }
                Button("Always Allow") { resolve(.approveAlways) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, idealWidth: 540)
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
        let total = max(1, approval.deadline.timeIntervalSinceNow + remaining)
        return min(1, max(0, remaining / total))
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
