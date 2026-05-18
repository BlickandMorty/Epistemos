// EidosParityTests.swift
//
// Cross-language parity contract for the Eidos V0 FFI wire format.
//
// The constant `canonicalParityPacketJson` below MUST match the Rust
// constant `CANONICAL_PARITY_PACKET_JSON` in
// `agent_core/src/eidos/parity.rs`. The Rust test in that module asserts
// the canonical typed packet serializes to those exact bytes; the Swift
// test in this file asserts the SAME bytes decode to the expected typed
// values on the Swift side.
//
// Together the two tests pin the wire format from both sides. If either
// side legitimately needs to change the format, update BOTH constants and
// re-run both tests.

import Foundation
import Testing

@testable import Epistemos

/// Mirror of agent_core/src/eidos/parity.rs::CANONICAL_PARITY_PACKET_JSON.
private let canonicalParityPacketJson = """
{"query":{"text":"alpha","mode":"Lexical","top_k":4},\
"manifest_id":"parity-snap",\
"hits":[{"source_id":"doc-1::lex","document_id":"doc-1","kind":"Note",\
"span":{"byte_start":0,"byte_end":5},\
"confidence":0.5,\
"score":{"lexical":0.5,"semantic":0.0,"recency":0.0,"graph":0.0},\
"provenance":{"manifest_id":"parity-snap","mode":"Lexical","retrieved_at_unix_ms":1700000000000}}]}
"""

@Suite("Eidos cross-language parity (Rust ↔ Swift wire format)")
struct EidosParityTests {

    @Test("canonical packet JSON decodes byte-equal to typed values")
    func canonicalPacketDecodes() throws {
        let data = canonicalParityPacketJson.data(using: .utf8)!
        let packet = try JSONDecoder().decode(EidosContextPacket.self, from: data)

        // Manifest id.
        #expect(packet.manifestId.raw == "parity-snap")

        // Query.
        #expect(packet.query.text == "alpha")
        #expect(packet.query.mode == .lexical)
        #expect(packet.query.topK == 4)
        #expect(packet.query.queryVector == nil)

        // Single hit, fully populated.
        #expect(packet.hits.count == 1)
        let hit = packet.hits[0]
        #expect(hit.sourceId.raw == "doc-1::lex")
        #expect(hit.documentId.raw == "doc-1")
        #expect(hit.kind == .note)
        #expect(hit.confidence == 0.5)

        let span = try #require(hit.span)
        #expect(span.byteStart == 0)
        #expect(span.byteEnd == 5)

        #expect(hit.score.lexical == 0.5)
        #expect(hit.score.semantic == 0.0)
        #expect(hit.score.recency == 0.0)
        #expect(hit.score.graph == 0.0)

        #expect(hit.provenance.manifestId.raw == "parity-snap")
        #expect(hit.provenance.mode == .lexical)
        #expect(hit.provenance.retrievedAtUnixMs == 1_700_000_000_000)
    }

    @Test("closed-citation contract holds against canonical packet")
    func closedCitationContractAgainstCanonicalPacket() throws {
        let data = canonicalParityPacketJson.data(using: .utf8)!
        let packet = try JSONDecoder().decode(EidosContextPacket.self, from: data)

        let real = EidosCitation(
            sourceId: EidosChunkId("doc-1::lex")!,
            manifestId: EidosIndexManifestId("parity-snap")!
        )
        #expect((try? packet.validate(citation: real).get()) != nil)

        let forged = EidosCitation(
            sourceId: EidosChunkId("doc-1::sem")!,
            manifestId: EidosIndexManifestId("parity-snap")!
        )
        switch packet.validate(citation: forged) {
        case .success: Issue.record("forged id should not validate")
        case .failure: ()
        }
    }

