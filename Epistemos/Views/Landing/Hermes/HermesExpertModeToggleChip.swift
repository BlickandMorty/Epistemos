import SwiftUI

/// Bottom-row CommandHint-shaped chip that toggles Hermes Expert Mode.
/// Reads the same as the other landing shortcut chips (icon + label,
/// `LandingShortcutDisplay.font()`, hover-glass) but with two extra
/// affordances when active:
///
/// - Accent-tinted icon + label
/// - A small breathing accent dot to the right of the label so the
///   chip reads as live state, not a one-shot button
struct HermesExpertModeToggleChip: View {
    var isActive: Bool
    let theme: EpistemosTheme
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(iconColor)
                Text(isActive ? "Hermes Mode On" : "Hermes Mode")
                    .font(LandingShortcutDisplay.font())
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if isActive {
                    breathingDot
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
            .contentShape(Rectangle())
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(
                cornerRadius: LandingShortcutDisplay.keyCornerRadius + 4,
                style: .continuous
            )
            .fill(isActive
                ? theme.resolved.accent.color.opacity(theme.isDark ? 0.10 : 0.08)
                : .clear)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: LandingShortcutDisplay.keyCornerRadius + 4,
                style: .continuous
            )
            .stroke(isActive
                ? theme.resolved.accent.color.opacity(0.32)
                : .clear, lineWidth: 0.6)
        )
        .hoverGlass(flatBackground: .clear,
                    cornerRadius: LandingShortcutDisplay.keyCornerRadius + 4)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isActive)
        .accessibilityLabel(isActive
            ? "Hermes Expert Mode is on. Click to exit."
            : "Hermes Expert Mode is off. Click to enter.")
    }

    private var iconColor: Color {
        isActive ? theme.resolved.accent.color : theme.textSecondary
    }

    private var labelColor: Color {
        isActive ? theme.resolved.accent.color : theme.textSecondary
    }

    @ViewBuilder
    private var breathingDot: some View {
        if reduceMotion {
            Circle()
                .fill(theme.resolved.accent.color)
                .frame(width: 6, height: 6)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let phase = (sin(context.date.timeIntervalSinceReferenceDate * 2.0 * .pi / 1.6) + 1.0) / 2.0
                Circle()
                    .fill(theme.resolved.accent.color)
                    .frame(width: 6, height: 6)
                    .opacity(0.55 + 0.45 * phase)
                    .shadow(color: theme.resolved.accent.color.opacity(0.6 * phase),
                            radius: 4 * phase)
            }
            .frame(width: 6, height: 6)
        }
    }
}
