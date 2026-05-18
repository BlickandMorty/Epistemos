// Eidos.swift
//
// Swift mirror types for the Rust `agent_core::eidos` module.
//
// These are the **declared** types the Swift side will use to talk to the
// future EidosBridge FFI (see W-46 in the cross-terminal wiring backlog).
// They mirror `agent_core/src/eidos/types.rs` field-for-field so JSON
// produced by the Rust side deserializes byte-identical here, and vice
// versa. The Codable round-trip is the FFI contract for V0 until a
// dedicated bridge lands.
//
// **Closed-citation contract** is mirrored here as
// `EidosContextPacket.validate(citation:)` so the chat layer can gate
// answer emission entirely on the Swift side without a Rust round-trip.
//
// Status: `implemented-not-wired` per AGENTS.md. The types are declared;
// the EidosBridge FFI that produces them lands under W-46. No Rust ↔ Swift
// FFI wiring in this file — that is the next iter's surface.

import Foundation

// MARK: - Identifier types

/// Opaque, Eidos-issued document identifier. Mirrors Rust `EidosDocumentId`.
public struct EidosDocumentId: Codable, Hashable, Sendable {
    public let raw: String

    /// Returns nil for empty payloads — matches Rust's `IdError::EmptyPayload`.
    public init?(_ raw: String) {
        guard !raw.isEmpty else { return nil }
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard !raw.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "EidosDocumentId payload cannot be empty"
            )
        }
        self.raw = raw
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}

/// Opaque, Eidos-issued chunk identifier — the **only** citable token.
public struct EidosChunkId: Codable, Hashable, Sendable {
    public let raw: String

    public init?(_ raw: String) {
        guard !raw.isEmpty else { return nil }
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard !raw.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "EidosChunkId payload cannot be empty"
            )
        }
        self.raw = raw
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}

/// Snapshot id pinning a retrieval to a specific corpus state.
public struct EidosIndexManifestId: Codable, Hashable, Sendable {
    public let raw: String

    public init?(_ raw: String) {
        guard !raw.isEmpty else { return nil }
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard !raw.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "EidosIndexManifestId payload cannot be empty"
            )
        }
        self.raw = raw
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}

// MARK: - Retrieval shape

/// The nine canonical retrieval modes. Mirrors Rust `EidosRetrievalMode`
/// (the seven canon modes plus Recency + ProvenanceVerified additions).
public enum EidosRetrievalMode: String, Codable, Hashable, Sendable, CaseIterable {
    case lexical = "Lexical"
    case semantic = "Semantic"
    case hybrid = "Hybrid"
    case codeSymbol = "CodeSymbol"
    case claimEvidence = "ClaimEvidence"
    case graphNeighborhood = "GraphNeighborhood"
    case rawArchive = "RawArchive"
    case recency = "Recency"
    case provenanceVerified = "ProvenanceVerified"
}

/// Discriminator for the substrate kind a hit came from.
public enum EidosSourceKind: String, Codable, Hashable, Sendable, CaseIterable {
    case note = "Note"
    case epdoc = "Epdoc"
    case chat = "Chat"
    case code = "Code"
    case graph = "Graph"
    case shadow = "Shadow"
    case exactPath = "ExactPath"
    case rawArchive = "RawArchive"
}

/// Byte span within a document body. Optional on the hit.
public struct EidosSpan: Codable, Hashable, Sendable {
    public let byteStart: UInt32
    public let byteEnd: UInt32

    public init(byteStart: UInt32, byteEnd: UInt32) {
        self.byteStart = byteStart
        self.byteEnd = byteEnd
    }

    enum CodingKeys: String, CodingKey {
        case byteStart = "byte_start"
        case byteEnd = "byte_end"
    }
}

/// Per-component score breakdown. Diagnostic, not normalized weights.
public struct EidosScoreComponents: Codable, Hashable, Sendable {
    public let lexical: Float
    public let semantic: Float
    public let recency: Float
    public let graph: Float

    public init(lexical: Float = 0, semantic: Float = 0, recency: Float = 0, graph: Float = 0) {
        self.lexical = lexical
        self.semantic = semantic
        self.recency = recency
        self.graph = graph
    }
}

/// Retrieval provenance — which manifest, which mode, when retrieved.
public struct EidosProvenance: Codable, Hashable, Sendable {
    public let manifestId: EidosIndexManifestId
    public let mode: EidosRetrievalMode
    public let retrievedAtUnixMs: UInt64

    enum CodingKeys: String, CodingKey {
        case manifestId = "manifest_id"
        case mode
        case retrievedAtUnixMs = "retrieved_at_unix_ms"
    }
}

// MARK: - Hit + packet + citation

/// One retrieved chunk. The `sourceId` is the only citable token.
public struct EidosHit: Codable, Hashable, Sendable {
    public let sourceId: EidosChunkId
    public let documentId: EidosDocumentId
    public let kind: EidosSourceKind
    public let span: EidosSpan?
    public let confidence: Float
    public let score: EidosScoreComponents
    public let provenance: EidosProvenance

    enum CodingKeys: String, CodingKey {
        case sourceId = "source_id"
        case documentId = "document_id"
        case kind
        case span
        case confidence
        case score
        case provenance
    }
}

