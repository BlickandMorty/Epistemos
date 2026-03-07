import Foundation

// MARK: - GraphNodeType
// 7 semantic categories for knowledge graph nodes.
// Reduced from 13: Idea absorbs BrainDump/Insight, Source absorbs Paper/Book/Thinker, Tag absorbs Concept.

nonisolated enum GraphNodeType: String, Codable, Sendable, CaseIterable {
    case note
    case chat
    case idea
    case source
    case folder
    case quote
    case tag
    case block
    // Agent system node types (Phase 7)
    case agent
    case codeFile
    case codeFolder
    case draft
    case searchResult

    /// Node types visible in the graph UI (excludes block — blocks are internal structure).
    static let visibleCases: [GraphNodeType] = allCases.filter { $0 != .block }

    /// Migration from legacy 13-type system.
    /// Existing SwiftData records store raw strings; this maps them to the new 7 types.
    init(legacy rawValue: String) {
        switch rawValue {
        case "brainDump", "insight":
            self = .idea
        case "paper", "book", "thinker":
            self = .source
        case "concept":
            self = .tag
        default:
            self = GraphNodeType(rawValue: rawValue) ?? .note
        }
    }

    /// Human-readable display name for the graph UI.
    var displayName: String {
        switch self {
        case .note:   return "Note"
        case .chat:   return "Chat"
        case .idea:   return "Idea"
        case .source: return "Source"
        case .folder: return "Folder"
        case .quote:  return "Quote"
        case .tag:    return "Tag"
        case .block:        return "Block"
        case .agent:        return "Agent"
        case .codeFile:     return "Code File"
        case .codeFolder:   return "Code Folder"
        case .draft:        return "Draft"
        case .searchResult: return "Search Result"
        }
    }

    /// SF Symbol name for node rendering.
    var icon: String {
        switch self {
        case .note:         return "doc.text"
        case .chat:         return "bubble.left"
        case .idea:         return "lightbulb"
        case .source:       return "link"
        case .folder:       return "folder"
        case .quote:        return "text.quote"
        case .tag:          return "number"
        case .block:        return "text.line.first.and.arrowtriangle.forward"
        case .agent:        return "person.crop.circle"
        case .codeFile:     return "doc.badge.gearshape"
        case .codeFolder:   return "folder.badge.gearshape"
        case .draft:        return "pencil.and.outline"
        case .searchResult: return "magnifyingglass"
        }
    }

    /// Index matching Rust NodeType enum for FFI.
    var rustIndex: UInt8 {
        switch self {
        case .note:         return 0
        case .chat:         return 1
        case .idea:         return 2
        case .source:       return 3
        case .folder:       return 4
        case .quote:        return 5
        case .tag:          return 6
        case .block:        return 7
        case .agent:        return 8
        case .codeFile:     return 9
        case .codeFolder:   return 10
        case .draft:        return 11
        case .searchResult: return 12
        }
    }

    /// Parse from display name (case-insensitive).
    static func from(displayName: String) -> GraphNodeType? {
        let lower = displayName.lowercased()
        return allCases.first { $0.displayName.lowercased() == lower || $0.rawValue.lowercased() == lower }
    }
}

// MARK: - GraphEdgeType
// 12 relationship types: 8 structural + 4 semantic.

nonisolated enum GraphEdgeType: String, Codable, Sendable {
    case reference
    case contains
    case tagged
    case mentions
    case cites
    case authored
    case related
    case quotes
    case supports      // Note A provides evidence for Note B
    case contradicts   // Note A contradicts claims in Note B
    case expands       // Note A expands on ideas in Note B
    case questions     // Note A raises questions about Note B
    // Agent system edge types (Phase 7)
    case agentWorkedOn   // Agent -> Node it modified/created
    case agentAttachedTo // Agent -> Node it's currently working on
    case bridgedTo       // Main graph node -> Agent territory node
    case derivedFrom     // Agent-created node -> source that inspired it

    /// Migration from legacy 23-type system.
    init(legacy rawValue: String) {
        switch rawValue {
        case "wikilink", "ideaLink", "referenced", "extractedFrom",
             "discoveredIn", "sharedIn", "referencedIn", "linksTo", "exploredIn":
            self = .reference
        case "livesIn", "belongsTo":
            self = .contains
        case "tagged":
            self = .tagged
        case "mentionedIn", "discussedIn", "appearsIn":
            self = .mentions
        case "backedBy", "citedIn":
            self = .cites
        case "authored", "attributedTo":
            self = .authored
        case "semanticLink", "relatesTo", "relatedConcept":
            self = .related
        case "said":
            self = .quotes
        default:
            self = GraphEdgeType(rawValue: rawValue) ?? .reference
        }
    }

    /// Index matching Rust EdgeType enum (0-11) for FFI.
    var rustIndex: UInt8 {
        switch self {
        case .reference:   return 0
        case .contains:    return 1
        case .tagged:      return 2
        case .mentions:    return 3
        case .cites:       return 4
        case .authored:    return 5
        case .related:     return 6
        case .quotes:      return 7
        case .supports:    return 8
        case .contradicts: return 9
        case .expands:     return 10
        case .questions:       return 11
        case .agentWorkedOn:   return 12
        case .agentAttachedTo: return 13
        case .bridgedTo:       return 14
        case .derivedFrom:     return 15
        }
    }
}

// MARK: - GraphNodeMetadata
// Optional metadata payload for graph nodes. Encoded as JSON in SDGraphNode.metadata.

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
