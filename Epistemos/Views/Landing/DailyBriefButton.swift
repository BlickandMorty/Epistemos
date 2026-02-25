import SwiftUI

// MARK: - Daily Brief Button
// Branded wallpaper button on landing page — looks embossed into the background
// at rest, then lifts with glass and shimmer on hover.
// Triggers a personalized daily research brief query.

struct DailyBriefButton: View {
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 14, weight: .medium))

                Text("Daily Brief")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(isHovered ? 1 : 0)
                    .offset(x: isHovered ? 0 : -4)
            }
            .foregroundStyle(
                isHovered
                    ? theme.accent
                    : theme.fontAccent.opacity(0.25)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                if isHovered {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: Capsule())
                } else {
                    // Embossed look — very subtle inner shadow + stroke
                    Capsule()
                        .fill(theme.fontAccent.opacity(0.04))
                        .overlay {
                            Capsule()
                                .strokeBorder(theme.fontAccent.opacity(0.08), lineWidth: 0.5)
                        }
                }
            }
            .siriGlow(cornerRadius: 20, lineWidth: 0.8, isActive: isHovered)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Motion.smooth) { isHovered = hovering }
        }
        .animation(Motion.smooth, value: isHovered)
    }
}
