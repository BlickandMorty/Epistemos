import SwiftUI

/// Native T6 avatar grammar for canonical Farm companion body families.
/// This is the visible creature layer; SF Symbols remain fine for chrome, but
/// companion bodies are drawn here so the Farm has a real body vocabulary.
struct CompanionAvatarGlyph: View {
    let kind: CompanionBodyKind
    let accent: Color
    var phase: CGFloat = 0
    var reduceMotionOverride: Bool? = nil
    var showsIdleBadge: Bool = false

    @Environment(\.accessibilityReduceMotion) private var environmentReduceMotion

    private var reduceMotion: Bool {
        reduceMotionOverride ?? environmentReduceMotion
    }

    private var pose: CGFloat {
        reduceMotion ? 0.5 : phase
    }

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                let side = min(canvasSize.width, canvasSize.height)
                let rect = CGRect(
                    x: (canvasSize.width - side) * 0.5,
                    y: (canvasSize.height - side) * 0.5,
                    width: side,
                    height: side
                )
                let breath = 0.96 + 0.05 * pose
                let bodyRect = rect.insetBy(
                    dx: rect.width * (0.05 + (1.0 - breath) * 0.4),
                    dy: rect.height * (0.05 - (1.0 - breath) * 0.2)
                )

                Self.drawHalo(context: &context, rect: rect, accent: accent, phase: pose)
                switch kind.family {
                case .block:
                    Self.drawBlock(
                        context: &context,
                        rect: bodyRect,
                        accent: accent,
                        phase: pose,
                        aspect: kind.blockAspect ?? .compact,
                        legs: kind.legStyle ?? .stubs,
                        antennae: kind.antennaStyle ?? .none,
                        eyeTreatment: kind.eyeTreatment ?? .filled
                    )
                case .sage:
                    Self.drawSage(context: &context, rect: bodyRect, accent: accent, phase: pose)
                case .orb:
                    Self.drawOrb(context: &context, rect: bodyRect, accent: accent, phase: pose)
                }
            }
            if showsIdleBadge {
                Text("idle")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .offset(y: 46)
            }
        }
        .accessibilityHidden(true)
    }

    private static func drawHalo(
        context: inout GraphicsContext,
        rect: CGRect,
        accent: Color,
        phase: CGFloat
    ) {
        let pulse = 0.72 + 0.18 * phase
        let halo = Path(ellipseIn: rect.insetBy(dx: rect.width * 0.03, dy: rect.height * 0.03))
        context.fill(halo, with: .color(accent.opacity(0.10 + 0.08 * phase)))
        let inner = Path(ellipseIn: rect.insetBy(dx: rect.width * 0.16 * pulse, dy: rect.height * 0.16 * pulse))
        context.fill(inner, with: .color(accent.opacity(0.08)))
    }

    private static func drawBlock(
        context: inout GraphicsContext,
        rect: CGRect,
        accent: Color,
        phase: CGFloat,
        aspect: CompanionBlockAspect,
        legs: CompanionLegStyle,
        antennae: CompanionAntennaStyle,
        eyeTreatment: CompanionEyeTreatment
    ) {
        let squash = rect.height * (0.02 * phase)
        let bodyWidth: CGFloat
        let bodyHeight: CGFloat
        switch aspect {
        case .compact:
            bodyWidth = 0.60
            bodyHeight = 0.56
        case .wide:
            bodyWidth = 0.72
            bodyHeight = 0.50
        case .tall:
            bodyWidth = 0.52
            bodyHeight = 0.66
        }
        let body = Path(
            roundedRect: CGRect(
                x: rect.minX + rect.width * ((1.0 - bodyWidth) * 0.5),
                y: rect.minY + rect.height * (0.22 + 0.02 * phase),
                width: rect.width * bodyWidth,
                height: rect.height * bodyHeight - squash
            ),
            cornerRadius: rect.width * 0.13
        )
        context.fill(body, with: .color(accent.opacity(0.82)))
        context.stroke(body, with: .color(.white.opacity(0.20)), lineWidth: max(1, rect.width * 0.025))
        switch eyeTreatment {
        case .filled:
            drawFace(context: &context, rect: rect, eyeY: 0.44, mouthY: 0.57, accent: accent, phase: phase)
        case .negativeSpace:
            drawNegativeSpaceFace(context: &context, rect: rect, eyeY: 0.43, mouthY: 0.56, phase: phase)
        }
        switch legs {
        case .none:
            break
        case .stubs:
            drawFeet(context: &context, rect: rect, leftX: 0.34, rightX: 0.66, y: 0.80, accent: accent, phase: phase)
        case .multi:
            for (index, x) in [0.30, 0.43, 0.57, 0.70].enumerated() {
                drawFoot(
                    context: &context,
                    rect: rect,
                    x: CGFloat(x),
                    y: 0.80,
                    accent: accent,
                    phase: phase,
                    isLeadingStep: index.isMultiple(of: 2)
                )
            }
        }
        switch antennae {
        case .none:
            break
        case .single:
            drawAntenna(context: &context, rect: rect, rootX: 0.50, tipX: 0.61, accent: accent, phase: phase)
        case .double:
            drawAntenna(context: &context, rect: rect, rootX: 0.44, tipX: 0.34, accent: accent, phase: phase)
            drawAntenna(context: &context, rect: rect, rootX: 0.56, tipX: 0.66, accent: accent, phase: phase)
        }
    }

    private static func drawSage(
        context: inout GraphicsContext,
        rect: CGRect,
        accent: Color,
        phase: CGFloat
    ) {
        let sway = (phase - 0.5) * rect.width * 0.05
        var robe = Path()
        robe.move(to: point(rect, 0.50, 0.16))
        robe.addCurve(
            to: point(rect, 0.22, 0.82),
            control1: point(rect, 0.30, 0.28),
            control2: CGPoint(x: point(rect, 0.22, 0.58).x + sway, y: point(rect, 0.22, 0.58).y)
        )
        robe.addQuadCurve(to: point(rect, 0.78, 0.82), control: point(rect, 0.50, 0.92))
        robe.addCurve(
            to: point(rect, 0.50, 0.16),
            control1: CGPoint(x: point(rect, 0.78, 0.58).x + sway, y: point(rect, 0.78, 0.58).y),
            control2: point(rect, 0.70, 0.28)
        )
        context.fill(robe, with: .color(accent.opacity(0.78)))
        context.stroke(robe, with: .color(.white.opacity(0.18)), lineWidth: max(1, rect.width * 0.023))

        let hood = Path(ellipseIn: unitRect(rect, x: 0.32, y: 0.20, width: 0.36, height: 0.32))
        context.fill(hood, with: .color(accent.opacity(0.86)))
        context.fill(Path(ellipseIn: unitRect(rect, x: 0.39, y: 0.30, width: 0.22, height: 0.17)), with: .color(.black.opacity(0.28)))
        drawFace(context: &context, rect: rect, eyeY: 0.38, mouthY: 0.49, accent: accent, phase: phase)
        drawFeet(context: &context, rect: rect, leftX: 0.39, rightX: 0.61, y: 0.84, accent: accent, phase: phase)
    }

    private static func drawOrb(
        context: inout GraphicsContext,
        rect: CGRect,
        accent: Color,
        phase: CGFloat
    ) {
        let lift = (0.5 - phase) * rect.height * 0.03
        let bodyRect = CGRect(
            x: rect.minX + rect.width * 0.18,
            y: rect.minY + rect.height * 0.22 + lift,
            width: rect.width * 0.64,
            height: rect.height * 0.62
        )
        let body = Path(ellipseIn: bodyRect)
        context.fill(body, with: .color(accent.opacity(0.80)))
        context.fill(Path(ellipseIn: bodyRect.insetBy(dx: bodyRect.width * 0.16, dy: bodyRect.height * 0.18)), with: .color(.white.opacity(0.12)))
        context.stroke(body, with: .color(.white.opacity(0.22)), lineWidth: max(1, rect.width * 0.024))
        drawAntenna(context: &context, rect: rect, rootX: 0.50, tipX: 0.60, accent: accent, phase: phase)
        drawFace(context: &context, rect: rect, eyeY: 0.48, mouthY: 0.61, accent: accent, phase: phase)
        drawFeet(context: &context, rect: rect, leftX: 0.38, rightX: 0.62, y: 0.83, accent: accent, phase: phase)
    }

    private static func drawFace(
        context: inout GraphicsContext,
        rect: CGRect,
        eyeY: CGFloat,
        mouthY: CGFloat,
        accent: Color,
        phase: CGFloat
    ) {
        drawEye(context: &context, center: point(rect, 0.41, eyeY), radius: rect.width * 0.028)
        drawEye(context: &context, center: point(rect, 0.59, eyeY), radius: rect.width * 0.028)
        var mouth = Path()
        mouth.move(to: point(rect, 0.43, mouthY))
        mouth.addQuadCurve(
            to: point(rect, 0.57, mouthY),
            control: point(rect, 0.50, mouthY + 0.05 + 0.02 * phase)
        )
        context.stroke(mouth, with: .color(.black.opacity(0.46)), style: StrokeStyle(lineWidth: max(1, rect.width * 0.017), lineCap: .round))
    }

    private static func drawNegativeSpaceFace(
        context: inout GraphicsContext,
        rect: CGRect,
        eyeY: CGFloat,
        mouthY: CGFloat,
        phase: CGFloat
    ) {
        let eyeSize = CGSize(width: rect.width * 0.08, height: rect.height * 0.055)
        for x in [0.40, 0.60] {
            let eye = CGRect(
                x: point(rect, CGFloat(x), eyeY).x - eyeSize.width * 0.5,
                y: point(rect, CGFloat(x), eyeY).y - eyeSize.height * 0.5,
                width: eyeSize.width,
                height: eyeSize.height
            )
            context.fill(Path(roundedRect: eye, cornerRadius: eyeSize.height * 0.45), with: .color(.black.opacity(0.42)))
        }
        var mouth = Path()
        mouth.move(to: point(rect, 0.43, mouthY))
        mouth.addQuadCurve(
            to: point(rect, 0.57, mouthY),
            control: point(rect, 0.50, mouthY + 0.035 + 0.012 * phase)
        )
        context.stroke(mouth, with: .color(.black.opacity(0.34)), style: StrokeStyle(lineWidth: max(1, rect.width * 0.014), lineCap: .round))
    }

    private static func drawEye(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let eye = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: eye), with: .color(.black.opacity(0.62)))
        let glintRadius = radius * 0.32
        let glint = CGRect(x: center.x - glintRadius * 0.4, y: center.y - glintRadius * 1.2, width: glintRadius, height: glintRadius)
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.72)))
    }

    private static func drawFeet(
        context: inout GraphicsContext,
        rect: CGRect,
        leftX: CGFloat,
        rightX: CGFloat,
        y: CGFloat,
        accent: Color,
        phase: CGFloat
    ) {
        drawFoot(context: &context, rect: rect, x: leftX, y: y, accent: accent, phase: phase, isLeadingStep: true)
        drawFoot(context: &context, rect: rect, x: rightX, y: y, accent: accent, phase: phase, isLeadingStep: false)
    }

    private static func drawFoot(
        context: inout GraphicsContext,
        rect: CGRect,
        x: CGFloat,
        y: CGFloat,
        accent: Color,
        phase: CGFloat,
        isLeadingStep: Bool
    ) {
        let direction: CGFloat = isLeadingStep ? 1 : -1
        let step = (phase - 0.5) * rect.height * 0.018 * direction
        let footSize = CGSize(width: rect.width * 0.14, height: rect.height * 0.065)
        let foot = CGRect(
            x: point(rect, x, y).x - footSize.width * 0.5,
            y: point(rect, x, y).y - footSize.height * 0.5 + step,
            width: footSize.width,
            height: footSize.height
        )
        context.fill(Path(ellipseIn: foot), with: .color(accent.opacity(0.62)))
    }

    private static func drawAntenna(
        context: inout GraphicsContext,
        rect: CGRect,
        rootX: CGFloat,
        tipX: CGFloat,
        accent: Color,
        phase: CGFloat
    ) {
        var antenna = Path()
        antenna.move(to: point(rect, rootX, 0.24))
        antenna.addQuadCurve(to: point(rect, tipX + 0.03 * phase, 0.11), control: point(rect, (rootX + tipX) * 0.5, 0.15))
        context.stroke(antenna, with: .color(accent.opacity(0.65)), style: StrokeStyle(lineWidth: max(1, rect.width * 0.018), lineCap: .round))
        context.fill(Path(ellipseIn: unitRect(rect, x: tipX - 0.03 + 0.03 * phase, y: 0.075, width: 0.08, height: 0.08)), with: .color(accent.opacity(0.80)))
    }

    private static func point(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }

    private static func unitRect(
        _ rect: CGRect,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> CGRect {
        CGRect(
            x: rect.minX + rect.width * x,
            y: rect.minY + rect.height * y,
            width: rect.width * width,
            height: rect.height * height
        )
    }
}

#if DEBUG
#Preview("Companion Avatar Grammar") {
    HStack(spacing: 18) {
        ForEach(CompanionBodyKind.creationPresets, id: \.self) { kind in
            CompanionAvatarGlyph(kind: kind, accent: .cyan, phase: 0.6)
                .frame(width: 96, height: 96)
        }
    }
    .padding(32)
    .background(Color.black.opacity(0.86))
}
#endif
