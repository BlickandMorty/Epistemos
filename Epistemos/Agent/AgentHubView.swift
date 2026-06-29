import SwiftUI

// Phase 1 (Step 3) — native Agent hub: greeting + composer entry point. No auto-submit on open
// (charter): the composer is a draft until the user sends. Reuses AgentComposerBar.

@MainActor
struct AgentHubView: View {
    let theme: EpistemosTheme
    /// True once the shared goose serve connection + session are ready to accept a prompt.
    let isReady: Bool
    let onSubmit: (String) -> Void

    @State private var draft = ""

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Text("Goose")
                .font(GooseSurfaceStyle.bodyFont(24, weight: .semibold))
                .foregroundStyle(theme.resolved.foreground.color)
            Text("How can I help?")
                .font(GooseSurfaceStyle.bodyFont(13))
                .foregroundStyle(theme.textTertiary)

            AgentComposerBar(
                text: $draft,
                isStreaming: false,
                theme: theme,
                onSend: onSubmit,
                onCancel: {}
            )
            .frame(maxWidth: 620)

            if !isReady {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Connecting to Goose…")
                        .font(GooseSurfaceStyle.bodyFont(10))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GooseSurfaceStyle.background(for: theme, role: .canvas))
    }
}
