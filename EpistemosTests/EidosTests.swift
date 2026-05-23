// EidosTests.swift
//
// Swift Testing coverage for the `Eidos.swift` mirror types. These tests
// stay independent of the Rust FFI bridge (which lands under W-46) so the
// Swift-side closed-citation contract can be exercised without xcodebuild
// invoking cargo. JSON byte-equality with Rust-emitted packets is
// validated separately once the bridge is wired.
//
// Per AGENTS.md test-naming convention: `<System>Tests.swift` for core
// tests; edge cases / parity tests get their own files.

import Foundation
import Testing

@testable import Epistemos

@Suite("Eidos.swift mirror types — closed-citation contract")
struct EidosClosedCitationTests {

    private func manifest(_ raw: String = "test-manifest") -> EidosIndexManifestId {
        EidosIndexManifestId(raw)!
    }

    private func chunk(_ raw: String) -> EidosChunkId {
        EidosChunkId(raw)!
    }

    private func doc(_ raw: String) -> EidosDocumentId {
        EidosDocumentId(raw)!
    }

    private func makeHit(source: String, manifestId: EidosIndexManifestId) -> EidosHit {
        EidosHit(
            sourceId: chunk(source),
            documentId: doc("\(source)::doc"),
            kind: .note,
            span: EidosSpan(byteStart: 0, byteEnd: 16),
            confidence: 0.5,
            score: EidosScoreComponents(lexical: 0.5),
            provenance: EidosProvenance(
                manifestId: manifestId,
                mode: .lexical,
                retrievedAtUnixMs: 1_700_000_000_000
            )
        )
    }

    private func samplePacket() -> EidosContextPacket {
        let m = manifest()
        return EidosContextPacket(
            query: EidosQuery(text: "anything", mode: .lexical, topK: 8),
            manifestId: m,
            hits: [
                makeHit(source: "chunk-1", manifestId: m),
                makeHit(source: "chunk-2", manifestId: m),
            ]
        )
    }

    @Test("fabricated source_id is rejected")
    func fabricatedSourceIdIsRejected() {
        let packet = samplePacket()
        let forged = EidosCitation(
            sourceId: chunk("never-emitted"),
            manifestId: packet.manifestId
        )
        switch packet.validate(citation: forged) {
        case .success: Issue.record("forged id should not validate")
        case .failure(let err):
            if case .fabricatedSourceId = err {
                // expected
            } else {
                Issue.record("expected .fabricatedSourceId, got \(err)")
            }
        }
    }

    @Test("returned source_id is accepted")
    func returnedSourceIdIsAccepted() {
        let packet = samplePacket()
        let real = EidosCitation(sourceId: chunk("chunk-1"), manifestId: packet.manifestId)
        #expect((try? packet.validate(citation: real).get()) != nil)
    }

    @Test("cross-manifest citation is rejected")
    func crossManifestCitationIsRejected() {
        let packet = samplePacket()
        let crossSnapshot = EidosCitation(
            sourceId: chunk("chunk-1"),
            manifestId: manifest("OTHER-snapshot")
        )
        switch packet.validate(citation: crossSnapshot) {
        case .success: Issue.record("cross-snapshot should not validate")
        case .failure(let err):
            if case .manifestMismatch = err {
                // expected
            } else {
                Issue.record("expected .manifestMismatch, got \(err)")
            }
        }
    }

    @Test("batch validate succeeds when all legitimate")
    func batchValidateAllLegitimate() {
        let packet = samplePacket()
        let cites = [
            EidosCitation(sourceId: chunk("chunk-1"), manifestId: packet.manifestId),
            EidosCitation(sourceId: chunk("chunk-2"), manifestId: packet.manifestId),
        ]
        #expect((try? packet.validate(citations: cites).get()) != nil)
    }

