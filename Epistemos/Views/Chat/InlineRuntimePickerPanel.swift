import SwiftUI
#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

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

    /// Owner 2026-06-18 (picker scroll/height): the panel was capped too short
    /// and macOS auto-hides the scrollbar, so only a couple of picks showed with
    /// no hint that more existed. We (a) raise the cap so more shows at once and
    /// (b) measure content-vs-viewport to surface an explicit "scroll for more"
    /// affordance whenever the content overflows — robust even if a parent
    /// compresses the panel below the cap.
    private let heightCap: CGFloat = 460
    @State private var pickerContentHeight: CGFloat = 0
    @State private var pickerViewportHeight: CGFloat = 0
    private var pickerOverflows: Bool { pickerContentHeight > pickerViewportHeight + 1 }

    /// Total picks across all tiers — surfaced in the always-visible count header so
    /// the lineup never *looks* like just the ~2 rows above the fold (owner 2026-06-18:
    /// "it seems like there were only two available because there's no scroll bar").
    private var totalModelCount: Int {
        EpistemosModelTier.allCases.reduce(0) { sum, tier in
            sum + EpistemosRuntimePicker.options(for: tier, environment: environment).count
        }
    }

    /// Always-visible header pinned above the scroll area: "N models" (+ a scroll
    /// chevron when the picks overflow the viewport). macOS hides the scrollbar and
    /// caps the panel, so without this the full lineup reads as only the couple of
    /// rows above the fold. This makes every Fast/Think/Code pick obviously reachable
    /// before the owner even scrolls.
    private var pickerCountHeader: some View {
        HStack(spacing: 6) {
            Text("\(totalModelCount) models")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(theme.textSecondary)
            if pickerOverflows {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                Text("scroll for all")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border.opacity(0.5)).frame(height: 1)
        }
    }

    private var environment: EpistemosRuntimePicker.Environment {
        let bytes = LocalInferenceMemoryPressureMonitor.availableMemoryBytes()
        let freeGB = bytes > 0 ? Int(bytes / 1_073_741_824) : 0
        return .init(
            installedModelIDs: inference.installedLocalTextModelIDs,
            freeMemoryGB: freeGB,
            appleIntelligenceAvailable: inference.appleIntelligenceAvailable
        )
    }

    /// Whether to show the in-picker "install a local model" call-to-action: only
    /// when no Epistemos foundation model is installed yet (otherwise the picker has
    /// real local picks and the CTA would be noise). Pure → unit-testable.
    static func shouldShowInstallCTA(hasInstalledFoundationModel: Bool) -> Bool {
        !hasInstalledFoundationModel
    }

    /// Unmissable install entry, shown at the top of the picker when no local model
    /// is installed. Posts `.openModelManager` (observed at the app level) so the
    /// owner reaches the foundation-package download without hunting through
    /// Settings ▸ Local AI ▸ Manage Local Models.
    private var installModelsCTA: some View {
        Button {
            NotificationCenter.default.post(name: .openModelManager, object: nil)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Install local AI")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Download Epistemos AI — Gemma · VibeThinker · coder")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.resolved.accent.color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.resolved.accent.color.opacity(0.5), lineWidth: 1)
            )
            .foregroundStyle(theme.resolved.accent.color)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        // Capped + scrollable so a tier with many models (Think holds VibeThinker
        // + Qwen 4B/8B + LFM + the 12B 2-bit) never pushes the composer off-screen
        // — matches the old popover's 380pt scroll budget, just flat + in-flow.
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Owner 2026-06-19 (top blocker — "still cannot find a way to install
                // a local model"): when no foundation model is installed, surface an
                // unmissable install CTA right here in the picker (where models are
                // chosen) that opens the model manager, instead of burying the only
                // path in Settings ▸ Local AI ▸ Manage Local Models.
                if Self.shouldShowInstallCTA(hasInstalledFoundationModel: inference.hasInstalledFoundationModel) {
                    installModelsCTA
                }
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
                    } else if operatingMode.wrappedValue.epistemosModelTier == .fast,
                              EpistemosFastEffortSizing.pickerOverrideEnabled {
                        // Fast has no thinking-budget tiers, but the owner wants the
                        // low/med/high SIZE effort visible + pinnable on Fast (L1128).
                        Divider()
                            .padding(.vertical, 2)
                        fastEffortSection
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
            // Measure the FULL (unclamped) content height so we can tell when
            // there's more below the fold than the viewport shows.
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: PickerContentHeightKey.self,
                        value: proxy.size.height
                    )
                }
            )
        }
        // Force the scrollbar to show (macOS auto-hides the overlay scroller — the
        // literal "there's no scroll bar" complaint) so overflow is obvious.
        .scrollIndicators(.visible)
        .frame(maxHeight: heightCap)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Measure the ACTUAL viewport height (after the cap + any parent
        // constraint) — overflow = content taller than what's visible.
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PickerViewportHeightKey.self,
                    value: proxy.size.height
                )
            }
        )
        .onPreferenceChange(PickerContentHeightKey.self) { pickerContentHeight = $0 }
        .onPreferenceChange(PickerViewportHeightKey.self) { pickerViewportHeight = $0 }
        // Always-visible "N models" count pinned above the scroll area (outside the
        // height cap, so it never eats scroll budget). Owner 2026-06-18: the panel
        // looked like only ~2 picks; the count makes the full lineup obvious.
        .safeAreaInset(edge: .top, spacing: 0) { pickerCountHeader }
        // Flat pixel-art chrome: solid fill + a hard 1.5px rectangular border,
        // no rounding, no shadow — the opposite of the rounded translucent
        // popover bubble.
        .background(theme.card)
        // Explicit "more exists" affordance: a fade + a "scroll for more" hint
        // pinned to the bottom edge, shown ONLY when the picks overflow the
        // viewport (so all Fast/Think/Code picks are obviously reachable even
        // though macOS hides the scrollbar).
        .overlay(alignment: .bottom) {
            if pickerOverflows {
                scrollMoreAffordance
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(theme.border, lineWidth: 1.5)
        )
        .accessibilityIdentifier("InlineRuntimePickerPanel")
    }

    /// Bottom-edge "scroll for more" cue: a short fade into the card colour, then
    /// a centered chevron + label. Non-interactive (hit-testing off) so it never
    /// blocks taps on the last visible row. Shown only when `pickerOverflows`.
    private var scrollMoreAffordance: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [theme.card.opacity(0), theme.card],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                Text("scroll for more")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.5)
            }
            .foregroundStyle(theme.textTertiary)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity)
            .background(theme.card)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func pickRow(_ option: EpistemosRuntimePicker.Option, tier: EpistemosModelTier) -> some View {
        let selected = isSelected(option)
        Button {
            select(option)
        } label: {
            HStack(spacing: 8) {
                // P6.1 — the provider brand logo for this pick (the tier is already
                // shown by the section header). Apple → apple; local model id →
                // gemma/qwen/generic via ProviderBrand.local.
                ProviderLogoView(
                    brand: option.isAppleIntelligence ? .apple : ProviderBrand.local(modelID: option.id),
                    size: 16
                )
                .foregroundStyle(option.isSelectable ? theme.textSecondary : theme.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(option.isSelectable ? theme.textPrimary : theme.textTertiary)
                    // SS-AB: show this model's SHORT use-case line ("Fastest
                    // on-device · everyday chat", "Best all-round · strong tools +
                    // reasoning", …) resolved from the single Rust ModelCapability
                    // Profile source. Falls back to the blocked reason (if blocked)
                    // or the generic tier tagline (unknown model / test host).
                    Text(option.blockedReason ?? modelUseCaseLine(for: option.id) ?? tier.tagline)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                // SS-AB: per-model context-window badge ("128K" / "1M" / "200K"),
                // resolved from the single Rust ModelCapabilityProfile source via
                // the model_context_window FFI. Hidden for an id neither lane knows.
                if let badge = modelContextBadge(for: option.id) {
                    Text(badge)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(theme.textTertiary.opacity(0.12), in: Capsule())
                        .help("Context window")
                }
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
        .help(option.blockedReason ?? modelBenefitsLine(for: option.id) ?? option.title)
    }

    /// SS-AB: the short per-model use-case line for the picker, resolved from the
    /// single Rust `ModelCapabilityProfile` source via the agent_core FFI — the
    /// Swift side does NOT duplicate the copy (one source of truth). `nil` for an
    /// unknown model id (empty FFI result) or a target that doesn't link
    /// `agent_coreFFI` (unit-test host), so the row keeps its generic tier tagline.
    private func modelUseCaseLine(for modelID: String) -> String? {
        #if canImport(agent_coreFFI)
        let line = modelPickerUseCase(modelId: modelID)
        return line.isEmpty ? nil : line
        #else
        return nil
        #endif
    }

    /// SS-AB: the richer model-details description (display name + use-case + real
    /// context window + runtime lane) for the row's hover tooltip, resolved from the
    /// single Rust `ModelCapabilityProfile` via `model_benefits_description`. `nil`
    /// for an unknown id or a non-FFI host, so the row falls back to its title.
    private func modelBenefitsLine(for modelID: String) -> String? {
        #if canImport(agent_coreFFI)
        let line = modelBenefitsDescription(modelId: modelID)
        return line.isEmpty ? nil : line
        #else
        return nil
        #endif
    }

    /// SS-AB: the per-model context-window badge string ("128K", "1M", …), resolved
    /// from the single Rust `ModelCapabilityProfile` source via the
    /// `model_context_window` FFI. `nil` for an id neither lane knows (FFI returns 0)
    /// or a target that doesn't link `agent_coreFFI` (unit-test host), so the row
    /// shows no badge.
    private func modelContextBadge(for modelID: String) -> String? {
        #if canImport(agent_coreFFI)
        return Self.formatContextWindow(modelContextWindow(modelId: modelID))
        #else
        return nil
        #endif
    }

    /// Compact a context-window token count into a picker badge: `128_000 → "128K"`,
    /// `1_048_576 → "1M"`, `0 → nil` (no badge). K uses truncation so a power-of-two
    /// window reads colloquially (`32_768 → "32K"`, not "33K"); M snaps to a whole
    /// million when within 0.1M, else one decimal.
    static func formatContextWindow(_ tokens: UInt32) -> String? {
        guard tokens > 0 else { return nil }
        if tokens >= 1_000_000 {
            if tokens % 1_000_000 < 100_000 {
                return "\(tokens / 1_000_000)M"
            }
            return String(format: "%.1fM", Double(tokens) / 1_000_000.0)
        }
        if tokens >= 1_000 {
            return "\(tokens / 1_000)K"
        }
        return "\(tokens)"
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

    /// Fast effort override selector (L1128 — "i dont see the low medium high on
    /// fast mode"). Fast has no thinking-budget tiers, so this surfaces the SIZE
    /// effort instead: Auto (per-query auto-sizing, the default) + an explicit
    /// Low/Medium/High that pins the Gemma band (E2B/E4B/12B). Only mounted when
    /// `EpistemosFastEffortSizing.pickerOverrideEnabled`.
    @ViewBuilder
    private var fastEffortSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FAST EFFORT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(theme.textTertiary)
            fastEffortRow(nil, isSelected: inference.fastEffortOverride == nil)
            ForEach(EpistemosFastEffortSizing.FastEffort.allCases, id: \.self) { effort in
                fastEffortRow(effort, isSelected: inference.fastEffortOverride == effort)
            }
        }
    }

    /// One Fast effort choice. `nil` = "Auto" (clears the override → per-query
    /// auto-sizing). A concrete effort pins the band.
    private func fastEffortRow(
        _ effort: EpistemosFastEffortSizing.FastEffort?,
        isSelected: Bool
    ) -> some View {
        let title: String = effort?.displayName ?? "Auto"
        let descriptor: String = switch effort {
        case .none: "Size to the query automatically (default)"
        case .some(.low): "Smallest Gemma — fastest, lightest"
        case .some(.medium): "Mid Gemma — balanced"
        case .some(.high): "Largest Gemma — most capable"
        }
        // Show the model this band resolves to on THIS machine ("low/medium/high"
        // is no longer abstract — the user sees e.g. "Smallest Gemma · Gemma 2B").
        let summary: String = {
            guard let effort, let model = inference.fastEffortResolvedModelName(for: effort) else {
                return descriptor
            }
            return "\(descriptor) · \(model)"
        }()
        return Button {
            inference.setFastEffortOverride(effort)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: effort == nil ? "wand.and.stars" : "gauge.medium")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                    Text(summary)
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
        .help(summary)
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

/// Full (unclamped) height of the picker's scrolling content.
private struct PickerContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Visible viewport height of the picker after the cap + any parent constraint.
private struct PickerViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
