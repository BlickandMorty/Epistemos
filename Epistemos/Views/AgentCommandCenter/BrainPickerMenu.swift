import SwiftUI

// MARK: - Brain Picker Menu
// Compact Claude-like picker for model, Epistemos mode, and view density.
// This keeps the app truthful: Fast / Thinking / Pro / Agent are the canonical
// modes, while provider-native effort knobs can be added only when a selected
// runtime actually exposes them.

struct BrainPickerMenu: View {
    @Environment(AgentCommandCenterState.self) private var accState
    @Environment(UIState.self) private var ui

    private let terminalInset = Color(red: 0.115, green: 0.116, blue: 0.116)
    private let terminalBorder = Color.white.opacity(0.10)
    private var theme: EpistemosTheme { ui.theme }

    private var currentBrainLabel: String {
        accState.selectedBrain?.displayName ?? "Auto"
    }

    private var currentBrainIcon: String {
        accState.selectedBrain?.icon ?? "bolt.circle"
    }

    private var currentModeLabel: String {
        accState.selectedOperatingMode.displayName
    }

    private var currentNativeEffortLabel: String? {
        accState.selectedNativeProviderEffort?.displayName
    }

    var body: some View {
        Menu {
            modelSection

            modeSection

            nativeEffortSection

            viewSection
        } label: {
            HStack(spacing: 5) {
                Image(systemName: currentBrainIcon)
                    .font(.system(size: 12, weight: .medium))
                Text(currentBrainLabel)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
                Text("·")
                    .foregroundStyle(theme.textTertiary)
                Text(currentModeLabel)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
                if let currentNativeEffortLabel {
                    Text("·")
                        .foregroundStyle(theme.textTertiary)
                    Text(currentNativeEffortLabel)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(theme.textPrimary)
            .background(
                terminalInset.opacity(theme.isDark ? 0.82 : 0.74),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(theme.border.opacity(0.75), lineWidth: 0.7)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Menu Sections

    @ViewBuilder
    private var modelSection: some View {
        Section("Models") {
            Button {
                accState.selectedBrain = nil
            } label: {
                menuRow(
                    title: "Auto",
                    detail: "Let Epistemos route",
                    icon: "bolt.circle",
                    isSelected: accState.selectedBrain == nil,
                    shortcut: "A"
                )
            }

            ForEach(accState.availableBrains) { brain in
                brainButton(brain)
            }
        }
    }

    private var modeSection: some View {
        Section("Mode") {
            ForEach(EpistemosOperatingMode.allCases, id: \.self) { mode in
                Button {
                    accState.selectedOperatingMode = mode
                } label: {
                    menuRow(
                        title: mode.displayName,
                        detail: mode.helpText,
                        icon: mode.systemImage,
                        isSelected: accState.selectedOperatingMode == mode,
                        shortcut: modeShortcut(mode)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var nativeEffortSection: some View {
        let efforts = accState.supportedNativeProviderEfforts
        if !efforts.isEmpty {
            Section("Native Effort") {
                ForEach(efforts) { effort in
                    Button {
                        accState.nativeProviderEffort = effort
                    } label: {
                        menuRow(
                            title: effort.displayName,
                            detail: effort.detail,
                            icon: "gauge.with.dots.needle.67percent",
                            isSelected: accState.nativeProviderEffort == effort,
                            shortcut: effortShortcut(effort)
                        )
                    }
                }
            }
        }
    }

    private var viewSection: some View {
        Section("View") {
            ForEach(ACCPresentationMode.allCases) { mode in
                Button {
                    selectPresentationMode(mode)
                } label: {
                    menuRow(
                        title: mode.displayName,
                        detail: mode.detail,
                        icon: mode.icon,
                        isSelected: accState.presentationMode == mode,
                        shortcut: nil
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func brainButton(_ brain: ACCBrainSelection) -> some View {
        Button {
            accState.selectedBrain = brain
        } label: {
            menuRow(
                title: brain.displayName,
                detail: brainSubtitle(brain),
                icon: brain.icon,
                isSelected: accState.selectedBrain == brain,
                shortcut: nil
            )
        }
    }

    private func selectPresentationMode(_ mode: ACCPresentationMode) {
        accState.presentationMode = mode

        switch mode {
        case .compact:
            accState.inspectorState = .collapsed
        case .standard:
            if case .expanded = accState.inspectorState {
                accState.inspectorState = .collapsed
            }
        case .advanced:
            if case .collapsed = accState.inspectorState {
                accState.inspectorState = .expanded(.capabilities)
            }
        }
    }

    // MARK: - Rows

    private func menuRow(
        title: String,
        detail: String,
        icon: String,
        isSelected: Bool,
        shortcut: String?
    ) -> some View {
        Label {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        } icon: {
            Image(systemName: icon)
        }
    }

    private func brainSubtitle(_ brain: ACCBrainSelection) -> String {
        switch brain {
        case .local(_, _, let thinking, let vision, let tools):
            var labels: [String] = ["Local"]
            if thinking { labels.append("thinking") }
            if vision { labels.append("vision") }
            if tools { labels.append("tools") }
            return labels.joined(separator: " · ")
        case .appleIntelligence:
            return "On-device"
        case .cloud(let provider):
            return provider.displayName
        }
    }

    private func modeShortcut(_ mode: EpistemosOperatingMode) -> String {
        switch mode {
        case .fast: "F"
        case .thinking: "T"
        case .pro: "P"
        case .agent: "A"
        }
    }

    private func effortShortcut(_ effort: ACCNativeProviderEffort) -> String {
        switch effort {
        case .low: "1"
        case .medium: "2"
        case .high: "3"
        case .max: "4"
        }
    }
}
