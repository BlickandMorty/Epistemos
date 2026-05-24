// EidosValidationParityTests.swift
//
// Terminal A 2026-05-23 — cross-language parity for the validation
// JSON wire shape returned by `eidos_validate_citation_json` and
// `eidos_validate_citations_json`.
//
// The Rust side encodes `Result<(), CitationError>` via serde's
// default `Result` shape: `{"Ok":null}` on accept and
// `{"Err": <CitationError JSON>}` on reject. The CitationError
// itself is external-tagged (`{"FabricatedSourceId": "<chunk>"}` or
// `{"ManifestMismatch": {"packet": "...", "citation": "..."}}`).
//
// This test pins the exact wire bytes Rust emits + asserts the Swift
// bridge decodes them into the right Swift typed values via the
// `EidosCitationError` mirror in `Epistemos/Eidos/Eidos.swift`. If
// either side legitimately changes the format, update BOTH the Rust
// pin (in `bridge.rs::eidos_production_ffi_tests`) and this test.

import Foundation
import Testing

@testable import Epistemos

@Suite("Eidos Validation Wire Parity")
struct EidosValidationParityTests {

    // MARK: - Result<(), CitationError> wire shape

    @Test("Rust accept JSON `{\"Ok\":null}` is recognized as accepted")
    func acceptShape() throws {
        // EidosBridge.validateCitation parses this JSON shape from the
        // Rust FFI. The internal JSONSerialization branch keys on the
        // top-level "Ok" key — pin that here so a future contract
        // change is caught.
        let raw = "{\"Ok\":null}"
        let data = try #require(raw.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json.keys.contains("Ok"))
        #expect(!json.keys.contains("Err"))
    }

    @Test("Rust reject FabricatedSourceId decodes into EidosCitationError")
    func fabricatedRejectDecodes() throws {
        let raw = "{\"Err\":{\"FabricatedSourceId\":\"forged::lex\"}}"
        let data = try #require(raw.data(using: .utf8))
        guard
            let top = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errPayload = top["Err"]
        else {
            Issue.record("Err payload missing")
            return
        }
        let errData = try JSONSerialization.data(withJSONObject: errPayload)
        let err = try JSONDecoder().decode(EidosCitationError.self, from: errData)
        guard case .fabricatedSourceId(let chunk) = err else {
            Issue.record("expected fabricatedSourceId, got \(err)")
            return
        }
        #expect(chunk.raw == "forged::lex")
    }

    @Test("Rust reject ManifestMismatch decodes with packet + citation manifests")
    func manifestMismatchRejectDecodes() throws {
        let raw =
        "{\"Err\":{\"ManifestMismatch\":{\"packet\":\"vault-a\",\"citation\":\"vault-b\"}}}"
        let data = try #require(raw.data(using: .utf8))
        guard
            let top = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errPayload = top["Err"]
        else {
            Issue.record("Err payload missing")
            return
        }
        let errData = try JSONSerialization.data(withJSONObject: errPayload)
        let err = try JSONDecoder().decode(EidosCitationError.self, from: errData)
        guard case .manifestMismatch(let packetMid, let citationMid) = err else {
            Issue.record("expected manifestMismatch, got \(err)")
            return
        }
        #expect(packetMid.raw == "vault-a")
        #expect(citationMid.raw == "vault-b")
    }

    @Test("EidosCitationError Codable round-trips both variants")
    func citationErrorRoundTripsBothVariants() throws {
        let chunk = try #require(EidosChunkId("a::lex"))
        let manifestA = try #require(EidosIndexManifestId("vault-a"))
        let manifestB = try #require(EidosIndexManifestId("vault-b"))

        // Fabricated round-trip.
        let fab = EidosCitationError.fabricatedSourceId(chunk)
        let fabData = try JSONEncoder().encode(fab)
        let fabDecoded = try JSONDecoder().decode(EidosCitationError.self, from: fabData)
        #expect(fab == fabDecoded)
        let fabJson = try #require(String(data: fabData, encoding: .utf8))
        #expect(fabJson.contains("\"FabricatedSourceId\""))

        // ManifestMismatch round-trip.
        let mm = EidosCitationError.manifestMismatch(packet: manifestA, citation: manifestB)
        let mmData = try JSONEncoder().encode(mm)
        let mmDecoded = try JSONDecoder().decode(EidosCitationError.self, from: mmData)
        #expect(mm == mmDecoded)
        let mmJson = try #require(String(data: mmData, encoding: .utf8))
        #expect(mmJson.contains("\"ManifestMismatch\""))
        #expect(mmJson.contains("\"packet\""))
        #expect(mmJson.contains("\"citation\""))
    }

