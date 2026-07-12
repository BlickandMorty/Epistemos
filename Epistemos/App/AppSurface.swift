import Foundation

enum AppSurface: String, Sendable {
    case appStore
    static let current: AppSurface = .appStore

    var isSandboxed: Bool { true }
    var allowsSubprocessCapabilities: Bool { false }
    var rendersCompanionPresence: Bool { false }
}
