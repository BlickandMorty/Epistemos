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
// ## ClaimEvidence backends
//
// `EidosRetrievalMode.claimEvidence` is backed by EITHER:
//
//   - `agent_core::eidos::claim_evidence::InMemoryClaimEvidence` (toy /
//     fixture path), or
//   - `agent_core::eidos::ledger_backed_claim_evidence::LedgerBackedClaimEvidence`
//     (production wiring over the Rust ClaimLedger — closes W-49).
//
// Both backends emit byte-equal `source_id` wire format
// (`{evidence_doc}::claim::{claim_id}::{stance}`) so the Swift side does
// not need to know which backend produced a packet. The cross-backend
// byte-equality is asserted by
// `agent_core::eidos::hardening_tests::
//  in_memory_and_ledger_backed_claim_evidence_emit_byte_equal_source_ids`.
//
// Status: `implemented-not-wired` per AGENTS.md. The types are declared;
// the EidosBridge FFI that produces them lands under W-46. No Rust ↔ Swift
// FFI wiring in this file — that is the next iter's surface.

import Foundation

// MARK: - Identifier types

/// Opaque, Eidos-issued document identifier. Mirrors Rust `EidosDocumentId`.
nonisolated public struct EidosDocumentId: Codable, Hashable, Sendable {
    public let raw: String

    /// Returns nil for empty payloads — matches Rust's `IdError::EmptyPayload`.
    public init?(_ raw: String) {
        guard !raw.isEmpty else { return nil }
        self.raw = raw
    }

    nonisolated public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard !raw.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "EidosDocumentId payload cannot be empty"
            )
        }
        self.raw = raw
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}

/// Opaque, Eidos-issued chunk identifier — the **only** citable token.
nonisolated public struct EidosChunkId: Codable, Hashable, Sendable {
    public let raw: String

    public init?(_ raw: String) {
        guard !raw.isEmpty else { return nil }
        self.raw = raw
    }

    nonisolated public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard !raw.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "EidosChunkId payload cannot be empty"
            )
        }
        self.raw = raw
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}

/// Snapshot id pinning a retrieval to a specific corpus state.
nonisolated public struct EidosIndexManifestId: Codable, Hashable, Sendable {
    public let raw: String

    public init?(_ raw: String) {
        guard !raw.isEmpty else { return nil }
        self.raw = raw
    }

    nonisolated public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard !raw.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "EidosIndexManifestId payload cannot be empty"
            )
        }
        self.raw = raw
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}

// MARK: - Retrieval shape

