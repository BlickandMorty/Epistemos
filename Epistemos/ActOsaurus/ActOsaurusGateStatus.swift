import Foundation

// Osaurus Act import — Seam A gate (P3.0). Honest flag-status for
// EPISTEMOS_ACT_OSAURUS_V0, read by the visible ActOsaurusHealthRow. ALWAYS-
// compiled + pure (no Osaurus dependency) so the MAS build can show the honest
// "Pro only" state without compiling any Osaurus runtime. Mirrors
// NightBrainLoRAGateStatus / DeepResearchGateStatus.
nonisolated enum ActOsaurusGateStatus {
    static let flagName = "EPISTEMOS_ACT_OSAURUS_V0"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ raw: String?) -> Bool {
        guard let n = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return ["1", "true", "yes", "on"].contains(n)
    }

    static func status(environment: [String: String] = ProcessInfo.processInfo.environment) -> Status {
        #if EPISTEMOS_APP_STORE
        return Status(
            isActive: false,
            headline: "Act = Osaurus: Pro only",
            detail: "The Osaurus Act substrate (local server, agent loop, Containerization sandbox, relay) is a Pro feature — outside the App Store sandbox. On this build, Act stays on the in-process local-agent path."
        )
        #else
        if isEnabled(environment[flagName]) {
            return Status(
                isActive: true,
                headline: "Act = Osaurus: ON (Pro, experimental)",
                detail: "The vendored Osaurus seam is armed (\(flagName)=1). MIT direct_import, Pro-gated. The runtime (server/VM/relay) stays inert until it clears the no-hidden-fallback bar — no hidden route."
            )
        }
        return Status(
            isActive: false,
            headline: "Act = Osaurus: off (opt-in, Pro)",
            detail: "Set \(flagName)=1 to arm the vendored Osaurus Act seam (Pro). Off by default → Act stays on the in-process local-agent path."
        )
        #endif
    }
}
