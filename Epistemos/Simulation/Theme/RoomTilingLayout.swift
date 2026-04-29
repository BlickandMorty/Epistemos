//
//  RoomTilingLayout.swift
//  Simulation Mode S7 — viewport-tiling math for the
//  multi-room graph theater.
//
//  Per DOCTRINE §3.3.1 v1.6 the multi-room theater is rendered
//  as ONE MTKView with one Metal pipeline state — each room is
//  an `MTLViewport` rectangle within the same drawable. This
//  file is the pure layout calculator: given (drawable size,
//  room count), it returns rect tiles that the renderer will
//  use as `MTLViewport` per-tile arguments. Layouts follow the
//  doctrine table:
//
//    | Sessions | Layout                                |
//    |----------|---------------------------------------|
//    |    1     | 1 × 1 (single full-screen room)       |
//    |    2     | 2 × 1 landscape / 1 × 2 portrait      |
//    |    3     | 1 large + 2 stacked (vertical split)  |
//    |    4     | 2 × 2 quad                            |
//    |   5–6    | 3 × 2                                 |
//    |   7–9    | 3 × 3 (cap; further sessions queue)   |
//
//  The drill-in layout is a special case: the focused room
//  takes ~83 % of the width with a thin (~17 %) thumbnail strip
//  along the right edge for the other rooms.
//

import CoreGraphics
import Foundation

/// One tile in the theater layout. Coordinates are in points;
/// the renderer multiplies by the backing scale to derive the
/// pixel-space `MTLViewport`.
public struct RoomTileLayout: Equatable, Sendable {
    public let sessionId: String
    /// Tile rect in *points* (not pixels). The renderer scales
    /// to the drawable's backing factor for `MTLViewport`.
    public let frame: CGRect
    /// `true` when this tile is the drilled-in (focused)
    /// session — the renderer + UI use this to decide whether
    /// to render the full inspector chrome (drill-in only) or
    /// the simplified glance chrome (overview only).
    public let isFocused: Bool
    /// Z-order hint: 0 = main / focused tile, 1+ = thumbnail
    /// strip in drill-in mode. Used by SwiftUI overlays to
    /// stack chrome above the right tile.
    public let zHint: Int
}

/// Pure layout calculator. No SwiftUI / Metal types — easy to
/// unit-test.
public enum RoomTilingLayout {

    /// Minimum tile size before the layout falls back to a 3×3
    /// cap with carousel overflow per §3.3.1 v1.6.
    public static let minTileSide: CGFloat = 80

    /// Padding (in points) between tiles in the overview grid.
    public static let tileGap: CGFloat = 4

    /// Width of the drill-in mode's right-edge thumbnail strip
    /// (in points). Tile mascots are ~32 pt + chrome.
    public static let thumbnailStripWidth: CGFloat = 64

    /// Build the overview layout — full multi-tile grid, no
    /// focused tile.
    public static func overview(
        bounds: CGRect, rooms: [Room]
    ) -> [RoomTileLayout] {
        guard !rooms.isEmpty else { return [] }
        // Cap at 9 visible per §3.3.1; ≥10 sessions enter
        // carousel mode (out of S7 scope — we just clip to the
        // first 9 for now).
        let visible = Array(rooms.prefix(9))
        let cells = gridCells(for: visible.count, in: bounds, isLandscape: bounds.width >= bounds.height)
        return zip(visible, cells).map { (room, frame) in
            RoomTileLayout(
                sessionId: room.sessionId,
                frame: frame,
                isFocused: false,
                zHint: 0
            )
        }
    }

    /// Build the drill-in layout — focused session takes ~83 %
    /// of the width; remaining rooms render as thumbnails along
    /// the right edge per §3.3.3 v1.6.
    public static func drillIn(
        bounds: CGRect, rooms: [Room], focusedSessionId: String
    ) -> [RoomTileLayout] {
        guard !rooms.isEmpty else { return [] }
        // If only one session is active, drill-in IS overview
        // per §3.3.3 ("when only ONE session is active, drill-in
        // mode IS overview mode — no thumbnail strip").
        if rooms.count == 1 {
            return [
                RoomTileLayout(
                    sessionId: rooms[0].sessionId,
                    frame: bounds,
                    isFocused: true,
                    zHint: 0
                )
            ]
        }

        let stripW = thumbnailStripWidth
        let mainFrame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: max(bounds.width - stripW - tileGap, minTileSide),
            height: bounds.height
        )
        let stripX = mainFrame.maxX + tileGap
        let stripFrame = CGRect(
            x: stripX,
            y: bounds.minY,
            width: stripW,
            height: bounds.height
        )

