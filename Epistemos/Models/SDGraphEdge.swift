import Foundation
import SwiftData

// MARK: - SDGraphEdge
// A directed edge in the knowledge graph. Connects two SDGraphNode entities
// via denormalized string IDs for fast graph traversal queries.
//
// CloudKit-compatible: all properties optional or defaulted.

@Model
final class SDGraphEdge {
    // MARK: - Indexes
    #Index<SDGraphEdge>([\.id], [\.sourceNodeId], [\.targetNodeId], [\.type])

    // MARK: - Identity
    var id: String = UUID().uuidString

    // MARK: - Relations (denormalized)
    var sourceNodeId: String = ""
    var targetNodeId: String = ""

    // MARK: - Edge Properties
    var type: String = GraphEdgeType.reference.rawValue
    var weight: Double = 1.0

    // MARK: - Timestamps
    var createdAt: Date = Date.now

    /// True for edges created by the user via the graph UI.
    var isManual: Bool = false

    // MARK: - Init

    init(
        source: String,
        target: String,
        type: GraphEdgeType,
        weight: Double = 1.0
    ) {
        self.id = UUID().uuidString
        self.sourceNodeId = source
        self.targetNodeId = target
        self.type = type.rawValue
        self.weight = weight
        self.createdAt = .now
    }

    // MARK: - Computed Accessors

    /// Typed edge type derived from the stored raw value.
    /// Uses legacy migration so old records (e.g. "wikilink", "livesIn") map to new 8-type system.
    var edgeType: GraphEdgeType {
        GraphEdgeType(legacy: type)
    }
}
