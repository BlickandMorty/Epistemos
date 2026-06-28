import Foundation

// Plan 3 PDF→Markdown import gate. EPISTEMOS_LITEPARSE_PDF_V0 is kept as the
// existing UI kill switch, but Plan 3's pure-Rust EdgeParse/unpdf MAS parser is ON by
// default. ALWAYS-compiled + pure so the build shows the honest status without loading
// parser crates in Swift. Mirrors WorkBackendGateStatus.
//
// MAS-SAFE BY SCOPE: dedicated PDF→Markdown is fully LOCAL — pure Rust EdgeParse
// (Apache-2.0) plus unpdf (MIT), NO sidecar. Office/image formats remain OUT OF SCOPE
// here (rejected, never shelled out).
nonisolated enum LiteParseImportGateStatus {
    static let flagName = "EPISTEMOS_LITEPARSE_PDF_V0"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ raw: String?) -> Bool {
        guard let n = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return ["1", "true", "yes", "on"].contains(n)
    }

    static func isDisabled(_ raw: String?) -> Bool {
        guard let n = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return ["0", "false", "no", "off"].contains(n)
    }

    static func status(environment: [String: String] = ProcessInfo.processInfo.environment) -> Status {
        if isDisabled(environment[flagName]) {
            return Status(
                isActive: false,
                headline: "PDF→Markdown import: disabled by kill switch",
                detail: "\(flagName)=0 disables the Plan 3 PDF import surface. Remove the variable or set it to 1 to re-enable the MAS-safe EdgeParse/unpdf parser."
            )
        }
        return Status(
            isActive: true,
            headline: "PDF→Markdown import: ready",
            detail: "Plan 3 PDF import is on by default. The Rust parser is EdgeParse primary + unpdf fallback (pure Rust, local, no sidecar); PDF only. Set \(flagName)=0 for an emergency kill switch."
        )
    }
}
