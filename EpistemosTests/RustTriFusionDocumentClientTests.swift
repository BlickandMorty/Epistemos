import Testing
@testable import Epistemos

@Suite("Rust Tri-Fusion Document Client")
struct RustTriFusionDocumentClientTests {

    private let canonicalJson = #"{"content":[{"attrs":{"id":"b1"},"content":[{"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#

    @Test("round trip returns canonical document through FFI")
    func roundTripReturnsCanonicalDocumentThroughFfi() throws {
        #if canImport(agent_coreFFI)
        let snapshot = try #require(RustTriFusionDocumentClient.roundTrip(json: canonicalJson))
        #expect(snapshot.canonicalJson == canonicalJson)
        #expect(snapshot.hashHex.count == 64)
        #expect(!snapshot.canonicalVersion.isEmpty)
        #else
        #expect(RustTriFusionDocumentClient.roundTrip(json: canonicalJson) == nil)
        #endif
    }

    @Test("Markdown round trip returns canonical projection through FFI")
    func markdownRoundTripReturnsCanonicalProjectionThroughFfi() throws {
        let markdown = "# Swift FFI\n\nBody\n\n- One\n- Two"

        #if canImport(agent_coreFFI)
        let snapshot = try #require(RustTriFusionDocumentClient.roundTrip(markdown: markdown))

        #expect(snapshot.projection == markdown)
        #expect(snapshot.canonicalJson.contains(#""type":"heading""#))
        #expect(snapshot.canonicalJson.contains(#""type":"bulletList""#))
        #expect(snapshot.hashHex.count == 64)
        #expect(!snapshot.canonicalVersion.isEmpty)
        #else
        #expect(RustTriFusionDocumentClient.roundTrip(markdown: markdown) == nil)
        #endif
    }

    @Test("HTML round trip returns canonical projection through FFI")
    func htmlRoundTripReturnsCanonicalProjectionThroughFfi() throws {
        let html = "<section data-tri-fusion-doc><H2>Swift FFI</H2><p>A &amp; B</p></section>"
        let canonicalHtml = "<h2>Swift FFI</h2><p>A &amp; B</p>"

        #if canImport(agent_coreFFI)
        let snapshot = try #require(RustTriFusionDocumentClient.roundTrip(html: html))

        #expect(snapshot.projection == canonicalHtml)
        #expect(snapshot.canonicalJson.contains(#""type":"heading""#))
        #expect(snapshot.canonicalJson.contains(#""A & B""#))
        #expect(snapshot.hashHex.count == 64)
        #expect(!snapshot.canonicalVersion.isEmpty)
        #else
        #expect(RustTriFusionDocumentClient.roundTrip(html: html) == nil)
        #endif
    }

    @Test("mutation round trip returns deferred witness through FFI")
    func mutationRoundTripReturnsDeferredWitnessThroughFfi() throws {
        #if canImport(agent_coreFFI)
        let snapshot = try #require(RustTriFusionDocumentClient.roundTrip(json: canonicalJson))
        let mutationJson = """
        {
          "mutation_id": "tfm-swift-client-45",
          "document_id": "doc-swift-client-45",
          "base_document_hash": "\(snapshot.hashHex)",
          "actor": {
            "kind": "agent",
            "run_id": "codex-t1-swift-client-45"
          },
          "source_format": "json",
          "kind": "insert_block",
          "artifact_id": "doc-swift-client-45",
          "rationale": "Swift FFI round trip",
          "after_block_id": "b1",
          "block": {
            "type": "paragraph",
            "attrs": {
              "id": "b2",
              "model_authored": true
            },
            "content": [
              {
                "type": "text",
                "text": "From Swift FFI"
              }
            ]
          }
        }
        """

        let response = try #require(
            RustTriFusionDocumentClient.applyMutation(
                json: canonicalJson,
                mutationJson: mutationJson
            )
        )

        #expect(response.accepted)
        #expect(response.canonicalJson.contains(#""id":"b2""#))
        #expect(response.documentHash == response.witness.afterHash)
        #expect(response.witness.beforeHash == snapshot.hashHex)
        #expect(response.witness.provenanceStatus == "deferred")
        #expect(response.witness.envelopeMutationId == "tfm-swift-client-45")
        #expect(response.provenance == nil)
        #else
        #expect(
            RustTriFusionDocumentClient.applyMutation(
                json: canonicalJson,
                mutationJson: "{}"
            ) == nil
        )
        #endif
    }

    @Test("mutation with provenance commits witness IDs through FFI")
    func mutationWithProvenanceCommitsWitnessIdsThroughFfi() throws {
        #if canImport(agent_coreFFI)
        let snapshot = try #require(RustTriFusionDocumentClient.roundTrip(json: canonicalJson))
        let mutationJson = """
        {
          "mutation_id": "tfm-swift-client-46",
          "document_id": "doc-swift-client-46",
          "base_document_hash": "\(snapshot.hashHex)",
          "actor": {
            "kind": "agent",
            "run_id": "codex-t1-swift-client-46"
          },
          "source_format": "json",
          "kind": "insert_block",
          "artifact_id": "doc-swift-client-46",
          "rationale": "Swift FFI provenance commit",
          "after_block_id": "b1",
          "block": {
            "type": "paragraph",
            "attrs": {
              "id": "b46",
              "model_authored": true
            },
            "content": [
              {
                "type": "text",
                "text": "Committed from Swift FFI"
              }
            ]
          }
        }
        """

        let response = try #require(
            RustTriFusionDocumentClient.applyMutationWithProvenance(
                json: canonicalJson,
                mutationJson: mutationJson,
                createdAtMs: 1_779_019_209_000
            )
        )
        let provenance = try #require(response.provenance)
        let claimGraphNodeId = try #require(response.witness.claimGraphNodeId)
        let cognitiveDagEdgeId = try #require(response.witness.cognitiveDagEdgeId)

        #expect(response.accepted)
        #expect(response.canonicalJson.contains(#""id":"b46""#))
        #expect(response.witness.provenanceStatus == "committed")
        #expect(response.witness.mutationEnvelopeId == "tfm-swift-client-46")
        #expect(claimGraphNodeId.count == 64)
        #expect(cognitiveDagEdgeId.count == 64)
        #expect(provenance.status == "complete")
        #expect(provenance.claimNodePresent)
        #expect(provenance.evidenceNodePresent)
        #expect(provenance.derivesFromEvidenceEdgePresent)
        #expect(provenance.ids.claimNodeId == claimGraphNodeId)
        #expect(provenance.ids.derivesFromEvidenceEdgeId == cognitiveDagEdgeId)
        #else
        #expect(
            RustTriFusionDocumentClient.applyMutationWithProvenance(
                json: canonicalJson,
                mutationJson: "{}",
                createdAtMs: 0
            ) == nil
        )
        #endif
    }
}
