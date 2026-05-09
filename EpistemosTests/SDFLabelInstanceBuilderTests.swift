import Testing
@testable import Epistemos

struct SDFLabelInstanceBuilderTests {
    private static let glyph = SDFGlyph(
        uvRect: SIMD4<Float>(0.1, 0.1, 0.05, 0.05),
        halfWidthEm: 0.3,
        halfHeightEm: 0.35,
        bearingXEm: 0.3,
        bearingYEm: 0.35,
        advanceEm: 0.6
    )

    private static let atlas = SDFLabelAtlas(
        atlasWidth: 1024,
        atlasHeight: 1024,
        emRange: 0.4,
        pxRange: 6.0,
        lineHeightEm: 1.2,
        glyphs: ["A": glyph],
        fallbackGlyph: glyph
    )

    @Test("SDF label builder never exceeds the global glyph budget")
    func outputCountNeverExceedsLabelBudget() {
        let nodes = (0..<200).map { index in
            SDFLabelInstanceBuilder.Node(
                worldX: Float(index),
                worldY: 0,
                radius: 10,
                label: String(repeating: "A", count: 32)
            )
        }

        let output = SDFLabelInstanceBuilder.build(
            nodes: nodes,
            atlas: Self.atlas,
            cameraWorld: .zero,
            worldPxPerEm: 20
        )

        #expect(output.count == SDFLabelInstanceBuilder.labelBudget)
    }

    @Test("Long labels stop at the remaining frame budget")
    func longLabelsRespectPerFrameBudget() {
        let almostFullNodeCount = (SDFLabelInstanceBuilder.labelBudget / 32)
        let nodes = (0...almostFullNodeCount).map { index in
            SDFLabelInstanceBuilder.Node(
                worldX: Float(index),
                worldY: 0,
                radius: 10,
                label: String(repeating: "A", count: 32)
            )
        }

        let output = SDFLabelInstanceBuilder.build(
            nodes: nodes,
            atlas: Self.atlas,
            cameraWorld: .zero,
            worldPxPerEm: 20
        )

        #expect(output.count <= SDFLabelInstanceBuilder.labelBudget)
    }
}
