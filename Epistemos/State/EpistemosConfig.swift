import Foundation
import SwiftUI

// MARK: - Epistemos Config
// Unified feature flags and thresholds for cognitive substrates.
// Backed by UserDefaults via @AppStorage — zero migration cost for new keys.

@Observable
final class EpistemosConfig {
    // MARK: - Cross-App Capture
    @ObservationIgnored @AppStorage("capture.enabled") var captureEnabled = false
    @ObservationIgnored @AppStorage("capture.ocrFallback") var ocrFallbackEnabled = true
    @ObservationIgnored @AppStorage("capture.allowlistJSON") var allowlistJSON = "[]"
    @ObservationIgnored @AppStorage("capture.blocklistJSON") var blocklistJSON = "[]"

    // MARK: - Friction Detection
    @ObservationIgnored @AppStorage("friction.enabled") var frictionEnabled = true
    @ObservationIgnored @AppStorage("friction.threshold") var frictionThreshold = 1.5

    // MARK: - Night Brain
    @ObservationIgnored @AppStorage("nightbrain.enabled") var nightBrainEnabled = true
    @ObservationIgnored @AppStorage("nightbrain.requiresAC") var nightBrainRequiresAC = true
    @ObservationIgnored @AppStorage("nightbrain.minIdleSeconds") var nightBrainMinIdleSeconds = 300.0
    @ObservationIgnored @AppStorage("nightbrain.menuBarAgent") var nightBrainMenuBarAgent = false

    // MARK: - Agent Heartbeat (Background scheduled agent runs)
    @ObservationIgnored @AppStorage("heartbeat.enabled") var heartbeatEnabled = false
    @ObservationIgnored @AppStorage("heartbeat.intervalSeconds") var heartbeatIntervalSeconds = 3600.0
    @ObservationIgnored @AppStorage("heartbeat.requiresAC") var heartbeatRequiresAC = true
    @ObservationIgnored @AppStorage("heartbeat.prompt") var heartbeatPrompt = "Review my vault for new items. Summarize anything added since last check."
    @ObservationIgnored @AppStorage("heartbeat.budgetCapMicro") var heartbeatBudgetCapMicro: Int = 500_000

    // MARK: - Allowlist / Blocklist Helpers

    var allowlist: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(allowlistJSON.utf8))) ?? [] }
        set { allowlistJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var blocklist: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(blocklistJSON.utf8))) ?? [] }
        set { blocklistJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    func isBlocked(_ bundleId: String) -> Bool {
        let block = blocklist
        if block.contains(bundleId) { return true }
        let allow = allowlist
        if !allow.isEmpty && !allow.contains(bundleId) { return true }
        return false
    }
}
