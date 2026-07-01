import Foundation

// Plan 3 arXiv pull gate. Search and metadata retrieval are MAS-safe public
// HTTPS calls. Full-text ingest still honestly depends on the PDF→Markdown
// importer, so a not-wired parser creates no note.
nonisolated enum ArxivPullGateStatus {
    static let flagName = "EPISTEMOS_ARXIV_PULL_V0"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ raw: String?) -> Bool {
        !isDisabled(raw)
    }

    static func isDisabled(_ raw: String?) -> Bool {
        guard let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["0", "false", "no", "off"].contains(normalized)
    }

    static func status(environment: [String: String] = ProcessInfo.processInfo.environment) -> Status {
        if isDisabled(environment[flagName]) {
            return Status(
                isActive: false,
                headline: "arXiv pull: disabled by kill switch",
                detail: "\(flagName)=0 disables the Plan 3 arXiv search and ingest surface. Remove the variable or set it to 1 to re-enable it."
            )
        }
        return Status(
            isActive: true,
            headline: "arXiv pull: ready",
            detail: "Plan 3 arXiv pull is on by default. Search uses arxiv.org HTTPS; ingest creates a note only after the local PDF→Markdown importer returns real markdown."
        )
    }
}
