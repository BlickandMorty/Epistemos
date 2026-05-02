import Foundation

// MARK: - MutationEnvelope (Swift mirror of agent_core::mutations)
//
// T+4.8 of `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`
// (cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §9 +
//  `docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` §3.5).
//
// Mirrors Rust types defined in:
//   - agent_core/src/mutations/envelope.rs — MutationEnvelope struct
//   - agent_core/src/mutations/types.rs    — MutationStatus, MutationActor,
//                                            Sensitivity, Reversibility,
//                                            BlockRef (named MutationBlockRef
//                                            here to avoid an implicit
//                                            collision with the local
//                                            BlockRef inside GraphBuilder.swift),
//                                            SourceOp, RelationChange
//
// Wire-format is byte-equal across Rust + Swift: lower-snake-case keys,
// internal-tag enums for MutationActor / SourceOp / RelationChange,
// optional fields skipped on the wire when nil. Cross-language parity
// is enforced by EpistemosTests/MutationEnvelopeParityTests.swift.
//
// T+4.8 ships these TYPES only. Replacing existing
// `NotificationCenter.default.post(name: .vaultChanged, ...)` style
// invalidation with envelope delivery is deferred to T+13 master
// hardening so this slice is purely additive.

// MARK: MutationStatus

nonisolated public enum MutationStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case committed
    case failed
    case reverted
}

// MARK: MutationActor

/// Internally-tagged enum: `{"kind": "user"}`, `{"kind": "agent", "run_id": "..."}`,
/// `{"kind": "system"}`. Matches the Rust serde representation exactly.
nonisolated public enum MutationActor: Codable, Sendable, Hashable {
    case user
    case agent(runID: String)
    case system

    private enum CodingKeys: String, CodingKey {
        case kind
        case runID = "run_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "user":
            self = .user
        case "agent":
            let runID = try c.decode(String.self, forKey: .runID)
            self = .agent(runID: runID)
        case "system":
            self = .system
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: c,
                debugDescription: "Unknown MutationActor kind: \(kind)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user:
            try c.encode("user", forKey: .kind)
        case .agent(let runID):
            try c.encode("agent", forKey: .kind)
            try c.encode(runID, forKey: .runID)
        case .system:
            try c.encode("system", forKey: .kind)
        }
    }
}

// MARK: Sensitivity / Reversibility

nonisolated public enum Sensitivity: String, Codable, Sendable, Hashable, CaseIterable {
    case `internal`
    case secret
    case `public`
}

nonisolated public enum Reversibility: String, Codable, Sendable, Hashable, CaseIterable {
    case reversible
    case irreversible
    case compensable
}

// MARK: MutationBlockRef
//
// Renamed from the Rust `BlockRef` to avoid an implicit collision with
// the function-local `struct BlockRef` inside GraphBuilder.swift:162.
// Wire-format is identical (`{"artifact_id": "...", "block_id": "..."}`).

nonisolated public struct MutationBlockRef: Codable, Sendable, Hashable {
    public let artifactID: String
    public let blockID: String

    public init(artifactID: String, blockID: String) {
        self.artifactID = artifactID
        self.blockID = blockID
    }

    enum CodingKeys: String, CodingKey {
        case artifactID = "artifact_id"
        case blockID = "block_id"
    }
}

// MARK: SourceOp

/// Internally-tagged: `{"kind": "graph_mutation"}`,
/// `{"kind": "artifact_create", "artifact_id": "...", "artifact_kind": "..."}`,
/// `{"kind": "artifact_update", "artifact_id": "..."}`,
/// `{"kind": "artifact_delete", "artifact_id": "..."}`,
/// `{"kind": "other", "label": "..."}`.
nonisolated public enum SourceOp: Codable, Sendable, Hashable {
    case graphMutation
    case artifactCreate(artifactID: String, artifactKind: String)
    case artifactUpdate(artifactID: String)
    case artifactDelete(artifactID: String)
    case other(label: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case artifactID = "artifact_id"
        case artifactKind = "artifact_kind"
        case label
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "graph_mutation":
            self = .graphMutation
        case "artifact_create":
            self = .artifactCreate(
                artifactID: try c.decode(String.self, forKey: .artifactID),
                artifactKind: try c.decode(String.self, forKey: .artifactKind)
            )
        case "artifact_update":
            self = .artifactUpdate(
                artifactID: try c.decode(String.self, forKey: .artifactID)
            )
        case "artifact_delete":
            self = .artifactDelete(
                artifactID: try c.decode(String.self, forKey: .artifactID)
            )
        case "other":
            self = .other(label: try c.decode(String.self, forKey: .label))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: c,
                debugDescription: "Unknown SourceOp kind: \(kind)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .graphMutation:
            try c.encode("graph_mutation", forKey: .kind)
        case .artifactCreate(let id, let kind):
            try c.encode("artifact_create", forKey: .kind)
            try c.encode(id, forKey: .artifactID)
            try c.encode(kind, forKey: .artifactKind)
        case .artifactUpdate(let id):
            try c.encode("artifact_update", forKey: .kind)
            try c.encode(id, forKey: .artifactID)
        case .artifactDelete(let id):
            try c.encode("artifact_delete", forKey: .kind)
            try c.encode(id, forKey: .artifactID)
        case .other(let label):
            try c.encode("other", forKey: .kind)
            try c.encode(label, forKey: .label)
        }
    }
}

