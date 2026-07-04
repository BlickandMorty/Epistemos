#if EPISTEMOS_APP_STORE
import SwiftUI

/// The MAS Agent-room toolbar pill (Plan 1-MAS §7): Home / New Chat /
/// All Chats wrapping the vendored June surface. Mirrors the Pro track's
/// ProAgentNavBar metrics so both builds' chrome reads identically. Drives
/// June via intent events (JuneAgentIntents), never URL reloads; the
/// all-chats sheet presents from here so RootView stays a one-branch mount.
struct JuneAgentNavBar: View {
    let theme: EpistemosTheme
    let onReturnHome: () -> Void

    @State private var showingAllChats = false

    private enum Metrics {
        static let navSlotHeight: CGFloat = 38
        static let leadingWidth: CGFloat = 116
        static let iconSize: CGFloat = 15
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onReturnHome) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: Metrics.iconSize, weight: .semibold))
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

            Button {
                JuneAgentIntents.newSession()
            } label: {
                Image(systemName: "plus.bubble")
                    .font(.system(size: Metrics.iconSize, weight: .semibold))
                    .frame(width: Metrics.navSlotHeight, height: Metrics.navSlotHeight)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("New agent session")
            .accessibilityLabel("New agent session")

            Button {
                showingAllChats = true
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: Metrics.iconSize, weight: .semibold))
                    .frame(width: Metrics.navSlotHeight, height: Metrics.navSlotHeight)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("All agent sessions")
            .accessibilityLabel("All agent sessions")
            .sheet(isPresented: $showingAllChats) {
                JuneAllChatsSheet()
            }
        }
    }
}
#endif