    @Test("optional query_vector and since_unix_ms stay absent on canonical packet")
    func optionalFieldsAbsentOnCanonicalPacket() {
        // The pinned JSON has no query_vector and no since_unix_ms — both
        // skip-serialize-when-none on the Rust side. Asserting this here
        // catches a future Swift drift where one of those keys leaks back
        // into the canonical wire format.
        #expect(!canonicalParityPacketJson.contains("query_vector"))
        #expect(!canonicalParityPacketJson.contains("since_unix_ms"))
    }

    @Test("EidosRetrievalMode raw values match Rust serde output for all 9 variants")
    func retrievalModeRawValuesMatchRust() {
        // Mirror of Rust's
        // `parity::eidos_retrieval_mode_json_case_forms_are_pinned`.
        // Swift's String-backed enum rawValue is the Codable wire token;
        // for the contract to hold across the FFI it must equal the Rust
        // serde token (variant Debug name in unrenamed form).
        let expected: [(EidosRetrievalMode, String)] = [
            (.lexical, "Lexical"),
            (.semantic, "Semantic"),
            (.hybrid, "Hybrid"),
            (.codeSymbol, "CodeSymbol"),
            (.claimEvidence, "ClaimEvidence"),
            (.graphNeighborhood, "GraphNeighborhood"),
            (.rawArchive, "RawArchive"),
            (.recency, "Recency"),
            (.provenanceVerified, "ProvenanceVerified"),
        ]
        #expect(EidosRetrievalMode.allCases.count == 9)
        for (mode, token) in expected {
            #expect(mode.rawValue == token, "\(mode) rawValue drift")
        }
    }

    @Test("EidosCitationError decodes Rust external-tag JSON wire shape")
    func citationErrorDecodesRustWireShape() throws {
        // Mirror the byte-equal shape pinned by Rust's
        // `parity::citation_error_serializes_with_external_tag` test.
        let forgedJSON = #"{"FabricatedSourceId":"d::lex"}"#.data(using: .utf8)!
        let forged = try JSONDecoder().decode(EidosCitationError.self, from: forgedJSON)
        if case .fabricatedSourceId(let chunk) = forged {
            #expect(chunk.raw == "d::lex")
        } else {
            Issue.record("expected .fabricatedSourceId, got \(forged)")
        }

        let mismatchJSON = #"{"ManifestMismatch":{"packet":"snap-a","citation":"snap-b"}}"#
            .data(using: .utf8)!
        let mismatch = try JSONDecoder().decode(EidosCitationError.self, from: mismatchJSON)
        if case .manifestMismatch(let pkt, let cit) = mismatch {
            #expect(pkt.raw == "snap-a")
            #expect(cit.raw == "snap-b")
        } else {
            Issue.record("expected .manifestMismatch, got \(mismatch)")
        }
    }

    @Test("EidosCitationError encode round-trips through JSON")
    func citationErrorEncodeRoundTrip() throws {
        // Encode-decode round-trip on the Swift side. Combined with the
        // Rust→Swift decode test above, this proves the wire format is
        // symmetric.
        let original: EidosCitationError = .manifestMismatch(
            packet: EidosIndexManifestId("p")!,
            citation: EidosIndexManifestId("c")!
        )
        let json = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(EidosCitationError.self, from: json)
        #expect(back == original)
    }

    @Test("EidosSourceKind raw values match Rust serde output for all 8 variants")
    func sourceKindRawValuesMatchRust() {
        // Mirror of Rust's
        // `parity::eidos_source_kind_json_case_forms_are_pinned_via_canon_all`.
        // Symmetrical wire-format pin so a future serde refactor on
        // either side surfaces immediately on the other.
        let expected: [(EidosSourceKind, String)] = [
            (.note, "Note"),
            (.epdoc, "Epdoc"),
            (.chat, "Chat"),
            (.code, "Code"),
            (.graph, "Graph"),
            (.shadow, "Shadow"),
            (.exactPath, "ExactPath"),
            (.rawArchive, "RawArchive"),
        ]
        #expect(EidosSourceKind.allCases.count == 8)
        for (kind, token) in expected {
            #expect(kind.rawValue == token, "\(kind) rawValue drift")
        }
    }
}
