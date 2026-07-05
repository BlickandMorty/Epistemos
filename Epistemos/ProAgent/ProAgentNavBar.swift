#if !EPISTEMOS_APP_STORE
import SwiftUI

extension Notification.Name {
    /// Native pill -> agent surface intents (Plan 1-PRO §5/§13.5). The surface
    /// injects these as a window CustomEvent — the SPA URL is never reloaded.
    static let epistemosProAgentChromeIntent = Notification.Name("EpistemosProAgentChromeIntent")
}

enum ProAgentChromeIntent {
    static let newChat = "newChat"
    static let selectSession = "selectSession"
}

/// Companion/mascot overlay extension point (Plan 1-PRO §5): Plan 5 mounts
/// the mascot here, layered above the WebView and outside donor DOM. Empty
/// by design in Plan 1 — a named seam, not a placeholder feature.
struct ProAgentMascotOverlayHook: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

/// The owner-signature toolbar pill for the Pro agent surface — ported from
/// the app's compact capsule language, narrowed to exactly the OpenChamber
/// workspace controls the owner asked for: Epistemos · New Chat · All Chats.
struct ProAgentNavBar: View {
    let theme: EpistemosTheme
    let onReturnHome: () -> Void
    let onNewChat: () -> Void
    let onAllChats: () -> Void

    private enum Metrics {
        static let barHeight: CGFloat = 34
        static let navSlotHeight: CGFloat = 28
        static let leadingWidth: CGFloat = 104
        static let actionWidth: CGFloat = 92
        static func pixelFont(_ size: CGFloat) -> Font {
            Font.custom("ChonkyPixels", size: size).weight(.semibold)
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Button(action: onReturnHome) {
                Text("Epistemos")
                    .font(Metrics.pixelFont(12))
                    .lineLimit(1)
                .frame(width: Metrics.leadingWidth, height: Metrics.navSlotHeight)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("Back to Epistemos")
            .accessibilityLabel("Back to Epistemos")
            .accessibilityIdentifier("proAgentPill.home")

            Button(action: onNewChat) {
                Text("New Chat")
                    .font(Metrics.pixelFont(11))
                .frame(width: Metrics.actionWidth, height: Metrics.navSlotHeight)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.9))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("New chat")
            .accessibilityLabel("New chat")
            .accessibilityIdentifier("proAgentPill.newChat")

            Button(action: onAllChats) {
                Text("All Chats")
                    .font(Metrics.pixelFont(11))
                .frame(width: Metrics.actionWidth, height: Metrics.navSlotHeight)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.9))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("All chats")
            .accessibilityLabel("All chats")
            .accessibilityIdentifier("proAgentPill.allChats")
        }
        .frame(height: Metrics.barHeight)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Epistemos chat controls")
    }
}
#endif
