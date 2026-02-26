import Foundation

// MARK: - GraphNodeType
// Classifies knowledge graph nodes into semantic categories.
// Each case maps to a SF Symbol icon and a filter key for the graph UI.

nonisolated enum GraphNodeType: String, Codable, Sendable, CaseIterable {
    case note
    case folder
    case idea
    case brainDump
    case chat
    case insight
    case thinker
    case paper
    case book
    case source
    case concept
    case tag
    case quote

    /// Human-readable display name for the graph UI.
    var displayName: String {
        switch self {
        case .note:      return "Note"
        case .folder:    return "Folder"
        case .idea:      return "Idea"
        case .brainDump: return "Brain Dump"
        case .chat:      return "Chat"
        case .insight:   return "Insight"
        case .thinker:   return "Thinker"
        case .paper:     return "Paper"
        case .book:      return "Book"
        case .source:    return "Source"
        case .concept:   return "Concept"
        case .tag:       return "Tag"
        case .quote:     return "Quote"
        }
    }

    /// SF Symbol name for node rendering.
    var icon: String {
        switch self {
        case .note:      return "doc.text"
        case .folder:    return "folder"
        case .idea:      return "lightbulb"
        case .brainDump: return "brain"
        case .chat:      return "bubble.left"
        case .insight:   return "sparkle"
        case .thinker:   return "person.bust"
        case .paper:     return "doc.richtext"
        case .book:      return "book.closed"
        case .source:    return "link"
        case .concept:   return "tag"
        case .tag:       return "number"
        case .quote:     return "text.quote"
        }
    }

    /// Filter key for graph toolbar. 1-9 for primary types, 0 for secondary.
    var filterKey: Int {
        switch self {
        case .note:    return 1
        case .idea:    return 2
        case .paper:   return 3
        case .thinker: return 4
        case .chat:    return 5
        case .concept: return 6
        case .source:  return 7
        case .insight: return 8
        case .quote:   return 9
        case .folder, .brainDump, .book, .tag: return 0
        }
    }
}

// MARK: - GraphEdgeType
// Classifies relationships between knowledge graph nodes.

nonisolated enum GraphEdgeType: String, Codable, Sendable {
    case livesIn
    case wikilink
    case semanticLink
    case belongsTo
    case ideaLink
    case referenced
    case extractedFrom
    case relatesTo
    case backedBy
    case authored
    case mentionedIn
    case discussedIn
    case said
    case citedIn
    case discoveredIn
    case sharedIn
    case referencedIn
    case linksTo
    case appearsIn
    case attributedTo
    case relatedConcept
    case exploredIn
    case tagged
}

// MARK: - GraphNodeMetadata
// Optional metadata payload for graph nodes. Encoded as JSON in SDGraphNode.metadata.
// Defined here alongside the graph types for co-location;
// JSON encode/decode happens in SDGraphNode.meta computed property.

nonisolated struct GraphNodeMetadata: Codable, Sendable, Equatable {
    var evidenceGrade: String?
    var researchStage: Int?
    var url: String?
    var authors: [String]?
    var quoteText: String?
    var year: Int?
    var journal: String?
    var doi: String?
    var abstract: String?
    var clusterTheme: String?
    var originChatId: String?
    var originNoteId: String?
}
