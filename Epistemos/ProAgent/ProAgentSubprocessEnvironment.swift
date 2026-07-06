#if !EPISTEMOS_APP_STORE
import Foundation

enum ProAgentSubprocessEnvironment {
    nonisolated static let maxSubprocessEnvironmentValueCharacters =
        AgentSurfaceSubprocessEnvironment.maxSubprocessEnvironmentValueCharacters
    nonisolated static let maxSubprocessPathCharacters =
        AgentSurfaceSubprocessEnvironment.maxSubprocessPathCharacters
    nonisolated static let maxSubprocessPathEntryCharacters =
        AgentSurfaceSubprocessEnvironment.maxSubprocessPathEntryCharacters
    nonisolated static let maxSubprocessPathEntries =
        AgentSurfaceSubprocessEnvironment.maxSubprocessPathEntries

    nonisolated static func childEnvironment(
        binaryDirectories: [URL],
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        AgentSurfaceSubprocessEnvironment.childEnvironment(binaryDirectories: binaryDirectories, base: base)
    }

    nonisolated static func userToolPathDirectories(home: String?) -> [String] {
        AgentSurfaceSubprocessEnvironment.userToolPathDirectories(home: home)
    }

    nonisolated static func withUserToolPath(_ env: [String: String]) -> [String: String] {
        AgentSurfaceSubprocessEnvironment.withUserToolPath(env)
    }
}
#endif
