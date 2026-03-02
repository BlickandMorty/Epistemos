import SwiftUI

// MARK: - Liquid Glass Modifiers (macOS 26)

/// Conditionally applies glass (when active) or a flat colored background (when inactive).
struct FlatToGlassModifier: ViewModifier {
    let isActive: Bool
    let flatBackground: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if isActive {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(flatBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// Hover glass: flat background at rest, Liquid Glass on hover.
/// Only the item under the cursor pays the blur cost.
struct HoverGlassModifier: ViewModifier {
    let flatBackground: Color
    let cornerRadius: CGFloat
    let shape: HoverGlassShape

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum HoverGlassShape {
        case roundedRect
        case capsule
    }

    func body(content: Content) -> some View {
        content
            .background {
                if isHovered {
                    switch shape {
                    case .roundedRect:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    case .capsule:
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: Capsule())
                    }
                } else {
                    switch shape {
                    case .roundedRect:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(flatBackground)
                    case .capsule:
                        Capsule().fill(flatBackground)
                    }
                }
            }
            .onHover { hovering in
                if reduceMotion {
                    isHovered = hovering
                } else {
                    withAnimation(Motion.smooth) { isHovered = hovering }
                }
            }
    }
}

// MARK: - Apple Intelligence Shimmer Border
/// Animated rainbow gradient border inspired by Apple Intelligence's Writing Tools glow.
/// Flows a spectral gradient around the element's border for a premium, AI-infused feel.

struct SiriGlowBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors: [Color] = [
        Color(hue: 0.75, saturation: 0.6, brightness: 0.9),  // purple
        Color(hue: 0.60, saturation: 0.5, brightness: 0.95), // blue
        Color(hue: 0.50, saturation: 0.5, brightness: 0.95), // cyan
        Color(hue: 0.35, saturation: 0.5, brightness: 0.9),  // green
        Color(hue: 0.15, saturation: 0.5, brightness: 0.95), // yellow
        Color(hue: 0.05, saturation: 0.6, brightness: 0.95), // orange
        Color(hue: 0.95, saturation: 0.5, brightness: 0.9),  // pink
        Color(hue: 0.75, saturation: 0.6, brightness: 0.9),  // purple (loop)
    ]

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    // TimelineView at 30Hz — glow rotation doesn't need 60fps.
                    // drawingGroup() rasterizes the gradient+blur to a Metal texture
                    // on GPU instead of CPU-compositing every frame.
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        let elapsed = context.date.timeIntervalSinceReferenceDate
                        let phase = elapsed.truncatingRemainder(dividingBy: 4) / 4 * 360

                        ZStack {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    AngularGradient(
                                        colors: Self.colors,
                                        center: .center,
                                        startAngle: .degrees(phase),
                                        endAngle: .degrees(phase + 360)
                                    ),
                                    lineWidth: lineWidth
                                )
                                .blur(radius: 1)
                                .opacity(0.7)

                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    AngularGradient(
                                        colors: Self.colors,
                                        center: .center,
                                        startAngle: .degrees(phase),
                                        endAngle: .degrees(phase + 360)
                                    ),
                                    lineWidth: lineWidth * 2.5
                                )
                                .blur(radius: 4)
                                .opacity(0.25)
                        }
                        .drawingGroup()
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - View Extensions

extension View {
    func flatToGlass(
        isActive: Bool,
        flatBackground: Color,
        cornerRadius: CGFloat = 10
    ) -> some View {
        modifier(FlatToGlassModifier(isActive: isActive, flatBackground: flatBackground, cornerRadius: cornerRadius))
    }

    func hoverGlass(
        flatBackground: Color,
        cornerRadius: CGFloat = 10
    ) -> some View {
        modifier(HoverGlassModifier(flatBackground: flatBackground, cornerRadius: cornerRadius, shape: .roundedRect))
    }

    func hoverGlassCapsule(
        flatBackground: Color
    ) -> some View {
        modifier(HoverGlassModifier(flatBackground: flatBackground, cornerRadius: 0, shape: .capsule))
    }

    func siriGlow(
        cornerRadius: CGFloat = 12,
        lineWidth: CGFloat = 1.5,
        isActive: Bool = true
    ) -> some View {
        modifier(SiriGlowBorderModifier(cornerRadius: cornerRadius, lineWidth: lineWidth, isActive: isActive))
    }
}
