import SwiftUI

/// Hermes graph faculty placement from Simulation v1.6 §8.1 — the canonical
/// "intelligent serpent that reads" rendered above the graph plane (z+1)
/// per character-DNA/hermes_snake.md.
///
/// The snake body is drawn as a stepped pixel-art coil per Invariant I-16.
/// The supporting chrome (halo, staff, wings) stays smooth — those are
/// §10.7 cosmetic glow elements, not part of the snake body atlas.
///
/// The §5.4 Hermes preset locks the palette: body `#D4AF37` gold,
/// accent `#A07028` bronze stripe, eye `#FFCC00` gleam. The §6.1 Custom
/// wizard explicitly does NOT allow palette override for Hermes.
struct HermesGraphFacultyGlyph: View {
    static let zPlusOne: CGFloat = 1

    /// Canonical Hermes gold palette per character-DNA/hermes_snake.md
    /// (the §5.4 preset table; not user-overridable by §6.1 contract).
    static let bodyGold = Color(red: 0xD4 / 255.0, green: 0xAF / 255.0, blue: 0x37 / 255.0)
    static let accentBronze = Color(red: 0xA0 / 255.0, green: 0x70 / 255.0, blue: 0x28 / 255.0)
    static let eyeYellow = Color(red: 0xFF / 255.0, green: 0xCC / 255.0, blue: 0x00 / 255.0)

    var phase: CGFloat = 0.5

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let rect = CGRect(
                x: floor((size.width - side) * 0.5),
                y: floor((size.height - side) * 0.5),
                width: floor(side),
                height: floor(side)
            ).insetBy(dx: floor(side * 0.05), dy: floor(side * 0.05))

