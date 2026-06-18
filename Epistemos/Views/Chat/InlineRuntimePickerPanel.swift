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
    /// Single-button surfaces (landing/mini/note/graph) carry the WHOLE picker
    /// in one control, so the inline panel shows a footer linking the advanced
    /// bits (cloud, routing, model details) to Settings. Main chat keeps those
    /// as their own split-toolbar buttons, so it leaves this off (default).
    var showsSettingsFooter: Bool = false

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
        // Capped + scrollable so a tier with many models (Think holds VibeThinker
        // + Qwen 4B/8B + LFM + the 12B 2-bit) never pushes the composer off-screen
        // — matches the old popover's 380pt scroll budget, just flat + in-flow.
        ScrollView {
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

                // MODE / Chat·Act depth (owner 2026-06-18 cross-reference — the
                // old depthToggle). Restores Act reachability on the single-button
                // surfaces (tier picks only reach Fast/Think/Code). Honest gating:
                // Act is disabled with the real reason when no agent route exists.
                if showsSettingsFooter, let operatingMode {
                    let actAvailable = CoworkChatMode.actAvailable(in: inference.availableOperatingModes)
                    let currentMode = CoworkChatMode.current(for: operatingMode.wrappedValue)
                    Divider()
                        .padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MODE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(theme.textTertiary)
                        coworkRow(.chat, current: currentMode, available: true, operatingMode: operatingMode)
                        coworkRow(.act, current: currentMode, available: actAvailable, operatingMode: operatingMode)
                    }
                }

                // EFFORT (owner 2026-06-18 cross-reference — the old effort
                // control). Single-button surfaces (showsSettingsFooter) gain the
                // reasoning-effort picker the main-chat split toolbar already has.
                // availableReasoningTiers is empty for Fast (correctly no effort)
                // and [.low,.medium,.high,.heavy] for Think/Code/Act.
                if showsSettingsFooter, let operatingMode {
                    let tiers = inference.availableReasoningTiers(for: operatingMode.wrappedValue)
                    if !tiers.isEmpty {
                        Divider()
                            .padding(.vertical, 2)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EFFORT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundStyle(theme.textTertiary)
                            let current = inference.sanitizedReasoningTier(
                                inference.chatReasoningTier,
                                for: operatingMode.wrappedValue
                            )
                            ForEach(tiers, id: \.self) { tier in
                                effortRow(
                                    tier,
                                    mode: operatingMode.wrappedValue,
                                    isSelected: current == tier
                                )
                            }
                        }
                    }
                }

                if showsSettingsFooter {
                    Divider()
                        .padding(.vertical, 2)
                    Button {
                        onOpenSettings()
                        onPicked()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Cloud, routing & model details — Settings")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(theme.resolved.accent.color)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 320)
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

    /// A reasoning-effort (ChatReasoningTier) row. Setting effort is a refinement
    /// of the current tier, so it does NOT collapse the panel (no onPicked) —
    /// the owner can keep adjusting; the trigger closes it.
    @ViewBuilder
    private func effortRow(
        _ tier: ChatReasoningTier,
        mode: EpistemosOperatingMode,
        isSelected: Bool
    ) -> some View {
        Button {
            inference.setChatReasoningTier(tier, for: mode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(inference.reasoningTierLabel(for: tier, operatingMode: mode))
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                    Text(tier.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.resolved.accent.color)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.resolved.accent.color.opacity(0.14) : Color.clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(theme.resolved.accent.color)
                        .frame(width: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tier.summary)
    }

    /// A Chat/Act depth row. Act is disabled (with the honest reason) when no
    /// agent route exists — never fakes agent capability for a local model.
    @ViewBuilder
    private func coworkRow(
        _ mode: CoworkChatMode,
        current: CoworkChatMode,
        available: Bool,
        operatingMode: Binding<EpistemosOperatingMode>
    ) -> some View {
        let isSelected = current == mode
        Button {
            guard available else {
                onOpenSettings()
                return
            }
            operatingMode.wrappedValue = mode.operatingMode(
                rememberedTier: rememberedTier(operatingMode.wrappedValue)
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(available ? theme.textSecondary : theme.textTertiary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.displayName)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(available ? theme.textPrimary : theme.textTertiary)
                    if mode == .act && !available {
                        Text(CoworkChatMode.actUnavailableReason)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.resolved.accent.color)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.resolved.accent.color.opacity(0.14) : Color.clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(theme.resolved.accent.color)
                        .frame(width: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Remember which tier to return to when toggling Chat/Act: keep a real tier
    /// mode; .agent (Act) has no tier of its own, so default to Fast.
    private func rememberedTier(_ mode: EpistemosOperatingMode) -> EpistemosOperatingMode {
        switch mode {
        case .fast, .thinking, .pro: return mode
        case .agent: return .fast
        }
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
