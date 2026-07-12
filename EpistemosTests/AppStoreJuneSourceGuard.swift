import Foundation

enum AppStoreJuneSourceGuard {
    nonisolated static func sourceSection(
        in source: String,
        startingAt startMarker: String,
        endingBefore endMarker: String
    ) -> String? {
        guard let startRange = source.range(of: startMarker) else { return nil }
        let searchRange = startRange.upperBound..<source.endIndex
        let endIndex = source.range(of: endMarker, range: searchRange)?.lowerBound ?? source.endIndex
        return String(source[startRange.lowerBound..<endIndex])
    }
}
