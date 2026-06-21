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
            headline: "Work = OpenCode terminal: Pro only",
            detail: "The OpenCode work shell (real terminal TUI in a native terminal view, lazy Bun engine, Goose/Hermes/OpenClaw fused beneath) ships on the direct-distribution build. The MAS dual-build gets the same capability via the researched sandbox substitute — never a silent cut. Chat and Act are unaffected."
        )
        #else
        if isEnabled(environment[flagName]) {
            return Status(
                isActive: true,
                headline: "Work = OpenCode terminal: ON (Pro, experimental)",
                detail: "The OpenCode shell seam is armed (\(flagName)=1). The native terminal view (SwiftTerm/PTY), the lazy-launched Bun engine, and the vendored OpenCode TUI are the follow-on; until they land the seam is honestly INERT (no fake terminal). Chat/Act stay on their own engines."
            )
        }
        return Status(
            isActive: false,
            headline: "Work = OpenCode terminal: off (opt-in, Pro)",
            detail: "Set \(flagName)=1 to arm the OpenCode work-shell seam (Pro). Off by default → Work's terminal is not yet wired; Chat/Act are unchanged."
        )
        #endif
    }
}
