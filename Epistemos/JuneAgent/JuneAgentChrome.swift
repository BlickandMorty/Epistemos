#if EPISTEMOS_APP_STORE
import Foundation
import SwiftUI
import os

// MARK: - Intents (native chrome → June)

/// Drives the vendored June surface through its OWN menu-bar event contract
/// (src/lib/menu-bar.ts at pinned a626597) over the shim's in-page Tauri
/// event bus — intent events, never URL reloads (Plan 1-MAS §7). Zero fork
/// overlay: June installed these listeners for its Tauri menu bar; the shim's
/// local bus delivers them identically.
@MainActor
enum JuneAgentIntents {
    private static let log = Logger(subsystem: "com.epistemos", category: "JuneAgentIntents")

    static func newSession() {
        emit(event: "june:menu-bar:new-agent-session", payloadJS: "null")
    }

    static func openSession(id: String) {
        emit(event: "june:menu-bar:open-agent-session", payloadJS: JuneAgentBridge.jsStringLiteral(id))
    }

    /// Tells June a session was deleted from native chrome so its sidebar
    /// drops it. Unlike the menu-bar intents, `june:agent:delete-session`
    /// (agent-events.ts) is a raw window CustomEvent, so dispatch it directly
    /// rather than through the shim's Tauri event bus.
    static func deleteSession(id: String) {
        guard let bridge = JuneAgentSurfaceHolder.shared.bridge else { return }
        let idLiteral = JuneAgentBridge.jsStringLiteral(id)
        bridge.runJS?(
            "window.dispatchEvent(new CustomEvent('june:agent:delete-session', { detail: { sessionId: \(idLiteral) } }));"
        )
    }

    private static func emit(event: String, payloadJS: String) {
        guard let bridge = JuneAgentSurfaceHolder.shared.bridge else {
            log.warning("intent \(event, privacy: .public) dropped — surface not started")
            return
        }
        let eventLiteral = JuneAgentBridge.jsStringLiteral(event)
        bridge.runJS?(
            "window.__EPISTEMOS_TAURI_SHIM__ && window.__EPISTEMOS_TAURI_SHIM__.emit(\(eventLiteral), \(payloadJS));"
        )
    }
}

// MARK: - Activity (June → native chrome)

/// Live agent activity from June's `june:menu-bar:agent-state` emits
/// (forwarded by the shim in host mode). Feeds the mascot's "agent working"
/// presence (Plan 5 seam) and any native chrome badges.
@MainActor
@Observable
final class JuneAgentActivityModel {
    static let shared = JuneAgentActivityModel()

    private(set) var activeCount = 0
    private(set) var needsUserCount = 0
    private(set) var lastUpdated: Date?

    var agentIsWorking: Bool { activeCount > 0 }

    func apply(statePayload: [String: Any]) {
        activeCount = (statePayload["activeCount"] as? Int) ?? 0
        needsUserCount = (statePayload["needsUserCount"] as? Int) ?? 0
        lastUpdated = Date()
    }
}

// MARK: - All-chats sheet

/// Native all-chats list over the gateway's durable session store; selecting
/// a row drives June via the open-session intent (never a reload).
struct JuneAllChatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    // Confirm before an irreversible delete (drops the messages file, no undo).
    @State private var pendingDelete: JuneSessionStore.Session?

    /// The conversation June currently shows — marked in the list so the sheet
    /// orients the user like June's own sidebar (read once on present).
    private var currentSessionID: String? {
        JuneAgentSurfaceHolder.shared.bridge?.gateway.currentSessionID
    }

    private var sessions: [JuneSessionStore.Session] {
        let all = JuneAgentSurfaceHolder.shared.bridge?.gateway.store.allSessions() ?? []
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.preview.localizedCaseInsensitiveContains(query)
        }
    }

    private static let iso = ISO8601DateFormatter()
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    /// Deletes a session from native chrome: drops it from the durable store,
    /// cancels any in-flight turn (forgetSession), and tells June so its
    /// sidebar stays in sync. The @Observable store refreshes this sheet.
    private static func delete(_ session: JuneSessionStore.Session) {
        guard let gateway = JuneAgentSurfaceHolder.shared.bridge?.gateway else { return }
        gateway.forgetSession(session.id)
        gateway.store.deleteSession(id: session.id)
        JuneAgentIntents.deleteSession(id: session.id)
    }

    /// "now"/"2m"/"3h" trailing label — parity with June's own session
    /// sidebar so the native sheet and the web list read the same.
    private func relativeLabel(_ iso8601: String) -> String? {
        guard let date = Self.iso.date(from: iso8601) else { return nil }
        if Date().timeIntervalSince(date) < 45 { return "now" }
        return Self.relative.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        ContentUnavailableView(
                            "No chats yet",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Start a chat in June and it will appear here.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    List(sessions, id: \.id) { session in
                        Button {
                            JuneAgentIntents.openSession(id: session.id)
                            dismiss()
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .lineLimit(1)
                                        .fontWeight(session.id == currentSessionID ? .semibold : .regular)
                                        .foregroundStyle(session.id == currentSessionID ? Color.accentColor : Color.primary)
                                    if !session.preview.isEmpty {
                                        Text(session.preview)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 8)
                                if let label = relativeLabel(session.lastActive) {
                                    Text(label)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDelete = session
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("June chats")
            .searchable(text: $searchText, prompt: "Search chats")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("New Chat") {
                        JuneAgentIntents.newSession()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete this conversation?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { session in
                Button("Delete", role: .destructive) {
                    Self.delete(session)
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { session in
                Text("“\(session.title)” and its messages will be permanently deleted. This can't be undone.")
            }
        }
        .frame(minWidth: 380, minHeight: 420)
    }
}

// MARK: - Mascot seam

/// Named overlay seam for the companion mascot on the Agent room (Plan 5
/// wires the real mascot here; present while an agent works). Hit-testing
/// stays off so June receives every pointer event.
struct JuneAgentMascotOverlayHook: View {
    @State private var activity = JuneAgentActivityModel.shared

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .overlay(alignment: .bottomTrailing) {
                if activity.agentIsWorking {
                    // Placeholder presence indicator until Plan 5's mascot
                    // mounts here; deliberately subtle, never interactive.
                    Circle()
                        .fill(.tint.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
    }
}
#endif
