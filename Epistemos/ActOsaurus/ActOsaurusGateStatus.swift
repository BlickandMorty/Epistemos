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
        FeatureGateOverride.isTruthy(raw)
    }

    /// The in-app toggle override, or `nil` when unset (→ defer to the env flag).
    static func override(defaults: UserDefaults = .standard) -> Bool? {
        FeatureGateOverride.value(forKey: overrideDefaultsKey, defaults: defaults)
    }

    /// Set (true/false) or CLEAR (`nil` → revert to env-flag behavior) the in-app toggle override.
    static func setOverride(_ value: Bool?, defaults: UserDefaults = .standard) {
        FeatureGateOverride.set(value, forKey: overrideDefaultsKey, defaults: defaults)
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
        return FeatureGateOverride.resolved(
            overrideKey: overrideDefaultsKey, envValue: environment[flagName], defaults: defaults)
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
        if LocalAgentLoop.shouldRouteActThroughOsaurus(environment: environment) {
            let source = overrideValue == true ? "legacy in-app override" : "default Pro route"
            return Status(
                isActive: true,
                headline: "Act = Osaurus: ON (Pro, experimental)",
                detail: "Act is routed through the vendored Osaurus engine (\(source)). MIT direct_import, Pro-gated, in-process, and honest: no hidden cloud route."
            )
        }
        let detail: String
        if overrideValue == false {
            detail = "Turned off by the legacy in-app override (overrides \(flagName)). Act stays on the in-process local-agent path."
        } else {
            detail = "The vendored Osaurus Act seam is unavailable in this build profile. Act stays on the in-process local-agent path."
        }
        return Status(isActive: false, headline: "Act = Osaurus: off", detail: detail)
        #endif
    }
}
