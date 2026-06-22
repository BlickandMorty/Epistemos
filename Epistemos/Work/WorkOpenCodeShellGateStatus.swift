import Foundation

// WORK = OpenCode shell — Seam A gate (owner 2026-06-21). Honest flag-status for
// EPISTEMOS_WORK_OPENCODE_V0, read by the visible WorkOpenCodeShellHealthRow.
// ALWAYS-compiled + pure (no SwiftTerm / PTY / OpenCode dependency) so the MAS
// build shows the honest state without compiling any terminal runtime. Mirrors
// WorkBackendGateStatus / ActOsaurusGateStatus.
//
// OWNER DIRECTIVE (2026-06-21): WORK mode = the REAL OpenCode terminal TUI rendered
// in a NATIVE terminal view (SwiftTerm/PTY) — not an Electron/Tauri GUI, not a
// native rebuild. The Bun engine lazy-launches on loopback (kill-on-idle); Goose +
// Hermes + OpenClaw fuse BENEATH the OpenCode shell (the existing WorkBackend Goose
// seam is one engine fused under here). This gate is the shell (UI) seam; the Goose
// gate (WorkBackendGateStatus) is the engine seam — distinct, both honest-inert until
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
            headline: "Work = OpenCode terminal: Pro only",
            detail: "The OpenCode work shell (real terminal TUI in a native terminal view, lazy Bun engine, Goose/Hermes/OpenClaw fused beneath) ships on the direct-distribution build. The MAS dual-build gets the same capability via the researched sandbox substitute — never a silent cut. Chat and Act are unaffected."
        )
        #else
        let overrideValue = override(defaults: defaults)
        if resolvedActive(environment: environment, defaults: defaults) {
            let source = overrideValue == true ? "in-app toggle" : "\(flagName)=1"
            return Status(
                isActive: true,
                headline: "Work = OpenCode terminal: ON (Pro, experimental)",
                detail: "The OpenCode shell seam is armed (\(source)). The native terminal view (SwiftTerm/PTY), the lazy-launched Bun engine, and the vendored OpenCode TUI go live when the runtime is bundled; until then the seam is honestly INERT (no fake terminal). Chat/Act stay on their own engines."
            )
        }
        let detail = overrideValue == false
            ? "Turned off by the in-app toggle (overrides \(flagName)). Work's terminal stays inert; Chat/Act are unchanged."
            : "Set \(flagName)=1 or use the in-app toggle to arm the OpenCode work-shell seam (Pro). Off by default → Work's terminal is not yet wired; Chat/Act are unchanged."
        return Status(isActive: false, headline: "Work = OpenCode terminal: off (opt-in, Pro)", detail: detail)
        #endif
    }
}
