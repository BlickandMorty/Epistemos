import Foundation

// Goose=WORK seam — Seam A gate (R-GOOSE). Honest flag-status for
// EPISTEMOS_WORK_GOOSE_V0, read by the visible WorkBackendHealthRow. ALWAYS-
// compiled + pure (no Goose dependency) so the MAS build shows the honest "Pro
// only" state without compiling any Goose runtime. Mirrors ActOsaurusGateStatus.
//
// GOOSE GUARDRAIL (owner 2026-06-18): the extracted Goose core is isolated behind
// WORK mode + this flag; Chat (Epistemos engine) and Act (Osaurus) stay on their
// own engines, UNCHANGED. This seam touches nothing in the Chat/Act path — it's a
// new, isolated interface; the Goose Rust vendor (block/goose, Apache-2.0, into
// agent_core via UniFFI) is the heavy follow-on.
nonisolated enum WorkBackendGateStatus {
    static let flagName = "EPISTEMOS_WORK_GOOSE_V0"

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
            headline: "Work = Goose: Pro only",
            detail: "The Goose Work/Open-Code engine (repo indexing, git lifecycle, multi-file diffs, test-and-fix loop, parallel subagents) is a Pro feature — outside the App Store sandbox. Chat and Act are unaffected."
        )
        #else
        if isEnabled(environment[flagName]) {
            return Status(
                isActive: true,
                headline: "Work = Goose: ON (Pro, experimental)",
                detail: "The Work-backend seam is armed (\(flagName)=1). The Goose Rust engine (Apache-2.0) is the follow-on vendor; until it lands the seam is honestly INERT (no fake capability). Chat/Act stay on their own engines."
            )
        }
        return Status(
            isActive: false,
            headline: "Work = Goose: off (opt-in, Pro)",
            detail: "Set \(flagName)=1 to arm the Goose Work-backend seam (Pro). Off by default → Work is not yet wired; Chat/Act are unchanged."
        )
        #endif
    }
}
