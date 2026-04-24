import AppKit
import CoreGraphics
import CoreText
import Foundation
import Metal

/// Builds the glyph atlas texture consumed by the landing-wave fragment shader.
///
/// Implementation notes:
/// - Each glyph is rasterized **once** into a single `MTLTexture` at app startup.
/// - Characters are laid out on a fixed cell grid so the shader can look up any
///   glyph by `(cellX, cellY)` pair without needing a UV map in a uniform.
/// - We pre-multiply alpha into the R channel so the fragment shader can treat
///   the atlas as a single-channel coverage mask and multiply against the theme
///   foreground color.
///
/// Thread safety: the builder is `nonisolated` — it touches no actor-bound
/// state and is safe to call from any thread. The resulting `MTLTexture` is
/// owned by whoever invoked `build` and is never mutated thereafter.
enum LandingWaveGlyphAtlas {

    /// Pixel format used for the atlas. Single-channel 8-bit coverage mask.
    static let pixelFormat: MTLPixelFormat = .r8Unorm

    /// Result bundle: the texture plus a lookup table mapping each character
    /// in `LandingWaveDesign.atlasGlyphOrder` to its `(cellX, cellY)` index.
    struct Built {
        let texture: MTLTexture
        /// Parallel to `LandingWaveDesign.atlasGlyphOrder`. `cellIndex[i]` is the
        /// `(cellX, cellY)` of the i-th glyph. Shader indexes this array.
        let cellIndex: [SIMD2<Int32>]
        /// Width/height of one cell in the atlas, pixels.
        let cellSize: SIMD2<Int32>
        /// Width/height of the whole atlas in cells.
        let gridSize: SIMD2<Int32>
    }

    /// Build the atlas. Returns nil on any failure (texture allocation, font
    /// resolution). Callers should log and fall back to a text-only landing.
    static func build(device: MTLDevice, fontSize: CGFloat = 14) -> Built? {
        let cellSize = LandingWaveDesign.atlasCellSize
        let gridSize = LandingWaveDesign.atlasGridSize
        let atlasWidth = Int(cellSize.x) * Int(gridSize.x)
        let atlasHeight = Int(cellSize.y) * Int(gridSize.y)

        // Allocate a single-channel 8-bit buffer for rasterization.
        let bytesPerRow = atlasWidth
        var pixels = [UInt8](repeating: 0, count: atlasWidth * atlasHeight)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard
            let bitmap = pixels.withUnsafeMutableBytes({ bytes -> CGContext? in
                CGContext(
                    data: bytes.baseAddress,
                    width: atlasWidth,
                    height: atlasHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                )
            })
        else {
            return nil
        }

        // Fill background fully transparent (0 = no coverage).
        bitmap.setFillColor(CGColor(gray: 0, alpha: 1))
        bitmap.fill([CGRect(x: 0, y: 0, width: atlasWidth, height: atlasHeight)])
        // Draw white glyphs — we'll treat the grayscale result as coverage.
        bitmap.setFillColor(CGColor(gray: 1, alpha: 1))

        // Use a monospaced system font so all glyphs share an advance width.
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let ctFont = font as CTFont

        var cellIndex: [SIMD2<Int32>] = []
        cellIndex.reserveCapacity(LandingWaveDesign.atlasGlyphOrder.count)

        for (i, character) in LandingWaveDesign.atlasGlyphOrder.enumerated() {
            let col = Int32(i % Int(gridSize.x))
            let row = Int32(i / Int(gridSize.x))
            cellIndex.append(SIMD2<Int32>(col, row))

            drawGlyph(
                character,
                cell: SIMD2<Int32>(col, row),
                cellSize: cellSize,
                atlasHeight: atlasHeight,
                font: ctFont,
                context: bitmap
            )
        }

        // Upload the rasterized buffer into an MTLTexture.
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = pixelFormat
        descriptor.width = atlasWidth
        descriptor.height = atlasHeight
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        pixels.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            texture.replace(
                region: MTLRegion(
                    origin: MTLOrigin(x: 0, y: 0, z: 0),
                    size: MTLSize(width: atlasWidth, height: atlasHeight, depth: 1)
                ),
                mipmapLevel: 0,
                withBytes: base,
                bytesPerRow: bytesPerRow
            )
        }

        return Built(
            texture: texture,
            cellIndex: cellIndex,
            cellSize: cellSize,
            gridSize: gridSize
        )
    }

    /// Rasterizes one glyph into its cell. Draws the character centered in the
    /// cell, baseline-adjusted so ascenders/descenders don't clip.
    private static func drawGlyph(
        _ character: Character,
        cell: SIMD2<Int32>,
        cellSize: SIMD2<Int32>,
        atlasHeight: Int,
        font: CTFont,
        context: CGContext
    ) {
        let cellW = CGFloat(cellSize.x)
        let cellH = CGFloat(cellSize.y)

        // Resolve the glyph index for this character. CoreText returns 0 for
        // unknown glyphs — we simply leave those cells blank.
        let string = String(character) as NSString
        let utf16: [unichar] = (0..<string.length).map { string.character(at: $0) }
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        let ok = CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count)
        guard ok, let glyph = glyphs.first, glyph != 0 else { return }

        // Cell origin in atlas pixel space. Metal and CoreGraphics agree on
        // bottom-left origin here because we are working in the bitmap's own
        // coordinate system (CGContext is bottom-left).
        let originX = CGFloat(cell.x) * cellW
        let originY = CGFloat(atlasHeight) - CGFloat(cell.y + 1) * cellH

        // Center the glyph horizontally within the cell and sit it on a
        // 3/10-up baseline so descenders remain inside the cell.
        let advance = CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, nil, 1)
        let offsetX = (cellW - advance) * 0.5
        let baselineY = originY + cellH * 0.3

        context.saveGState()
        context.textMatrix = .identity
        var glyphMut = glyph
        var position = CGPoint(x: originX + offsetX, y: baselineY)
        CTFontDrawGlyphs(font, &glyphMut, &position, 1, context)
        context.restoreGState()
    }
}
