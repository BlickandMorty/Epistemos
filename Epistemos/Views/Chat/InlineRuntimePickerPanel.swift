import SwiftUI

/// Flat, inline, pixel-art runtime picker (owner 2026-06-18: "delete the
/// .popover, rebuild as a flat inline pixel-art panel — modelPopover/
/// simplifiedRuntimePopover"). Renders the SAME explicit per-tier Fast/Think/
/// Code model picks as the popover's `foundationPickerSection`, driven by the
/// standalone `EpistemosRuntimePicker` with the SAME honest install+memory
/// gating — but as a flat in-flow panel (sharp pixel-art border, monospaced
/// titles, solid `theme.card` background, no system popover bubble) that lives
/// in the composer's vertical stack instead of a floating macOS popover.
///
/// Self-contained: depends only on `InferenceState` (selection + install/AI
/// availability) and `EpistemosRuntimePicker` (the standalone option model), so
/// it needs none of `LocalModelToolbarMenu`'s private popover plumbing.
struct InlineRuntimePickerPanel: View {
    let inference: InferenceState
    var operatingMode: Binding<EpistemosOperatingMode>?
    /// Invoked after a successful pick so the host can collapse the panel.
    var onPicked: () -> Void
    /// A blocked pick (not installed / won't fit memory) routes here — the
    /// honest path to install or free memory, never a silent switch.
    var onOpenSettings: () -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var environment: EpistemosRuntimePicker.Environment {
        let bytes = LocalInferenceMemoryPressureMonitor.availableMemoryBytes()
        let freeGB = bytes > 0 ? Int(bytes / 1_073_741_824) : 0
        return .init(
            installedModelIDs: inference.installedLocalTextModelIDs,
            freeMemoryGB: freeGB,
            appleIntelligenceAvailable: inference.appleIntelligenceAvailable
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(EpistemosModelTier.allCases, id: \.rawValue) { tier in
                VStack(alignment: .leading, spacing: 6) {
                    Text(tier.shortName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(theme.textTertiary)
                    ForEach(EpistemosRuntimePicker.options(for: tier, environment: environment)) { option in
                        pickRow(option, tier: tier)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Flat pixel-art chrome: solid fill + a hard 1.5px rectangular border,
        // no rounding, no shadow — the opposite of the rounded translucent
        // popover bubble.
        .background(theme.card)
        .overlay(
            Rectangle()
                .strokeBorder(theme.border, lineWidth: 1.5)
        )
        .accessibilityIdentifier("InlineRuntimePickerPanel")
    }

    @ViewBuilder
    private func pickRow(_ option: EpistemosRuntimePicker.Option, tier: EpistemosModelTier) -> some View {
        let selected = isSelected(option)
        Button {
            select(option)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: option.isAppleIntelligence ? "apple.intelligence" : tier.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(option.isSelectable ? theme.textSecondary : theme.textTertiary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(option.isSelectable ? theme.textPrimary : theme.textTertiary)
                    Text(option.blockedReason ?? tier.tagline)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.resolved.accent.color)
                } else if !option.isSelectable {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Flat selected highlight: a hard accent-tinted rectangle, no capsule.
            .background(selected ? theme.resolved.accent.color.opacity(0.14) : Color.clear)
            .overlay(alignment: .leading) {
                if selected {
                    Rectangle()
                        .fill(theme.resolved.accent.color)
                        .frame(width: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(option.blockedReason ?? option.title)
    }

    private func isSelected(_ option: EpistemosRuntimePicker.Option) -> Bool {
        if option.isAppleIntelligence {
            return inference.preferredChatModelSelection == .appleIntelligence
        }
        return inference.preferredChatModelSelection == .localMLX(option.id)
    }

    private func operatingModeForTier(_ tier: EpistemosModelTier) -> EpistemosOperatingMode {
        switch tier {
        case .fast: return .fast
        case .think: return .thinking
        case .code: return .pro
        }
    }

    /// Mirrors `LocalModelToolbarMenu.selectRuntimePick`: a blocked pick routes
    /// to Settings (honest install/free-memory path); a valid pick sets the
    /// tier's operating mode and pins the model, then collapses the panel.
    private func select(_ option: EpistemosRuntimePicker.Option) {
        guard option.isSelectable else {
            onOpenSettings()
            onPicked()
            return
        }
        operatingMode?.wrappedValue = operatingModeForTier(option.tier)
        if option.isAppleIntelligence {
            inference.setPreferredChatModelSelection(.appleIntelligence)
        } else {
            inference.setPreferredChatModelSelection(.localMLX(option.id))
        }
        onPicked()
    }
}
