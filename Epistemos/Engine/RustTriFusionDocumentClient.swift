import Foundation
import os

#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

/// Swift mirror of a canonical Tri-Fusion document handle snapshot.
nonisolated struct RustTriFusionDocumentSnapshot: Sendable, Equatable {
    let canonicalJson: String
    let hashHex: String
    let canonicalVersion: String
}

/// Decoded shape returned by `TriFusionDocumentHandle.applyMutationJson`.
nonisolated struct RustTriFusionApplyResponse: Sendable, Equatable, Decodable {
    let accepted: Bool
    let canonicalJson: String
    let canonicalVersion: String
    let documentHash: String
    let witness: RustTriFusionWitness
    let provenance: RustTriFusionProvenanceVerification?

    enum CodingKeys: String, CodingKey {
        case accepted
        case canonicalJson = "canonical_json"
        case canonicalVersion = "canonical_version"
        case documentHash = "document_hash"
        case witness
        case provenance
    }
}

/// Minimal Swift mirror of `TriFusionWitness` for FFI smoke tests and UI wiring.
nonisolated struct RustTriFusionWitness: Sendable, Equatable, Decodable {
    let mutationId: String
    let beforeHash: String
    let afterHash: String
    let mutationKind: String
    let provenanceStatus: String
    let envelopeMutationId: String?
    let mutationEnvelopeId: String?
    let claimGraphNodeId: String?
    let cognitiveDagEdgeId: String?

    enum CodingKeys: String, CodingKey {
        case mutationId = "mutation_id"
        case beforeHash = "before_hash"
        case afterHash = "after_hash"
        case mutationKind = "mutation_kind"
        case provenanceStatus = "provenance_status"
        case envelopeMutationId = "envelope_mutation_id"
        case mutationEnvelopeId = "mutation_envelope_id"
        case claimGraphNodeId = "claim_graph_node_id"
        case cognitiveDagEdgeId = "cognitive_dag_edge_id"
    }
}

/// Decoded Tri-Fusion Cognitive DAG provenance verification from Rust.
nonisolated struct RustTriFusionProvenanceVerification: Sendable, Equatable, Decodable {
    let ids: RustTriFusionProvenanceIds
    let claimNodePresent: Bool
    let evidenceNodePresent: Bool
    let derivesFromEvidenceEdgePresent: Bool
    let status: String

    enum CodingKeys: String, CodingKey {
        case ids
        case claimNodePresent = "claim_node_present"
        case evidenceNodePresent = "evidence_node_present"
        case derivesFromEvidenceEdgePresent = "derives_from_evidence_edge_present"
        case status
    }
}

/// Deterministic DAG IDs computed for a Tri-Fusion mutation witness.
nonisolated struct RustTriFusionProvenanceIds: Sendable, Equatable, Decodable {
    let claimNodeId: String
    let evidenceNodeId: String
    let derivesFromEvidenceEdgeId: String

    enum CodingKeys: String, CodingKey {
        case claimNodeId = "claim_node_id"
        case evidenceNodeId = "evidence_node_id"
        case derivesFromEvidenceEdgeId = "derives_from_evidence_edge_id"
    }
}

/// Swift client for the Rust-owned opaque `TriFusionDocumentHandle`.
nonisolated enum RustTriFusionDocumentClient {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "RustTriFusionDocumentClient"
    )

    /// Create a Rust Tri-Fusion handle and return its canonical Swift snapshot.
    static func roundTrip(json: String) -> RustTriFusionDocumentSnapshot? {
        #if canImport(agent_coreFFI)
        do {
            let handle = try triFusionDocumentFromJson(inputJson: json)
            return RustTriFusionDocumentSnapshot(
                canonicalJson: handle.canonicalJson(),
                hashHex: handle.hashHex(),
                canonicalVersion: handle.canonicalVersion()
            )
        } catch {
            log.error("Tri-Fusion document FFI round trip failed (\(String(describing: error), privacy: .public))")
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Apply a mutation through the Rust handle and decode the witness response.
    static func applyMutation(json: String, mutationJson: String) -> RustTriFusionApplyResponse? {
        #if canImport(agent_coreFFI)
        do {
            let handle = try triFusionDocumentFromJson(inputJson: json)
            let output = try handle.applyMutationJson(mutationJson: mutationJson)
            return try JSONDecoder().decode(
                RustTriFusionApplyResponse.self,
                from: Data(output.utf8)
            )
        } catch {
            log.error("Tri-Fusion mutation FFI round trip failed (\(String(describing: error), privacy: .public))")
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Apply a mutation and commit its provenance into the Rust ClaimGraph and Cognitive DAG.
    static func applyMutationWithProvenance(
        json: String,
        mutationJson: String,
        createdAtMs: Int64
    ) -> RustTriFusionApplyResponse? {
        #if canImport(agent_coreFFI)
        do {
            let handle = try triFusionDocumentFromJson(inputJson: json)
            let output = try handle.applyMutationWithProvenanceJson(
                mutationJson: mutationJson,
                createdAtMs: createdAtMs
            )
            return try JSONDecoder().decode(
                RustTriFusionApplyResponse.self,
                from: Data(output.utf8)
            )
        } catch {
            log.error("Tri-Fusion provenance mutation FFI round trip failed (\(String(describing: error), privacy: .public))")
            return nil
        }
        #else
        return nil
        #endif
    }
}
