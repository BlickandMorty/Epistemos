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

    @Test("EidosBatchCitationError decodes Rust Vec<(usize, CitationError)> wire shape")
    func batchCitationErrorDecodesRustWireShape() throws {
        // Mirror of Rust's
        // `batch_validate_result_can_serialize_per_index_errors_to_json`.
        // Wire shape: array of [index, error] pairs.
        let json = #"""
        [[0,{"FabricatedSourceId":"forged"}],[1,{"ManifestMismatch":{"packet":"snap-A","citation":"OTHER"}}]]
        """#.data(using: .utf8)!
        let batch = try JSONDecoder().decode(EidosBatchCitationError.self, from: json)

        #expect(batch.errors.count == 2)

        #expect(batch.errors[0].index == 0)
        if case .fabricatedSourceId(let chunk) = batch.errors[0].error {
            #expect(chunk.raw == "forged")
        } else {
            Issue.record("expected .fabricatedSourceId at index 0")
        }

        #expect(batch.errors[1].index == 1)
        if case .manifestMismatch(let pkt, let cit) = batch.errors[1].error {
            #expect(pkt.raw == "snap-A")
            #expect(cit.raw == "OTHER")
        } else {
            Issue.record("expected .manifestMismatch at index 1")
        }
    }

    @Test("EidosBatchCitationError encode round-trips through JSON")
    func batchCitationErrorRoundTrip() throws {
        let original = EidosBatchCitationError(errors: [
            EidosIndexedCitationError(
                index: 3,
                error: .fabricatedSourceId(EidosChunkId("a::lex")!)
            ),
            EidosIndexedCitationError(
                index: 7,
                error: .manifestMismatch(
                    packet: EidosIndexManifestId("p")!,
                    citation: EidosIndexManifestId("c")!
                )
            ),
        ])
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(EidosBatchCitationError.self, from: data)
        #expect(back == original)
    }

    @Test("closed-citation validator harness outputs decode Rust-pinned JSON")
    func closedCitationValidatorHarnessOutputsDecodeRustWireShape() throws {
        let acceptedJson = #"{"accepted_count":1}"#.data(using: .utf8)!
        let accepted = try JSONDecoder().decode(EidosClosedCitationValidation.self, from: acceptedJson)
        #expect(accepted.acceptedCount == 1)

        let rejectedJson = #"{"errors":[[0,{"FabricatedSourceId":"ghost::lex"}]]}"#
            .data(using: .utf8)!
        let rejected = try JSONDecoder().decode(EidosClosedCitationValidationError.self, from: rejectedJson)
        #expect(rejected.errors.count == 1)
        #expect(rejected.errors[0].index == 0)
        if case .fabricatedSourceId(let chunk) = rejected.errors[0].error {
            #expect(chunk.raw == "ghost::lex")
        } else {
            Issue.record("expected .fabricatedSourceId in closed-citation validator rejection")
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

    @Test("EidosFalsifierWitness decodes Rust canonical witness JSON bytes")
    func falsifierWitnessDecodesRustWireShape() throws {
        // Mirror of Rust's
        // `falsifier::tests::witness_decodes_canonical_pinned_json_bytes`.
        // The Rust side serialize-pin lives in
        // `falsifier::tests::witness_serializes_to_json_with_exact_fields`.
        // Together these prove the wire format is symmetric across the FFI
        // seam: Rust emits these exact bytes; Swift consumes them losslessly
        // back into typed fields.
        let pinned = #"""
        {"retrievers_checked":12,"queries_per_retriever":6,"total_hits_validated":18,"fake_citation_rejections":72}
        """#.data(using: .utf8)!
        let witness = try JSONDecoder().decode(EidosFalsifierWitness.self, from: pinned)
        #expect(witness.retrieversChecked == 12)
        #expect(witness.queriesPerRetriever == 6)
        #expect(witness.totalHitsValidated == 18)
        #expect(witness.fakeCitationRejections == 72)

        // Round-trip the other way on the Swift side too — encoding the
        // typed witness back must produce decodable bytes identical in
        // semantics. (Field-order on encode is implementation-defined by
        // JSONEncoder.OutputFormatting; this asserts only re-decodability,
        // not byte equality — the byte-equality pin lives on the Rust
        // side.)
        let reencoded = try JSONEncoder().encode(witness)
        let back = try JSONDecoder().decode(EidosFalsifierWitness.self, from: reencoded)
        #expect(back == witness)
    }

    @Test("EidosFalsifierFailure decodes the 6 Rust-pinned variant bytes")
    func falsifierFailureDecodesRustWireShape() throws {
        // Mirror of Rust's
        // `falsifier::tests::failure_serialize_pins_exact_bytes_for_every_variant`.
        // The Swift custom Codable must consume the exact internal-tag
        // (`"variant":"..."`) JSON bytes Rust serializes. Six non-NaN
        // variants — HitConfidenceOutOfRange is exercised separately
        // below because its f32 confidence field needs its own pin.
        let cases: [(String, EidosFalsifierFailure)] = [
            (
                #"{"variant":"PacketManifestDriftsFromRetriever","retriever_mode":"Lexical","retriever_manifest":"snap-a","packet_manifest":"snap-b"}"#,
                .packetManifestDriftsFromRetriever(
                    retrieverMode: .lexical,
                    retrieverManifest: EidosIndexManifestId("snap-a")!,
                    packetManifest: EidosIndexManifestId("snap-b")!
                )
            ),
            (
                #"{"variant":"HitProvenanceManifestMismatch","retriever_mode":"Semantic","source_id":"d::sem","hit_manifest":"h","packet_manifest":"p"}"#,
                .hitProvenanceManifestMismatch(
                    retrieverMode: .semantic,
                    sourceId: EidosChunkId("d::sem")!,
                    hitManifest: EidosIndexManifestId("h")!,
                    packetManifest: EidosIndexManifestId("p")!
                )
            ),
            (
                #"{"variant":"HitProvenanceModeMismatch","retriever_mode":"Lexical","source_id":"d::lex","hit_mode":"Semantic"}"#,
                .hitProvenanceModeMismatch(
                    retrieverMode: .lexical,
                    sourceId: EidosChunkId("d::lex")!,
                    hitMode: .semantic
                )
            ),
            (
                #"{"variant":"LegitimateCitationRejected","retriever_mode":"Lexical","source_id":"doc::lex"}"#,
                .legitimateCitationRejected(
                    retrieverMode: .lexical,
                    sourceId: EidosChunkId("doc::lex")!
                )
            ),
            (
                #"{"variant":"FakeCitationAccepted","retriever_mode":"Hybrid"}"#,
                .fakeCitationAccepted(retrieverMode: .hybrid)
            ),
            (
                #"{"variant":"HitSpanInvalid","retriever_mode":"Lexical","source_id":"badspan::lex","byte_start":100,"byte_end":50}"#,
                .hitSpanInvalid(
                    retrieverMode: .lexical,
                    sourceId: EidosChunkId("badspan::lex")!,
                    byteStart: 100,
                    byteEnd: 50
                )
            ),
        ]
        for (pinnedJSON, expected) in cases {
            let data = pinnedJSON.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(EidosFalsifierFailure.self, from: data)
            #expect(decoded == expected, "decode drift on \(pinnedJSON)")

            // Swift encode → decode round-trip. Byte-equality with the
            // Rust string is intentionally NOT asserted (JSONEncoder
            // field-order is implementation-defined); the Rust-side
            // serialize bytes-pin owns that lock.
            let reencoded = try JSONEncoder().encode(expected)
            let back = try JSONDecoder().decode(EidosFalsifierFailure.self, from: reencoded)
            #expect(back == expected, "round-trip drift on \(pinnedJSON)")
        }
    }

    @Test("EidosFalsifierFailure HitConfidenceOutOfRange decodes finite confidence")
    func falsifierFailureHitConfidenceFiniteDecodes() throws {
        // Mirror of Rust's
        // `failure_hit_confidence_out_of_range_round_trips_for_finite_values`.
        // NaN handling is intentionally not pinned here — JSON `null` →
        // Float fails on both Rust and Swift, which is the documented
        // contract.
        let pinned =
            #"{"variant":"HitConfidenceOutOfRange","retriever_mode":"Lexical","source_id":"hi::lex","confidence":1.5}"#
        let data = pinned.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(EidosFalsifierFailure.self, from: data)
        if case let .hitConfidenceOutOfRange(retrieverMode, sourceId, confidence) = decoded {
            #expect(retrieverMode == .lexical)
            #expect(sourceId.raw == "hi::lex")
            #expect(confidence == 1.5)
        } else {
            Issue.record("expected hitConfidenceOutOfRange, got \(decoded)")
        }
    }

    @Test("EidosFalsifierFailure unknown variant tag decode errors cleanly")
    func falsifierFailureUnknownVariantTagErrors() {
        // A future Rust-side variant rename or addition must surface
        // as a decode error here, not as a silent fallback that
        // discards the unknown payload.
        let pinned = #"{"variant":"FutureUnknownVariant","retriever_mode":"Lexical"}"#
        let data = pinned.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(EidosFalsifierFailure.self, from: data)
        }
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
