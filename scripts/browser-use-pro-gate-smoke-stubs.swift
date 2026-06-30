import Foundation

nonisolated enum BrowserUseSettingsStoreError: Error, Equatable, LocalizedError {
    case invalidFile(String)
    case unsafePath(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile(let message),
             .unsafePath(let message):
            message
        }
    }
}
