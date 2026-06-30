import Foundation

nonisolated enum BrowserUseVendorManifestError: Error, LocalizedError, Equatable {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let reason):
            return reason
        }
    }
}
