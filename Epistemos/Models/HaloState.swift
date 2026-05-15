import Foundation

// MARK: - Contextual Shadows / Halo — domain types
//
// Wave 8 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` — V1's defining
//  feature: "type a sentence, see a related thought appear, can't
//  remember a time before it worked that way").
//
// Per the V1 decision §"What Epistemos V1 *is*": Contextual Shadows
// surfaced through a Halo is the only differentiator. These types are
// the canonical Swift shape; mirror the Rust `ShadowHit` /
// `ShadowDocument` / `ShadowStats` in `epistemos-shadow/src/lib.rs`.

/// Domain partition for the index. The Wave 8 backend keeps two
/// independent usearch + tantivy indices so a query against `notes`
/// never sees `chats` results and vice versa.
nonisolated public enum ShadowDomain: String, Sendable, Codable, Hashable, CaseIterable {
    case notes = "note"
    case chats = "chat"

    /// Stable wire representation that crosses the FFI to the Rust
    /// `ShadowDocument.domain` field (`"note"` / `"chat"`).
    public var wireValue: String { rawValue }
}

/// One result returned by the Shadow engine — pre-truncated snippet
/// + score + provenance. Identifiable so SwiftUI lists can diff
/// efficiently across re-renders.
nonisolated public struct ShadowHit: Sendable, Identifiable, Hashable {
    public let id: String       // doc_id from Rust
    public let title: String
    public let snippet: String  // pre-truncated to ~160 chars by the engine
    public let score: Float
    public let domain: ShadowDomain
    /// Origin signal for the optional UI provenance pill (e.g.
    /// "lexical", "dense", "rrf", "in-memory-substring").
    public let source: String
    /// Sidecar metadata — which vault this hit originated from.
    /// Mirrors the Rust `ShadowHit.origin_vault_key` field and the
    /// `GraphNodeMetadata.originVaultKey` contract on the graph side.
    /// `nil` for hits the indexer didn't tag (lenient nil-passthrough
    /// so partial-rollout doesn't hide every hit when a vault filter
    /// is active).
    public let originVaultKey: String?

    public init(
        id: String,
        title: String,
        snippet: String,
        score: Float,
        domain: ShadowDomain,
        source: String = "",
        originVaultKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.score = score
        self.domain = domain
        self.source = source
        self.originVaultKey = originVaultKey
    }
}

/// Halo state machine — six states + an error fallback. Per the V1
/// decision §"The state machine", transitions are deterministic so
/// the UI can drive show/hide animations without race conditions.
nonisolated public enum HaloState: Sendable, Hashable {
    /// Editor empty / focus lost / app inactive. Halo invisible.
    case dormant
    /// Query is in flight (debounced). Halo invisible (no flicker).
    case sensing
    /// Search returned ≥ 1 result above the score threshold. Halo
    /// glyph appears; the count drives the badge label.
    case available(count: Int)
    /// User clicked the Halo glyph; panel is open showing results
    /// for the current domain.
    case open(domain: ShadowDomain)
    /// User opened a result for inline edit inside the panel.
    case editingNote(id: String)
    /// User opened a chat result for inline summarisation.
    case summarizingChat(id: String)
    /// Recoverable error (e.g. backend not yet ready). Halo shows a
    /// neutral "snapshot" glyph; the user can retry.
    case errorRecoverable(String)

    /// Whether the Halo overlay should be rendered in the editor's
    /// trailing-edge slot. The dormant + sensing states stay invisible
    /// to avoid flicker during typing.
    public var isVisible: Bool {
        switch self {
        case .dormant, .sensing: return false
        case .available, .open, .editingNote, .summarizingChat, .errorRecoverable:
            return true
        }
    }

    /// Whether the floating panel is open (the user clicked the glyph
    /// or drilled into a result).
    public var isPanelOpen: Bool {
        switch self {
        case .open, .editingNote, .summarizingChat: return true
        default: return false
        }
    }
}
