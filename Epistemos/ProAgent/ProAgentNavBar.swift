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
/// the pre-excision goose nav bar's capsule language (recovered at
/// 0b10f728b~1 RootView), narrowed to the OpenChamber workspace's needs:
/// Home · title · New Chat. (All-chats joins when the native sheet lands.)
struct ProAgentNavBar: View {
    let theme: EpistemosTheme
    let onReturnHome: () -> Void
    let onNewChat: () -> Void
    let onAllChats: () -> Void

    private enum Metrics {
        static let barHeight: CGFloat = 44
        static let navSlotHeight: CGFloat = 38
        static let leadingWidth: CGFloat = 116
        static let iconSize: CGFloat = 15
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onReturnHome) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Epistemos")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .frame(width: Metrics.leadingWidth, height: Metrics.navSlotHeight)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("Back to Epistemos")
            .accessibilityLabel("Back to Epistemos")

            Divider()
                .frame(height: 22)
                .opacity(0.34)

            Text("Agent")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary.opacity(0.85))
                .lineLimit(1)
                .accessibilityLabel("Agent surface")

            Button(action: onNewChat) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: Metrics.iconSize, weight: .semibold))
                    Text("New Chat")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .frame(height: Metrics.navSlotHeight - 6)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.9))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("New chat")
            .accessibilityLabel("New chat")

            Button(action: onAllChats) {
                HStack(spacing: 5) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: Metrics.iconSize - 1, weight: .semibold))
                    Text("All Chats")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .frame(height: Metrics.navSlotHeight - 6)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.9))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("All chats")
            .accessibilityLabel("All chats")
        }
        .frame(height: Metrics.barHeight)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Agent native chrome")
    }
}
#endif
