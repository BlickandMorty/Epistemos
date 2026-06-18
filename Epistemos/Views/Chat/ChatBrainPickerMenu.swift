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
// Thin wrapper over the shared runtime popover so main chat and landing
// keep their existing call sites while gaining the same explicit routing
// controls as the standalone chat surfaces.

struct ChatBrainPickerMenu: View {
    var operatingMode: Binding<EpistemosOperatingMode>? = nil
    var availableOperatingModes: [EpistemosOperatingMode]? = nil
    var isTemporaryChatEnabled: Binding<Bool>? = nil
    /// Main chat's composer wants the full split toolbar (mode / model /
    /// routing / effort / native controls). Landing's hero chat wants the
    /// single compact "Fast · Qwen" popover, same as mini/note/graph.
    /// Default off so only the opted-in caller (main chat) splits.
    var preferSplitToolbarControls: Bool = false
    /// When the host renders its own flat inline runtime picker (the main-chat
    /// composer does), the split toolbar's floating model button is redundant —
    /// hide it so there's exactly one model picker. Default off → every other
    /// surface keeps the model button unchanged.
    var hidesModelButton: Bool = false

    var body: some View {
        LocalModelToolbarMenu(
            variant: .toolbar,
            operatingMode: operatingMode,
            availableOperatingModes: availableOperatingModes,
            isTemporaryChatEnabled: isTemporaryChatEnabled,
            preferSplitToolbarControls: preferSplitToolbarControls,
            hidesModelButton: hidesModelButton
        )
    }
}
