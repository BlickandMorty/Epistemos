import Foundation
import Testing

@testable import Epistemos

/// Wave 7.16 source-guard for Epdoc Metal-render attributes.
@Suite("EpdocGraphRenderingMapper (Wave 7.16)")
nonisolated struct EpdocGraphRenderingMapperTests {

    private static func projection(weight: Double) -> EpdocGraphProjection {
        EpdocGraphProjection(
            nodeID: "x",
            nodeLabel: "x",
            nodeWeight: weight,
            nodeType: .document,
            edges: []
        )
    }

    @Test("Epdoc node rendering stays neutral regardless of legacy weight")
    func nodeRenderingIsNeutral() {
        for weight in [-2.0, 0.0, 0.5, 1.0, 5.0] {
            let attrs = EpdocGraphRenderingMapper.attributes(for: Self.projection(weight: weight))
            #expect(attrs.radiusMultiplier == 1.0)
            #expect(attrs.labelFontScale == 1.0)
            #expect(attrs.haloAlpha == 0.0)
        }
    }

    // MARK: - Edge weights

    @Test("edgeWeightMultiplier table — provenance hubs visually; tags sit quietly")
    func edgeWeightTable() {
        #expect(EpdocGraphRenderingMapper.edgeWeightMultiplier(for: .derivedFrom) == 1.6,
                "derivedFrom edges MUST hub the visual hierarchy")
        #expect(EpdocGraphRenderingMapper.edgeWeightMultiplier(for: .reference) == 1.0)
        #expect(EpdocGraphRenderingMapper.edgeWeightMultiplier(for: .contains) == 1.4)
        #expect(EpdocGraphRenderingMapper.edgeWeightMultiplier(for: .tagged) == 0.7)
        // Unknown / future cases default to 1.0
        #expect(EpdocGraphRenderingMapper.edgeWeightMultiplier(for: .related) == 1.0,
                "unmapped GraphEdgeType cases MUST inherit 1.0 (graceful default)")
    }

}
