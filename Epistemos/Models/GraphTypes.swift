import Foundation

// MARK: - GraphNodeType
// 14 FFI graph node categories shared with the Rust renderer (rustIndex 0-13)
// plus app-level Raw Thoughts artifact types (run, rawThought, toolTrace) that
// are NEVER sent through the Rust FFI batch payloads. To keep the FFI contract
// tests stable (`FFIVersionSyncTests`/`GraphTypesTests` assert exactly 14
// contiguous indices), `allCases` returns only the FFI cases. The Raw
// Thoughts artifact types are accessible via `appLevelCases` and individual
// case references.

nonisolated enum GraphNodeType: String, Codable, Sendable, CaseIterable {
    // Structural types (original 8)
    case note
    case chat
    case idea
    case source
    case folder
    case quote
    case tag
    case block

    // Semantic entity types (Rowboat-inspired ontology)
    case person       // notes in People/ folder
    case project      // notes in Projects/ folder
    case topic        // notes in Topics/ folder
    case decision     // notes in Decisions/ folder
    case event        // notes in Events/ folder
    case resource     // notes in Resources/ folder

    // Raw Thoughts artifact types (Patch 5 / USER_WIRING_GAPS G2).
    // App-level only — not bridged to the Rust graph engine. Excluded from
    // `allCases` so the FFI contract (14 contiguous u8 indices) stays intact.
    case run          // one agent run, parent of its rawThoughts + toolTraces
    case rawThought   // a single thinking_delta / signature pair from a run
    case toolTrace    // a single tool_use + tool_result pair from a run

    // Wave 3.3 typed cognitive-artifact graph types (Extended Program Plan
    // §Wave 3.3, cross-ref COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md §2).
    // App-level only — these mirror the new `ArtifactKind` taxonomy
    // (Wave 3.2) and use the `mapsToArtifactKind()` bridge below for
    // typed routing. Excluded from FFI for the same reason as the Raw
    // Thoughts cases.
    //
    // Naming choice: existing `.note` and `.source` cases stay as the
    // legacy SwiftData-backed ontology entries. `.proseNote` is the
    // first-class Wave 3.3 case for ProseMirror JSON documents — when
    // the cognitive workspace overtakes the legacy notes surface
    // `.note` becomes a thin alias that delegates display + routing
    // to `.proseNote`.
    case proseNote    // ProseMirror JSON document (ArtifactKind.proseNote)
    case document     // .epdoc rich package (ArtifactKind.document)
    case code         // source code file (ArtifactKind.code)
    case output       // captured terminal/REPL/build output (ArtifactKind.output)

    /// FFI-bridged cases (rustIndex 0-13). Hand-implemented to preserve the
    /// strict 14-case contract enforced by `FFIVersionSyncTests`. The
    /// app-level cases (Raw Thoughts + Wave 3.3 typed artifacts) are
    /// intentionally excluded.
    static var allCases: [GraphNodeType] {
        [
            .note, .chat, .idea, .source, .folder, .quote, .tag, .block,
            .person, .project, .topic, .decision, .event, .resource,
        ]
    }

    /// App-level cases — Raw Thoughts (Patch 5) + Wave 3.3 typed
    /// cognitive-artifact types. Not sent through the FFI.
    static let appLevelCases: [GraphNodeType] = [
        .run, .rawThought, .toolTrace,
        .proseNote, .document, .code, .output,
    ]

    /// Node types visible in the Swift graph UI.
    ///
    /// `allCases` intentionally stays FFI-only, but app-level artifacts must
    /// remain visible once persisted into SwiftData; otherwise `.epdoc`,
    /// ProseMirror, raw-thought, and code/output nodes disappear behind the
    /// default type filter before the user ever sees them.
    static let visibleCases: [GraphNodeType] = allCases.filter { $0 != .block } + appLevelCases

    /// Semantic entity types — used for Knowledge Index grouping.
    static let entityTypes: [GraphNodeType] = [.person, .project, .topic, .decision, .event, .resource]

    /// Migration from legacy 13-type system.
    /// Existing SwiftData records store raw strings; this maps them to the new types.
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
        case .note:       return "Note"
        case .chat:       return "Chat"
        case .idea:       return "Idea"
        case .source:     return "Source"
        case .folder:     return "Folder"
        case .quote:      return "Quote"
        case .tag:        return "Tag"
        case .block:      return "Block"
        case .person:     return "Person"
        case .project:    return "Project"
        case .topic:      return "Topic"
        case .decision:   return "Decision"
        case .event:      return "Event"
        case .resource:   return "Resource"
        case .run:        return "Run"
        case .rawThought: return "Raw Thought"
        case .toolTrace:  return "Tool Trace"
        case .proseNote:  return "Prose Note"
        case .document:   return "Document"
        case .code:       return "Code"
        case .output:     return "Output"
        }
    }

    /// SF Symbol name for node rendering.
    var icon: String {
        switch self {
        case .note:       return "doc.text"
        case .chat:       return "bubble.left"
        case .idea:       return "lightbulb"
        case .source:     return "link"
        case .folder:     return "folder"
        case .quote:      return "text.quote"
        case .tag:        return "number"
        case .block:      return "text.line.first.and.arrowtriangle.forward"
        case .person:     return "person"
        case .project:    return "hammer"
        case .topic:      return "text.book.closed"
        case .decision:   return "checkmark.seal"
        case .event:      return "calendar"
        case .resource:   return "archivebox"
        case .run:        return "play.rectangle"
        case .rawThought: return "brain"
        case .toolTrace:  return "wrench.and.screwdriver"
        case .proseNote:  return "doc.richtext"
        case .document:   return "doc.append"
        case .code:       return "chevron.left.forwardslash.chevron.right"
        case .output:     return "terminal"
        }
    }

    /// Index matching Rust NodeType enum (0–13) for FFI.
    /// App-level Raw Thoughts cases (run/rawThought/toolTrace) are NOT bridged
    /// to the Rust graph engine; they fall back to `.note`'s index (0) defensively
    /// so a misuse cannot read off the end of the FFI enum table. They should
    /// never reach the FFI batch payload in practice.
    var rustIndex: UInt8 {
        switch self {
        case .note:       return 0
        case .chat:       return 1
        case .idea:       return 2
        case .source:     return 3
        case .folder:     return 4
        case .quote:      return 5
        case .tag:        return 6
        case .block:      return 7
        case .person:     return 8
        case .project:    return 9
        case .topic:      return 10
        case .decision:   return 11
        case .event:      return 12
        case .resource:   return 13
        case .run, .rawThought, .toolTrace,
             .proseNote, .document, .code, .output: return 0
        }
    }

    /// Infer entity type from vault folder path convention.
    /// e.g. "People/Alex.md" → .person, "Projects/MOHAWK/" → .project
    static func inferFromPath(_ path: String) -> GraphNodeType? {
        let components = path.split(separator: "/")
        guard let firstFolder = components.first?.lowercased() else { return nil }
        switch firstFolder {
        case "people":    return .person
        case "projects":  return .project
        case "topics":    return .topic
        case "decisions": return .decision
        case "events":    return .event
        case "resources": return .resource
        default:          return nil
        }
    }

    /// Parse from display name (case-insensitive).
    static func from(displayName: String) -> GraphNodeType? {
        let lower = displayName.lowercased()
        return allCases.first { $0.displayName.lowercased() == lower || $0.rawValue.lowercased() == lower }
    }

    // MARK: - ArtifactKind bridge (Wave 3.3)

    /// Map a GraphNodeType to its corresponding ArtifactKind, when one
    /// exists. Returns `nil` for legacy graph types that don't have a
    /// cognitive-artifact counterpart yet (idea / folder / quote / tag /
    /// block / person / project / topic / decision / event / resource /
    /// chat / toolTrace).
    ///
    /// Per `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §2:
    /// "the new code path uses `ArtifactKind` for typed routing".
    /// Use this on legacy node visits to upgrade them into the typed
    /// pipeline without rewriting the call sites.
    var mapsToArtifactKind: ArtifactKind? {
        switch self {
        case .proseNote, .note: return .proseNote
        case .document:         return .document
        case .source:           return .source
        case .code:             return .code
        case .output:           return .output
        case .run:              return .run
        case .rawThought:       return .rawThought
        case .chat,
             .idea, .folder, .quote, .tag, .block,
             .person, .project, .topic, .decision, .event, .resource,
             .toolTrace:
            return nil
        }
    }

    /// Reverse bridge: pick the canonical GraphNodeType for an
    /// ArtifactKind. Used when the typed-routing path needs to materialise
    /// a graph node from a freshly-decoded artifact header.
    init(from artifactKind: ArtifactKind) {
        switch artifactKind {
        case .proseNote:  self = .proseNote
        case .document:   self = .document
        case .rawThought: self = .rawThought
        case .source:     self = .source
        case .code:       self = .code
        case .run:        self = .run
        case .output:     self = .output
        }
    }
}

