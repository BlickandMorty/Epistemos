import SwiftUI

/// Pixel-art companion renderer per Simulation v1.6 character-DNA + Invariant
/// I-16 (bit-perfect stepped pixels, no anti-aliasing). Each body family is
/// drawn into a logical 48×48 grid; cells are rendered as discrete squares
/// (floor/ceil to integer pixel boundaries) so the silhouette reads as 8-bit
/// pixel-art at the 96pt Farm node size.
///
/// The grid is canonical: Orb is a 32px stepped circle in 48×48; Block is a
/// 48×48 (Compact) or 64×48-stretched (Wide) silhouette; Sage is a 48×64
/// humanoid squished into the same 48×48 quad with discrete head/body/legs.
///
/// Animation: phase 0…1 drives the canonical state's frame index via
/// CompanionAnimationState.frameIndex; idle = ±1px drift / sway, walk =
/// alternating step. Reduce-motion snaps to the rest pose with the
/// "idle" badge per Invariant I-14.
struct CompanionAvatarGlyph: View {
    let kind: CompanionBodyKind
    let accent: Color
    var phase: CGFloat = 0
    var state: CompanionAnimationState = .idle
    var reduceMotionOverride: Bool? = nil
    var showsIdleBadge: Bool = false

    @Environment(\.accessibilityReduceMotion) private var environmentReduceMotion

    private var reduceMotion: Bool {
        reduceMotionOverride ?? environmentReduceMotion
    }

