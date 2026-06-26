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
