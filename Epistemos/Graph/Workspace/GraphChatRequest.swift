import Foundation

// MARK: - Graph Chat Request (Phase 7 Step 6)
//
// Typed payload describing the graph-local context that a user has asked
// the agent about via the "Ask Graph Chat" context menu (or, later, the
// dedicated Graph Chat surface).
//
// `GraphState.askGraphChat(nodeId:)` constructs one of these and posts it
// as the `.graphChatRequested` notification. A receiver — typically the
// Agent Command Center or a future `GraphChatState` — listens for the
// notification, prefills its composer with the node context, and opens
// its own UI. The graph workspace does NOT own a second control plane;
// this is purely an intent event, not a second chat session store.
//
// Keeping this as a plain `Sendable` struct (not `@Observable`) means it
// can cross the NotificationCenter sendable boundary without main-actor
// isolation gymnastics.

struct GraphChatRequest: Sendable, Equatable {
    /// The graph store node id the user right-clicked.
    let graphNodeId: String
    /// Backing SwiftData entity id (SDPage.id for notes, SDFolder.id for
    /// folders). May be nil if the graph node has no backing entity.
    let sourceId: String?
    /// Raw node type string (e.g. "note", "folder", "idea").
    let nodeType: String
    /// Human-readable label as stored on the graph node.
    let nodeLabel: String
    /// The graph workspace route at the moment the user asked. The
    /// receiver can surface this so the user knows which surface they
    /// were on when they clicked "Ask Graph Chat".
    let route: GraphWorkspaceRoute
}

extension Notification.Name {
    /// Posted when the user invokes "Ask Graph Chat" from a graph node's
    /// context menu. The notification's `object` is the posting
    /// `GraphState`; the typed `GraphChatRequest` is attached via
    /// `userInfo["request"]`.
    ///
    /// See `GraphChatRequest.fromNotification` for safe decoding.
    static let graphChatRequested = Notification.Name("epistemos.graphChatRequested")
}

extension GraphChatRequest {
    nonisolated static let userInfoKey = "request"

    /// Convenience for receivers that listen on `.graphChatRequested`.
    nonisolated static func fromNotification(_ notification: Notification) -> GraphChatRequest? {
        notification.userInfo?[Self.userInfoKey] as? GraphChatRequest
    }
}
