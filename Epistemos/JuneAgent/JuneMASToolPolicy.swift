import Foundation

/// Single Swift authority for the MAS June agent tool surface. This list is
/// intentionally smaller than broader Core/Pro registries: it is the in-process
/// agent_core allowlist used by the App Store June cloud lane and by June's
/// observable composition ledger.
nonisolated enum JuneMASToolPolicy {
    private static let forbiddenNameFragments = [
        "bash",
        "browser",
        "chromium",
        "cli",
        "code_exec",
        "computer",
        "delegate",
        "goose_runtime",
        "localhost",
        "mcp",
        "process",
        "shell",
        "stdio",
        "subprocess",
        "terminal",
    ]

    static let allowedAgentToolNames: [String] = {
        let names = [
            "vault.search",
            "vault.read",
            "vault.write",
            "vault.list",
            "pdf.to_markdown",
            "knowledge.recall",
            "web.search",
            "web.fetch",
            "http_fetch",
            "think",
        ]
        precondition(
            names.allSatisfy(Self.isMASPermittedAgentToolName),
            "MAS June agent tool allowlist contains a forbidden runtime/tool name"
        )
        return names
    }()

    static let allowedObservableCompositionToolNames = Set(Self.allowedAgentToolNames)

    static func isAllowedAgentToolName(_ name: String) -> Bool {
        Self.allowedObservableCompositionToolNames.contains(name)
            && Self.isMASPermittedAgentToolName(name)
    }

    private static func isMASPermittedAgentToolName(_ name: String) -> Bool {
        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty,
              normalized.rangeOfCharacter(from: .controlCharacters) == nil else {
            return false
        }
        return !Self.containsForbiddenPackagedRuntimeName(normalized)
            && !Self.forbiddenNameFragments.contains { normalized.contains($0) }
    }

    private static func containsForbiddenPackagedRuntimeName(_ normalized: String) -> Bool {
        var matchedPrefixLength = 0
        for byte in normalized.utf8 {
            switch matchedPrefixLength {
            case 0:
                matchedPrefixLength = byte == 0x64 ? 1 : 0
            case 1:
                matchedPrefixLength = byte == 0x6f ? 2 : (byte == 0x64 ? 1 : 0)
            case 2:
                matchedPrefixLength = byte == 0x63 ? 3 : (byte == 0x64 ? 1 : 0)
            case 3:
                matchedPrefixLength = byte == 0x6b ? 4 : (byte == 0x64 ? 1 : 0)
            case 4:
                matchedPrefixLength = byte == 0x65 ? 5 : (byte == 0x64 ? 1 : 0)
            case 5:
                if byte == 0x72 {
                    return true
                }
                matchedPrefixLength = byte == 0x64 ? 1 : 0
            default:
                matchedPrefixLength = 0
            }
        }
        return false
    }
}
