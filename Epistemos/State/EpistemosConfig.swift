import Foundation
import OSLog
import SwiftUI

// MARK: - Epistemos Config
// Unified feature flags and thresholds for cognitive substrates.
// Backed by UserDefaults via @AppStorage — zero migration cost for new keys.

@Observable
final class EpistemosConfig {
    private static let log = Logger(subsystem: "com.epistemos", category: "EpistemosConfig")

    // MARK: - Power Management
    @ObservationIgnored @AppStorage("epistemos.ecoMode") var ecoModeEnabled = true

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

    // MARK: - SSM State Persistence (Mamba vault memory)
    @ObservationIgnored @AppStorage("ssm.statePersistenceEnabled") var ssmStatePersistenceEnabled = false
    @ObservationIgnored @AppStorage("ssm.autoSaveOnTurnEnd") var ssmAutoSaveOnTurnEnd = true
    @ObservationIgnored @AppStorage("ssm.maxSnapshotsPerModel") var ssmMaxSnapshotsPerModel: Int = 5

    // MARK: - Claude Managed Sessions (Optional cloud agent backend)
    @ObservationIgnored @AppStorage("cma.enabled") var claudeManagedSessionsEnabled = false
    @ObservationIgnored @AppStorage("cma.defaultBudgetUSD") var defaultAgentBudgetUSD: Double = 0
    // 0 = unlimited; any positive value = hard cap per session

    // MARK: - Agent Heartbeat (Background scheduled agent runs)
    @ObservationIgnored @AppStorage("heartbeat.enabled") var heartbeatEnabled = false
    @ObservationIgnored @AppStorage("heartbeat.intervalSeconds") var heartbeatIntervalSeconds = 3600.0
    @ObservationIgnored @AppStorage("heartbeat.requiresAC") var heartbeatRequiresAC = true
    @ObservationIgnored @AppStorage("heartbeat.prompt") var heartbeatPrompt = "Review my vault for new items. Summarize anything added since last check."
    @ObservationIgnored @AppStorage("heartbeat.budgetCapMicro") var heartbeatBudgetCapMicro: Int = 500_000

    // MARK: - Allowlist / Blocklist Helpers

    var allowlist: [String] {
        get { decodeBundleList(allowlistJSON, label: "allowlist") ?? [] }
        set {
            guard let encoded = encodeBundleList(newValue) else { return }
            allowlistJSON = encoded
        }
    }

    var blocklist: [String] {
        get { decodeBundleList(blocklistJSON, label: "blocklist") ?? [] }
        set {
            guard let encoded = encodeBundleList(newValue) else { return }
            blocklistJSON = encoded
        }
    }

    func isBlocked(_ bundleId: String) -> Bool {
        guard let block = decodeBundleList(blocklistJSON, label: "blocklist") else { return true }
        if block.contains(bundleId) { return true }
        guard let allow = decodeBundleList(allowlistJSON, label: "allowlist") else { return true }
        if !allow.isEmpty && !allow.contains(bundleId) { return true }
        return false
    }

    private func decodeBundleList(_ json: String, label: String) -> [String]? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        do {
            let decoded = try JSONDecoder().decode([String].self, from: Data(trimmed.utf8))
            let normalized = deduplicatedBundleList(decoded)
            persistDecodedBundleList(normalized, label: label, rawValue: trimmed)
            return normalized
        } catch {
            if let legacyList = decodeLegacyBundleList(trimmed) {
                persistDecodedBundleList(legacyList, label: label, rawValue: trimmed)
                return legacyList
            }

            let message: String
            switch label {
            case "allowlist":
                message = "EpistemosConfig: failed to decode capture allowlist JSON"
            case "blocklist":
                message = "EpistemosConfig: failed to decode capture blocklist JSON"
            default:
                message = "EpistemosConfig: failed to decode capture filter JSON"
            }
            Self.log.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func decodeLegacyBundleList(_ raw: String) -> [String]? {
        let values = raw
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !values.isEmpty else { return [] }
        guard values.count > 1 || values[0].contains(".") else { return nil }
        return deduplicatedBundleList(values)
    }

    private func deduplicatedBundleList(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var deduplicated: [String] = []
        deduplicated.reserveCapacity(values.count)

        for value in values where seen.insert(value).inserted {
            deduplicated.append(value)
        }

        return deduplicated
    }

    private func persistDecodedBundleList(_ values: [String], label: String, rawValue: String) {
        guard let encoded = encodeBundleList(values), encoded != rawValue else { return }

        switch label {
        case "allowlist":
            allowlistJSON = encoded
        case "blocklist":
            blocklistJSON = encoded
        default:
            break
        }
    }

    private func encodeBundleList(_ values: [String]) -> String? {
        do {
            let encoded = try JSONEncoder().encode(values)
            guard let json = String(data: encoded, encoding: .utf8) else {
                Self.log.error("EpistemosConfig: failed to encode capture filter JSON as UTF-8 text")
                return nil
            }
            return json
        } catch {
            Self.log.error("EpistemosConfig: failed to encode capture filter JSON: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
