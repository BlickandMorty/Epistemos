import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 provenance workspace-context removal tests must compile in the App Store target.")
#endif

@Suite("Free V1 provenance workspace-context removal")
@MainActor
struct FreeV1ProvenanceWorkspaceContextRemovalTests {
    @Test("stored answer provenance is not presented as workspace context")
    func storedAnswerProvenanceFailsClosed() throws {
        #expect(!ProductCapabilityPolicy.allowsWorkspaceContextPresentation(kind: "provenance_claim"))

        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "provenance claims", limit: 5)
        let legacyData = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            contextResults: [
                HTMLWorkspaceDataFeedResult(
                    pageID: "answer-packet:archived:claim:1",
                    title: "Empirical claim",
                    snippet: "A paid answer witness that must not appear in Free V1.",
                    rank: 1,
                    contextKind: "provenance_claim",
                    sourceLabel: "Provenance claim",
                    provenance: "AnswerPacketStore / packet:archived / claim:1"
                ),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_800_000_000),
            requiredContextKind: "provenance_claim"
        )

        let presentationData = HTMLWorkspaceDataFeedRenderer.presentationDataJSON(from: legacyData)
        #expect(!presentationData.contains("paid answer witness"))
        #expect(!presentationData.contains("AnswerPacketStore"))
        #expect(!presentationData.contains("provenance_claim"))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: presentationData))
        #expect(metadata.resultCount == 0)
        #expect(metadata.contextKinds == [])
        #expect(metadata.requiredContextKind == nil)

        let provenanceOnlyData = """
        {"results":[],"_epistemos":{"source":"vault_search","query":"archived provenance","limit":5,"result_count":0,"context_kinds":[],"refreshed_at_ms":1800000000000,"provenance":"provenance_claim / AnswerPacketStore","stale":false,"status":"fresh","error":null,"required_context_kind":null,"required_context_available":null}}
        """
        let redactedProvenanceOnlyData = HTMLWorkspaceDataFeedRenderer.presentationDataJSON(
            from: provenanceOnlyData
        )
        #expect(!redactedProvenanceOnlyData.contains("provenance_claim"))
        #expect(!redactedProvenanceOnlyData.contains("AnswerPacketStore"))
    }
}
