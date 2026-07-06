import Foundation

// Work backend seam. Honest flag-status for EPISTEMOS_WORK_BACKEND_V0, read by
// the visible WorkBackendHealthRow. ALWAYS-compiled + pure so the MAS build shows
// the honest "Pro only" state without compiling any secondary runtime. Mirrors
// ActOsaurusGateStatus.
nonisolated enum WorkBackendGateStatus {
    static let flagName = "EPISTEMOS_WORK_BACKEND_V0"

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
                detail: "The Epistemos Work backend seam is armed (\(flagName)=1). The follow-on repo engine is not wired yet, so the seam stays honestly inert with no fake capability. Other app modes stay on their own engines."
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
