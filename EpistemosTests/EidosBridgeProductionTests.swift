import Foundation
import Testing
@testable import Epistemos

// Terminal A 2026-05-23 — Eidos Real Vault Binding (W-46.1 / W-47)
// Swift integration tests.
//
// Verifies the production-vault FFI surface end-to-end:
//
//   - openVaultIndex / insertVaultNote / retrieve round-trip emits a
//     packet whose manifest_id flips backend detection to `.real`.
//   - validateCitation accepts every emitted source_id.
//   - validateCitation rejects forged source_ids (FabricatedSourceId)
//     and manifest-mismatched citations (ManifestMismatch).
//   - validateCitations batch helper returns the first rejection in
//     order, matches Rust semantics.
//   - retrieve before open returns nil + records into EidosMetrics.
//   - closeVaultIndex returns the index to the not-open state.
//
// Suite is serialized via `.serialized` because all tests touch the
// process-global Rust vault slot.

@Suite("Eidos Production Bridge", .serialized)
struct EidosBridgeProductionTests {

    // MARK: - Helpers

    private func reset() {
        EidosBridge.closeVaultIndex()
        EidosMetrics.shared.reset()
    }

    // MARK: - Round-trip

    @Test("openVaultIndex returns a vault-prefixed manifest id")
    func openReturnsVaultPrefixedManifest() throws {
        reset()
        defer { reset() }

        let manifest = try #require(
            EidosBridge.openVaultIndex(signature: "swift-roundtrip-2026-05-23")
        )
        #expect(manifest.raw.hasPrefix("vault-"))
        #expect(manifest.raw == "vault-swift-roundtrip-2026-05-23")
    }

    @Test("insert then retrieve produces citation-bearing packet on the production manifest")
    func insertThenRetrieveRoundTrip() throws {
        reset()
        defer { reset() }

        _ = EidosBridge.openVaultIndex(signature: "insert-retrieve-test")
        #expect(
            EidosBridge.insertVaultNote(
                documentId: "note-1",
                body: "Tropical semirings make optimization convex.",
                kind: .note
            )
        )
        #expect(
            EidosBridge.insertVaultNote(
                documentId: "note-2",
                body: "This note is irrelevant.",
                kind: .note
            )
        )

        let packet = try #require(EidosBridge.retrieve(query: "tropical", topK: 8))
        #expect(packet.hits.count == 1, "only note-1 should match")
        #expect(packet.manifestId.raw == "vault-insert-retrieve-test")
        #expect(EidosBridge.detectedBackend(from: packet) == .real)

        // EidosMetrics now records the .real backend → chip-strip flips
        // orange→green in EidosHealthRow.
        let snap = EidosMetrics.shared.snapshot()
        #expect(snap.lastBackend == .real)
        #expect(snap.lastCitationCount == 1)
    }

    @Test("validateCitation accepts every emitted source_id")
    func validateCitationAcceptsEmittedHits() throws {
        reset()
        defer { reset() }

        _ = EidosBridge.openVaultIndex(signature: "validate-accept-test")
        _ = EidosBridge.insertVaultNote(
            documentId: "doc-a",
            body: "alpha beta gamma",
            kind: .note
        )
        _ = EidosBridge.insertVaultNote(
            documentId: "doc-b",
            body: "alpha delta",
            kind: .note
        )

        let packet = try #require(EidosBridge.retrieve(query: "alpha", topK: 8))
        #expect(packet.hits.count == 2)
        for hit in packet.hits {
            let citation = EidosCitation(
                sourceId: hit.sourceId,
                manifestId: packet.manifestId
            )
            let outcome = EidosBridge.validateCitation(packet: packet, citation: citation)
            switch outcome {
            case .accepted: break
            case .rejected(let err):
                Issue.record("legitimate citation rejected: \(err)")
            case .bridgeFailure(let msg):
                Issue.record("bridge failure for legitimate citation: \(msg)")
            }
        }
    }

    @Test("validateCitation rejects a fabricated source_id")
    func validateCitationRejectsForged() throws {
        reset()
        defer { reset() }

        _ = EidosBridge.openVaultIndex(signature: "forged-test")
        _ = EidosBridge.insertVaultNote(
            documentId: "real",
            body: "the real body",
            kind: .note
        )

        let packet = try #require(EidosBridge.retrieve(query: "real", topK: 8))
        let forged = EidosCitation(
            sourceId: try #require(EidosChunkId("forged::lex")),
            manifestId: packet.manifestId
        )
        let outcome = EidosBridge.validateCitation(packet: packet, citation: forged)
        switch outcome {
        case .rejected(let err):
            if case .fabricatedSourceId(let chunk) = err {
                #expect(chunk.raw == "forged::lex")
            } else {
                Issue.record("expected fabricatedSourceId, got \(err)")
            }
        case .accepted:
            Issue.record("forged citation must be rejected by closed-citation contract")
        case .bridgeFailure(let msg):
            Issue.record("bridge failure: \(msg)")
        }
    }

    @Test("validateCitation rejects manifest-mismatched citation")
    func validateCitationRejectsManifestMismatch() throws {
        reset()
        defer { reset() }

        _ = EidosBridge.openVaultIndex(signature: "manifest-mismatch-test")
        _ = EidosBridge.insertVaultNote(
            documentId: "doc",
            body: "body",
            kind: .note
        )
        let packet = try #require(EidosBridge.retrieve(query: "body", topK: 8))
        #expect(!packet.hits.isEmpty)

        let crossManifest = try #require(EidosIndexManifestId("vault-some-other"))
        let stolen = EidosCitation(
            sourceId: packet.hits[0].sourceId,
            manifestId: crossManifest
        )
        let outcome = EidosBridge.validateCitation(packet: packet, citation: stolen)
        switch outcome {
        case .rejected(let err):
            if case .manifestMismatch(let packetMid, let citationMid) = err {
                #expect(packetMid == packet.manifestId)
                #expect(citationMid == crossManifest)
            } else {
                Issue.record("expected manifestMismatch, got \(err)")
            }
        default:
            Issue.record("manifest mismatch must be rejected")
        }
    }

    @Test("validateCitations batch helper rejects on first forged entry")
    func validateCitationsBatchShortCircuits() throws {
        reset()
        defer { reset() }

        _ = EidosBridge.openVaultIndex(signature: "batch-test")
        _ = EidosBridge.insertVaultNote(documentId: "a", body: "alpha", kind: .note)
        _ = EidosBridge.insertVaultNote(documentId: "b", body: "alpha beta", kind: .note)

        let packet = try #require(EidosBridge.retrieve(query: "alpha", topK: 8))
        let real = packet.hits.map(\.sourceId)
        let mixed = [real[0], try #require(EidosChunkId("forged::lex"))]
        let outcome = EidosBridge.validateCitations(
            packet: packet,
            sourceIds: mixed
        )
        if case .rejected(.fabricatedSourceId(let chunk)) = outcome {
            #expect(chunk.raw == "forged::lex")
        } else {
            Issue.record("expected fabricatedSourceId rejection, got \(outcome)")
        }
    }

    @Test("validateCitations accepts when every emitted source_id is in packet")
    func validateCitationsBatchAccepts() throws {
        reset()
        defer { reset() }

        _ = EidosBridge.openVaultIndex(signature: "batch-accept-test")
        _ = EidosBridge.insertVaultNote(documentId: "a", body: "alpha", kind: .note)
        _ = EidosBridge.insertVaultNote(documentId: "b", body: "alpha beta", kind: .note)

        let packet = try #require(EidosBridge.retrieve(query: "alpha", topK: 8))
        let real = packet.hits.map(\.sourceId)
        let outcome = EidosBridge.validateCitations(packet: packet, sourceIds: real)
        if case .accepted = outcome {
            // pass
        } else {
            Issue.record("legitimate batch must validate, got \(outcome)")
        }
    }

    // MARK: - Failure modes

    @Test("retrieve before open returns nil and records error")
    func retrieveBeforeOpenReturnsNil() {
        reset()
        defer { reset() }
        let packet = EidosBridge.retrieve(query: "anything", topK: 4)
        #expect(packet == nil)
        let snap = EidosMetrics.shared.snapshot()
        #expect(snap.lastErrorDescription != nil)
    }

    @Test("insertVaultNote before open returns false")
    func insertBeforeOpenReturnsFalse() {
        reset()
        defer { reset() }
        #expect(
            !EidosBridge.insertVaultNote(documentId: "x", body: "y", kind: .note)
        )
    }

    @Test("closeVaultIndex returns the index to the not-open state")
    func closeReturnsToNotOpen() {
        reset()
        defer { reset() }
        _ = EidosBridge.openVaultIndex(signature: "close-test")
        #expect(EidosBridge.closeVaultIndex(), "first close should report was-open")
        #expect(!EidosBridge.closeVaultIndex(), "second close should report not-open")
        // retrieve now errors back to nil
        #expect(EidosBridge.retrieve(query: "anything", topK: 4) == nil)
    }

    @Test("re-open replaces the index — prior notes are dropped")
    func reopenDropsPriorNotes() throws {
        reset()
        defer { reset() }
        _ = EidosBridge.openVaultIndex(signature: "first")
        _ = EidosBridge.insertVaultNote(
            documentId: "ghost",
            body: "alpha",
            kind: .note
        )
        _ = EidosBridge.openVaultIndex(signature: "second")
        let packet = try #require(EidosBridge.retrieve(query: "alpha", topK: 4))
        #expect(packet.hits.isEmpty, "post-reopen retrieve must not see prior notes")
        #expect(packet.manifestId.raw == "vault-second")
    }

    @Test("SearchIndexService page upsert also feeds the production Eidos vault index")
    func searchIndexUpsertFeedsProductionEidosIndex() throws {
        reset()
        defer { reset() }

        _ = EidosBridge.openVaultIndex(signature: "search-index-upsert")
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("eidos-search-index-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        let searchIndex = try SearchIndexService(databaseURL: dbURL)

        try searchIndex.upsert(
            id: "page-eidos-live",
            title: "Live Eidos",
            body: "production vault retrieval should see this substrate phrase",
            tags: "",
            updatedAt: .now
        )

        let packet = try #require(EidosBridge.retrieve(query: "substrate phrase", topK: 8))
        #expect(packet.manifestId.raw == "vault-search-index-upsert")
        #expect(packet.hits.map(\.documentId.raw) == ["page-eidos-live"])
        #expect(EidosBridge.detectedBackend(from: packet) == .real)
    }
}
