import Foundation
import Observation

enum SidebarMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case myVault
    case modelVaults
    case system

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .myVault:
            "Vault"
        case .modelVaults:
            "Models"
        case .system:
            "System"
        }
    }

    var systemImage: String {
        switch self {
        case .myVault:
            "tray.full"
        case .modelVaults:
            "cube.transparent"
        case .system:
            "gearshape.2"
        }
    }
}

@MainActor
@Observable
final class SidebarModeStore {
    nonisolated static let modeKey = "sidebar.mode"

    @ObservationIgnored private let defaults: UserDefaults

    var currentMode: SidebarMode {
        didSet {
            defaults.set(currentMode.rawValue, forKey: Self.modeKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawMode = defaults.string(forKey: Self.modeKey),
           let mode = SidebarMode(rawValue: rawMode) {
            currentMode = mode
        } else {
            currentMode = .myVault
        }
    }

    func select(_ mode: SidebarMode) {
        currentMode = mode
    }
}
