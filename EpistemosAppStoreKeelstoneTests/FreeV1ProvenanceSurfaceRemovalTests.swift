import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 provenance-surface removal tests must compile in the App Store target.")
#endif

@Suite("Free V1 provenance display removal")
struct FreeV1ProvenanceSurfaceRemovalTests {
    @Test("Free V1 omits the retired AnswerPacket lineage display")
    func freeV1OmitsRetiredAnswerPacketLineageDisplay() {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let retiredPath = "Epistemos/Views/Provenance/VRMLabelView.swift"

        #expect(
            !FileManager.default.fileExists(
                atPath: repositoryRoot.appendingPathComponent(retiredPath).path
            ),
            "Free V1 must not ship the retired AnswerPacket lineage display."
        )
    }
}
