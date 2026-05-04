import SwiftUI

/// Hermes graph faculty placement from Simulation v1.6 §8.1.
/// The glyph is rendered above the graph plane at z+1 and is intentionally
/// not part of the Landing Farm companion body picker.
struct HermesGraphFacultyGlyph: View {
    static let zPlusOne: CGFloat = 1

    var accent: Color = Color(red: 0.49, green: 0.23, blue: 0.93)
    var phase: CGFloat = 0.5

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let rect = CGRect(
                x: (size.width - side) * 0.5,
                y: (size.height - side) * 0.5,
                width: side,
                height: side
            ).insetBy(dx: side * 0.05, dy: side * 0.05)

            drawFacultyHalo(context: &context, rect: rect)
            drawStaff(context: &context, rect: rect)
            drawWings(context: &context, rect: rect)
            drawSnake(context: &context, rect: rect)
        }
        .accessibilityLabel("Hermes graph faculty")
        .accessibilityHidden(false)
    }

    private func drawFacultyHalo(context: inout GraphicsContext, rect: CGRect) {
        let halo = Path(ellipseIn: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04))
        context.fill(halo, with: .color(accent.opacity(0.10 + 0.04 * phase)))
    }

    private func drawStaff(context: inout GraphicsContext, rect: CGRect) {
        var staff = Path()
        staff.move(to: point(rect, 0.50, 0.16))
        staff.addLine(to: point(rect, 0.50, 0.86))
        context.stroke(
            staff,
            with: .color(accent.opacity(0.74)),
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
            with: .color(accent.opacity(0.66)),
            style: StrokeStyle(lineWidth: max(1.5, rect.width * 0.026), lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            wing,
            with: .color(.white.opacity(0.16)),
            style: StrokeStyle(lineWidth: max(1, rect.width * 0.010), lineCap: .round, lineJoin: .round)
        )
    }

    private func drawSnake(context: inout GraphicsContext, rect: CGRect) {
        let sway = (phase - 0.5) * 0.06
        var snake = Path()
        snake.move(to: point(rect, 0.39, 0.25))
        snake.addCurve(
            to: point(rect, 0.60, 0.43),
            control1: point(rect, 0.16, 0.34 + sway),
            control2: point(rect, 0.77, 0.33 - sway)
        )
        snake.addCurve(
            to: point(rect, 0.40, 0.61),
            control1: point(rect, 0.46, 0.50),
            control2: point(rect, 0.18, 0.51)
        )
        snake.addCurve(
            to: point(rect, 0.62, 0.78),
            control1: point(rect, 0.56, 0.68),
            control2: point(rect, 0.76, 0.66)
        )
        context.stroke(
            snake,
            with: .color(accent.opacity(0.94)),
            style: StrokeStyle(lineWidth: max(2, rect.width * 0.044), lineCap: .round, lineJoin: .round)
        )

        let head = Path(ellipseIn: unitRect(rect, x: 0.33, y: 0.20, width: 0.13, height: 0.11))
        context.fill(head, with: .color(accent.opacity(0.96)))
        context.fill(Path(ellipseIn: unitRect(rect, x: 0.385, y: 0.235, width: 0.025, height: 0.025)), with: .color(.black.opacity(0.65)))
    }

    private func point(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }

    private func unitRect(
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
#Preview("Hermes Graph Faculty") {
    HermesGraphFacultyGlyph(phase: 0.65)
        .frame(width: 128, height: 128)
        .padding(28)
        .background(Color.black.opacity(0.86))
}
#endif
