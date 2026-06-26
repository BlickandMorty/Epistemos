import Foundation

// Mini-session ontology — the DATA FOUNDATION for the authority plan's "Mini Session Model For Work" (§109-163).
// A Work session is either the MAIN (root/tab) session that owns the workspace + OpenCode/OpenWork session
// identity, or a MINI session: a first-class CHILD with an explicit `parentSessionID` (NOT a cosmetic mini-chat).
// "Attached" vs "detached" is PRESENTATION only — it changes how a mini session is shown (inline compact pane vs
// floating MiniChat window) and NEVER its identity (so detach/reattach is a no-op on identity).
//
// This is a pure value type (Codable for later persistence, Sendable for cross-actor use). UI, persistence, and
// the OpenCode/OpenWork binding land in later increments; this fixes the ontology + invariants first.

nonisolated enum WorkSessionKind: String, Codable, Sendable, Hashable {
    case main
    case mini
}

/// Presentation of a MINI session (no effect for `.main`). Detach/reattach flips this without changing identity.
nonisolated enum WorkSessionPresentation: String, Codable, Sendable, Hashable {
    case attached   // inline compact pane/card/rail under the parent main session
    case detached   // floating MiniChat-style window
}

nonisolated struct WorkSession: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let kind: WorkSessionKind
    /// nil for `.main`; non-nil (and != id) for `.mini` — a mini session must reference a parent.
    let parentSessionID: String?
    /// Presentation for mini sessions; `.attached` by default. Ignored for `.main`.
    var presentation: WorkSessionPresentation
    /// The OpenWork/OpenCode workspace this session belongs to (a mini inherits its parent's).
    let workspaceID: String
    /// The OpenCode/OpenWork session identity this Work session drives, once bound (nil until created).
    var openCodeSessionID: String?
    var title: String?

    /// Invariants: main ⇒ no parent; mini ⇒ has a parent that is not itself.
    var isValid: Bool {
        switch kind {
        case .main: return parentSessionID == nil
        case .mini: return parentSessionID != nil && parentSessionID != id
        }
    }

    /// A MAIN (root/tab) session — owns the workspace + OpenCode identity.
    static func main(
        id: String, workspaceID: String, openCodeSessionID: String? = nil, title: String? = nil
    ) -> WorkSession {
        WorkSession(id: id, kind: .main, parentSessionID: nil, presentation: .attached,
                    workspaceID: workspaceID, openCodeSessionID: openCodeSessionID, title: normalizedTitle(title))
    }

    /// A MINI (child) session attached to `parent` — inherits the parent's workspace.
    static func mini(
        id: String, parent: WorkSession, presentation: WorkSessionPresentation = .attached,
        openCodeSessionID: String? = nil, title: String? = nil
    ) -> WorkSession {
        WorkSession(id: id, kind: .mini, parentSessionID: parent.id, presentation: presentation,
                    workspaceID: parent.workspaceID, openCodeSessionID: openCodeSessionID, title: normalizedTitle(title))
    }

    /// Compact titles for rails/recents and for the title sent to the engine: single-line, trimmed, bounded.
    static func normalizedTitle(_ raw: String?, limit: Int = 80) -> String? {
        guard let raw else { return nil }
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(max(1, limit)))
    }

    /// Detach/reattach a mini session — presentation only; identity (id/kind/parent/workspace) is unchanged.
    func presented(as presentation: WorkSessionPresentation) -> WorkSession {
        var copy = self
        copy.presentation = presentation
        return copy
    }
}
