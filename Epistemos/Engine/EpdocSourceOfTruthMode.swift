import Foundation

/// Staged L1 source-of-truth switch for `.epdoc` persistence.
///
/// Default is intentionally JSON-only. The markdown bridge can be proven
/// and dual-written without making vault `.md` canonical until the
/// round-trip falsifiers are green.
nonisolated public enum EpdocSourceOfTruthMode: Sendable, Hashable {
    case jsonOnly
    case dualWrite
    case markdownCanonical

    public static let environmentKey = "EPISTEMOS_MD_SOURCE_OF_TRUTH"

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self = Self.parse(environment[Self.environmentKey])
    }

    public static func parse(_ rawValue: String?) -> EpdocSourceOfTruthMode {
        let value = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch value {
        case "1", "true", "yes", "dualwrite", "dual-write", "dual_write":
            return .dualWrite
        case "2", "canonical", "markdowncanonical", "markdown-canonical", "markdown_canonical":
            return .markdownCanonical
        default:
            return .jsonOnly
        }
    }
}
