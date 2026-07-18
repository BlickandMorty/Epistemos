import Foundation

/// Filters durable records that belong to removed product surfaces.
nonisolated enum ProductCapabilityPolicy {
    static let hiddenGraphNodeTypes: Set<GraphNodeType> = [
        .chat,
        .run,
        .rawThought,
        .toolTrace,
    ]

    static func allowsGraphProjection(of type: GraphNodeType) -> Bool {
        !hiddenGraphNodeTypes.contains(type)
    }

    static func allowsGraphProjection(of record: GraphNodeRecord) -> Bool {
        allowsGraphProjection(of: record.type) && record.metadata.originChatId == nil
    }

    static func sanitizedQueryNodeTypes(_ types: [GraphNodeType]) -> [GraphNodeType] {
        types.filter(allowsGraphProjection)
    }

    static func sanitizedGraphProjection(_ types: Set<GraphNodeType>) -> Set<GraphNodeType> {
        Set(types.filter(allowsGraphProjection))
    }

    static func allowsContextualShadowPresentation(of kind: RecallContextKind) -> Bool {
        kind == .note
    }

    static func allowsWorkspaceContextPresentation(kind: String) -> Bool {
        kind != "recent_chat" && kind != "provenance_claim"
    }

    static func sanitizedAIOutput(_ output: String) -> String { "" }
    static var allowsChatPresentation: Bool { false }
    static var allowsAIOutputPresentation: Bool { false }
    static var allowsHTMLWorkspaceRegeneration: Bool { false }
}
