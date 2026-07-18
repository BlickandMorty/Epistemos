import Foundation

nonisolated enum LiteParseImportSettings {
    static let parsePDFOnImportKey = "epistemos.liteparse.parsePDFOnImport"
    static let defaultOpenForImportedPDFKey = "epistemos.liteparse.defaultOpenForImportedPDF"

    enum DefaultOpenTarget: String, Sendable {
        case parsedNote
        case originalPDF
    }

    static func parsePDFOnImport(defaults: UserDefaults = FoundationSafety.runtimeUserDefaults) -> Bool {
        guard defaults.object(forKey: parsePDFOnImportKey) != nil else { return true }
        return defaults.bool(forKey: parsePDFOnImportKey)
    }

    static func defaultOpenForImportedPDF(defaults: UserDefaults = FoundationSafety.runtimeUserDefaults) -> DefaultOpenTarget {
        guard let raw = defaults.string(forKey: defaultOpenForImportedPDFKey),
              let target = DefaultOpenTarget(rawValue: raw) else {
            return .parsedNote
        }
        return target
    }
}
