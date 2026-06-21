import SwiftUI

/// "Epistemos Picks" — the curated, pixel-art presentation of the owner's hardened models
/// (Gemma QAT ladder + explicit Qwen extras + curated Apple Intelligence), top-billed above
/// generic "Installed Models". Owner 2026-06-21: surface my custom hardened models as a
/// distinct section so they aren't lost in the act/Osaurus model stack.
///
/// Pure-data layer is `EpistemosPicks` (verified, tested); this is its VIEW. It reuses the
/// proven live-state → `EpistemosRuntimePicker.Environment` mapping (identical to
/// `InlineRuntimePickerPanel`) and the same HONEST gating — a too-large/uninstalled pick
/// stays VISIBLE with its reason and is non-selectable, never a silent Qwen substitute. The
/// front-end is the minimal Epistemos pixel-art skin (monospaced titles, hard 1.5px border,
/// solid `theme.card`). This same component is what the act composer's model picker mounts (S4).
struct EpistemosPicksSectionView: View {
    let inference: InferenceState

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    /// Live inputs → the picker environment (same mapping as `InlineRuntimePickerPanel`):
    /// installed ∪ prepared models, free memory, Apple-Intelligence availability, and the
    /// owner's advertised additional picks. Single source of truth — no drift.
    private var environment: EpistemosRuntimePicker.Environment {
        let bytes = LocalInferenceMemoryPressureMonitor.availableMemoryBytes()
        let freeGB = bytes > 0 ? Int(bytes / 1_073_741_824) : 0
        let installed = inference.installedLocalTextModelIDs.union(inference.preparedLocalTextModelIDs)
        let store = AdvertisedModelStore()
        return .init(
            installedModelIDs: installed,
            freeMemoryGB: freeGB,
            appleIntelligenceAvailable: inference.appleIntelligenceAvailable,
            additionalPicks: RuntimePickerExtraPicksBuilder.picks(
                installedIDs: installed,
                advertised: store.effectiveAdvertised(fullCatalog: installed),
                isCustomized: store.isCustomized
            )
        )
    }

    private var groups: [EpistemosPicks.Group] {
        EpistemosPicks.allSections(environment: environment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.section.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(theme.textTertiary)
                    Text(group.section.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.bottom, 2)
                    ForEach(group.options) { option in
                        pickRow(option)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card)
        .overlay(Rectangle().strokeBorder(theme.border, lineWidth: 1.5))
        .accessibilityIdentifier("EpistemosPicksSectionView")
    }

    @ViewBuilder
    private func pickRow(_ option: EpistemosRuntimePicker.Option) -> some View {
        let selected = isSelected(option)
        Button {
            select(option)
        } label: {
            HStack(spacing: 8) {
                ProviderLogoView(
                    brand: option.isAppleIntelligence ? .apple : ProviderBrand.local(modelID: option.id),
                    size: 16
                )
                .foregroundStyle(option.isSelectable ? theme.textSecondary : theme.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(option.isSelectable ? theme.textPrimary : theme.textTertiary)
                    // Honest: a blocked pick shows its real reason; otherwise the tier tagline.
                    Text(option.blockedReason ?? option.tier.tagline)
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
                    // Honestly un-pickable (not installed / won't fit) — not a silent swap.
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? theme.resolved.accent.color.opacity(0.14) : Color.clear)
            .overlay(alignment: .leading) {
                if selected {
                    Rectangle().fill(theme.resolved.accent.color).frame(width: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!option.isSelectable)
        .help(option.blockedReason ?? option.title)
    }

    private func isSelected(_ option: EpistemosRuntimePicker.Option) -> Bool {
        if option.isAppleIntelligence {
            return inference.preferredChatModelSelection == .appleIntelligence
        }
        return inference.preferredChatModelSelection == .localMLX(option.id)
    }

    /// Pin the picked model via the SAME honest path as the composer picker. Blocked picks
    /// are disabled (never selected here) — no silent substitute.
    private func select(_ option: EpistemosRuntimePicker.Option) {
        guard option.isSelectable else { return }
        if option.isAppleIntelligence {
            inference.setPreferredChatModelSelection(.appleIntelligence)
        } else {
            inference.setPreferredChatModelSelection(.localMLX(option.id))
        }
    }
}