            drawFacultyHalo(context: &context, rect: rect)
            drawStaff(context: &context, rect: rect)
            drawWings(context: &context, rect: rect)
            drawSnake(context: &context, rect: rect, phase: phase)
        }
        .drawingGroup()
        .accessibilityLabel("Hermes graph faculty")
        .accessibilityHidden(false)
    }

    // MARK: - Smooth chrome (§10.7 cosmetic — not part of snake body atlas)

    private func drawFacultyHalo(context: inout GraphicsContext, rect: CGRect) {
        let halo = Path(ellipseIn: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04))
        context.fill(halo, with: .color(Self.bodyGold.opacity(0.10 + 0.04 * phase)))
    }

    private func drawStaff(context: inout GraphicsContext, rect: CGRect) {
        var staff = Path()
        staff.move(to: point(rect, 0.50, 0.16))
        staff.addLine(to: point(rect, 0.50, 0.86))
        context.stroke(
            staff,
            with: .color(Self.accentBronze.opacity(0.74)),
            style: StrokeStyle(lineWidth: max(2, rect.width * 0.035), lineCap: .round)
        )
    }

    private func drawWings(context: inout GraphicsContext, rect: CGRect) {
        drawWing(context: &context, rect: rect, side: -1)
        drawWing(context: &context, rect: rect, side: 1)
    }

    private func drawWing(context: inout GraphicsContext, rect: CGRect, side: CGFloat) {
        var wing = Path()
        wing.move(to: point(rect, 0.50 + side * 0.04, 0.29))
        wing.addCurve(
            to: point(rect, 0.50 + side * 0.31, 0.22),
            control1: point(rect, 0.50 + side * 0.13, 0.16),
            control2: point(rect, 0.50 + side * 0.25, 0.16)
        )
        wing.addCurve(
            to: point(rect, 0.50 + side * 0.15, 0.40),
            control1: point(rect, 0.50 + side * 0.26, 0.32),
            control2: point(rect, 0.50 + side * 0.19, 0.39)
        )
        context.stroke(
            wing,
            with: .color(Self.bodyGold.opacity(0.66)),
            style: StrokeStyle(lineWidth: max(1.5, rect.width * 0.026), lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            wing,
            with: .color(.white.opacity(0.16)),
            style: StrokeStyle(lineWidth: max(1, rect.width * 0.010), lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Pixel-art snake body (Invariant I-16)

    /// Three-coil pixel-art spiral per character-DNA. Three rings stacked
    /// vertically with 2-cell gaps; head emerges top-right, tail bottom-left;
    /// body segmented every 4 cells with a 1-cell-darker bronze stripe.
    private func drawSnake(context: inout GraphicsContext, rect: CGRect, phase: CGFloat) {
        // Idle hover: ±1 cell vertical drift sampled from continuous phase.
        let driftCell = (phase < 0.5) ? -1 : 0

        // Three coils, stacked. Each coil is a stepped circle ring (outer 6 / inner 4).
        let coilCenterX = 24
        let coilOuter = 6
        let coilInner = 4
        let coils = [
            (cx: coilCenterX - 2, cy: 14 + driftCell),
            (cx: coilCenterX, cy: 24 + driftCell),
            (cx: coilCenterX + 2, cy: 34 + driftCell),
        ]

        // Body coils (gold), each with a 1-cell-darker bronze accent stripe
        // segmented every 4 cells per the DNA stripe contract.
        for (index, coil) in coils.enumerated() {
            forEachCellInRing(
                centerX: coil.cx,
                centerY: coil.cy,
                outerRadius: coilOuter,
                innerRadius: coilInner
            ) { x, y in
                let stripe = (x + y + index * 2) % 4 == 0
                fillCell(
                    context: &context,
                    rect: rect,
                    x: x,
                    y: y,
                    color: stripe ? Self.accentBronze : Self.bodyGold
                )
            }
        }

        // Head emerges from the top-right of the top coil — a 6×6 square
        // with two 1×3 slit eyes per the §5.4 Hermes "Slit" eye style.
        let headX = coils[0].cx + coilOuter - 1
        let headY = coils[0].cy - coilOuter + 1
        for y in 0..<6 {
            for x in 0..<6 {
                fillCell(context: &context, rect: rect, x: headX + x, y: headY + y, color: Self.bodyGold)
            }
        }
        // Slit eyes (each 3 cells wide × 1 cell tall).
        for col in 0..<3 {
            fillCell(context: &context, rect: rect, x: headX + 1 + col, y: headY + 2, color: Self.eyeYellow)
            fillCell(context: &context, rect: rect, x: headX + 1 + col, y: headY + 4, color: Self.eyeYellow)
        }

        // Tail emerges bottom-left of the bottom coil — a 1-cell-thick
        // 4-cell-long taper.
        let tailX = coils[2].cx - coilOuter
        let tailY = coils[2].cy + coilOuter - 1
        for delta in 0..<4 {
            fillCell(context: &context, rect: rect, x: tailX - delta, y: tailY + delta, color: Self.bodyGold)
        }
    }

    // MARK: - Pixel-cell primitives (mirrors CompanionAvatarGlyph for
    // visual cohesion across all simulation-theater sprites).

    private static let gridSize: Int = 48

    private func fillCell(
        context: inout GraphicsContext,
        rect: CGRect,
        x: Int,
        y: Int,
        color: Color
    ) {
        guard x >= 0, x < Self.gridSize, y >= 0, y < Self.gridSize else { return }
        let cellWidth = rect.width / CGFloat(Self.gridSize)
        let cellHeight = rect.height / CGFloat(Self.gridSize)
        let cell = CGRect(
            x: floor(rect.minX + cellWidth * CGFloat(x)),
            y: floor(rect.minY + cellHeight * CGFloat(y)),
            width: ceil(cellWidth),
            height: ceil(cellHeight)
        )
        context.fill(Path(cell), with: .color(color))
    }

    private func forEachCellInRing(
        centerX: Int,
        centerY: Int,
        outerRadius: Int,
        innerRadius: Int,
        callback: (Int, Int) -> Void
    ) {
        let outer2 = outerRadius * outerRadius
        let inner2 = innerRadius * innerRadius
        for dy in -outerRadius...outerRadius {
            for dx in -outerRadius...outerRadius {
                let d2 = dx * dx + dy * dy
                if d2 <= outer2 && d2 > inner2 {
                    callback(centerX + dx, centerY + dy)
                }
            }
        }
    }

    // MARK: - Smooth-coordinate helpers (used by chrome, not snake atlas).

    private func point(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }
}

#if DEBUG
#Preview("Hermes Graph Faculty — Pixel Coil") {
    HStack(spacing: 24) {
        HermesGraphFacultyGlyph(phase: 0.25)
            .frame(width: 128, height: 128)
        HermesGraphFacultyGlyph(phase: 0.75)
            .frame(width: 128, height: 128)
    }
    .padding(28)
    .background(Color.black.opacity(0.86))
}
#endif