    @Test("batch validate reports every forgery with index")
    func batchValidateReportsEveryForgery() {
        let packet = samplePacket()
        let cites = [
            EidosCitation(sourceId: chunk("chunk-1"), manifestId: packet.manifestId),
            EidosCitation(sourceId: chunk("forged-A"), manifestId: packet.manifestId),
            EidosCitation(sourceId: chunk("forged-B"), manifestId: packet.manifestId),
        ]
        switch packet.validate(citations: cites) {
        case .success: Issue.record("forged ids should not validate")
        case .failure(let batch):
            #expect(batch.errors.count == 2)
            #expect(batch.errors[0].index == 1)
            #expect(batch.errors[1].index == 2)
        }
    }

    @Test("citable source ids preserves hit order")
    func citableSourceIdsPreservesHitOrder() {
        let packet = samplePacket()
        #expect(packet.citableSourceIds == [chunk("chunk-1"), chunk("chunk-2")])
    }

    @Test("EidosCitation participates in Set dedup correctly")
    func eidosCitationHashableSetDedup() {
        // Mirror of the Rust hardening test
        // `eidos_citation_hash_eq_dedup_in_hashset`. Pin that two
        // citations constructed with the same (sourceId, manifestId)
        // collide in a Swift Set, and that varying manifestId creates
        // a distinct key.
        let m = EidosIndexManifestId("hash-test")!
        let id = EidosChunkId("d::lex")!

        let c1 = EidosCitation(sourceId: id, manifestId: m)
        let c2 = EidosCitation(sourceId: id, manifestId: m)
        #expect(c1 == c2)

        var set: Set<EidosCitation> = []
        set.insert(c1)
        set.insert(c2)
        #expect(set.count == 1)

        let other = EidosCitation(
            sourceId: id,
            manifestId: EidosIndexManifestId("DIFFERENT")!
        )
        set.insert(other)
        #expect(set.count == 2)
    }
}

@Suite("Eidos.swift mirror types — Codable round-trip")
struct EidosCodableTests {

    @Test("EidosContextPacket round-trips through JSON")
    func packetRoundTrip() throws {
        let m = EidosIndexManifestId("rt-manifest")!
        let packet = EidosContextPacket(
            query: EidosQuery(text: "hello", mode: .hybrid, topK: 4, queryVector: [0.5, 0.5]),
            manifestId: m,
            hits: [
                EidosHit(
                    sourceId: EidosChunkId("doc-1::lex")!,
                    documentId: EidosDocumentId("doc-1")!,
                    kind: .note,
                    span: EidosSpan(byteStart: 0, byteEnd: 5),
                    confidence: 0.83,
                    score: EidosScoreComponents(lexical: 0.83, semantic: 0.0, recency: 0.0, graph: 0.0),
                    provenance: EidosProvenance(
                        manifestId: m,
                        mode: .hybrid,
                        retrievedAtUnixMs: 1_700_000_000_000
                    )
                )
            ]
        )
        let json = try JSONEncoder().encode(packet)
        let back = try JSONDecoder().decode(EidosContextPacket.self, from: json)
        #expect(back == packet)
    }

    @Test("EidosIndexManifest without Live Files binding omits field in JSON")
    func manifestOmitsLiveFilesWhenNil() throws {
        let m = EidosIndexManifest(
            id: EidosIndexManifestId("snap-A")!,
            createdAtUnixMs: 1_700_000_000_000
        )
        let json = String(data: try JSONEncoder().encode(m), encoding: .utf8)!
        #expect(!json.contains("live_files_snapshot_id"))
    }

    @Test("empty document id rejected at construction")
    func emptyDocumentIdRejected() {
        #expect(EidosDocumentId("") == nil)
        #expect(EidosChunkId("") == nil)
        #expect(EidosIndexManifestId("") == nil)
    }

    @Test("all nine retrieval modes are representable")
    func allNineRetrievalModes() {
        #expect(EidosRetrievalMode.allCases.count == 9)
    }
}
