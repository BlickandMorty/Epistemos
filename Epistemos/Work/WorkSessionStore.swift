import Foundation
import Observation

// Mini-session ontology — increment 3: the @Observable store the UI binds to. It wraps the pure
// `WorkSessionRegistry` (model + structural rules) and adds the one piece of UI state the registry shouldn't own:
// the ACTIVE (focused) session. The tabs / mini-rail / detach-window UI read `mainSessions` / `children(of:)` /
// `activeSession` and call `focus` / `upsert` / `remove` / `promote` / `setPresentation`. The native Work surface
// upserts live OpenGUI `sessions.list` recents through this store; OpenWork worker sessions use the same registry path
// when that fallback surface is active. @MainActor (drives SwiftUI); @Observable per house style.
@MainActor
@Observable
final class WorkSessionStore {
    private(set) var registry: WorkSessionRegistry
    /// The currently-focused session id (a main tab or a mini); nil when there are none.
    private(set) var activeSessionID: String?

    init(_ registry: WorkSessionRegistry = WorkSessionRegistry()) {
        self.registry = registry
        self.activeSessionID = registry.mainSessions.first?.id
    }

    // MARK: Reads (UI binds to these)
    var sessions: [WorkSession] { registry.sessions }
    var mainSessions: [WorkSession] { registry.mainSessions }
    var activeSession: WorkSession? { activeSessionID.flatMap { registry.session(id: $0) } }
    func children(of parentID: String) -> [WorkSession] { registry.children(of: parentID) }

    // MARK: Mutations (keep `activeSessionID` always valid or nil)

    /// Add/replace a session (dedup by id). Focuses it if nothing valid is focused yet.
    func upsert(_ session: WorkSession) {
        registry.upsert(session)
        guard registry.session(id: session.id) != nil else { return } // ignored as invalid
        if activeSessionID == nil || registry.session(id: activeSessionID!) == nil {
            activeSessionID = session.id
        }
    }

    /// Focus an existing session; no-op for unknown ids (so focus can never point at a ghost).
    func focus(id: String) {
        guard registry.session(id: id) != nil else { return }
        activeSessionID = id
    }

    /// Remove a session (MAIN cascades its minis). If the active session went away, fall back to a main tab (or nil).
    func remove(id: String) {
        registry.remove(id: id)
        if let active = activeSessionID, registry.session(id: active) == nil {
            activeSessionID = registry.mainSessions.first?.id
        }
    }

    /// Explicit mini→main promotion (keeps focus on it).
    func promote(id: String) {
        guard registry.session(id: id)?.kind == .mini else { return }
        registry.promote(id: id)
        if registry.session(id: id)?.kind == .main {
            activeSessionID = id
        }
    }

    /// Detach/reattach a mini (presentation only; identity + focus unchanged).
    func setPresentation(id: String, _ presentation: WorkSessionPresentation) {
        registry.setPresentation(id: id, presentation)
    }
}
