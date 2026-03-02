import SwiftUI

// MARK: - Physics ViewModifiers
// Five opt-in modifiers that make views feel physically present.
// Each is self-contained, respects accessibilityReduceMotion, and follows
// the pattern established in GlassModifiers.swift.
//
// Performance contract:
// - Zero cost when idle (no timers, no per-frame work)
// - .breathe() uses TimelineView at 30Hz, gated by windowOccluded
// - All continuous effects pause when accessibilityReduceMotion is on
//
// WARNING: NO .repeatForever (Pitfall #10 — 70% idle CPU in v2).

// MARK: - 1. Physics Hover

/// Adds physical presence on hover: scale, shadow depth shift, optional 3D tilt.
/// Three tiers: .subtle (sidebar rows), .medium (cards), .lift (feature cards).
struct PhysicsHoverModifier: ViewModifier {
    let depth: Depth
    let enableTilt: Bool

    @State private var isHovered = false
    @State private var hoverLocation: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Depth {
        case subtle  // sidebar rows — visible but not distracting
        case medium  // cards — clear lift with shadow
        case lift    // feature cards — dramatic 3D presence

        var scale: CGFloat {
            switch self {
            case .subtle: 1.015
            case .medium: 1.025
            case .lift:   1.035
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .subtle: 0.12
            case .medium: 0.18
            case .lift:   0.24
            }
        }

        var shadowRadius: CGFloat {
            switch self {
            case .subtle: 6
            case .medium: 12
            case .lift:   20
            }
        }

        /// Background tint opacity on hover (gives clear visual feedback)
        var backgroundOpacity: Double {
            switch self {
            case .subtle: 0.04
            case .medium: 0.06
            case .lift:   0.08
            }
        }
    }

    /// Tilt angles derived from cursor position (±3°). Only active with enableTilt.
    private var tiltX: Double {
        guard isHovered, enableTilt else { return 0 }
        return (hoverLocation.y - 0.5) * -6
    }

    private var tiltY: Double {
        guard isHovered, enableTilt else { return 0 }
        return (hoverLocation.x - 0.5) * 6
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? depth.scale : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? depth.backgroundOpacity : 0))
            )
            .shadow(
                color: .black.opacity(isHovered ? depth.shadowOpacity : 0),
                radius: isHovered ? depth.shadowRadius : 0,
                y: isHovered ? 3 : 0
            )
            .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0))
            .onContinuousHover { phase in
                guard !reduceMotion else {
                    switch phase {
                    case .active: isHovered = true
                    case .ended:  isHovered = false
                    }
                    return
                }
                switch phase {
                case .active(let location):
                    withAnimation(Motion.micro) { isHovered = true }
                    if enableTilt {
                        // Normalize to 0…1 within card bounds (assume ~200x140)
                        hoverLocation = CGPoint(
                            x: min(max(location.x / 200, 0), 1),
                            y: min(max(location.y / 140, 0), 1)
                        )
                    }
                case .ended:
                    withAnimation(Motion.smooth) {
                        isHovered = false
                        hoverLocation = CGPoint(x: 0.5, y: 0.5)
                    }
                }
            }
    }
}

// MARK: - 2. Physics Press

/// Depth on press, spring-back on release.
/// Scale 0.97 down with Motion.micro, snap back with Motion.sharp.
struct PhysicsPressModifier: ViewModifier {
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .brightness(isPressed ? -0.02 : 0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        if reduceMotion {
                            isPressed = true
                        } else {
                            withAnimation(Motion.micro) { isPressed = true }
                        }
                    }
                    .onEnded { _ in
                        if reduceMotion {
                            isPressed = false
                        } else {
                            withAnimation(Motion.sharp) { isPressed = false }
                        }
                    }
            )
    }
}

// MARK: - 3. Breathe

/// Subtle idle oscillation — subliminal scale/opacity modulation.
/// Uses TimelineView at 30Hz, gated by windowOccluded + reduceMotion.
/// Default amplitude 0.3% — a 300px element moves ~1px.
struct BreatheModifier: ViewModifier {
    let amplitude: CGFloat
    let period: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui

    private var shouldAnimate: Bool { !reduceMotion && !ui.windowOccluded }

    func body(content: Content) -> some View {
        if shouldAnimate {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = sin(t * (2 * .pi / period))
                content
                    .scaleEffect(1.0 + amplitude * phase)
                    .opacity(1.0 - 0.04 * abs(phase))
            }
        } else {
            content
        }
    }
}

// MARK: - 4. Spring Entrance

/// Staggered appear animation: opacity, offset, and scale spring in.
/// Staggered spring entrance with overshoot bounce.
struct SpringEntranceModifier: ViewModifier {
    let index: Int
    let staggerDelay: Double

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .scaleEffect(appeared ? 1 : 0.88)
            .animation(
                reduceMotion
                    ? .none
                    : Motion.settle.delay(Double(index) * staggerDelay),
                value: appeared
            )
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(50))
                        appeared = true
                    }
                }
            }
    }
}

// MARK: - 5. Graph Reactive

/// Cross-view bridge: when the graph-hovered node matches this nodeId,
/// show a subtle accent bar + background fill on this view.
struct GraphReactiveModifier: ViewModifier {
    let nodeId: String

    @Environment(PhysicsCoordinator.self) private var physics

    private var isHighlighted: Bool {
        physics.graphHoveredNodeId == nodeId
    }

    func body(content: Content) -> some View {
        content
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .leading) {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 3)
                        .transition(.scale(scale: 0, anchor: .leading).combined(with: .opacity))
                }
            }
            .animation(Motion.quick, value: isHighlighted)
    }
}

// MARK: - View Extensions

extension View {

    /// Add physical hover presence. Use `.subtle` for rows, `.medium` for cards, `.lift` for feature cards.
    func physicsHover(_ depth: PhysicsHoverModifier.Depth = .subtle, tilt: Bool = false) -> some View {
        modifier(PhysicsHoverModifier(depth: depth, enableTilt: tilt))
    }

    /// Scale down on press, spring back on release.
    func physicsPress() -> some View {
        modifier(PhysicsPressModifier())
    }

    /// Subtle idle breathing oscillation. Amplitude 0.003 = 0.3% scale (subliminal).
    func breathe(amplitude: CGFloat = 0.003, period: Double = 4.0) -> some View {
        modifier(BreatheModifier(amplitude: amplitude, period: period))
    }

    /// Staggered spring entrance. Pass index for cascade delay.
    func springEntrance(index: Int = 0, stagger: Double = 0.04) -> some View {
        modifier(SpringEntranceModifier(index: index, staggerDelay: stagger))
    }

    /// React when the graph hovers over the matching node.
    func graphReactive(nodeId: String) -> some View {
        modifier(GraphReactiveModifier(nodeId: nodeId))
    }
}
