import SwiftUI

enum MainChatOperatingModePreference {
    static let defaultsKey = "epistemos.mainChatOperatingMode"

    @MainActor
    static func supportedModes(
        for inference: InferenceState,
        availableModes: [EpistemosOperatingMode]? = nil
    ) -> [EpistemosOperatingMode] {
        let modes = availableModes ?? inference.availableOperatingModes
        return modes.isEmpty ? [.fast] : modes
    }

    @MainActor
    static func sanitize(
        _ mode: EpistemosOperatingMode,
        for inference: InferenceState,
        availableModes: [EpistemosOperatingMode]? = nil
    ) -> EpistemosOperatingMode {
        let supportedModes = supportedModes(for: inference, availableModes: availableModes)
        guard supportedModes.contains(mode) else {
            return supportedModes.first ?? .fast
        }
        return mode
    }
}

// MARK: - Chat Brain Picker Menu
// Compact inline model picker for Main Chat + Landing Chat popover.
// Mirrors the agent page's `BrainPickerMenu` but binds to
// `InferenceState.preferredChatModelSelection` so the user always sees which
// model is powering the next chat turn, and can switch without leaving the
// composer.

struct ChatBrainPickerMenu: View {
    var operatingMode: Binding<EpistemosOperatingMode>? = nil
    var availableOperatingModes: [EpistemosOperatingMode]? = nil

    @Environment(InferenceState.self) private var inference
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    private var installedLocalIDs: [String] {
        inference.releaseSelectableInstalledLocalTextModelIDs
    }

    private var currentLabel: String {
        inference.activeChatModelDisplayName
    }

    private var displayedOperatingModes: [EpistemosOperatingMode] {
        MainChatOperatingModePreference.supportedModes(
            for: inference,
            availableModes: availableOperatingModes
        )
    }

    private var currentModeLabel: String? {
        operatingMode?.wrappedValue.displayName
    }

    private var isAutomaticCloudRoutingEnabled: Bool {
        inference.chatAutoRouteToCloud && inference.preferredAutoRouteCloudProvider != nil
    }

    private var automaticCloudRoutingLabel: String {
        if let provider = inference.preferredAutoRouteCloudProvider {
            return "Auto-route Local -> \(provider.displayName)"
        }
        return "Auto-route Local -> Cloud"
    }

    private var currentIcon: String {
        if isAutomaticCloudRoutingEnabled {
            return "arrow.triangle.branch"
        }
        return switch inference.preferredChatModelSelection {
        case .appleIntelligence: "apple.logo"
        case .localMLX: "cpu"
        case .cloud: "cloud"
        }
    }

    /// Single cloud entry the picker shows: the user's currently-selected
    /// cloud model from Settings → Inference. If nothing is configured
    /// yet, falls back to the provider-default for the active AI
    /// provider so switching TO cloud from the picker still works
    /// without forcing a detour through Settings. This is the whole
    /// point of the picker simplification — instead of offering every
    /// CloudTextModelID as a row, the picker only shows the one
    /// that's active, and the user changes it in Settings.
    private var pickerCloudModel: CloudTextModelID? {
        if case .cloud(let model) = inference.preferredChatModelSelection {
            return model
        }
        guard let provider = inference.activeAIProvider.cloudProvider else {
            return nil
        }
        return inference.preferredCloudModel(for: provider)
    }

    var body: some View {
        Menu {
            Section("Apple") {
                Button {
                    inference.setPreferredChatModelSelection(.appleIntelligence)
                } label: {
                    Label("Apple Intelligence", systemImage: "apple.logo")
                }
            }

            if !installedLocalIDs.isEmpty {
                Section("Local (on-device)") {
                    ForEach(installedLocalIDs, id: \.self) { modelID in
                        let local = LocalTextModelID(rawValue: modelID)
                        Button {
                            inference.setPreferredChatModelSelection(.localMLX(modelID))
                        } label: {
                            Label(local?.displayName ?? modelID, systemImage: "cpu")
                        }
                    }
                }
            }

            // Cloud: one row only — the user's preferred cloud model from
            // Settings → Inference. Change which cloud model is active by
            // going to Settings, not by expanding this menu. Keeps the
            // picker focused on "am I on local vs cloud right now" instead
            // of forcing the user to scan 10+ cloud names in-line.
            if let cloudModel = pickerCloudModel {
                Section("Cloud") {
                    Button {
                        inference.setPreferredChatModelSelection(.cloud(cloudModel))
                    } label: {
                        Label(cloudModel.displayName, systemImage: "cloud")
                    }
                }
            }

            if let operatingMode {
                Section("Mode") {
                    ForEach(displayedOperatingModes, id: \.self) { option in
                        Button {
                            operatingMode.wrappedValue = MainChatOperatingModePreference.sanitize(
                                option,
                                for: inference,
                                availableModes: availableOperatingModes
                            )
                        } label: {
                            HStack(spacing: 8) {
                                Label(option.displayName, systemImage: option.systemImage)
                                Spacer(minLength: 8)
                                if operatingMode.wrappedValue == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: currentIcon)
                    .font(.system(size: 11, weight: .medium))
                Text(currentLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                if let currentModeLabel {
                    Text("·")
                        .foregroundStyle(theme.textTertiary)
                    Text(currentModeLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(theme.textPrimary)
            .background(
                theme.muted.opacity(theme.isDark ? 0.75 : 0.4),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.border.opacity(0.6), lineWidth: 0.6)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
