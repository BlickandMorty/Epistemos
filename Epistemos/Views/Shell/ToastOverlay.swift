import SwiftUI

// MARK: - Toast Overlay
// Bottom-aligned toast notification with native glass capsule effect.
// Shows error/warning/info/success messages that auto-dismiss.

struct ToastOverlay: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var iconName: String {
        switch type {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch type {
        case .success: theme.success
        case .error: theme.error
        case .warning: theme.warning
        case .info: theme.info
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)

            Text(message)
                .font(.epCaption)
                .foregroundStyle(theme.foreground)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
    }
}
