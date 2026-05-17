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

    enum CodingKeys: String, CodingKey {
        case accepted
        case canonicalJson = "canonical_json"
        case canonicalVersion = "canonical_version"
        case documentHash = "document_hash"
        case witness
    }
}

/// Minimal Swift mirror of `TriFusionWitness` for FFI smoke tests and UI wiring.
nonisolated struct RustTriFusionWitness: Sendable, Equatable, Decodable {
    let beforeHash: String
    let afterHash: String
    let mutationKind: String
    let provenanceStatus: String
    let envelopeMutationId: String?
    let mutationEnvelopeId: String?

    enum CodingKeys: String, CodingKey {
        case beforeHash = "before_hash"
        case afterHash = "after_hash"
        case mutationKind = "mutation_kind"
        case provenanceStatus = "provenance_status"
        case envelopeMutationId = "envelope_mutation_id"
        case mutationEnvelopeId = "mutation_envelope_id"
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
}
