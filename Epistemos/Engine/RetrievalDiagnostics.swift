import Foundation

nonisolated enum RetrievalDiagnostics {
    static let maxStatusMessageCharacters = 240

    static func statusMessage(for error: Error, fallback: String) -> String {
        let nsError = error as NSError
        return statusMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func statusMessage(_ message: String, fallback: String = "Retrieval operation failed") -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxStatusMessageCharacters else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(
            trimmed.startIndex,
            offsetBy: max(0, maxStatusMessageCharacters - suffix.count)
        )
        return String(trimmed[..<end]) + suffix
    }

    private static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= 80 else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: 80)
            return String(trimmed[..<end])
        }
        return trimmed
    }
}
