import Metal
import Testing

@testable import Epistemos

@MainActor
struct LandingWaveGlyphAtlasTests {

    /// The builder must produce one cell index per glyph in the authoritative
    /// ordering defined by `LandingWaveDesign.atlasGlyphOrder`. Any change to
    /// that ordering is a breaking change for the fragment shader, so this
    /// test pins it down.
    @Test func cellIndicesMatchGlyphOrder() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // CI runners without a GPU: skip rather than fail.
            return
        }

        let built = try #require(LandingWaveGlyphAtlas.build(device: device))
        #expect(
            built.cellIndex.count == LandingWaveDesign.atlasGlyphOrder.count,
            "cellIndex count must match the declared glyph set"
        )

        // Cells are assigned in row-major order. Verify the first few entries
        // to catch subtle layout drift.
        #expect(built.cellIndex.first == SIMD2<Int32>(0, 0))
        if built.cellIndex.count > 1 {
            #expect(built.cellIndex[1] == SIMD2<Int32>(1, 0))
        }
    }

    /// The texture dimensions must match the declared cell × grid product so
    /// the fragment shader can index by `(cellX, cellY)` without a separate
    /// UV lookup table.
    @Test func textureDimensionsMatchDesign() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let built = try #require(LandingWaveGlyphAtlas.build(device: device))

        let expectedWidth = Int(LandingWaveDesign.atlasCellSize.x)
            * Int(LandingWaveDesign.atlasGridSize.x)
        let expectedHeight = Int(LandingWaveDesign.atlasCellSize.y)
            * Int(LandingWaveDesign.atlasGridSize.y)

        #expect(built.texture.width == expectedWidth)
        #expect(built.texture.height == expectedHeight)
        #expect(built.texture.pixelFormat == LandingWaveGlyphAtlas.pixelFormat)
    }

    /// The glyph set must fit inside the atlas grid (no overflow past the last row).
    @Test func glyphSetFitsAtlas() {
        let capacity = Int(LandingWaveDesign.atlasGridSize.x)
            * Int(LandingWaveDesign.atlasGridSize.y)
        #expect(
            LandingWaveDesign.atlasGlyphOrder.count <= capacity,
            "Glyph set exceeds atlas capacity — enlarge atlasGridSize or trim the set"
        )
    }

    /// Luminance ramp must be non-empty and start with a blank/space entry so
    /// an index of 0 reads as "no glyph". The fragment shader relies on this.
    @Test func luminanceRampStartsWithBlank() {
        #expect(LandingWaveDesign.luminanceRamp.first == " ")
        #expect(LandingWaveDesign.luminanceRamp.count == 16)
        #expect(LandingWaveDesign.luminanceRamp.contains("@"))
    }
}
