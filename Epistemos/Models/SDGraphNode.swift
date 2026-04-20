import Foundation
import OSLog
import SwiftData

// MARK: - SDGraphNode
// A node in the knowledge graph. Represents any entity (note, thinker, concept, etc.)
// stored as a SwiftData model with denormalized string FKs for graph queries.
//
// CloudKit-compatible: all properties optional or defaulted.

@Model
final class SDGraphNode {
    // MARK: - Indexes
    #Index<SDGraphNode>([\.id], [\.type], [\.sourceId], [\.label], [\.createdAt])

    // MARK: - Identity
    var id: String = UUID().uuidString
    var type: String = GraphNodeType.note.rawValue
    var label: String = ""

    // MARK: - Relations (denormalized)
    /// Optional reference back to the originating SDPage, SDChat, etc.
    var sourceId: String?

    // MARK: - Payload
    /// JSON-encoded GraphNodeMetadata. Use the `meta` computed property for typed access.
    var metadata: Data?

    // MARK: - Graph Properties
    var weight: Double = 1.0

    // MARK: - Timestamps
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// True for nodes created by the user via the graph UI (not derived from structural data).
    /// GraphBuilder.persist() preserves manual nodes during rebuilds.
    var isManual: Bool = false

    // MARK: - Init

    init(
        type: GraphNodeType,
        label: String,
        sourceId: String? = nil,
        weight: Double = 1.0
    ) {
        self.id = UUID().uuidString
        self.type = type.rawValue
        self.label = label
        self.sourceId = sourceId
        self.weight = weight
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed Accessors

    /// Typed node type derived from the stored raw value.
    /// Uses legacy migration so old records (e.g. "brainDump", "paper") map to new 7-type system.
    var nodeType: GraphNodeType {
        GraphNodeType(legacy: type)
    }

    /// Cached metadata — avoids JSON decode/encode on every access.
    /// Same pattern as SDPage.frontMatter.
    @Transient private var _metaCache: GraphNodeMetadata?

    private static let log = Logger(subsystem: "com.epistemos", category: "SDGraphNode")

    var meta: GraphNodeMetadata {
        get {
            if let cached = _metaCache { return cached }
            guard let data = metadata else { return GraphNodeMetadata() }
            do {
                let decoded = try JSONDecoder().decode(GraphNodeMetadata.self, from: data)
                _metaCache = decoded
                return decoded
            } catch {
                Self.log.error("SDGraphNode: metadata decode failed: \(error.localizedDescription, privacy: .public)")
                return GraphNodeMetadata()
            }
        }
        set {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                metadata = encoded
                _metaCache = newValue
            } catch {
                Self.log.error("SDGraphNode: metadata encode failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
