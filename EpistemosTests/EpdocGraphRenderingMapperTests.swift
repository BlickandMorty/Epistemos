import Foundation
import Testing

@testable import Epistemos

/// Wave 7.16 source-guard for the complexity → Metal-render attribute
/// mapping curves.
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

    @Test("Complexity 0.0 maps to the bottom of every range (smallest, no halo, base font)")
    func zeroComplexityIsBaseline() {
        let attrs = EpdocGraphRenderingMapper.attributes(for: Self.projection(weight: 0.0))
        #expect(attrs.radiusMultiplier == 0.7)
        #expect(attrs.labelFontScale == 1.0)
        #expect(attrs.haloAlpha == 0.0,
                "complexity 0 docs MUST disable the halo pass entirely (alpha = 0)")
    }

    @Test("Complexity 1.0 maps to the top of every range (largest, max halo, big font)")
    func oneComplexityIsCeiling() {
        let attrs = EpdocGraphRenderingMapper.attributes(for: Self.projection(weight: 1.0))
        #expect(abs(attrs.radiusMultiplier - 1.6) < 0.001)
        #expect(abs(attrs.labelFontScale - 1.4) < 0.001)
        #expect(abs(attrs.haloAlpha - 0.40) < 0.001,
                "complexity 1 docs MUST cap halo alpha at 0.40 (no blend blow-out)")
    }

    @Test("Complexity 0.5 lands at the linear midpoint of every range")
    func midComplexityIsMidpoint() {
        let attrs = EpdocGraphRenderingMapper.attributes(for: Self.projection(weight: 0.5))
        #expect(abs(attrs.radiusMultiplier - 1.15) < 0.001)
        #expect(abs(attrs.labelFontScale - 1.20) < 0.001)
        #expect(abs(attrs.haloAlpha - 0.20) < 0.001)
    }

    @Test("Out-of-range complexity values clamp to [0, 1] (defensive against future tuning)")
    func outOfRangeClamps() {
        let above = EpdocGraphRenderingMapper.attributes(for: Self.projection(weight: 5.0))
        #expect(abs(above.radiusMultiplier - 1.6) < 0.001,
                "weight > 1.0 MUST clamp to 1.0; got \(above.radiusMultiplier)")
        let below = EpdocGraphRenderingMapper.attributes(for: Self.projection(weight: -2.0))
        #expect(above.radiusMultiplier == 1.6 && below.radiusMultiplier == 0.7,
                "weight < 0.0 MUST clamp to 0.0")
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

    @Test("Mapping is monotonic — strictly increasing weight → non-decreasing render scalars")
    func mappingIsMonotonic() {
        let weights: [Double] = [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]
        var prev = EpdocGraphRenderingMapper.attributes(for: Self.projection(weight: weights[0]))
        for w in weights.dropFirst() {
            let next = EpdocGraphRenderingMapper.attributes(for: Self.projection(weight: w))
            #expect(next.radiusMultiplier >= prev.radiusMultiplier)
            #expect(next.labelFontScale  >= prev.labelFontScale)
            #expect(next.haloAlpha       >= prev.haloAlpha)
            prev = next
        }
    }
}
