import SwiftUI

// MARK: - Shaped Graph Boundary
//
// Experimental, opt-in via Settings → Appearance → Shaped Graph (experimental).
// Renders a soft shape-blur overlay over the graph canvas so the user sees a
// "frameless" liquid-glass region instead of an obvious window.
//
// Per user direction 2026-05-19, the shape matches the existing
// `ShapeBoundKind` physics constraint (`GraphState.shapeBoundKind` —
// circle / square / triangle / hexagon / star, size `shapeBoundRadius`).
// The physics engine already keeps nodes inside that boundary, so this
// overlay just renders the SAME shape statically — no per-frame hull
// computation, no recomputation as nodes drift. Performance stays cheap.
//
// In note / folder routes the shape morphs into a rounded rectangle sized
// to the inline editor.
//
// The shape is filled with `.ultraThinMaterial` and masked so the perimeter
// fades to transparent — the boundary dissolves into the desktop instead of
// showing a hard edge.

struct ShapedGraphBoundaryHost: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    /// When experimental mode is on we treat `.off` as `.circle` per user
    /// direction 2026-05-19 — the shape setting acts as if it were
    /// constantly on, defaulting to a circle. The user can switch to
    /// square / triangle / hexagon / star via the existing Shape controls
    /// in the graph's floating toolbar.
    private var effectiveShapeKind: ShapeBoundKind {
        if ui.shapedGraphExperimental && graphState.shapeBoundKind == .off {
            return .circle
        }
        return graphState.shapeBoundKind
    }

    var body: some View {
        GeometryReader { proxy in
            ShapedGraphBoundaryView(
                enabled: ui.shapedGraphExperimental,
                theme: theme,
                route: graphState.currentRoute,
                shapeKind: effectiveShapeKind,
                shapeRadius: CGFloat(graphState.shapeBoundRadius),
                availableSize: proxy.size
            )
        }
        .allowsHitTesting(false)
        .onAppear {
            // Deferred to next runloop tick — mutating GraphState
            // synchronously inside onAppear during the first render pass
            // triggered SwiftUI's "invalid reuse after initialization
            // failure" because the physics shape-change cascades through
            // the renderer + state observers while the view tree is still
            // being initialized.
            Task { @MainActor in autoEnableShapeBoundIfNeeded() }
        }
        .onChange(of: ui.shapedGraphExperimental) { _, newValue in
            guard newValue else { return }
            Task { @MainActor in autoEnableShapeBoundIfNeeded() }
        }
    }

    /// Auto-enables the physics shape-bound when the user opts into
    /// experimental mode but doesn't have a shape selected. Without this,
    /// nodes would still roam freely and "leak" past the visible blur.
    private func autoEnableShapeBoundIfNeeded() {
        guard ui.shapedGraphExperimental,
              graphState.shapeBoundKind == .off
        else { return }
        graphState.shapeBoundKind = .circle
    }
}

struct ShapedGraphBoundaryView: View {
    let enabled: Bool
    let theme: EpistemosTheme
    let route: GraphWorkspaceRoute
    let shapeKind: ShapeBoundKind
    /// World-space radius of the physics shape-bound. Mapped ~1:1 to view
    /// pixels at the overlay's default zoom; if the user resizes the
    /// boundary via the Shape settings this updates with it.
    let shapeRadius: CGFloat
    let availableSize: CGSize

    static let noteInset: CGFloat = 24
    private static let fadeWidth: CGFloat = 56
    /// Hard cap so the shape never overflows the window even if the user
    /// dials the bound radius enormous. Keeps a comfortable margin.
    private static let maxShapeFraction: CGFloat = 0.92

    var body: some View {
        if enabled {
            shapeLayer
                .allowsHitTesting(false)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isCanvasRoute)
                .animation(.spring(response: 0.55, dampingFraction: 0.85), value: shapeKind)
                .animation(.spring(response: 0.55, dampingFraction: 0.85), value: shapeRadius)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: availableSize.width)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: availableSize.height)
        } else {
            Color.clear
        }
    }

    private var isCanvasRoute: Bool {
        if case .canvas = route { return true }
        return false
    }

    /// Diameter (or side length, for square / polygon enclosing box) of the
    /// rendered shape. Maps world radius to view pixels, clamped so the
    /// shape always fits inside the available area with room for the fade.
    private var shapeSize: CGFloat {
        let maxByWindow = min(availableSize.width, availableSize.height)
            * Self.maxShapeFraction
        let desired = shapeRadius * 2
        return min(maxByWindow, max(120, desired))
    }

    private var noteRect: CGRect {
        CGRect(
            x: Self.noteInset,
            y: Self.noteInset,
            width: max(0, availableSize.width - Self.noteInset * 2),
            height: max(0, availableSize.height - Self.noteInset * 2)
        )
    }

    static func noteCornerRadius(for rect: CGRect) -> CGFloat {
        max(34, min(rect.width, rect.height) * 0.20)
    }

    @ViewBuilder
    private var shapeLayer: some View {
        // Guard against zero-size geometry passes during initial layout
        // (one of the conditions that triggered the previous "invalid
        // reuse after initialization failure").
        if availableSize.width > 1, availableSize.height > 1 {
            if isCanvasRoute {
                canvasShapeLayer
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private var canvasShapeLayer: some View {
        let size = max(120, shapeSize)
        ZStack(alignment: .center) {
            // Use `.blur(radius:)` on a soft-stroked + filled shape to get
            // the fading-edge effect without a `.mask` chain. Cheaper for
            // SwiftUI's layout engine and avoids the recursion that
            // caused the previous reuse-after-init crash.
            shape
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .blur(radius: 18)
            shape
                .fill(theme.glassBg.opacity(0.18))
                .frame(width: size, height: size)
                .blur(radius: 18)
        }
        .frame(width: availableSize.width, height: availableSize.height)
    }

    /// SwiftUI shape matching the active `ShapeBoundKind` so the visual
    /// boundary mirrors the physics boundary exactly. Returns `AnyShape`
    /// because `@ViewBuilder` returns `some View`, not `some Shape`.
    private var shape: AnyShape {
        switch shapeKind {
        case .off, .circle:
            return AnyShape(Circle())
        case .square:
            return AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        case .triangle:
            return AnyShape(RegularPolygonShape(sides: 3))
        case .hexagon:
            return AnyShape(RegularPolygonShape(sides: 6))
        case .star:
            return AnyShape(StarShape(points: 5, innerRatio: 0.45))
        }
    }
}

// MARK: - Regular polygon (triangle, hexagon)

private struct RegularPolygonShape: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard sides >= 3 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5
        let angleStep = (2 * .pi) / CGFloat(sides)
        // Start at top.
        let startAngle = -CGFloat.pi / 2
        for i in 0..<sides {
            let angle = startAngle + angleStep * CGFloat(i)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Star

private struct StarShape: Shape {
    let points: Int
    /// Ratio of inner vertex radius to outer vertex radius (smaller →
    /// pointier star). 0.45 is a clean five-point star.
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points >= 3 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.5
        let innerRadius = outerRadius * innerRatio
        let totalSteps = points * 2
        let angleStep = (2 * .pi) / CGFloat(totalSteps)
        let startAngle = -CGFloat.pi / 2
        for i in 0..<totalSteps {
            let radius = (i.isMultiple(of: 2)) ? outerRadius : innerRadius
            let angle = startAngle + angleStep * CGFloat(i)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
