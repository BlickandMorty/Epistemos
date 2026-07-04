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

    static func openSettings() {
        emit(event: "june://open-settings", payloadJS: "null")
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

    private var sessions: [JuneSessionStore.Session] {
        JuneAgentSurfaceHolder.shared.bridge?.gateway.store.allSessions() ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a chat in the Agent room and it will appear here.")
                    )
                } else {
                    List(sessions, id: \.id) { session in
                        Button {
                            JuneAgentIntents.openSession(id: session.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .lineLimit(1)
                                if !session.preview.isEmpty {
                                    Text(session.preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Agent sessions")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("New session") {
                        JuneAgentIntents.newSession()
                        dismiss()
                    }
                }
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
