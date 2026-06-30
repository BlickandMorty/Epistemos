import Foundation

// Native Goose frame surface flag.
//
// Per the owner charter (2026-06-30): NATIVE = the macOS window frame plus native
// permission / elicitation pop-ups only. Goose's reskinned WebView owns the whole
// visible app surface, including navigation; no native nav rail or route panels.

enum AgentSurface {
    static let environmentKey = "EPISTEMOS_AGENT_NATIVE_FRAME"
    static let userDefaultsKey = "epistemos.agent.nativeFrame"

    static func isEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        if let raw = environment[environmentKey]?.lowercased() {
            return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
        }
        if let stored = userDefaults.object(forKey: userDefaultsKey) as? Bool {
            return stored
        }
        return true
    }
}