    private var clampedPhase: CGFloat {
        reduceMotion ? 0.0 : max(0.0, min(1.0, phase))
    }

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                let side = min(canvasSize.width, canvasSize.height)
                let rect = CGRect(
                    x: floor((canvasSize.width - side) * 0.5),
                    y: floor((canvasSize.height - side) * 0.5),
                    width: floor(side),
                    height: floor(side)
                )
                Self.drawHalo(context: &context, rect: rect, accent: accent, phase: clampedPhase)
                Self.drawBody(
                    context: &context,
                    rect: rect,
                    kind: kind,
                    accent: accent,
                    phase: clampedPhase,
                    state: reduceMotion ? .idle : state
                )
            }
            .drawingGroup()
            if showsIdleBadge {
                Text("idle")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .offset(y: 46)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Body dispatch

    private static func drawBody(
        context: inout GraphicsContext,
        rect: CGRect,
        kind: CompanionBodyKind,
        accent: Color,
        phase: CGFloat,
        state: CompanionAnimationState
    ) {
        let palette = Palette(family: kind.family, accent: accent)
        let frameOffset = stepOffset(phase: phase, state: state)
        switch kind.family {
        case .orb:
            drawOrb(context: &context, rect: rect, palette: palette, phase: phase, state: state, offset: frameOffset)
        case .block:
            drawBlock(
                context: &context,
                rect: rect,
                palette: palette,
                phase: phase,
                state: state,
                offset: frameOffset,
                aspect: kind.blockAspect ?? .compact,
                legs: kind.legStyle ?? .stubs,
                antennae: kind.antennaStyle ?? .none,
                eyeTreatment: kind.eyeTreatment ?? .filled
            )
        case .sage:
            drawSage(context: &context, rect: rect, palette: palette, phase: phase, state: state, offset: frameOffset)
        }
    }

    /// Per-state step offset (in logical-cell units) applied to the body's
    /// vertical/horizontal anchor. idle = ±1 cell breath; walk = alternating
    /// 1-cell bob; sleep = 1-cell down; success = 2-cell up; error = ±1
    /// horizontal jitter; spawn = staged reveal (handled per renderer);
    /// other states reuse idle's gentle breath until the Hermes state machine
    /// drives them explicitly.
    private static func stepOffset(phase: CGFloat, state: CompanionAnimationState) -> StepOffset {
        let frame = state.frameIndex(forPhase: Double(phase))
        switch state {
        case .idle:
            let v = (frame % 2 == 0) ? -1 : 0
            return StepOffset(dx: 0, dy: v, leftLeg: 0, rightLeg: 0)
        case .walk:
            let leftStep = (frame % 2 == 0) ? -1 : 0
            let rightStep = (frame % 2 == 0) ? 0 : -1
            let bob = (frame % 2 == 0) ? -1 : 0
            return StepOffset(dx: 0, dy: bob, leftLeg: leftStep, rightLeg: rightStep)
        case .sleep:
            return StepOffset(dx: 0, dy: 1, leftLeg: 0, rightLeg: 0)
        case .success:
            let lift = (frame < 2) ? -2 : 0
            return StepOffset(dx: 0, dy: lift, leftLeg: 0, rightLeg: 0)
        case .error:
            let h = (frame % 2 == 0) ? -1 : 1
            return StepOffset(dx: h, dy: 0, leftLeg: 0, rightLeg: 0)
        case .think, .speak, .tool, .recover, .spawn,
             .handoffGive, .handoffReceive, .retrieve, .gate:
            let v = (frame % 2 == 0) ? -1 : 0
            return StepOffset(dx: 0, dy: v, leftLeg: 0, rightLeg: 0)
        }
    }

    private struct StepOffset {
        let dx: Int
        let dy: Int
        let leftLeg: Int
        let rightLeg: Int
    }

    // MARK: - Halo (cosmetic glow ring; not pixel-art — Invariant I-16
    // applies to the body silhouette, the halo is a cosmetic glow per
    // Simulation §10.7 smooth category).

    private static func drawHalo(
        context: inout GraphicsContext,
        rect: CGRect,
        accent: Color,
        phase: CGFloat
    ) {
        let pulse = 0.72 + 0.18 * phase
        let halo = Path(ellipseIn: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04))
        context.fill(halo, with: .color(accent.opacity(0.10 + 0.06 * phase)))
        let inner = Path(ellipseIn: rect.insetBy(dx: rect.width * 0.18 * pulse, dy: rect.height * 0.18 * pulse))
        context.fill(inner, with: .color(accent.opacity(0.08)))
    }

    // MARK: - Orb

    /// Stepped 32-cell circle inside the 48-cell quad, per character-DNA/orb.md.
    /// Idle = ±1 cell vertical drift; walk = same drift but the orb glides
    /// (no bob — it has no legs to push off).
    private static func drawOrb(
        context: inout GraphicsContext,
        rect: CGRect,
        palette: Palette,
        phase: CGFloat,
        state: CompanionAnimationState,
        offset: StepOffset
    ) {
        let cx = 24
        let cy = 24 + offset.dy
        let radius = 16

        // Body disc (canonical pixel-art stepped circle).
        forEachCellInDisc(centerX: cx, centerY: cy, radius: radius) { x, y in
            fillCell(context: &context, rect: rect, x: x, y: y, color: palette.body)
        }

        // Accent rim (1-cell thick) around the body — the §10.4 cosmetic accent.
        forEachCellInRing(centerX: cx, centerY: cy, outerRadius: radius, innerRadius: radius - 1) { x, y in
            fillCell(context: &context, rect: rect, x: x, y: y, color: palette.accent)
        }

        // Closed-eye horizontal slit (canonical resting pose) — eye region is
        // the §6.1 GPT preset's "Closed" axis: a 1-cell-tall horizontal slit
        // just above vertical center. During `speak` the slit pulses (we
        // brighten it); during `gate` we make it 2-cells tall (the canonical
        // "awaiting" bright pose).
        let eyeY = cy - 3
        let eyeWidth = 6
        let eyeX0 = cx - eyeWidth / 2
        let eyeFill = (state == .gate) ? palette.eyeBright : palette.eye
        let eyeRows = (state == .gate) ? 2 : 1
        for row in 0..<eyeRows {
            for col in 0..<eyeWidth {
                fillCell(context: &context, rect: rect, x: eyeX0 + col, y: eyeY + row, color: eyeFill)
            }
        }

        // Speak-state ring pulse: an extra accent cell at the perimeter at top
        // and bottom — implies the §6.1 4-frame ring pulse in static form.
        if state == .speak {
            for x in (cx - radius - 1)...(cx + radius + 1) {
                fillCell(context: &context, rect: rect, x: x, y: cy - radius - 1, color: palette.eyeBright.opacity(0.6))
                fillCell(context: &context, rect: rect, x: x, y: cy + radius + 1, color: palette.eyeBright.opacity(0.6))
            }
        }
    }

    // MARK: - Block (Compact + Wide)

    private static func drawBlock(
        context: inout GraphicsContext,
        rect: CGRect,
        palette: Palette,
        phase: CGFloat,
        state: CompanionAnimationState,
        offset: StepOffset,
        aspect: CompanionBlockAspect,
        legs: CompanionLegStyle,
        antennae: CompanionAntennaStyle,
        eyeTreatment: CompanionEyeTreatment
    ) {
        let bodyWidth: Int
        let bodyHeight: Int
        let bodyTop: Int
        let bodyLeft: Int
        switch aspect {
        case .compact:
            bodyWidth = 32
            bodyHeight = 32
            bodyTop = 8
            bodyLeft = 8
        case .wide:
            bodyWidth = 42
            bodyHeight = 28
            bodyTop = 10
            bodyLeft = 3
        case .tall:
            bodyWidth = 28
            bodyHeight = 38
            bodyTop = 5
            bodyLeft = 10
        }

        let appliedTop = bodyTop + offset.dy
        let appliedLeft = bodyLeft + offset.dx

        // Antenna (drawn first so the body paints over its root).
        switch antennae {
        case .none:
            break
        case .single:
            // Single antenna at top-right per Block(Wide) DNA.
            let baseX = appliedLeft + bodyWidth - 8
            for row in 0..<6 {
                fillCell(context: &context, rect: rect, x: baseX, y: appliedTop - 6 + row, color: palette.accent)
            }
            fillCell(context: &context, rect: rect, x: baseX, y: appliedTop - 7, color: palette.eyeBright)
        case .double:
            for row in 0..<5 {
                fillCell(context: &context, rect: rect, x: appliedLeft + 6, y: appliedTop - 5 + row, color: palette.accent)
                fillCell(context: &context, rect: rect, x: appliedLeft + bodyWidth - 7, y: appliedTop - 5 + row, color: palette.accent)
            }
        }

        // Body rectangle (filled cells).
        for y in 0..<bodyHeight {
            for x in 0..<bodyWidth {
                fillCell(context: &context, rect: rect, x: appliedLeft + x, y: appliedTop + y, color: palette.body)
            }
        }

        // Vertical accent spine through the middle (per Block(Wide) DNA).
        if aspect == .wide {
            let spineX = appliedLeft + bodyWidth / 2
            for y in 0..<bodyHeight {
                fillCell(context: &context, rect: rect, x: spineX, y: appliedTop + y, color: palette.accent)
            }
        }

        // Belt accent for Compact (1-cell horizontal stripe at body midpoint).
        if aspect == .compact {
            let beltY = appliedTop + bodyHeight - 8
            for x in 0..<bodyWidth {
                fillCell(context: &context, rect: rect, x: appliedLeft + x, y: beltY, color: palette.accent)
            }
        }

        // Eyes (filled vs. negative-space).
        let eyeY = appliedTop + 8
        let eyeWidth = 4
        let eyeHeight = 3
        let leftEyeX = appliedLeft + bodyWidth / 4 - 2
        let rightEyeX = appliedLeft + (bodyWidth * 3 / 4) - 2
        switch eyeTreatment {
        case .filled:
            for row in 0..<eyeHeight {
                for col in 0..<eyeWidth {
                    fillCell(context: &context, rect: rect, x: leftEyeX + col, y: eyeY + row, color: palette.eye)
                    fillCell(context: &context, rect: rect, x: rightEyeX + col, y: eyeY + row, color: palette.eye)
                }
            }
        case .negativeSpace:
            // Punch through: paint the cosmetic theater background behind the
            // eyes. We approximate by erasing to a darker accent (the renderer
            // doesn't have direct access to the surface backdrop here).
            for row in 0..<eyeHeight {
                for col in 0..<eyeWidth {
                    fillCell(context: &context, rect: rect, x: leftEyeX + col, y: eyeY + row, color: Color.black.opacity(0.62))
                    fillCell(context: &context, rect: rect, x: rightEyeX + col, y: eyeY + row, color: Color.black.opacity(0.62))
                }
            }
        }

        // Mouth — small horizontal accent beneath the eyes (Compact only;
        // Wide reads via eye-cutout pulse per DNA).
        if aspect == .compact {
            let mouthY = eyeY + 6
            let mouthX0 = appliedLeft + bodyWidth / 2 - 3
            for col in 0..<6 {
                fillCell(context: &context, rect: rect, x: mouthX0 + col, y: mouthY, color: Color.black.opacity(0.46))
            }
        }

        // Legs.
        let legBaseY = appliedTop + bodyHeight
        switch legs {
        case .none:
            break
        case .stubs:
            // Two 4×6 stub legs separated by ~10 cells.
            drawLeg(
                context: &context, rect: rect,
                x: appliedLeft + bodyWidth / 4 - 2,
                y: legBaseY,
                width: 4, height: 5,
                offset: offset.leftLeg,
                color: palette.body
            )
            drawLeg(
                context: &context, rect: rect,
                x: appliedLeft + (bodyWidth * 3 / 4) - 2,
                y: legBaseY,
                width: 4, height: 5,
                offset: offset.rightLeg,
                color: palette.body
            )
        case .multi:
            // Four leg notches per Block(Wide) DNA.
            let notchWidth = 5
            let notchSpacing = bodyWidth / 4
            for i in 0..<4 {
                let nx = appliedLeft + i * notchSpacing + (notchSpacing - notchWidth) / 2
                let stepOff = (i % 2 == 0) ? offset.leftLeg : offset.rightLeg
                drawLeg(
                    context: &context, rect: rect,
                    x: nx,
                    y: legBaseY,
                    width: notchWidth, height: 4,
                    offset: stepOff,
                    color: palette.body
                )
            }
        }

        // Spawn-state staged reveal: erase top rows progressively for the
        // bottom-up reveal canon (Compact) or top-down reveal (Wide).
        if state == .spawn {
            let frame = state.frameIndex(forPhase: Double(phase))
            let revealRows = bodyHeight - (bodyHeight * (frame + 1) / 5)
            if revealRows > 0 {
                let isTopDown = aspect == .wide
                for row in 0..<revealRows {
                    let y = isTopDown ? appliedTop + row : appliedTop + bodyHeight - 1 - row
                    for x in 0..<bodyWidth {
                        fillCell(context: &context, rect: rect, x: appliedLeft + x, y: y, color: Color.black.opacity(0.0))
                    }
                }
            }
        }
    }

    private static func drawLeg(
        context: inout GraphicsContext,
        rect: CGRect,
        x: Int, y: Int,
        width: Int, height: Int,
        offset: Int,
        color: Color
    ) {
        for row in 0..<height {
            for col in 0..<width {
                fillCell(context: &context, rect: rect, x: x + col, y: y + row + offset, color: color)
            }
        }
    }

    // MARK: - Sage (humanoid)

    /// Discrete head + body + arms + legs per character-DNA/sage.md. The
    /// canonical Sage bounding box is 48×64; we squish into the 48×48 quad
    /// while preserving the head/body/arms/legs proportions.
    private static func drawSage(
        context: inout GraphicsContext,
        rect: CGRect,
        palette: Palette,
        phase: CGFloat,
        state: CompanionAnimationState,
        offset: StepOffset
    ) {
        let headSize = 10
        let bodyWidth = 24
        let bodyHeight = 22
        let baseTop = 4 + offset.dy
        let baseLeft = 24 - bodyWidth / 2

        // Head (centered horizontally).
        let headLeft = 24 - headSize / 2
        for y in 0..<headSize {
            for x in 0..<headSize {
                fillCell(context: &context, rect: rect, x: headLeft + x, y: baseTop + y, color: palette.body)
            }
        }
        // Eye highlights (two 2×1 cells).
        let eyeY = baseTop + 4
        for col in 0..<2 {
            fillCell(context: &context, rect: rect, x: headLeft + 2 + col, y: eyeY, color: palette.eye)
            fillCell(context: &context, rect: rect, x: headLeft + headSize - 4 + col, y: eyeY, color: palette.eye)
        }

        // Neck (2 cells wide).
        let neckTop = baseTop + headSize
        for x in 0..<2 {
            fillCell(context: &context, rect: rect, x: 23 + x, y: neckTop, color: palette.body)
        }

        // Body (robe).
        let bodyTop = neckTop + 1
        for y in 0..<bodyHeight {
            for x in 0..<bodyWidth {
                fillCell(context: &context, rect: rect, x: baseLeft + x, y: bodyTop + y, color: palette.body)
            }
        }

        // Belt accent (1-cell horizontal stripe at body midpoint).
        let beltY = bodyTop + bodyHeight / 2
        for x in 0..<bodyWidth {
            fillCell(context: &context, rect: rect, x: baseLeft + x, y: beltY, color: palette.accent)
        }

        // Arms (3 cells wide × 8 cells tall, hanging from body's upper edge).
        let armTop = bodyTop + 2
        let armHeight = 8
        for y in 0..<armHeight {
            for col in 0..<3 {
                fillCell(context: &context, rect: rect, x: baseLeft - 3 + col, y: armTop + y, color: palette.body)
                fillCell(context: &context, rect: rect, x: baseLeft + bodyWidth + col, y: armTop + y, color: palette.body)
            }
        }

        // Legs (5 cells wide × 6 cells tall).
        let legTop = bodyTop + bodyHeight
        let legHeight = 6
        let legWidth = 5
        for y in 0..<legHeight {
            for col in 0..<legWidth {
                fillCell(context: &context, rect: rect, x: 24 - legWidth - 1 + col, y: legTop + y + offset.leftLeg, color: palette.body)
                fillCell(context: &context, rect: rect, x: 24 + 1 + col, y: legTop + y + offset.rightLeg, color: palette.body)
            }
        }

        // State accents.
        if state == .think {
            // "Hand to chin" — extra accent cell near the head's right side.
            for col in 0..<2 {
                fillCell(context: &context, rect: rect, x: headLeft + headSize + col, y: baseTop + headSize - 2, color: palette.accent)
            }
        }
        if state == .success {
            // Raised right arm tip: 1-cell accent above the arm's baseline.
            for y in 0..<3 {
                fillCell(context: &context, rect: rect, x: baseLeft + bodyWidth + 1, y: armTop - 3 + y, color: palette.eyeBright)
            }
        }
    }

    // MARK: - Pixel-cell primitives

    /// 48-cell logical pixel grid. The Farm renders companions at 96pt nodes
    /// → 2pt per cell at 1× scale; Retina paints each cell as 4 device
    /// pixels. Floor/ceil keeps cell edges integer-aligned per Invariant I-16.
    private static let gridSize: Int = 48

    private static func fillCell(
        context: inout GraphicsContext,
        rect: CGRect,
        x: Int,
        y: Int,
        color: Color
    ) {
        guard x >= 0, x < gridSize, y >= 0, y < gridSize else { return }
        let cellWidth = rect.width / CGFloat(gridSize)
        let cellHeight = rect.height / CGFloat(gridSize)
        let cell = CGRect(
            x: floor(rect.minX + cellWidth * CGFloat(x)),
            y: floor(rect.minY + cellHeight * CGFloat(y)),
            width: ceil(cellWidth),
            height: ceil(cellHeight)
        )
        context.fill(Path(cell), with: .color(color))
    }

    /// Stepped pixel-art disc (canonical pixel-art circle algorithm). Each
    /// cell is "in" iff its center is within radius² of the center; no
    /// anti-aliased edges per Invariant I-16.
    private static func forEachCellInDisc(
        centerX: Int,
        centerY: Int,
        radius: Int,
        callback: (Int, Int) -> Void
    ) {
        let r2 = radius * radius
        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy <= r2 {
                    callback(centerX + dx, centerY + dy)
                }
            }
        }
    }

    /// Stepped pixel-art ring (1+ cells thick).
    private static func forEachCellInRing(
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

    // MARK: - Palette

    /// Per-family canonical palette per character-DNA. The Farm's preset bodies
    /// derive Body/Accent/Eye from the entry's accent color; canonical preset
    /// hexes (Claude warm `#D97757`, Orb neutral `#9C9C9C`, etc.) are applied
    /// as the *family default* when the entry's accent is nil.
    private struct Palette {
        let body: Color
        let accent: Color
        let eye: Color
        let eyeBright: Color

        init(family: CompanionBodyFamily, accent base: Color) {
            switch family {
            case .orb:
                // Canonical orb palette: neutral grey body + bluish-grey accent.
                // We tint slightly toward the entry accent so per-companion
                // colour identity still reads.
                self.body = base.opacity(0.78)
                self.accent = base.opacity(0.55)
                self.eye = base.opacity(0.92)
                self.eyeBright = base.opacity(1.0)
            case .block:
                self.body = base.opacity(0.86)
                self.accent = base.opacity(0.64)
                self.eye = Color.black.opacity(0.62)
                self.eyeBright = base.opacity(1.0)
            case .sage:
                self.body = base.opacity(0.82)
                self.accent = base.opacity(0.62)
                self.eye = Color.black.opacity(0.58)
                self.eyeBright = base.opacity(0.95)
            }
        }
    }
}

#if DEBUG
#Preview("Companion Avatar Grammar — Pixel Art") {
    HStack(spacing: 18) {
        ForEach(CompanionBodyKind.creationPresets, id: \.self) { kind in
            VStack(spacing: 6) {
                CompanionAvatarGlyph(kind: kind, accent: .cyan, phase: 0.6, state: .idle)
                    .frame(width: 96, height: 96)
                CompanionAvatarGlyph(kind: kind, accent: .orange, phase: 0.3, state: .walk)
                    .frame(width: 96, height: 96)
            }
        }
    }
    .padding(32)
    .background(Color.black.opacity(0.86))
}
#endif