// MARK: RelationChange

/// Internally-tagged: `{"op": "added", ...}`, `{"op": "removed", ...}`,
/// `{"op": "updated", ...}`.
nonisolated public enum RelationChange: Codable, Sendable, Hashable {
    case added(fromID: String, toID: String, label: String)
    case removed(fromID: String, toID: String, label: String)
    case updated(fromID: String, toID: String, oldLabel: String, newLabel: String)

    private enum CodingKeys: String, CodingKey {
        case op
        case fromID = "from_id"
        case toID = "to_id"
        case label
        case oldLabel = "old_label"
        case newLabel = "new_label"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let op = try c.decode(String.self, forKey: .op)
        let fromID = try c.decode(String.self, forKey: .fromID)
        let toID = try c.decode(String.self, forKey: .toID)
        switch op {
        case "added":
            self = .added(
                fromID: fromID,
                toID: toID,
                label: try c.decode(String.self, forKey: .label)
            )
        case "removed":
            self = .removed(
                fromID: fromID,
                toID: toID,
                label: try c.decode(String.self, forKey: .label)
            )
        case "updated":
            self = .updated(
                fromID: fromID,
                toID: toID,
                oldLabel: try c.decode(String.self, forKey: .oldLabel),
                newLabel: try c.decode(String.self, forKey: .newLabel)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .op,
                in: c,
                debugDescription: "Unknown RelationChange op: \(op)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .added(let from, let to, let label):
            try c.encode("added", forKey: .op)
            try c.encode(from, forKey: .fromID)
            try c.encode(to, forKey: .toID)
            try c.encode(label, forKey: .label)
        case .removed(let from, let to, let label):
            try c.encode("removed", forKey: .op)
            try c.encode(from, forKey: .fromID)
            try c.encode(to, forKey: .toID)
            try c.encode(label, forKey: .label)
        case .updated(let from, let to, let oldLabel, let newLabel):
            try c.encode("updated", forKey: .op)
            try c.encode(from, forKey: .fromID)
            try c.encode(to, forKey: .toID)
            try c.encode(oldLabel, forKey: .oldLabel)
            try c.encode(newLabel, forKey: .newLabel)
        }
    }
}

// MARK: MutationEnvelope

/// Mirrors `agent_core::mutations::MutationEnvelope`. Field order and
/// CodingKeys match the Rust serde wire format byte-for-byte. Optional
/// fields use Swift `Optional<T>` and skip serialization when nil
/// (matches Rust's `#[serde(skip_serializing_if = "Option::is_none")]`).
///
/// Note: this Swift type uses `EpdocArtifactRef` for `touched_artifacts`
/// — it's the existing application-level mirror of the Rust
/// `agent_core::artifacts::ArtifactRef`. JSON wire format is identical
/// across both Swift names (Rust serializes `ArtifactRef`, Swift
/// decodes into `EpdocArtifactRef`; field set and snake_case keys match).
nonisolated public struct MutationEnvelope: Codable, Sendable, Hashable {
    // §3.5 four-layer event hierarchy contract.
    public let mutationID: String
    public let runID: String?
    public let sequence: UInt64
    public let causedByEventID: String?
    public let actor: MutationActor
    public let approvalID: String?
    public let status: MutationStatus
    public let createdAtMs: Int64
    public let committedAtMs: Int64?
    public let op: SourceOp
    public let sensitivity: Sensitivity
    public let reversibility: Reversibility
    public let integrityHash: String
    public let schemaVersion: UInt32

    // Implementation-plan §9 query-fingerprint matching addendum.
    public let touchedArtifacts: [EpdocArtifactRef]
    public let touchedBlocks: [MutationBlockRef]
    public let relationChanges: [RelationChange]
    public let affectsSummary: Bool
    public let affectsOutline: Bool
    public let affectsBacklinks: Bool
    public let affectsSearchProjection: Bool
    public let affectsGraph: Bool
    public let affectsBody: Bool

    public static let currentSchemaVersion: UInt32 = 1

    public init(
        mutationID: String,
        runID: String? = nil,
        sequence: UInt64,
        causedByEventID: String? = nil,
        actor: MutationActor,
        approvalID: String? = nil,
        status: MutationStatus,
        createdAtMs: Int64,
        committedAtMs: Int64? = nil,
        op: SourceOp,
        sensitivity: Sensitivity,
        reversibility: Reversibility,
        integrityHash: String,
        schemaVersion: UInt32 = currentSchemaVersion,
        touchedArtifacts: [EpdocArtifactRef] = [],
        touchedBlocks: [MutationBlockRef] = [],
        relationChanges: [RelationChange] = [],
        affectsSummary: Bool = false,
        affectsOutline: Bool = false,
        affectsBacklinks: Bool = false,
        affectsSearchProjection: Bool = false,
        affectsGraph: Bool = false,
        affectsBody: Bool = false
    ) {
        self.mutationID = mutationID
        self.runID = runID
        self.sequence = sequence
        self.causedByEventID = causedByEventID
        self.actor = actor
        self.approvalID = approvalID
        self.status = status
        self.createdAtMs = createdAtMs
        self.committedAtMs = committedAtMs
        self.op = op
        self.sensitivity = sensitivity
        self.reversibility = reversibility
        self.integrityHash = integrityHash
        self.schemaVersion = schemaVersion
        self.touchedArtifacts = touchedArtifacts
        self.touchedBlocks = touchedBlocks
        self.relationChanges = relationChanges
        self.affectsSummary = affectsSummary
        self.affectsOutline = affectsOutline
        self.affectsBacklinks = affectsBacklinks
        self.affectsSearchProjection = affectsSearchProjection
        self.affectsGraph = affectsGraph
        self.affectsBody = affectsBody
    }

    /// True iff any `affects_*` flag is set. Matches the Rust
    /// `MutationEnvelope::affects_anything()` helper.
    public var affectsAnything: Bool {
        affectsSummary
            || affectsOutline
            || affectsBacklinks
            || affectsSearchProjection
            || affectsGraph
            || affectsBody
    }

    enum CodingKeys: String, CodingKey {
        case mutationID = "mutation_id"
        case runID = "run_id"
        case sequence
        case causedByEventID = "caused_by_event_id"
        case actor
        case approvalID = "approval_id"
        case status
        case createdAtMs = "created_at_ms"
        case committedAtMs = "committed_at_ms"
        case op
        case sensitivity
        case reversibility
        case integrityHash = "integrity_hash"
        case schemaVersion = "schema_version"
        case touchedArtifacts = "touched_artifacts"
        case touchedBlocks = "touched_blocks"
        case relationChanges = "relation_changes"
        case affectsSummary = "affects_summary"
        case affectsOutline = "affects_outline"
        case affectsBacklinks = "affects_backlinks"
        case affectsSearchProjection = "affects_search_projection"
        case affectsGraph = "affects_graph"
        case affectsBody = "affects_body"
    }
}

// MARK: DurableGraphEvent

/// Durable graph-projection event derived from committed mutation envelopes.
///
/// `GraphEvent` is already the 64-byte substrate-rt ring event used by
/// `EventDrain.swift`; this model owns the persisted graph mutation stream.
nonisolated public enum DurableGraphEventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case graphMutation = "graph_mutation"
    case nodeCreated = "node_created"
    case nodeUpdated = "node_updated"
    case nodeDeleted = "node_deleted"
    case edgeCreated = "edge_created"
    case edgeUpdated = "edge_updated"
    case edgeDeleted = "edge_deleted"
}

