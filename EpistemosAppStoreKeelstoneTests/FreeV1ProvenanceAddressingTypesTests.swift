import Foundation
import Testing
@testable import Epistemos

@Suite("Free V1 provenance addressing compatibility")
struct FreeV1ProvenanceAddressingTypesTests {
    @Test("persisted anchors retain passive plane and residency metadata without a runtime router")
    func persistedAnchorsRoundTripWithoutRuntimeRouter() throws {
        let original = AcsAnchor(
            anchorId: "anchor-1",
            theoremId: "theorem-1",
            plane: .controller,
            residency: .verifiedFloor,
            sourceHash: "source-hash",
            activePacketId: "packet-1",
            compatibilityEdge: "edge-1",
            salience: 0.75
        )

        let decoded = try JSONDecoder().decode(
            AcsAnchor.self,
            from: JSONEncoder().encode(original)
        )

        #expect(decoded == original)
        #expect(RuntimePlane.allCases.map(\.rawValue) == [
            "state", "episodic", "assembly", "controller", "verification",
        ])
        #expect(ResidencyTier.allCases.map(\.rawValue) == [
            "current_app", "verified_floor", "capability_ceiling",
        ])
    }
}
