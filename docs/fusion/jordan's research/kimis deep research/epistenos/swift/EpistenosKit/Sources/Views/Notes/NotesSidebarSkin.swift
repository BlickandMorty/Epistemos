import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - NotesSidebarSkin
// ---------------------------------------------------------------------------

/// A companion-aware skin for the Notes sidebar.
///
/// `NotesSidebarSkin` wraps the existing sidebar content and adds a companion
/// avatar at the top. The avatar reacts to live `AgentProvenanceEvent` events
/// via `CompanionState.currentReaction`, showing brief visual feedback:
///
/// | Event kind        | Reaction                     |
/// |-------------------|------------------------------|
/// | `tool_completed`  | Green glow pulse + nod       |
/// | `tool_failed`     | Red pulse + shake              |
/// | `summary_started` | Attentive lean forward       |
/// | `summary_completed`| Satisfied settle back         |
/// | `vault_created`   | Curious tilt                   |
/// | `vault_archived`  | Somber dim                     |
///
/// All reactions are < 0.5 s, gated by `reduceMotion`, and cancel any
/// previous reaction when a new event arrives.
public struct NotesSidebarSkin<Content: View>: View {
    @Environment(CompanionState.self) private var companionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let content: Content

    @State private var reactionRotation: Double = 0
    @State private var reactionScale: CGFloat = 1.0
    @State private var reactionOpacity: Double = 1.0
    @State private var reactionGlowColor: Color = .clear
    @State private var reactionTask: Task<Void, Never>?
    @State private var tooltipText: String?
    @State private var showTooltip = false

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            companionHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            content
        }
        .frame(minWidth: 220)
        .onChange(of: companionState.currentReaction) { _, newReaction in
            applyReaction(newReaction)
        }
    }

    // MARK: - Companion Header

    private var companionHeader: some View {
        HStack(spacing: 10) {
            if let companion = companionState.activeCompanion {
                avatarView(for: companion)
                    .frame(width: 32, height: 32)
                    .overlay(
                        reactionGlow
                            .allowsHitTesting(false)
                    )
                    .rotationEffect(.degrees(reactionRotation))
                    .scaleEffect(reactionScale)
                    .opacity(reactionOpacity)
                    .animation(.easeInOut(duration: 0.25), value: reactionRotation)
                    .animation(.easeInOut(duration: 0.25), value: reactionScale)
                    .animation(.easeInOut(duration: 0.25), value: reactionOpacity)

                VStack(alignment: .leading, spacing: 1) {
                    Text(companion.name)
                        .font(.caption.bold())
                    Text(statusText(for: companionState.currentReaction))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                activityDot
            } else {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No companion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .help(tooltipText ?? "Your active companion reacts to agent events here.")
    }

    @ViewBuilder
    private func avatarView(for companion: CompanionModel) -> some View {
        switch companion.cosmeticConfig.avatarShape {
        case "shard":
            Diamond()
                .fill(companion.themeColor)
                .shadow(color: companion.themeColor.opacity(0.4), radius: 4)
        case "pulse":
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            companion.themeColor,
                            companion.themeColor.opacity(0.4)
                        ]),
                        center: .center,
                        startRadius: 6,
                        endRadius: 16
                    )
                )
        default:
            Circle()
                .fill(companion.themeColor)
                .shadow(color: companion.themeColor.opacity(0.35), radius: 4)
        }
    }

    @ViewBuilder
    private var reactionGlow: some View {
        if reactionGlowColor != .clear {
            Circle()
                .stroke(reactionGlowColor, lineWidth: 2)
                .frame(width: 36, height: 36)
                .blur(radius: 1)
        }
    }

    @ViewBuilder
    private var activityDot: some View {
        Circle()
            .fill(companionState.currentReaction != nil ? Color.accentColor : Color.green)
            .frame(width: 6, height: 6)
            .opacity(companionState.currentReaction != nil ? 1.0 : 0.5)
    }

    // MARK: - Reaction Application

    private func applyReaction(_ reaction: CompanionReaction?) {
        reactionTask?.cancel()
        tooltipText = nil
        showTooltip = false

        guard let reaction = reaction, !reduceMotion else {
            resetReactionVisuals()
            return
        }

        switch reaction {
        case .toolCompleted:
            reactionGlowColor = .green
            reactionScale = 1.1
            tooltipText = "Agent completed a task successfully"
        case .toolFailed:
            reactionGlowColor = .red
            reactionScale = 1.05
            reactionRotation = 5
            tooltipText = "Agent task failed"
        case .summaryStarted:
            reactionGlowColor = .blue
            reactionScale = 1.05
            tooltipText = "Agent is summarising notes …"
        case .summaryCompleted:
            reactionGlowColor = .green.opacity(0.6)
            reactionScale = 1.0
            tooltipText = "Summary completed"
        case .vaultCreated:
            reactionGlowColor = .yellow
            reactionRotation = 10
            tooltipText = "New vault created"
        case .vaultArchived:
            reactionGlowColor = .gray
            reactionOpacity = 0.6
            tooltipText = "Vault archived"
        case .idle:
            resetReactionVisuals()
            return
        }

        reactionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s
            guard !Task.isCancelled else { return }
            resetReactionVisuals()
        }
    }

    private func resetReactionVisuals() {
        reactionRotation = 0
        reactionScale = 1.0
        reactionOpacity = 1.0
        reactionGlowColor = .clear
    }

    // MARK: - Helpers

    private func statusText(for reaction: CompanionReaction?) -> String {
        guard let reaction else { return "Listening …" }
        switch reaction {
        case .toolCompleted:    return "Done"
        case .toolFailed:         return "Failed"
        case .summaryStarted:     return "Working …"
        case .summaryCompleted:   return "All caught up"
        case .vaultCreated:       return "Curious"
        case .vaultArchived:      return "Noted"
        case .idle:               return "Listening …"
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - Diamond Shape
// ---------------------------------------------------------------------------

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let halfW = rect.width / 2
        let halfH = rect.height / 2
        path.move(to: CGPoint(x: cx, y: cy - halfH))
        path.addLine(to: CGPoint(x: cx + halfW, y: cy))
        path.addLine(to: CGPoint(x: cx, y: cy + halfH))
        path.addLine(to: CGPoint(x: cx - halfW, y: cy))
        path.closeSubpath()
        return path
    }
}

// ---------------------------------------------------------------------------
// MARK: - Preview
// ---------------------------------------------------------------------------

#if DEBUG
#Preview {
    let state = CompanionState()
    state.companions = [
        CompanionModel(name: "Amber", baseProfile: "default", cosmeticConfig: CosmeticConfig(colorTheme: "amber", avatarShape: "orb", idleBreathingRate: 1.0))
    ]
    state.activeCompanion = state.companions.first

    return NotesSidebarSkin {
        List {
            Text("All Notes")
            Text("Recents")
            Text("Archive")
        }
    }
    .environment(state)
    .frame(width: 260, height: 400)
}
#endif
