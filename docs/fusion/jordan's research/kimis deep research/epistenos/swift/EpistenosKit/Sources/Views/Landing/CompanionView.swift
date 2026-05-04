import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - CompanionView
// ---------------------------------------------------------------------------

/// A single companion orb rendered inside `LandingFarmView`.
///
/// `CompanionView` uses `TimelineView` to drive idle breathing animation.
/// All motion is gated by `windowOccluded` (passed down) and the system
/// `accessibilityReduceMotion` setting. When `reduceMotion` is true the
/// avatar is completely static.
///
/// The view also renders transient reactions (`CompanionReaction`) as brief
/// overlays that expire automatically.
public struct CompanionView: View {
    let companion: CompanionModel
    let isActive: Bool

    @Environment(CompanionState.self) private var companionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var windowOccluded = false

    private let breathingInterval: Double = 1.0 / 30.0 // 30 Hz

    public init(companion: CompanionModel, isActive: Bool) {
        self.companion = companion
        self.isActive = isActive
    }

    public var body: some View {
        VStack(spacing: 12) {
            orb
            Text(companion.name)
                .font(.system(.body, design: .rounded))
                .lineLimit(1)
            Text(companion.relativeLastActive)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140, height: 160)
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuButtons
        }
        .onDisappear {
            windowOccluded = true
        }
    }

    // MARK: - Orb

    @ViewBuilder
    private var orb: some View {
        if reduceMotion || windowOccluded {
            staticOrb
        } else {
            breathingOrb
        }
    }

    private var staticOrb: some View {
        orbShape
            .frame(width: 80, height: 80)
            .overlay(activeGlow, alignment: .center)
            .overlay(reactionOverlay, alignment: .center)
    }

    private var breathingOrb: some View {
        TimelineView(.periodic(from: Date(), by: breathingInterval)) { timeline in
            let phase = breathingPhase(at: timeline.date)
            orbShape
                .frame(width: 80 * phase.scale, height: 80 * phase.scale)
                .opacity(phase.opacity)
                .overlay(activeGlow, alignment: .center)
                .overlay(reactionOverlay, alignment: .center)
                .animation(.easeInOut(duration: breathingInterval), value: phase)
        }
    }

    @ViewBuilder
    private var orbShape: some View {
        switch companion.cosmeticConfig.avatarShape {
        case "shard":
            Diamond()
                .fill(companion.themeColor)
                .shadow(color: companion.themeColor.opacity(0.4), radius: 8)
        case "pulse":
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            companion.themeColor,
                            companion.themeColor.opacity(0.4)
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 40
                    )
                )
                .shadow(color: companion.themeColor.opacity(0.3), radius: 10)
        default:
            Circle()
                .fill(companion.themeColor)
                .shadow(color: companion.themeColor.opacity(0.35), radius: 12)
        }
    }

    @ViewBuilder
    private var activeGlow: some View {
        if isActive {
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                .frame(width: 88, height: 88)
                .blur(radius: 2)
        }
    }

    @ViewBuilder
    private var reactionOverlay: some View {
        if let reaction = companionState.currentReaction,
           companionState.activeCompanion?.id == companion.id {
            reactionVisual(for: reaction)
        }
    }

    // MARK: - Reaction Visuals

    @ViewBuilder
    private func reactionVisual(for reaction: CompanionReaction) -> some View {
        switch reaction {
        case .toolCompleted:
            Circle()
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 92, height: 92)
                .opacity(0.8)
        case .toolFailed:
            Circle()
                .stroke(Color.red, lineWidth: 3)
                .frame(width: 92, height: 92)
                .opacity(0.8)
        case .summaryStarted:
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: 86, height: 86)
        case .summaryCompleted:
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 90, height: 90)
        case .vaultCreated:
            Circle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(15))
        case .vaultArchived:
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
        case .idle:
            EmptyView()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuButtons: some View {
        Button("Activate") {
            companionState.activeCompanion = companion
            companion.lastActiveAt = Date()
        }
        .disabled(isActive)

        Button("Rename …") {
            // In production this would present a rename sheet.
            // For Core we delegate to a simple alert or inline edit.
        }

        Divider()

        Button("Archive") {
            Task { @MainActor in
                try? await companionState.archiveCompanion(companion)
            }
        }

        Button("Delete …", role: .destructive) {
            Task { @MainActor in
                try? await companionState.deleteCompanion(companion)
            }
        }
    }

    // MARK: - Breathing Math

    private func breathingPhase(at date: Date) -> BreathingPhase {
        let rate = companion.cosmeticConfig.idleBreathingRate
        let seconds = date.timeIntervalSinceReferenceDate
        let cycle = sin(seconds * Double.pi * 2.0 * rate)
        let scale = 1.0 + 0.02 * cycle   // [0.98, 1.02]
        let opacity = 0.925 + 0.075 * cycle // [0.85, 1.0]
        return BreathingPhase(scale: scale, opacity: opacity)
    }
}

// ---------------------------------------------------------------------------
// MARK: - BreathingPhase
// ---------------------------------------------------------------------------

private struct BreathingPhase: Equatable {
    let scale: CGFloat
    let opacity: Double
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
    let companion = CompanionModel(
        name: "Amber",
        baseProfile: "default",
        cosmeticConfig: CosmeticConfig(colorTheme: "amber", avatarShape: "orb", idleBreathingRate: 1.0)
    )
    let state = CompanionState()
    state.companions = [companion]
    state.activeCompanion = companion

    return CompanionView(companion: companion, isActive: true)
        .environment(state)
        .frame(width: 200, height: 200)
}
#endif
