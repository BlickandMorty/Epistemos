import SwiftUI

/// Single-companion render. Body grammar (Block / Sage / Orb /
/// HermesSnake) determines silhouette + animation vocabulary; identity
/// hash seeds DeterministicPRNG so cosmetic randomness is replayable
/// (Invariant I-13).
///
/// Idle animation is a TimelineView-driven breathing (Invariant I-5
/// `cosmetic_idle`) — no Combine timers, no explicit `withAnimation`
/// on a phase; the timeline just samples the state on every frame.
/// Reduce-motion: snap to a static pose with the state badge visible
/// (Invariant I-14).
///
/// On hover: lift + glow brighten (Invariant I-6 `cosmetic_focus`).
/// On tap: caller's closure (`onActivate`) — typically activates the
/// companion as the foreground persona for the next chat.
struct CompanionView: View {
    let entry: CompanionRosterEntry
    var size: CGFloat = 96
    var isActive: Bool = false
    var onActivate: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

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
                if isActive {
                    Capsule()
                        .fill(accent)
                        .frame(width: 24, height: 3)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .accessibilityLabel("Companion \(entry.name)")
        .accessibilityValue(isActive ? "active" : "available")
        .accessibilityHint("Activate \(entry.name) as the foreground persona")
    }

    @ViewBuilder
    private var bodyLayer: some View {
        if reduceMotion {
            staticBody
        } else {
            breathingBody
        }
    }

    /// Reduce-motion fallback: the companion's body in its rest pose
    /// + a small text "idle" badge so the user knows the surface is
    /// alive but not animating. Invariant I-14 conformance.
    private var staticBody: some View {
        CompanionAvatarGlyph(
            kind: entry.bodyKind,
            accent: accent,
            phase: 0.5,
            reduceMotionOverride: true,
            showsIdleBadge: true
        )
    }

    /// Idle animation per Invariant I-5 (`cosmetic_idle`): slow breathe
    /// (4-second period) of the halo + a subtle scale of the figure.
    /// All driven by TimelineView so no Combine subscription leaks.
    private var breathingBody: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let breathe = Self.breathePhase(at: context.date,
                                            seedString: entry.identityHash)
            CompanionAvatarGlyph(
                kind: entry.bodyKind,
                accent: accent,
                phase: breathe,
                reduceMotionOverride: false
            )
            .scaleEffect(0.98 + 0.02 * breathe)
        }
    }

    /// Deterministic breathe phase. Per-companion phase offset comes
    /// from `seedString` so two companions on screen don't pulse in
    /// lockstep (would feel mechanical). Invariant I-13: same seed +
    /// same date = same phase.
    nonisolated static func breathePhase(at date: Date, seedString: String) -> CGFloat {
        var prng = DeterministicPRNG(seedString: seedString)
        let phaseOffset = prng.unitDouble() * .pi * 2.0
        let t = date.timeIntervalSinceReferenceDate
        let raw = sin(t * 2.0 * .pi / 4.0 + phaseOffset)
        return CGFloat((raw + 1.0) / 2.0)
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