/// The nine canonical retrieval modes. Mirrors Rust `EidosRetrievalMode`
/// (the seven canon modes plus Recency + ProvenanceVerified additions).
nonisolated public enum EidosRetrievalMode: String, Codable, Hashable, Sendable, CaseIterable {
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
nonisolated public enum EidosSourceKind: String, Codable, Hashable, Sendable, CaseIterable {
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
nonisolated public struct EidosSpan: Codable, Hashable, Sendable {
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
nonisolated public struct EidosScoreComponents: Codable, Hashable, Sendable {
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
nonisolated public struct EidosProvenance: Codable, Hashable, Sendable {
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
nonisolated public struct EidosHit: Codable, Hashable, Sendable {
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
nonisolated public struct EidosQuery: Codable, Hashable, Sendable {
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
nonisolated public struct EidosContextPacket: Codable, Hashable, Sendable {
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
nonisolated public struct EidosCitation: Codable, Hashable, Sendable {
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
nonisolated public struct EidosIndexManifest: Codable, Hashable, Sendable {
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
///
/// `Codable` is implemented manually to match Rust's external-tagged
/// enum wire shape (the serde default for enums):
///   - `{"FabricatedSourceId": "<chunk-id>"}`
///   - `{"ManifestMismatch": {"packet": "...", "citation": "..."}}`
///
/// Internal-tagging (`#[serde(tag = "...")]`) isn't an option on the
/// Rust side because tuple-newtype variants can't carry a tag inline;
/// the Swift side matches that constraint with this custom Codable.
nonisolated public enum EidosCitationError: Error, Hashable, Sendable {
    case fabricatedSourceId(EidosChunkId)
    case manifestMismatch(packet: EidosIndexManifestId, citation: EidosIndexManifestId)
}

nonisolated extension EidosCitationError: Codable {
    private struct ManifestMismatchPayload: Codable {
        let packet: EidosIndexManifestId
        let citation: EidosIndexManifestId
    }

    private enum WireKey: String, CodingKey {
        case fabricatedSourceId = "FabricatedSourceId"
        case manifestMismatch = "ManifestMismatch"
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: WireKey.self)
        if let chunk = try container.decodeIfPresent(EidosChunkId.self, forKey: .fabricatedSourceId) {
            self = .fabricatedSourceId(chunk)
            return
        }
        if let payload = try container.decodeIfPresent(
            ManifestMismatchPayload.self,
            forKey: .manifestMismatch
        ) {
            self = .manifestMismatch(packet: payload.packet, citation: payload.citation)
            return
        }
        throw DecodingError.dataCorruptedError(
            forKey: .fabricatedSourceId,
            in: container,
            debugDescription: "expected one of FabricatedSourceId or ManifestMismatch"
        )
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: WireKey.self)
        switch self {
        case .fabricatedSourceId(let chunk):
            try container.encode(chunk, forKey: .fabricatedSourceId)
        case .manifestMismatch(let packet, let citation):
            let payload = ManifestMismatchPayload(packet: packet, citation: citation)
            try container.encode(payload, forKey: .manifestMismatch)
        }
    }
}

/// One per-index entry inside an `EidosBatchCitationError`. Preserves the
/// original position of the rejected citation so the chat-layer rejection
/// UI can highlight the exact bad input.
///
/// `Codable` is a custom unkeyed 2-element array `[index, error]` to
/// match Rust's `(usize, CitationError)` tuple wire shape under
/// `serde_json::to_string`.
nonisolated public struct EidosIndexedCitationError: Hashable, Sendable, Codable {
    public let index: Int
    public let error: EidosCitationError

    public init(index: Int, error: EidosCitationError) {
        self.index = index
        self.error = error
    }

    nonisolated public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let index = try container.decode(Int.self)
        let error = try container.decode(EidosCitationError.self)
        self.init(index: index, error: error)
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(index)
        try container.encode(error)
    }
}

/// Batch rejection result — at least one citation in the input slice
/// failed validation. Tuple-based `Result.Failure` isn't possible in
/// Swift (Failure must conform to Error), so the per-index errors travel
/// inside this typed error.
///
/// `Codable` is implemented as a transparent passthrough of `errors` so
/// the wire shape matches Rust's `Vec<(usize, CitationError)>` exactly:
/// `[[index, citationError], ...]`.
nonisolated public struct EidosBatchCitationError: Error, Hashable, Sendable, Codable {
    public let errors: [EidosIndexedCitationError]

    public init(errors: [EidosIndexedCitationError]) {
        self.errors = errors
    }

    nonisolated public init(from decoder: Decoder) throws {
        let errors = try [EidosIndexedCitationError](from: decoder)
        self.init(errors: errors)
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        try errors.encode(to: encoder)
    }
}

/// Successful result from the named closed-citation validator harness.
/// Mirrors Rust `ClosedCitationValidation`.
nonisolated public struct EidosClosedCitationValidation: Codable, Hashable, Sendable {
    public let acceptedCount: Int

    public init(acceptedCount: Int) {
        self.acceptedCount = acceptedCount
    }

    enum CodingKeys: String, CodingKey {
        case acceptedCount = "accepted_count"
    }
}

/// Rejection result from the named closed-citation validator harness.
/// Mirrors Rust `ClosedCitationValidationError`.
nonisolated public struct EidosClosedCitationValidationError: Error, Codable, Hashable, Sendable {
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

    /// Named chat/bridge emit gate. Mirrors Rust
    /// `enforce_closed_citation_contract`: every citation must validate
    /// against this packet or the answer is rejected wholesale with
    /// per-index diagnostics.
    public func enforceClosedCitationContract(
        citations: [EidosCitation]
    ) -> Result<EidosClosedCitationValidation, EidosClosedCitationValidationError> {
        switch validate(citations: citations) {
        case .success:
            return .success(EidosClosedCitationValidation(acceptedCount: citations.count))
        case .failure(let batch):
            return .failure(EidosClosedCitationValidationError(errors: batch.errors))
        }
    }

    /// Citable source ids in deterministic hit order. The chat layer can
    /// use this to gate model output BEFORE asking for full validation.
    public var citableSourceIds: [EidosChunkId] {
        hits.map { $0.sourceId }
    }
}

// MARK: - F-Eidos-ClosedCitation falsifier outcome mirror

/// Swift mirror of Rust `FEidosClosedCitationWitness`
/// (`agent_core/src/eidos/falsifier.rs`). Successful witness emitted
/// when the falsifier verified every retriever × query × hit triple
/// without breaking the closed-citation contract.
///
/// The Rust side pins the wire shape via
/// `falsifier::tests::witness_decodes_canonical_pinned_json_bytes`.
/// The matching Swift Codable decode pin is in EidosParityTests.swift
/// (`falsifierWitnessDecodesRustWireShape`). The mirror's Swift field
/// names are camelCase; the wire field names below stay snake_case to
/// match Rust serde output byte-for-byte.
///
/// The Rust failure type `FalsifierFailure` is mirrored below as
/// `EidosFalsifierFailure` — a hand-rolled Codable that consumes the
/// exact `serde(tag = "variant")` internal-tag JSON bytes Rust
/// produces.
nonisolated public struct EidosFalsifierWitness: Codable, Hashable, Sendable {
    public let retrieversChecked: UInt32
    public let queriesPerRetriever: UInt32
    public let totalHitsValidated: UInt32
    public let fakeCitationRejections: UInt32

    public init(
        retrieversChecked: UInt32,
        queriesPerRetriever: UInt32,
        totalHitsValidated: UInt32,
        fakeCitationRejections: UInt32
    ) {
        self.retrieversChecked = retrieversChecked
        self.queriesPerRetriever = queriesPerRetriever
        self.totalHitsValidated = totalHitsValidated
        self.fakeCitationRejections = fakeCitationRejections
    }

    enum CodingKeys: String, CodingKey {
        case retrieversChecked = "retrievers_checked"
        case queriesPerRetriever = "queries_per_retriever"
        case totalHitsValidated = "total_hits_validated"
        case fakeCitationRejections = "fake_citation_rejections"
    }
}

/// Swift mirror of Rust `FalsifierFailure`
/// (`agent_core/src/eidos/falsifier.rs`). One variant per contract
/// violation surfaced by the F-Eidos-ClosedCitation falsifier. The
/// Rust enum uses `#[serde(tag = "variant")]`, an internal-tag wire
/// shape where the variant name lives as a sibling `"variant"` field
/// alongside the variant's payload fields. Swift Codable doesn't
/// auto-derive this for enums with heterogeneous associated values,
/// so the Codable conformance below is hand-rolled to match Rust's
/// byte output exactly.
///
/// The Rust side pins every variant's exact wire bytes via
/// `falsifier::tests::failure_serialize_pins_exact_bytes_for_every_variant`.
/// The matching Swift decode pins live in EidosParityTests.swift
/// (`falsifierFailureDecodesRustWireShape*`).
///
/// `HitConfidenceOutOfRange.confidence` is `Float` and round-trips
/// cleanly for finite values; NaN serializes to JSON `null` on the
/// Rust side (per serde_json convention) and decoding `null` into a
/// `Float` fails by design — same asymmetry as the Rust side
/// (`falsifier::tests::failure_hit_confidence_nan_serializes_to_null_and_decode_errors`).
nonisolated public enum EidosFalsifierFailure: Error, Hashable, Sendable {
    case packetManifestDriftsFromRetriever(
        retrieverMode: EidosRetrievalMode,
        retrieverManifest: EidosIndexManifestId,
        packetManifest: EidosIndexManifestId
    )
    case hitProvenanceManifestMismatch(
        retrieverMode: EidosRetrievalMode,
        sourceId: EidosChunkId,
        hitManifest: EidosIndexManifestId,
        packetManifest: EidosIndexManifestId
    )
    case hitProvenanceModeMismatch(
        retrieverMode: EidosRetrievalMode,
        sourceId: EidosChunkId,
        hitMode: EidosRetrievalMode
    )
    case legitimateCitationRejected(
        retrieverMode: EidosRetrievalMode,
        sourceId: EidosChunkId
    )
    case fakeCitationAccepted(retrieverMode: EidosRetrievalMode)
    case hitConfidenceOutOfRange(
        retrieverMode: EidosRetrievalMode,
        sourceId: EidosChunkId,
        confidence: Float
    )
    case hitSpanInvalid(
        retrieverMode: EidosRetrievalMode,
        sourceId: EidosChunkId,
        byteStart: UInt32,
        byteEnd: UInt32
    )
}

extension EidosFalsifierFailure: Codable {
    private enum WireKey: String, CodingKey {
        case variant
        case retrieverMode = "retriever_mode"
        case sourceId = "source_id"
        case retrieverManifest = "retriever_manifest"
        case packetManifest = "packet_manifest"
        case hitManifest = "hit_manifest"
        case hitMode = "hit_mode"
        case byteStart = "byte_start"
        case byteEnd = "byte_end"
        case confidence
    }

    private enum VariantTag: String {
        case packetManifestDriftsFromRetriever = "PacketManifestDriftsFromRetriever"
        case hitProvenanceManifestMismatch = "HitProvenanceManifestMismatch"
        case hitProvenanceModeMismatch = "HitProvenanceModeMismatch"
        case legitimateCitationRejected = "LegitimateCitationRejected"
        case fakeCitationAccepted = "FakeCitationAccepted"
        case hitConfidenceOutOfRange = "HitConfidenceOutOfRange"
        case hitSpanInvalid = "HitSpanInvalid"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: WireKey.self)
        let tag = try container.decode(String.self, forKey: .variant)
        guard let variant = VariantTag(rawValue: tag) else {
            throw DecodingError.dataCorruptedError(
                forKey: .variant,
                in: container,
                debugDescription: "unknown FalsifierFailure variant: \(tag)"
            )
        }
        switch variant {
        case .packetManifestDriftsFromRetriever:
            self = .packetManifestDriftsFromRetriever(
                retrieverMode: try container.decode(EidosRetrievalMode.self, forKey: .retrieverMode),
                retrieverManifest: try container.decode(EidosIndexManifestId.self, forKey: .retrieverManifest),
                packetManifest: try container.decode(EidosIndexManifestId.self, forKey: .packetManifest)
            )
        case .hitProvenanceManifestMismatch:
            self = .hitProvenanceManifestMismatch(
                retrieverMode: try container.decode(EidosRetrievalMode.self, forKey: .retrieverMode),
                sourceId: try container.decode(EidosChunkId.self, forKey: .sourceId),
                hitManifest: try container.decode(EidosIndexManifestId.self, forKey: .hitManifest),
                packetManifest: try container.decode(EidosIndexManifestId.self, forKey: .packetManifest)
            )
        case .hitProvenanceModeMismatch:
            self = .hitProvenanceModeMismatch(
                retrieverMode: try container.decode(EidosRetrievalMode.self, forKey: .retrieverMode),
                sourceId: try container.decode(EidosChunkId.self, forKey: .sourceId),
                hitMode: try container.decode(EidosRetrievalMode.self, forKey: .hitMode)
            )
        case .legitimateCitationRejected:
            self = .legitimateCitationRejected(
                retrieverMode: try container.decode(EidosRetrievalMode.self, forKey: .retrieverMode),
                sourceId: try container.decode(EidosChunkId.self, forKey: .sourceId)
            )
        case .fakeCitationAccepted:
            self = .fakeCitationAccepted(
                retrieverMode: try container.decode(EidosRetrievalMode.self, forKey: .retrieverMode)
            )
        case .hitConfidenceOutOfRange:
            self = .hitConfidenceOutOfRange(
                retrieverMode: try container.decode(EidosRetrievalMode.self, forKey: .retrieverMode),
                sourceId: try container.decode(EidosChunkId.self, forKey: .sourceId),
                confidence: try container.decode(Float.self, forKey: .confidence)
            )
        case .hitSpanInvalid:
            self = .hitSpanInvalid(
                retrieverMode: try container.decode(EidosRetrievalMode.self, forKey: .retrieverMode),
                sourceId: try container.decode(EidosChunkId.self, forKey: .sourceId),
                byteStart: try container.decode(UInt32.self, forKey: .byteStart),
                byteEnd: try container.decode(UInt32.self, forKey: .byteEnd)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: WireKey.self)
        switch self {
        case let .packetManifestDriftsFromRetriever(retrieverMode, retrieverManifest, packetManifest):
            try container.encode(VariantTag.packetManifestDriftsFromRetriever.rawValue, forKey: .variant)
            try container.encode(retrieverMode, forKey: .retrieverMode)
            try container.encode(retrieverManifest, forKey: .retrieverManifest)
            try container.encode(packetManifest, forKey: .packetManifest)
        case let .hitProvenanceManifestMismatch(retrieverMode, sourceId, hitManifest, packetManifest):
            try container.encode(VariantTag.hitProvenanceManifestMismatch.rawValue, forKey: .variant)
            try container.encode(retrieverMode, forKey: .retrieverMode)
            try container.encode(sourceId, forKey: .sourceId)
            try container.encode(hitManifest, forKey: .hitManifest)
            try container.encode(packetManifest, forKey: .packetManifest)
        case let .hitProvenanceModeMismatch(retrieverMode, sourceId, hitMode):
            try container.encode(VariantTag.hitProvenanceModeMismatch.rawValue, forKey: .variant)
            try container.encode(retrieverMode, forKey: .retrieverMode)
            try container.encode(sourceId, forKey: .sourceId)
            try container.encode(hitMode, forKey: .hitMode)
        case let .legitimateCitationRejected(retrieverMode, sourceId):
            try container.encode(VariantTag.legitimateCitationRejected.rawValue, forKey: .variant)
            try container.encode(retrieverMode, forKey: .retrieverMode)
            try container.encode(sourceId, forKey: .sourceId)
        case let .fakeCitationAccepted(retrieverMode):
            try container.encode(VariantTag.fakeCitationAccepted.rawValue, forKey: .variant)
            try container.encode(retrieverMode, forKey: .retrieverMode)
        case let .hitConfidenceOutOfRange(retrieverMode, sourceId, confidence):
            try container.encode(VariantTag.hitConfidenceOutOfRange.rawValue, forKey: .variant)
            try container.encode(retrieverMode, forKey: .retrieverMode)
            try container.encode(sourceId, forKey: .sourceId)
            try container.encode(confidence, forKey: .confidence)
        case let .hitSpanInvalid(retrieverMode, sourceId, byteStart, byteEnd):
            try container.encode(VariantTag.hitSpanInvalid.rawValue, forKey: .variant)
            try container.encode(retrieverMode, forKey: .retrieverMode)
            try container.encode(sourceId, forKey: .sourceId)
            try container.encode(byteStart, forKey: .byteStart)
            try container.encode(byteEnd, forKey: .byteEnd)
        }
    }
}
