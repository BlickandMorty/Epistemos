import Foundation

// WORK = OpenCode shell — legacy Seam A gate (owner 2026-06-21). Kept as a
// compatibility/status seam for EPISTEMOS_WORK_OPENCODE_V0; the visible Work
// health row now reads WorkOpenCodeShellFactory directly because Work goes live
// from bundled-runtime presence, not from this old opt-in gate.
// ALWAYS-compiled + pure (no SwiftTerm / PTY / OpenCode dependency) so the MAS
// build shows the honest state without compiling any terminal runtime. Mirrors
// WorkBackendGateStatus / ActOsaurusGateStatus.
//
// OWNER DIRECTIVE (2026-06-21): WORK mode = the REAL OpenCode terminal TUI rendered
// in a NATIVE terminal view (SwiftTerm/PTY) — not an Electron/Tauri GUI, not a
// native rebuild. The Bun engine lazy-launches on loopback (kill-on-idle); donor
// engines fuse beneath the OpenCode shell through explicit backend seams. This gate
// is the shell (UI) seam; WorkBackendGateStatus is the engine seam — distinct, both honest-inert until
// their heavy vendors land. Pro path (`#if !EPISTEMOS_APP_STORE`); the MAS dual-build
// gets the same capability via the researched sandbox substitute, never a silent cut.
nonisolated enum WorkOpenCodeShellGateStatus {
    static let flagName = "EPISTEMOS_WORK_OPENCODE_V0"

    /// IN-APP TOGGLE override (owner §194 "two toggles = act/work") — the work-mode twin of the act gate's
    /// override, so BOTH modes are runtime-toggleable (no env var + relaunch). Tri-state: ABSENT → defer to the
    /// env flag; true/false → the toggle forces work on/off at runtime. Default-absent = flag-OFF behavior
    /// (work stays honest-inert by default). Mirrors `ActOsaurusGateStatus`.
    static let overrideDefaultsKey = "epistemos.work.opencode.v0.override"

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

    /// Resolved arm-state: in-app override WINS; else the env flag; else off. App Store build = ALWAYS off
    /// (the OpenCode/Bun runtime is Pro / direct-distribution only). Default-absent override keeps flag-OFF.
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
            headline: "Epistemos Work: terminal runtime Pro only",
            detail: "Epistemos Work's terminal runtime ships on the direct-distribution build, with native Epistemos chrome above it. The MAS dual-build gets the researched sandbox substitute — never a silent cut. Other app modes are unaffected."
        )
        #else
        let overrideValue = override(defaults: defaults)
        if resolvedActive(environment: environment, defaults: defaults) {
            let source = overrideValue == true ? "legacy in-app toggle" : "\(flagName)=1"
            return Status(
                isActive: true,
                headline: "Epistemos Work: legacy runtime override active",
                detail: "The legacy terminal compatibility override is active (\(source)). The visible Work surface still follows bundled runtime readiness; if the runtime is absent, Epistemos Work stays honestly INERT and no fake terminal is launched. Other app modes stay on their own engines."
            )
        }
        let detail = overrideValue == false
            ? "Disabled by the legacy in-app toggle (overrides \(flagName)). Epistemos Work follows bundled runtime readiness for the visible surface; other app modes are unchanged."
            : "Epistemos Work goes live when its bundled terminal runtime is present. \(flagName)=1 remains as a legacy compatibility arm for diagnostics, but it does not fake a terminal. Other app modes are unchanged."
        return Status(isActive: false, headline: "Epistemos Work: terminal runtime unavailable", detail: detail)
        #endif
    }
}
