import SwiftUI

/// Single-agent render. Body grammar determines silhouette + animation
/// vocabulary; identity hash seeds DeterministicPRNG so cosmetic randomness is
/// replayable (Invariant I-13).
///
/// Idle animation is a TimelineView-driven breathing (Invariant I-5
/// `cosmetic_idle`) — no Combine timers, no explicit `withAnimation`
/// on a phase; the timeline just samples the state on every frame.
/// Reduce-motion: snap to a static pose with the state badge visible
/// (Invariant I-14).
///
/// On hover: lift + glow brighten (Invariant I-6 `cosmetic_focus`).
/// On tap: caller's closure (`onActivate`) — typically activates the
/// agent as the foreground persona for the next chat.
struct CompanionView: View {
    let entry: CompanionRosterEntry
    var size: CGFloat = 96
    var isActive: Bool = false
    var sampledAnimationDate: Date? = nil
    var showsMetadata: Bool = true
    var onActivate: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    nonisolated private static let breathingRefreshInterval: TimeInterval = 0.5

    private var accent: Color {
        Color(hex: entry.accentHex) ?? Color(hue: 0.55, saturation: 0.55, brightness: 0.95)
    }

    var body: some View {
        Button(action: onActivate) {
            VStack(spacing: 8) {
                bodyLayer
                    .frame(width: size, height: size)
                    .scaleEffect(isHovered ? 1.06 : 1.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72),
                               value: isHovered)
                if isActive {
                    Rectangle()
                        .fill(accent)
                        .frame(width: showsMetadata ? 24 : 18, height: showsMetadata ? 3 : 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                }
                if showsMetadata {
                    Text(entry.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(isActive ? accent : .primary.opacity(0.85))
                        .lineLimit(1)
                    if !entry.tagline.isEmpty {
                        Text(entry.tagline)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .lineLimit(1)
                            .frame(maxWidth: size * 1.4)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .accessibilityLabel("Agent \(entry.name)")
        .accessibilityValue(isActive ? "active" : "available")
        .accessibilityHint("Activate \(entry.name) as the foreground landing agent")
    }

    @ViewBuilder
    private var bodyLayer: some View {
        if reduceMotion {
            staticBody
        } else if let sampledAnimationDate {
            breathingBody(at: sampledAnimationDate)
        } else {
            breathingTimeline
        }
    }

    /// Per-agent canonical animation state. Landing agents sit and breathe;
    /// hover brightens to `speak` to telegraph the click affordance. Active
    /// selection is shown by the small rectangular badge, not a walk cycle.
    private var animationState: CompanionAnimationState {
        if isHovered { return .speak }
        return .idle
    }

    /// Reduce-motion fallback: the companion's body in its rest pose
    /// + a small text "idle" badge so the user knows the surface is
    /// alive but not animating. Invariant I-14 conformance.
    private var staticBody: some View {
        CompanionAvatarGlyph(
            kind: entry.bodyKind,
            accent: accent,
            phase: 0.5,
            state: .idle,
            reduceMotionOverride: true,
            showsIdleBadge: showsMetadata
        )
    }

    /// Idle animation per Invariant I-5 (`cosmetic_idle`): slow breathe
    /// (4-second period) via a subtle scale of the figure.
    /// Farm callers can pass a sampled date so one parent timeline drives
    /// every companion instead of each node owning its own clock.
    @ViewBuilder
    private func breathingBody(at date: Date) -> some View {
        let breathe = Self.breathePhase(at: date, seedString: entry.identityHash)
        CompanionAvatarGlyph(
            kind: entry.bodyKind,
            accent: accent,
            phase: breathe,
            state: animationState,
            reduceMotionOverride: false
        )
        .scaleEffect(0.98 + 0.02 * breathe)
    }

    /// Standalone contexts still get a local periodic clock; the Farm path
    /// supplies `sampledAnimationDate` to avoid per-companion timelines.
    private var breathingTimeline: some View {
        TimelineView(.periodic(from: .now, by: Self.breathingRefreshInterval)) { context in
            breathingBody(at: context.date)
        }
    }

    /// Deterministic breathe phase. Per-companion phase offset comes
    /// from `seedString` so two companions on screen don't pulse in
    /// lockstep (would feel mechanical). Invariant I-13: same seed +
    /// same date = same phase.
    nonisolated static func breathePhase(at date: Date, seedString: String) -> CGFloat {
        var prng = DeterministicPRNG(seedString: seedString)
        let phaseOffset = prng.unitDouble() * .pi * 2.0
        let cycle = normalizedCycleFraction(date.timeIntervalSinceReferenceDate, period: 4.0)
        let raw = sin(cycle * 2.0 * .pi + phaseOffset)
        return CGFloat((raw + 1.0) / 2.0)
    }

    nonisolated private static func normalizedCycleFraction(_ seconds: TimeInterval, period: TimeInterval) -> Double {
        guard seconds.isFinite, period.isFinite, period > 0 else { return 0 }
        let remainder = seconds.truncatingRemainder(dividingBy: period)
        return (remainder < 0 ? remainder + period : remainder) / period
    }
}

// MARK: - Color hex helper

extension Color {
    /// Initialize from a hex string like "#7BA8E0" or "7BA8E0".
    /// Returns nil if the input doesn't parse.
    init?(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = UInt64(trimmed, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xff) / 255.0
        let g = Double((value >>  8) & 0xff) / 255.0
        let b = Double( value        & 0xff) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
