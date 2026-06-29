import Foundation

// Phase 1 — native Agent frame surface flag.
//
// Per the owner charter (2026-06-27): NATIVE = FIXED frame (window + nav rail + permission/elicitation
// pop-ups) wrapping Goose's reskinned WebView; chat and every Goose feature stay in the WebView (there
// is NO native chat path — Gate 7 was deleted). This flag gates the opt-in native Agent frame window
// entry until the frame is proven (the WebView Goose surface, ⌘3, remains the default). Flip via the
// EPISTEMOS_AGENT_NATIVE_FRAME env var or the epistemos.agent.nativeFrame UserDefaults key.

enum AgentSurface {
    static let environmentKey = "EPISTEMOS_AGENT_NATIVE_FRAME"
    static let userDefaultsKey = "epistemos.agent.nativeFrame"

    static func isEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        if let raw = environment[environmentKey]?.lowercased() {
            return raw == "1" || raw == "true" || raw == "yes"
        }
        return userDefaults.bool(forKey: userDefaultsKey)
    }
}
