import Foundation

// Mini-session ontology — increment 2: the pure REGISTRY of `WorkSession`s (the data layer behind the future
// tabs/mini-rail/recents UI). Captures the authority plan's structural rules WITHOUT any UI/actor coupling, so it's
// fully unit-testable: upsert-dedup-by-id, children-of-parent, cascade-remove (no orphaned minis), explicit
// promote (a mini must never become a main tab implicitly), and detach/reattach (presentation only). A later
// increment wraps this in an `@Observable` store bound to the live SPA session identity.
nonisolated struct WorkSessionRegistry: Sendable, Equatable {
    /// Insertion-ordered: main sessions appear as tabs in order; minis follow under their parents.
    private(set) var sessions: [WorkSession]

    init(_ sessions: [WorkSession] = []) {
        self.sessions = []
        for session in sessions where session.kind == .main {
            upsert(session)
        }
        for session in sessions where session.kind == .mini {
            upsert(session)
        }
    }

    /// Insert or replace by id (dedup). Invalid sessions (broken parentage) are ignored — opening the same session
    /// from two surfaces converges on ONE entry rather than forking ghost state (the plan's dedup requirement).
    mutating func upsert(_ session: WorkSession) {
        guard session.isValid else { return }
        if session.kind == .mini, !hasMainParent(for: session) { return }
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            let existing = sessions[idx]
            guard existing.kind == session.kind else { return }
            if existing.kind == .mini {
                guard existing.parentSessionID == session.parentSessionID else { return }
            }
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
    }

    private func hasMainParent(for session: WorkSession) -> Bool {
        guard let parentID = session.parentSessionID else { return false }
        return sessions.contains { $0.id == parentID && $0.kind == .main }
    }

    func session(id: String) -> WorkSession? { sessions.first { $0.id == id } }

    /// Main (root/tab) sessions, in order.
    var mainSessions: [WorkSession] { sessions.filter { $0.kind == .main } }

    /// Mini sessions whose parent is `parentID`, in order.
    func children(of parentID: String) -> [WorkSession] {
        sessions.filter { $0.kind == .mini && $0.parentSessionID == parentID }
    }

    /// Remove a session. Removing a MAIN cascade-removes its mini children (no orphans); removing a mini removes
    /// only it.
    mutating func remove(id: String) {
        guard let target = session(id: id) else { return }
        if target.kind == .main {
            sessions.removeAll { $0.id == id || ($0.kind == .mini && $0.parentSessionID == id) }
        } else {
            sessions.removeAll { $0.id == id }
        }
    }

    /// EXPLICIT promotion of a mini to a main (root tab) — drops parentage. No-op for non-mini ids (a mini never
    /// becomes a main tab implicitly, per the plan).
    mutating func promote(id: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }), sessions[idx].kind == .mini else { return }
        let old = sessions[idx]
        sessions[idx] = WorkSession.main(
            id: old.id, workspaceID: old.workspaceID, openCodeSessionID: old.openCodeSessionID, title: old.title)
    }

    /// Detach/reattach a mini (presentation only; identity unchanged). No-op for unknown ids.
    mutating func setPresentation(id: String, _ presentation: WorkSessionPresentation) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx] = sessions[idx].presented(as: presentation)
    }
}