nonisolated public struct DurableGraphEventRelation: Codable, Sendable, Hashable {
    public let fromID: String
    public let toID: String
    public let label: String
    public let oldLabel: String?
    public let newLabel: String?

    public init(
        fromID: String,
        toID: String,
        label: String,
        oldLabel: String? = nil,
        newLabel: String? = nil
    ) {
        self.fromID = fromID
        self.toID = toID
        self.label = label
        self.oldLabel = oldLabel
        self.newLabel = newLabel
    }

    private enum CodingKeys: String, CodingKey {
        case fromID = "from_id"
        case toID = "to_id"
        case label
        case oldLabel = "old_label"
        case newLabel = "new_label"
    }
}

nonisolated public struct DurableGraphEvent: Codable, Sendable, Hashable {
    public static let currentSchemaVersion: UInt32 = 1

    public let eventID: String
    public let mutationID: String
    public let runID: String?
    public let traceID: String?
    public let sequence: UInt64
    public let kind: DurableGraphEventKind
    public let entityID: String?
    public let entityKind: String?
    public let occurredAtMs: Int64
    public let relation: DurableGraphEventRelation?
    public let metadata: [String: String]
    public let schemaVersion: UInt32

    public init(
        eventID: String,
        mutationID: String,
        runID: String? = nil,
        traceID: String? = nil,
        sequence: UInt64,
        kind: DurableGraphEventKind,
        entityID: String? = nil,
        entityKind: String? = nil,
        occurredAtMs: Int64,
        relation: DurableGraphEventRelation? = nil,
        metadata: [String: String] = [:],
        schemaVersion: UInt32 = currentSchemaVersion
    ) {
        self.eventID = eventID
        self.mutationID = mutationID
        self.runID = runID
        self.traceID = traceID
        self.sequence = sequence
        self.kind = kind
        self.entityID = entityID
        self.entityKind = entityKind
        self.occurredAtMs = occurredAtMs
        self.relation = relation
        self.metadata = metadata
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case mutationID = "mutation_id"
        case runID = "run_id"
        case traceID = "trace_id"
        case sequence
        case kind
        case entityID = "entity_id"
        case entityKind = "entity_kind"
        case occurredAtMs = "occurred_at_ms"
        case relation
        case metadata
        case schemaVersion = "schema_version"
    }
}
