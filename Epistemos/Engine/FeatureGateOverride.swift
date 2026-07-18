import Foundation

/// Shared in-app-toggle override semantics for experimental feature gates.
/// Both gates carried an identical copy of this logic (override > env flag > off); this is the single source so
/// they can't drift. The App-Store guard + the gate-specific flag/key/status stay at each call site.
///
/// Tri-state override: ABSENT (`nil`) → defer to the env flag; `true`/`false` → the in-app toggle forces the
/// gate on/off at runtime. Default-absent keeps flag-OFF behavior (the proven default path unchanged).
nonisolated enum FeatureGateOverride {
    /// The stored override for `key`, or `nil` when unset (→ defer to the env flag).
    static func value(forKey key: String, defaults: UserDefaults = FoundationSafety.runtimeUserDefaults) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    /// Set (true/false) or CLEAR (`nil` → revert to env-flag behavior) the override at `key`.
    static func set(_ value: Bool?, forKey key: String, defaults: UserDefaults = FoundationSafety.runtimeUserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// Whether an env-flag raw value means "on" (`1`/`true`/`yes`/`on`, case/whitespace-insensitive).
    static func isTruthy(_ raw: String?) -> Bool {
        guard let n = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return ["1", "true", "yes", "on"].contains(n)
    }

    /// Resolution used by the gates: the in-app override WINS; else the env flag; else off. Callers add the
    /// App-Store guard (these features are Pro / direct-distribution only).
    static func resolved(overrideKey: String, envValue: String?, defaults: UserDefaults = FoundationSafety.runtimeUserDefaults) -> Bool {
        if let override = value(forKey: overrideKey, defaults: defaults) { return override }
        return isTruthy(envValue)
    }
}