/// A query against an Eidos manifest. `queryVector` is consumed by Semantic
/// and Hybrid; ignored elsewhere.
public struct EidosQuery: Codable, Hashable, Sendable {
    public let text: String
    public let mode: EidosRetrievalMode
    public let topK: UInt16
    public let queryVector: [Float]?

    public init(text: String, mode: EidosRetrievalMode, topK: UInt16, queryVector: [Float]? = nil) {
        self.text = text
        self.mode = mode
        self.topK = topK
        self.queryVector = queryVector
    }

    enum CodingKeys: String, CodingKey {
        case text
        case mode
        case topK = "top_k"
        case queryVector = "query_vector"
    }
}

/// Sealed query → hits packet. The `hits[*].sourceId` set is the closed
/// citation universe for any answer that uses this packet.
public struct EidosContextPacket: Codable, Hashable, Sendable {
    public let query: EidosQuery
    public let manifestId: EidosIndexManifestId
    public let hits: [EidosHit]

    enum CodingKeys: String, CodingKey {
        case query
        case manifestId = "manifest_id"
        case hits
    }
}

/// A chat-layer reference back to one chunk in a packet.
public struct EidosCitation: Codable, Hashable, Sendable {
    public let sourceId: EidosChunkId
    public let manifestId: EidosIndexManifestId

    public init(sourceId: EidosChunkId, manifestId: EidosIndexManifestId) {
        self.sourceId = sourceId
        self.manifestId = manifestId
    }

    enum CodingKeys: String, CodingKey {
        case sourceId = "source_id"
        case manifestId = "manifest_id"
    }
}

/// Snapshot descriptor. Live Files binding lands under W-row backlog.
public struct EidosIndexManifest: Codable, Hashable, Sendable {
    public let id: EidosIndexManifestId
    public let createdAtUnixMs: UInt64
    public let corpusDigestHex: String
    public let liveFilesSnapshotId: String?

    public init(
        id: EidosIndexManifestId,
        createdAtUnixMs: UInt64,
        corpusDigestHex: String = "",
        liveFilesSnapshotId: String? = nil
    ) {
        self.id = id
        self.createdAtUnixMs = createdAtUnixMs
        self.corpusDigestHex = corpusDigestHex
        self.liveFilesSnapshotId = liveFilesSnapshotId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtUnixMs = "created_at_unix_ms"
        case corpusDigestHex = "corpus_digest_hex"
        case liveFilesSnapshotId = "live_files_snapshot_id"
    }
}

// MARK: - Closed-citation contract

/// Reasons a citation can be rejected. Mirrors Rust `CitationError`.
public enum EidosCitationError: Error, Hashable, Sendable {
    case fabricatedSourceId(EidosChunkId)
    case manifestMismatch(packet: EidosIndexManifestId, citation: EidosIndexManifestId)
}

/// One per-index entry inside an `EidosBatchCitationError`. Preserves the
/// original position of the rejected citation so the chat-layer rejection
/// UI can highlight the exact bad input.
public struct EidosIndexedCitationError: Hashable, Sendable {
    public let index: Int
    public let error: EidosCitationError

    public init(index: Int, error: EidosCitationError) {
        self.index = index
        self.error = error
    }
}

/// Batch rejection result — at least one citation in the input slice
/// failed validation. Tuple-based `Result.Failure` isn't possible in
/// Swift (Failure must conform to Error), so the per-index errors travel
/// inside this typed error.
public struct EidosBatchCitationError: Error, Hashable, Sendable {
    public let errors: [EidosIndexedCitationError]

    public init(errors: [EidosIndexedCitationError]) {
        self.errors = errors
    }
}

extension EidosContextPacket {
    /// Validate a single candidate citation. Returns success only if the
    /// citation's `sourceId` appears in `hits` AND its `manifestId` equals
    /// the packet's. Mirrors Rust `EidosContextPacket::validate_citation`
    /// truth table exactly.
    public func validate(citation: EidosCitation) -> Result<Void, EidosCitationError> {
        if citation.manifestId != manifestId {
            return .failure(.manifestMismatch(packet: manifestId, citation: citation.manifestId))
        }
        if hits.contains(where: { $0.sourceId == citation.sourceId }) {
            return .success(())
        }
        return .failure(.fabricatedSourceId(citation.sourceId))
    }

    /// Batch-validate a list of citations. Returns success only if EVERY
    /// citation passes; otherwise returns an `EidosBatchCitationError` with
    /// the per-index errors preserved so the rejection UI can show the
    /// complete picture. Mirrors Rust
    /// `EidosContextPacket::validate_citations`.
    public func validate(citations: [EidosCitation]) -> Result<Void, EidosBatchCitationError> {
        var errors: [EidosIndexedCitationError] = []
        for (idx, c) in citations.enumerated() {
            if case .failure(let err) = validate(citation: c) {
                errors.append(EidosIndexedCitationError(index: idx, error: err))
            }
        }
        return errors.isEmpty ? .success(()) : .failure(EidosBatchCitationError(errors: errors))
    }

    /// Citable source ids in deterministic hit order. The chat layer can
    /// use this to gate model output BEFORE asking for full validation.
    public var citableSourceIds: [EidosChunkId] {
        hits.map { $0.sourceId }
    }
}
