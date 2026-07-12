import Foundation

nonisolated enum EngineLogDiagnostics {
    static let maxLogMessageCharacters = 240
    private static let maxDomainCharacters = 80

    static func logMessage(for error: Error, fallback: String) -> String {
        if let message = agentCoreMessage(from: error),
           let safeMessage = safeFFIMessageDetail(message) {
            return logMessage("\(fallback): \(safeMessage)", fallback: fallback)
        }

        let nsError = error as NSError
        return logMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func logMessage(_ message: String, fallback: String = "Engine operation failed") -> String {
        let bounded = String(message.prefix(maxLogMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxLogMessageCharacters else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(
            trimmed.startIndex,
            offsetBy: max(0, maxLogMessageCharacters - suffix.count)
        )
        return String(trimmed[..<end]) + suffix
    }

    static func agentCoreCallbackMessage(_ message: String, fallback: String) -> String {
        guard let safeMessage = safeFFIMessageDetail(message) else {
            return fallback
        }
        return logMessage("\(fallback): \(safeMessage)", fallback: fallback)
    }

    private static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= maxDomainCharacters else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: maxDomainCharacters)
            return String(trimmed[..<end])
        }
        return trimmed
    }

    private static func agentCoreMessage(from error: Error) -> String? {
        guard let ffiError = error as? AgentErrorFfi else { return nil }
        switch ffiError {
        case .AgentError(let message):
            return message
        }
    }

    private static func safeFFIMessageDetail(_ message: String) -> String? {
        let bounded = String(message.prefix(maxLogMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }

        // FFI messages may include provider/runtime errors, but they can also
        // carry vault paths or transport headers. Preserve the actionable
        // operation while replacing path-bearing tokens and rejecting any
        // message that looks credential-bearing.
        let lower = trimmed.lowercased()
        let forbiddenCredentialFragments = [
            "bearer ",
            "authorization",
            "access_token",
            "refresh_token",
            "client_secret",
            "secret=",
            "password",
            "sk-",
            "AIza",
        ]
        guard !forbiddenCredentialFragments.contains(where: { lower.contains($0.lowercased()) }) else {
            return nil
        }

        let redacted = trimmed
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { token in
                token.contains("/") || token.contains("\\")
                    ? "<redacted-path>"
                    : String(token)
            }
            .joined(separator: " ")
        return redacted.isEmpty ? nil : redacted
    }
}
