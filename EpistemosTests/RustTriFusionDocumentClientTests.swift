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
        #else
        #expect(
            RustTriFusionDocumentClient.applyMutation(
                json: canonicalJson,
                mutationJson: "{}"
            ) == nil
        )
        #endif
    }
}
