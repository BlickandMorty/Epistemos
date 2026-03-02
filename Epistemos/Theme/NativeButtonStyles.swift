import SwiftUI

// MARK: - Native Button Styles
// Three reusable ButtonStyles that encapsulate hover state internally.
// Replace the pattern of @State isHovered + .onHover + manual backgrounds.

/// Plain SF Symbol button. No background at rest, subtle highlight on press.
/// Used for: toolbar actions, message toolbar, settings icon buttons.
struct NativeToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovered || configuration.isPressed ? .primary : .secondary)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .shadow(color: .black.opacity(isHovered ? 0.06 : 0), radius: isHovered ? 4 : 0, y: 2)
            .animation(Motion.sharp, value: configuration.isPressed)
            .animation(Motion.micro, value: isHovered)
            .onHover { isHovered = $0 }
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Themed variant that uses EpistemosTheme colors.
struct ThemedToolbarButtonStyle: ButtonStyle {
    let theme: EpistemosTheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                isHovered || configuration.isPressed ? theme.accent : theme.accent.opacity(0.7)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? theme.accent.opacity(0.1) : .clear)
            )
            .animation(Motion.micro, value: configuration.isPressed)
            .animation(Motion.micro, value: isHovered)
            .onHover { isHovered = $0 }
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Capsule pill button. Outline at rest, filled when active or hovered.
/// Used for: nav pills, filter chips, tag chips, toggle buttons.
struct NativePillButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var activeColor: Color = .primary

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? activeColor : (isHovered ? .primary : .secondary))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background {
                if isActive {
                    Capsule()
                        .fill(activeColor.opacity(0.12))
                } else if isHovered {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                } else {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Motion.micro, value: configuration.isPressed)
            .animation(Motion.micro, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

/// Rounded rect card button. Subtle background fill on hover.
/// Used for: list items, sidebar items, cards, command palette rows.
struct NativeCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isHovered || configuration.isPressed
                            ? Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04)
                            : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.04 : 0), radius: isHovered ? 3 : 0, y: 1)
            .animation(Motion.sharp, value: configuration.isPressed)
            .animation(Motion.micro, value: isHovered)
            .onHover { isHovered = $0 }
    }
}
