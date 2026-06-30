import Foundation

nonisolated enum AgentToolNameAliases {
    static func canonical(_ name: String) -> String {
        name
    }
}

nonisolated struct WorkNativeMCPRegistration: Equatable, Sendable {
    let url: String
    let token: String
}

nonisolated enum ToolSurfacePolicy {
    enum Distribution: Sendable {
        case currentBuild
    }
}

nonisolated enum ChatToolTier: Sendable {
    case readOnly
}

nonisolated struct ToolTierBridge: Sendable {
    init(vaultPath: String, tier: ChatToolTier, allowedToolNames: Set<String>) {}

    func toolExecutor() -> LocalAgentToolExecutor {
        { name, argumentsJSON in
            LocalToolResult(
                toolName: name,
                resultJson: #"{"tool":"\#(name)","arguments":\#(argumentsJSON)}"#,
                isError: false)
        }
    }
}

nonisolated struct VaultMCPTokenStore: Sendable {
    func currentToken() -> String {
        "secret-token-abcdefghijklmnopqrstuvwxyz"
    }

    func rotateToken() -> String {
        "rotated-secret-token-abcdefghijklmnopqrstuvwxyz"
    }
}

nonisolated struct WorkAppContextSnapshot: Sendable {}

final class WorkAppContextStore {
    var snapshot: WorkAppContextSnapshot? { nil }
}

nonisolated enum WorkServerDiagnostics {
    static func statusMessage(for error: Error, fallback: String) -> String {
        let nsError = error as NSError
        return "\(fallback) (domain=\(nsError.domain) code=\(nsError.code))"
    }
}

struct WorkToolMCPCore {
    init(
        executor: @escaping LocalAgentToolExecutor,
        distribution: ToolSurfacePolicy.Distribution = .currentBuild,
        nativeToolVaultPath: String? = nil,
        appContextProvider: (@Sendable () -> WorkAppContextSnapshot?)? = nil
    ) {}

    func handle(requestJSON: String) async -> String {
        #"{"jsonrpc":"2.0","id":null,"result":{}}"#
    }
}