        var tiles: [RoomTileLayout] = []
        if let focused = rooms.first(where: { $0.sessionId == focusedSessionId })
            ?? rooms.first
        {
            tiles.append(RoomTileLayout(
                sessionId: focused.sessionId,
                frame: mainFrame,
                isFocused: true,
                zHint: 0
            ))
            // Thumbnails for the other sessions, top-down.
            let others = rooms.filter { $0.sessionId != focused.sessionId }
            let thumbHeight: CGFloat = 56
            let perTile = thumbHeight + tileGap
            let visible = Array(others.prefix(Int((stripFrame.height / perTile).rounded(.down))))
            for (idx, r) in visible.enumerated() {
                let y = stripFrame.minY + CGFloat(idx) * perTile
                tiles.append(RoomTileLayout(
                    sessionId: r.sessionId,
                    frame: CGRect(
                        x: stripFrame.minX,
                        y: y,
                        width: stripFrame.width,
                        height: thumbHeight
                    ),
                    isFocused: false,
                    zHint: 1
                ))
            }
        }
        return tiles
    }

    // MARK: - Grid math

    /// Compute `count` cell rects within `bounds` per the
    /// §3.3.1 layout table.
    private static func gridCells(
        for count: Int, in bounds: CGRect, isLandscape: Bool
    ) -> [CGRect] {
        guard count > 0 else { return [] }
        switch count {
        case 1:
            return [bounds]
        case 2:
            return splitTwo(in: bounds, landscape: isLandscape)
        case 3:
            return splitThree(in: bounds, landscape: isLandscape)
        case 4:
            return uniformGrid(rows: 2, cols: 2, in: bounds)
        case 5, 6:
            return uniformGrid(rows: 2, cols: 3, in: bounds, fillCount: count)
        default:
            // 7–9: 3 × 3
            return uniformGrid(rows: 3, cols: 3, in: bounds, fillCount: count)
        }
    }

    private static func splitTwo(in bounds: CGRect, landscape: Bool) -> [CGRect] {
        if landscape {
            let w = (bounds.width - tileGap) / 2
            return [
                CGRect(x: bounds.minX, y: bounds.minY, width: w, height: bounds.height),
                CGRect(x: bounds.minX + w + tileGap, y: bounds.minY, width: w, height: bounds.height),
            ]
        } else {
            let h = (bounds.height - tileGap) / 2
            return [
                CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: h),
                CGRect(x: bounds.minX, y: bounds.minY + h + tileGap, width: bounds.width, height: h),
            ]
        }
    }

    private static func splitThree(in bounds: CGRect, landscape: Bool) -> [CGRect] {
        // §3.3.1: "1 + (1 × 2 stacked)" — the lead room takes
        // half the width / height, two stacked tiles fill the
        // other half.
        if landscape {
            let mainW = (bounds.width - tileGap) / 2
            let stackW = bounds.width - mainW - tileGap
            let stackH = (bounds.height - tileGap) / 2
            return [
                CGRect(x: bounds.minX, y: bounds.minY, width: mainW, height: bounds.height),
                CGRect(
                    x: bounds.minX + mainW + tileGap, y: bounds.minY,
                    width: stackW, height: stackH
                ),
                CGRect(
                    x: bounds.minX + mainW + tileGap, y: bounds.minY + stackH + tileGap,
                    width: stackW, height: stackH
                ),
            ]
        } else {
            let mainH = (bounds.height - tileGap) / 2
            let stackH = bounds.height - mainH - tileGap
            let stackW = (bounds.width - tileGap) / 2
            return [
                CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: mainH),
                CGRect(
                    x: bounds.minX, y: bounds.minY + mainH + tileGap,
                    width: stackW, height: stackH
                ),
                CGRect(
                    x: bounds.minX + stackW + tileGap, y: bounds.minY + mainH + tileGap,
                    width: stackW, height: stackH
                ),
            ]
        }
    }

    private static func uniformGrid(
        rows: Int, cols: Int, in bounds: CGRect, fillCount: Int? = nil
    ) -> [CGRect] {
        let cellW = (bounds.width - CGFloat(cols - 1) * tileGap) / CGFloat(cols)
        let cellH = (bounds.height - CGFloat(rows - 1) * tileGap) / CGFloat(rows)
        var rects: [CGRect] = []
        let limit = fillCount ?? (rows * cols)
        for r in 0..<rows {
            for c in 0..<cols {
                if rects.count >= limit { return rects }
                let x = bounds.minX + CGFloat(c) * (cellW + tileGap)
                let y = bounds.minY + CGFloat(r) * (cellH + tileGap)
                rects.append(CGRect(x: x, y: y, width: cellW, height: cellH))
            }
        }
        return rects
    }
}