// MARK: - GraphEdgeType
// 12 FFI relationship types (8 structural + 4 semantic) shared with Rust,
// plus app-level Raw Thoughts edges that are NEVER sent through the FFI.
// `allCases` is hand-implemented to return only the FFI cases so the strict
// 12-case contract (`FFIVersionSyncTests`/`GraphTypesTests`) stays intact.

nonisolated enum GraphEdgeType: String, Codable, Sendable, CaseIterable {
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

    // Raw Thoughts artifact edges (Patch 5 / USER_WIRING_GAPS G2). App-level
    // only — not bridged to the Rust graph engine.
    case producedDuring   // artifact -> Run that produced it
    case generatedBy      // artifact -> Run that generated it (alias of producedDuring at the canon level)
    case derivedFrom      // Document -> Prose source it derived from
    case summarizes       // Run summary -> Run

    /// FFI-bridged cases (rustIndex 0-11). Hand-implemented to preserve the
    /// strict 12-case contract enforced by `FFIVersionSyncTests`.
    static var allCases: [GraphEdgeType] {
        [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions,
        ]
    }

    /// App-level Raw Thoughts artifact edges. Not sent through the FFI.
    static let appLevelCases: [GraphEdgeType] = [
        .producedDuring, .generatedBy, .derivedFrom, .summarizes,
    ]

    /// Edge types visible in the Swift graph UI. Keeps app-level artifact
    /// relationships enabled by default without changing the Rust FFI case set.
    static let visibleCases: [GraphEdgeType] = allCases + appLevelCases

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
    /// App-level Raw Thoughts edges fall back to `.reference`'s index (0)
    /// defensively; they should never reach the FFI batch payload in practice.
    var rustIndex: UInt8 {
        switch self {
        case .reference:      return 0
        case .contains:       return 1
        case .tagged:         return 2
        case .mentions:       return 3
        case .cites:          return 4
        case .authored:       return 5
        case .related:        return 6
        case .quotes:         return 7
        case .supports:       return 8
        case .contradicts:    return 9
        case .expands:        return 10
        case .questions:      return 11
        case .producedDuring,
             .generatedBy,
             .derivedFrom,
             .summarizes:     return 0
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
    /// Per-node vault provenance — set by the node creator to declare
    /// which model-profile vault this node belongs to. Used by
    /// `FilterEngine.selectedVaultFilter` to scope the visible graph
    /// to a single vault.
    ///
    /// **Lenient nil-passthrough contract (RCA-P1-010, 2026-05-13):**
    /// when the user has activated a vault filter but a node's
    /// `originVaultKey` is nil, the node passes through visibility. This
    /// avoids the footgun where a partially-rolled-out provenance field
    /// would make every vault filter hide every node. As future commits
    /// populate `originVaultKey` per node-creation site, the filter
    /// becomes progressively effective without breaking existing
    /// behavior.
    var originVaultKey: String?
}

// MARK: - Snapshots
// Sendable snapshots of graph state for background FFI payload generation.
// Prevents MainActor contention when building large (10K+) node batches.

nonisolated struct GraphFilterSnapshot: Sendable {
    let activeNodeTypes: Set<GraphNodeType>
    let activeEdgeTypes: Set<GraphEdgeType>
    let focusedNodeId: String?
    let focusedConnected: Set<String>?
    let searchMatchedNodeIds: Set<String>?
    /// Vault filter (RCA-P1-010 second pass, 2026-05-13). When set,
    /// nodes whose `metadata.originVaultKey` is non-nil AND mismatches
    /// this string are hidden. Lenient nil-passthrough — see field doc
    /// on `GraphNodeMetadata.originVaultKey`.
    let selectedVaultFilter: String?

    @MainActor
    init(filter: FilterEngine) {
        activeNodeTypes = filter.activeNodeTypes
        activeEdgeTypes = filter.activeEdgeTypes
        focusedNodeId = filter.focusedNodeId
        focusedConnected = filter.focusedConnected
        searchMatchedNodeIds = filter.searchMatchedNodeIds
        selectedVaultFilter = filter.selectedVaultFilter
    }

    func isNodeVisible(_ node: GraphNodeRecord) -> Bool {
        // 1. Type filter
        guard activeNodeTypes.contains(node.type) else { return false }

        // 2. Focus filter
        if let connected = focusedConnected {
            guard connected.contains(node.id) else { return false }
        }

        // 4. Vault filter — RCA-P1-010 second pass (2026-05-13).
        // Lenient nil-passthrough; see GraphNodeMetadata.originVaultKey
        // for the rationale. The snapshot mirrors FilterEngine's check
        // so background renderers and the main path return identical
        // visibility.
        if let vaultKey = selectedVaultFilter,
           let nodeVaultKey = node.metadata.originVaultKey,
           nodeVaultKey != vaultKey {
            return false
        }

        // 3. Search filter — RCA13 P1-010 fix: snapshot must
        // mirror FilterEngine and actually consult the matched
        // set, not just carry it.
        if let matched = searchMatchedNodeIds {
            guard matched.contains(node.id) else { return false }
        }

        return true
    }

    func isEdgeVisible(
        _ edge: GraphEdgeRecord,
        sourceVisible: Bool,
        targetVisible: Bool
    ) -> Bool {
        sourceVisible && targetVisible && activeEdgeTypes.contains(edge.type)
    }
}

nonisolated struct GraphStoreSnapshot: Sendable {
    let nodes: [String: GraphNodeRecord]
    let edges: [String: GraphEdgeRecord]
    /// Pre-computed link counts (degree) for each node ID.
    let linkCounts: [String: UInt32]

    func linkCount(for nodeId: String) -> UInt32 {
        linkCounts[nodeId] ?? 0
    }
}
