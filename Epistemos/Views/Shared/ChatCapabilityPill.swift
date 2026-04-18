import SwiftUI

/// Small rounded badge that shows the user which ChatCapability tier the
/// active chat is running in. Used across main chat, mini chat, note chat,
/// and graph chat so the same signal reads the same way everywhere.
///
/// Kept deliberately tiny — it reads at a glance, never steals focus, and
/// animates a subtle pulse while agent work is in flight so the user knows
/// a long-running turn is actually progressing.
///
/// Optional `detail` appends a live sub-signal: when the agent is executing
/// a specific tool, the pill reads e.g. "Agent • web_search" so the user
/// sees what the agent is doing right now without needing the command
/// center open. Pass nil to hide the detail.
struct ChatCapabilityPill: View {
    let capability: ChatCapability
    let detail: String?

    @State private var isPulsing = false

    init(capability: ChatCapability, detail: String? = nil) {
        self.capability = capability
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: capability.iconSystemName)
                .font(.system(size: 10, weight: .semibold))
            Text(capability.displayName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
            if let detail, !detail.isEmpty {
                Text("•")
                    .font(.system(size: 10, weight: .regular))
                    .opacity(0.55)
                Text(detail)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(background)
        .overlay(border)
        .clipShape(Capsule())
        .help(detail.map { "\(capability.displayName): \($0)" } ?? capability.shortExplanation)
        .accessibilityLabel(
            Text(
                detail.map { "\(capability.displayName) running \($0)" }
                    ?? "\(capability.displayName) — \(capability.shortExplanation)"
            )
        )
        .animation(.easeOut(duration: 0.18), value: detail)
        .scaleEffect(isPulsing ? 1.035 : 1.0)
        .onChange(of: capability.isAgentActive, initial: true) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isPulsing = false
                }
            }
        }
    }

    private var tint: Color {
        switch capability {
        case .local: .green
        case .thinking: .indigo
        case .research: .teal
        case .cloud: .blue
        case .agent: .purple
        }
    }

    private var background: some View {
        Capsule()
            .fill(tint.opacity(0.14))
    }

    private var border: some View {
        Capsule()
            .strokeBorder(tint.opacity(0.35), lineWidth: 0.75)
    }
}

#Preview("All capabilities") {
    VStack(alignment: .leading, spacing: 10) {
        ForEach(ChatCapability.allCases, id: \.self) { capability in
            HStack(spacing: 10) {
                ChatCapabilityPill(capability: capability)
                Text(capability.shortExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .frame(width: 500)
}
