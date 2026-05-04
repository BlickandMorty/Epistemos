import SwiftUI

/// Notes Sidebar Skin — Simulation Mode v1.6 third placement (alongside
/// Landing Farm + Graph Live Theater). Renders a compact strip of the
/// active companion's presence in any sidebar that wants to host it.
///
/// Per the doctrine: this is the user's "ambient companion" — when
/// they're working in notes, the active companion sits at the edge of
/// the surface, idle-breathing, ready for activation. Reacts to the
/// AgentEvent stream so when the agent emits a thinking / tool-call
/// event, the companion's state badge updates ("thinking…", "writing…",
/// idle).
///
/// Embed via `NotesSidebarSkin(companionState:)` in any sidebar; the
/// view collapses to a thin "no active companion" rail when none is
/// foregrounded so it never intrudes.
struct NotesSidebarSkin: View {
    @Bindable var companionState: CompanionState
    var theme: EpistemosTheme
    /// Optional ambient label set by the host (e.g. "thinking…",
    /// "writing…"). Visual only; the AgentEvent → label translation
    /// is the host's responsibility so this stays a thin renderer.
    var ambientLabel: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeEntry: CompanionRosterEntry? {
        guard let activeID = companionState.activeCompanionID else { return nil }
        return companionState.roster.first(where: { $0.id == activeID })
    }

    var body: some View {
        VStack(spacing: 8) {
            if let entry = activeEntry {
                activeBody(entry)
            } else {
                idleRail
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .frame(width: 92)
        .background(skinBackground)
    }

    // MARK: - Active

    private func activeBody(_ entry: CompanionRosterEntry) -> some View {
        VStack(spacing: 8) {
            CompanionView(entry: entry, size: 56)
            Text(entry.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
            if let ambient = ambientLabel, !ambient.isEmpty {
                ambientPill(ambient, accent: Color(hex: entry.accentHex) ?? theme.resolved.accent.color)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            Button {
                companionState.deactivate()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                    Text("clear")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(theme.textTertiary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: ambientLabel)
    }

    private func ambientPill(_ label: String, accent: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .modifier(BreathingDotModifier(accent: accent, reduceMotion: reduceMotion))
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(accent.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(accent.opacity(0.10)))
    }

    // MARK: - Idle (no active companion)

    private var idleRail: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(theme.textTertiary.opacity(0.45))
            Text("no active\ncompanion")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textTertiary.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Background

    private var skinBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.textTertiary.opacity(0.10), lineWidth: 0.5)
            )
    }
}

// MARK: - Helpers

/// Subtle accent-colored breathing dot used in the ambient pill.
private struct BreathingDotModifier: ViewModifier {
    let accent: Color
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let phase = (sin(context.date.timeIntervalSinceReferenceDate * 2.0 * .pi / 1.8) + 1.0) / 2.0
                content
                    .opacity(0.55 + 0.45 * phase)
                    .shadow(color: accent.opacity(0.6 * phase), radius: 3 * phase)
            }
        }
    }
}
