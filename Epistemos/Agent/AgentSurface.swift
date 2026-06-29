import Foundation

// Phase 1 — native Agent surface feature flags.
//
// `useNativeChatPath` stays DEFAULT FALSE until Step 9 (chat-primary flip): the WebView remains the
// proven primary surface; the native Agent window is opt-in until its WRV passes. Flip via the
// `EPISTEMOS_AGENT_NATIVE_CHAT` env var or the `epistemos.agent.useNativeChatPath` UserDefaults key —
// the single explicit promotion point (mirrors the GooseSurfaceRouter flag pattern).

enum AgentSurface {
    static let environmentKey = "EPISTEMOS_AGENT_NATIVE_CHAT"
    static let userDefaultsKey = "epistemos.agent.useNativeChatPath"

    static func useNativeChatPath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        if let raw = environment[environmentKey]?.lowercased() {
            return raw == "1" || raw == "true" || raw == "yes"
        }
        return userDefaults.bool(forKey: userDefaultsKey)
    }
}
