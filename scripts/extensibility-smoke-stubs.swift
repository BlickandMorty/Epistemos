import Foundation

nonisolated enum ToolSurfacePolicy {
    enum Distribution: Sendable {
        case currentBuild
        case coreAppStore
        case proResearch
    }

    static let coreAppStoreAllowedToolNames: Set<String> = [
        "vault.search",
        "vault.read",
        "eidos.query",
        "web.search",
        "web.fetch",
        "graph.query",
        "graph.neighbors",
    ]

    static func resolvedDistribution(_ distribution: Distribution) -> Distribution {
        switch distribution {
        case .currentBuild:
            return .coreAppStore
        case .coreAppStore, .proResearch:
            return distribution
        }
    }

    static func isSurfacedToolName(
        _ canonicalToolName: String,
        distribution: Distribution = .currentBuild
    ) -> Bool {
        switch resolvedDistribution(distribution) {
        case .coreAppStore:
            return coreAppStoreAllowedToolNames.contains(canonicalToolName)
        case .proResearch:
            return true
        case .currentBuild:
            return coreAppStoreAllowedToolNames.contains(canonicalToolName)
        }
    }
}
