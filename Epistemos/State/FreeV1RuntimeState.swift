import Foundation

nonisolated enum LegacyRemoteConfiguration {
    static func purge(defaults: UserDefaults = FoundationSafety.runtimeUserDefaults) {
        [
            "epistemos.apiProvider",
            "epistemos.ollamaBaseUrl",
            "epistemos.ollamaModel",
            "epistemos.activeAIProvider",
            "epistemos.lastNonLocalAIProvider",
            "epistemos.chatAutoRouteToCloud",
            "epistemos.cloudAutoFallback",
        ].forEach(defaults.removeObject(forKey:))
    }
}
