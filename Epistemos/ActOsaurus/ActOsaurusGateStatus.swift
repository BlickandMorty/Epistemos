import Foundation

// Osaurus Act import — Seam A gate (P3.0). Honest flag-status for
// EPISTEMOS_ACT_OSAURUS_V0, read by the visible ActOsaurusHealthRow. ALWAYS-
// compiled + pure (no Osaurus dependency) so the MAS build can show the honest
// "Pro only" state without compiling any Osaurus runtime. Mirrors
// NightBrainLoRAGateStatus / DeepResearchGateStatus.
nonisolated enum ActOsaurusGateStatus {
    static let flagName = "EPISTEMOS_ACT_OSAURUS_V0"

    /// UserDefaults key for the IN-APP TOGGLE override (owner §806: "an easy in-app toggle"). Tri-state:
    /// ABSENT → defer to the `EPISTEMOS_ACT_OSAURUS_V0` env flag (the launch-time path the loop/cron uses);
    /// true/false → the in-app toggle FORCES the seam on/off at runtime (no relaunch). Default-absent keeps the
    /// flag-OFF-byte-identical guarantee (no override + no env = off, the proven MLX path unchanged).
    static let overrideDefaultsKey = "epistemos.act.osaurus.v0.override"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ raw: String?) -> Bool {
        guard let n = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return ["1", "true", "yes", "on"].contains(n)
    }

    /// The in-app toggle override, or `nil` when unset (→ defer to the env flag).
    static func override(defaults: UserDefaults = .standard) -> Bool? {
        defaults.object(forKey: overrideDefaultsKey) as? Bool
    }

    /// Set (true/false) or CLEAR (`nil` → revert to env-flag behavior) the in-app toggle override.
    static func setOverride(_ value: Bool?, defaults: UserDefaults = .standard) {
        if let value {
            defaults.set(value, forKey: overrideDefaultsKey)
        } else {
            defaults.removeObject(forKey: overrideDefaultsKey)
        }
    }

    /// Resolved arm-state used by the router: in-app override WINS; else the env flag; else off. The App Store
    /// build is ALWAYS off (the Osaurus substrate is Pro-only — no override can arm it there).
    static func resolvedActive(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        #if EPISTEMOS_APP_STORE
        return false
        #else
        if let override = override(defaults: defaults) { return override }
        return isEnabled(environment[flagName])
        #endif
    }

    static func status(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Status {
        #if EPISTEMOS_APP_STORE
        return Status(
            isActive: false,
            headline: "Act = Osaurus: Pro only",
            detail: "The Osaurus Act substrate (local server, agent loop, Containerization sandbox, relay) is a Pro feature — outside the App Store sandbox. On this build, Act stays on the in-process local-agent path."
        )
        #else
        let overrideValue = override(defaults: defaults)
        if resolvedActive(environment: environment, defaults: defaults) {
            let source = overrideValue == true ? "in-app toggle" : "\(flagName)=1"
            return Status(
                isActive: true,
                headline: "Act = Osaurus: ON (Pro, experimental)",
                detail: "The vendored Osaurus seam is armed (\(source)). MIT direct_import, Pro-gated. The runtime (server/VM/relay) stays inert until it clears the no-hidden-fallback bar — no hidden route."
            )
        }
        let detail: String
        if overrideValue == false {
            detail = "Turned off by the in-app toggle (overrides \(flagName)). Act stays on the in-process local-agent path."
        } else {
            detail = "Set \(flagName)=1 or use the in-app toggle to arm the vendored Osaurus Act seam (Pro). Off by default → Act stays on the in-process local-agent path."
        }
        return Status(isActive: false, headline: "Act = Osaurus: off (opt-in, Pro)", detail: detail)
        #endif
    }
}
