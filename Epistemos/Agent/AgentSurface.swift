import Foundation

// Native Goose frame surface flag.
//
// Per the owner charter (2026-06-27): NATIVE = FIXED frame (window + nav rail + permission/elicitation
// pop-ups) wrapping Goose's reskinned WebView; chat and every Goose feature stay in the WebView (there
// is NO native chat path — Gate 7 was deleted). The frame is now a real Goose entry; the env/UserDefaults
// flag remains as an override for diagnostics or rollback, not as a proof gate.

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
