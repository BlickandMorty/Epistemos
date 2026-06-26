import Foundation

// Goose=WORK seam — Seam A gate (R-GOOSE). Honest flag-status for
// EPISTEMOS_WORK_GOOSE_V0, read by the visible WorkBackendHealthRow. ALWAYS-
// compiled + pure (no Goose dependency) so the MAS build shows the honest "Pro
// only" state without compiling any Goose runtime. Mirrors ActOsaurusGateStatus.
//
// GOOSE GUARDRAIL (owner 2026-06-18): the extracted Goose core is isolated behind
// WORK mode + this flag. This seam touches nothing outside the Work path — it's a
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
        FeatureGateOverride.isTruthy(raw)
    }

    static func status(environment: [String: String] = ProcessInfo.processInfo.environment) -> Status {
        #if EPISTEMOS_APP_STORE
        return Status(
            isActive: false,
            headline: "Epistemos Work: secondary engine Pro only",
            detail: "The secondary repo-work engine layer (repo indexing, git lifecycle, multi-file diffs, test-and-fix loop, parallel subagents) is a Pro feature outside the App Store sandbox. Other app modes are unaffected."
        )
        #else
        if isEnabled(environment[flagName]) {
            return Status(
                isActive: true,
                headline: "Epistemos Work: secondary engine ON",
                detail: "The Epistemos Work backend seam is armed (\(flagName)=1). The follow-on repo engine vendor is not wired yet, so the seam stays honestly inert with no fake capability. Other app modes stay on their own engines."
            )
        }
        return Status(
            isActive: false,
            headline: "Epistemos Work: secondary engine off",
            detail: "Set \(flagName)=1 to arm the secondary backend seam for Epistemos Work. Off by default means that layer is not wired yet; other app modes are unchanged."
        )
        #endif
    }
}
