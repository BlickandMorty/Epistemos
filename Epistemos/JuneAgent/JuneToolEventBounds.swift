#if EPISTEMOS_APP_STORE
import Foundation

@MainActor
enum JuneToolEventBounds {
    static let maxToolPayloadBytes = 12_000
    static let maxToolEventIDBytes = 128
    static let maxToolNameBytes = 128
    static let maxToolRiskLevelBytes = 64
    private static let toolPayloadTruncationMarker = "\n[truncated]"

    static func boundedToolPayload(_ value: String) -> String {
        let roots = JuneAgentCoreVaultScope.redactedVaultRootCandidates()
        let lookaheadBytes = roots.reduce(0) { max($0, $1.utf8.count) }
        let scanLimit = maxToolPayloadBytes + lookaheadBytes
        let scanned = truncateUTF8(value, maxBytes: scanLimit, appendMarker: false)
        let redacted = redactKnownVaultRoots(in: scanned, roots: roots)
        return truncateUTF8(redacted, maxBytes: maxToolPayloadBytes, appendMarker: value.utf8.count > maxToolPayloadBytes)
    }

    static func boundedToolMetadata(_ value: String, maxBytes: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return truncateUTF8(trimmed, maxBytes: maxBytes, appendMarker: false)
    }

    static func boundedToolProtocolID(_ value: String) -> String? {
        guard isBoundedToolProtocolID(value) else { return nil }
        return value
    }

    static func isBoundedToolProtocolID(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.utf8.count <= maxToolEventIDBytes
            && value.rangeOfCharacter(from: .controlCharacters) == nil
    }

    static func approvalDescription(
        toolName: String,
        riskLevel: String,
        inputJson: String
    ) -> String {
        let bounded = boundedToolPayload(inputJson)
        if bounded.isEmpty || bounded == "{}" {
            return "\(toolName) requests \(riskLevel) access."
        }
        return "\(toolName) requests \(riskLevel) access:\n\(bounded)"
    }

    private static func redactKnownVaultRoots(in value: String, roots: [String]) -> String {
        var redacted = value
        for path in roots where !path.isEmpty {
            redacted = redacted.replacingOccurrences(of: path, with: "[vault]")
        }
        return redacted
    }

    private static func truncateUTF8(_ value: String, maxBytes: Int, appendMarker: Bool) -> String {
        let marker = appendMarker ? toolPayloadTruncationMarker : ""
        let bodyLimit = max(0, maxBytes - marker.utf8.count)
        guard value.utf8.count > bodyLimit else { return value + marker }
        var candidate = String(value.prefix(bodyLimit))
        while candidate.utf8.count > bodyLimit, !candidate.isEmpty {
            candidate.removeLast()
        }
        return candidate + marker
    }
}
#endif