    // MARK: - Batch wire shape

    @Test("batch accept JSON has shape `{\"Ok\":{\"accepted_count\":N}}`")
    func batchAcceptShape() throws {
        let raw = "{\"Ok\":{\"accepted_count\":3}}"
        let data = try #require(raw.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let ok = try #require(json["Ok"] as? [String: Any])
        let n = try #require(ok["accepted_count"] as? Int)
        #expect(n == 3)
    }

    @Test("batch reject JSON `[[index, error], ...]` preserves input position")
    func batchRejectShape() throws {
        // Rust serialize emits the per-index failure array as
        // `{"Err":[[1,{"FabricatedSourceId":"forged"}],[2,{"ManifestMismatch":...}]]}`.
        let raw = """
        {"Err":[[1,{"FabricatedSourceId":"forged::lex"}],\
        [2,{"ManifestMismatch":{"packet":"vault-a","citation":"vault-b"}}]]}
        """
        let data = try #require(raw.data(using: .utf8))
        let top = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let errArr = try #require(top["Err"] as? [[Any]])
        #expect(errArr.count == 2)
        // First element: [1, {...}]
        let first = errArr[0]
        #expect(first.count == 2)
        #expect((first[0] as? Int) == 1)
        let firstErrJson = try JSONSerialization.data(withJSONObject: first[1])
        let firstErr = try JSONDecoder().decode(EidosCitationError.self, from: firstErrJson)
        if case .fabricatedSourceId(let chunk) = firstErr {
            #expect(chunk.raw == "forged::lex")
        } else {
            Issue.record("expected fabricatedSourceId at index 1, got \(firstErr)")
        }
        // Second element: [2, {...}]
        let second = errArr[1]
        #expect((second[0] as? Int) == 2)
        let secondErrJson = try JSONSerialization.data(withJSONObject: second[1])
        let secondErr = try JSONDecoder().decode(EidosCitationError.self, from: secondErrJson)
        if case .manifestMismatch = secondErr {
            // pass
        } else {
            Issue.record("expected manifestMismatch at index 2, got \(secondErr)")
        }
    }

    // MARK: - Swift-encoded packet must Rust-decode

    @Test("Swift-encoded EidosContextPacket fields are all present + named per snake_case contract")
    func swiftEncodedPacketShape() throws {
        let manifest = try #require(EidosIndexManifestId("vault-shape-test"))
        let chunk = try #require(EidosChunkId("doc-1::lex"))
        let doc = try #require(EidosDocumentId("doc-1"))
        let packet = EidosContextPacket(
            query: EidosQuery(text: "alpha", mode: .lexical, topK: 4),
            manifestId: manifest,
            hits: [
                EidosHit(
                    sourceId: chunk,
                    documentId: doc,
                    kind: .note,
                    span: EidosSpan(byteStart: 0, byteEnd: 5),
                    confidence: 0.5,
                    score: EidosScoreComponents(
                        lexical: 0.5, semantic: 0, recency: 0, graph: 0
                    ),
                    provenance: EidosProvenance(
                        manifestId: manifest,
                        mode: .lexical,
                        retrievedAtUnixMs: 1_700_000_000_000
                    )
                )
            ]
        )
        let data = try JSONEncoder().encode(packet)
        let json = try #require(String(data: data, encoding: .utf8))

        // Field names must use snake_case per the Rust contract.
        #expect(json.contains("\"manifest_id\":\"vault-shape-test\""))
        #expect(json.contains("\"top_k\":4"))
        #expect(json.contains("\"source_id\":\"doc-1::lex\""))
        #expect(json.contains("\"document_id\":\"doc-1\""))
        #expect(json.contains("\"byte_start\":0"))
        #expect(json.contains("\"byte_end\":5"))
        #expect(json.contains("\"retrieved_at_unix_ms\":1700000000000"))

        // Round-trip back through Swift's decoder.
        let decoded = try JSONDecoder().decode(EidosContextPacket.self, from: data)
        #expect(decoded == packet)
    }
}
