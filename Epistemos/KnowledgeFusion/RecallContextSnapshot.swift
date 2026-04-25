import Foundation

// MARK: - RecallContextSnapshot
// Patch 7 / AMBIENT_RECALL_WIRING_PLAN.md §5 — `Sendable` carrier for the
// composer-level snapshot that crosses the @MainActor → detached-task boundary
// before being handed to `InstantRecallService.searchAsync(...)`.
//
// Strict Sendable guarantees the snapshot can travel through `Task.detached`
// without picking up actor isolation. The struct intentionally captures only
// value types — no @Observable references, no SwiftData handles — so the
// contextual-shadows query path stays free of MainActor hops.

/// Whether the snapshot originated from a note composer or a chat composer.
/// V0 only forks UI presentation by kind; the search path is the same for both.
enum RecallContextKind: String, Sendable {
    case note
    case chat
}

/// Single composer-level snapshot. `text` is the current paragraph (or the
/// composer draft for chat). `originId` identifies the note or chat that the
/// user is composing into so the panel can avoid re-surfacing the source.
struct RecallContextSnapshot: Sendable, Hashable {
    let text: String
    let kind: RecallContextKind
    let originId: UUID

    init(text: String, kind: RecallContextKind, originId: UUID) {
        self.text = text
        self.kind = kind
        self.originId = originId
    }
}
